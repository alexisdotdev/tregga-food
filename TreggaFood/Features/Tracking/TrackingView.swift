import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pantalla de tracking en vivo: mapa con repartidor + tarjeta flotante con
/// estado, ETA, timeline y acciones (chat / llamar). Polling vía el VM.
struct TrackingView: View {
    @State private var viewModel: TrackingViewModel
    @State private var showCallSheet = false
    @State private var mapController = MapController()
    let onChat: (String) -> Void
    let onCompleted: (PedidoTracking) -> Void
    let onBack: () -> Void

    init(
        viewModel: TrackingViewModel,
        onChat: @escaping (String) -> Void,
        onCompleted: @escaping (PedidoTracking) -> Void,
        onBack: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onChat = onChat
        self.onCompleted = onCompleted
        self.onBack = onBack
    }

    private var repartidorName: String {
        viewModel.pedido?.repartidorName ?? "tu repartidor"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TrackingMapView(
                pickup: viewModel.pedido?.pickup,
                delivery: viewModel.pedido?.delivery,
                repartidor: viewModel.repartidorCoord,
                routeEncoded: viewModel.routeEncoded,
                showRoute: viewModel.pedido?.status.driverHeadingToClient ?? false,
                controller: mapController
            )
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .bottomTrailing) { mapControls }

            backButton

            switch viewModel.phase {
            case .loading:
                loadingCard
            case .error(let msg):
                errorCard(msg)
            case .loaded:
                if let pedido = viewModel.pedido {
                    statusSheet(pedido)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onChange(of: viewModel.didComplete) { _, completed in
            if completed, let pedido = viewModel.pedido {
                onCompleted(pedido)
            }
        }
        .confirmationDialog("Llamar a \(repartidorName)", isPresented: $showCallSheet, titleVisibility: .visible) {
            Button("Por WhatsApp") { abrirWhatsApp() }
            Button("Llamada directa") { abrirLlamada() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Te comunicamos con tu repartidor para coordinar la entrega.")
        }
        .swipeToGoBack(onBack)
    }

    private var backButton: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    TreggaIcon(.chevL, size: 22, color: TreggaColors.text)
                        .frame(width: 40, height: 40)
                        .background(TreggaColors.bg, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Controles del mapa

    private var mapControls: some View {
        VStack(spacing: 8) {
            mapControlButton(icon: "plus") { mapController.zoomIn() }
            mapControlButton(icon: "minus") { mapController.zoomOut() }
            mapControlButton(icon: "location.fill") {
                mapController.recenter(to: [
                    viewModel.pedido?.pickup,
                    viewModel.pedido?.delivery,
                    viewModel.repartidorCoord
                ].compactMap { $0 })
            }
        }
        .padding(.trailing, 14)
        .padding(.bottom, 120)
    }

    private func mapControlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TreggaIcon(sfSymbol: icon, size: 16, color: TreggaColors.text)
                .frame(width: 42, height: 42)
                .treggaGlass(in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status sheet

    private func statusSheet(_ pedido: PedidoTracking) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(TreggaColors.border)
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 6) {
                Tag(pedido.status.tagLabel, tone: .soft)
                if let eta = pedido.estimatedDurationMin, !pedido.status.isTerminal {
                    (Text("Llega en ") + Text("\(eta) min").foregroundColor(TreggaColors.primary))
                        .treggaStyle(.h2)
                        .foregroundStyle(TreggaColors.text)
                } else {
                    Text(pedido.status.titulo)
                        .treggaStyle(.h2)
                        .foregroundStyle(TreggaColors.text)
                }
                Text(subtitulo(pedido))
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)

            timeline(pedido.status.stepIndex)
                .padding(.top, 16)

            TreggaDivider().padding(.vertical, 14)

            courierRow(pedido)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
        .background(
            TreggaColors.bg
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
    }

    private func subtitulo(_ pedido: PedidoTracking) -> String {
        let nombre = pedido.repartidorName ?? "Tu repartidor"
        let negocio = pedido.negocioName ?? "el negocio"
        switch pedido.status {
        case .pending:    return "Estamos asignando un repartidor a tu pedido."
        case .assigned:   return "\(nombre) va en camino a \(negocio)."
        case .enRecogida: return "\(nombre) está recogiendo tu pedido en \(negocio)."
        case .recogido:   return "\(nombre) ya tiene tu pedido y sale hacia ti."
        case .enEntrega:  return "\(nombre) ya pasó por tu pedido en \(negocio)."
        case .completed:  return "¡Tu pedido fue entregado! Buen provecho."
        case .cancelled:  return "Este pedido fue cancelado."
        }
    }

    private func timeline(_ step: Int) -> some View {
        let etapas = ["Confirmado", "Preparando", "En camino", "Entregado"]
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? TreggaColors.primary : TreggaColors.surface2)
                        .frame(height: 5)
                        .opacity(i == step ? 0.6 : 1)
                }
            }
            HStack {
                ForEach(Array(etapas.enumerated()), id: \.offset) { i, label in
                    Text(label)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(i <= step ? TreggaColors.text : TreggaColors.textTer)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func courierRow(_ pedido: PedidoTracking) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(TreggaColors.primarySoft).frame(width: 52, height: 52)
                Text(pedido.repartidorIniciales)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(TreggaColors.primaryDark)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(pedido.repartidorName ?? "Asignando…")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                HStack(spacing: 4) {
                    TreggaIcon(.star, size: 12, color: TreggaColors.warning)
                    Text("Tu repartidor de Tregga")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TreggaColors.textSec)
                }
            }
            Spacer()
            Button { onChat(pedido.repartidorName ?? "tu repartidor") } label: {
                TreggaIcon(.message, size: 18, color: TreggaColors.text)
                    .frame(width: 44, height: 44)
                    .background(TreggaColors.surface, in: Circle())
                    .overlay(Circle().stroke(TreggaColors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Button { showCallSheet = true } label: {
                TreggaIcon(.phone, size: 18, color: .white)
                    .frame(width: 44, height: 44)
                    .background(TreggaColors.primary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(pedido.repartidorId == nil)
            .opacity(pedido.repartidorId == nil ? 0.4 : 1)
        }
    }

    // MARK: - States

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large).tint(TreggaColors.primaryDark)
            Text("Cargando tu pedido…")
                .treggaStyle(.sub)
                .foregroundStyle(TreggaColors.textSec)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(TreggaColors.bg.clipShape(RoundedRectangle(cornerRadius: 24)).ignoresSafeArea(edges: .bottom))
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(spacing: 14) {
            TreggaIcon(.info, size: 36, color: TreggaColors.textTer)
            Text(msg)
                .treggaStyle(.sub)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 32)
            TreggaButton("Reintentar", kind: .secondary, isFullWidth: false) {
                viewModel.reintentar()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(TreggaColors.bg.clipShape(RoundedRectangle(cornerRadius: 24)).ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Acciones de llamada

    private func abrirWhatsApp() {
        let digits = (viewModel.repartidorPhone ?? "").filter(\.isNumber)
        guard !digits.isEmpty, let url = URL(string: "https://wa.me/\(digits)"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    private func abrirLlamada() {
        let cleaned = (viewModel.repartidorPhone ?? "").filter { $0.isNumber || $0 == "+" }
        guard !cleaned.isEmpty, let url = URL(string: "tel://\(cleaned)"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
