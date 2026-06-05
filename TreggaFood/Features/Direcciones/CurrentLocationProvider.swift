import Foundation
import CoreLocation

/// Provee la ubicación actual del dispositivo (one-shot) vía CoreLocation.
/// Maneja el permiso `WhenInUse` (ya declarado en Info.plist). Devuelve `nil` si
/// el usuario niega el permiso o falla la localización.
@MainActor
final class CurrentLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<TrackCoord?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// `true` si el permiso está denegado/restringido (para ocultar el CTA o avisar).
    var denegado: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    func current() async -> TrackCoord? {
        let status = manager.authorizationStatus
        guard status != .denied, status != .restricted else { return nil }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    // CoreLocation entrega los callbacks en el hilo donde se creó el manager
    // (main, porque `init` corre en @MainActor), así que asumimos el aislamiento.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                finish(nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.first?.coordinate
        MainActor.assumeIsolated {
            guard let coord else { return finish(nil) }
            finish(TrackCoord(lat: coord.latitude, lng: coord.longitude))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(nil) }
    }

    private func finish(_ coord: TrackCoord?) {
        continuation?.resume(returning: coord)
        continuation = nil
    }
}
