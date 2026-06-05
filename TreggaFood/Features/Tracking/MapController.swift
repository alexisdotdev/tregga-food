import Foundation
import GoogleMaps

/// Puente para que botones SwiftUI controlen el `GMSMapView` envuelto en
/// `TrackingMapView`. El representable registra el mapa en `makeUIView`.
@MainActor
@Observable
final class MapController {
    weak var mapView: GMSMapView?

    func zoomIn() {
        guard let mapView else { return }
        mapView.animate(toZoom: mapView.camera.zoom + 1)
    }

    func zoomOut() {
        guard let mapView else { return }
        mapView.animate(toZoom: mapView.camera.zoom - 1)
    }

    /// Re-encuadra los puntos del tracking (negocio, cliente, repartidor).
    func recenter(to coords: [TrackCoord]) {
        guard let mapView, !coords.isEmpty else { return }
        if coords.count == 1 {
            mapView.animate(toLocation: CLLocationCoordinate2D(latitude: coords[0].lat, longitude: coords[0].lng))
        } else {
            var bounds = GMSCoordinateBounds()
            for c in coords {
                bounds = bounds.includingCoordinate(CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng))
            }
            mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 64))
        }
    }
}
