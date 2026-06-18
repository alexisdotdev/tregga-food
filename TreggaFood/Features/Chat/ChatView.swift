import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Chat in-app con el repartidor: burbujas estilo iMessage, quick replies e input.
struct ChatView: View {
    @State private var viewModel: ChatViewModel
    let repartidorName: String
    let onBack: () -> Void

    init(viewModel: ChatViewModel, repartidorName: String = "tu repartidor", onBack: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.repartidorName = repartidorName
        self.onBack = onBack
    }

    private var iniciales: String {
        let partes = repartidorName.split(separator: " ").prefix(2)
        let i = partes.compactMap { $0.first }.map(String.init).joined()
        return i.isEmpty ? "TG" : i.uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            safetyStrip
            mensajesList
            quickReplies
            inputBar
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .keyboardDismissToolbar()
        .swipeToGoBack(onBack)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                TreggaIcon(.chevL, size: 20, color: TreggaColors.text)
                    .frame(width: 36, height: 36)
                    .background(TreggaColors.surface, in: Circle())
                    .overlay(Circle().stroke(TreggaColors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            ZStack {
                Circle().fill(TreggaColors.primarySoft).frame(width: 42, height: 42)
                Text(iniciales)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(TreggaColors.primaryDark)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(repartidorName)
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                HStack(spacing: 5) {
                    Circle().fill(TreggaColors.primary).frame(width: 7, height: 7)
                    Text("En camino")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TreggaColors.textSec)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(TreggaColors.divider).frame(height: 1)
        }
    }

    private var safetyStrip: some View {
        HStack(spacing: 8) {
            TreggaIcon(.info, size: 14, color: TreggaColors.primaryDark)
            Text("Tu chat es anónimo y privado. No compartas datos sensibles.")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(TreggaColors.primaryDark)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TreggaColors.primarySoft, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var mensajesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.cargando {
                        ProgressView().padding(.top, 40)
                    } else if viewModel.mensajes.isEmpty {
                        Text("Envía el primer mensaje a \(repartidorName).")
                            .treggaStyle(.sub)
                            .foregroundStyle(TreggaColors.textSec)
                            .padding(.top, 40)
                    }
                    ForEach(viewModel.mensajes) { m in
                        bubble(m).id(m.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .onChange(of: viewModel.mensajes.count) { _, _ in
                if let last = viewModel.mensajes.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(_ m: Mensaje) -> some View {
        HStack {
            if m.esMio { Spacer(minLength: 48) }
            VStack(alignment: m.esMio ? .trailing : .leading, spacing: 3) {
                Text(m.content)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(m.esMio ? .white : TreggaColors.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(m.esMio ? TreggaColors.primary : TreggaColors.surface)
                    .clipShape(BubbleShape(esMio: m.esMio))
                Text(horaTexto(m.fecha))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(TreggaColors.textTer)
            }
            if !m.esMio { Spacer(minLength: 48) }
        }
    }

    private var quickReplies: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.quickReplies, id: \.self) { q in
                    Button {
                        Task { await viewModel.enviarRapido(q) }
                    } label: {
                        Text(q)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TreggaColors.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(TreggaColors.bg, in: Capsule())
                            .overlay(Capsule().stroke(TreggaColors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 8)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Mensaje a \(repartidorName)…", text: $viewModel.borrador, axis: .vertical)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TreggaColors.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...4)
            Button {
                Task { await viewModel.enviar() }
            } label: {
                TreggaIcon(.arrow, size: 18, color: .white)
                    .frame(width: 40, height: 40)
                    .background(TreggaColors.primary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.puedeEnviar)
            .opacity(viewModel.puedeEnviar ? 1 : 0.4)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(TreggaColors.divider).frame(height: 1)
        }
        .background(.bar)
    }

    private func horaTexto(_ fecha: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: fecha)
    }
}

/// Burbuja con una esquina inferior recortada del lado del emisor.
private struct BubbleShape: Shape {
    let esMio: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let small: CGFloat = 4
        let topLeft = r
        let topRight = r
        let bottomLeft: CGFloat = esMio ? r : small
        let bottomRight: CGFloat = esMio ? small : r

        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: topLeft, y: 0))
        p.addLine(to: CGPoint(x: w - topRight, y: 0))
        p.addArc(center: CGPoint(x: w - topRight, y: topRight), radius: topRight, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: w, y: h - bottomRight))
        p.addArc(center: CGPoint(x: w - bottomRight, y: h - bottomRight), radius: bottomRight, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: bottomLeft, y: h))
        p.addArc(center: CGPoint(x: bottomLeft, y: h - bottomLeft), radius: bottomLeft, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: 0, y: topLeft))
        p.addArc(center: CGPoint(x: topLeft, y: topLeft), radius: topLeft, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}
