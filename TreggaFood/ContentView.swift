import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Root del runtime de Tregga Food. Decide la pantalla según el estado de sesión:
/// splash mientras restaura, luego onboarding (no autenticado) o la app (autenticado).
struct ContentView: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.scenePhase) private var scenePhase
    @State private var phase: Phase = .loading
    @State private var coordinator: OnboardingCoordinator?
    @State private var cart = CartStore()
    @State private var isLocked = false
    @State private var showBiometricOffer = false
    private let remembered = RememberedUserStore()
    /// Apariencia elegida en Cuenta → Preferencias. Persistida local.
    @AppStorage("APPEARANCE_MODE") private var appearanceRaw: String = AppearanceMode.system.rawValue

    enum Phase { case loading, unauthenticated, welcomeBack, authenticated }

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        Group {
            if isLocked {
                BiometricLockView(
                    kind: BiometricAuthService.shared.availableKind,
                    onUnlock: { await tryUnlock() },
                    onUseOtherAccount: { await useOtherAccount() }
                )
            } else {
                switch phase {
                case .loading:
                    SplashScreen()
                case .unauthenticated:
                    if let coordinator {
                        OnboardingFlowView(coordinator: coordinator)
                    } else {
                        SplashScreen()
                    }
                case .welcomeBack:
                    WelcomeBackView(
                        displayName: remembered.displayName ?? "",
                        kind: BiometricAuthService.shared.availableKind,
                        onIngresar: { await ingresarConBiometria() },
                        onUseAccount: { phase = .unauthenticated }
                    )
                case .authenticated:
                    ClientTabView(onSignOut: signOut)
                        .environment(\.cartStore, cart)
                }
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .onChange(of: phase) { _, newValue in
            if newValue == .authenticated { maybeOfferBiometric() }
        }
        .onChange(of: scenePhase) { _, newScene in
            // Re-bloquear al pasar a segundo plano (oculta contenido en el switcher).
            if newScene == .background,
               phase == .authenticated,
               BiometricLockPreference.isEnabled,
               BiometricAuthService.shared.isAvailable {
                isLocked = true
            }
        }
        .alert("Desbloqueo con \(biometricLabel)", isPresented: $showBiometricOffer) {
            Button("Activar") { Task { await enableBiometric() } }
            Button("Ahora no", role: .cancel) {}
        } message: {
            Text("Protege tu cuenta: la próxima vez que abras Tregga te pediremos \(biometricLabel) para entrar.")
        }
        .task {
            guard coordinator == nil, let deps else { return }
            coordinator = OnboardingCoordinator(
                authService: deps.authService,
                authSession: deps.authSession,
                clienteRepository: deps.clienteRepository,
                profileRepository: deps.profileRepository,
                direccionRepository: deps.direccionRepository,
                storageService: deps.storageService,
                onAuthenticated: { phase = .authenticated }
            )
        }
        .task {
            guard let deps else { return }
            await deps.authSession.restore()
            // Validamos la sesión persistida ANTES de conceder acceso: un token del
            // Keychain podría estar caducado/revocado (sesión "fantasma"). Hacemos un
            // refresh real contra el backend; si falla por credenciales → a login. Si
            // falla por red, conservamos la sesión (tolerancia offline).
            if let refresh = deps.authSession.tokens?.refreshToken {
                do {
                    let fresh = try await deps.authService.restoreSession(refreshToken: refresh)
                    await deps.authSession.persist(fresh)
                } catch AuthError.networkFailure {
                    // Sin red: conservamos la sesión persistida.
                } catch {
                    try? await deps.authService.signOut()
                    await deps.authSession.clear()
                }
            }
            // Una sesión anónima sobrante del andamiaje de signup no cuenta como login.
            if deps.authSession.isAuthenticated, await deps.authService.currentUserIsAnonymous() {
                try? await deps.authService.signOut()
                await deps.authSession.clear()
            }
            if deps.authSession.isAuthenticated {
                // Candado biométrico: si está activado, bloquear ANTES de mostrar
                // contenido. La BiometricLockView auto-dispara Face ID.
                if BiometricLockPreference.isEnabled, BiometricAuthService.shared.isAvailable {
                    isLocked = true
                    await captureRememberedUser()
                }
                phase = .authenticated
            } else if remembered.hasRemembered, BiometricAuthService.shared.isAvailable {
                // Sesión cerrada/vencida pero el dispositivo recuerda al usuario:
                // pantalla de bienvenida con re-login biométrico (estilo Banamex).
                phase = .welcomeBack
            } else {
                phase = .unauthenticated
            }
        }
    }

    /// Guarda al usuario recordado (nombre + refresh token actual) para el
    /// re-login biométrico. Se llama cuando hay sesión activa y Face ID activado.
    private func captureRememberedUser() async {
        guard let deps, let tokens = deps.authSession.tokens else { return }
        let name = ((try? await deps.profileRepository.fetch(userId: tokens.userId)) ?? nil)?.fullName ?? ""
        await remembered.save(displayName: name, refreshToken: tokens.refreshToken, userId: tokens.userId)
    }

    /// Re-login biométrico desde la pantalla de bienvenida. Pide Face ID, lee el
    /// refresh token recordado y restaura la sesión. Devuelve false si falla (la
    /// vista queda en reintento y ofrece entrar con correo/teléfono).
    private func ingresarConBiometria() async -> Bool {
        guard let deps else { return false }
        let ok = await BiometricAuthService.shared.authenticate(
            reason: "Ingresa a Tregga con \(biometricLabel)"
        )
        guard ok, let token = await remembered.refreshToken() else { return false }
        do {
            let tokens = try await deps.authService.restoreSession(refreshToken: token)
            await deps.authSession.persist(tokens)
            await remembered.save(
                displayName: remembered.displayName ?? "",
                refreshToken: tokens.refreshToken,
                userId: tokens.userId
            )
            phase = .authenticated
            return true
        } catch {
            // Token expirado o revocado: olvidamos al usuario y caemos al login.
            await remembered.clear()
            return false
        }
    }

    // MARK: - Candado biométrico

    private var biometricLabel: String {
        BiometricAuthService.shared.availableKind == .touchID ? "Touch ID" : "Face ID"
    }

    /// Intenta desbloquear. Si la biometría pasa, levanta el candado; si falla,
    /// la BiometricLockView se queda en estado de reintento (no saca al usuario).
    private func tryUnlock() async {
        let ok = await BiometricAuthService.shared.authenticate(
            reason: "Desbloquea Tregga para continuar"
        )
        if ok { withAnimation { isLocked = false } }
    }

    /// "Usar otra cuenta": fallback elegido → cerrar sesión y volver al login.
    private func useOtherAccount() async {
        isLocked = false
        BiometricLockPreference.reset()
        signOut()
    }

    /// Ofrece activar el candado una sola vez, tras el primer login real.
    private func maybeOfferBiometric() {
        guard BiometricAuthService.shared.isAvailable,
              !BiometricLockPreference.isEnabled,
              !BiometricLockPreference.didPrompt,
              !isLocked else { return }
        BiometricLockPreference.didPrompt = true
        showBiometricOffer = true
    }

    private func enableBiometric() async {
        let ok = await BiometricAuthService.shared.authenticate(
            reason: "Confirma tu identidad para activar el desbloqueo"
        )
        if ok {
            BiometricLockPreference.isEnabled = true
            await captureRememberedUser()
        }
    }

    /// Cierra sesión. Si Face ID está activado, recuerda al usuario y hace un
    /// cierre **local** (sin revocar el token) para permitir re-login biométrico
    /// → pantalla de bienvenida. Si no, cierre completo (revoca) → Welcome.
    private func signOut() {
        guard let deps else { return }
        Task {
            if BiometricLockPreference.isEnabled,
               BiometricAuthService.shared.isAvailable,
               deps.authSession.tokens != nil {
                await captureRememberedUser()
                try? await deps.authService.signOutLocal()
                await deps.authSession.clear()
                recreateCoordinator(deps)
                phase = .welcomeBack
            } else {
                BiometricLockPreference.reset()
                await remembered.clear()
                try? await deps.authService.signOut()
                await deps.authSession.clear()
                recreateCoordinator(deps)
                phase = .unauthenticated
            }
        }
    }

    private func recreateCoordinator(_ deps: AppDependencies) {
        coordinator = OnboardingCoordinator(
            authService: deps.authService,
            authSession: deps.authSession,
            clienteRepository: deps.clienteRepository,
            profileRepository: deps.profileRepository,
            direccionRepository: deps.direccionRepository,
            storageService: deps.storageService,
            onAuthenticated: { phase = .authenticated }
        )
    }
}

