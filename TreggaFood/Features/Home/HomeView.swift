import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pantalla de inicio (discovery): ubicación + búsqueda + lista de negocios.
struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var path: [CatalogRoute] = []
    @State private var clienteId: UUID?
    @State private var direccionDefault: DireccionCliente?
    @State private var showNotifications = false
    @State private var showOffers = false
    @State private var showDirecciones = false
    @State private var noLeidas = 0
    private let catalog: CatalogRepository

    @Environment(\.cartStore) private var cartEnv
    @Environment(\.appDependencies) private var deps
    @Environment(\.clientShell) private var shell

    init(catalog: CatalogRepository) {
        self.catalog = catalog
        _viewModel = State(initialValue: HomeViewModel(repository: catalog))
    }

    private var cart: CartStore { cartEnv ?? CartStore() }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        content
                            .padding(.top, 18)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
                .background(TreggaColors.bg)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: CatalogRoute.self) { route in
                    destination(for: route)
                }
                // Oculta la barra flotante mientras haya navegación profunda
                // (restaurante/item con CTA al fondo). Basado en la profundidad
                // del path para evitar carreras entre onAppear/onDisappear.
                .onChange(of: path) { _, p in shell?.setDeep(.inicio, deep: !p.isEmpty) }
            }
        }
        .task { await viewModel.load() }
        .task { await resolveCliente() }
        .task { await cargarNoLeidas() }
        .onChange(of: showNotifications) { _, abierto in
            // Al cerrar el inbox, las que se marcaron leídas bajan el contador.
            if !abierto { Task { await cargarNoLeidas() } }
        }
        .alert(
            "Carrito de otro negocio",
            isPresented: Binding(
                get: { cart.pendingConflict != nil },
                set: { if !$0 { cart.resolverConflicto(reemplazar: false) } }
            )
        ) {
            Button("Vaciar y agregar", role: .destructive) { cart.resolverConflicto(reemplazar: true) }
            Button("Cancelar", role: .cancel) { cart.resolverConflicto(reemplazar: false) }
        } message: {
            Text("Tu carrito tiene productos de \(cart.negocioName). Para pedir de otro negocio vaciaremos el carrito actual.")
        }
        .sheet(isPresented: $showNotifications) {
            NavigationStack {
                ScreenNotifications(
                    userId: deps?.authSession.tokens?.userId,
                    repo: deps?.notificacionRepository ?? MockNotificacionRepository()
                )
            }
        }
        .sheet(isPresented: $showOffers) {
            NavigationStack { ScreenOffers() }
        }
        .sheet(isPresented: $showDirecciones) {
            if let cid = clienteId {
                DireccionPickerView(
                    viewModel: DireccionPickerViewModel(
                        repo: deps?.direccionRepository ?? MockDireccionClienteRepository(),
                        clienteId: cid,
                        storage: deps?.storageService ?? MockStorageService(),
                        userId: deps?.authSession.tokens?.userId ?? cid
                    ),
                    onSelected: { Task { await resolveCliente() } }
                )
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(TreggaColors.bg)
            }
        }
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
            // El flujo de carrito (carrito → checkout → tracking → chat) vive
            // ahora en la pestaña Carrito (CartTabView). Home solo descubre.
            EmptyView()
        }
    }

    /// Cuenta las notificaciones no leídas (ya sin las de admin, que el repo
    /// filtra) para el badge de la campanita.
    private func cargarNoLeidas() async {
        guard let deps, let userId = deps.authSession.tokens?.userId else { return }
        if let items = try? await deps.notificacionRepository.fetch(userId: userId) {
            noLeidas = items.filter { !$0.read }.count
        }
    }

    private func resolveCliente() async {
        guard let deps, let userId = deps.authSession.tokens?.userId else { return }
        // El clienteId se resuelve una sola vez; la dirección activa se recarga
        // siempre (p.ej. al volver del selector tras elegir otra → refresca header).
        if clienteId == nil {
            clienteId = try? await deps.clienteRepository.fetchByUserId(userId)?.id
        }
        guard let cid = clienteId else { return }
        let direcciones = try? await deps.direccionRepository.fetchDelCliente(clienteId: cid)
        direccionDefault = direcciones?.first(where: \.isDefault) ?? direcciones?.first
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button { showDirecciones = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Entregar ahora")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.3)
                        .textCase(.uppercase)
                        .foregroundStyle(TreggaColors.textSec)
                    HStack(spacing: 6) {
                        TreggaIcon(.pin, size: 18, color: TreggaColors.primary)
                        Text(direccionDefault?.address ?? "Agrega tu dirección")
                            .font(.system(size: 17, weight: .heavy))
                            .tracking(-0.2)
                            .foregroundStyle(TreggaColors.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        TreggaIcon(.chevD, size: 14, color: TreggaColors.textSec)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 10) {
                Button { showOffers = true } label: {
                    ZStack {
                        Circle().fill(TreggaColors.accentSoft).frame(width: 40, height: 40)
                        TreggaIcon(.gift, size: 20, color: TreggaColors.accent)
                    }
                }
                .buttonStyle(.plain)
                Button { showNotifications = true } label: {
                    ZStack {
                        Circle().fill(TreggaColors.surface).frame(width: 40, height: 40)
                        TreggaIcon(.bell, size: 20, color: TreggaColors.text)
                    }
                    .overlay(alignment: .topTrailing) {
                        if noLeidas > 0 {
                            Text(noLeidas > 9 ? "9+" : "\(noLeidas)")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(TreggaColors.danger, in: Capsule())
                                .overlay(Capsule().stroke(TreggaColors.bg, lineWidth: 1.5))
                                .offset(x: 5, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Cargando negocios…")
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)

        case .loaded(let negocios):
            VStack(spacing: 24) {
                let destacados = topRated(negocios)
                if !destacados.isEmpty {
                    carousel("Destacados de Tregga", destacados)
                }
                let cerca = cercaDeTi(negocios)
                if !cerca.isEmpty {
                    carousel("Cerca de ti", cerca)
                }
                let populares = masPedidos(negocios)
                if !populares.isEmpty {
                    carousel("Más pedidos", populares)
                }
                VStack(spacing: 0) {
                    SectionHeader("Todos los negocios")
                    LazyVStack(spacing: 18) {
                        ForEach(negocios) { negocio in
                            Button {
                                path.append(.restaurant(negocio))
                            } label: {
                                FoodCard(negocio: negocio)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

        case .empty:
            emptyState(
                icon: .bag,
                title: "Sin negocios disponibles",
                message: "Por ahora no hay negocios aceptando pedidos en tu zona."
            )

        case .error(let message):
            VStack(spacing: 14) {
                emptyState(icon: .info, title: "Algo salió mal", message: message)
                TreggaButton("Reintentar", kind: .secondary, isFullWidth: false) {
                    Task { await viewModel.load() }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Secciones (derivadas en el cliente desde la lista de negocios)

    /// Carrusel horizontal de negocios con título.
    @ViewBuilder
    private func carousel(_ title: String, _ negocios: [Negocio]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(negocios) { negocio in
                        Button { path.append(.restaurant(negocio)) } label: {
                            FoodCard(negocio: negocio).frame(width: 260)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func topRated(_ n: [Negocio]) -> [Negocio] {
        Array(n.filter { $0.rating > 0 }.sorted { $0.rating > $1.rating }.prefix(10))
    }

    private func masPedidos(_ n: [Negocio]) -> [Negocio] {
        Array(n.sorted { $0.totalOrders > $1.totalOrders }.prefix(10))
    }

    /// Ordena por distancia a la dirección activa; sin coordenadas, por más pedidos.
    private func cercaDeTi(_ n: [Negocio]) -> [Negocio] {
        guard let lat = direccionDefault?.lat, let lng = direccionDefault?.lng else {
            return masPedidos(n)
        }
        return Array(n.sorted { distanciaSq($0, lat, lng) < distanciaSq($1, lat, lng) }.prefix(10))
    }

    private func distanciaSq(_ neg: Negocio, _ lat: Double, _ lng: Double) -> Double {
        guard let nlat = neg.lat, let nlng = neg.lng else { return .greatestFiniteMagnitude }
        let dlat = nlat - lat, dlng = nlng - lng
        return dlat * dlat + dlng * dlng
    }

    private func emptyState(icon: TreggaIcon.Name, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            TreggaIcon(icon, size: 40, color: TreggaColors.textTer)
            Text(title)
                .treggaStyle(.h4)
                .foregroundStyle(TreggaColors.text)
            Text(message)
                .treggaStyle(.sub)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 60)
    }
}
