import SwiftUI
import UIKit

extension View {
    /// Re-habilita el gesto **nativo** de "deslizar para regresar" (el que arrastra
    /// la pantalla siguiendo el dedo) en pantallas que ocultan la barra de
    /// navegación y usan header propio — caso en el que iOS lo desactiva por
    /// defecto. Funciona en pantallas empujadas (push) dentro de un NavigationStack;
    /// en raíces de sheet no hay nada que "popear", así que queda el cierre vertical
    /// nativo del sheet.
    func enableNativeSwipeBack() -> some View {
        background(NativeSwipeBackEnabler().frame(width: 0, height: 0))
    }

    /// Compat: las pantallas ya cableadas con `swipeToGoBack`/`swipeBackToDismiss`
    /// siguen funcionando, pero ahora usan el **pop nativo del sistema**. La acción
    /// explícita ya no es necesaria (el NavigationStack hace el pop y sincroniza su
    /// `path`); se conserva la firma para no tocar los call sites.
    func swipeToGoBack(_ action: @escaping () -> Void) -> some View {
        enableNativeSwipeBack()
    }

    func swipeBackToDismiss() -> some View {
        enableNativeSwipeBack()
    }
}

/// Puente a UIKit: encuentra el `UINavigationController` que hospeda la pantalla y
/// se pone como delegate de su `interactivePopGestureRecognizer` para re-activarlo
/// aun con la nav bar oculta. El check de `viewControllers.count > 1` evita que el
/// gesto se dispare en la raíz (donde no hay a dónde regresar) y previene cuelgues.
private struct NativeSwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Enabler { Enabler() }
    func updateUIViewController(_ uiViewController: Enabler, context: Context) {}

    final class Enabler: UIViewController, UIGestureRecognizerDelegate {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let nav = findNav() else { return }
            nav.interactivePopGestureRecognizer?.delegate = self
            nav.interactivePopGestureRecognizer?.isEnabled = true
        }

        private func findNav() -> UINavigationController? {
            var current: UIViewController? = self
            while let c = current {
                if let nav = c as? UINavigationController { return nav }
                if let nav = c.navigationController { return nav }
                current = c.parent
            }
            return nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let count = (navigationController ?? findNav())?.viewControllers.count ?? 0
            return count > 1
        }
    }
}
