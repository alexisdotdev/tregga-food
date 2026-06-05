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

/// Pestaña 📍: mapa de discovery con los negocios disponibles como pines. Tap en
/// un pin → tarjeta del negocio → abrir su menú. Vacío donde no hay negocios.
struct MapaNegociosView: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.cartStore) private var cartEnv
    @Environment(\.clientShell) private var shell

    @State private var viewModel: MapaNegociosViewModel
    @State private var mapController = MapController()
    @State private var path: [CatalogRoute] = []
    @State private var seleccionado: Negocio?
    @State private var center: TrackCoord?

    private let catalog: CatalogRepository
    private var cart: CartStore { cartEnv ?? CartStore() }

    init(catalog: CatalogRepository) {
        self.catalog = catalog
        _viewModel = State(initialValue: MapaNegociosViewModel(catalog: catalog))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                NegociosMapView(
                    negocios: viewModel.conCoords,
                    center: center,
                    onSelect: { seleccionado = $0 },
                    controller: mapController
                )
                .ignoresSafeArea()
                .overlay(alignment: .bottomTrailing) { mapControls }

                topBar

                if let negocio = seleccionado {
                    negocioCard(negocio)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if viewModel.conCoords.isEmpty && !viewModel.loading {
                    emptyCard
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: seleccionado)
            .navigationDestination(for: CatalogRoute.self) { route in
                destination(for: route)
                    .onAppear { shell?.barHidden = true }
                    .onDisappear { shell?.barHidden = false }
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

    // MARK: - Overlays

    private var topBar: some View {
        VStack {
            HStack(spacing: 10) {
                TreggaIcon(.pin, size: 18, color: TreggaColors.primary)
                Text(viewModel.conCoords.isEmpty ? "Negocios cerca de ti" : "\(viewModel.conCoords.count) negocios cerca")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(TreggaColors.card, in: Capsule())
            .overlay(Capsule().stroke(TreggaColors.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }

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
        .padding(.bottom, seleccionado != nil ? 200 : 120)
    }

    private func mapControlButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TreggaIcon(sfSymbol: icon, size: 16, color: TreggaColors.text)
                .frame(width: 42, height: 42)
                .treggaGlass(in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func negocioCard(_ negocio: Negocio) -> some View {
        Button { path.append(.restaurant(negocio)) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(TreggaColors.primarySoft).frame(width: 54, height: 54)
                    TreggaIcon(.bag, size: 26, color: TreggaColors.primary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(negocio.name)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                        .lineLimit(1)
                    if let tipo = negocio.tipo {
                        Text(tipo)
                            .font(.system(size: 13))
                            .foregroundStyle(TreggaColors.textSec)
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            TreggaIcon(.star, size: 12, color: TreggaColors.warning)
                            Text(negocio.ratingLabel)
                                .font(.system(size: 12.5, weight: .heavy))
                                .foregroundStyle(TreggaColors.text)
                        }
                        Text("·").foregroundStyle(TreggaColors.textTer)
                        Text(negocio.tiempoLabel)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TreggaColors.textSec)
                    }
                }
                Spacer(minLength: 4)
                TreggaIcon(.chevR, size: 20, color: TreggaColors.textTer)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TreggaColors.bg)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 18, y: -2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.bottom, 92)
    }

    private var emptyCard: some View {
        VStack(spacing: 6) {
            Text("No hay negocios en esta zona todavía")
                .font(.system(size: 15, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.text)
            Text("Irán apareciendo conforme se den de alta cerca de ti.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(TreggaColors.bg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -2)
        .padding(.horizontal, 14)
        .padding(.bottom, 92)
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
