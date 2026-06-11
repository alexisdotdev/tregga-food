import Foundation
import TreggaCore
import Observation

@MainActor
@Observable
public final class OTPViewModel {
    /// Identifica si la sesión OTP arrancó desde un teléfono (sendOTP) o desde
    /// un correo (sendEmailOTP). Determina qué APIs llamar.
    public enum Kind: Equatable, Sendable {
        case phone(e164: String)
        case email(String)

        public var displayDestination: String {
            switch self {
            case .phone(let e164):
                let last4 = String(e164.suffix(4))
                let mid = e164.suffix(10).prefix(3)
                return "+52 \(mid) ••• \(last4)"
            case .email(let mail):
                return mail
            }
        }
    }

    public var code: String = ""
    public private(set) var attemptsRemaining: Int = 5
    public private(set) var error: String?
    public private(set) var loading = false
    public private(set) var resendCountdown: Int = 60

    public let kind: Kind
    /// Datos que el coordinator usa para `linkOrCreate` al verificar.
    public let fullName: String?

    private let authService: AuthService
    public weak var coordinator: OnboardingCoordinator?

    public init(
        kind: Kind,
        authService: AuthService,
        coordinator: OnboardingCoordinator?,
        fullName: String? = nil
    ) {
        self.kind = kind
        self.authService = authService
        self.coordinator = coordinator
        self.fullName = fullName
    }

    /// El diseño usa OTP de 4 dígitos. En BYPASS_OTP cualquier código de 4
    /// dígitos es válido. El email OTP de Supabase trae 6 dígitos.
    public var expectedDigits: Int {
        switch kind {
        case .phone: return 4
        case .email: return 6
        }
    }

    public var canVerify: Bool {
        code.count == expectedDigits && code.allSatisfy(\.isNumber)
    }

    public var phoneE164: String? {
        if case .phone(let e164) = kind { return e164 }
        return nil
    }

    public var email: String? {
        if case .email(let mail) = kind { return mail }
        return nil
    }

    public func verify() async {
        guard canVerify else { error = "Código incompleto"; return }
        loading = true
        defer { loading = false }
        error = nil
        do {
            let tokens: AuthSession.Tokens
            switch kind {
            case .phone(let e164):
                tokens = try await authService.verifyOTP(phoneE164: e164, code: code)
            case .email(let mail):
                tokens = try await authService.verifyEmailOTP(email: mail, code: code)
            }
            await coordinator?.completeAuth(
                tokens: tokens,
                fullName: fullName,
                email: email,
                phoneE164: phoneE164
            )
        } catch let e as AuthError {
            switch e {
            case .invalidCode:
                attemptsRemaining = max(0, attemptsRemaining - 1)
                self.error = attemptsRemaining > 0
                    ? "Código incorrecto · \(attemptsRemaining) intentos restantes"
                    : "Demasiados intentos. Espera 5 minutos."
            case .tooManyAttempts:
                self.error = "Demasiados intentos. Espera 5 minutos."
            case .networkFailure:
                self.error = "Sin conexión. Revisa tu internet e intenta de nuevo."
            case .weakConnection:
                self.error = "Tu conexión es inestable. Verifica tu señal e intenta de nuevo."
            default:
                self.error = "No se pudo verificar el código."
            }
        } catch {
            self.error = "No se pudo verificar el código."
        }
    }

    public func resend() async {
        guard resendCountdown == 0 else { return }
        error = nil
        do {
            switch kind {
            case .phone(let e164): try await authService.sendOTP(phoneE164: e164)
            case .email(let mail): try await authService.sendEmailOTP(email: mail)
            }
            resendCountdown = 60
        } catch AuthError.weakConnection {
            self.error = "Tu conexión es inestable. Verifica tu señal e intenta de nuevo."
        } catch AuthError.networkFailure {
            self.error = "Sin conexión. Revisa tu internet e intenta de nuevo."
        } catch {
            self.error = "No se pudo reenviar el código."
        }
    }

    public func tickResendCountdown() {
        if resendCountdown > 0 { resendCountdown -= 1 }
    }
}
