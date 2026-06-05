import Foundation
import TreggaCore

/// Obtiene la ruta por calles (Google **Routes API**) entre dos puntos y devuelve
/// la polyline codificada lista para `GMSPath(fromEncodedPath:)`. Si la Routes API
/// falla, devuelve `nil` y el mapa cae a una línea recta. Reusa la API key de
/// Google Maps del proyecto.
///
/// Usamos la Routes API (no la legacy Directions, que está deshabilitada en el
/// proyecto). La key está restringida a apps iOS, así que el request REST debe
/// incluir `X-Ios-Bundle-Identifier` manualmente (el SDK lo hace solo; URLSession no).
struct RouteService {
    private let apiKey: String
    private let bundleId: String

    init(
        apiKey: String = Config.GOOGLE_MAPS_API_KEY,
        bundleId: String = Bundle.main.bundleIdentifier ?? "app.tregga.food"
    ) {
        self.apiKey = apiKey
        self.bundleId = bundleId
    }

    func fetchEncodedPolyline(from: TrackCoord, to: TrackCoord) async -> String? {
        guard !apiKey.isEmpty, !apiKey.hasPrefix("PLACEHOLDER"),
              let url = URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes")
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(bundleId, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.setValue("routes.polyline.encodedPolyline", forHTTPHeaderField: "X-Goog-FieldMask")

        let body = ComputeRoutesRequest(
            origin: .init(location: .init(latLng: .init(latitude: from.lat, longitude: from.lng))),
            destination: .init(location: .init(latLng: .init(latitude: to.lat, longitude: to.lng))),
            travelMode: "DRIVE"
        )
        guard let data = try? JSONEncoder().encode(body) else { return nil }
        request.httpBody = data

        do {
            let (respData, _) = try await URLSession.shared.data(for: request)
            let resp = try JSONDecoder().decode(ComputeRoutesResponse.self, from: respData)
            return resp.routes?.first?.polyline.encodedPolyline
        } catch {
            return nil
        }
    }

    // MARK: - DTOs (Routes API)

    private struct ComputeRoutesRequest: Encodable {
        let origin: Waypoint
        let destination: Waypoint
        let travelMode: String

        struct Waypoint: Encodable { let location: Location }
        struct Location: Encodable { let latLng: LatLng }
        struct LatLng: Encodable { let latitude: Double; let longitude: Double }
    }

    private struct ComputeRoutesResponse: Decodable {
        let routes: [Route]?
        struct Route: Decodable { let polyline: Polyline }
        struct Polyline: Decodable { let encodedPolyline: String }
    }
}
