import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Shell de la app autenticada. Barra de navegación **flotante** (diseño Claude
/// Design): Inicio · Live · Buscar · Carrito · Cuenta. Las pestañas se mantienen
/// vivas (preservan su navegación al cambiar). La barra se oculta en flujos
/// profundos vía `ClientShell.barHidden`.
struct ClientTabView: View {
    @Environment(\.appDependencies) private var deps
    @Environment(\.cartStore) private var cartEnv
    /// Callback hacia ContentView para volver la app a `.unauthenticated`.
    var onSignOut: () -> Void = {}

    @State private var shell = ClientShell()
    @State private var showSignOut = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                tab(.inicio) { HomeView(catalog: catalog) }
                tab(.live) { MapaNegociosView(catalog: catalog) }
                tab(.buscar) { BuscarTabView() }
                tab(.carrito) { CartTabView() }
                tab(.cuenta) {
                    CuentaTab(
                        onSignOut: onSignOut,
                        onRequestSignOut: { withAnimation(.easeInOut(duration: 0.25)) { showSignOut = true } }
                    )
                }
            }

            if mostrarBarra {
                ClientBottomBar(tab: Bindable(shell).tab, cartCount: cartEnv?.count ?? 0)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showSignOut {
                LogoutConfirmDialog(isPresented: $showSignOut, onConfirm: onSignOut)
            }
        }
        .environment(\.clientShell, shell)
        .animation(.easeInOut(duration: 0.22), value: mostrarBarra)
    }

    /// La barra se oculta en flujos profundos (`barHidden`) y en el carrito con
    /// productos, que tiene su propio CTA "Ir a pagar" a pantalla completa.
    private var cartFlowActivo: Bool {
        shell.tab == .carrito && (cartEnv?.count ?? 0) > 0
    }

    private var mostrarBarra: Bool {
        !shell.barHidden && !cartFlowActivo
    }

    /// Pestaña keep-alive: visible solo si está activa; reserva espacio para la
    /// barra flotante cuando ésta se muestra.
    @ViewBuilder
    private func tab<Content: View>(_ which: ClientTab, @ViewBuilder _ content: () -> Content) -> some View {
        let active = shell.tab == which
        content()
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: mostrarBarra ? 72 : 0)
            }
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .zIndex(active ? 1 : 0)
    }

    private var catalog: CatalogRepository {
        deps?.catalogRepository ?? MockCatalogRepository()
    }
}
