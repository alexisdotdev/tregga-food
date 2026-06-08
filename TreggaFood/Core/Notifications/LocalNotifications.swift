import Foundation
import UserNotifications

/// Notificaciones locales del cliente (sin servidor/FCM). Hoy solo se usa para
/// avisar de la aproximación del repartidor durante el tracking.
@MainActor
enum LocalNotifications {

    /// Pide permiso de notificaciones (idempotente: iOS no re-pregunta si ya hay
    /// decisión). Silencioso ante rechazo.
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    /// Dispara el aviso "tu repartidor está llegando". Entrega inmediata
    /// (trigger nil). El identifier por pedido evita duplicados del sistema.
    static func fireProximity(pedidoId: UUID, repartidorName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Tu repartidor está llegando"
        content.body = "\(repartidorName ?? "Tu repartidor") está a unos metros de tu domicilio."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "proximity-\(pedidoId.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
