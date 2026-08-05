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
    /// Callback hacia ContentView para volver la app a modo invitado.
    var onSignOut: () -> Void = {}
    /// `true` cuando no hay sesión: navegar es libre, pero carrito/cuenta y
    /// "agregar al carrito" disparan el login (App Store 5.1.1(v)).
    var isGuest: Bool = false
    /// Abre el flujo de login (lo presenta `ContentView` como sheet).
    var onRequestLogin: () -> Void = {}

    @State private var shell = ClientShell()
    @State private var showSignOut = false
    /// La barra colapsa "Buscar" a icono cuando el ancho no alcanza para el texto.
    /// En iPad "Designed for iPhone" la app corre en un lienzo portrait fijo
    /// (375×667) que iPadOS rota: en landscape el ancho usable baja (~325) y el
    /// texto desborda. No hay señal de orientación (size classes/geo siempre dicen
    /// portrait), así que decidimos por ancho medido.
    @State private var barCompact = false

    var body: some View {
        ZStack {
            ZStack {
                tab(.inicio) { HomeView(catalog: catalog) }
                tab(.live) { MapaNegociosView(catalog: catalog) }
                tab(.buscar) { BuscarTabView() }
                tab(.carrito) {
                    if isGuest {
                        GuestGateView(
                            icon: .bag,
                            titulo: "Inicia sesión para tu carrito",
                            mensaje: "Crea tu cuenta o entra para agregar productos y hacer tu pedido.",
                            onLogin: onRequestLogin
                        )
                    } else {
                        CartTabView()
                    }
                }
                tab(.cuenta) {
                    if isGuest {
                        GuestGateView(
                            icon: .user,
                            titulo: "Inicia sesión en Tregga",
                            mensaje: "Administra tus pedidos, direcciones y favoritos desde tu cuenta.",
                            onLogin: onRequestLogin
                        )
                    } else {
                        CuentaTab(
                            onSignOut: onSignOut,
                            onRequestSignOut: { withAnimation(.easeInOut(duration: 0.25)) { showSignOut = true } }
                        )
                    }
                }
            }
            // La barra flotante se hospeda como safe-area inset: reserva su espacio
            // y lo propaga al contenido de cada pestaña (incluidos sus NavigationStack),
            // así el contenido nunca queda debajo de la barra.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if mostrarBarra {
                    ClientBottomBar(tab: Bindable(shell).tab, cartCount: cartEnv?.count ?? 0, compact: barCompact)
                        // Cap de ancho + centrado: en pantallas anchas (iPad en
                        // landscape, donde la app rota sin poder bloquearse) la barra
                        // no se estira ni empuja los botones fuera de pantalla.
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if showSignOut {
                LogoutConfirmDialog(isPresented: $showSignOut, onConfirm: onSignOut)
            }
        }
        .background(
            GeometryReader { geo in
                // Colapsa "Buscar" cuando no hay ancho para el texto (~360pt).
                // iPhone (≥402) e iPad portrait (~375): expandido. iPad landscape
                // (~325): colapsado a icono.
                Color.clear.task(id: geo.size.width) { barCompact = geo.size.width < 360 }
            }
        )
        .environment(\.clientShell, shell)
        .animation(.easeInOut(duration: 0.22), value: mostrarBarra)
        .animation(.easeInOut(duration: 0.22), value: barCompact)
        .onAppear {
            shell.isGuest = isGuest
            shell.requestLogin = onRequestLogin
        }
        .onChange(of: isGuest) { _, nuevo in shell.isGuest = nuevo }
    }

    /// La barra se oculta cuando la pestaña activa está en navegación profunda, y
    /// en el carrito con productos (tiene su propio CTA "Ir a pagar" a pantalla
    /// completa).
    private var cartFlowActivo: Bool {
        shell.tab == .carrito && (cartEnv?.count ?? 0) > 0
    }

    private var mostrarBarra: Bool {
        !shell.deepTabs.contains(shell.tab) && !cartFlowActivo
    }

    /// Pestaña keep-alive: visible solo si está activa; reserva espacio para la
    /// barra flotante cuando ésta se muestra.
    @ViewBuilder
    private func tab<Content: View>(_ which: ClientTab, @ViewBuilder _ content: () -> Content) -> some View {
        let active = shell.tab == which
        content()
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .zIndex(active ? 1 : 0)
    }

    private var catalog: CatalogRepository {
        deps?.catalogRepository ?? MockCatalogRepository()
    }
}
