import SwiftUI
import TreggaDesignSystem

/// "En camino · parada N de M" + mapa con la ubicación de Alexis cuando el servidor la expone (§9.4).
struct CostcoRutaCard: View {
    let pedido: CostcoPedido

    @State private var controller = MapController()
    @State private var polyline: String?
    @State private var minutos: Int?

    private var repartidor: TrackCoord? {
        guard let lat = pedido.ruta?.lat, let lng = pedido.ruta?.lng else { return nil }
        return TrackCoord(lat: lat, lng: lng)
    }
    private var casa: TrackCoord? {
        guard let lat = pedido.direccion?.lat, let lng = pedido.direccion?.lng else { return nil }
        return TrackCoord(lat: lat, lng: lng)
    }
    private var esSiguiente: Bool { pedido.ruta?.paradasAntes == 0 }

    var body: some View {
        CostcoUI.card {
            if let n = pedido.rutaOrden, let total = pedido.rutaTotal {
                Text(CostcoCopy.enCamino(parada: n, de: total))
                    .font(.system(size: 16, weight: .heavy)).foregroundStyle(TreggaColors.primaryDark)
            }
            if let ruta = pedido.ruta {
                Text(ruta.paradasAntes == 0 ? CostcoCopy.vamosParaTuCasa : CostcoCopy.paradasAntes(ruta.paradasAntes))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(TreggaColors.text)
                if esSiguiente, let minutos {
                    Text(CostcoCopy.llegadaAprox(minutos))
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(TreggaColors.textSec)
                }
                if repartidor != nil {
                    TrackingMapView(pickup: nil, delivery: casa, repartidor: repartidor,
                                    routeEncoded: polyline, showRoute: esSiguiente, controller: controller)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: TreggaRadius.lg))
                } else {
                    Text(CostcoCopy.ubicacionPendiente)
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(TreggaColors.textSec)
                }
            }
        }
        // Solo para la siguiente parada: ruta y ETA desde la ubicación actual.
        .task(id: esSiguiente ? repartidor?.lat : nil) {
            guard esSiguiente, let desde = repartidor, let hasta = casa,
                  let r = await RouteService().fetchRoute(from: desde, to: hasta) else { return }
            polyline = r.polyline
            minutos = r.segundos.map { max(1, Int((Double($0) / 60).rounded())) }
        }
    }
}
