import Foundation

/// Dirección de entrega de un cliente (tabla `direcciones_cliente`).
public struct DireccionCliente: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let clienteId: UUID
    public var label: String
    public var address: String
    public var lat: Double?
    public var lng: Double?
    public var referencias: String?
    public var isDefault: Bool
    public var codigoPostal: String?
    public var estado: String?
    public var municipio: String?
    public var colonia: String?
    public var calle: String?
    /// Instrucciones para el repartidor (cómo llegar a la puerta exacta).
    public var instrucciones: String?
    /// URLs públicas de fotos de la ubicación (fachada/entrada) para el repartidor.
    public var fotos: [String]

    public init(
        id: UUID,
        clienteId: UUID,
        label: String = "Casa",
        address: String,
        lat: Double? = nil,
        lng: Double? = nil,
        referencias: String? = nil,
        isDefault: Bool = false,
        codigoPostal: String? = nil,
        estado: String? = nil,
        municipio: String? = nil,
        colonia: String? = nil,
        calle: String? = nil,
        instrucciones: String? = nil,
        fotos: [String] = []
    ) {
        self.id = id
        self.clienteId = clienteId
        self.label = label
        self.address = address
        self.lat = lat
        self.lng = lng
        self.referencias = referencias
        self.isDefault = isDefault
        self.codigoPostal = codigoPostal
        self.estado = estado
        self.municipio = municipio
        self.colonia = colonia
        self.calle = calle
        self.instrucciones = instrucciones
        self.fotos = fotos
    }

    /// Subtítulo para tarjeta: dirección + municipio si existe.
    public var detalleLine: String {
        let parts = [colonia, municipio].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (referencias ?? "") : parts.joined(separator: " · ")
    }
}
