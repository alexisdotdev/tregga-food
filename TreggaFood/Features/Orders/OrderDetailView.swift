import SwiftUI
import UIKit
import TreggaCore
import TreggaDesignSystem

/// Detalle completo de un pedido (F5): banner de estatus, negocio, items con
/// modificadores, desglose, entrega/pago, calificación o CTA, y acciones.
struct OrderDetailView: View {
    @State var viewModel: OrderDetailViewModel
    let onSeguir: (UUID) -> Void
    let onCalificar: (PedidoDetalle) -> Void
    let onBack: () -> Void

    @Environment(\.appDependencies) private var deps
    @Environment(\.cartStore) private var cart
    @Environment(\.clientShell) private var shell

    @State private var volviendoAPedir = false
    @State private var noDisponibles: [String] = []
    @State private var huboModificadores = false
    @State private var mostrarResultadoReorden = false
    /// Pedido en espera de confirmar el reemplazo del carrito (otro negocio).
    @State private var reordenPendiente: PedidoDetalle?

    var body: some View {
        ZStack(alignment: .bottom) {
            content
            if let detalle = viewModel.detalle {
                footer(detalle)
            }
        }
        .background(TreggaColors.bg)
        .task { await viewModel.cargar() }
        .swipeToGoBack(onBack)
        .alert(
            "Carrito de otro negocio",
            isPresented: Binding(
                get: { cart?.pendingConflict != nil || reordenPendiente != nil },
                set: { if !$0 { cart?.resolverConflicto(reemplazar: false); reordenPendiente = nil } }
            )
        ) {
            Button("Vaciar y agregar", role: .destructive) {
                if let pedido = reordenPendiente {
                    cart?.clear()
                    reordenPendiente = nil
                    Task { await agregarVigentes(pedido) }
                } else {
                    cart?.resolverConflicto(reemplazar: true)
                }
            }
            Button("Cancelar", role: .cancel) {
                cart?.resolverConflicto(reemplazar: false)
                reordenPendiente = nil
            }
        } message: {
            Text("Tu carrito tiene productos de \(cart?.negocioName ?? "otro negocio"). Para pedir de otro negocio vaciaremos el carrito actual.")
        }
        // Solo aparece si hubo algo que avisar (faltantes y/o modificadores no
        // reconstruidos); al aceptar se navega al carrito — el requerimiento es
        // cerrar el detalle tras agregar.
        .alert(
            noDisponibles.isEmpty ? "Revisa tu carrito" : "Algunos productos ya no están disponibles",
            isPresented: $mostrarResultadoReorden
        ) {
            Button("Ver carrito") { irAlCarrito() }
        } message: {
            Text(noDisponiblesMensaje)
        }
    }

    private var noDisponiblesMensaje: String {
        var partes: [String] = []
        if !noDisponibles.isEmpty {
            partes.append(noDisponibles.joined(separator: ", "))
        }
        if huboModificadores {
            partes.append("Revisa las personalizaciones en tu carrito: se agregaron los productos base.")
        }
        return partes.joined(separator: "\n\n")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .cargando:
            VStack(spacing: 12) {
                ProgressView()
                Text("Cargando pedido…").treggaStyle(.sub).foregroundStyle(TreggaColors.textSec)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let msg):
            VStack(spacing: 14) {
                TreggaIcon(.info, size: 36, color: TreggaColors.danger)
                Text(msg).treggaStyle(.sub).multilineTextAlignment(.center)
                    .foregroundStyle(TreggaColors.textSec).padding(.horizontal, 40)
                TreggaButton("Reintentar", kind: .secondary, isFullWidth: false, height: 44) {
                    Task { await viewModel.cargar() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .cargado(let detalle):
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    navBar(detalle)
                    statusBanner(detalle)
                    negocioCard(detalle)
                    itemsSection(detalle)
                    entregaPagoSection(detalle)
                    desgloseSection(detalle)
                    if detalle.status.isCompleted { calificacionSection(detalle) }
                    if detalle.status.isCancelled, let motivo = detalle.cancellationReason {
                        motivoCancelacion(motivo)
                    }
                }
                .padding(.bottom, 140)
            }
        }
    }

    // MARK: - Secciones

