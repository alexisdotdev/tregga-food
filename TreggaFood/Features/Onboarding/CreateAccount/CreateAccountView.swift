import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pantalla Crear cuenta del diseño client-v2: nombre, correo, teléfono +52,
/// contraseña + opt-in de newsletter. Incluye el sheet "¿Eres tú?" (AccountMatch).
public struct CreateAccountView: View {
    @State private var viewModel: CreateAccountViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case name, email, phone, password }

    public init(viewModel: CreateAccountViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer().frame(height: 18)
                    field(label: "NOMBRE COMPLETO", text: $viewModel.fullName,
                          placeholder: "Juan Ramírez", field: .name)
                    field(label: "CORREO ELECTRÓNICO", text: $viewModel.email,
                          placeholder: "tu@correo.com", field: .email,
                          keyboard: .emailAddress, autocap: false)
                    field(label: "TELÉFONO", text: $viewModel.phoneDisplay,
                          placeholder: "443 123 4567", field: .phone,
                          prefix: "+52", keyboard: .numberPad,
                          hint: "Te mandaremos un código por SMS",
                          formatPhone: true)
                    field(label: "CONTRASEÑA", text: $viewModel.password,
                          placeholder: "Mínimo 8 caracteres", field: .password,
                          secure: true, autocap: false)
                    Spacer().frame(height: 14)
                    newsletterRow
                    if let err = viewModel.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(TreggaColors.danger)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 130)
            }
            footer
        }
        .background(TreggaColors.bg)
        .sheet(isPresented: Binding(
            get: { viewModel.coordinator?.showAccountMatch ?? false },
            set: { viewModel.coordinator?.showAccountMatch = $0 }
        )) {
            AccountMatchSheet(viewModel: viewModel)
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            Button { viewModel.coordinator?.goToWelcome() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TreggaColors.text)
                    .frame(width: 40, height: 40)
                    .background(TreggaColors.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text("Crear cuenta")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                Text("Solo te toma un minuto")
                    .font(.system(size: 13))
                    .foregroundStyle(TreggaColors.textSec)
            }
            .padding(.leading, 6)
            Spacer()
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func field(
        label: String,
        text: Binding<String>,
        placeholder: String,
        field: Field,
        prefix: String? = nil,
        secure: Bool = false,
        keyboard: UIKeyboardType = .default,
        autocap: Bool = true,
        hint: String? = nil,
        formatPhone: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.2)
                .foregroundStyle(TreggaColors.textSec)
            HStack(spacing: 10) {
                if let prefix {
                    Text(prefix)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TreggaColors.textSec)
                }
                Group {
                    if secure {
                        SecureField(placeholder, text: text)
                    } else {
                        TextField(placeholder, text: text)
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap ? .words : .never)
                .autocorrectionDisabled(true)
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { _, new in
                    if formatPhone {
                        let f = PhoneFormatter.format(new)
                        if f != new { text.wrappedValue = f }
                    }
                }
                if !text.wrappedValue.isEmpty {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TreggaColors.primary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(TreggaColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(text.wrappedValue.isEmpty ? Color.clear : TreggaColors.primary, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(TreggaColors.textTer)
            }
        }
        .padding(.bottom, 14)
    }

    private var newsletterRow: some View {
        Button { viewModel.newsletterOptIn.toggle() } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(viewModel.newsletterOptIn ? TreggaColors.primary : TreggaColors.surface2)
                    if viewModel.newsletterOptIn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                Text("Quiero recibir ofertas y novedades por correo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TreggaColors.text)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(14)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button { Task { await viewModel.crearCuenta() } } label: {
                HStack(spacing: 8) {
                    Text(viewModel.loading ? "Creando..." : "Crear cuenta")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                    if !viewModel.loading {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(viewModel.canSubmit ? TreggaColors.primary : TreggaColors.primary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!viewModel.canSubmit || viewModel.loading)

            Button { viewModel.coordinator?.goToWelcome() } label: {
                HStack(spacing: 4) {
                    Text("¿Ya tienes cuenta?")
                        .font(.system(size: 13))
                        .foregroundStyle(TreggaColors.textSec)
                    Text("Inicia sesión")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(TreggaColors.primary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 34)
        .padding(.top, 10)
        .background(TreggaColors.bg)
    }
}

/// Sheet "¿Eres tú?" (ScreenAccountMatch): se muestra cuando el teléfono
/// ingresado ya tiene una cuenta cliente existente.
private struct AccountMatchSheet: View {
    let viewModel: CreateAccountViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 10)
            Text("¿Eres tú?")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
            Text("Encontramos una cuenta existente con este número de teléfono.")
                .font(.system(size: 14.5))
                .foregroundStyle(TreggaColors.textSec)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 24)

            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(TreggaColors.primary)
                    Text(initials)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.fullName.isEmpty ? "Cuenta existente" : viewModel.fullName)
                        .font(.system(size: 15.5, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                    Text(viewModel.phoneE164)
                        .font(.system(size: 13))
                        .foregroundStyle(TreggaColors.textSec)
                }
                Spacer()
            }
            .padding(14)
            .background(TreggaColors.surface)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.top, 22)

            Button { Task { await viewModel.confirmAccountMatch() } } label: {
                HStack(spacing: 8) {
                    Text("Sí, soy yo")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(TreggaColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            Button { viewModel.coordinator?.showAccountMatch = false } label: {
                Text("No, no soy yo")
                    .font(.system(size: 14.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
            }
            .padding(.top, 14)
            Spacer()
        }
        .background(TreggaColors.bg)
    }

    private var initials: String {
        let parts = viewModel.fullName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

#Preview {
    CreateAccountView(viewModel: CreateAccountViewModel(authService: MockAuthService(), coordinator: nil))
}
