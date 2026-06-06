import UIKit

/// Instala (una sola vez) un tap a nivel de ventana que oculta el teclado al
/// tocar fuera de un campo de texto. Aplica a **toda la app**, incluidas las
/// hojas (sheets) — que se presentan en la misma ventana.
///
/// `cancelsTouchesInView = false` para no bloquear los demás taps de la UI.
@MainActor
enum KeyboardDismiss {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        guard let window = keyWindow else {
            // La ventana puede no existir aún al primer intento; reintenta pronto.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { install() }
            return
        }
        let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        window.addGestureRecognizer(tap)
        installed = true
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
