import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pestaña "Buscar" (Explorar). Placeholder hasta portar la grilla de categorías
/// del diseño; mantiene el encabezado y la barra de búsqueda.
struct BuscarTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Explorar")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(TreggaColors.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            SearchBar(placeholder: "Carnitas, pizza, tacos…")
                .padding(.top, 12)

            VStack(spacing: 12) {
                TreggaIcon(.search, size: 40, color: TreggaColors.textTer)
                Text("Pronto podrás explorar por tipo de comida")
                    .font(.system(size: 14.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TreggaColors.textSec)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TreggaColors.bg)
    }
}
