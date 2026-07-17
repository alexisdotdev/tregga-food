import SwiftUI
import TreggaCore
import AuthenticationServices
import TreggaDesignSystem

/// Login de Tregga Food. Diseño del cliente: hero ilustrado + input unificado
/// teléfono/correo + botón Google + link a crear cuenta.
public struct WelcomeView: View {
    @State private var viewModel: WelcomeViewModel
    @State private var googleError: String?
    @State private var showNotRegisteredDialog = false
    @State private var selectedDoc: LegalDocument?
    @State private var biometricWorking = false
    @Environment(\.webAuthenticationSession) private var webAuth

    /// Nombre del usuario recordado en el dispositivo (para el re-login biométrico).
    /// Nil = no hay usuario recordado o la biometría no está disponible.
    private let rememberedName: String?
    /// Re-login por Face ID/Touch ID. Devuelve true si entró (la vista se reemplaza).
    private let onBiometricLogin: (() async -> Bool)?

    private let heroHeight: CGFloat = 320

    public init(
        viewModel: WelcomeViewModel,
        rememberedName: String? = nil,
        onBiometricLogin: (() async -> Bool)? = nil
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.rememberedName = rememberedName
        self.onBiometricLogin = onBiometricLogin
    }

    private var mostrarBiometrico: Bool {
        rememberedName != nil && onBiometricLogin != nil && BiometricAuthService.shared.isAvailable
    }

