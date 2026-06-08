import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pestaña "Buscar" (Explorar). Placeholder de la grilla de categorías, pero con
/// la barra de búsqueda ya funcional (enfocable, abre el teclado).
struct BuscarTabView: View {
    @State private var query = ""
    @FocusState private var searchFocused: Bool

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

            SearchBar(text: $query, placeholder: "Carnitas, pizza, tacos…")
                .focused($searchFocused)
                .padding(.horizontal, 16)
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
            .contentShape(Rectangle())
            .onTapGesture { searchFocused = false }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TreggaColors.bg)
        .keyboardDoneToolbar()
    }
}
