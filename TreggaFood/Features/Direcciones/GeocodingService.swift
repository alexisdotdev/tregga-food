import Foundation
import TreggaCore

/// Resultado geocodificado: dirección legible + coordenadas + componentes.
struct GeocodedPlace: Identifiable, Equatable {
    let id = UUID()
    let address: String
    let lat: Double
    let lng: Double
    var codigoPostal: String?
    var colonia: String?
    var municipio: String?
    var estado: String?
}

/// Geocoding de Google (forward: texto→lugares; reverse: coords→dirección).
/// Reusa la API key del proyecto + el header de bundle iOS (la key está
/// restringida a la app). Requiere la **Geocoding API** habilitada.
struct GeocodingService {
    private let apiKey: String
    private let bundleId: String

    init(
        apiKey: String = Config.GOOGLE_MAPS_API_KEY,
        bundleId: String = Bundle.main.bundleIdentifier ?? "app.tregga.food"
    ) {
        self.apiKey = apiKey
        self.bundleId = bundleId
    }

    /// Texto → lista de lugares candidatos. `contexto` (municipio/estado de la
    /// zona actual) se anexa a la consulta para resolver nombres de calle sueltos
    /// (p.ej. "13 de septiembre" → "13 de septiembre, Zinapécuaro, Michoacán").
    func buscar(_ query: String, contexto: String? = nil) async -> [GeocodedPlace] {
        let q0 = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q0.count >= 3, var comps = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")
        else { return [] }
        let q = (contexto?.isEmpty == false) ? "\(q0), \(contexto!)" : q0
        comps.queryItems = [
            URLQueryItem(name: "address", value: q),
            URLQueryItem(name: "components", value: "country:MX"),
            URLQueryItem(name: "region", value: "mx"),
            URLQueryItem(name: "language", value: "es"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        return await run(comps)
    }

    /// Coords → dirección más cercana.
    func reverse(lat: Double, lng: Double) async -> GeocodedPlace? {
        guard var comps = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")
        else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "latlng", value: "\(lat),\(lng)"),
            URLQueryItem(name: "language", value: "es"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        return await run(comps).first
    }

    private func run(_ comps: URLComponents) async -> [GeocodedPlace] {
        guard !apiKey.isEmpty, !apiKey.hasPrefix("PLACEHOLDER"), let url = comps.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue(bundleId, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let resp = try JSONDecoder().decode(GeocodeResponse.self, from: data)
            guard resp.status == "OK" else { return [] }
            return resp.results.prefix(6).map { $0.toPlace() }
        } catch {
            return []
        }
    }

    // MARK: - DTOs (Geocoding API)

    private struct GeocodeResponse: Decodable {
        let status: String
        let results: [Result]
        struct Result: Decodable {
            let formatted_address: String
            let geometry: Geometry
            let address_components: [Component]

            func toPlace() -> GeocodedPlace {
                func comp(_ type: String) -> String? {
                    address_components.first { $0.types.contains(type) }?.long_name
                }
                return GeocodedPlace(
                    address: formatted_address,
                    lat: geometry.location.lat,
                    lng: geometry.location.lng,
                    codigoPostal: comp("postal_code"),
                    colonia: comp("sublocality") ?? comp("neighborhood"),
                    municipio: comp("locality") ?? comp("administrative_area_level_2"),
                    estado: comp("administrative_area_level_1")
                )
            }
        }
        struct Geometry: Decodable { let location: Location }
        struct Location: Decodable { let lat: Double; let lng: Double }
        struct Component: Decodable { let long_name: String; let types: [String] }
    }
}
