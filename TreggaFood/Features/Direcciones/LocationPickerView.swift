import SwiftUI
import TreggaCore
import TreggaDesignSystem
import GoogleMaps
import Observation
import PhotosUI
import UIKit

/// Mapa con pin fijo al centro: reporta su centro al quedar quieto (para reverse
/// geocoding). El pin es un overlay SwiftUI, no un marcador, así queda centrado.
struct LocationPickerMapView: UIViewRepresentable {
    let initial: TrackCoord
    let controller: MapController
    var topPadding: CGFloat = 0
    var bottomPadding: CGFloat = 0
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

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // El padding recentra el target de la cámara (que reporta `idleAt`) dentro
        // del área visible entre la barra superior y el drawer, así el pin apunta
        // a la zona libre del mapa y no queda tapado por el panel.
        let nuevo = UIEdgeInsets(top: topPadding, left: 0, bottom: bottomPadding, right: 0)
        if mapView.padding != nuevo { mapView.padding = nuevo }
    }
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

    init(center: TrackCoord, addressPreload: String? = nil, placePreload: GeocodedPlace? = nil) {
        self.center = center
        if let addressPreload { self.direccionActual = addressPreload }
        self.place = placePreload
    }

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
        } else {
            // Sin reverse-geocoding (Geocoding API no disponible): igual dejamos
            // guardar usando las coordenadas del pin, para no bloquear al usuario.
            let etiqueta = String(format: "Ubicación seleccionada (%.5f, %.5f)", coord.lat, coord.lng)
            direccionActual = etiqueta
            place = GeocodedPlace(address: etiqueta, lat: coord.lat, lng: coord.lng,
                                  codigoPostal: nil, colonia: nil, municipio: nil, estado: nil)
        }
    }
}

/// Selector de ubicación: mapa con pin central + buscador + reverse geocoding.
struct LocationPickerView: View {
    @State private var viewModel: LocationPickerViewModel
    @State private var mapController = MapController()
    @State private var label = "Casa"
    @State private var referencias = ""
    @State private var instrucciones = ""
    @State private var fotosSel: [PhotosPickerItem] = []
    @State private var fotosImg: [UIImage] = []
    /// URLs de fotos ya guardadas (modo edición); se conservan salvo que se quiten.
    @State private var fotosExistentes: [String] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var locationProvider = CurrentLocationProvider()
    @State private var buscandoUbicacion = false
    @State private var ubicacionDenegada = false
    @State private var topH: CGFloat = 0
    @State private var drawerH: CGFloat = 0
    @State private var showFotoOpciones = false
    @State private var showLibrary = false
    @State private var showCamara = false
    @Environment(\.dismiss) private var dismiss

    /// `fotosExistentes`: URLs que el usuario decidió conservar; `nuevasFotos`: fotos
    /// recién tomadas/elegidas (Data para subir).
    let onGuardar: (_ label: String, _ address: String, _ referencias: String?,
                    _ instrucciones: String?, _ nuevasFotos: [Data],
                    _ fotosExistentes: [String], _ place: GeocodedPlace?) -> Void

    private let etiquetas = ["Casa", "Trabajo", "Otro"]

    private var totalFotos: Int { fotosExistentes.count + fotosImg.count }

    /// Alta: arranca en `center`, sin datos precargados.
    init(
        center: TrackCoord,
        onGuardar: @escaping (String, String, String?, String?, [Data], [String], GeocodedPlace?) -> Void
    ) {
        _viewModel = State(initialValue: LocationPickerViewModel(center: center))
        self.onGuardar = onGuardar
    }

