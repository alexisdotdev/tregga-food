import SwiftUI
import TreggaDesignSystem

/// Barra de navegación flotante del cliente (diseño Claude Design):
/// 4 botones circulares + una píldora central "Buscar" que se expande. Al activar
/// Buscar, la píldora colapsa a solo el icono (texto oculto) con una transición y
/// los 5 botones se reparten parejos.
struct ClientBottomBar: View {
    @Binding var tab: ClientTab
    var cartCount: Int

    private let size: CGFloat = 52
    private var searchActive: Bool { tab == .buscar }

    var body: some View {
        HStack(spacing: 6) {
            circle(.home, target: .inicio)
            flexGap
            circle(.pin, target: .live)
            flexGap
            searchPill
            flexGap
            circle(.bag, target: .carrito, badge: cartCount)
            flexGap
            circle(.user, target: .cuenta)
        }
        .padding(.horizontal, 14)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: tab)
    }

    /// Separador que solo reclama espacio cuando la píldora está colapsada, para
    /// repartir los 5 botones de forma pareja; en estado normal es de ancho 0 y la
    /// píldora central ocupa el espacio sobrante.
    private var flexGap: some View {
        Spacer(minLength: 0).frame(maxWidth: searchActive ? .infinity : 0)
    }

    private func circle(_ icon: TreggaIcon.Name, target: ClientTab, badge: Int = 0) -> some View {
        let active = tab == target
        return Button {
            tab = target
        } label: {
            ZStack {
                TreggaIcon(icon, size: 22, color: active ? TreggaColors.primary : TreggaColors.text)
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(TreggaColors.primary, in: Capsule())
                        .overlay(Capsule().stroke(TreggaColors.bg, lineWidth: 2))
                        .offset(x: 16, y: -16)
                }
            }
            .frame(width: size, height: size)
            .background(TreggaColors.card, in: Circle())
            .overlay(Circle().stroke(TreggaColors.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 11, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var searchPill: some View {
        Button {
            tab = .buscar
        } label: {
            HStack(spacing: 8) {
                TreggaIcon(.search, size: 20, color: searchActive ? TreggaColors.primary : TreggaColors.text)
                if !searchActive {
                    Text("Buscar")
                        .font(.system(size: 15.5, weight: .bold))
                        .tracking(-0.1)
                        .foregroundStyle(TreggaColors.text)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }
            .frame(minWidth: searchActive ? size : 0,
                   maxWidth: searchActive ? size : .infinity)
            .frame(height: size)
            .background(TreggaColors.card, in: Capsule())
            .overlay(Capsule().stroke(TreggaColors.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 11, y: 8)
        }
        .buttonStyle(.plain)
    }
}
