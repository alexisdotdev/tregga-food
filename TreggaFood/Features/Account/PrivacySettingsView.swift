import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Privacidad: control de ubicación y datos compartidos (sobre
/// `preferencias_usuario`) + acceso a eliminar cuenta.
struct PrivacySettingsView: View {
    @Bindable var viewModel: AccountViewModel
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Privacidad")

                SectionHeader("Tu ubicación").padding(.top, 8)
                VStack(spacing: 0) {
                    AccountToggleRow(icon: .pin, label: "Compartir ubicación en vivo",
                                     sub: "Permite a tu familia ver el tracking de tu pedido.",
                                     isOn: bind(\.shareLocationActive))
                    RowDivider()
                    AccountToggleRow(icon: .info, label: "Negocios cerca al abrir",
                                     sub: "Mostrar opciones cercanas sin pedirlo cada vez.",
                                     isOn: bind(\.shareLocationIdle))
                }
                .padding(.horizontal, 16)

                SectionHeader("Datos y diagnóstico").padding(.top, 8)
                VStack(spacing: 0) {
                    AccountToggleRow(icon: .grid, label: "Compartir datos de uso",
                                     sub: "Nos ayuda a mejorar la app.",
                                     isOn: bind(\.shareUsageData))
                    RowDivider()
                    AccountToggleRow(icon: .info, label: "Enviar reportes de error",
                                     sub: "Diagnósticos cuando algo falla.",
                                     isOn: bind(\.shareErrorReports))
                }
                .padding(.horizontal, 16)

                SectionHeader("Seguridad de la cuenta").padding(.top, 8)
                AccountCard {
                    Button(action: onDelete) {
                        AccountNavRow(icon: .trash, label: "Eliminar mi cuenta",
                                      sub: "Acción irreversible", danger: true)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .swipeBackToDismiss()
    }

    private func bind(_ key: WritableKeyPath<PreferenciasUsuario, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.prefs?[keyPath: key] ?? false },
            set: { nuevo in
                Task { await viewModel.actualizarPrefs { $0[keyPath: key] = nuevo } }
            }
        )
    }
}
