import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pestaña "Buscar" (Explorar): búsqueda real de negocios por nombre o tipo de
/// comida. Filtra en el cliente sobre la lista de negocios disponibles y navega
/// al restaurante con el mismo flujo de descubrimiento que Home.
struct BuscarTabView: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.cartStore) private var cartEnv
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [CatalogRoute] = []
    @State private var query = ""
    @State private var negocios: [Negocio] = []
    @State private var categoria: BusinessCategory?
    @FocusState private var searchFocused: Bool

    private var catalog: CatalogRepository { deps?.catalogRepository ?? MockCatalogRepository() }
    private var cart: CartStore { cartEnv ?? CartStore() }

    private var queryLimpia: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Hay un filtro activo (texto o categoría) → mostramos resultados.
    private var hayFiltro: Bool { !queryLimpia.isEmpty || categoria != nil }

    /// Solo las categorías que tienen al menos un negocio disponible, en el
    /// orden canónico del catálogo compartido.
    private var categoriasDisponibles: [BusinessCategory] {
        let presentes = Set(negocios.compactMap { BusinessCategory.resolve($0.tipo)?.id })
        return BusinessCategory.all.filter { presentes.contains($0.id) }
    }

    private var resultados: [Negocio] {
        var base = negocios
        if let categoria {
            base = base.filter { BusinessCategory.resolve($0.tipo)?.id == categoria.id }
        }
        let q = queryLimpia.lowercased()
        if !q.isEmpty {
            base = base.filter {
                $0.name.lowercased().contains(q) || ($0.tipo?.lowercased().contains(q) ?? false)
            }
        }
        return base
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

                if !categoriasDisponibles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categoriasDisponibles) { cat in
                                Chip("\(cat.emoji) \(cat.label)", isActive: categoria?.id == cat.id) {
                                    categoria = (categoria?.id == cat.id) ? nil : cat
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 12)
                }

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(TreggaColors.bg)
            .navigationDestination(for: CatalogRoute.self) { route in destination(for: route) }
        }
        .task { if negocios.isEmpty { negocios = (try? await catalog.fetchNegociosDisponibles()) ?? [] } }
        // Recarga al volver al frente para no mostrar disponibilidad vieja
        // (Home tiene realtime; Buscar al menos se refresca al reactivar la app).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { negocios = (try? await catalog.fetchNegociosDisponibles()) ?? negocios }
            }
        }
        .keyboardDismissToolbar()
    }

    @ViewBuilder
    private var content: some View {
        if !hayFiltro {
            estado(icon: .search, titulo: "Busca lo que se te antoje",
                   sub: "Elige una categoría o escribe el nombre de un negocio o tipo de comida.")
        } else if resultados.isEmpty {
            estado(icon: .info, titulo: "Sin resultados",
                   sub: queryLimpia.isEmpty
                        ? "No hay negocios en \(categoria?.label ?? "esta categoría") por ahora."
                        : "No encontramos negocios para “\(queryLimpia)”.")
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
