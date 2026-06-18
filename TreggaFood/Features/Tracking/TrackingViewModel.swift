import Foundation
import Observation
import CoreLocation

@MainActor
@Observable
final class TrackingViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case error(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var pedido: PedidoTracking?
    private(set) var repartidorCoord: TrackCoord?
    /// Teléfono del repartidor (para llamar/WhatsApp). Se carga una vez cuando el
    /// pedido ya tiene repartidor asignado.
    private(set) var repartidorPhone: String?

    /// Polyline codificada de la ruta repartidor → casa (Directions API). El mapa
    /// la decodifica; si es `nil`, dibuja una recta de respaldo.
    private(set) var routeEncoded: String?

    /// Se activa una vez cuando el pedido pasa a completado, para navegar a éxito.
    var didComplete: Bool = false

    private let pedidoId: UUID
    private let repo: TrackingRepository
    private let routeService = RouteService()
    private var pollingTask: Task<Void, Never>?

    /// Origen de la última ruta pedida, para no re-consultar Directions en cada poll.
    private var lastRouteFrom: TrackCoord?

    /// Aviso de aproximación: se dispara una sola vez por pedido al cruzar el umbral.
    private var proximityNotified = false
    private let proximityThresholdMeters: Double = 300

    init(pedidoId: UUID, repo: TrackingRepository) {
        self.pedidoId = pedidoId
        self.repo = repo
    }

    func start() {
        guard pollingTask == nil else { return }
        Task { await LocalNotifications.requestAuthorization() }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh(initial: true)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                if Task.isCancelled { break }
                await self.refresh(initial: false)
                if self.pedido?.status.isTerminal == true { break }
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func reintentar() {
        phase = .loading
        stop()
        start()
    }

    private func refresh(initial: Bool) async {
        do {
            let p = try await repo.fetchPedido(id: pedidoId)
            pedido = p
            if let repId = p.repartidorId {
                if let ubic = try? await repo.fetchUbicacionRepartidor(repartidorId: repId) {
                    repartidorCoord = ubic.coord
                }
                if repartidorPhone == nil {
                    repartidorPhone = try? await repo.telefonoRepartidor(pedidoId: pedidoId)
                }
            }
            phase = .loaded
            await updateRouteIfNeeded(status: p.status)
            checkProximity(status: p.status)
            if p.status.isCompleted && !didComplete {
                didComplete = true
            }
        } catch {
            if initial {
                phase = .error("No pudimos cargar tu pedido. Revisa tu conexión.")
            }
        }
    }

    /// Pide la ruta por calles repartidor → casa solo cuando el repartidor ya
    /// lleva el pedido, y evita re-consultar Directions si apenas se movió.
    private func updateRouteIfNeeded(status: PedidoStatus) async {
        guard status.driverHeadingToClient,
              let from = repartidorCoord, let to = pedido?.delivery else { return }
        // No re-consultamos Directions hasta que el repartidor se mueva >120m,
        // incluso si el intento previo falló (la recta de respaldo cubre lo visual).
        if let last = lastRouteFrom, Self.meters(last, from) < 120 { return }
        lastRouteFrom = from
        if let encoded = await routeService.fetchEncodedPolyline(from: from, to: to) {
            routeEncoded = encoded
        }
    }

    /// Dispara la notificación local de aproximación una sola vez por pedido,
    /// cuando el repartidor ya lleva el pedido y entra en el radio del domicilio.
    private func checkProximity(status: PedidoStatus) {
        guard !proximityNotified, status.driverHeadingToClient,
              let from = repartidorCoord, let to = pedido?.delivery else { return }
        guard Self.meters(from, to) <= proximityThresholdMeters else { return }
        proximityNotified = true
        LocalNotifications.fireProximity(pedidoId: pedidoId, repartidorName: pedido?.repartidorName)
    }

    /// Distancia en metros entre dos coordenadas.
    static func meters(_ a: TrackCoord, _ b: TrackCoord) -> Double {
        CLLocation(latitude: a.lat, longitude: a.lng)
            .distance(from: CLLocation(latitude: b.lat, longitude: b.lng))
    }
}