    private func navBar(_ detalle: PedidoDetalle) -> some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                ZStack {
                    Circle().fill(TreggaColors.surface).frame(width: 38, height: 38)
                    TreggaIcon(.chevL, size: 18, color: TreggaColors.text)
                }
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(detalle.orderNumber.isEmpty ? "Pedido" : "Pedido \(detalle.orderNumber)")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                Text(OrderDateFormat.headerSub(detalle.fecha))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(TreggaColors.textSec)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func statusBanner(_ detalle: PedidoDetalle) -> some View {
        let cancelled = detalle.status.isCancelled
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(cancelled ? TreggaColors.accent : TreggaColors.primary).frame(width: 38, height: 38)
                TreggaIcon(cancelled ? .close : .check, size: 20, color: .white, weight: .bold)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(detalle.estadoTitulo)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(cancelled ? TreggaColors.accent : TreggaColors.primaryDeep)
                Text(subStatus(detalle))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(cancelled ? TreggaColors.accent : TreggaColors.primaryDark)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cancelled ? TreggaColors.accentSoft : TreggaColors.primarySoft, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func subStatus(_ detalle: PedidoDetalle) -> String {
        if detalle.esperandoNegocio {
            return "Estamos confirmando tu pedido con el negocio."
        }
        if detalle.status.isCompleted, let c = detalle.completedAt {
            return "Entregado el \(OrderDateFormat.headerSub(c))"
        }
        if detalle.status.isCancelled, let c = detalle.cancelledAt {
            return "Cancelado el \(OrderDateFormat.headerSub(c))"
        }
        return "Tu pedido está en proceso"
    }

    private func negocioCard(_ detalle: PedidoDetalle) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(TreggaColors.primarySoft).frame(width: 52, height: 52)
                TreggaIcon(.bag, size: 24, color: TreggaColors.primaryDark)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(detalle.negocioName)
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                Text("\(detalle.items.count) producto\(detalle.items.count == 1 ? "" : "s")")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(TreggaColors.textSec)
            }
            Spacer()
        }
        .padding(12)
        .background(TreggaColors.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func itemsSection(_ detalle: PedidoDetalle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Lo que pediste")
            VStack(spacing: 0) {
                ForEach(Array(detalle.items.enumerated()), id: \.element.id) { idx, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(item.cantidad)×")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(TreggaColors.text)
                            .frame(width: 26, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.nombre)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundStyle(TreggaColors.text)
                            if !item.modificadores.isEmpty {
                                Text(item.modificadores.joined(separator: " · "))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TreggaColors.textSec)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(PriceFormat.pesos(item.subtotal))
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(TreggaColors.text)
                    }
                    .padding(.vertical, 12)
                    if idx < detalle.items.count - 1 { TreggaDivider() }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 18)
    }

    private func entregaPagoSection(_ detalle: PedidoDetalle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Entrega y pago")
            VStack(spacing: 0) {
                if let address = detalle.deliveryAddress, !address.isEmpty {
                    infoRow(icon: .pin, label: "Entrega", sub: address)
                    TreggaDivider()
                }
                if let rep = detalle.repartidorName, !rep.isEmpty {
                    infoRow(icon: .bike, label: rep, sub: "Repartidor")
                    TreggaDivider()
                }
                infoRow(icon: .card, label: detalle.metodoPago.titulo, sub: pagoSub(detalle))
            }
            .background(TreggaColors.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
        .padding(.top, 18)
    }

    private func pagoSub(_ detalle: PedidoDetalle) -> String {
        switch (detalle.paymentStatus ?? "").lowercased() {
        case "paid", "pagado": return "Pagado"
        case "pending", "pendiente": return "Pago pendiente"
        default: return "Método de pago"
        }
    }

    private func infoRow(icon: TreggaIcon.Name, label: String, sub: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(TreggaColors.surface).frame(width: 34, height: 34)
                TreggaIcon(icon, size: 16, color: TreggaColors.text)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 13.5, weight: .bold)).foregroundStyle(TreggaColors.text)
                Text(sub).font(.system(size: 12, weight: .medium)).foregroundStyle(TreggaColors.textSec)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func desgloseSection(_ detalle: PedidoDetalle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Desglose")
            VStack(spacing: 6) {
                desgloseRow("Subtotal", detalle.subtotal)
                desgloseRow("Envío", detalle.deliveryFee)
                if detalle.propina > 0 { desgloseRow("Propina", detalle.propina) }
                HStack {
                    Text("Total")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                    Spacer()
                    Text(PriceFormat.pesos(detalle.total))
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 18)
    }

    private func desgloseRow(_ label: String, _ value: Decimal) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(TreggaColors.textSec)
            Spacer()
            Text(PriceFormat.pesos(value)).font(.system(size: 14, weight: .bold)).foregroundStyle(TreggaColors.text)
        }
    }

    private func calificacionSection(_ detalle: PedidoDetalle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Tu calificación")
            if let cal = detalle.calificacion {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { i in
                            TreggaIcon(.star, size: 18, color: i <= cal.rating ? TreggaColors.star : TreggaColors.textTer)
                        }
                    }
                    if let comment = cal.comment, !comment.isEmpty {
                        Text("“\(comment)”")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(TreggaColors.textSec)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TreggaColors.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.border, lineWidth: 1))
                .padding(.horizontal, 16)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("¿Cómo estuvo tu entrega?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TreggaColors.text)
                    TreggaButton("Calificar", kind: .primary, height: 48) {
                        onCalificar(detalle)
                    }
                }
                .padding(14)
                .background(TreggaColors.primarySoft, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 18)
    }

    /// Traduce el enum `cancellation_reason` de la DB a texto para el cliente.
    private func motivoLegible(_ motivo: String) -> String {
        switch motivo {
        case "negocio_timeout": return "El negocio no alcanzó a tomar tu pedido a tiempo. No se te hizo ningún cargo."
        case "negocio_rechazo": return "El negocio no pudo tomar tu pedido. No se te hizo ningún cargo."
        case "negocio_cancelo": return "El negocio canceló tu pedido."
        case "sin_repartidor":  return "No encontramos un repartidor disponible para tu pedido."
        default:                return motivo
        }
    }

    private func motivoCancelacion(_ motivo: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Motivo de cancelación")
            Text(motivoLegible(motivo))
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(TreggaColors.textSec)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TreggaColors.accentSoft, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
        }
        .padding(.top, 18)
    }

    // MARK: - Footer

    @ViewBuilder
    private func footer(_ detalle: PedidoDetalle) -> some View {
        VStack(spacing: 10) {
            if detalle.enCurso {
                TreggaButton("Seguir mi pedido", kind: .primary, height: 54) {
                    onSeguir(detalle.id)
                }
            } else {
                HStack(spacing: 10) {
                    Button {
                        reportarProblema(detalle)
                    } label: {
                        Text("Reportar problema")
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .foregroundStyle(TreggaColors.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(TreggaColors.dangerBg, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(TreggaColors.danger.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await volverAPedir(detalle) }
                    } label: {
                        Group {
                            if volviendoAPedir {
                                ProgressView().tint(.white)
                            } else {
                                Text("Volver a pedir")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(TreggaColors.primary, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(volviendoAPedir)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(.bar)
    }

    // MARK: - Volver a pedir

    /// Punto de entrada del botón: si el carrito tiene productos de OTRO
    /// negocio, pide confirmación (mismo mecanismo que `CartStore`) antes de
    /// tocar nada; si no, agrega directo.
    private func volverAPedir(_ detalle: PedidoDetalle) async {
        guard let cart, let negocioId = detalle.negocioId else { return }
        if let actual = cart.negocioId, actual != negocioId {
            reordenPendiente = detalle
            return
        }
        await agregarVigentes(detalle)
    }

    /// Re-consulta los productos vigentes del pedido y agrega al carrito los que
    /// siguen disponibles. Los modificadores originales solo quedan como texto
    /// (sin ids) en `PedidoDetalleItem`, así que v1 agrega el producto base y
    /// avisa al usuario que revise las personalizaciones en el carrito.
    private func agregarVigentes(_ detalle: PedidoDetalle) async {
        guard let catalog = deps?.catalogRepository, let cart, let negocioId = detalle.negocioId else { return }
        volviendoAPedir = true
        defer { volviendoAPedir = false }

        let ids = detalle.items.compactMap(\.productoId)
        let vigentes: [UUID: Producto]
        do {
            vigentes = Dictionary(uniqueKeysWithValues: try await catalog.fetchProductosPorIds(ids).map { ($0.id, $0) })
        } catch {
            vigentes = [:]
        }

        var faltantes: [String] = []
        huboModificadores = detalle.items.contains { !$0.modificadores.isEmpty }

        for item in detalle.items {
            guard let productoId = item.productoId, let producto = vigentes[productoId], producto.isAvailable else {
                faltantes.append(item.nombre)
                continue
            }
            let selection = ProductSelection(producto: producto, cantidad: item.cantidad, modificadores: [], total: producto.precio * Decimal(item.cantidad))
            cart.add(selection: selection, negocioId: negocioId, negocioName: detalle.negocioName)
        }

        if !faltantes.isEmpty || huboModificadores {
            noDisponibles = faltantes
            mostrarResultadoReorden = true
        } else {
            irAlCarrito()
        }
    }

    private func irAlCarrito() {
        shell?.tab = .carrito
        onBack()
    }

    // MARK: - Soporte

    private func reportarProblema(_ detalle: PedidoDetalle) {
        let folio = detalle.orderNumber.isEmpty ? "s/n" : detalle.orderNumber
        let mensaje = "Hola, necesito ayuda con mi pedido \(folio) de \(detalle.negocioName)."
        let digits = TreggaSupport.whatsappE164.filter(\.isNumber)
        guard let encoded = mensaje.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://wa.me/\(digits)?text=\(encoded)"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
