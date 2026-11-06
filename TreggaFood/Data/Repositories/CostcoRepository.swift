import Foundation
import TreggaCore
import Supabase

/// Pedidos Costco vía RPC (`docs/SPEC-pedidos-costco.md` §5.1). Las RPC devuelven `jsonb`;
/// se decodifica con `CostcoJSON.decoder` y los errores se traducen a `CostcoError`.
public protocol CostcoRepository: Sendable {
    func estado() async throws -> CostcoEstado
    func catalogo() async throws -> [CostcoProducto]
    func misPedidos() async throws -> [CostcoPedido]
    func detalle(pedidoId: UUID) async throws -> CostcoPedido
    func crearPedido(direccionId: UUID, items: [CostcoItemSolicitud]) async throws -> CostcoPedido
    /// Sube el archivo al bucket privado y registra la ruta en el pedido.
    func subirComprobante(pedidoId: UUID, data: Data, fileExtension: String) async throws -> CostcoPedido
    func cancelar(pedidoId: UUID) async throws -> CostcoPedido
    func resolverNoEncontrado(itemId: UUID, sustituto: CostcoItemSolicitud?) async throws -> CostcoPedido
}

public final class SupabaseCostcoRepository: CostcoRepository {
    private let client: SupabaseClient
    private let bucket = "costco-comprobantes"

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    public func estado() async throws -> CostcoEstado {
        try await call("costco_estado")
    }

    public func catalogo() async throws -> [CostcoProducto] {
        try await call("costco_catalogo")
    }

    public func misPedidos() async throws -> [CostcoPedido] {
        try await call("costco_mis_pedidos")
    }

    public func detalle(pedidoId: UUID) async throws -> CostcoPedido {
        try await call("costco_pedido_detalle", ["p_pedido_id": .string(pedidoId.uuidString.lowercased())])
    }

    public func crearPedido(direccionId: UUID, items: [CostcoItemSolicitud]) async throws -> CostcoPedido {
        try await call("crear_pedido_costco", [
            "p_direccion_id": .string(direccionId.uuidString.lowercased()),
            "p_items": .array(items.map(\.anyJSON)),
        ])
    }

    public func subirComprobante(pedidoId: UUID, data: Data, fileExtension: String) async throws -> CostcoPedido {
        // La RLS del bucket exige la ruta EXACTA "{auth.uid}/{pedido_id}/{nombre}" (uid en minúsculas).
        guard let uid = try? await client.auth.user().id else { throw CostcoError.sinSesion("Inicia sesión para continuar.") }
        let ext = fileExtension.lowercased()
        let path = "\(uid.uuidString.lowercased())/\(pedidoId.uuidString.lowercased())/\(Int(Date().timeIntervalSince1970 * 1000)).\(ext)"
        do {
            // Solo INSERT (sin upsert): tras un rechazo se sube otro con nombre nuevo.
            _ = try await client.storage.from(bucket).upload(
                path, data: data, options: FileOptions(contentType: Self.contentType(ext), upsert: false)
            )
        } catch {
            throw CostcoError.red
        }
        return try await call("subir_comprobante_costco", [
            "p_pedido_id": .string(pedidoId.uuidString.lowercased()),
            "p_path": .string(path),
        ])
    }

    public func cancelar(pedidoId: UUID) async throws -> CostcoPedido {
        try await call("cancelar_pedido_costco", ["p_pedido_id": .string(pedidoId.uuidString.lowercased())])
    }

    public func resolverNoEncontrado(itemId: UUID, sustituto: CostcoItemSolicitud?) async throws -> CostcoPedido {
        var params: [String: AnyJSON] = [
            "p_item_id": .string(itemId.uuidString.lowercased()),
            "p_opcion": .string(sustituto == nil ? "reembolsar" : "sustituir"),
        ]
        if let sustituto { params["p_sustituto"] = sustituto.anyJSON }
        return try await call("resolver_no_encontrado_costco", params)
    }

    // MARK: - Helpers