/// Pantalla 00 — Splash. Mismo diseño que Tregga Delivery: gradiente vertical
/// `primaryDeep → primaryDark → primary`, logo con sombra, tagline de cliente y
/// spinner animado abajo (sin motion stripes).
struct SplashScreen: View {
    @State private var rotating = false

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: TreggaColors.primaryDeep, location: 0.0),
                    .init(color: TreggaColors.primaryDark, location: 0.5),
                    .init(color: TreggaColors.primary,     location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Image("logo-tregga")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220)
                    .shadow(color: .black.opacity(0.30), radius: 16, x: 0, y: 12)

                Text("Tu antojo, al instante")
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(17 * 0.35)
                    .opacity(0.95)
                    .padding(.top, 14)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)

            VStack {
                Spacer()
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(rotating ? 360 : 0))
                    .background(
                        Circle().stroke(Color.white.opacity(0.32), lineWidth: 3)
                    )
                    .padding(.bottom, 96)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotating = true
            }
        }
    }
}

/// Flujo de onboarding/auth (F1). Enruta entre Welcome, el alta multi-paso y OTP
/// según el destino del `OnboardingCoordinator`.
struct OnboardingFlowView: View {
    @Environment(\.appDependencies) private var deps
    let coordinator: OnboardingCoordinator

