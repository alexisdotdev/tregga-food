import SwiftUI
import TreggaDesignSystem

/// Pantalla de candado biométrico. Se muestra en lugar del contenido cuando el
/// candado está activo y hay sesión. Auto-dispara Face ID al aparecer; si falla
/// o se cancela, queda en estado de reintento (no saca al usuario solo). El
/// botón "Usar otra cuenta" es el camino de salida → logout → login por OTP.
struct BiometricLockView: View {
    let kind: BiometricKind
    let onUnlock: () async -> Void
    let onUseOtherAccount: () async -> Void

    @State private var failed = false
    @State private var working = false

    private var biometricLabel: String { kind == .touchID ? "Touch ID" : "Face ID" }
    private var biometricIcon: String { kind == .touchID ? "touchid" : "faceid" }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            TreggaIcon(sfSymbol: biometricIcon, size: 64, color: TreggaColors.primary)

            Spacer().frame(height: 24)

            Text("Tregga")
                .treggaStyle(.h2)
                .foregroundStyle(TreggaColors.text)

            Spacer().frame(height: 8)

            Text(failed
                 ? "No pudimos verificarte. Intenta de nuevo."
                 : "Desbloquea para continuar")
                .font(.system(size: 14.5))
                .foregroundStyle(failed ? TreggaColors.danger : TreggaColors.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 14) {
                TreggaButton("Usar \(biometricLabel)", kind: .primary) {
                    Task { await runUnlock() }
                }
                .disabled(working)

                Button {
                    Task { await onUseOtherAccount() }
                } label: {
                    Text("Usar otra cuenta")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TreggaColors.textSec)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TreggaColors.bg)
        .task { await runUnlock() }
    }

    private func runUnlock() async {
        guard !working else { return }
        working = true
        await onUnlock()
        // Si seguimos aquí (la vista no se reemplazó), la autenticación falló.
        failed = true
        working = false
    }
}
