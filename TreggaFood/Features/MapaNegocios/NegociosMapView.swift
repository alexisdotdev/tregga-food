import SwiftUI
import TreggaCore
import GoogleMaps

/// Mapa de discovery: muestra los negocios disponibles como pines. Tap en un pin
/// → `onSelect`. Encadra la cámara para que quepan todos los negocios.
struct NegociosMapView: UIViewRepresentable {
    /// Negocios con coordenadas (ya filtrados por el VM).
    let negocios: [Negocio]
    let onSelect: (Negocio) -> Void
    let controller: MapController

    /// Fallback de cámara: centro de Zinapécuaro si aún no hay negocios.
    private let fallback = TrackCoord(lat: 19.8642, lng: -100.8225)

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: fallback.lat, longitude: fallback.lng, zoom: 13.5)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.isMyLocationEnabled = false
        mapView.settings.compassButton = false
        mapView.settings.myLocationButton = false
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = false
        mapView.mapStyle = try? GMSMapStyle(jsonString: MapStyle.light)
        mapView.delegate = context.coordinator
        controller.mapView = mapView
        return mapView
    }

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onSelect: (Negocio) -> Void
        var byId: [String: Negocio] = [:]
        var markers: [String: GMSMarker] = [:]
        var fitted = false

        init(onSelect: @escaping (Negocio) -> Void) { self.onSelect = onSelect }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let key = marker.userData as? String, let negocio = byId[key] {
                onSelect(negocio)
            }
            return true
        }
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let coord = context.coordinator
        coord.onSelect = onSelect

        let conCoords = negocios.compactMap { n -> (Negocio, CLLocationCoordinate2D)? in
            guard let la = n.lat, let lo = n.lng else { return nil }
            return (n, CLLocationCoordinate2D(latitude: la, longitude: lo))
        }

        // Sincroniza marcadores (reusa por id, agrega nuevos, quita los que ya no están).
        var vigentes = Set<String>()
        for (negocio, position) in conCoords {
            let key = negocio.id.uuidString
            vigentes.insert(key)
            coord.byId[key] = negocio
            let marker = coord.markers[key] ?? {
                let m = GMSMarker()
                m.icon = GMSMarker.markerImage(with: UIColor(red: 0.05, green: 0.71, blue: 0.36, alpha: 1))
                m.userData = key
                m.map = mapView
                return m
            }()
            marker.position = position
            marker.title = negocio.name
            coord.markers[key] = marker
        }
        for (key, marker) in coord.markers where !vigentes.contains(key) {
            marker.map = nil
            coord.markers.removeValue(forKey: key)
            coord.byId.removeValue(forKey: key)
        }

        // Encadre inicial a los negocios.
        if !coord.fitted, !conCoords.isEmpty {
            if conCoords.count == 1 {
                mapView.animate(toLocation: conCoords[0].1)
                mapView.animate(toZoom: 15)
            } else {
                var bounds = GMSCoordinateBounds()
                for (_, position) in conCoords { bounds = bounds.includingCoordinate(position) }
                mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 72))
            }
            coord.fitted = true
        }
    }
}