    private func call<T: Decodable>(_ fn: String, _ params: [String: AnyJSON] = [:]) async throws -> T {
        let data: Data
        do {
            data = try await client.rpc(fn, params: params).execute().data
        } catch let e as PostgrestError {
            throw CostcoError.from(code: e.code, message: e.message)
        } catch {
            throw CostcoError.red
        }
        return try CostcoJSON.decoder.decode(T.self, from: data)
    }

    static func contentType(_ ext: String) -> String {
        switch ext {
        case "png": return "image/png"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "heif": return "image/heif"
        case "pdf": return "application/pdf"
        default: return "image/jpeg"
        }
    }
}

extension CostcoItemSolicitud {
    var anyJSON: AnyJSON {
        switch self {
        case .catalogo(let id, let cantidad):
            return .object(["producto_id": .string(id.uuidString.lowercased()), "cantidad": .integer(cantidad)])
        case .libre(let d, let cantidad, let precio):
            return .object([
                "descripcion": .string(d),
                "cantidad": .integer(cantidad),
                "precio_estimado": .double(NSDecimalNumber(decimal: precio).doubleValue),
            ])
        }
    }
}

// MARK: - Mock

/// Mock con estado en memoria. `demo()` trae viaje abierto + catálogo para revisar la UI con `-USE_MOCK YES`.
@MainActor
public final class MockCostcoRepository: CostcoRepository {
    public var estadoValue = CostcoEstado(viaje: nil, config: CostcoConfig(
        comisionPct: 10, anticipoPct: 50, minimo: 800, diasLimiteCancelacion: 2, clabe: nil, titular: nil
    ))
    public var productos: [CostcoProducto] = []
    public var pedidos: [CostcoPedido] = []
    public var error: CostcoError?

    public init() {}

    public static func demo() -> MockCostcoRepository {
        let r = MockCostcoRepository()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = CostcoFormat.zona
        let viaje = Date().addingTimeInterval(8 * 86400)
        r.estadoValue = CostcoEstado(
            viaje: CostcoViaje(id: UUID(), estado: "abierto", fechaViaje: f.string(from: viaje),
                               fechaCierre: viaje.addingTimeInterval(-2 * 86400), nota: nil, aceptaPedidos: true),
            config: CostcoConfig(comisionPct: 10, anticipoPct: 50, minimo: 800, diasLimiteCancelacion: 2,
                                 clabe: "012345678901234567", titular: "Tregga Demo")
        )
        r.productos = [
            ("Papel higiénico Kirkland", "30 rollos", 389),
            ("Aceite de oliva Kirkland", "2 L", 279),
            ("Croissants", "12 piezas", 159),
            ("Pañales Kirkland etapa 4", "180 piezas", 649),
        ].map { CostcoProducto(id: UUID(), nombre: $0.0, presentacion: $0.1, fotoURL: nil,
                               precio: Decimal($0.2), precioConComision: Decimal($0.2) * Decimal(string: "1.1")!) }
        return r
    }

    public func estado() async throws -> CostcoEstado { if let error { throw error }; return estadoValue }
    public func catalogo() async throws -> [CostcoProducto] { if let error { throw error }; return productos }
    public func misPedidos() async throws -> [CostcoPedido] { if let error { throw error }; return pedidos }
    public func detalle(pedidoId: UUID) async throws -> CostcoPedido {
        if let error { throw error }
        guard let p = pedidos.first(where: { $0.id == pedidoId }) else { throw CostcoError.noEncontrado("Pedido no encontrado.") }
        return p
    }

