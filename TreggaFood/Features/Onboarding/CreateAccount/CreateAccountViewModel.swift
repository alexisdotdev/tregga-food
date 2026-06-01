import Foundation
import TreggaCore
import Observation

@MainActor
@Observable
public final class CreateAccountViewModel {
    public var fullName: String = ""
    public var email: String = ""
    public var phoneDisplay: String = ""   // formato MX: "443 123 4567"
    public var password: String = ""
    public var newsletterOptIn: Bool = true

    public private(set) var loading = false
    public private(set) var error: String?

    private let authService: AuthService
    public weak var coordinator: OnboardingCoordinator?

    public init(authService: AuthService, coordinator: OnboardingCoordinator?) {
        self.authService = authService
        self.coordinator = coordinator
    }

    public var phoneE164: String {
        "+52" + phoneDisplay.filter(\.isNumber)
    }

    public var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && emailLooksValid(email)
            && phoneDisplay.filter(\.isNumber).count == 10
            && password.count >= 8
    }

    /// Crear cuenta: el camino feliz envía OTP al teléfono y entra a la OTPView.
    /// Si el teléfono ya tiene cuenta cliente, muestra el sheet "¿Eres tú?".
    public func crearCuenta() async {
        guard canSubmit else {
            error = "Completa todos los campos (contraseña de 8+ caracteres)."
            return
        }
        loading = true
        defer { loading = false }
        error = nil

        let e164 = phoneE164
        coordinator?.pendingFullName = fullName.trimmingCharacters(in: .whitespaces)
        coordinator?.pendingEmail = email.trimmingCharacters(in: .whitespaces)
        coordinator?.pendingPhoneE164 = e164

        do {
            // ¿El teléfono ya tiene cuenta? → sheet de match en vez de duplicar.
            if try await authService.phoneIsRegistered(phoneE164: e164) {
                coordinator?.showAccountMatch = true
                return
            }
            try await authService.sendOTP(phoneE164: e164)
            coordinator?.startOTP(.phone(e164: e164))
        } catch let e as AuthError {
            switch e {
            case .invalidPhone: self.error = "Número de teléfono inválido."
            case .rateLimitedSMS: self.error = "Espera un momento antes de reintentar."
            case .networkFailure: self.error = "Sin conexión. Revisa tu internet."
            default: self.error = "No se pudo crear la cuenta. Intenta de nuevo."
            }
        } catch {
            self.error = "No se pudo crear la cuenta. Intenta de nuevo."
        }
    }

    /// Confirmación del sheet "¿Eres tú?": continúa el login con OTP al teléfono.
    public func confirmAccountMatch() async {
        coordinator?.showAccountMatch = false
        loading = true
        defer { loading = false }
        do {
            try await authService.sendOTP(phoneE164: phoneE164)
            coordinator?.startOTP(.phone(e164: phoneE164))
        } catch {
            self.error = "No se pudo enviar el código. Intenta de nuevo."
        }
    }

    private func emailLooksValid(_ s: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return s.range(of: pattern, options: [.caseInsensitive, .regularExpression]) != nil
    }
}
