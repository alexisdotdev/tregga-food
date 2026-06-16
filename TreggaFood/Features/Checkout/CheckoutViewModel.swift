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

    let opcionesPropina: [Decimal] = [0, 10, 20]
    let deliveryFee: Decimal = 25

    private let cart: CartStore
    private let clienteId: UUID
    private let pedidoRepo: PedidoRepository
    private let direccionRepo: DireccionClienteRepository
    private let storage: StorageService
    private let userId: UUID

    init(
        cart: CartStore,
        clienteId: UUID,
        pedidoRepo: PedidoRepository,
        direccionRepo: DireccionClienteRepository,
        storage: StorageService,
        userId: UUID
    ) {
        self.cart = cart
        self.clienteId = clienteId
        self.pedidoRepo = pedidoRepo
        self.direccionRepo = direccionRepo
        self.storage = storage
        self.userId = userId
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

    var total: Decimal { subtotal + deliveryFee + propinaEfectiva }

    var puedeConfirmar: Bool {
        !cart.isEmpty && direccionSeleccionada != nil
    }

    func load() async {
        cargandoDirecciones = true
        direcciones = (try? await direccionRepo.fetchDelCliente(clienteId: clienteId)) ?? []
        if direccionSeleccionada == nil || !direcciones.contains(where: { $0.id == direccionSeleccionada?.id }) {
            direccionSeleccionada = direcciones.first(where: { $0.isDefault }) ?? direcciones.first
        }
        cargandoDirecciones = false
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
        let nueva = try? await direccionRepo.crear(
            clienteId: clienteId, label: label, address: address, referencias: referencias,
            isDefault: esPrimera,
            lat: place?.lat, lng: place?.lng,
            calle: place?.calle,
            codigoPostal: place?.codigoPostal, colonia: place?.colonia,
            municipio: place?.municipio, estado: place?.estado,
            instrucciones: instrucciones, fotos: urls
        )
        if let nueva { direccionSeleccionada = nueva }
        await load()
    }

    func seleccionarPropina(_ valor: Decimal) {
        propina = valor
        propinaPersonalizada = ""
    }

    func confirmar() async {
        guard let negocioId = cart.negocioId, !cart.isEmpty else {
            phase = .error("Tu carrito está vacío.")
            return
        }
        guard let dir = direccionSeleccionada else {
            phase = .error("Agrega tu dirección de entrega.")
            return
        }
        phase = .confirming

        do {
            let resultado = try await pedidoRepo.crearPedido(
                clienteId: clienteId,
                negocioId: negocioId,
                direccionId: dir.id,
                items: cart.buildPedidoItems(),
                metodoPago: metodoPago,
                deliveryFee: deliveryFee,
                propina: propinaEfectiva,
                notes: nil
            )
            phase = .success(resultado)
        } catch {
            phase = .error("No pudimos crear tu pedido. Revisa tu conexión e intenta de nuevo.")
        }
    }

    func reintentar() { phase = .idle }
}
