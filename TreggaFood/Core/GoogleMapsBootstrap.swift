import Foundation
import TreggaCore
import GoogleMaps

/// provideAPIKey al arranque. Vive en la app (no en TreggaCore) para que cada app
/// vincule su propio SDK de mapas — Maps en Business/Food, Navigation en Delivery.
enum GoogleMapsBootstrap {
    static func configure() {
        GMSServices.provideAPIKey(Config.GOOGLE_MAPS_API_KEY)
    }
}
