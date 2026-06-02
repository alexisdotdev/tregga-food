import Foundation
import TreggaCore
import Observation

@MainActor
@Observable
public final class WelcomeViewModel {
    public enum ContactKind: Equatable, Sendable {
        case phone(e164: String)
        case email(String)
        case invalid
    }

    public var contactInput: String = ""
    public private(set) var loading = false
    public private(set) var error: String?

    private let authService: AuthService
    public weak var coordinator: OnboardingCoordinator?

    public init(authService: AuthService, coordinator: OnboardingCoordinator?) {
        self.authService = authService
        self.coordinator = coordinator
    }

    public var detectedKind: ContactKind {
        let trimmed = contactInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") {
            return emailLooksValid(trimmed) ? .email(trimmed) : .invalid
        }
        let digits = trimmed.filter(\.isNumber)
        if digits.count == 10 { return .phone(e164: "+52\(digits)") }
        return .invalid
    }

    public var canContinue: Bool {
        if case .invalid = detectedKind { return false }
        return true
    }

    /// Welcome → identificarse. Si la cuenta cliente existe, manda OTP y entra a
    /// la OTPView; si no existe, lanza `accountNotRegistered` para que la View
    /// ofrezca crear cuenta o continuar con Google.
    public func continuar() async throws {
        guard canContinue else {
            error = "Ingresa un teléfono (10 dígitos) o correo válido"
            return
        }
        loading = true
        defer { loading = false }
        error = nil

        switch detectedKind {
        case .phone(let e164):
            do {
                let registered = try await authService.phoneIsRegistered(phoneE164: e164)
                guard registered else {
                    coordinator?.pendingPhoneE164 = e164
                    throw AuthError.accountNotRegistered
                }
                try await authService.sendOTP(phoneE164: e164)
                coordinator?.pendingPhoneE164 = e164
                coordinator?.startOTP(.phone(e164: e164))
            } catch let e as AuthError {
                switch e {
                case .invalidPhone: error = "Número inválido"
                case .rateLimitedSMS: error = "Espera un momento antes de reintentar"
                case .accountNotRegistered: error = nil
                default: error = "No se pudo enviar el código. Intenta de nuevo"
                }
                throw e
            }

        case .email(let email):
            coordinator?.pendingEmail = email
            let kind: AccountKind
            do {
                kind = try await authService.emailAccountKind(email: email)
            } catch {
                self.error = "No pudimos verificar el correo. Revisa tu conexión e intenta de nuevo."
                throw error
            }
            switch kind {
            case .repartidor, .other:
                // Cuenta existente con ese correo → login por OTP de correo.
                // (En la app de cliente cualquier rol existente entra por OTP.)
                do {
                    try await authService.sendEmailOTP(email: email)
                    coordinator?.startOTP(.email(email))
                } catch {
                    self.error = "No pudimos enviar el código. Intenta de nuevo."
                    throw error
                }
            case .none:
                throw AuthError.accountNotRegistered
            }

        case .invalid:
            error = "Ingresa un teléfono (10 dígitos) o correo válido"
        }
    }

    public func continuarConGoogle(launchFlow: @escaping OAuthLaunchFlow) async throws {
        loading = true
        defer { loading = false }
        error = nil
        do {
            let tokens = try await authService.signInWithGoogle(launchFlow: launchFlow)
            await coordinator?.completeAuth(tokens: tokens)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            self.error = "No se pudo iniciar sesión con Google."
            throw error
        }
    }

    public func irACrearCuenta() {
        coordinator?.goToSignup()
    }

    private func emailLooksValid(_ s: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return s.range(of: pattern, options: [.caseInsensitive, .regularExpression]) != nil
    }
}
