import Foundation
import Observation
import TreggaCore

@MainActor
@Observable
final class CheckoutViewModel {
    enum Phase: Equatable {
        case idle
        case confirming
        case success(ResultadoPedido)
        case error(String)
    }

    // Inputs editables
    var metodoPago: MetodoPago = .efectivo
    var direccionSeleccionada: DireccionCliente?
    var propina: Decimal = 0
    var propinaPersonalizada: String = ""

    private(set) var direcciones: [DireccionCliente] = []
    private(set) var cargandoDirecciones: Bool = true
    private(set) var phase: Phase = .idle
    /// Error no-bloqueante (cargar direcciones / guardar dirección) que antes se
    /// tragaba con `try?` y dejaba el checkout bloqueado sin explicación.
    private(set) var errorCarga: String?

    func clearErrorCarga() { errorCarga = nil }

    // Descuentos (motor de promociones)
    private(set) var descuento: Decimal = 0
    private(set) var promoTitulo: String?
    private(set) var codigoAplicado: String?
    var codigoInput: String = ""
    private(set) var codigoError: String?
    private(set) var aplicandoCodigo = false

    let opcionesPropina: [Decimal] = [0, 10, 20]
    let deliveryFee: Decimal = 25

    private let cart: CartStore
    private let clienteId: UUID
    private let pedidoRepo: PedidoRepository
    private let direccionRepo: DireccionClienteRepository
    private let storage: StorageService
    private let userId: UUID
    private let notasNegocio: String?

    init(
        cart: CartStore,
        clienteId: UUID,
        pedidoRepo: PedidoRepository,
        direccionRepo: DireccionClienteRepository,
        storage: StorageService,
        userId: UUID,
        notasNegocio: String? = nil
    ) {
        self.cart = cart
        self.clienteId = clienteId
        self.pedidoRepo = pedidoRepo
        self.direccionRepo = direccionRepo
        self.storage = storage
        self.userId = userId
        self.notasNegocio = notasNegocio
    }

    /// Centro inicial del mapa al agregar dirección: la seleccionada (si tiene
    /// coordenadas) o el centro de Zinapécuaro como respaldo.
    var centroInicial: TrackCoord {
        if let d = direccionSeleccionada ?? direcciones.first, let la = d.lat, let lo = d.lng {
            return TrackCoord(lat: la, lng: lo)
        }
        return TrackCoord(lat: 19.8642, lng: -100.8225)
    }

    var subtotal: Decimal { cart.subtotal }

    var propinaEfectiva: Decimal {
        if !propinaPersonalizada.isEmpty,
           let valor = Decimal(string: propinaPersonalizada.replacingOccurrences(of: ",", with: ".")) {
            return max(0, valor)
        }
        return propina
    }

    var total: Decimal { max(0, subtotal - descuento) + deliveryFee + propinaEfectiva }

    /// Evalúa el descuento (promo automática o cupón aplicado) para el subtotal actual.
    func cargarDescuento() async {
        guard let negocioId = cart.negocioId, !cart.isEmpty else {
            descuento = 0; promoTitulo = nil; return
        }
        let r = (try? await pedidoRepo.calcularDescuento(negocioId: negocioId, subtotal: subtotal, codigo: codigoAplicado))
            ?? .ninguno
        if r.ok, r.descuento > 0 {
            descuento = r.descuento
            promoTitulo = r.titulo
        } else {
            // Cupón dejó de aplicar (p. ej. subtotal bajó del mínimo): cae a automático.
            if codigoAplicado != nil { codigoAplicado = nil; await cargarDescuento(); return }
            descuento = 0; promoTitulo = nil
        }
    }

    func aplicarCodigo() async {
        let code = codigoInput.trimmingCharacters(in: .whitespaces)
        guard let negocioId = cart.negocioId, !code.isEmpty else { return }
        aplicandoCodigo = true
        codigoError = nil
        defer { aplicandoCodigo = false }
        let r = (try? await pedidoRepo.calcularDescuento(negocioId: negocioId, subtotal: subtotal, codigo: code))
            ?? DescuentoCalculado(ok: false, descuento: 0, titulo: nil, promocionId: nil, error: "error")
        if r.ok, r.descuento > 0 {
            codigoAplicado = code
            descuento = r.descuento
            promoTitulo = r.titulo
            codigoInput = ""
        } else {
            codigoError = "Cupón inválido o no aplica a tu pedido."
        }
    }

