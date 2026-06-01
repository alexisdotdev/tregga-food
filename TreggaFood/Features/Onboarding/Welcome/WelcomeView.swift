import SwiftUI
import TreggaCore
import AuthenticationServices
import TreggaDesignSystem

/// Login de Tregga Food. Mismo diseño que Tregga Delivery: brand header +
/// input unificado teléfono/correo + botón Google + link a crear cuenta.
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
                brandHeader
                Spacer().frame(height: 28)
                headline
                Spacer().frame(height: 18)
                contactField
                Spacer().frame(height: 12)
                continueButton
                Spacer().frame(height: 22)
                divider
                Spacer().frame(height: 18)
                googleButton
                Spacer().frame(height: 18)
                createAccountLink
                Spacer().frame(height: 22)
                disclaimer
                Spacer().frame(height: 28)
                recaptchaFootnote
            }
            .padding(.bottom, 40)
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
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            Image("logo-tregga")
                .resizable()
                .scaledToFit()
                .frame(height: 28)
            Text("TREGGA FOOD")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(2.5)
                .foregroundStyle(TreggaColors.textSec)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var headline: some View {
        Text("¿Cuál es tu número o correo?")
            .font(.system(size: 26, weight: .heavy))
            .tracking(-0.4)
            .lineSpacing(26 * 0.2)
            .foregroundStyle(TreggaColors.text)
            .padding(.horizontal, 20)
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
                    .foregroundStyle(.white)
                if !viewModel.loading {
                    TreggaIcon(.arrow, size: 18, color: .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(viewModel.canContinue ? TreggaColors.primary : TreggaColors.primary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!viewModel.canContinue || viewModel.loading)
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
                Text("Crear cuenta con correo")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(TreggaColors.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
    }

    private var disclaimer: some View {
        Text("Al continuar, aceptas recibir llamadas, WhatsApp o SMS — incluyendo mensajes automatizados — de Tregga y sus afiliados al número proporcionado.")
            .font(.system(size: 12))
            .foregroundStyle(TreggaColors.textSec)
            .lineSpacing(2)
            .padding(.horizontal, 20)
    }

    private var recaptchaFootnote: some View {
        Text("Este sitio está protegido por reCAPTCHA, y aplican la **Política de privacidad** y los **Términos del servicio** de Google.")
            .font(.system(size: 11))
            .foregroundStyle(TreggaColors.textTer)
            .lineSpacing(2)
            .padding(.horizontal, 20)
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
