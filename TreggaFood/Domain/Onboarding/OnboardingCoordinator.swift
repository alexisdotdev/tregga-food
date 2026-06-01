import Foundation
import TreggaCore
import Observation

/// Coordina el flujo de onboarding/auth de Tregga Food (cliente).
///
/// El cliente no tiene checklist/INE/vehículo: solo se identifica (teléfono o
/// correo → OTP) o crea cuenta, y al terminar se crea/enlaza el `cliente`.
/// Tras obtener tokens persiste la sesión, llama `clienteRepository.linkOrCreate`
/// y notifica al ContentView vía `onAuthenticated` para pasar a `.authenticated`.
@MainActor
@Observable
public final class OnboardingCoordinator {

    public enum Destination: Equatable, Sendable {
        case welcome
        case createAccount
        case otp(OTPViewModel.Kind)
        case permissionExplainer
    }

    public private(set) var destination: Destination = .welcome

    /// Datos que arrastra el flujo de creación de cuenta para el `linkOrCreate`.
    public var pendingFullName: String = ""
    public var pendingEmail: String?
    public var pendingPhoneE164: String?

    /// Sheet "¿Eres tú?" — se muestra cuando, al crear cuenta, el teléfono ya
    /// tiene una cuenta cliente existente.
    public var showAccountMatch = false

    private let authService: AuthService
    private let authSession: AuthSession
    private let clienteRepository: ClienteRepository

    /// Callback que el ContentView inyecta para avanzar a `.authenticated`.
    public var onAuthenticated: (() -> Void)?

    public init(
        authService: AuthService,
        authSession: AuthSession,
        clienteRepository: ClienteRepository,
        onAuthenticated: (() -> Void)? = nil
    ) {
        self.authService = authService
        self.authSession = authSession
        self.clienteRepository = clienteRepository
        self.onAuthenticated = onAuthenticated
    }

    // MARK: - Navegación

    public func goToCreateAccount() {
        destination = .createAccount
    }

    public func goToWelcome() {
        destination = .welcome
    }

    public func startOTP(_ kind: OTPViewModel.Kind) {
        destination = .otp(kind)
    }

    public func cancelOTP() {
        destination = .welcome
    }

    // MARK: - Éxito de auth

    /// Punto único de finalización: persiste tokens, asegura el perfil de
    /// cliente y dispara la transición a la app. `fullName`/`email`/`phone`
    /// alimentan el `linkOrCreate`; si vienen vacíos se usan los pendientes.
    public func completeAuth(
        tokens: AuthSession.Tokens,
        fullName: String? = nil,
        email: String? = nil,
        phoneE164: String? = nil
    ) async {
        await authSession.persist(tokens)

        let name = fullName ?? (pendingFullName.isEmpty ? "Cliente" : pendingFullName)
        let mail = email ?? pendingEmail
        // El teléfono puede no conocerse en login por correo/Google; en ese caso
        // pasamos cadena vacía y el RPC reconcilia por user_id.
        let phone = phoneE164 ?? pendingPhoneE164 ?? ""

        do {
            _ = try await clienteRepository.linkOrCreate(
                userId: tokens.userId,
                phone: phone,
                fullName: name,
                email: mail
            )
        } catch {
            // No bloqueamos el acceso si el enlace falla: el perfil puede
            // reconciliarse luego. El usuario ya tiene sesión válida.
        }

        onAuthenticated?()
    }
}
