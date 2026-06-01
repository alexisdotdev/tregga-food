import Foundation

/// Perfil del usuario-cliente (tabla `profiles`, role='cliente').
/// Enlazado 1:1 con `auth.users` vía `id`.
public struct PerfilCliente: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var fullName: String
    public var apellidoPaterno: String
    public var apellidoMaterno: String
    public var email: String?
    public var phone: String?
    public var avatarUrl: String?
    public var fechaNacimiento: Date?
    public var codigoPostal: String?
    public var estado: String?
    public var municipio: String?
    public var colonia: String?
    public var calle: String?
    public var curp: String?

    public init(
        id: UUID,
        fullName: String = "",
        apellidoPaterno: String = "",
        apellidoMaterno: String = "",
        email: String? = nil,
        phone: String? = nil,
        avatarUrl: String? = nil,
        fechaNacimiento: Date? = nil,
        codigoPostal: String? = nil,
        estado: String? = nil,
        municipio: String? = nil,
        colonia: String? = nil,
        calle: String? = nil,
        curp: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.apellidoPaterno = apellidoPaterno
        self.apellidoMaterno = apellidoMaterno
        self.email = email
        self.phone = phone
        self.avatarUrl = avatarUrl
        self.fechaNacimiento = fechaNacimiento
        self.codigoPostal = codigoPostal
        self.estado = estado
        self.municipio = municipio
        self.colonia = colonia
        self.calle = calle
        self.curp = curp
    }

    /// Nombre para mostrar: nombre + apellido paterno si existe.
    public var displayName: String {
        let parts = [fullName, apellidoPaterno].filter { !$0.isEmpty }
        return parts.isEmpty ? "Cliente" : parts.joined(separator: " ")
    }

    /// Iniciales para avatar (máx 2 letras).
    public var initials: String {
        let source = displayName
        let words = source.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "T" : letters.joined().uppercased()
    }
}
