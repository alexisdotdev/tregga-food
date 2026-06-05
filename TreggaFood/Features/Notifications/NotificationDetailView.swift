import SwiftUI
import TreggaCore
import TreggaDesignSystem

// MARK: - Estilo por tipo

/// Estilo visual de cada tipo de notificación (etiqueta, icono, color y degradado
/// del hero del detalle), para que lista y detalle se vean coherentes.
extension Notificacion.Tipo {
    var displayLabel: String {
        switch self {
        case .info:   return "INFORMACIÓN"
        case .alert:  return "AVISO"
        case .system: return "SISTEMA"
        }
    }

    var icono: TreggaIcon.Name {
        switch self {
        case .info:   return .bell
        case .alert:  return .warning
        case .system: return .settings
        }
    }

    var tint: Color {
        switch self {
        case .info:   return TreggaColors.primary
        case .alert:  return TreggaColors.accent
        case .system: return Color(red: 0.294, green: 0.353, blue: 0.471)
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .info:
            return [TreggaColors.primary, TreggaColors.primaryDark, TreggaColors.primaryDeep]
        case .alert:
            return [Color(red: 1.0, green: 0.478, blue: 0.239),
                    Color(red: 0.949, green: 0.329, blue: 0.110),
                    Color(red: 0.761, green: 0.224, blue: 0.055)]
        case .system:
            return [Color(red: 0.294, green: 0.353, blue: 0.471),
                    Color(red: 0.212, green: 0.259, blue: 0.361),
                    Color(red: 0.137, green: 0.173, blue: 0.247)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Detalle

/// Detalle de una notificación: hero con la ilustración + cuerpo. Header con
/// "Inbox" + un único CTA para **eliminar** la notificación.
struct NotificationDetailView: View {
    let notificacion: Notificacion
    let onEliminar: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer().frame(height: 12)
                heroBanner
                Spacer().frame(height: 16)
                messageBody
                Spacer().frame(height: 80)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                ZStack {
                    Circle().fill(TreggaColors.surface).frame(width: 40, height: 40)
                    TreggaIcon(.chevL, size: 20, color: TreggaColors.text)
                }
            }
            .buttonStyle(.plain)

            Text("Inbox")
                .treggaStyle(.h3)
                .foregroundStyle(TreggaColors.text)

            Spacer()

            Button {
                onEliminar()
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(TreggaColors.surface)
                        .overlay(Circle().stroke(TreggaColors.border, lineWidth: 1))
                        .frame(width: 40, height: 40)
                    TreggaIcon(.trash, size: 17, color: TreggaColors.danger)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            notificacion.kind.gradient
            RadialGradient(
                colors: [Color.white.opacity(0.22), Color.clear],
                center: .init(x: 0.85, y: 0.1),
                startRadius: 0,
                endRadius: 220
            )
            .allowsHitTesting(false)

            Image("mail-illustration")
                .resizable()
                .scaledToFit()
                .frame(height: 168)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.trailing, -10)
                .padding(.top, -6)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                TreggaIcon(notificacion.kind.icono, size: 20, color: .white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(notificacion.kind.displayLabel)
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(notificacion.title)
                        .font(.system(size: 24, weight: .heavy))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(minHeight: 196, alignment: .bottomLeading)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var messageBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TREGGA · \(notificacion.cuando)")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.3)
                .foregroundStyle(notificacion.kind.tint)

            if let body = notificacion.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(TreggaColors.text)
                    .lineSpacing(14.5 * 0.65)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
    }
}
