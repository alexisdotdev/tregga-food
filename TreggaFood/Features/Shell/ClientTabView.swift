import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Shell de la app autenticada: TabView con Inicio, Buscar, Pedidos y Cuenta.
/// Inicio es la pantalla real (discovery + menú); el resto son placeholders (F3+).
struct ClientTabView: View {
    @Environment(\.appDependencies) private var deps
    /// Callback hacia ContentView para volver la app a `.unauthenticated`.
    var onSignOut: () -> Void = {}

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

            OrdersTab()
                .tabItem { Label("Pedidos", systemImage: "bag.fill") }

            CuentaTab(onSignOut: onSignOut)
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
            TreggaIcon(sfSymbol: icon, size: 40, color: TreggaColors.textTer)
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
