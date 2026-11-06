import SwiftUI
import TreggaDesignSystem

/// Piezas visuales comunes del flujo Costco.
enum CostcoUI {
    static func backButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TreggaIcon(.chevL, size: 20, color: TreggaColors.text)
                .frame(width: 40, height: 40)
                .background(TreggaColors.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Atrás")
    }

    static func header(_ titulo: String, subtitulo: String? = nil, onBack: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            backButton(onBack)
            Text(titulo)
                .treggaStyle(.h2)
                .foregroundStyle(TreggaColors.text)
                .padding(.top, 8)
            if let subtitulo {
                Text(subtitulo)
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    static func row(_ label: String, _ value: String, fuerte: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: fuerte ? .heavy : .medium))
                .foregroundStyle(fuerte ? TreggaColors.text : TreggaColors.textSec)
            Spacer()
            Text(value)
                .font(.system(size: fuerte ? 17 : 15, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
        }
    }

    static func banner(_ texto: String, icon: TreggaIcon.Name = .info, tono: Color = TreggaColors.primary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            TreggaIcon(icon, size: 18, color: tono)
            Text(texto)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TreggaColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(tono.opacity(0.10), in: RoundedRectangle(cornerRadius: TreggaRadius.lg))
    }

    static func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.xl))
    }
}

/// Stepper compacto − n +.
struct CostcoStepper: View {
    let cantidad: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            boton(.minus) { onChange(cantidad - 1) }
            Text("\(cantidad)")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
                .frame(minWidth: 28)
            boton(.plus) { onChange(cantidad + 1) }
                .disabled(cantidad >= CostcoCartStore.maxCantidad)
        }
        .background(TreggaColors.surface, in: Capsule())
    }

    private func boton(_ icon: TreggaIcon.Name, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TreggaIcon(icon, size: 16, color: TreggaColors.text).frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }
}
