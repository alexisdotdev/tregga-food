import SwiftUI
import TreggaDesignSystem

/// Pantalla ScreenPermissionExplainer del diseño client-v2. Explica por qué
/// pedimos ubicación antes de disparar el diálogo nativo de iOS. No solicita
/// el permiso por sí misma: invoca callbacks para que el caller decida cuándo
/// llamar a CoreLocation (se conectará en F2).
public struct PermissionExplainerView: View {
    private let onAllow: () -> Void
    private let onManual: () -> Void
    private let onClose: () -> Void

    public init(
        onAllow: @escaping () -> Void,
        onManual: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        self.onAllow = onAllow
        self.onManual = onManual
        self.onClose = onClose
    }

    private struct Perk: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let sub: String
    }

    private let perks: [Perk] = [
        Perk(icon: "mappin.and.ellipse", title: "Negocios cerca de ti",
             sub: "Ordena de restaurantes que pueden llegar rápido"),
        Perk(icon: "shippingbox.fill", title: "Tracking en tiempo real",
             sub: "Mira dónde va tu repartidor en el mapa"),
        Perk(icon: "clock.fill", title: "Tiempo estimado preciso",
             sub: "Mejor cálculo de cuándo recibes tu pedido"),
    ]

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(TreggaColors.text)
                                .frame(width: 36, height: 36)
                                .background(TreggaColors.surface)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    ZStack {
                        RoundedRectangle(cornerRadius: 22).fill(TreggaColors.primarySoft)
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(TreggaColors.primaryDeep)
                    }
                    .frame(width: 76, height: 76)
                    .padding(.top, 8)

                    Text("Tu ubicación nos ayuda a entregarte")
                        .font(.system(size: 28, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(TreggaColors.text)
                        .padding(.top, 22)

                    Text("Necesitamos tu ubicación para mostrarte negocios cerca, calcular costos de envío y guiar al repartidor hasta tu puerta.")
                        .font(.system(size: 14.5))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineSpacing(2)
                        .padding(.top, 10)

                    VStack(spacing: 0) {
                        ForEach(perks) { perk in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle().fill(TreggaColors.primarySoft)
                                    Image(systemName: perk.icon)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(TreggaColors.primaryDark)
                                }
                                .frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(perk.title)
                                        .font(.system(size: 14, weight: .heavy))
                                        .foregroundStyle(TreggaColors.text)
                                    Text(perk.sub)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(TreggaColors.textSec)
                                        .lineSpacing(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .overlay(alignment: .top) {
                                Rectangle().fill(TreggaColors.divider).frame(height: 1)
                            }
                        }
                    }
                    .padding(.top, 22)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
            }

            VStack(spacing: 12) {
                Button(action: onAllow) {
                    HStack(spacing: 8) {
                        Text("Permitir ubicación")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(TreggaColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button(action: onManual) {
                    Text("Ingresar dirección manualmente")
                        .font(.system(size: 13.5, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .background(TreggaColors.bg)
        }
        .background(TreggaColors.bg)
    }
}

#Preview {
    PermissionExplainerView(onAllow: {})
}
