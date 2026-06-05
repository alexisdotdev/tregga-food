import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pestaña "Live" (📍): seguimiento del pedido en curso. En la raíz muestra una
/// tarjeta compacta (para no chocar con la barra flotante) que abre el tracking
/// completo; si no hay pedido activo, un estado vacío.
struct LiveTabView: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.clientShell) private var shell

    @State private var path: [LiveRoute] = []
    @State private var clienteId: UUID?
    @State private var activo: PedidoTracking?
    @State private var pedidoEntregado: PedidoTracking?

    enum LiveRoute: Hashable {
        case tracking(pedidoId: UUID)
        case chat(pedidoId: UUID, repartidorName: String)
    }

    private var tracking: TrackingRepository { deps?.trackingRepository ?? MockTrackingRepository() }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let activo {
                    activeCard(activo)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TreggaColors.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) { header }
            .navigationDestination(for: LiveRoute.self) { route in
                destination(for: route)
                    .onAppear { shell?.barHidden = true }
                    .onDisappear { shell?.barHidden = false }
            }
        }
        .task { await load() }
        .fullScreenCover(item: $pedidoEntregado) { pedido in
            DeliveryRatingFlow(
                pedido: pedido,
                clienteId: clienteId,
                repo: deps?.calificacionRepository ?? MockCalificacionRepository(),
                onDone: {
                    pedidoEntregado = nil
                    activo = nil
                    path.removeAll()
                    Task { await load() }
                }
            )
        }
    }

    private var header: some View {
        HStack {
            Text("En curso")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(TreggaColors.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(TreggaColors.bg)
    }

    private func activeCard(_ pedido: PedidoTracking) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { path.append(.tracking(pedidoId: pedido.id)) } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Tag(pedido.status.tagLabel, tone: .soft)
                        Spacer()
                        if let eta = pedido.estimatedDurationMin, !pedido.status.isTerminal {
                            Text("\(eta) min")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(TreggaColors.primary)
                        }
                    }
                    Text(pedido.status.titulo)
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                    Text(pedido.negocioName ?? "Tu pedido")
                        .font(.system(size: 14))
                        .foregroundStyle(TreggaColors.textSec)
                    HStack(spacing: 6) {
                        TreggaIcon(.pin, size: 16, color: TreggaColors.primary)
                        Text("Ver seguimiento en el mapa")
                            .font(.system(size: 14.5, weight: .heavy))
                            .foregroundStyle(TreggaColors.primary)
                        TreggaIcon(.chevR, size: 14, color: TreggaColors.primary)
                    }
                    .padding(.top, 2)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TreggaColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(TreggaColors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(TreggaColors.surface).frame(width: 120, height: 120)
                TreggaIcon(.truck, size: 54, color: TreggaColors.textTer)
            }
            Text("No tienes pedidos en curso")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
            Text("Cuando hagas un pedido, aquí podrás seguir a tu repartidor en el mapa.")
                .font(.system(size: 14.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 44)
            Button { shell?.tab = .inicio } label: {
                Text("Explorar negocios")
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 50)
                    .background(TreggaColors.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.top, 40)
    }

    @ViewBuilder
    private func destination(for route: LiveRoute) -> some View {
        switch route {
        case .tracking(let pedidoId):
            TrackingView(
                viewModel: TrackingViewModel(pedidoId: pedidoId, repo: tracking),
                onChat: { name in path.append(.chat(pedidoId: pedidoId, repartidorName: name)) },
                onCompleted: { pedido in pedidoEntregado = pedido },
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

    private func load() async {
        if clienteId == nil, let deps, let userId = deps.authSession.tokens?.userId {
            clienteId = try? await deps.clienteRepository.fetchByUserId(userId)?.id
        }
        guard let cid = clienteId else { return }
        activo = try? await tracking.fetchPedidoActivo(clienteId: cid)
    }
}
