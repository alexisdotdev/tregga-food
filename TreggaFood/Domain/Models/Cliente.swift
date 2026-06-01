import Foundation

/// Cliente del ecosistema Tregga. Históricamente identificado por teléfono
/// (pedidos vía WhatsApp); ahora se enlaza a `auth.users` vía `userId` cuando
/// el cliente crea cuenta en la app nativa.
public struct Cliente: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var userId: UUID?
    public var phone: String
    public var fullName: String
    public var apellidoPaterno: String
    public var apellidoMaterno: String
    public var email: String?
    public var totalOrders: Int
    public var status: String

    public init(
        id: UUID,
        userId: UUID? = nil,
        phone: String,
        fullName: String,
        apellidoPaterno: String = "",
        apellidoMaterno: String = "",
        email: String? = nil,
        totalOrders: Int = 0,
        status: String = "active"
    ) {
        self.id = id
        self.userId = userId
        self.phone = phone
        self.fullName = fullName
        self.apellidoPaterno = apellidoPaterno
        self.apellidoMaterno = apellidoMaterno
        self.email = email
        self.totalOrders = totalOrders
        self.status = status
    }

    public var displayName: String {
        let parts = [fullName, apellidoPaterno].filter { !$0.isEmpty }
        return parts.isEmpty ? "Cliente" : parts.joined(separator: " ")
    }
}
