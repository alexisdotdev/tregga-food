import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// "Tus favoritos": negocios marcados con el corazón. Se presenta como sheet
/// desde Cuenta y navega al restaurante con el mismo flujo de descubrimiento que
/// Home (restaurante → detalle de producto → agregar al carrito).
struct FavoritosView: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.cartStore) private var cartEnv
    @State private var path: [CatalogRoute] = []
    @State private var negocios: [Negocio] = []
    @State private var cargando = true

    private var catalog: CatalogRepository { deps?.catalogRepository ?? MockCatalogRepository() }
    private var cart: CartStore { cartEnv ?? CartStore() }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(TreggaColors.bg)
                .navigationDestination(for: CatalogRoute.self) { route in destination(for: route) }
        }
        .task { await cargar() }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Tus favoritos")
                        .treggaStyle(.h1)
                        .foregroundStyle(TreggaColors.text)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                if cargando {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 90)
                } else if negocios.isEmpty {
                    empty
                } else {
                    VStack(spacing: 14) {
                        ForEach(negocios) { n in
                            Button { path.append(.restaurant(n)) } label: { FoodCard(negocio: n) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            TreggaIcon(.heart, size: 40, color: TreggaColors.textTer)
            Text("Aún no tienes favoritos")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(TreggaColors.text)
            Text("Toca el corazón en un negocio para guardarlo aquí.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
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

    private func cargar() async {
        guard let deps, let uid = deps.authSession.tokens?.userId else { cargando = false; return }
        negocios = (try? await deps.favoritoRepository.listar(userId: uid)) ?? []
        cargando = false
    }
}
