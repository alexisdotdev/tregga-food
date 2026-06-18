import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Flujo final: celebración de entrega -> calificación del repartidor.
/// Al terminar (`onDone`) se limpia el carrito y se vuelve a Inicio.
struct DeliveryRatingFlow: View {
    let pedido: PedidoTracking
    @State private var viewModel: RatingViewModel
    @State private var mostrandoRating = false
    let onDone: () -> Void

    init(pedido: PedidoTracking, clienteId: UUID?, repo: CalificacionRepository, onDone: @escaping () -> Void) {
        self.pedido = pedido
        _viewModel = State(initialValue: RatingViewModel(pedido: pedido, clienteId: clienteId, repo: repo))
        self.onDone = onDone
    }

    var body: some View {
        Group {
            if mostrandoRating {
                RatingView(viewModel: viewModel, onDone: onDone, onClose: onDone)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                DeliverySuccessView(
                    pedido: pedido,
                    onContinue: { withAnimation(.easeInOut(duration: 0.3)) { mostrandoRating = true } },
                    onSkip: onDone
                )
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Celebración de entrega exitosa.
private struct DeliverySuccessView: View {
    let pedido: PedidoTracking
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TreggaColors.bg.ignoresSafeArea()
            Button(action: onSkip) {
                ZStack {
                    Circle().fill(TreggaColors.surface).frame(width: 36, height: 36)
                    TreggaIcon(.close, size: 18, color: TreggaColors.textSec)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
            .zIndex(1)
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    Circle().fill(TreggaColors.primarySoft).frame(width: 110, height: 110)
                    Circle().fill(TreggaColors.primary).frame(width: 72, height: 72)
                    TreggaIcon(.check, size: 38, color: .white, weight: .bold)
                }
                VStack(spacing: 8) {
                    Text("¡Disfruta tu comida!")
                        .treggaStyle(.h1)
                        .foregroundStyle(TreggaColors.text)
                    Text("Tu pedido de \(pedido.negocioName ?? "el negocio") fue entregado por \(pedido.repartidorName ?? "tu repartidor").")
                        .treggaStyle(.sub)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TreggaColors.textSec)
                        .padding(.horizontal, 36)
                }
                resumen
                Spacer()
                TreggaButton("Calificar entrega", kind: .primary, height: 56) { onContinue() }
                    .padding(.horizontal, 16)
                Button(action: onSkip) {
                    Text("Ahora no")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TreggaColors.textSec)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
        }
    }

    private var resumen: some View {
        VStack(spacing: 10) {
            if !pedido.orderNumber.isEmpty {
                HStack {
                    Text("Pedido")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(TreggaColors.textSec)
                    Spacer()
                    Text(pedido.orderNumber)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                }
            }
            HStack {
                Text("Total")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TreggaColors.textSec)
                Spacer()
                Text(PriceFormat.pesos(pedido.amount))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
            }
        }
        .padding(16)
        .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.xl))
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

/// Calificación del repartidor: estrellas + tags + comentario.
private struct RatingView: View {
    @State var viewModel: RatingViewModel
    let onDone: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    pregunta
                    estrellas
                    tags
                    comentario
                    if case .error(let msg) = viewModel.phase { errorBanner(msg) }
                }
                .padding(.bottom, 160)
            }
            .background(TreggaColors.bg)

            footer
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                ZStack {
                    Circle().fill(.white.opacity(0.95)).frame(width: 36, height: 36)
                    TreggaIcon(.close, size: 18, color: TreggaColors.text)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 30)
            .padding(.trailing, 24)
        }
        .onChange(of: viewModel.phase) { _, phase in
            if phase == .enviado { onDone() }
        }
        .keyboardDismissToolbar()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().fill(.white.opacity(0.95)).frame(width: 48, height: 48)
                TreggaIcon(.check, size: 26, color: TreggaColors.primary, weight: .bold)
            }
            Text("Pedido entregado")
                .treggaStyle(.h2)
                .foregroundStyle(.white)
            Text("Tu pedido de \(viewModel.negocioName) fue entregado por \(viewModel.repartidorName).")
                .treggaStyle(.sub)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [TreggaColors.primary, TreggaColors.primaryDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    private var pregunta: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("¿Cómo estuvo \(viewModel.repartidorName)?")
                .treggaStyle(.h3)
                .foregroundStyle(TreggaColors.text)
            Text("Tu calificación es anónima.")
                .treggaStyle(.sub)
                .foregroundStyle(TreggaColors.textSec)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    private var estrellas: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { i in
                let activa = i <= viewModel.rating
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.rating = i }
                } label: {
                    TreggaIcon(.star, size: 26, color: activa ? TreggaColors.primary : TreggaColors.textTer)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(activa ? TreggaColors.primarySoft : TreggaColors.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(activa ? TreggaColors.primary : TreggaColors.border, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var tags: some View {
        FlowTags(
            tags: viewModel.tagsDisponibles,
            isActive: { viewModel.isTag($0) },
            onTap: { viewModel.toggleTag($0) }
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var comentario: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Comentario (opcional)")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.2)
                .textCase(.uppercase)
                .foregroundStyle(TreggaColors.textSec)
            TextField("¿Algo que quieras compartir?", text: $viewModel.comentario, axis: .vertical)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(TreggaColors.text)
                .lineLimit(2...5)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(TreggaColors.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            TreggaIcon(.info, size: 16, color: TreggaColors.danger)
            Text(msg)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TreggaColors.danger)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TreggaColors.dangerBg, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            TreggaButton(
                viewModel.phase == .enviando ? "Enviando…" : "Enviar calificación",
                kind: .primary,
                height: 56
            ) {
                Task { await viewModel.enviar() }
            }
            .disabled(viewModel.phase == .enviando)
            Button(action: onDone) {
                (Text("¿Quieres pedir lo mismo? ") + Text("Volver a pedir").foregroundColor(TreggaColors.primary).bold())
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(TreggaColors.textSec)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.bar)
    }
}

/// Chips de tags con wrap simple en filas.
private struct FlowTags: View {
    let tags: [String]
    let isActive: (String) -> Bool
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(filas, id: \.self) { fila in
                HStack(spacing: 8) {
                    ForEach(fila, id: \.self) { tag in chip(tag) }
                }
            }
        }
    }

    private var filas: [[String]] {
        stride(from: 0, to: tags.count, by: 2).map { Array(tags[$0..<min($0 + 2, tags.count)]) }
    }

    private func chip(_ tag: String) -> some View {
        let active = isActive(tag)
        return Button { onTap(tag) } label: {
            Text(tag)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(active ? TreggaColors.primaryDark : TreggaColors.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(active ? TreggaColors.primarySoft : TreggaColors.surface, in: Capsule())
                .overlay(Capsule().stroke(active ? TreggaColors.primary : TreggaColors.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
