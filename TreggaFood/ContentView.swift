import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Root del runtime de Tregga Food. Decide la pantalla según el estado de sesión:
/// splash mientras restaura, luego onboarding (no autenticado) o la app (autenticado).
struct ContentView: View {
    @Environment(\.appDependencies) private var deps
    @State private var phase: Phase = .loading
    @State private var coordinator: OnboardingCoordinator?
    @State private var cart = CartStore()
    /// Apariencia elegida en Cuenta → Preferencias. Persistida local.
    @AppStorage("APPEARANCE_MODE") private var appearanceRaw: String = AppearanceMode.system.rawValue

    enum Phase { case loading, unauthenticated, authenticated }

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                SplashScreen()
            case .unauthenticated:
                if let coordinator {
                    OnboardingFlowView(coordinator: coordinator)
                } else {
                    SplashScreen()
                }
            case .authenticated:
                ClientTabView(onSignOut: signOut)
                    .environment(\.cartStore, cart)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
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
            // Una sesión anónima sobrante del andamiaje de signup no cuenta como login.
            if deps.authSession.isAuthenticated, await deps.authService.currentUserIsAnonymous() {
                try? await deps.authService.signOut()
                await deps.authSession.clear()
            }
            phase = deps.authSession.isAuthenticated ? .authenticated : .unauthenticated
        }
    }

    /// Cierra sesión: revoca en el servicio auth, limpia la sesión local y
    /// recrea el coordinator para volver el flujo a Welcome.
    private func signOut() {
        guard let deps else { return }
        Task {
            try? await deps.authService.signOut()
            await deps.authSession.clear()
            coordinator = OnboardingCoordinator(
                authService: deps.authService,
                authSession: deps.authSession,
                clienteRepository: deps.clienteRepository,
                profileRepository: deps.profileRepository,
                direccionRepository: deps.direccionRepository,
                storageService: deps.storageService,
                onAuthenticated: { phase = .authenticated }
            )
            phase = .unauthenticated
        }
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
                    onContinue: { coordinator.advanceSignup() }
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
