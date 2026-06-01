import Foundation

/// Resultado de un intento de pago con pasarela (tarjeta/Stripe).
public enum PaymentGatewayResult: Equatable, Sendable {
    /// Pago autorizado por la pasarela.
    case autorizado(referencia: String)
    /// La pasarela aún no está configurada (sin SDK/edge function/llaves).
    case pendienteConfiguracion
    /// Error recuperable, con mensaje en español.
    case error(String)
}

/// Abstracción de la pasarela de pago con tarjeta. F3 deja un stub; F4+ conecta Stripe real.
public protocol PaymentGateway: Sendable {
    func cobrarTarjeta(amount: Decimal, currency: String) async -> PaymentGatewayResult
}

/// Stub: no integra el SDK de Stripe. Siempre responde `.pendienteConfiguracion`
/// para que el flujo cree el pedido con `payment_method=tarjeta` y muestre el aviso.
public struct StubStripeGateway: PaymentGateway {
    public nonisolated init() {}

    public func cobrarTarjeta(amount: Decimal, currency: String) async -> PaymentGatewayResult {
        .pendienteConfiguracion
    }
}
