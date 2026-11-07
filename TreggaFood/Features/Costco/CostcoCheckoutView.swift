import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Checkout Costco: dirección, desglose con anticipo y condiciones que el cliente debe aceptar.
struct CostcoCheckoutView: View {
    let model: CostcoFlowModel
    let onCreado: (CostcoPedido) -> Void
    let onBack: () -> Void

    @Environment(\.costcoCart) private var cartEnv
    @Environment(\.appDependencies) private var deps
    @State private var clienteId: UUID?
    @State private var direccion: DireccionCliente?
    @State private var showDirecciones = false
    @State private var acepto = false
    @State private var enviando = false
    @State private var error: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CostcoUI.header(CostcoCopy.checkoutTitulo, onBack: onBack)
                    Group {
                        direccionCard
                        if let cart = cartEnv, let config = model.config {
                            desglose(cart.totales(catalogo: model.catalogo, config: config), config: config)
                        }
                        condiciones
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 120)
            }
            TreggaButton(enviando ? CostcoCopy.enviando : CostcoCopy.hacerPedido, kind: .primary, height: 56) {
                Task { await hacerPedido() }
            }
            .disabled(!listo)
            .opacity(listo ? 1 : 0.5)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .background(TreggaColors.bg)
        .toolbar(.hidden, for: .navigationBar)
        .swipeToGoBack { onBack() }
        .task { await cargarDireccion() }
        .sheet(isPresented: $showDirecciones) {
            if let cid = clienteId, let deps {
                DireccionPickerView(
                    viewModel: DireccionPickerViewModel(
                        repo: deps.direccionRepository, clienteId: cid,
                        storage: deps.storageService, userId: deps.authSession.tokens?.userId ?? cid
                    ),
                    onSelected: { Task { await cargarDireccion() } }
                )
            }
        }
        .alert(error ?? "", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var listo: Bool { acepto && direccion != nil && !enviando && model.puedePedir }

    private var direccionCard: some View {
        CostcoUI.card {
            Text(CostcoCopy.entregarEn).font(.system(size: 13, weight: .semibold)).foregroundStyle(TreggaColors.textSec)
            Button { showDirecciones = true } label: {
                HStack(spacing: 10) {
                    TreggaIcon(.pin, size: 20, color: TreggaColors.primaryDark)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(direccion?.label ?? CostcoCopy.elegirDireccion)
                            .font(.system(size: 15, weight: .heavy)).foregroundStyle(TreggaColors.text)
                        if let d = direccion {
                            Text(d.address).font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TreggaColors.textSec).lineLimit(2)
                        }
                    }
                    Spacer()
                    TreggaIcon(.chevR, size: 16, color: TreggaColors.textTer)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func desglose(_ t: CostcoCartStore.Totales, config: CostcoConfig) -> some View {
        CostcoUI.card {
            CostcoUI.row(CostcoCopy.subtotal, PriceFormat.pesos(t.subtotal))
            CostcoUI.row(CostcoCopy.comision(pct: CostcoFormat.pct(config.comisionPct)), PriceFormat.pesos(t.comision))
            CostcoUI.row(CostcoCopy.envio, CostcoCopy.envioIncluido)
            CostcoUI.row(CostcoCopy.totalEstimado, PriceFormat.pesos(t.total))
            TreggaDivider()
            CostcoUI.row(CostcoCopy.anticipoAhora(pct: CostcoFormat.pct(config.anticipoPct)), PriceFormat.pesos(t.anticipo), fuerte: true)
            CostcoUI.row(CostcoCopy.restoAlRecibir, PriceFormat.pesos(t.total - t.anticipo))
        }
    }

    private var condiciones: some View {
        CostcoUI.card {
            ForEach(CostcoCopy.condiciones(cancelarHasta: limiteCancelacion), id: \.self) { linea in
                HStack(alignment: .top, spacing: 8) {
                    TreggaIcon(.checkCircle, size: 16, color: TreggaColors.primaryDark)
                    Text(linea).font(.system(size: 13.5, weight: .medium)).foregroundStyle(TreggaColors.text)
                }
            }
            Button { acepto.toggle() } label: {
                HStack(spacing: 10) {
                    Image(systemName: acepto ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundStyle(acepto ? TreggaColors.primary : TreggaColors.textTer)
                    Text(CostcoCopy.aceptoCondiciones)
                        .font(.system(size: 15, weight: .heavy)).foregroundStyle(TreggaColors.text)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityAddTraits(acepto ? [.isButton, .isSelected] : .isButton)
        }
    }

    /// Antes de crear el pedido aún no hay `limite_cancelacion` del servidor; se muestra el día
    /// (`fecha_viaje − dias_limite_cancelacion`) solo como texto. El pedido creado trae el valor real.
    private var limiteCancelacion: String? {
        guard let viaje = model.estado?.viaje, let config = model.config else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = CostcoFormat.zona
        f.dateFormat = "yyyy-MM-dd"
        guard let dia = f.date(from: viaje.fechaViaje) else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = CostcoFormat.zona
        let limite = cal.date(byAdding: .day, value: -config.diasLimiteCancelacion, to: dia) ?? dia
        // El límite vence al terminar ese día (23:59:59 CDMX).
        guard let finDelDia = cal.date(byAdding: .day, value: 1, to: limite), Date() < finDelDia else { return nil }
        return CostcoFormat.fechaCorta(limite.addingTimeInterval(12 * 3600))
    }

    private func cargarDireccion() async {
        guard let deps, let userId = deps.authSession.tokens?.userId else { return }
        if clienteId == nil { clienteId = try? await deps.clienteRepository.fetchByUserId(userId)?.id }
        guard let clienteId else { return }
        let lista = (try? await deps.direccionRepository.fetchDelCliente(clienteId: clienteId)) ?? []
        direccion = lista.first(where: \.isDefault) ?? lista.first
    }

    private func hacerPedido() async {
        guard let cart = cartEnv, let direccion, !enviando else { return }
        enviando = true
        defer { enviando = false }
        do {
            let pedido = try await model.repo.crearPedido(direccionId: direccion.id, items: cart.solicitudes)
            cart.vaciar()
            onCreado(pedido)
        } catch let e as CostcoError {
            error = e.mensaje
            if case .noEncontrado = e { await model.cargar(cart: cart) }
        } catch {
            self.error = CostcoCopy.errorRed
        }
    }
}
