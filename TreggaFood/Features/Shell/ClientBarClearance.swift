import SwiftUI

private struct ClientBottomBarClearance: ViewModifier {
    func body(content: Content) -> some View {
        content.contentMargins(.bottom, 72, for: .scrollContent)
    }
}

extension View {
    /// Reserva el alto de la barra flotante inferior en el contenido scrolleable.
    ///
    /// La barra se hospeda como `safeAreaInset` en `ClientTabView`, pero ese inset
    /// NO se propaga a través de los `NavigationStack` anidados de cada pestaña
    /// (la reserva efectiva es ~0), así que el último elemento queda debajo de la
    /// barra. En iPhone el hueco del home indicator lo disimula, pero en iPad
    /// (la app corre a pantalla completa como "iPhone app on iPad" en iPadOS 26)
    /// el contenido queda tapado — el rechazo de App Store Guideline 4.
    ///
    /// `contentMargins(.scrollContent)` reserva el espacio de forma directa y
    /// consistente en cualquier tamaño (verificado en iPhone 17 Pro y iPad Air 11").
    /// Aplícalo al `ScrollView` raíz de cada pestaña que muestra la barra.
    func clientBottomBarClearance() -> some View {
        modifier(ClientBottomBarClearance())
    }
}
