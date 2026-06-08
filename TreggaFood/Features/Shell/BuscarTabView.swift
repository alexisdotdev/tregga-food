import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pestaña "Buscar" (Explorar): búsqueda real de negocios por nombre o tipo de
/// comida. Filtra en el cliente sobre la lista de negocios disponibles y navega
/// al restaurante con el mismo flujo de descubrimiento que Home.
struct BuscarTabView: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.cartStore) private var cartEnv
    @State private var path: [CatalogRoute] = []
    @State private var query = ""
    @State private var negocios: [Negocio] = []
    @FocusState private var searchFocused: Bool

    private var catalog: CatalogRepository { deps?.catalogRepository ?? MockCatalogRepository() }
    private var cart: CartStore { cartEnv ?? CartStore() }

    private var queryLimpia: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resultados: [Negocio] {
        let q = queryLimpia.lowercased()
        guard !q.isEmpty else { return [] }
        return negocios.filter {
            $0.name.lowercased().contains(q) || ($0.tipo?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Explorar")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(TreggaColors.text)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                SearchBar(text: $query, placeholder: "Carnitas, pizza, tacos…")
                    .focused($searchFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(TreggaColors.bg)
            .navigationDestination(for: CatalogRoute.self) { route in destination(for: route) }
        }
        .task { if negocios.isEmpty { negocios = (try? await catalog.fetchNegociosDisponibles()) ?? [] } }
        .keyboardDoneToolbar()
    }

    @ViewBuilder
    private var content: some View {
        if queryLimpia.isEmpty {
            estado(icon: .search, titulo: "Busca lo que se te antoje",
                   sub: "Escribe el nombre de un negocio o tipo de comida (tacos, pizza, sushi…).")
        } else if resultados.isEmpty {
            estado(icon: .info, titulo: "Sin resultados",
                   sub: "No encontramos negocios para “\(queryLimpia)”.")
        } else {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(resultados) { negocio in
                        Button { path.append(.restaurant(negocio)) } label: {
                            FoodCard(negocio: negocio)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func estado(icon: TreggaIcon.Name, titulo: String, sub: String) -> some View {
        VStack(spacing: 12) {
            TreggaIcon(icon, size: 40, color: TreggaColors.textTer)
            Text(titulo)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(TreggaColors.text)
            Text(sub)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func destination(for route: CatalogRoute) -> some View {
        switch route {
        case .restaurant(let negocio):
            RestaurantView(negocio: negocio, catalog: catalog, path: $path)
        case .itemDetail(let producto, let negocioName):
            ItemDetailView(
                producto: producto,
                negocioName: negocioName,
                catalog: catalog,
                onAdd: { selection in
                    cart.add(selection: selection, negocioId: producto.negocioId, negocioName: negocioName)
                    path.removeLast()
                }
            )
        case .cart, .checkout, .tracking, .chat:
            EmptyView()
        }
    }
}