    var body: some View {
        Group {
            switch coordinator.destination {
            case .welcome:
                WelcomeView(viewModel: WelcomeViewModel(
                    authService: authService, coordinator: coordinator
                ))
            case .otp(let kind):
                OTPView(viewModel: OTPViewModel(
                    kind: kind,
                    authService: authService,
                    coordinator: coordinator,
                    fullName: coordinator.pendingFullName.isEmpty ? nil : coordinator.pendingFullName
                ))
            case .permissionExplainer:
                PermissionExplainerView(onAllow: {})

            // MARK: Alta multi-paso (cliente)
            case .signupIntro:
                SignupIntroView(
                    onBack: { coordinator.backSignup() },
                    onContinue: { coordinator.advanceSignup() }
                )
            case .signupName:
                SignupNameView(
                    state: coordinator.signup,
                    onBack: { coordinator.backSignup() },
                    onContinue: { coordinator.advanceSignup() }
                )
            case .signupEmail:
                SignupEmailView(
                    state: coordinator.signup,
                    onBack: { coordinator.backSignup() },
                    onContinue: { Task { await coordinator.validarYAvanzarEmail() } }
                )
            case .signupPhoto:
                SignupPhotoView(
                    state: coordinator.signup,
                    storage: storageService,
                    userId: coordinator.currentUserId,
                    onBack: { coordinator.backSignup() },
                    onContinue: { coordinator.advanceSignup() }
                )
            case .signupAddress:
                SignupAddressView(
                    state: coordinator.signup,
                    postalCodeRepo: deps?.postalCodeRepository,
                    onBack: { coordinator.backSignup() },
                    onContinue: { coordinator.advanceSignup() }
                )
            case .signupPassword:
                SignupPasswordView(
                    state: coordinator.signup,
                    onBack: { coordinator.backSignup() },
                    onContinue: { coordinator.advanceSignup() }
                )
            case .signupTerms:
                SignupTermsView(
                    state: coordinator.signup,
                    submitting: coordinator.signupSubmitting,
                    errorMessage: coordinator.signupError,
                    onBack: { coordinator.backSignup() },
                    onCrearCuenta: { Task { await coordinator.submitSignup() } }
                )
            case .signupSuccess:
                SignupSuccessView(
                    nombres: coordinator.signup.nombres,
                    onContinuar: { coordinator.finishSignup() }
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.destination)
    }

    private var authService: AuthService {
        deps?.authService ?? MockAuthService()
    }

    private var storageService: StorageService {
        deps?.storageService ?? MockStorageService()
    }
}

#Preview { ContentView() }
