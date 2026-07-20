import Foundation
import TreggaCore
import Supabase

/// Tarifa de reparto calculada por el servidor para un trayecto concreto.
public struct TarifaReparto: Sendable, Equatable {
    public let distanciaKm: Double
    public let duracionMin: Int
    public let tarifa: Decimal
    /// Lo que gana el repartidor. Hoy coincide con la tarifa (se queda el envío completo).
    public let gananciaRepartidor: Decimal
}

/// Calcula el envío contra la API en vez de asumir una cifra fija.
///
/// La tarifa NO es un número plano: es `tarifa_base + incremento_por_km × km`
/// (hoy 15 + 6/km, en `system_config`). Esa tabla tiene RLS de super_admin, así
/// que el cliente no puede leerla: el único camino es este endpoint.
///
/// Importante: la RPC `crear_pedido_cliente` persiste el `p_delivery_fee` que
/// mande el cliente sin validarlo, así que lo que se muestre aquí es lo que se
/// cobra. Un valor inventado no da un error, da un cobro incorrecto.
public protocol TarifaRepository: Sendable {
    func calcular(pickupLat: Double, pickupLng: Double,
                  deliveryLat: Double, deliveryLng: Double) async throws -> TarifaReparto
}

public final class SupabaseTarifaRepository: TarifaRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    public func calcular(pickupLat: Double, pickupLng: Double,
                         deliveryLat: Double, deliveryLng: Double) async throws -> TarifaReparto {
        struct Body: Encodable {
            let pickup_lat: Double
            let pickup_lng: Double
            let delivery_lat: Double
            let delivery_lng: Double
        }
        struct Resp: Decodable {
            let distancia_km: Double
            let duracion_min: Int
            let tarifa_reparto: Double
            let ganancia_repartidor: Double
        }

        // El endpoint autentica por Bearer (además de cookies para la web).
        guard let token = try? await client.auth.session.accessToken else {
            throw TarifaError.sinSesion
        }
        var request = URLRequest(url: Config.API_BASE.appendingPathComponent("api/tarifa-reparto/calcular"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            Body(pickup_lat: pickupLat, pickup_lng: pickupLng,
                 delivery_lat: deliveryLat, delivery_lng: deliveryLng)
        )
        // El checkout no puede quedarse colgado esperando la tarifa.
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw TarifaError.servidor(status) }

        let r = try JSONDecoder().decode(Resp.self, from: data)
        return TarifaReparto(
            distanciaKm: r.distancia_km,
            duracionMin: r.duracion_min,
            tarifa: Decimal(r.tarifa_reparto),
            gananciaRepartidor: Decimal(r.ganancia_repartidor)
        )
    }
}

public enum TarifaError: Error, Sendable, Equatable {
    case sinSesion
    case servidor(Int)
}

public final class MockTarifaRepository: TarifaRepository {
    private let tarifa: Decimal
    public init(tarifa: Decimal = 20.82) { self.tarifa = tarifa }

    public func calcular(pickupLat: Double, pickupLng: Double,
                         deliveryLat: Double, deliveryLng: Double) async throws -> TarifaReparto {
        TarifaReparto(distanciaKm: 0.97, duracionMin: 4, tarifa: tarifa, gananciaRepartidor: tarifa)
    }
}
