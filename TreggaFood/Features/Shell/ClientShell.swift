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
    /// Al cambiar de pestaña siempre re-mostramos la barra: evita que un flujo
    /// profundo que la ocultó deje la nueva pestaña sin barra.
    var tab: ClientTab = .inicio {
        didSet { if tab != oldValue { barHidden = false } }
    }
    var barHidden = false
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
