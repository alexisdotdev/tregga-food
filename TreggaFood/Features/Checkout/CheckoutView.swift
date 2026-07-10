import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pantalla de checkout: método de pago + dirección + propina + resumen.
/// Al confirmar muestra HangTight y luego la confirmación con order_number.
struct CheckoutView: View {
    @State private var viewModel: CheckoutViewModel
    @State private var showPicker = false
    /// Llamado al cerrar la confirmación: navega al tracking del pedido creado.
    let onFinish: (ResultadoPedido) -> Void
    @Environment(\.dismiss) private var dismiss

    init(viewModel: CheckoutViewModel, onFinish: @escaping (ResultadoPedido) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            content
            switch viewModel.phase {
            case .confirming:
                HangTightOverlay()
                    .transition(.opacity)
            case .success(let resultado):
                OrderSuccessOverlay(
                    resultado: resultado,
                    onDone: { onFinish(resultado) }
                )
                .transition(.opacity)
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .keyboardDismissToolbar()
        .task { await viewModel.load() }
        .alert("Algo salió mal", isPresented: Binding(
            get: { viewModel.errorCarga != nil }, set: { if !$0 { viewModel.clearErrorCarga() } }
        )) {
            Button("Reintentar") { Task { await viewModel.load() } }
            Button("Cerrar", role: .cancel) {}
        } message: {
            Text(viewModel.errorCarga ?? "")
        }
        .fullScreenCover(isPresented: $showPicker) {
            LocationPickerView(center: viewModel.centroInicial) { label, address, refs, instrucciones, fotosData, _, place in
                Task {
                    await viewModel.crearConUbicacion(
                        label: label, address: address, referencias: refs,
                        instrucciones: instrucciones, fotosData: fotosData, place: place
                    )
                }
            }
        }
        .swipeBackToDismiss()
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    direccionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    pagoSection
                        .padding(.top, 16)
                    propinaSection
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                    cuponSection
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                    TreggaDivider().padding(.vertical, 16)
                    resumenSection
                        .padding(.horizontal, 16)
                    if case .error(let msg) = viewModel.phase {
                        errorBanner(msg)
                    }
                }
                .padding(.bottom, 120)
            }
            .background(TreggaColors.bg)

