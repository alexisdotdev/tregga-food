import Foundation
import TreggaCore
import Observation

/// Coordina el flujo de onboarding/auth de Tregga Food (cliente).
///
/// El cliente no tiene checklist/INE/vehículo: se identifica (teléfono o
/// correo → OTP), o crea cuenta vía el flujo multi-paso (8 pantallas).
/// Tras obtener tokens persiste la sesión, llama `clienteRepository.linkOrCreate`
/// y notifica al ContentView vía `onAuthenticated` para pasar a `.authenticated`.
@MainActor
@Observable
public final class OnboardingCoordinator {

    public enum Destination: Equatable, Sendable {
        case welcome
        case otp(OTPViewModel.Kind)
        case permissionExplainer
        // Flujo de alta multi-paso (cliente).
        case signupIntro
        case signupName
        case signupEmail
        case signupPhoto
        case signupAddress
        case signupPassword
        case signupTerms
        case signupSuccess
    }

    public private(set) var destination: Destination = .welcome

    /// Estado acumulado del flujo de alta multi-paso.
    public let signup = SignupFlowState()

    /// `true` mientras corre `submitSignup`.
    public private(set) var signupSubmitting = false
    /// Error visible para la pantalla de términos si el alta falla.
    public private(set) var signupError: String?

    /// Datos que arrastra el flujo de creación de cuenta para el `linkOrCreate`.
    public var pendingFullName: String = ""
    public var pendingEmail: String?
    public var pendingPhoneE164: String?

    private let authService: AuthService
    private let authSession: AuthSession
    private let clienteRepository: ClienteRepository
    private let profileRepository: ProfileRepository
    private let direccionRepository: DireccionClienteRepository
    private let storageService: StorageService

    /// Callback que el ContentView inyecta para avanzar a `.authenticated`.
    public var onAuthenticated: (() -> Void)?

    public init(
        authService: AuthService,
        authSession: AuthSession,
        clienteRepository: ClienteRepository,
        profileRepository: ProfileRepository,
        direccionRepository: DireccionClienteRepository,
        storageService: StorageService,
        onAuthenticated: (() -> Void)? = nil
    ) {
        self.authService = authService
        self.authSession = authSession
        self.clienteRepository = clienteRepository
        self.profileRepository = profileRepository
        self.direccionRepository = direccionRepository
        self.storageService = storageService
        self.onAuthenticated = onAuthenticated
    }

    /// `userId` de la sesión actual (anónima durante el alta). Lo usa la pantalla
    /// de foto para subir al bucket `avatars`.
    public var currentUserId: UUID? { authSession.tokens?.userId }

    // MARK: - Navegación

    public func goToWelcome() {
        destination = .welcome
        Task { await cleanupAnonymousSessionIfNeeded() }
    }

    public func startOTP(_ kind: OTPViewModel.Kind) {
        destination = .otp(kind)
    }

    public func cancelOTP() {
        destination = .welcome
    }

    // MARK: - Flujo de alta multi-paso

    /// Arranca el alta de cuenta en la pantalla intro. Limpia estado previo y
    /// crea una sesión anónima (si es posible) para que el upload a Storage y los
    /// RPC tengan `auth.uid()`.
    public func goToSignup() {
        signup.reset()
        signupError = nil
        if let phone = pendingPhoneE164 { signup.phoneE164 = phone }
        destination = .signupIntro
        Task { await ensureAnonymousSession() }
    }

    private static let order: [Destination] = [
        .signupIntro, .signupName, .signupEmail, .signupPhoto,
        .signupAddress, .signupPassword, .signupTerms, .signupSuccess
    ]

    public func advanceSignup() {
        guard let idx = Self.order.firstIndex(of: destination), idx + 1 < Self.order.count else { return }
        destination = Self.order[idx + 1]
    }

    /// `true` mientras se verifican los duplicados del paso 2 (correo/teléfono).
    public private(set) var validandoEmail = false

    /// Verifica contra la base que el correo y el teléfono del paso 2 no estén
    /// ya registrados antes de avanzar. Si alguno existe (o hay error de red),
    /// publica el mensaje en `signup.emailDuplicadoError` y NO avanza.
    public func validarYAvanzarEmail() async {
        signup.emailDuplicadoError = nil
        validandoEmail = true
        defer { validandoEmail = false }

        let email = signup.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let e164 = signup.phoneE164Normalized

        do {
            // "Registrado" = existe cualquier cuenta con ese correo (cliente,
            // repartidor o admin), no solo repartidor — por eso usamos el kind.
            if try await authService.emailAccountKind(email: email) != .none {
                signup.emailDuplicadoError = "Ese correo ya está registrado. Inicia sesión."
                return
            }
            if !e164.isEmpty, try await authService.phoneIsRegistered(phoneE164: e164) {
                signup.emailDuplicadoError = "Ese teléfono ya está registrado. Inicia sesión."
                return
            }
        } catch {
            signup.emailDuplicadoError = "No pudimos verificar tus datos. Revisa tu conexión."
            return
        }

        advanceSignup()
    }

    public func backSignup() {
        guard let idx = Self.order.firstIndex(of: destination) else { return }
        if idx == 0 {
            destination = .welcome
            Task { await cleanupAnonymousSessionIfNeeded() }
        } else {
            destination = Self.order[idx - 1]
        }
    }

    /// Crea una sesión anónima si aún no hay sesión, para que el upload de la foto
    /// y los RPC del alta tengan un `auth.uid()` estable (mismo userId al convertir).
    private func ensureAnonymousSession() async {
        guard authSession.tokens == nil else { return }
        do {
            let tokens = try await authService.signInAnonymously()
            await authSession.persist(tokens)
        } catch {
            print("[signup] signInAnonymously falló:", error)
        }
    }

