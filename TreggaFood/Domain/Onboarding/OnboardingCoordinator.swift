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

    /// Login pendiente cuando el paso 2 detecta una cuenta existente (modelo Uber:
    /// no se crea otra cuenta, se inicia sesión y se agrega el rol cliente).
    public private(set) var pendingLoginKind: OTPViewModel.Kind?

    /// Verifica contra la base que el correo y el teléfono del paso 2 no estén
    /// ya registrados antes de avanzar. Si alguno existe (o hay error de red),
    /// publica el mensaje en `signup.emailDuplicadoError` y NO avanza.
    public func validarYAvanzarEmail() async {
        signup.emailDuplicadoError = nil
        signup.mostrarIniciarSesion = false
        pendingLoginKind = nil
        validandoEmail = true
        defer { validandoEmail = false }

        let email = signup.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            // Login SOLO por correo (ver IDENTIDAD-Y-LOGIN-reglas.md). Una sola
            // identidad por persona: si el correo ya pertenece a una cuenta (cualquier
            // rol), NO creamos otra — ofrecemos iniciar sesión y al entrar se agrega el
            // rol cliente (`vincular_cliente` en `completeAuth`). El teléfono es solo
            // contacto; el índice `clientes_phone_unique` evita duplicar el cliente.
            if try await authService.emailAccountKind(email: email) != .none {
                signup.emailDuplicadoError = "Ya tienes una cuenta Tregga con ese correo. Inicia sesión y activamos tu perfil de cliente."
                signup.mostrarIniciarSesion = true
                pendingLoginKind = .email(email)
                return
            }
        } catch {
            signup.emailDuplicadoError = "No pudimos verificar tus datos. Revisa tu conexión."
            return
        }

        advanceSignup()
    }

    /// "Iniciar sesión" desde el paso 2 cuando la cuenta ya existe: cierra la
    /// sesión anónima del alta y arranca el login por OTP (correo o teléfono). Al
    /// completar, `completeAuth` agrega el rol cliente a esa misma cuenta.
    public func iniciarSesionCuentaExistente() {
        guard let kind = pendingLoginKind else { return }
        pendingLoginKind = nil
        signup.mostrarIniciarSesion = false
        Task {
            await cleanupAnonymousSessionIfNeeded()
            startOTP(kind)
        }
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

        let fullName = signup.nombres.trimmingCharacters(in: .whitespaces)
        let phone = signup.phoneE164Normalized
        let email = signup.email.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1 — alta vía la API de Next.js (crítico). Enruta por el servidor a propósito: solo así
        // se captura la IP pública en profiles.registration_ip. El endpoint crea cuenta+cliente+
        // perfil (nombre/apellidos/phone) y devuelve la sesión; la establecemos aquí.
        let userId: UUID
        do {
            let tokens = try await authService.registerCliente(
                email: email,
                password: signup.password,
                fullName: fullName,
                apellidoPaterno: signup.apellidoPaterno.trimmingCharacters(in: .whitespaces),
                apellidoMaterno: signup.apellidoMaterno.isEmpty
                    ? nil : signup.apellidoMaterno.trimmingCharacters(in: .whitespaces),
                phone: phone.isEmpty ? nil : phone
            )
            await authSession.persist(tokens)
            userId = tokens.userId
        } catch {
            print("[submitSignup] registerCliente falló:", error)
            if case let AuthError.unknown(msg) = error {
                signupError = msg
            } else {
                signupError = "No pudimos crear tu cuenta. Revisa tu conexión e intenta de nuevo."
            }
            return
        }

        // 2 — correo de verificación (no bloqueante): manda un enlace para que
        // el cliente confirme la propiedad de su correo. Si falla, no afecta el alta.
        do {
            try await authService.requestEmailVerification()
        } catch {
            print("[submitSignup] requestEmailVerification falló:", error)
        }

        // 3 — foto: ya fue subida en la pantalla de foto; aquí solo su URL.
        let avatarURL: String? = signup.fotoPerfilURL?.absoluteString

        // 4 — id del cliente para la dirección. En prod el endpoint ya creó la fila
        // `clientes`; si no está (alta sin API / timing), la aseguramos con
        // `vincular_cliente` (idempotente) para no perder la dirección de entrega.
        var clienteId: UUID?
        do {
            clienteId = try await clienteRepository.fetchByUserId(userId)?.id
        } catch {
            print("[submitSignup] fetchByUserId falló:", error)
        }
        if clienteId == nil {
            do {
                clienteId = try await clienteRepository.linkOrCreate(
                    userId: userId, phone: phone, fullName: fullName, email: email
                ).id
            } catch {
                print("[submitSignup] linkOrCreate (asegurar cliente) falló:", error)
            }
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

        // 6 — dirección principal (no bloqueante). Guardamos también los componentes
        // capturados en el onboarding (CP/colonia/municipio/estado) para que la
        // dirección de entrega quede completa, no solo el texto.
        if let clienteId {
            let calle = signup.direccionCalle.trimmingCharacters(in: .whitespaces)
            let colonia = signup.colonia.trimmingCharacters(in: .whitespaces)
            let municipio = signup.municipio.trimmingCharacters(in: .whitespaces)
            let estado = signup.estado.trimmingCharacters(in: .whitespaces)
            let cp = signup.codigoPostal.filter(\.isNumber)
            let address = [calle, colonia, municipio, estado]
                .filter { !$0.isEmpty }.joined(separator: ", ")
            let refs = signup.referencias.trimmingCharacters(in: .whitespaces)
            do {
                _ = try await direccionRepository.crear(
                    clienteId: clienteId,
                    label: "Casa",
                    address: address,
                    referencias: refs.isEmpty ? nil : refs,
                    isDefault: true,
                    lat: nil,
                    lng: nil,
                    calle: calle.isEmpty ? nil : calle,
                    codigoPostal: cp.isEmpty ? nil : cp,
                    colonia: colonia.isEmpty ? nil : colonia,
                    municipio: municipio.isEmpty ? nil : municipio,
                    estado: estado.isEmpty ? nil : estado,
                    instrucciones: nil,
                    fotos: []
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

        // El perfil puede haberse creado server-side: el trigger `handle_new_user`
        // copia nombre/email/avatar del proveedor (Google). Preferimos ese nombre
        // real antes que el fallback "Cliente", porque `vincular_cliente` lo
        // sobrescribiría con lo que le pasemos.
        let existente = try? await profileRepository.fetch(userId: tokens.userId)
        let name = resolverNombre(recibido: fullName, existente: existente?.fullName)
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

    /// Elige el nombre a persistir: prioriza el nombre real ya existente en el
    /// perfil (p. ej. el que puso el trigger desde Google), luego el recibido del
    /// proveedor, y solo como último recurso el placeholder "Cliente".
    private func resolverNombre(recibido: String?, existente: String?) -> String {
        let ex = (existente ?? "").trimmingCharacters(in: .whitespaces)
        if !ex.isEmpty, ex != "Cliente" { return ex }
        let rec = (recibido ?? "").trimmingCharacters(in: .whitespaces)
        if !rec.isEmpty { return rec }
        return pendingFullName.isEmpty ? "Cliente" : pendingFullName
    }
}
