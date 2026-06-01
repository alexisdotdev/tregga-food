import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pantalla de checkout: método de pago + dirección + propina + resumen.
/// Al confirmar muestra HangTight y luego la confirmación con order_number.
struct CheckoutView: View {
    @State private var viewModel: CheckoutViewModel
    /// Llamado al cerrar la confirmación: limpia carrito y vuelve a Inicio.
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(viewModel: CheckoutViewModel, onFinish: @escaping () -> Void) {
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
            case .success(let resultado, let avisoTarjeta):
                OrderSuccessOverlay(
                    resultado: resultado,
                    avisoTarjeta: avisoTarjeta,
                    onDone: onFinish
                )
                .transition(.opacity)
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
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
            } else if viewModel.capturandoDireccion {
                capturaDireccion
            } else {
                ForEach(viewModel.direcciones) { dir in
                    direccionCard(dir)
                }
                Button {
                    withAnimation { viewModel.capturandoDireccion = true; viewModel.direccionSeleccionada = nil }
                } label: {
                    HStack(spacing: 8) {
                        TreggaIcon(.plus, size: 14, color: TreggaColors.text, weight: .bold)
                        Text("Agregar otra dirección")
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
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func direccionCard(_ dir: DireccionCliente) -> some View {
        let selected = viewModel.direccionSeleccionada?.id == dir.id
        return Button {
            withAnimation { viewModel.direccionSeleccionada = dir; viewModel.capturandoDireccion = false }
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

    private var capturaDireccion: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldBox(
                title: "Dirección de entrega",
                placeholder: "Calle, número, colonia",
                text: $viewModel.nuevaDireccionTexto
            )
            fieldBox(
                title: "Referencias (opcional)",
                placeholder: "Casa azul, frente al jardín",
                text: $viewModel.nuevaDireccionReferencias
            )
            if !viewModel.direcciones.isEmpty {
                Button {
                    withAnimation {
                        viewModel.capturandoDireccion = false
                        viewModel.direccionSeleccionada = viewModel.direcciones.first(where: { $0.isDefault }) ?? viewModel.direcciones.first
                    }
                } label: {
                    Text("Usar una dirección guardada")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(TreggaColors.primaryDark)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func fieldBox(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .treggaStyle(.caption)
                .foregroundStyle(TreggaColors.textSec)
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TreggaColors.text)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: TreggaRadius.lg)
                        .stroke(TreggaColors.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Pago

    private var pagoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Método de pago").padding(.horizontal, 16)
            VStack(spacing: 0) {
                ForEach(Array(MetodoPago.allCases.enumerated()), id: \.element.id) { idx, metodo in
                    pagoRow(metodo)
                    if idx < MetodoPago.allCases.count - 1 {
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

    // MARK: - Resumen

    private var resumenSection: some View {
        VStack(spacing: 8) {
            resumenRow("Subtotal", PriceFormat.pesos(viewModel.subtotal))
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
            MotionStripes(color: TreggaColors.primaryDeep, tint: TreggaColors.primarySoft)
                .ignoresSafeArea()
                .opacity(0.4)
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
    let avisoTarjeta: Bool
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
                Text("¡Pedido confirmado!")
                    .treggaStyle(.h2)
                    .foregroundStyle(TreggaColors.text)
                if !resultado.orderNumber.isEmpty {
                    Text("Pedido \(resultado.orderNumber)")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TreggaColors.primaryDark)
                }
                Text("Estamos buscando un repartidor para ti. Te avisaremos cuando lo asignemos.")
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                if avisoTarjeta {
                    HStack(spacing: 8) {
                        TreggaIcon(.info, size: 16, color: TreggaColors.warning)
                        Text("Pago con tarjeta: pasarela en configuración. Coordinaremos el cobro contigo.")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TreggaColors.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                }
                Spacer()
                TreggaButton("Entendido", kind: .primary, height: 56) { onDone() }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
}