    /// Edición: precarga ubicación, etiqueta, referencias, instrucciones y fotos.
    init(
        editing dir: DireccionCliente,
        onGuardar: @escaping (String, String, String?, String?, [Data], [String], GeocodedPlace?) -> Void
    ) {
        let center: TrackCoord = (dir.lat != nil && dir.lng != nil)
            ? TrackCoord(lat: dir.lat!, lng: dir.lng!)
            : TrackCoord(lat: 19.8642, lng: -100.8225)
        let place = GeocodedPlace(
            address: dir.address, lat: center.lat, lng: center.lng,
            calle: dir.calle,
            codigoPostal: dir.codigoPostal, colonia: dir.colonia,
            municipio: dir.municipio, estado: dir.estado
        )
        _viewModel = State(initialValue: LocationPickerViewModel(
            center: center, addressPreload: dir.address, placePreload: place))
        _label = State(initialValue: dir.label)
        _referencias = State(initialValue: dir.referencias ?? "")
        _instrucciones = State(initialValue: dir.instrucciones ?? "")
        _fotosExistentes = State(initialValue: dir.fotos)
        self.onGuardar = onGuardar
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LocationPickerMapView(
                    initial: viewModel.center,
                    controller: mapController,
                    topPadding: topH,
                    bottomPadding: drawerH,
                    onIdle: { coord in Task { await viewModel.mapaQuieto(coord) } }
                )
                .ignoresSafeArea()

                centerPin
                    .ignoresSafeArea()
                    .offset(y: (topH - drawerH) / 2)

                VStack(spacing: 0) {
                    searchArea
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height + proxy.safeAreaInsets.top
                        } action: { topH = $0 }
                    Spacer()
                    bottomPanel
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height + proxy.safeAreaInsets.bottom
                        } action: { drawerH = $0 }
                }
            }
            .navigationTitle("Ubicación de entrega")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert("Ubicación desactivada", isPresented: $ubicacionDenegada) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Activa el permiso de ubicación en Ajustes para usar tu ubicación actual.")
            }
            // Layout en capas (buscador en overlay + panel con scroll propio): el
            // orden de foco no es lineal, así que solo el check para ocultar teclado.
            .keyboardDismissToolbar()
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

            ubicacionActualButton

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
                            .contentShape(Rectangle())
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

    private var ubicacionActualButton: some View {
        Button {
            Task {
                buscandoUbicacion = true
                if let c = await locationProvider.current() {
                    mapController.center(lat: c.lat, lng: c.lng)
                    await viewModel.mapaQuieto(c)
                } else {
                    ubicacionDenegada = true
                }
                buscandoUbicacion = false
            }
        } label: {
            HStack(spacing: 8) {
                if buscandoUbicacion {
                    ProgressView().controlSize(.mini)
                } else {
                    TreggaIcon(.location, size: 16, color: TreggaColors.primary)
                }
                Text("Usar mi ubicación actual")
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(TreggaColors.card, in: Capsule())
            .overlay(Capsule().stroke(TreggaColors.primary.opacity(0.4), lineWidth: 1.2))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            ScrollView {
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

                    campo("Referencias (opcional): casa azul, portón…", text: $referencias)

                    Text("Para el repartidor")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.3)
                        .foregroundStyle(TreggaColors.textSec)
                        .padding(.top, 2)

                    TextField("Instrucciones: cómo llegar a la puerta exacta…",
                              text: $instrucciones, axis: .vertical)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(TreggaColors.text)
                        .lineLimit(2...4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(TreggaColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    fotosPicker
                }
                .padding(16)
            }
            .frame(maxHeight: 300)

            TreggaButton("Guardar dirección") {
                onGuardar(
                    label, viewModel.direccionActual,
                    referencias.isEmpty ? nil : referencias,
                    instrucciones.isEmpty ? nil : instrucciones,
                    fotosImg.compactMap { jpegComprimido($0) },
                    fotosExistentes,
                    viewModel.place
                )
                dismiss()
            }
            .disabled(viewModel.place == nil)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
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
        .onChange(of: fotosSel) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var nuevas: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        nuevas.append(img)
                    }
                }
                let espacio = max(0, 3 - totalFotos)
                fotosImg.append(contentsOf: nuevas.prefix(espacio))
                fotosSel = []
            }
        }
    }

    /// Redimensiona (máx 1280px) y comprime la foto antes de subirla, para no
    /// guardar imágenes de varios MB que el repartidor tendría que descargar.
    private func jpegComprimido(_ img: UIImage, maxDim: CGFloat = 1280, quality: CGFloat = 0.6) -> Data? {
        let lado = max(img.size.width, img.size.height)
        let escala = lado > maxDim ? maxDim / lado : 1
        let target = CGSize(width: img.size.width * escala, height: img.size.height * escala)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: quality)
    }

    private func campo(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(TreggaColors.text)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var fotosPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { showFotoOpciones = true } label: {
                HStack(spacing: 8) {
                    TreggaIcon(.camera, size: 16, color: TreggaColors.primary)
                    Text(totalFotos == 0 ? "Agregar fotos de la entrada" : "\(totalFotos) foto\(totalFotos == 1 ? "" : "s")")
                        .font(.system(size: 13.5, weight: .heavy))
                        .foregroundStyle(TreggaColors.primary)
                    Spacer()
                    TreggaIcon(.plus, size: 14, color: TreggaColors.primary)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(TreggaColors.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(TreggaColors.primary.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(totalFotos >= 3)
            .confirmationDialog("Agregar foto de la entrada", isPresented: $showFotoOpciones, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Tomar foto") { showCamara = true }
                }
                Button("Elegir de la galería") { showLibrary = true }
                Button("Cancelar", role: .cancel) {}
            }
            .photosPicker(isPresented: $showLibrary, selection: $fotosSel,
                          maxSelectionCount: max(1, 3 - totalFotos), matching: .images)
            .fullScreenCover(isPresented: $showCamara) {
                CameraPicker(onImage: { img in
                    if totalFotos < 3 { fotosImg.append(img) }
                }, preferRear: true)
                .ignoresSafeArea()
            }

            if totalFotos > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(fotosExistentes.enumerated()), id: \.element) { idx, url in
                            fotoThumb {
                                AsyncImage(url: URL(string: url)) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    ZStack { TreggaColors.surface; ProgressView().controlSize(.mini) }
                                }
                            } onRemove: {
                                fotosExistentes.remove(at: idx)
                            }
                        }
                        ForEach(Array(fotosImg.enumerated()), id: \.offset) { idx, img in
                            fotoThumb {
                                Image(uiImage: img).resizable().scaledToFill()
                            } onRemove: {
                                fotosImg.remove(at: idx)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Miniatura de foto (64×64) con botón para quitarla.
    private func fotoThumb<Content: View>(
        @ViewBuilder _ content: () -> Content,
        onRemove: @escaping () -> Void
    ) -> some View {
        content()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.black.opacity(0.55), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(3)
            }
    }
}
