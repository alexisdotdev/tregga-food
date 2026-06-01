import SwiftUI
import TreggaCore
import AuthenticationServices
import TreggaDesignSystem

/// Pantalla Welcome del diseño client-v2. Hero de marca + input unificado
/// teléfono/correo + botón Google + link a crear cuenta.
public struct WelcomeView: View {
    @State private var viewModel: WelcomeViewModel
    @State private var googleError: String?
    @State private var showNotRegisteredDialog = false
    @Environment(\.webAuthenticationSession) private var webAuth

    public init(viewModel: WelcomeViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 0) {
                    headline
                    Spacer().frame(height: 22)
                    contactField
                    Spacer().frame(height: 12)
                    continueButton
                    Spacer().frame(height: 20)
                    divider
                    Spacer().frame(height: 16)
                    googleButton
                    Spacer().frame(height: 20)
                    createAccountLink
                    Spacer().frame(height: 16)
                    disclaimer
                }
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 40)
            }
        }
        .background(TreggaColors.bg)
        .ignoresSafeArea(edges: .top)
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
            Button("Crear cuenta nueva") { viewModel.irACrearCuenta() }
            Button("Continuar con Google") { runGoogle() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Puedes crear una cuenta nueva o continuar con Google.")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [TreggaColors.primary, TreggaColors.primaryDark, TreggaColors.primaryDeep],
                startPoint: .top, endPoint: .bottom
            )
            MotionStripes(color: TreggaColors.primaryDeep, tint: TreggaColors.primary)
                .opacity(0.35)

            VStack(spacing: 14) {
                Image("logo-tregga")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                Text("tregga")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(.white)
            }
            .padding(.top, 96)
        }
        .frame(height: 320)
        .clipped()
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comida que llega rápido")
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(TreggaColors.text)
            Text("Pide de tus negocios favoritos. Solo te toma un minuto crear tu cuenta.")
                .font(.system(size: 15))
                .foregroundStyle(TreggaColors.textSec)
                .lineSpacing(2)
        }
    }

    private var contactField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Teléfono o correo", text: $viewModel.contactInput)
                    .onChange(of: viewModel.contactInput) { _, new in
                        let isEmail = new.contains { $0.isLetter || $0 == "@" }
                        guard !isEmail else { return }
                        let formatted = PhoneFormatter.format(new)
                        if formatted != new { viewModel.contactInput = formatted }
                    }
                    .font(.system(size: 15.5, weight: .semibold))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if let err = viewModel.error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(TreggaColors.danger)
            }
        }
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
                    .foregroundStyle(.white)
                if !viewModel.loading {
                    TreggaIcon(.arrow, size: 18, color: .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(viewModel.canContinue ? TreggaColors.primary : TreggaColors.primary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!viewModel.canContinue || viewModel.loading)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(TreggaColors.border).frame(height: 1)
            Text("o").font(.system(size: 12.5, weight: .heavy)).foregroundStyle(TreggaColors.textSec)
            Rectangle().fill(TreggaColors.border).frame(height: 1)
        }
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
            .frame(height: 54)
            .background(TreggaColors.card)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(TreggaColors.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var createAccountLink: some View {
        Button { viewModel.irACrearCuenta() } label: {
            HStack(spacing: 4) {
                Text("¿Aún no tienes cuenta? ")
                    .font(.system(size: 14))
                    .foregroundStyle(TreggaColors.textSec)
                Text("Crear cuenta nueva")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(TreggaColors.primary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var disclaimer: some View {
        Text("Al continuar aceptas los Términos y la Política de privacidad de Tregga.")
            .font(.system(size: 11.5))
            .foregroundStyle(TreggaColors.textTer)
            .lineSpacing(2)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    private func runGoogle() {
        Task {
            do {
                try await viewModel.continuarConGoogle { url in
                    try await webAuth.authenticate(using: url, callbackURLScheme: "app.tregga.food")
                }
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
