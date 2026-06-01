import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pantalla de inicio (discovery): ubicación + búsqueda + lista de negocios.
struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var path: [CatalogRoute] = []
    private let catalog: CatalogRepository

    init(catalog: CatalogRepository) {
        self.catalog = catalog
        _viewModel = State(initialValue: HomeViewModel(repository: catalog))
    }

    var body: some View {
        NavigationStack(path: $path) {
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
                .padding(.bottom, 24)
            }
            .background(TreggaColors.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CatalogRoute.self) { route in
                switch route {
                case .restaurant(let negocio):
                    RestaurantView(negocio: negocio, catalog: catalog, path: $path)
                case .itemDetail(let producto, let negocioName):
                    ItemDetailView(
                        producto: producto,
                        negocioName: negocioName,
                        catalog: catalog,
                        onAdd: { _ in path.removeLast() }
                    )
                }
            }
        }
        .task { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Entregar ahora")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.3)
                .textCase(.uppercase)
                .foregroundStyle(TreggaColors.textSec)
            HStack(spacing: 6) {
                TreggaIcon(.pin, size: 18, color: TreggaColors.primary)
                Text("Av. Hidalgo 142, Centro")
                    .font(.system(size: 17, weight: .heavy))
                    .tracking(-0.2)
                    .foregroundStyle(TreggaColors.text)
                TreggaIcon(.chevD, size: 14, color: TreggaColors.textSec)
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
