import UIKit
import UserNotifications

#if canImport(FirebaseCore) && canImport(FirebaseMessaging)
import FirebaseCore
import FirebaseMessaging

/// AppDelegate mínimo para FCM: inicializa Firebase, registra APNs y entrega el
/// token FCM al `PushTokenCoordinator`. Enganchado en `TreggaFoodApp` vía
/// `@UIApplicationDelegateAdaptor`.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        // Proveedor de token para que onLogin pueda pedirlo directo (sin depender
        // de que el callback didReceiveRegistrationToken se dispare este arranque).
        PushTokenCoordinator.shared.fetchToken = { try? await Messaging.messaging().token() }
        application.registerForRemoteNotifications()
        return true
    }

    /// Bloquea la app a vertical en TODOS los dispositivos. La clave de Info.plist
    /// `UISupportedInterfaceOrientations~ipad` NO se respeta cuando iPadOS corre la
    /// app como "Designed for iPhone" (la app gira con el iPad y el layout vertical
    /// se ve rotado/roto). Este método sí manda en runtime.
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] APNs registration falló: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { await PushTokenCoordinator.shared.onTokenRefresh(token) }
    }

    // Mostrar el banner aunque la app esté en foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

#else

/// Fallback mientras el paquete FirebaseMessaging no esté agregado al target.
/// Mantiene los banners en foreground; el token FCM queda inactivo hasta que se
/// agregue el SPM de Firebase (entonces se compila la rama de arriba sin más cambios).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Bloquea la app a vertical en todos los dispositivos (ver rama FCM arriba).
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

#endif
