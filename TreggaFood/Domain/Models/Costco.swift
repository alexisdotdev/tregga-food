import Foundation

// Pedidos Costco — modelos del contrato con Supabase (`docs/SPEC-pedidos-costco.md` §5.1).
// Toda la aritmética de dinero y de fechas la hace el servidor; aquí solo se decodifica.

public struct CostcoViaje: Decodable, Equatable, Sendable {
    public let id: UUID
    public let estado: String
    /// Día del viaje ("YYYY-MM-DD"), sin hora ni zona.
    public let fechaViaje: String
    public let fechaCierre: Date
    public let nota: String?
    public let aceptaPedidos: Bool

    enum CodingKeys: String, CodingKey {
        case id, estado, nota
        case fechaViaje = "fecha_viaje"
        case fechaCierre = "fecha_cierre"
        case aceptaPedidos = "acepta_pedidos"
    }
}

public struct CostcoConfig: Decodable, Equatable, Sendable {
    public let comisionPct: Decimal
    public let anticipoPct: Decimal
    public let minimo: Decimal
    public let diasLimiteCancelacion: Int
    /// `nil` sin sesión.
    public let clabe: String?
    public let titular: String?

    enum CodingKeys: String, CodingKey {
        case clabe, titular, minimo
        case comisionPct = "comision_pct"
        case anticipoPct = "anticipo_pct"
        case diasLimiteCancelacion = "dias_limite_cancelacion"
    }
}

public struct CostcoEstado: Decodable, Equatable, Sendable {
    public let viaje: CostcoViaje?
    public let config: CostcoConfig

    /// Fail-closed: solo se puede pedir con viaje que acepta pedidos.
    public var puedePedir: Bool { viaje?.aceptaPedidos == true }
}

public struct CostcoProducto: Decodable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let nombre: String
    public let presentacion: String?
    public let fotoURL: URL?
    public let precio: Decimal
    public let precioConComision: Decimal

    enum CodingKeys: String, CodingKey {
        case id, nombre, presentacion, precio
        case fotoURL = "foto_url"
        case precioConComision = "precio_con_comision"
    }
}

public struct CostcoDireccion: Decodable, Equatable, Hashable, Sendable {
    public let label: String?
    public let address: String?
    public let referencias: String?
    public var lat: Double? = nil
    public var lng: Double? = nil
}

public struct CostcoItem: Decodable, Identifiable, Equatable, Hashable, Sendable {
    public enum Estado: String, Decodable, Sendable {
        case pendiente, comprado, sustituido, quitado
        case noEncontrado = "no_encontrado"
    }

    public let id: UUID
    public let productoId: UUID?
    public let descripcion: String
    public let presentacion: String?
    public let esLibre: Bool
    public let cantidad: Int
    public let precioEstimado: Decimal
    public let importeEstimado: Decimal
    public let precioReal: Decimal?
    public let estado: Estado
    public let sustitutoDe: UUID?

    enum CodingKeys: String, CodingKey {
        case id, descripcion, presentacion, cantidad, estado
        case productoId = "producto_id"
        case esLibre = "es_libre"
        case precioEstimado = "precio_estimado"
        case importeEstimado = "importe_estimado"
        case precioReal = "precio_real"
        case sustitutoDe = "sustituto_de"
    }
}

public struct CostcoPedido: Decodable, Identifiable, Equatable, Hashable, Sendable {
    public enum Estado: String, Decodable, Sendable {
        case esperandoAnticipo = "esperando_anticipo"
        case anticipoEnRevision = "anticipo_en_revision"
        case confirmado, comprado, entregado, cancelado
    }

    public enum CancelMotivo: String, Decodable, Sendable {
        case cliente, admin
        case viajeCancelado = "viaje_cancelado"
        case anticipoVencido = "anticipo_vencido"
    }

    public let id: UUID
    public let viajeId: UUID
    public let fechaViaje: String
    public let estado: Estado
    public let direccion: CostcoDireccion?
    public let subtotalEstimado: Decimal
    public let comision: Decimal
    public let totalEstimado: Decimal
    public let anticipo: Decimal
    public let comprobantePath: String?
    public let anticipoRechazoMotivo: String?
    public let totalReal: Decimal?
    public let resto: Decimal?
    public let reembolsoMonto: Decimal?
    public let reembolsoPendiente: Bool
    public let reembolsoAt: Date?
    public let entregaAcordadaAt: Date?
    public let cancelMotivo: CancelMotivo?
    public let cancelNota: String?
    public let createdAt: Date
    public let limiteCancelacion: Date?
    public let puedeCancelar: Bool
    public let items: [CostcoItem]
    // Ruta de entrega (§9). Opcionales: el servidor puede no mandarlos.
    public var rutaOrden: Int? = nil
    public var rutaTotal: Int? = nil
    public var enRutaAt: Date? = nil
    public var entregaFallidaAt: Date? = nil
    public var entregaFallidaNota: String? = nil
    public var restoCobrado: Decimal? = nil
    public var restoMetodo: String? = nil
    /// Solo no es `nil` si el servidor deja ver la ubicación (privacidad §9.1).
    public var ruta: CostcoRutaEnVivo? = nil

