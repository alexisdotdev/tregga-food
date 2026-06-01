import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Root del runtime de Tregga Food. Decide la pantalla según el estado de sesión:
/// splash mientras restaura, luego onboarding (no autenticado) o la app (autenticado).
struct ContentView: View {
    @Environment(\.appDependencies) private var deps
    @State private var phase: Phase = .loading
    @State private var coordinator: OnboardingCoordinator?

    enum Phase { case loading, unauthenticated, authenticated }

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
                HomePlaceholder()
            }
        }
        .task {
            guard coordinator == nil, let deps else { return }
            coordinator = OnboardingCoordinator(
                authService: deps.authService,
                authSession: deps.authSession,
                clienteRepository: deps.clienteRepository,
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
}

/// Pantalla 00 — Splash. Fondo verde de marca + motion stripes + logo + tagline.
struct SplashScreen: View {
    var body: some View {
        ZStack {
            TreggaColors.primary.ignoresSafeArea()
            MotionStripes(color: TreggaColors.primaryDeep, tint: TreggaColors.primary)
                .ignoresSafeArea()
                .opacity(0.6)

            VStack(spacing: 14) {
                Image("logo-tregga")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                Text("Tregga Food")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .tracking(-0.5)
                Text("Tu antojo, al instante")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

/// Flujo de onboarding/auth (F1). Enruta entre Welcome, CreateAccount y OTP
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
            case .createAccount:
                CreateAccountView(viewModel: CreateAccountViewModel(
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
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.destination)
    }

    private var authService: AuthService {
        deps?.authService ?? MockAuthService()
    }
}

/// Placeholder de la app autenticada — se reemplaza por el TabView (F2+).
struct HomePlaceholder: View {
    var body: some View {
        Screen {
            Text("Home (F2) en construcción")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(TreggaColors.text)
        }
    }
}

#Preview { ContentView() }
