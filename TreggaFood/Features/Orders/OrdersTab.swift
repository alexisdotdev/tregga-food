import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Tab "Pedidos": acceso mínimo al pedido en curso (si lo hay) que abre Tracking.
/// El historial completo llega en F5.
struct OrdersTab: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.cartStore) private var cartEnv

    @State private var path: [CatalogRoute] = []
    @State private var pedidoEntregado: PedidoTracking?
    @State private var clienteId: UUID?
    @State private var estado: Estado = .cargando

    enum Estado: Equatable {
        case cargando
        case activo(PedidoTracking)
        case vacio
    }

    private var cart: CartStore { cartEnv ?? CartStore() }
    private var tracking: TrackingRepository { deps?.trackingRepository ?? MockTrackingRepository() }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(TreggaColors.bg)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: CatalogRoute.self) { route in
                    destination(for: route)
                }
        }
        .task { await cargar() }
        .fullScreenCover(item: $pedidoEntregado) { pedido in
            DeliveryRatingFlow(
                pedido: pedido,
                clienteId: clienteId,
                repo: deps?.calificacionRepository ?? MockCalificacionRepository(),
                onDone: {
                    pedidoEntregado = nil
                    path.removeAll()
                    Task { await cargar() }
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch estado {
        case .cargando:
            VStack(spacing: 12) {
                ProgressView()
                Text("Buscando tus pedidos…")
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .activo(let pedido):
            VStack(alignment: .leading, spacing: 0) {
                header
                Button { path.append(.tracking(pedidoId: pedido.id)) } label: {
                    pedidoCard(pedido)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }

        case .vacio:
            VStack(spacing: 12) {
                TreggaIcon(.bag, size: 40, color: TreggaColors.textTer)
                Text("Sin pedidos en curso")
                    .treggaStyle(.h3)
                    .foregroundStyle(TreggaColors.text)
                Text("Cuando hagas un pedido podrás seguirlo en vivo desde aquí.")
                    .treggaStyle(.sub)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TreggaColors.textSec)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        Text("Tus pedidos")
            .treggaStyle(.h2)
            .foregroundStyle(TreggaColors.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }

    private func pedidoCard(_ pedido: PedidoTracking) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: TreggaRadius.md).fill(TreggaColors.primarySoft).frame(width: 48, height: 48)
                TreggaIcon(.bike, size: 22, color: TreggaColors.primaryDark)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(pedido.negocioName ?? "Pedido en curso")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                Tag(pedido.status.tagLabel, tone: .soft)
            }
            Spacer()
            TreggaIcon(.chevR, size: 18, color: TreggaColors.textSec)
        }
        .padding(14)
        .background(TreggaColors.card, in: RoundedRectangle(cornerRadius: TreggaRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: TreggaRadius.xl).stroke(TreggaColors.border, lineWidth: 1))
    }

    @ViewBuilder
    private func destination(for route: CatalogRoute) -> some View {
        switch route {
        case .tracking(let pedidoId):
            TrackingView(
                viewModel: TrackingViewModel(pedidoId: pedidoId, repo: tracking),
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
        default:
            EmptyView()
        }
    }

    private func cargar() async {
        if clienteId == nil, let deps, let userId = deps.authSession.tokens?.userId {
            clienteId = try? await deps.clienteRepository.fetchByUserId(userId)?.id
        }
        guard let clienteId else { estado = .vacio; return }
        do {
            if let activo = try await tracking.fetchPedidoActivo(clienteId: clienteId) {
                estado = .activo(activo)
            } else {
                estado = .vacio
            }
        } catch {
            estado = .vacio
        }
    }
}