    /// Si el alta aborta tras crear la sesión anónima, la cerramos para no dejar
    /// un perfil de cliente vacío huérfano colgando del usuario anónimo.
    private func cleanupAnonymousSessionIfNeeded() async {
        if await authService.currentUserIsAnonymous() {
            try? await authService.signOut()
            await authSession.clear()
        }
    }

    // MARK: - Submit del alta

    /// Orquesta el alta real del cliente al terminar el paso de términos:
    /// 1. Asegura sesión (anónima) para tener `auth.uid()`.
    /// 2. Sube la foto al bucket `avatars` (si hay).
    /// 3. Convierte el anónimo a cuenta email+password (crítico).
    /// 4. `linkOrCreate` del cliente (RPC `vincular_cliente`).
    /// 5. Actualiza el perfil (apellidos, fecha, avatar, dirección).
    /// 6. Crea la dirección principal.
    /// 7. Avanza a `signupSuccess`.
    /// Los pasos secundarios (2, 5, 6) no bloquean el alta si fallan; solo el
    /// registro de credenciales (3) es crítico.
    public func submitSignup() async {
        signupSubmitting = true
        signupError = nil
        defer { signupSubmitting = false }

        // 1 — sesión
        await ensureAnonymousSession()
        guard let userId = authSession.tokens?.userId else {
            await cleanupAnonymousSessionIfNeeded()
            signupError = "No se pudo iniciar la sesión. Revisa tu conexión e intenta de nuevo."
            return
        }

        // 2 — foto: ya fue subida en la pantalla de foto; aquí solo su URL.
        let avatarURL: String? = signup.fotoPerfilURL?.absoluteString

        // 3 — credenciales (crítico)
        do {
            try await authService.registerEmailPassword(
                email: signup.email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: signup.password
            )
        } catch {
            print("[submitSignup] registerEmailPassword falló:", error)
            await cleanupAnonymousSessionIfNeeded()
            signupError = "No pudimos crear tu cuenta con ese correo. Quizá ya está registrado o hubo un problema de conexión."
            return
        }

        let fullName = signup.nombres.trimmingCharacters(in: .whitespaces)
        let phone = signup.phoneE164Normalized
        let email = signup.email.trimmingCharacters(in: .whitespacesAndNewlines)

        // 4 — link/create cliente (no bloqueante: ya hay cuenta)
        var clienteId: UUID?
        do {
            let cliente = try await clienteRepository.linkOrCreate(
                userId: userId,
                phone: phone,
                fullName: fullName,
                email: email
            )
            clienteId = cliente.id
        } catch {
            print("[submitSignup] linkOrCreate falló:", error)
        }

        // 5 — perfil (no bloqueante)
        do {
            _ = try await profileRepository.actualizar(
                userId: userId,
                fullName: fullName,
                apellidoPaterno: signup.apellidoPaterno.trimmingCharacters(in: .whitespaces),
                apellidoMaterno: signup.apellidoMaterno.isEmpty
                    ? nil : signup.apellidoMaterno.trimmingCharacters(in: .whitespaces),
                email: email,
                phone: phone.isEmpty ? nil : phone,
                fechaNacimiento: signup.fechaNacimiento,
                avatarUrl: avatarURL,
                calle: signup.direccionCalle.trimmingCharacters(in: .whitespaces),
                colonia: signup.colonia.trimmingCharacters(in: .whitespaces),
                codigoPostal: signup.codigoPostal.filter(\.isNumber),
                municipio: signup.municipio.trimmingCharacters(in: .whitespaces),
                estado: signup.estado.trimmingCharacters(in: .whitespaces)
            )
        } catch {
            print("[submitSignup] profile actualizar falló:", error)
        }

        // 6 — dirección principal (no bloqueante)
        if let clienteId {
            let calle = signup.direccionCalle.trimmingCharacters(in: .whitespaces)
            let colonia = signup.colonia.trimmingCharacters(in: .whitespaces)
            let address = [calle, colonia].filter { !$0.isEmpty }.joined(separator: ", ")
            let refs = signup.referencias.trimmingCharacters(in: .whitespaces)
            do {
                _ = try await direccionRepository.crear(
                    clienteId: clienteId,
                    label: "Casa",
                    address: address,
                    referencias: refs.isEmpty ? nil : refs,
                    isDefault: true
                )
            } catch {
                print("[submitSignup] crear dirección falló:", error)
            }
        }

        // 7 — éxito
        destination = .signupSuccess
    }

    /// "Continuar" de la pantalla de éxito → entra a la app.
    public func finishSignup() {
        onAuthenticated?()
    }

    // MARK: - Éxito de auth (login OTP / Google)

    /// Punto único de finalización para login: persiste tokens, asegura el perfil
    /// de cliente y dispara la transición a la app.
    public func completeAuth(
        tokens: AuthSession.Tokens,
        fullName: String? = nil,
        email: String? = nil,
        phoneE164: String? = nil
    ) async {
        await authSession.persist(tokens)

        let name = fullName ?? (pendingFullName.isEmpty ? "Cliente" : pendingFullName)
        let mail = email ?? pendingEmail
        let phone = phoneE164 ?? pendingPhoneE164 ?? ""

        do {
            _ = try await clienteRepository.linkOrCreate(
                userId: tokens.userId,
                phone: phone,
                fullName: name,
                email: mail
            )
        } catch {
            // No bloqueamos el acceso si el enlace falla.
        }

        onAuthenticated?()
    }
}