    enum CodingKeys: String, CodingKey {
        case id, estado, direccion, comision, anticipo, resto, items
        case viajeId = "viaje_id"
        case fechaViaje = "fecha_viaje"
        case subtotalEstimado = "subtotal_estimado"
        case totalEstimado = "total_estimado"
        case comprobantePath = "comprobante_path"
        case anticipoRechazoMotivo = "anticipo_rechazo_motivo"
        case totalReal = "total_real"
        case reembolsoMonto = "reembolso_monto"
        case reembolsoPendiente = "reembolso_pendiente"
        case reembolsoAt = "reembolso_at"
        case entregaAcordadaAt = "entrega_acordada_at"
        case cancelMotivo = "cancel_motivo"
        case cancelNota = "cancel_nota"
        case createdAt = "created_at"
        case limiteCancelacion = "limite_cancelacion"
        case puedeCancelar = "puede_cancelar"
        case ruta
        case rutaOrden = "ruta_orden"
        case rutaTotal = "ruta_total"
        case enRutaAt = "en_ruta_at"
        case entregaFallidaAt = "entrega_fallida_at"
        case entregaFallidaNota = "entrega_fallida_nota"
        case restoCobrado = "resto_cobrado"
        case restoMetodo = "resto_metodo"
    }

    /// En camino: comprado, en ruta y sin entrega fallida.
    public var enCamino: Bool { estado == .comprado && enRutaAt != nil && entregaFallidaAt == nil }

    /// Renglones que esperan decisión del cliente.
    public var pendientesDeDecision: [CostcoItem] { items.filter { $0.estado == .noEncontrado } }
    public var enCurso: Bool { estado != .entregado && estado != .cancelado }
}

public struct CostcoRutaEnVivo: Decodable, Equatable, Hashable, Sendable {
    /// `nil` hasta el primer `costco_ruta_ubicacion`.
    public let lat: Double?
    public let lng: Double?
    public let ubicacionAt: Date?
    public let paradasAntes: Int

    enum CodingKeys: String, CodingKey {
        case lat, lng
        case ubicacionAt = "ubicacion_at"
        case paradasAntes = "paradas_antes"
    }
}

/// Renglón que se manda a `crear_pedido_costco`. Nunca lleva precio de catálogo.
public enum CostcoItemSolicitud: Equatable, Sendable {
    case catalogo(productoId: UUID, cantidad: Int)
    case libre(descripcion: String, cantidad: Int, precioEstimado: Decimal)

}

/// Errores del contrato (SQLSTATE en `code`; el mensaje del servidor ya viene en español).
public enum CostcoError: Error, Equatable, Sendable {
    case sinSesion(String)          // 28000
    case datoInvalido(String)       // 22023
    case reglaDeNegocio(String)     // P0001
    case noEncontrado(String)       // P0002 (incl. producto inactivo → "actualiza tu carrito")
    case bajoMinimo(String)         // P0003
    case red

    public static func from(code: String?, message: String?) -> CostcoError {
        let m = message ?? "Algo salió mal. Intenta de nuevo."
        switch code {
        case "28000": return .sinSesion(m)
        case "22023": return .datoInvalido(m)
        case "P0001": return .reglaDeNegocio(m)
        case "P0002": return .noEncontrado(m)
        case "P0003": return .bajoMinimo(m)
        default: return .red
        }
    }

    public var mensaje: String {
        switch self {
        case .sinSesion(let m), .datoInvalido(let m), .reglaDeNegocio(let m),
             .noEncontrado(let m), .bajoMinimo(let m): return m
        case .red: return CostcoCopy.errorRed
        }
    }
}

/// Decodificador del contrato: timestamptz llegan ISO-8601 con offset (+00:00) y a veces con fracción.
enum CostcoJSON {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = parse(s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Fecha inválida: \(s)")
        }
        return d
    }()

    static func parse(_ s: String) -> Date? {
        // Postgres manda microsegundos (6 dígitos); ISO8601DateFormatter solo garantiza 3.
        let s = s.replacingOccurrences(of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression)
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}
