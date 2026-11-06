import SwiftUI
import TreggaDesignSystem

/// Fila de un pedido Costco en "Mis pedidos".
struct CostcoOrderRow: View {
    let pedido: CostcoPedido

    var body: some View {
        HStack(spacing: 12) {
            TreggaIcon(.box, size: 22, color: TreggaColors.primaryDark)
                .frame(width: 44, height: 44)
                .background(TreggaColors.primarySoft, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
            VStack(alignment: .leading, spacing: 3) {
                Text(CostcoCopy.estado(pedido.estado).titulo)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                Text("\(CostcoCopy.viajeDel(CostcoFormat.fechaCorta(dia: pedido.fechaViaje))) · \(CostcoCopy.filaCostco(productos: pedido.items.filter { $0.sustitutoDe == nil }.count))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TreggaColors.textSec)
                if !pedido.pendientesDeDecision.isEmpty {
                    Text(CostcoCopy.noEncontradoBanner)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TreggaColors.accent)
                }
            }
            Spacer(minLength: 0)
            Text(PriceFormat.pesos(pedido.totalReal ?? pedido.totalEstimado))
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
        }
        .padding(14)
        .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.xl))
    }
}
