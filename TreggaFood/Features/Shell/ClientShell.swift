import SwiftUI
import Observation

/// Pestañas del shell del cliente (orden visual de la barra flotante).
enum ClientTab: Hashable {
    case inicio, live, buscar, carrito, cuenta
}

/// Estado compartido del shell autenticado: pestaña activa + visibilidad de la
/// barra flotante. Lo inyecta `ClientTabView` por environment para que cualquier
/// pantalla pueda cambiar de pestaña (p.ej. "Ver carrito" → `.carrito`) u ocultar
/// la barra durante flujos profundos con CTA al fondo.
@MainActor
@Observable
final class ClientShell {
    var tab: ClientTab = .inicio

    /// Pestañas que están en navegación profunda (path no vacío). La barra
    /// flotante se oculta cuando la pestaña **activa** está aquí — así no
    /// reaparece sobre los CTAs al volver a una pestaña que quedó profunda.
    private(set) var deepTabs: Set<ClientTab> = []

    func setDeep(_ tab: ClientTab, deep: Bool) {
        if deep { deepTabs.insert(tab) } else { deepTabs.remove(tab) }
    }
}

private struct ClientShellKey: EnvironmentKey {
    static let defaultValue: ClientShell? = nil
}

extension EnvironmentValues {
    var clientShell: ClientShell? {
        get { self[ClientShellKey.self] }
        set { self[ClientShellKey.self] = newValue }
    }
}
