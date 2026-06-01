import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Tab "Pedidos": historial completo del cliente (F5).
/// En curso arriba, anteriores abajo. Tap → detalle → tracking (F4) / rating.
struct OrdersTab: View {
    @Environment(\.appDependencies) private var deps

    @State private var path: [OrdersRoute] = []
    @State private var viewModel: MyOrdersViewModel?
    @State private var pedidoParaCalificar: PedidoTracking?
    @State private var clienteId: UUID?

    private var pedidoRepo: PedidoRepository { deps?.pedidoRepository ?? MockPedidoRepository() }
    private var tracking: TrackingRepository { deps?.trackingRepository ?? MockTrackingRepository() }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let viewModel {
                    MyOrdersView(viewModel: viewModel) { resumen in
                        path.append(.detalle(pedidoId: resumen.id))
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(TreggaColors.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: OrdersRoute.self) { route in
                destination(for: route)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        .task { await setup() }
        .fullScreenCover(item: $pedidoParaCalificar) { pedido in
            DeliveryRatingFlow(
                pedido: pedido,
                clienteId: clienteId,
                repo: deps?.calificacionRepository ?? MockCalificacionRepository(),
                onDone: {
                    pedidoParaCalificar = nil
                    path.removeAll()
                    Task { await viewModel?.cargar() }
                }
            )
        }
    }

    @ViewBuilder
    private func destination(for route: OrdersRoute) -> some View {
        switch route {
        case .detalle(let pedidoId):
            OrderDetailView(
                viewModel: OrderDetailViewModel(pedidoId: pedidoId, pedidoRepository: pedidoRepo),
                onSeguir: { id in path.append(.tracking(pedidoId: id)) },
                onCalificar: { detalle in pedidoParaCalificar = trackingFrom(detalle) },
                onBack: { if !path.isEmpty { path.removeLast() } }
            )
        case .tracking(let pedidoId):
            TrackingView(
                viewModel: TrackingViewModel(pedidoId: pedidoId, repo: tracking),
                onChat: { name in path.append(.chat(pedidoId: pedidoId, repartidorName: name)) },
                onCompleted: { pedido in pedidoParaCalificar = pedido },
                onBack: { if !path.isEmpty { path.removeLast() } }
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

    private func trackingFrom(_ detalle: PedidoDetalle) -> PedidoTracking {
        PedidoTracking(
            id: detalle.id,
            orderNumber: detalle.orderNumber,
            status: detalle.status,
            repartidorId: detalle.repartidorId,
            repartidorName: detalle.repartidorName,
            negocioName: detalle.negocioName,
            pickup: nil,
            delivery: nil,
            estimatedDurationMin: nil,
            amount: detalle.total
        )
    }

    private func setup() async {
        if viewModel == nil {
            let vm = MyOrdersViewModel(
                clienteRepository: deps?.clienteRepository ?? MockClienteRepository(),
                pedidoRepository: pedidoRepo,
                userId: deps?.authSession.tokens?.userId
            )
            viewModel = vm
        }
        if clienteId == nil, let deps, let userId = deps.authSession.tokens?.userId {
            clienteId = try? await deps.clienteRepository.fetchByUserId(userId)?.id
        }
        await viewModel?.cargar()
    }
}
