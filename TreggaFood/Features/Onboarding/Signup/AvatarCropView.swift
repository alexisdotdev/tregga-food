import SwiftUI
import TreggaDesignSystem

/// Envoltorio `Identifiable` para presentar el ajuste de foto vía `fullScreenCover(item:)`.
struct AvatarCropImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Ajuste de la foto de perfil: el usuario arrastra y hace zoom dentro de un
/// marco circular antes de subirla. Devuelve un `UIImage` cuadrado recortado.
struct AvatarCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onDone: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let diameter: CGFloat = 300

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Acomoda tu foto")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                Spacer()

                cropContent
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .frame(width: diameter, height: diameter)
                    .contentShape(Circle())
                    .gesture(SimultaneousGesture(dragGesture, zoomGesture))

                Text("Arrastra y pellizca para acomodar")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 20)

                Spacer()

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancelar")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.4), lineWidth: 1))
                    }
                    Button { onDone(cropped() ?? image) } label: {
                        Text("Usar foto")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(TreggaColors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(TreggaColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var cropContent: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: diameter, height: diameter)
            .clipped()
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                offset = CGSize(
                    width: lastOffset.width + v.translation.width,
                    height: lastOffset.height + v.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in scale = min(max(lastScale * v.magnification, 1), 4) }
            .onEnded { _ in lastScale = scale }
    }

    @MainActor
    private func cropped() -> UIImage? {
        let renderer = ImageRenderer(content: cropContent)
        renderer.scale = 1080 / diameter
        return renderer.uiImage
    }
}
