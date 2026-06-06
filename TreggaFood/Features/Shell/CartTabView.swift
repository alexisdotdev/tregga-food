import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pestaña "Carritos" (estilo Uber Eats): encabezado con título + acceso a
/// "Pedidos" (historial) arriba a la derecha, y el carrito activo abajo. Hospeda
/// el flujo Carrito → Checkout → Tracking → calificación (movido desde Home).
struct CartTabView: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.cartStore) private var cartEnv
    @Environment(\.clientShell) private var shell

    @State private var path: [CartRoute] = []
    @State private var clienteId: UUID?
    @State private var showPedidos = false
    @State private var pedidoEntregado: PedidoTracking?

    private var cart: CartStore { cartEnv ?? CartStore() }

    enum CartRoute: Hashable {
        case checkout
        case tracking(pedidoId: UUID)
        case chat(pedidoId: UUID, repartidorName: String)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if cart.isEmpty {
                    emptyState
                } else {
                    CartView(
                        cart: cart,
                        onCheckout: { path.append(.checkout) },
                        onClose: { shell?.tab = .inicio }
                    )
                }
            }
            .background(TreggaColors.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                // Con productos, CartView muestra su propio header (✕ + negocio);
                // evitamos el doble header mostrando "Carritos/Pedidos" solo vacío.
                if cart.isEmpty { headerBar }
            }
            .navigationDestination(for: CartRoute.self) { route in
                destination(for: route)
            }
            .onChange(of: path) { _, p in shell?.setDeep(.carrito, deep: !p.isEmpty) }
        }
        .task { await resolveCliente() }
        .sheet(isPresented: $showPedidos) {
            OrdersTab()
        }
        .fullScreenCover(item: $pedidoEntregado) { pedido in
            DeliveryRatingFlow(
                pedido: pedido,
                clienteId: clienteId,
                repo: deps?.calificacionRepository ?? MockCalificacionRepository(),
                onDone: {
                    pedidoEntregado = nil
                    cart.clear()
                    path.removeAll()
                }
            )
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center) {
            Text("Carritos")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(TreggaColors.text)
            Spacer()
            Button { showPedidos = true } label: {
                HStack(spacing: 7) {
                    TreggaIcon(.receipt, size: 17, color: TreggaColors.text)
                    Text("Pedidos")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(TreggaColors.surface, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(TreggaColors.bg)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            ZStack {
                Circle().fill(TreggaColors.primarySoft).frame(width: 132, height: 132)
                TreggaIcon(.bag, size: 60, color: TreggaColors.primary)
            }
            Spacer().frame(height: 28)
            Text("Agrega artículos para\ncomenzar a llenar un carrito")
                .font(.system(size: 21, weight: .heavy))
                .tracking(-0.3)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.text)
            Spacer().frame(height: 12)
            Text("Cuando agregues artículos de un restaurante o negocio, tu carrito aparecerá aquí.")
                .font(.system(size: 14.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 44)
            Spacer().frame(height: 28)
            Button { shell?.tab = .inicio } label: {
                Text("Comprar ahora")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(TreggaColors.bg)
                    .padding(.horizontal, 28)
                    .frame(height: 52)
                    .background(TreggaColors.text, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cart flow

    @ViewBuilder
    private func destination(for route: CartRoute) -> some View {
        switch route {
        case .checkout:
            CheckoutView(
                viewModel: CheckoutViewModel(
                    cart: cart,
                    clienteId: clienteId ?? UUID(),
                    pedidoRepo: deps?.pedidoRepository ?? MockPedidoRepository(),
                    direccionRepo: deps?.direccionRepository ?? MockDireccionClienteRepository()
                ),
                onFinish: { resultado in
                    cart.clear()
                    path = [.tracking(pedidoId: resultado.id)]
                }
            )
        case .tracking(let pedidoId):
            TrackingView(
                viewModel: TrackingViewModel(
                    pedidoId: pedidoId,
                    repo: deps?.trackingRepository ?? MockTrackingRepository()
                ),
                onChat: { name in path.append(.chat(pedidoId: pedidoId, repartidorName: name)) },
                onCompleted: { pedido in pedidoEntregado = pedido },
                onBack: { path.removeAll() }
            )
        case .chat(let pedidoId, let repartidorName):
            ChatView(
                viewModel: ChatViewModel(
                    pedidoId: pedidoId,
                    senderId: deps?.authSession.tokens?.userId,
                    repo: deps?.mensajeRepository ?? MockMensajeRepository()
                ),
                repartidorName: repartidorName,
                onBack: { if !path.isEmpty { path.removeLast() } }
            )
        }
    }

    private func resolveCliente() async {
        guard clienteId == nil, let deps,
              let userId = deps.authSession.tokens?.userId else { return }
        clienteId = try? await deps.clienteRepository.fetchByUserId(userId)?.id
    }
}