    public func crearPedido(direccionId: UUID, items: [CostcoItemSolicitud]) async throws -> CostcoPedido {
        if let error { throw error }
        guard let viaje = estadoValue.viaje else { throw CostcoError.reglaDeNegocio("No hay viaje abierto.") }
        let renglones: [CostcoItem] = items.map { item in
            switch item {
            case .catalogo(let id, let c):
                let p = productos.first { $0.id == id }
                return CostcoItem(id: UUID(), productoId: id, descripcion: p?.nombre ?? "", presentacion: p?.presentacion,
                                  esLibre: false, cantidad: c, precioEstimado: p?.precio ?? 0,
                                  importeEstimado: (p?.precio ?? 0) * Decimal(c), precioReal: nil, estado: .pendiente, sustitutoDe: nil)
            case .libre(let d, let c, let precio):
                return CostcoItem(id: UUID(), productoId: nil, descripcion: d, presentacion: nil, esLibre: true, cantidad: c,
                                  precioEstimado: precio, importeEstimado: precio * Decimal(c), precioReal: nil,
                                  estado: .pendiente, sustitutoDe: nil)
            }
        }
        let subtotal = renglones.reduce(Decimal(0)) { $0 + $1.importeEstimado }
        guard subtotal >= estadoValue.config.minimo else { throw CostcoError.bajoMinimo("Tu pedido no llega al mínimo.") }
        let comision = CostcoCartStore.redondear(subtotal / 10)
        let pedido = CostcoPedido(
            id: UUID(), viajeId: viaje.id, fechaViaje: viaje.fechaViaje, estado: .esperandoAnticipo,
            direccion: CostcoDireccion(label: "Casa", address: "Calle Demo 1", referencias: nil),
            subtotalEstimado: subtotal, comision: comision, totalEstimado: subtotal + comision,
            anticipo: CostcoCartStore.redondear((subtotal + comision) / 2), comprobantePath: nil, anticipoRechazoMotivo: nil,
            totalReal: nil, resto: nil, reembolsoMonto: nil, reembolsoPendiente: false, reembolsoAt: nil,
            entregaAcordadaAt: nil, cancelMotivo: nil, cancelNota: nil, createdAt: Date(),
            limiteCancelacion: viaje.fechaCierre, puedeCancelar: true, items: renglones
        )
        pedidos.insert(pedido, at: 0)
        return pedido
    }

    public func subirComprobante(pedidoId: UUID, data: Data, fileExtension: String) async throws -> CostcoPedido {
        try actualizar(pedidoId) { $0.with(estado: .anticipoEnRevision) }
    }

    public func cancelar(pedidoId: UUID) async throws -> CostcoPedido {
        try actualizar(pedidoId) { $0.with(estado: .cancelado, cancelMotivo: .cliente) }
    }

    public func resolverNoEncontrado(itemId: UUID, sustituto: CostcoItemSolicitud?) async throws -> CostcoPedido {
        throw error ?? CostcoError.red
    }

    private func actualizar(_ id: UUID, _ cambio: (CostcoPedido) -> CostcoPedido) throws -> CostcoPedido {
        if let error { throw error }
        guard let i = pedidos.firstIndex(where: { $0.id == id }) else { throw CostcoError.noEncontrado("Pedido no encontrado.") }
        pedidos[i] = cambio(pedidos[i])
        return pedidos[i]
    }
}

private extension CostcoPedido {
    func with(estado: Estado, cancelMotivo: CancelMotivo? = nil) -> CostcoPedido {
        CostcoPedido(
            id: id, viajeId: viajeId, fechaViaje: fechaViaje, estado: estado, direccion: direccion,
            subtotalEstimado: subtotalEstimado, comision: comision, totalEstimado: totalEstimado, anticipo: anticipo,
            comprobantePath: estado == .anticipoEnRevision ? "demo.jpg" : comprobantePath,
            anticipoRechazoMotivo: anticipoRechazoMotivo, totalReal: totalReal, resto: resto, reembolsoMonto: reembolsoMonto,
            reembolsoPendiente: reembolsoPendiente, reembolsoAt: reembolsoAt, entregaAcordadaAt: entregaAcordadaAt,
            cancelMotivo: cancelMotivo ?? self.cancelMotivo, cancelNota: cancelNota, createdAt: createdAt,
            limiteCancelacion: limiteCancelacion, puedeCancelar: estado == .esperandoAnticipo || estado == .anticipoEnRevision,
            items: items
        )
    }
}
