import Foundation

/// Promoción/oferta mostrada al cliente (tabla `promociones`). Puede ser global
/// (negocio_id nil = Tregga) o de un negocio específico.
public struct Promocion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let negocioId: UUID?
    public let titulo: String
    public let descripcion: String?
    public let tag: String?
    public let tipo: String
    public let imagenUrl: String?

    public init(
        id: UUID,
        negocioId: UUID?,
        titulo: String,
        descripcion: String?,
        tag: String?,
        tipo: String,
        imagenUrl: String? = nil
    ) {
        self.id = id
        self.negocioId = negocioId
        self.titulo = titulo
        self.descripcion = descripcion
        self.tag = tag
        self.tipo = tipo
        self.imagenUrl = imagenUrl
    }
}
