import SwiftUI
import TreggaDesignSystem

/// Barra de navegación flotante del cliente (diseño Claude Design):
/// 4 botones circulares + una píldora central "Buscar" que se expande.
/// `Inicio · Live · [Buscar] · Carrito(badge) · Cuenta`.
struct ClientBottomBar: View {
    @Binding var tab: ClientTab
    var cartCount: Int

    private let height: CGFloat = 52

    var body: some View {
        HStack(spacing: 6) {
            circle(.home, target: .inicio)
            circle(.pin, target: .live)
            searchPill
            circle(.bag, target: .carrito, badge: cartCount)
            circle(.user, target: .cuenta)
        }
        .padding(.horizontal, 14)
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
            .frame(width: height, height: height)
            .background(TreggaColors.card, in: Circle())
            .overlay(Circle().stroke(TreggaColors.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 11, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var searchPill: some View {
        let active = tab == .buscar
        return Button {
            tab = .buscar
        } label: {
            HStack(spacing: 8) {
                TreggaIcon(.search, size: 20, color: active ? TreggaColors.primary : TreggaColors.text)
                Text("Buscar")
                    .font(.system(size: 15.5, weight: .bold))
                    .tracking(-0.1)
                    .foregroundStyle(active ? TreggaColors.primary : TreggaColors.text)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(TreggaColors.card, in: Capsule())
            .overlay(Capsule().stroke(TreggaColors.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 11, y: 8)
        }
        .buttonStyle(.plain)
    }
}
