import SwiftUI
import TreggaDesignSystem

/// Estado neutro reutilizable: ícono grande (Hugeicons) + título + subtítulo +
/// CTA opcional. Base de los estados edge (sin conexión, mantenimiento, etc.).
struct NeutralStateView: View {
    let icon: TreggaIcon.Name
    let title: String
    let subtitle: String
    var iconBg: Color = TreggaColors.surface
    var iconFg: Color = TreggaColors.textSec
    var code: String? = nil
    var footer: String? = nil
    var primaryCta: String? = nil
    var onPrimary: (() -> Void)? = nil
    var secondaryCta: String? = nil
    var onSecondary: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(iconBg).frame(width: 84, height: 84)
                TreggaIcon(icon, size: 42, color: iconFg)
            }
            Text(title)
                .treggaStyle(.h2)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.text)
                .padding(.top, 24)
            Text(subtitle)
                .font(.system(size: 14.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.top, 12)
                .frame(maxWidth: 320)

            if let code {
                Text(code)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(TreggaColors.textSec)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(TreggaColors.border, lineWidth: 1))
                    .padding(.top, 20)
            }

            if let primaryCta {
                TreggaButton(primaryCta) { onPrimary?() }
                    .padding(.top, 28)
                    .frame(maxWidth: 340)
            }
            if let secondaryCta {
                Button { onSecondary?() } label: {
                    Text(secondaryCta)
                        .font(.system(size: 13.5, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
            if let footer {
                Text(footer)
                    .font(.system(size: 11.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TreggaColors.textTer)
                    .padding(.top, 18)
                    .frame(maxWidth: 320)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

/// Sin conexión. Usable como fallback cuando una carga de red falla.
struct NoConnectionView: View {
    var message: String = "No podemos cargar el contenido sin conexión. Revisa tu Wi-Fi o datos móviles e intenta de nuevo."
    var onRetry: (() -> Void)? = nil

    var body: some View {
        NeutralStateView(
            icon: .refresh,
            title: "Sin conexión a internet",
            subtitle: message,
            primaryCta: onRetry != nil ? "Reintentar" : nil,
            onPrimary: onRetry
        )
    }
}

/// Mantenimiento programado.
struct MaintenanceView: View {
    var onRetry: (() -> Void)? = nil
    var body: some View {
        NeutralStateView(
            icon: .info,
            title: "Tregga está en mantenimiento",
            subtitle: "Estamos haciendo mejoras al sistema. Mientras tanto, no podrás hacer pedidos nuevos.",
            code: "VOLVEMOS PRONTO",
            footer: "Los pedidos en curso siguen normales.",
            primaryCta: "Reintentar",
            onPrimary: onRetry
        )
    }
}

/// Actualización forzada de versión.
struct ForceUpdateView: View {
    var onUpdate: (() -> Void)? = nil
    var body: some View {
        NeutralStateView(
            icon: .refresh,
            title: "Actualiza Tregga para continuar",
            subtitle: "Esta versión ya no es compatible. Necesitas actualizar antes de seguir pidiendo.",
            iconBg: TreggaColors.primarySoft,
            iconFg: TreggaColors.primaryDark,
            footer: "No podemos garantizar la seguridad de tus datos en versiones viejas.",
            primaryCta: "Ir a la App Store",
            onPrimary: onUpdate
        )
    }
}

#Preview("Sin conexión") {
    NoConnectionView(onRetry: {}).frame(maxHeight: .infinity).background(TreggaColors.bg)
}

#Preview("Mantenimiento") {
    MaintenanceView(onRetry: {}).frame(maxHeight: .infinity).background(TreggaColors.bg)
}

#Preview("Actualizar") {
    ForceUpdateView(onUpdate: {}).frame(maxHeight: .infinity).background(TreggaColors.bg)
}
