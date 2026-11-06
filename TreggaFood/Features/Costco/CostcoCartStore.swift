import Foundation
import Observation

/// Carrito Costco: separado de `CartStore` y **persistente** por usuario (spec §5.1).
/// Guarda solo ids + cantidades (catálogo) y los renglones libres tal cual; los precios
/// mostrados salen del catálogo vigente y el que manda es el de `crear_pedido_costco`.
@MainActor
@Observable
final class CostcoCartStore {
    struct LineaLibre: Codable, Identifiable, Equatable {
        var id = UUID()
        var descripcion: String
        var cantidad: Int
        var precioEstimado: Decimal
    }

    struct Snapshot: Codable, Equatable {
        var viajeId: UUID?
        var catalogo: [UUID: Int] = [:]
        var libres: [LineaLibre] = []
    }

    enum Aviso: Equatable { case viajeCambio, productosQuitados }

    static let maxCantidad = 99

    private(set) var snapshot = Snapshot() { didSet { guardar() } }
    private var userId: UUID?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Sesión

    /// Carga el carrito del usuario (o lo vacía si no hay sesión). Llamar al cambiar de sesión.
    func activar(userId: UUID?) {
        guard self.userId != userId else { return }
        self.userId = userId
        if let userId, let data = defaults.data(forKey: Self.key(userId)),
           let s = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = s
        } else {
            snapshot = Snapshot()
        }
    }

    /// Al cerrar sesión: borra lo guardado para que nadie lo herede.
    func cerrarSesion() {
        if let userId { defaults.removeObject(forKey: Self.key(userId)) }
        userId = nil
        snapshot = Snapshot()
    }

    // MARK: Edición

    var isEmpty: Bool { snapshot.catalogo.isEmpty && snapshot.libres.isEmpty }
    var cantidadTotal: Int { snapshot.catalogo.values.reduce(0, +) + snapshot.libres.reduce(0) { $0 + $1.cantidad } }

    func cantidad(de productoId: UUID) -> Int { snapshot.catalogo[productoId] ?? 0 }

    func setCantidad(_ cantidad: Int, productoId: UUID, viajeId: UUID) {
        asegurarViaje(viajeId)
        let c = min(max(cantidad, 0), Self.maxCantidad)
        if c == 0 { snapshot.catalogo.removeValue(forKey: productoId) } else { snapshot.catalogo[productoId] = c }
    }

    func agregarLibre(descripcion: String, cantidad: Int, precioEstimado: Decimal, viajeId: UUID) {
        asegurarViaje(viajeId)
        let d = descripcion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !d.isEmpty, precioEstimado > 0 else { return }
        snapshot.libres.append(LineaLibre(
            descripcion: String(d.prefix(200)),
            cantidad: min(max(cantidad, 1), Self.maxCantidad),
            precioEstimado: precioEstimado
        ))
    }

    func setCantidadLibre(_ cantidad: Int, id: UUID) {
        guard let i = snapshot.libres.firstIndex(where: { $0.id == id }) else { return }
        if cantidad <= 0 { snapshot.libres.remove(at: i) } else { snapshot.libres[i].cantidad = min(cantidad, Self.maxCantidad) }
    }

    func vaciar() { snapshot = Snapshot() }

    // MARK: Sincronización con el servidor

    /// Vacía si el viaje ya no acepta pedidos o cambió, y quita productos inactivos.
    @discardableResult
    func sincronizar(estado: CostcoEstado, catalogo: [CostcoProducto]?) -> Aviso? {
        guard !isEmpty else { return nil }
        guard let viaje = estado.viaje, viaje.aceptaPedidos, viaje.id == snapshot.viajeId else {
            snapshot = Snapshot()
            return .viajeCambio
        }
        guard let catalogo else { return nil }
        let activos = Set(catalogo.map(\.id))
        let inactivos = snapshot.catalogo.keys.filter { !activos.contains($0) }
        guard !inactivos.isEmpty else { return nil }
        for id in inactivos { snapshot.catalogo.removeValue(forKey: id) }
        return .productosQuitados
    }

    // MARK: Totales (solo para mostrar; el servidor recalcula)

    struct Totales: Equatable {
        let subtotal: Decimal
        let comision: Decimal
        let total: Decimal
        let anticipo: Decimal
        let faltaParaMinimo: Decimal
    }

    func totales(catalogo: [CostcoProducto], config: CostcoConfig) -> Totales {
        let precios = Dictionary(uniqueKeysWithValues: catalogo.map { ($0.id, $0.precio) })
        let deCatalogo = snapshot.catalogo.reduce(Decimal(0)) { $0 + (precios[$1.key] ?? 0) * Decimal($1.value) }
        let libres = snapshot.libres.reduce(Decimal(0)) { $0 + $1.precioEstimado * Decimal($1.cantidad) }
        let subtotal = Self.redondear(deCatalogo + libres)
        let comision = Self.redondear(subtotal * config.comisionPct / 100)
        let total = subtotal + comision
        let anticipo = Self.redondear(total * config.anticipoPct / 100)
        return Totales(subtotal: subtotal, comision: comision, total: total, anticipo: anticipo,
                       faltaParaMinimo: max(0, config.minimo - subtotal))
    }

    var solicitudes: [CostcoItemSolicitud] {
        snapshot.catalogo.sorted { $0.key.uuidString < $1.key.uuidString }
            .map { .catalogo(productoId: $0.key, cantidad: $0.value) }
        + snapshot.libres.map { .libre(descripcion: $0.descripcion, cantidad: $0.cantidad, precioEstimado: $0.precioEstimado) }
    }

    // MARK: Privado

    private func asegurarViaje(_ viajeId: UUID) {
        if snapshot.viajeId != viajeId {
            snapshot = Snapshot(viajeId: viajeId)
        }
    }

    private func guardar() {
        guard let userId else { return }
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: Self.key(userId)) }
    }

    static func key(_ userId: UUID) -> String { "costco_cart_\(userId.uuidString.lowercased())" }

    static func redondear(_ d: Decimal) -> Decimal {
        var x = d, r = Decimal()
        NSDecimalRound(&r, &x, 2, .plain)
        return r
    }
}
