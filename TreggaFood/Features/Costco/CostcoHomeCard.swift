import SwiftUI
import TreggaDesignSystem

/// Entrada a Costco en el Home: estado del viaje en una línea. Visible también para invitados.
struct CostcoHomeCard: View {
    let model: CostcoFlowModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                TreggaIcon(.box, size: 26, color: TreggaColors.primaryDark)
                    .frame(width: 52, height: 52)
                    .background(TreggaColors.primarySoft, in: RoundedRectangle(cornerRadius: TreggaRadius.lg))
                VStack(alignment: .leading, spacing: 3) {
                    Text(CostcoCopy.homeTitulo)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                    Text(Self.subtitulo(model.estado))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(TreggaColors.textSec)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.puedePedir {
                        Text(CostcoCopy.homeSujeto)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(TreggaColors.accent)
                    }
                }
                Spacer(minLength: 0)
                TreggaIcon(.chevR, size: 18, color: TreggaColors.textTer)
            }
            .padding(14)
            .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.xl))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    static func subtitulo(_ estado: CostcoEstado?) -> String {
        guard let viaje = estado?.viaje else { return CostcoCopy.homeSinViaje }
        let dia = CostcoFormat.fechaCorta(dia: viaje.fechaViaje)
        if viaje.aceptaPedidos {
            return CostcoCopy.homeAbierto(viaje: dia, cierre: CostcoFormat.fechaHora(viaje.fechaCierre))
        }
        return CostcoCopy.homeConfirmado(viaje: dia)
    }
}
