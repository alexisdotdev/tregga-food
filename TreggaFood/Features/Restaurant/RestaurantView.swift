import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Pantalla de restaurante: hero + info del negocio + menú por categorías.
struct RestaurantView: View {
    let negocio: Negocio
    let catalog: CatalogRepository
    @Binding var path: [CatalogRoute]

    @State private var viewModel: RestaurantViewModel
    @State private var isFav = false
    @State private var favBusy = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cartStore) private var cartEnv
    @Environment(\.clientShell) private var shell
    @Environment(\.appDependencies) private var deps

    init(negocio: Negocio, catalog: CatalogRepository, path: Binding<[CatalogRoute]>) {
        self.negocio = negocio
        self.catalog = catalog
        self._path = path
        _viewModel = State(initialValue: RestaurantViewModel(negocioId: negocio.id, repository: catalog))
    }

    private var cart: CartStore { cartEnv ?? CartStore() }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    infoCard
                        .padding(.horizontal, 16)
                        .offset(y: -22)
                        .padding(.bottom, -22)
                    menu
                        .padding(.top, 16)
                }
                .padding(.bottom, cart.isEmpty ? 24 : 88)
            }
            .background(TreggaColors.bg)
            .ignoresSafeArea(edges: .top)

            CartFloatingBar(cart: cart) { shell?.tab = .carrito }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: cart.count)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .task {
            guard let deps, let uid = deps.authSession.tokens?.userId else { return }
            isFav = ((try? await deps.favoritoRepository.idsFavoritos(userId: uid)) ?? []).contains(negocio.id)
        }
        .swipeBackToDismiss()
    }

    private func toggleFavorito() async {
        guard let deps, let uid = deps.authSession.tokens?.userId, !favBusy else { return }
        favBusy = true
        defer { favBusy = false }
        let nuevo = !isFav
        do {
            if nuevo {
                try await deps.favoritoRepository.agregar(userId: uid, negocioId: negocio.id)
            } else {
                try await deps.favoritoRepository.quitar(userId: uid, negocioId: negocio.id)
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isFav = nuevo }
        } catch {}
    }

    private var hero: some View {
        ZStack(alignment: .top) {
            CoverImage(url: negocio.coverImageURL ?? negocio.logoURL, seed: negocio.name)
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .clipped()

            HStack {
                circleButton(.chevL) { dismiss() }
                Spacer()
                Button { Task { await toggleFavorito() } } label: {
                    TreggaIcon(.heart, size: 20, color: isFav ? TreggaColors.danger : Color(red: 0.04, green: 0.06, blue: 0.05))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.95), in: Circle())
                        .scaleEffect(isFav ? 1.08 : 1)
                }
                .buttonStyle(.plain)
                .disabled(favBusy)
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
    }

    private func circleButton(_ icon: TreggaIcon.Name, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TreggaIcon(icon, size: 20, color: Color(red: 0.04, green: 0.06, blue: 0.05))
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.95), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(negocio.name)
                .treggaStyle(.h2)
                .foregroundStyle(TreggaColors.text)
            if let tipo = negocio.tipo, !tipo.isEmpty {
                Text(tipo)
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
                    .padding(.top, 4)
            }
            if let estado = viewModel.estadoApertura {
                aperturaBadge(estado)
                    .padding(.top, 10)
            }
            HStack(spacing: 14) {
                metaItem(icon: .star, text: negocio.ratingLabel, iconColor: TreggaColors.star)
                metaItem(icon: .clock, text: negocio.tiempoLabel)
                if negocio.totalOrders > 0 {
                    metaItem(icon: .bike, text: "\(negocio.totalOrders) pedidos")
                }
            }
            .padding(.top, 12)

            if let desc = negocio.descripcion, !desc.isEmpty {
                HStack(spacing: 8) {
                    TreggaIcon(.info, size: 18, color: TreggaColors.primaryDark)
                    Text(desc)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TreggaColors.primaryDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TreggaColors.primarySoft, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
                .padding(.top, 12)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TreggaColors.card, in: RoundedRectangle(cornerRadius: TreggaRadius.xxl))
        .overlay(
            RoundedRectangle(cornerRadius: TreggaRadius.xxl)
                .stroke(TreggaColors.border, lineWidth: 1)
        )
    }

    private func aperturaBadge(_ estado: EstadoApertura) -> some View {
        let color = estado.abierto ? TreggaColors.primaryDeep : TreggaColors.danger
        return HStack(spacing: 7) {
            Circle()
                .fill(estado.abierto ? TreggaColors.primary : TreggaColors.danger)
                .frame(width: 7, height: 7)
            Text(estado.abierto ? "Abierto" : "Cerrado")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(color)
            Text("· \(estado.detalle)")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(TreggaColors.textSec)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            (estado.abierto ? TreggaColors.primarySoft : TreggaColors.danger.opacity(0.10)),
            in: Capsule()
        )
    }

    private func metaItem(icon: TreggaIcon.Name, text: String, iconColor: Color = TreggaColors.textSec) -> some View {
        HStack(spacing: 4) {
            TreggaIcon(icon, size: 14, color: iconColor)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TreggaColors.text)
        }
    }

    @ViewBuilder
    private var menu: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        case .loaded(let sections):
            VStack(spacing: 0) {
                ForEach(sections) { section in
                    SectionHeader(section.categoria.nombre)
                        .padding(.top, 8)
                    VStack(spacing: 0) {
                        ForEach(section.productos) { producto in
                            ProductoRow(producto: producto) {
                                path.append(.itemDetail(producto, negocioName: negocio.name))
                            }
                            if producto.id != section.productos.last?.id {
                                TreggaDivider().padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        case .empty:
            Text("Este negocio aún no tiene menú publicado.")
                .treggaStyle(.sub)
                .foregroundStyle(TreggaColors.textSec)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 40)
        case .error(let message):
            VStack(spacing: 12) {
                Text(message)
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
                    .multilineTextAlignment(.center)
                TreggaButton("Reintentar", kind: .secondary, isFullWidth: false) {
                    Task { await viewModel.load() }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 40)
        }
    }
}

/// Fila de producto dentro del menú del restaurante.
private struct ProductoRow: View {
    let producto: Producto
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(producto.nombre)
                        .treggaStyle(.h4)
                        .foregroundStyle(TreggaColors.text)
                        .multilineTextAlignment(.leading)
                    if let desc = producto.descripcion, !desc.isEmpty {
                        Text(desc)
                            .treggaStyle(.sub)
                            .foregroundStyle(TreggaColors.textSec)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    Text(PriceFormat.pesos(producto.precio))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: .bottomTrailing) {
                    CoverImage(url: producto.imageURL, seed: producto.nombre)
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: TreggaRadius.xl))
                    TreggaIcon(.plus, size: 16, color: TreggaColors.bg, weight: .bold)
                        .frame(width: 28, height: 28)
                        .background(TreggaColors.text, in: Circle())
                        .padding(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
