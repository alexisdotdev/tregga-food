import Foundation
import LocalAuthentication

public enum BiometricKind: Sendable {
    case faceID
    case touchID
    case none
}

/// Wrapper de `LocalAuthentication` para el candado biométrico de la app.
/// Política **solo biometría** (`.deviceOwnerAuthenticationWithBiometrics`): no
/// cae al passcode del dispositivo; si falla, el caller decide (en Tregga: salir
/// a login por OTP/contraseña vía "Usar otra cuenta").
@MainActor
public final class BiometricAuthService {
    public static let shared = BiometricAuthService()
    public init() {}

    /// Tipo de biometría disponible y enrolada. `.none` si no hay o no está configurada.
    public var availableKind: BiometricKind {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch ctx.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    public var isAvailable: Bool { availableKind != .none }

    /// Corre la autenticación biométrica. Devuelve `true` solo si el usuario se
    /// autenticó correctamente; `false` si falló, canceló o no hay biometría.
    public func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "" // sin fallback a passcode: solo biometría
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
