import SwiftUI

// Wrapper compartido para glassEffect (iOS 26+) con fallback a .ultraThinMaterial.
// El deployment target sigue siendo iOS 18; cuando se suba se puede borrar el branch de fallback.
extension View {
    @ViewBuilder
    func treggaGlass<S: Shape>(tint: Color? = nil, in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                self.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            self.background(shape.fill(.ultraThinMaterial))
        }
    }
}
