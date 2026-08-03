import SwiftUI
import TreggaCore
import GoogleMaps

/// Mapa de tracking del cliente: muestra pickup (negocio), entrega (cliente)
/// y el repartidor en vivo. Encadra la cámara para que los tres puntos quepan.
struct TrackingMapView: UIViewRepresentable {
    let pickup: TrackCoord?
    let delivery: TrackCoord?
    let repartidor: TrackCoord?
    /// Tipo de vehículo del repartidor para elegir el ícono del pin.
    var vehiculoTipo: String? = nil
    /// Ruta repartidor → casa, codificada (Directions). Si es `nil` y `showRoute`,
    /// se dibuja una recta de respaldo.
    var routeEncoded: String? = nil
    /// Solo dibuja la ruta cuando el repartidor ya lleva el pedido hacia el cliente.
    var showRoute: Bool = false
    let controller: MapController

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
        controller.mapView = mapView
        return mapView
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var pickupMarker: GMSMarker?
        var deliveryMarker: GMSMarker?
        var repartidorMarker: GMSMarker?
        var routePolyline: GMSPolyline?
        var fitted = false
        var lastRepartidor: TrackCoord?
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let coord = context.coordinator

        if let pickup {
            let m = coord.pickupMarker ?? circleMarker(on: mapView, icon: pickupIcon(), title: "Negocio")
            m.position = CLLocationCoordinate2D(latitude: pickup.lat, longitude: pickup.lng)
            coord.pickupMarker = m
        }
        if let delivery {
            let m = coord.deliveryMarker ?? circleMarker(on: mapView, icon: deliveryIcon(), title: "Tu dirección")
            m.position = CLLocationCoordinate2D(latitude: delivery.lat, longitude: delivery.lng)
            coord.deliveryMarker = m
        }
        if let repartidor {
            let icon = repartidorIcon(vehiculoTipo: vehiculoTipo)
            let m: GMSMarker
            if let existing = coord.repartidorMarker {
                m = existing
                // Actualiza el ícono por si vehiculoTipo llegó después de crear el marker.
                m.icon = icon
            } else {
                m = circleMarker(on: mapView, icon: icon, title: "Repartidor")
            }
            m.position = CLLocationCoordinate2D(latitude: repartidor.lat, longitude: repartidor.lng)
            coord.repartidorMarker = m
            // Sigue al repartidor con un pan suave una vez encuadrado.
            if coord.fitted, coord.lastRepartidor != repartidor {
                mapView.animate(toLocation: CLLocationCoordinate2D(latitude: repartidor.lat, longitude: repartidor.lng))
            }
            coord.lastRepartidor = repartidor
        }

        updateRoute(on: mapView, coord: coord)

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

    /// Dibuja/actualiza la ruta repartidor → casa. Usa la polyline de Directions
    /// si llegó; si no, una recta de respaldo. Se oculta si `showRoute` es false.
    private func updateRoute(on mapView: GMSMapView, coord: Coordinator) {
        let path: GMSPath? = {
            guard showRoute else { return nil }
            if let encoded = routeEncoded, let p = GMSPath(fromEncodedPath: encoded) { return p }
            if let r = repartidor, let d = delivery {
                let mp = GMSMutablePath()
                mp.add(CLLocationCoordinate2D(latitude: r.lat, longitude: r.lng))
                mp.add(CLLocationCoordinate2D(latitude: d.lat, longitude: d.lng))
                return mp
            }
            return nil
        }()

        guard let path else {
            coord.routePolyline?.map = nil
            coord.routePolyline = nil
            return
        }
        let line = coord.routePolyline ?? GMSPolyline()
        line.path = path
        line.strokeColor = UIColor(red: 0.05, green: 0.71, blue: 0.36, alpha: 1)
        line.strokeWidth = 4
        line.geodesic = true
        if line.map == nil { line.map = mapView }
        coord.routePolyline = line
    }

    // MARK: - Pin helpers

    private func circleMarker(on mapView: GMSMapView, icon: UIImage, title: String) -> GMSMarker {
        let m = GMSMarker()
        m.icon = icon
        m.title = title
        m.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        m.map = mapView
        return m
    }

    /// Pin naranja con emoji de tienda para el negocio (pickup). Emoji para igualar el
    /// estilo de los pines de la ruta en Android (preferencia del usuario).
    private func pickupIcon() -> UIImage {
        pinImage(emoji: "🏪", background: UIColor(red: 1.0, green: 0.42, blue: 0.17, alpha: 1))
    }

    /// Pin verde oscuro con casa para el cliente (delivery).
    private func deliveryIcon() -> UIImage {
        pinImage(emoji: "🏠", background: UIColor(red: 0.02, green: 0.37, blue: 0.18, alpha: 1))
    }

    /// Pin verde con emoji según el tipo de vehículo del repartidor.
    private func repartidorIcon(vehiculoTipo: String?) -> UIImage {
        let emoji = vehiculoTipo?.lowercased().hasPrefix("bicicleta") == true ? "🚲" : "🛵"
        return pinImage(emoji: emoji, background: UIColor(red: 0.05, green: 0.71, blue: 0.36, alpha: 1))
    }

    /// Renderiza un círculo de color con el emoji centrado (espejo del `pinDescriptor`
    /// de Android, que dibuja el emoji sobre el círculo de color del rol).
    private func pinImage(emoji: String, background: UIColor) -> UIImage {
        let size: CGFloat = 40
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            background.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
            let font = UIFont.systemFont(ofSize: size * 0.5)
            let str = emoji as NSString
            let textSize = str.size(withAttributes: [.font: font])
            str.draw(
                at: CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2),
                withAttributes: [.font: font]
            )
        }
    }
}
