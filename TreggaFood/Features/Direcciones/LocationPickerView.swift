import SwiftUI
import TreggaCore
import TreggaDesignSystem
import GoogleMaps
import Observation

/// Mapa con pin fijo al centro: reporta su centro al quedar quieto (para reverse
/// geocoding). El pin es un overlay SwiftUI, no un marcador, así queda centrado.
struct LocationPickerMapView: UIViewRepresentable {
    let initial: TrackCoord
    let controller: MapController
    let onIdle: (TrackCoord) -> Void

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: initial.lat, longitude: initial.lng, zoom: 16)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.settings.compassButton = false
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = false
        mapView.settings.myLocationButton = false
        mapView.mapStyle = try? GMSMapStyle(jsonString: MapStyle.light)
        mapView.delegate = context.coordinator
        controller.mapView = mapView
        return mapView
    }

    func makeCoordinator() -> Coordinator { Coordinator(onIdle: onIdle) }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        let onIdle: (TrackCoord) -> Void
        init(onIdle: @escaping (TrackCoord) -> Void) { self.onIdle = onIdle }
        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            onIdle(TrackCoord(lat: position.target.latitude, lng: position.target.longitude))
        }
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {}
}

@MainActor
@Observable
final class LocationPickerViewModel {
    private let geocoder = GeocodingService()

    var query = ""
    private(set) var resultados: [GeocodedPlace] = []
    private(set) var buscando = false

    private(set) var center: TrackCoord
    private(set) var direccionActual: String = "Mueve el mapa para ubicar tu dirección"
    private(set) var place: GeocodedPlace?

    init(center: TrackCoord) { self.center = center }

    func buscar() async {
        let q = query
        guard q.count >= 3 else { resultados = []; return }
        buscando = true
        let contexto = [place?.municipio, place?.estado]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        let r = await geocoder.buscar(q, contexto: contexto.isEmpty ? nil : contexto)
        guard q == query else { return }
        resultados = r
        buscando = false
    }

    /// El usuario eligió un resultado del buscador.
    func elegir(_ p: GeocodedPlace) {
        center = TrackCoord(lat: p.lat, lng: p.lng)
        direccionActual = p.address
        place = p
        resultados = []
        query = ""
    }

    /// El mapa quedó quieto: reverse-geocode del nuevo centro.
    func mapaQuieto(_ coord: TrackCoord) async {
        center = coord
        if let p = await geocoder.reverse(lat: coord.lat, lng: coord.lng) {
            direccionActual = p.address
            place = p
        }
    }
}

/// Selector de ubicación: mapa con pin central + buscador + reverse geocoding.
struct LocationPickerView: View {
    @State private var viewModel: LocationPickerViewModel
    @State private var mapController = MapController()
    @State private var label = "Casa"
    @State private var referencias = ""
    @State private var searchTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    let onGuardar: (_ label: String, _ address: String, _ referencias: String?, _ place: GeocodedPlace?) -> Void

    private let etiquetas = ["Casa", "Trabajo", "Otro"]

    init(center: TrackCoord, onGuardar: @escaping (String, String, String?, GeocodedPlace?) -> Void) {
        _viewModel = State(initialValue: LocationPickerViewModel(center: center))
        self.onGuardar = onGuardar
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LocationPickerMapView(
                    initial: viewModel.center,
                    controller: mapController,
                    onIdle: { coord in Task { await viewModel.mapaQuieto(coord) } }
                )
                .ignoresSafeArea()

                centerPin

                VStack(spacing: 0) {
                    searchArea
                    Spacer()
                    bottomPanel
                }
            }
            .navigationTitle("Ubicación de entrega")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    // Pin centrado; la punta apunta al centro real del mapa.
    private var centerPin: some View {
        VStack(spacing: 0) {
            TreggaIcon(.pin, size: 38, color: TreggaColors.primary)
                .background(Circle().fill(.white).frame(width: 20, height: 20).offset(y: 4))
            Spacer().frame(height: 38)
        }
        .allowsHitTesting(false)
    }

    private var searchArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TreggaIcon(.search, size: 18, color: TreggaColors.textSec)
                TextField("Busca una dirección", text: $viewModel.query)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TreggaColors.text)
                    .autocorrectionDisabled(true)
                if viewModel.buscando { ProgressView().controlSize(.mini) }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(TreggaColors.card, in: Capsule())
            .overlay(Capsule().stroke(TreggaColors.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)

            if !viewModel.resultados.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.resultados) { p in
                        Button {
                            viewModel.elegir(p)
                            mapController.center(lat: p.lat, lng: p.lng)
                        } label: {
                            HStack(spacing: 10) {
                                TreggaIcon(.pin, size: 16, color: TreggaColors.textSec)
                                Text(p.address)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(TreggaColors.text)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        RowDivider()
                    }
                }
                .background(TreggaColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(TreggaColors.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TreggaIcon(.pin, size: 18, color: TreggaColors.primary)
                Text(viewModel.direccionActual)
                    .font(.system(size: 14.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                ForEach(etiquetas, id: \.self) { e in
                    Chip(e, isActive: label == e) { label = e }
                }
            }

            TextField("Referencias (opcional): casa azul, portón…", text: $referencias)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TreggaColors.text)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(TreggaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            TreggaButton("Guardar dirección") {
                onGuardar(label, viewModel.direccionActual, referencias.isEmpty ? nil : referencias, viewModel.place)
                dismiss()
            }
            .disabled(viewModel.place == nil)
        }
        .padding(16)
        .background(
            TreggaColors.bg
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
        .onChange(of: viewModel.query) { _, _ in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { return }
                await viewModel.buscar()
            }
        }
    }
}
