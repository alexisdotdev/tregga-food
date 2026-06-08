import SwiftUI
import TreggaCore
import TreggaDesignSystem
import Observation

@MainActor
@Observable
final class MapaNegociosViewModel {
    private let catalog: CatalogRepository
    private(set) var negocios: [Negocio] = []
    private(set) var loading = true

    /// Solo los negocios con coordenadas (los que se pueden pinchar en el mapa).
    var conCoords: [Negocio] { negocios.filter { $0.lat != nil && $0.lng != nil } }

    init(catalog: CatalogRepository) {
        self.catalog = catalog
    }

    func cargar() async {
        negocios = (try? await catalog.fetchNegociosDisponibles()) ?? []
        loading = false
    }
}

/// Pestaña 📍: mapa de discovery con los negocios como pines + un drawer inferior
/// (estilo Uber) que lista los negocios; al levantarlo aparece el buscador. Tap en
/// un negocio → su menú.
struct MapaNegociosView: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.cartStore) private var cartEnv
    @Environment(\.clientShell) private var shell

    @State private var viewModel: MapaNegociosViewModel
    @State private var mapController = MapController()
    @State private var path: [CatalogRoute] = []
    @State private var center: TrackCoord?
    @State private var expanded = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private let catalog: CatalogRepository
    private var cart: CartStore { cartEnv ?? CartStore() }

    init(catalog: CatalogRepository) {
        self.catalog = catalog
        _viewModel = State(initialValue: MapaNegociosViewModel(catalog: catalog))
    }

    private var filtrados: [Negocio] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return viewModel.negocios }
        return viewModel.negocios.filter {
            $0.name.lowercased().contains(q) || ($0.tipo?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    NegociosMapView(
                        negocios: viewModel.conCoords,
                        center: center,
                        onSelect: { path.append(.restaurant($0)) },
                        controller: mapController
                    )
                    .ignoresSafeArea()
                    .overlay(alignment: .bottomTrailing) { mapControls }

                    drawer(maxHeight: geo.size.height)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: expanded)
                .navigationDestination(for: CatalogRoute.self) { route in
                    destination(for: route)
                }
                .onChange(of: path) { _, p in shell?.setDeep(.live, deep: !p.isEmpty) }
            }
        }
        .task {
            await resolverCentro()
            await viewModel.cargar()
        }
    }

    /// Centro del mapa = dirección activa del cliente (si tiene coordenadas).
    private func resolverCentro() async {
        guard center == nil, let deps, let uid = deps.authSession.tokens?.userId,
              let cid = try? await deps.clienteRepository.fetchByUserId(uid)?.id,
              let dirs = try? await deps.direccionRepository.fetchDelCliente(clienteId: cid),
              let activa = dirs.first(where: \.isDefault) ?? dirs.first,
              let la = activa.lat, let lo = activa.lng else { return }
        center = TrackCoord(lat: la, lng: lo)
    }

    // MARK: - Drawer

    @ViewBuilder
    private func drawer(maxHeight: CGFloat) -> some View {
        let peek: CGFloat = 280
        let full = max(peek, maxHeight * 0.9)
        VStack(spacing: 0) {
            // Zona "agarrable": handle + header + buscador (al expandir).
            VStack(spacing: 0) {
                Capsule()
                    .fill(TreggaColors.border)
                    .frame(width: 42, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Negocios cerca de ti")
                            .font(.system(size: 20, weight: .heavy))
                            .tracking(-0.3)
                            .foregroundStyle(TreggaColors.text)
                        Text(subtituloHeader)
                            .font(.system(size: 13))
                            .foregroundStyle(TreggaColors.textSec)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                if expanded {
                    SearchBar(text: $query, placeholder: "Busca un negocio o tipo de comida")
                        .focused($searchFocused)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
            }
            .padding(.bottom, 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { v in
                        if v.translation.height < -40 { expanded = true }
                        else if v.translation.height > 40 { expanded = false; searchFocused = false }
                    }
            )
            .onTapGesture { if !expanded { expanded = true } }

            lista
        }
        .frame(maxWidth: .infinity)
        .frame(height: expanded ? full : peek, alignment: .top)
        .background(TreggaColors.bg)
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .shadow(color: .black.opacity(0.16), radius: 20, y: -4)
    }

    private var subtituloHeader: String {
        if viewModel.loading { return "Cargando…" }
        let n = viewModel.negocios.count
        return n == 0 ? "Sin negocios en tu zona todavía" : "\(n) negocio\(n == 1 ? "" : "s") cerca de ti"
    }

    private var lista: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filtrados) { negocio in
                    Button { path.append(.restaurant(negocio)) } label: {
                        FoodCard(negocio: negocio)
                    }
                    .buttonStyle(.plain)
                }
                if filtrados.isEmpty && !viewModel.loading {
                    Text(query.isEmpty ? "No hay negocios disponibles." : "Sin resultados para “\(query)”.")
                        .font(.system(size: 14))
                        .foregroundStyle(TreggaColors.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .scrollDisabled(!expanded)
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Controles del mapa

    private var mapControls: some View {
        VStack(spacing: 8) {
            mapControlButton("plus") { mapController.zoomIn() }
            mapControlButton("minus") { mapController.zoomOut() }
            mapControlButton("location.fill") {
                mapController.recenter(to: viewModel.conCoords.compactMap { n in
                    guard let la = n.lat, let lo = n.lng else { return nil }
                    return TrackCoord(lat: la, lng: lo)
                })
            }
        }
        .padding(.trailing, 14)
        .padding(.bottom, 296)
    }

    private func mapControlButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TreggaIcon(sfSymbol: icon, size: 16, color: TreggaColors.text)
                .frame(width: 42, height: 42)
                .treggaGlass(in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navegación al restaurante (mismo flujo que Home)

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
                    if !path.isEmpty { path.removeLast() }
                }
            )
        case .cart, .checkout, .tracking, .chat:
            // El carrito vive en la pestaña Carrito (CartTabView).
            EmptyView()
        }
    }
}