            cta
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                TreggaIcon(.chevL, size: 18, color: TreggaColors.text)
                    .frame(width: 36, height: 36)
                    .background(TreggaColors.surface, in: Circle())
            }
            .buttonStyle(.plain)
            Text("Confirmar pedido")
                .treggaStyle(.h3)
                .foregroundStyle(TreggaColors.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Dirección

    @ViewBuilder
    private var direccionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Entregar en")
            if viewModel.cargandoDirecciones {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                ForEach(viewModel.direcciones) { dir in
                    direccionCard(dir)
                }
                Button { showPicker = true } label: {
                    HStack(spacing: 8) {
                        TreggaIcon(.plus, size: 14, color: TreggaColors.text, weight: .bold)
                        Text(viewModel.direcciones.isEmpty ? "Agregar dirección de entrega" : "Agregar otra dirección")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(TreggaColors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: TreggaRadius.lg)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .foregroundStyle(TreggaColors.border)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func direccionCard(_ dir: DireccionCliente) -> some View {
        let selected = viewModel.direccionSeleccionada?.id == dir.id
        return Button {
            withAnimation { viewModel.direccionSeleccionada = dir }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                TreggaIcon(.pin, size: 20, color: selected ? TreggaColors.primaryDark : TreggaColors.text)
                    .frame(width: 38, height: 38)
                    .background(selected ? TreggaColors.primarySoft : TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(dir.label)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(TreggaColors.text)
                        if dir.isDefault { Tag("Principal", tone: .soft) }
                    }
                    Text(dir.address)
                        .treggaStyle(.sub)
                        .foregroundStyle(TreggaColors.textSec)
                    if !dir.detalleLine.isEmpty {
                        Text(dir.detalleLine)
                            .treggaStyle(.caption)
                            .foregroundStyle(TreggaColors.textTer)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    TreggaIcon(.check, size: 18, color: TreggaColors.primary, weight: .bold)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: TreggaRadius.xl)
                    .fill(selected ? TreggaColors.primarySoft : TreggaColors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TreggaRadius.xl)
                    .stroke(selected ? TreggaColors.primary : TreggaColors.border, lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pago

    private var pagoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Método de pago").padding(.horizontal, 16)
            VStack(spacing: 0) {
                ForEach(Array(MetodoPago.seleccionables.enumerated()), id: \.element.id) { idx, metodo in
                    pagoRow(metodo)
                    if idx < MetodoPago.seleccionables.count - 1 {
                        Divider().background(TreggaColors.divider).padding(.leading, 62)
                    }
                }
            }
            .background(TreggaColors.card, in: RoundedRectangle(cornerRadius: TreggaRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: TreggaRadius.xl).stroke(TreggaColors.border, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    private func pagoRow(_ metodo: MetodoPago) -> some View {
        let selected = viewModel.metodoPago == metodo
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { viewModel.metodoPago = metodo }
        } label: {
            HStack(spacing: 14) {
                TreggaIcon(icon(for: metodo), size: 18, color: TreggaColors.text)
                    .frame(width: 36, height: 36)
                    .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
                VStack(alignment: .leading, spacing: 2) {
                    Text(metodo.titulo)
                        .font(.system(size: 14.5, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                    Text(metodo.subtitulo)
                        .treggaStyle(.caption)
                        .foregroundStyle(TreggaColors.textSec)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(selected ? TreggaColors.primary : TreggaColors.border, lineWidth: 2)
                        .background(Circle().fill(selected ? TreggaColors.primary : .clear))
                        .frame(width: 22, height: 22)
                    if selected { TreggaIcon(.check, size: 12, color: .white, weight: .bold) }
                }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func icon(for metodo: MetodoPago) -> TreggaIcon.Name {
        switch metodo {
        case .efectivo:      return .cash
        case .transferencia: return .wallet
        case .tarjeta:       return .card
        }
    }

    // MARK: - Propina

    private var propinaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Propina para tu repartidor")
            HStack(spacing: 8) {
                ForEach(viewModel.opcionesPropina, id: \.self) { valor in
                    propinaChip(label: valor == 0 ? "Sin propina" : "$\(NSDecimalNumber(decimal: valor).intValue)", valor: valor)
                }
                propinaCustomChip
            }
        }
    }

    private func propinaChip(label: String, valor: Decimal) -> some View {
        let selected = viewModel.propinaPersonalizada.isEmpty && viewModel.propina == valor
        return Button {
            withAnimation { viewModel.seleccionarPropina(valor) }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(selected ? TreggaColors.primaryDark : TreggaColors.text)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selected ? TreggaColors.primarySoft : TreggaColors.bg, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: TreggaRadius.md)
                        .stroke(selected ? TreggaColors.primary : TreggaColors.border, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var propinaCustomChip: some View {
        let active = !viewModel.propinaPersonalizada.isEmpty
        return HStack(spacing: 2) {
            Text("$")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TreggaColors.textSec)
            TextField("Otra", text: $viewModel.propinaPersonalizada)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TreggaColors.text)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(active ? TreggaColors.primarySoft : TreggaColors.bg, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: TreggaRadius.md)
                .stroke(active ? TreggaColors.primary : TreggaColors.border, lineWidth: 1.5)
        )
    }

    // MARK: - Cupón

    private var cuponSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("¿Tienes un cupón?")
            if let aplicado = viewModel.codigoAplicado {
                HStack(spacing: 8) {
                    TreggaIcon(.tag, size: 15, color: TreggaColors.primary)
                    Text(aplicado.uppercased())
                        .font(.system(size: 14.5, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                    Spacer()
                    Button("Quitar") { Task { await viewModel.quitarCodigo() } }
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(TreggaColors.danger)
                }
                .padding(14)
                .background(TreggaColors.primarySoft, in: RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 8) {
                    TextField("Código de cupón", text: $viewModel.codigoInput)
                        .font(.system(size: 14.5, weight: .semibold))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .padding(.horizontal, 14).frame(height: 46)
                        .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: 12))
                    Button {
                        Task { await viewModel.aplicarCodigo() }
                    } label: {
                        Group {
                            if viewModel.aplicandoCodigo { ProgressView().tint(.white) }
                            else { Text("Aplicar").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white) }
                        }
                        .frame(width: 92, height: 46)
                        .background(
                            viewModel.codigoInput.trimmingCharacters(in: .whitespaces).isEmpty
                                ? TreggaColors.primary.opacity(0.4) : TreggaColors.primary,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .disabled(viewModel.codigoInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.aplicandoCodigo)
                }
                if let err = viewModel.codigoError {
                    Text(err)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TreggaColors.danger)
                }
            }
        }
    }

    // MARK: - Resumen

    private var resumenSection: some View {
        VStack(spacing: 8) {
            resumenRow("Subtotal", PriceFormat.pesos(viewModel.subtotal))
            if viewModel.descuento > 0 {
                HStack {
                    HStack(spacing: 5) {
                        TreggaIcon(.tag, size: 13, color: TreggaColors.primary)
                        Text(viewModel.promoTitulo ?? "Descuento")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TreggaColors.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("−\(PriceFormat.pesos(viewModel.descuento))")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(TreggaColors.primary)
                }
            }
            resumenRow("Envío", PriceFormat.pesos(viewModel.deliveryFee))
            resumenRow("Propina", PriceFormat.pesos(viewModel.propinaEfectiva))
            HStack {
                Text("Total")
                    .treggaStyle(.h3)
                    .foregroundStyle(TreggaColors.text)
                Spacer()
                Text(PriceFormat.pesos(viewModel.total))
                    .treggaStyle(.h3)
                    .foregroundStyle(TreggaColors.text)
            }
            .padding(.top, 4)
        }
    }

    private func resumenRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TreggaColors.textSec)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TreggaColors.text)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            TreggaIcon(.info, size: 16, color: TreggaColors.danger)
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TreggaColors.danger)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TreggaColors.dangerBg, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var cta: some View {
        VStack(spacing: 0) {
            TreggaButton(
                "Confirmar pedido · \(PriceFormat.pesos(viewModel.total))",
                kind: .primary,
                height: 56
            ) {
                Task { await viewModel.confirmar() }
            }
            .opacity(viewModel.puedeConfirmar ? 1 : 0.5)
            .disabled(!viewModel.puedeConfirmar)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.bar)
    }
}

/// Etiqueta de sección en mayúsculas.
private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.3)
            .textCase(.uppercase)
            .foregroundStyle(TreggaColors.textSec)
    }
}

/// Overlay "Un momento…" mientras se crea el pedido.
private struct HangTightOverlay: View {
    var body: some View {
        ZStack {
            TreggaColors.primarySoft.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(TreggaColors.primaryDark)
                Text("Un momento…")
                    .treggaStyle(.h2)
                    .foregroundStyle(TreggaColors.text)
                Text("Estamos confirmando tu pedido con el negocio")
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

/// Confirmación de pedido creado: order_number + aviso tarjeta + "Entendido".
private struct OrderSuccessOverlay: View {
    let resultado: ResultadoPedido
    let onDone: () -> Void

    var body: some View {
        ZStack {
            TreggaColors.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                ZStack {
                    Circle().fill(TreggaColors.primarySoft).frame(width: 96, height: 96)
                    TreggaIcon(.check, size: 44, color: TreggaColors.primary, weight: .bold)
                }
                Text("¡Pedido enviado!")
                    .treggaStyle(.h2)
                    .foregroundStyle(TreggaColors.text)
                if !resultado.orderNumber.isEmpty {
                    Text("Pedido \(resultado.orderNumber)")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TreggaColors.primaryDark)
                }
                Text("Estamos confirmando tu pedido con el negocio. Te avisaremos en cuanto lo acepte y busquemos un repartidor.")
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                Spacer()
                TreggaButton("Seguir mi pedido", kind: .primary, height: 56) { onDone() }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
}
