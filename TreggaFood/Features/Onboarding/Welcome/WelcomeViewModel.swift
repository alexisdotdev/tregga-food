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

    /// Método de acceso: código por correo (OTP) o correo + contraseña.
    public enum LoginMethod: Hashable, Sendable { case code, password }

    public var contactInput: String = ""
    public var password: String = ""
    public var method: LoginMethod = .code
    public private(set) var loading = false
    public private(set) var error: String?

    private let authService: AuthService
    public weak var coordinator: OnboardingCoordinator?

    public init(authService: AuthService, coordinator: OnboardingCoordinator?) {
        self.authService = authService
        self.coordinator = coordinator
    }

    public var detectedKind: ContactKind {
        // Login SOLO por correo (el teléfono no es identidad única). Ver
        // IDENTIDAD-Y-LOGIN-reglas.md. Un input tipo teléfono queda inválido.
        let trimmed = contactInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return emailLooksValid(trimmed) ? .email(trimmed) : .invalid
    }

    public var canContinue: Bool {
        if case .invalid = detectedKind { return false }
        return true
    }

    /// Habilita el botón principal: código solo requiere correo; contraseña requiere
    /// correo + contraseña no vacía.
    public var canSubmit: Bool {
        switch method {
        case .code: return canContinue
        case .password: return canContinue && !password.isEmpty
        }
    }

    /// Welcome → login con correo + contraseña. Mismo gate que el OTP (cliente es el
    /// rol base: cualquier cuenta existente entra); `completeAuth` asegura el perfil.
    public func loginConPassword() async throws {
        guard case .email(let email) = detectedKind else {
            error = "Ingresa tu correo electrónico"
            return
        }
        guard !password.isEmpty else {
            error = "Ingresa tu contraseña"
            return
        }
        loading = true
        defer { loading = false }
        error = nil

        coordinator?.pendingEmail = email
        let roles: Set<AccountKind>
        do {
            roles = try await authService.emailAccountRoles(email: email)
        } catch let e as AuthError where e == .weakConnection {
            self.error = "Tu conexión es inestable. Verifica tu señal e intenta de nuevo."
            throw e
        } catch {
            self.error = "No pudimos verificar el correo. Revisa tu conexión e intenta de nuevo."
            throw error
        }
        guard !roles.isEmpty else {
            throw AuthError.accountNotRegistered
        }
        do {
            let tokens = try await authService.signInWithPassword(email: email, password: password)
            await coordinator?.completeAuth(tokens: tokens)
        } catch let e as AuthError where e == .invalidCode {
            self.error = "Correo o contraseña incorrectos."
            throw e
        } catch let e as AuthError where e == .weakConnection {
            self.error = "Tu conexión es inestable. Verifica tu señal e intenta de nuevo."
            throw e
        } catch {
            self.error = "No se pudo iniciar sesión. Intenta de nuevo."
            throw error
        }
    }

    /// Welcome → identificarse. Si la cuenta cliente existe, manda OTP y entra a
    /// la OTPView; si no existe, lanza `accountNotRegistered` para que la View
    /// ofrezca crear cuenta o continuar con Google.
    public func continuar() async throws {
        guard canContinue else {
            error = "Ingresa tu correo electrónico"
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
                case .networkFailure: error = "Sin conexión. Revisa tu internet e intenta de nuevo."
                case .weakConnection: error = "Tu conexión es inestable. Verifica tu señal e intenta de nuevo."
                default: error = "No se pudo enviar el código. Intenta de nuevo"
                }
                throw e
            }

        case .email(let email):
            coordinator?.pendingEmail = email
            let roles: Set<AccountKind>
            do {
                roles = try await authService.emailAccountRoles(email: email)
            } catch let e as AuthError where e == .weakConnection {
                self.error = "Tu conexión es inestable. Verifica tu señal e intenta de nuevo."
                throw e
            } catch {
                self.error = "No pudimos verificar el correo. Revisa tu conexión e intenta de nuevo."
                throw error
            }
            // Cliente es el rol base de Tregga: cualquier cuenta existente (aunque
            // también sea de negocio o repartidor) puede pedir como cliente con el
            // mismo correo. Solo un correo sin cuenta va al registro. `completeAuth`
            // asegura el perfil de cliente (vincular_cliente) tras el OTP.
            guard !roles.isEmpty else {
                throw AuthError.accountNotRegistered
            }
            do {
                try await authService.sendEmailOTP(email: email)
                coordinator?.startOTP(.email(email))
            } catch {
                self.error = "No pudimos enviar el código. Intenta de nuevo."
                throw error
            }

        case .invalid:
            error = "Ingresa tu correo electrónico"
        }
    }

    /// Sign-in nativo con Google: la View obtiene el `idToken` con el SDK y aquí
    /// lo canjeamos con Supabase (`signInWithIdToken`) → `completeAuth`.
    public func continuarConGoogle(idToken: String, accessToken: String?) async throws {
        loading = true
        defer { loading = false }
        error = nil
        do {
            let tokens = try await authService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
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
