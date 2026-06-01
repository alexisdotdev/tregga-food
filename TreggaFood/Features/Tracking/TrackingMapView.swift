import SwiftUI
import TreggaCore
import GoogleMaps

/// Mapa de tracking del cliente: muestra pickup (negocio), entrega (cliente)
/// y el repartidor en vivo. Encadra la cámara para que los tres puntos quepan.
struct TrackingMapView: UIViewRepresentable {
    let pickup: TrackCoord?
    let delivery: TrackCoord?
    let repartidor: TrackCoord?

    func makeUIView(context: Context) -> GMSMapView {
        let center = repartidor ?? delivery ?? pickup ?? TrackCoord(lat: 19.4326, lng: -99.1332)
        let camera = GMSCameraPosition(latitude: center.lat, longitude: center.lng, zoom: 14)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.isMyLocationEnabled = false
        mapView.settings.compassButton = false
        mapView.settings.myLocationButton = false
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = false
        mapView.mapStyle = try? GMSMapStyle(jsonString: MapStyle.light)
        return mapView
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var pickupMarker: GMSMarker?
        var deliveryMarker: GMSMarker?
        var repartidorMarker: GMSMarker?
        var fitted = false
        var lastRepartidor: TrackCoord?
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let coord = context.coordinator

        if let pickup {
            let m = coord.pickupMarker ?? marker(on: mapView, color: .black, title: "Negocio")
            m.position = CLLocationCoordinate2D(latitude: pickup.lat, longitude: pickup.lng)
            coord.pickupMarker = m
        }
        if let delivery {
            let m = coord.deliveryMarker ?? marker(on: mapView, color: UIColor(red: 0.02, green: 0.37, blue: 0.18, alpha: 1), title: "Tu dirección")
            m.position = CLLocationCoordinate2D(latitude: delivery.lat, longitude: delivery.lng)
            coord.deliveryMarker = m
        }
        if let repartidor {
            let m = coord.repartidorMarker ?? marker(on: mapView, color: UIColor(red: 0.05, green: 0.71, blue: 0.36, alpha: 1), title: "Repartidor")
            m.position = CLLocationCoordinate2D(latitude: repartidor.lat, longitude: repartidor.lng)
            coord.repartidorMarker = m
            // Sigue al repartidor con un pan suave una vez encuadrado.
            if coord.fitted, coord.lastRepartidor != repartidor {
                mapView.animate(toLocation: CLLocationCoordinate2D(latitude: repartidor.lat, longitude: repartidor.lng))
            }
            coord.lastRepartidor = repartidor
        }

        // Encuadre inicial que contiene los puntos disponibles.
        if !coord.fitted {
            let puntos = [pickup, delivery, repartidor].compactMap { $0 }
            if puntos.count >= 2 {
                var bounds = GMSCoordinateBounds()
                for p in puntos {
                    bounds = bounds.includingCoordinate(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng))
                }
                mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 64))
                coord.fitted = true
            } else if let only = puntos.first {
                mapView.animate(toLocation: CLLocationCoordinate2D(latitude: only.lat, longitude: only.lng))
                coord.fitted = true
            }
        }
    }

    private func marker(on mapView: GMSMapView, color: UIColor, title: String) -> GMSMarker {
        let m = GMSMarker()
        m.icon = GMSMarker.markerImage(with: color)
        m.title = title
        m.groundAnchor = CGPoint(x: 0.5, y: 1.0)
        m.map = mapView
        return m
    }
}
