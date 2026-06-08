import UIKit

/// Instala (una sola vez) un tap a nivel de ventana que oculta el teclado al
/// tocar fuera de un campo de texto. Aplica a **toda la app**, incluidas las
/// hojas (sheets) — que se presentan en la misma ventana.
///
/// `cancelsTouchesInView = false` para no bloquear los demás taps de la UI, y un
/// delegate que IGNORA los taps que caen sobre un campo de texto o control: sin
/// esto, el `endEditing` se dispara en el mismo tap que intenta enfocar el campo
/// y obliga a tocar dos veces para abrir el teclado.
@MainActor
enum KeyboardDismiss {
    private static var installed = false
    private static let delegate = IgnoreTextInputDelegate()

    static func install() {
        guard !installed else { return }
        guard let window = keyWindow else {
            // La ventana puede no existir aún al primer intento; reintenta pronto.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { install() }
            return
        }
        let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        tap.delegate = delegate
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

/// No deja que el tap de "ocultar teclado" reciba toques sobre campos de texto o
/// controles: así el primer tap enfoca el campo y abre el teclado sin pelear con
/// el `endEditing`.
private final class IgnoreTextInputDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var view: UIView? = touch.view
        while let current = view {
            if current is UIControl || current is UITextField || current is UITextView {
                return false
            }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
