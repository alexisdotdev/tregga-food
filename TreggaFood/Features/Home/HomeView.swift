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
                        SearchBar(placeholder: "Carnitas, pizza, tacos…")
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
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
                        // Oculta la barra flotante en flujos profundos con CTA al
                        // fondo (restaurante/item) para que no queden detrás.
                        .onAppear { shell?.barHidden = true }
                        .onDisappear { shell?.barHidden = false }
                }
            }
        }
        .task { await viewModel.load() }
        .task { await resolveCliente() }
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
                    viewModel: NotificationsViewModel(
                        userId: deps?.authSession.tokens?.userId,
                        repo: deps?.notificacionRepository ?? MockNotificacionRepository()
                    )
                )
            }
        }
        .sheet(isPresented: $showOffers) {
            NavigationStack { ScreenOffers() }
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

    private func resolveCliente() async {
        guard clienteId == nil, let deps,
              let userId = deps.authSession.tokens?.userId else { return }
        clienteId = try? await deps.clienteRepository.fetchByUserId(userId)?.id
        guard let cid = clienteId else { return }
        let direcciones = try? await deps.direccionRepository.fetchDelCliente(clienteId: cid)
        direccionDefault = direcciones?.first(where: \.isDefault) ?? direcciones?.first
    }

    private var header: some View {
        HStack(alignment: .top) {
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
            VStack(spacing: 0) {
                SectionHeader("Negocios cerca de ti")
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