    private var biometricLabel: String {
        BiometricAuthService.shared.availableKind == .touchID ? "Touch ID" : "Face ID"
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 0) {
                    brandLogo
                    Spacer().frame(height: 16)
                    headline
                    Spacer().frame(height: 6)
                    subtitle
                    Spacer().frame(height: 18)
                    contactField
                    Spacer().frame(height: 12)
                    continueButton
                    if mostrarBiometrico {
                        Spacer().frame(height: 12)
                        biometricButton
                    }
                    Spacer().frame(height: 20)
                    divider
                    Spacer().frame(height: 16)
                    googleButton
                    Spacer().frame(height: 18)
                    createAccountLink
                    Spacer().frame(height: 22)
                    disclaimer
                }
            }
            .padding(.bottom, 30)
        }
        .background(TreggaColors.bg)
        .alert("No pudimos iniciar sesión", isPresented: Binding(
            get: { googleError != nil },
            set: { if !$0 { googleError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(googleError ?? "") }
        .confirmationDialog(
            "No encontramos una cuenta con esos datos",
            isPresented: $showNotRegisteredDialog,
            titleVisibility: .visible
        ) {
            Button("Crear cuenta con correo") { viewModel.irACrearCuenta() }
            Button("Continuar con Google") { runGoogle() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Puedes crear una cuenta nueva con tu correo o continuar con Google.")
        }
        .sheet(item: $selectedDoc) { doc in
            LegalDocumentView(document: doc, onBack: { selectedDoc = nil })
        }
        .keyboardDismissToolbar()
    }

    private var hero: some View {
        Image("hero-login-cliente")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(TreggaColors.bg)
    }

    private var brandLogo: some View {
        HStack(spacing: 8) {
            Image("logo-tregga")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
            Text("FOOD")
                .font(.system(size: 11, weight: .heavy))
                .tracking(2.5)
                .foregroundStyle(TreggaColors.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var headline: some View {
        Text("¿Qué se te antoja hoy?")
            .font(.system(size: 28, weight: .heavy))
            .tracking(-0.5)
            .foregroundStyle(TreggaColors.text)
            .padding(.horizontal, 20)
    }

    private var subtitle: some View {
        Text("Pide de tus negocios favoritos en Zinapécuaro.")
            .font(.system(size: 14.5))
            .foregroundStyle(TreggaColors.textSec)
            .lineSpacing(3)
            .padding(.horizontal, 20)
    }

    private var contactField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Correo electrónico", text: $viewModel.contactInput)
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if let err = viewModel.error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(TreggaColors.danger)
            }
        }
        .padding(.horizontal, 20)
    }

    private var continueButton: some View {
        Button {
            Task {
                do { try await viewModel.continuar() }
                catch AuthError.accountNotRegistered { showNotRegisteredDialog = true }
                catch {}
            }
        } label: {
            HStack(spacing: 8) {
                Text(viewModel.loading ? "Enviando..." : "Continuar")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(viewModel.canContinue ? .white : TreggaColors.textTer)
                if !viewModel.loading {
                    TreggaIcon(.arrow, size: 18, color: viewModel.canContinue ? .white : TreggaColors.textTer)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(viewModel.canContinue ? TreggaColors.primary : TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!viewModel.canContinue || viewModel.loading)
        .padding(.horizontal, 20)
    }

    /// Re-login rápido con Face ID/Touch ID cuando el dispositivo recuerda al
    /// usuario (aparece debajo de "Continuar"). Evita reescribir correo + OTP.
    private var biometricButton: some View {
        Button {
            guard let onBiometricLogin, !biometricWorking else { return }
            Task {
                biometricWorking = true
                _ = await onBiometricLogin()
                biometricWorking = false
            }
        } label: {
            HStack(spacing: 10) {
                if biometricWorking {
                    ProgressView().controlSize(.small)
                } else {
                    TreggaIcon(
                        BiometricAuthService.shared.availableKind == .touchID ? .touchId : .faceId,
                        size: 20, color: TreggaColors.primary
                    )
                }
                Text("Entrar con \(biometricLabel)")
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(TreggaColors.surface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(TreggaColors.primary.opacity(0.5), lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(biometricWorking)
        .padding(.horizontal, 20)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(TreggaColors.border).frame(height: 1)
            Text("o").font(.system(size: 12.5, weight: .heavy)).foregroundStyle(TreggaColors.textSec)
            Rectangle().fill(TreggaColors.border).frame(height: 1)
        }
        .padding(.horizontal, 20)
    }

    private var googleButton: some View {
        Button { runGoogle() } label: {
            HStack(spacing: 10) {
                GoogleGIcon(size: 20)
                Text("Continuar con Google")
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(TreggaColors.surface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(TreggaColors.primary, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topTrailing) {
                Text("RECOMENDADO")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(TreggaColors.primary)
                    .clipShape(Capsule())
                    .offset(x: -14, y: -10)
            }
        }
        .padding(.horizontal, 20)
    }

    private var createAccountLink: some View {
        Button { viewModel.irACrearCuenta() } label: {
            HStack(spacing: 4) {
                Text("¿Primera vez en Tregga? ")
                    .font(.system(size: 14))
                    .foregroundStyle(TreggaColors.textSec)
                Text("Crear cuenta")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(TreggaColors.primary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 20)
    }

    private var disclaimer: some View {
        Text(disclaimerText)
            .font(.system(size: 11.5))
            .foregroundStyle(TreggaColors.textTer)
            .tint(TreggaColors.text)
            .lineSpacing(3)
            .padding(.horizontal, 20)
            .environment(\.openURL, OpenURLAction { url in
                switch url.host {
                case "terminos": selectedDoc = FoodLegalContent.document(id: "terminos-servicio")
                case "privacidad": selectedDoc = FoodLegalContent.document(id: "politica-privacidad")
                default: break
                }
                return .handled
            })
    }

    private var disclaimerText: AttributedString {
        func link(_ text: String, _ host: String) -> AttributedString {
            var s = AttributedString(text)
            s.link = URL(string: "tregga://\(host)")
            s.font = .system(size: 11.5, weight: .bold)
            s.underlineStyle = .single
            return s
        }
        return AttributedString("Al continuar aceptas los ")
            + link("Términos", "terminos")
            + AttributedString(" y la ")
            + link("Política de privacidad", "privacidad")
            + AttributedString(".")
    }

    private func runGoogle() {
        Task {
            do {
                // Sign-in NATIVO de Google (selector de cuenta de Google, sin el
                // diálogo del dominio de Supabase). Devuelve el idToken → Supabase.
                let g = try await GoogleSignInHelper.signIn()
                try await viewModel.continuarConGoogle(idToken: g.idToken, accessToken: g.accessToken)
            } catch is CancellationError {
            } catch {
                googleError = error.localizedDescription
            }
        }
    }
}

#Preview {
    WelcomeView(viewModel: WelcomeViewModel(authService: MockAuthService(), coordinator: nil))
}
