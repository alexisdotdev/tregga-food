import SwiftUI
import TreggaDesignSystem

/// Encabezado de subpantalla con botón atrás (dismiss) y título.
struct AccountHeader: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(TreggaColors.surface)
                        .frame(width: 40, height: 40)
                    TreggaIcon(.chevL, size: 20, color: TreggaColors.text)
                }
            }
            .buttonStyle(.plain)
            Text(title)
                .treggaStyle(.h3)
                .foregroundStyle(TreggaColors.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

/// Fila de navegación dentro de una tarjeta agrupada.
struct AccountNavRow: View {
    let icon: TreggaIcon.Name
    let label: String
    var sub: String? = nil
    var tail: String? = nil
    var danger: Bool = false
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(danger ? TreggaColors.dangerBg : TreggaColors.surface)
                    .frame(width: 34, height: 34)
                TreggaIcon(icon, size: 18, color: danger ? TreggaColors.danger : TreggaColors.text)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(danger ? TreggaColors.danger : TreggaColors.text)
                if let sub {
                    Text(sub)
                        .font(.system(size: 12.5))
                        .foregroundStyle(TreggaColors.textSec)
                }
            }
            Spacer(minLength: 8)
            if let tail {
                Text(tail)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TreggaColors.textSec)
            }
            if showChevron {
                TreggaIcon(.chevR, size: 18, color: TreggaColors.textSec)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

/// Tarjeta que agrupa filas con divisores entre ellas.
struct AccountCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(TreggaColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
    }
}

/// Fila con toggle (sonidos, privacidad, notificaciones).
struct AccountToggleRow: View {
    let icon: TreggaIcon.Name?
    let label: String
    var sub: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(TreggaColors.surface)
                        .frame(width: 34, height: 34)
                    TreggaIcon(icon, size: 18, color: TreggaColors.text)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(TreggaColors.text)
                if let sub {
                    Text(sub)
                        .font(.system(size: 12.5))
                        .foregroundStyle(TreggaColors.textSec)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(TreggaColors.primary)
        }
        .padding(.vertical, 12)
    }
}

/// Divisor fino para separar filas dentro de una tarjeta.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(TreggaColors.divider)
            .frame(height: 1)
            .padding(.leading, 14)
    }
}
