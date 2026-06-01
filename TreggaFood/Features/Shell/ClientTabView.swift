import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Shell de la app autenticada: TabView con Inicio, Buscar, Pedidos y Cuenta.
/// Inicio es la pantalla real (discovery + menú); el resto son placeholders (F3+).
struct ClientTabView: View {
    @Environment(\.appDependencies) private var deps

    var body: some View {
        TabView {
            HomeView(catalog: catalog)
                .tabItem { Label("Inicio", systemImage: "house.fill") }

            PlaceholderTab(
                icon: "magnifyingglass",
                title: "Buscar",
                message: "Pronto podrás explorar negocios por tipo de comida."
            )
            .tabItem { Label("Buscar", systemImage: "magnifyingglass") }

            PlaceholderTab(
                icon: "bag.fill",
                title: "Pedidos",
                message: "Aquí verás tus pedidos en curso e historial."
            )
            .tabItem { Label("Pedidos", systemImage: "bag.fill") }

            PlaceholderTab(
                icon: "person.crop.circle.fill",
                title: "Cuenta",
                message: "Tu perfil, direcciones y métodos de pago."
            )
            .tabItem { Label("Cuenta", systemImage: "person.crop.circle.fill") }
        }
        .tint(TreggaColors.primary)
    }

    private var catalog: CatalogRepository {
        deps?.catalogRepository ?? MockCatalogRepository()
    }
}

/// Placeholder simple para tabs aún no implementados.
private struct PlaceholderTab: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(TreggaColors.textTer)
            Text(title)
                .treggaStyle(.h3)
                .foregroundStyle(TreggaColors.text)
            Text("En construcción")
                .treggaStyle(.caption)
                .textCase(.uppercase)
                .foregroundStyle(TreggaColors.primary)
            Text(message)
                .treggaStyle(.sub)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TreggaColors.bg)
    }
}
