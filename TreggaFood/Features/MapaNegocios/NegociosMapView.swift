import SwiftUI
import TreggaCore
import GoogleMaps

/// Mapa de discovery: muestra los negocios disponibles como pines. Tap en un pin
/// → `onSelect`. Encadra la cámara para que quepan todos los negocios.
struct NegociosMapView: UIViewRepresentable {
    /// Negocios con coordenadas (ya filtrados por el VM).
    let negocios: [Negocio]
    /// Dirección activa del cliente (centro preferido del mapa).
    var center: TrackCoord? = nil
    let onSelect: (Negocio) -> Void
    /// Tap en el mapa fuera de un pin (cierra la preview de negocio).
    var onMapTap: () -> Void = {}
    let controller: MapController

    /// Fallback de cámara: centro de Zinapécuaro si aún no hay negocios.
    private let fallback = TrackCoord(lat: 19.8642, lng: -100.8225)

    func makeUIView(context: Context) -> GMSMapView {
        let start = center ?? fallback
        let camera = GMSCameraPosition(latitude: start.lat, longitude: start.lng, zoom: 13.5)
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

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect, onMapTap: onMapTap) }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onSelect: (Negocio) -> Void
        var onMapTap: () -> Void
        var byId: [String: Negocio] = [:]
        var markers: [String: GMSMarker] = [:]
        var fitted = false

        init(onSelect: @escaping (Negocio) -> Void, onMapTap: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onMapTap = onMapTap
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let key = marker.userData as? String, let negocio = byId[key] {
                onSelect(negocio)
            }
            return true
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            onMapTap()
        }
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let coord = context.coordinator
        coord.onSelect = onSelect
        coord.onMapTap = onMapTap

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
                m.userData = key
                m.groundAnchor = CGPoint(x: 0.5, y: 1)   // la punta ancla en la coordenada
                m.icon = NegocioPin.image(emoji: NegocioPin.emoji(for: negocio.tipo),
                                          rating: negocio.rating)
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

        // Encadre inicial: negocios + dirección del cliente (si la hay).
        if !coord.fitted, !conCoords.isEmpty {
            var puntos = conCoords.map { $0.1 }
            if let c = center {
                puntos.append(CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng))
            }
            if puntos.count == 1 {
                mapView.animate(toLocation: puntos[0])
                mapView.animate(toZoom: 15)
            } else {
                var bounds = GMSCoordinateBounds()
                for p in puntos { bounds = bounds.includingCoordinate(p) }
                mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 72))
            }
            coord.fitted = true
        }
    }
}

/// Pin de discovery estilo Uber: círculo blanco con sombra + punta inferior que
/// ancla en la coordenada + emoji de la categoría, y una pastilla "⭐ x.x" encima
/// cuando el negocio tiene rating. Paridad 1:1 con el mapa de Android.
private enum NegocioPin {
    /// Mapea el `tipo` del negocio a un emoji de categoría (mismo mapeo que Android).
    static func emoji(for tipo: String?) -> String {
        let t = (tipo ?? "").lowercased()
        func has(_ keys: String...) -> Bool { keys.contains { t.contains($0) } }
        switch true {
        case has("café", "cafe", "coffee"):        return "☕"
        case has("pizza"):                         return "🍕"
        case has("parrilla", "carne", "asador"):   return "🥩"
        case has("taco", "antojito"):              return "🌮"
        case has("sushi", "japon"):                return "🍣"
        case has("hamburguesa", "burger"):         return "🍔"
        case has("pollo"):                         return "🍗"
        case has("marisco", "aguachile"):          return "🦐"
        case has("postre"):                        return "🧁"
        case has("desayuno"):                      return "🍳"
        case has("bebida"):                        return "🥤"
        case has("panadería", "panaderia", "pan"): return "🥐"
        default:                                   return "🍽️"
        }
    }

    private static let textColor = UIColor(red: 26 / 255, green: 29 / 255, blue: 27 / 255, alpha: 1)  // #1A1D1B

    static func image(emoji: String, rating: Double) -> UIImage {
        let pinD: CGFloat = 46
        let pointerH: CGFloat = 9
        let pad: CGFloat = 6                       // margen para la sombra

        let showPill = rating > 0
        let pillText = showPill ? "⭐ \(String(format: "%.1f", rating))" : ""
        let pillFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        let pillH: CGFloat = showPill ? 22 : 0
        let pillGap: CGFloat = showPill ? 4 : 0
        let pillW: CGFloat = showPill
            ? (pillText as NSString).size(withAttributes: [.font: pillFont]).width + 14   // ~7pt por lado
            : 0

        let contentW = max(pinD, pillW)
        let width = contentW + pad * 2
        let height = pad + pillH + pillGap + pinD + pointerH   // punta hasta el borde inferior

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let centerX = width / 2
            let circleTop = pad + pillH + pillGap
            let circleRect = CGRect(x: centerX - pinD / 2, y: circleTop, width: pinD, height: pinD)

            // Pin (círculo + punta) como un solo path con sombra suave.
            let path = UIBezierPath(ovalIn: circleRect)
            let baseY = circleRect.maxY - 4
            let tri = UIBezierPath()
            tri.move(to: CGPoint(x: centerX - 8, y: baseY))
            tri.addLine(to: CGPoint(x: centerX, y: height))
            tri.addLine(to: CGPoint(x: centerX + 8, y: baseY))
            tri.close()
            path.append(tri)

            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 2), blur: 5,
                         color: UIColor.black.withAlphaComponent(0.22).cgColor)
            UIColor.white.setFill()
            path.fill()
            cg.restoreGState()

            // Emoji centrado en el círculo.
            let emojiFont = UIFont.systemFont(ofSize: 24)
            let es = (emoji as NSString).size(withAttributes: [.font: emojiFont])
            (emoji as NSString).draw(at: CGPoint(x: centerX - es.width / 2,
                                                 y: circleRect.midY - es.height / 2),
                                     withAttributes: [.font: emojiFont])

            // Pastilla de rating encima (solo si rating > 0).
            if showPill {
                let pillRect = CGRect(x: centerX - pillW / 2, y: pad, width: pillW, height: pillH)
                let pill = UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2)
                cg.saveGState()
                cg.setShadow(offset: CGSize(width: 0, height: 1), blur: 4,
                             color: UIColor.black.withAlphaComponent(0.18).cgColor)
                UIColor.white.setFill()
                pill.fill()
                cg.restoreGState()

                let ts = (pillText as NSString).size(withAttributes: [.font: pillFont])
                (pillText as NSString).draw(at: CGPoint(x: centerX - ts.width / 2,
                                                        y: pillRect.midY - ts.height / 2),
                                            withAttributes: [.font: pillFont, .foregroundColor: textColor])
            }
        }
    }
}
