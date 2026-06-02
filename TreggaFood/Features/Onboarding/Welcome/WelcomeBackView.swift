import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pantalla de bienvenida para re-login biométrico (estilo Banamex). Aparece
/// cuando la sesión se cerró o venció pero el dispositivo recuerda al usuario:
/// saludo por hora + nombre, "Ingresar" con Face ID como acción primaria, y un
/// camino secundario para entrar con correo/teléfono.
struct WelcomeBackView: View {
    let displayName: String
    let kind: BiometricKind
    /// Devuelve true si el re-login biométrico tuvo éxito (la vista se reemplaza).
    let onIngresar: () async -> Bool
    let onUseAccount: () -> Void

    @State private var working = false
    @State private var failed = false

    private var biometricLabel: String { kind == .touchID ? "Touch ID" : "Face ID" }
    private var biometricIcon: String { kind == .touchID ? "touchid" : "faceid" }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default:      return "Buenas noches"
        }
    }

    private var firstName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 24)

            Image("logo-tregga")
                .resizable()
                .scaledToFit()
                .frame(height: 38)

            Spacer()

            Text("\(greeting),")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
            Text(firstName.isEmpty ? "de nuevo" : firstName)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(TreggaColors.text)

            Spacer().frame(height: 28)

            Button {
                Task { await run() }
            } label: {
                HStack(spacing: 12) {
                    Spacer()
                    Text(working ? "Verificando…" : "Ingresar")
                        .font(.system(size: 17, weight: .heavy))
                    Spacer()
                    TreggaIcon(sfSymbol: biometricIcon, size: 24, color: .white)
                }
                .foregroundStyle(.white)
                .padding(.vertical, 18)
                .padding(.horizontal, 22)
                .background(TreggaColors.primary, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(working)

            if failed {
                Text("No pudimos verificarte. Intenta de nuevo o ingresa con tu cuenta.")
                    .font(.system(size: 13))
                    .foregroundStyle(TreggaColors.danger)
                    .padding(.top, 12)
            }

            Spacer().frame(height: 18)

            Button(action: onUseAccount) {
                Text("Ingresar con correo o teléfono")
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.primaryDeep)
            }
            .buttonStyle(.plain)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(TreggaColors.bg)
        .task { await run() }
    }

    private func run() async {
        guard !working else { return }
        working = true
        failed = false
        let ok = await onIngresar()
        // Si seguimos aquí, falló (la vista no se reemplazó).
        if !ok { failed = true }
        working = false
    }
}