    func quitarCodigo() async {
        codigoAplicado = nil
        codigoError = nil
        await cargarDescuento()
    }

    var puedeConfirmar: Bool {
        guard !cart.isEmpty, direccionSeleccionada != nil else { return false }
        // Habilitado para enviar (.idle) o reintentar (.error); deshabilitado
        // durante el vuelo (.confirming → evita doble pedido) y tras éxito.
        switch phase {
        case .idle, .error: return true
        case .confirming, .success: return false
        }
    }

    func load() async {
        cargandoDirecciones = true
        do {
            direcciones = try await direccionRepo.fetchDelCliente(clienteId: clienteId)
            errorCarga = nil
        } catch {
            errorCarga = "No pudimos cargar tus direcciones. Revisa tu conexión e intenta de nuevo."
        }
        if direccionSeleccionada == nil || !direcciones.contains(where: { $0.id == direccionSeleccionada?.id }) {
            direccionSeleccionada = direcciones.first(where: { $0.isDefault }) ?? direcciones.first
        }
        cargandoDirecciones = false
        await cargarDescuento()
    }

    /// Alta de dirección con mapa+pin (mismo flujo que el selector de Direcciones):
    /// sube las fotos, crea con coordenadas/datos estructurados y la deja
    /// seleccionada para este pedido. La primera dirección queda como principal.
    func crearConUbicacion(
        label: String, address: String, referencias: String?,
        instrucciones: String?, fotosData: [Data], place: GeocodedPlace?
    ) async {
        let esPrimera = direcciones.isEmpty
        var urls: [String] = []
        for (i, data) in fotosData.enumerated() {
            if let url = try? await storage.uploadAvatar(
                data: data, userId: userId, fileName: "direcciones/\(UUID().uuidString)-\(i).jpg"
            ) {
                urls.append(url.absoluteString)
            }
        }
        do {
            let nueva = try await direccionRepo.crear(
                clienteId: clienteId, label: label, address: address, referencias: referencias,
                isDefault: esPrimera,
                lat: place?.lat, lng: place?.lng,
                calle: place?.calle,
                codigoPostal: place?.codigoPostal, colonia: place?.colonia,
                municipio: place?.municipio, estado: place?.estado,
                instrucciones: instrucciones, fotos: urls
            )
            direccionSeleccionada = nueva
            errorCarga = nil
            await load()
        } catch {
            // Antes el `try?` lo tragaba: el cliente creía que guardó y no.
            errorCarga = "No pudimos guardar tu dirección. Intenta de nuevo."
        }
    }

    func seleccionarPropina(_ valor: Decimal) {
        propina = valor
        propinaPersonalizada = ""
    }

    func confirmar() async {
        // No re-entrar si ya hay una confirmación en vuelo (doble tap → 2 pedidos)
        // ni re-crear tras éxito; sí permite reintentar desde .error.
        switch phase {
        case .confirming, .success: return
        case .idle, .error: break
        }
        guard let negocioId = cart.negocioId, !cart.isEmpty else {
            phase = .error("Tu carrito está vacío.")
            return
        }
        guard let dir = direccionSeleccionada else {
            phase = .error("Agrega tu dirección de entrega.")
            return
        }
        phase = .confirming

        // No crear pedido si no hay repartidores en línea para asignar. Fail-open:
        // si el conteo falla (red), no bloqueamos; solo si devuelve 0 explícito.
        if let disponibles = try? await pedidoRepo.contarRepartidoresDisponibles(), disponibles == 0 {
            phase = .error("Por ahora no hay repartidores disponibles para entregar tu pedido. Intenta de nuevo en unos minutos.")
            return
        }

        do {
            let resultado = try await pedidoRepo.crearPedido(
                clienteId: clienteId,
                negocioId: negocioId,
                direccionId: dir.id,
                items: cart.buildPedidoItems(),
                metodoPago: metodoPago,
                deliveryFee: deliveryFee,
                propina: propinaEfectiva,
                notes: notasNegocio,
                codigo: codigoAplicado
            )
            phase = .success(resultado)
        } catch {
            phase = .error("No pudimos crear tu pedido. Revisa tu conexión e intenta de nuevo.")
        }
    }

    func reintentar() { phase = .idle }
}
