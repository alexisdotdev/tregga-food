import Foundation
import Observation

@MainActor
@Observable
final class CheckoutViewModel {
    enum Phase: Equatable {
        case idle
        case confirming
        case success(ResultadoPedido, avisoTarjeta: Bool)
        case error(String)
    }

    // Inputs editables
    var metodoPago: MetodoPago = .efectivo
    var direccionSeleccionada: DireccionCliente?
    var propina: Decimal = 0
    var propinaPersonalizada: String = ""

    // Captura inline de dirección (cuando el cliente no tiene ninguna)
    var capturandoDireccion: Bool = false
    var nuevaDireccionTexto: String = ""
    var nuevaDireccionReferencias: String = ""

    private(set) var direcciones: [DireccionCliente] = []
    private(set) var cargandoDirecciones: Bool = true
    private(set) var phase: Phase = .idle

    let opcionesPropina: [Decimal] = [0, 10, 20]
    let deliveryFee: Decimal = 25

    private let cart: CartStore
    private let clienteId: UUID
    private let pedidoRepo: PedidoRepository
    private let direccionRepo: DireccionClienteRepository
    private let gateway: PaymentGateway

    init(
        cart: CartStore,
        clienteId: UUID,
        pedidoRepo: PedidoRepository,
        direccionRepo: DireccionClienteRepository,
        gateway: PaymentGateway = StubStripeGateway()
    ) {
        self.cart = cart
        self.clienteId = clienteId
        self.pedidoRepo = pedidoRepo
        self.direccionRepo = direccionRepo
        self.gateway = gateway
    }

    var subtotal: Decimal { cart.subtotal }

    var propinaEfectiva: Decimal {
        if !propinaPersonalizada.isEmpty,
           let valor = Decimal(string: propinaPersonalizada.replacingOccurrences(of: ",", with: ".")) {
            return max(0, valor)
        }
        return propina
    }

    var total: Decimal { subtotal + deliveryFee + propinaEfectiva }

    var puedeConfirmar: Bool {
        guard !cart.isEmpty else { return false }
        if direccionSeleccionada != nil { return true }
        return !nuevaDireccionTexto.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func load() async {
        cargandoDirecciones = true
        do {
            direcciones = try await direccionRepo.fetchDelCliente(clienteId: clienteId)
            direccionSeleccionada = direcciones.first(where: { $0.isDefault }) ?? direcciones.first
            capturandoDireccion = direcciones.isEmpty
        } catch {
            direcciones = []
            capturandoDireccion = true
        }
        cargandoDirecciones = false
    }

    func seleccionarPropina(_ valor: Decimal) {
        propina = valor
        propinaPersonalizada = ""
    }

    func confirmar() async {
        guard cart.negocioId != nil, !cart.isEmpty else {
            phase = .error("Tu carrito está vacío.")
            return
        }
        phase = .confirming

        // Resolver dirección: usar la seleccionada o crear una inline.
        let direccionId: UUID
        do {
            if let dir = direccionSeleccionada {
                direccionId = dir.id
            } else {
                let texto = nuevaDireccionTexto.trimmingCharacters(in: .whitespaces)
                guard !texto.isEmpty else {
                    phase = .error("Falta tu dirección de entrega.")
                    return
                }
                let creada = try await direccionRepo.crear(
                    clienteId: clienteId,
                    label: "Casa",
                    address: texto,
                    referencias: nuevaDireccionReferencias.isEmpty ? nil : nuevaDireccionReferencias,
                    isDefault: direcciones.isEmpty
                )
                direccionId = creada.id
            }
        } catch {
            phase = .error("No pudimos guardar tu dirección. Intenta de nuevo.")
            return
        }

        // Tarjeta: intentar pasarela (stub). No bloquea — solo determina el aviso.
        var avisoTarjeta = false
        if metodoPago == .tarjeta {
            let resultado = await gateway.cobrarTarjeta(amount: total, currency: "MXN")
            if case .pendienteConfiguracion = resultado { avisoTarjeta = true }
        }

        guard let negocioId = cart.negocioId else {
            phase = .error("Tu carrito está vacío.")
            return
        }

        do {
            let resultado = try await pedidoRepo.crearPedido(
                clienteId: clienteId,
                negocioId: negocioId,
                direccionId: direccionId,
                items: cart.buildPedidoItems(),
                metodoPago: metodoPago,
                deliveryFee: deliveryFee,
                propina: propinaEfectiva,
                notes: nil
            )
            phase = .success(resultado, avisoTarjeta: avisoTarjeta)
        } catch {
            phase = .error("No pudimos crear tu pedido. Revisa tu conexión e intenta de nuevo.")
        }
    }

    func reintentar() { phase = .idle }
}
