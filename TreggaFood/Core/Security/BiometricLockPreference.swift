import Foundation

/// Preferencia **local del dispositivo** (NO se sincroniza a la DB ni a otros
/// equipos): si el candado biométrico está activado para esta instalación.
/// La biometría es propia del dispositivo, por eso vive en UserDefaults.
@MainActor
public enum BiometricLockPreference {
    private static let enabledKey = "tregga.biometricLock.enabled"
    private static let promptedKey = "tregga.biometricLock.prompted"

    /// Candado activado para esta instalación.
    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Si ya se ofreció el enrolamiento tras el primer login (para no repetir).
    public static var didPrompt: Bool {
        get { UserDefaults.standard.bool(forKey: promptedKey) }
        set { UserDefaults.standard.set(newValue, forKey: promptedKey) }
    }

    /// Al cerrar sesión por completo conviene olvidar la preferencia para que la
    /// próxima cuenta en este dispositivo no herede el candado.
    public static func reset() {
        isEnabled = false
        didPrompt = false
    }
}
