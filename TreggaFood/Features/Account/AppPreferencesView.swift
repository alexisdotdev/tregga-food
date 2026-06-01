import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Preferencias de la app: apariencia (claro/oscuro/automático, local) +
/// sonidos/vibración/audio de tracking sobre `preferencias_usuario`.
struct AppPreferencesView: View {
    @Bindable var viewModel: AccountViewModel
    @AppStorage("APPEARANCE_MODE") private var appearanceRaw: String = AppearanceMode.system.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Preferencias")

                SectionHeader("Apariencia").padding(.top, 8)
                HStack(spacing: 8) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        opcionApariencia(mode)
                    }
                }
                .padding(.horizontal, 16)

                SectionHeader("Sonidos y movimiento").padding(.top, 18)
                VStack(spacing: 0) {
                    AccountToggleRow(icon: .bell, label: "Sonidos de la app",
                                     sub: "Confirmaciones y notificaciones.",
                                     isOn: bind(\.soundsEnabled))
                    RowDivider()
                    AccountToggleRow(icon: .phone, label: "Vibración",
                                     sub: "En notificaciones y errores.",
                                     isOn: bind(\.vibrationEnabled))
                    RowDivider()
                    AccountToggleRow(icon: .message, label: "Audio de seguimiento",
                                     sub: "Te avisa por voz cuando llega tu pedido.",
                                     isOn: bind(\.voiceAnnouncements))
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
    }

    private func opcionApariencia(_ mode: AppearanceMode) -> some View {
        let on = appearance == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { appearanceRaw = mode.rawValue }
        } label: {
            VStack(spacing: 3) {
                Text(mode.label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(on ? TreggaColors.primaryDeep : TreggaColors.text)
                Text(mode.sub)
                    .font(.system(size: 10.5))
                    .foregroundStyle(on ? TreggaColors.primaryDark : TreggaColors.textSec)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(on ? TreggaColors.primarySoft : TreggaColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(on ? TreggaColors.primary : TreggaColors.border, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
