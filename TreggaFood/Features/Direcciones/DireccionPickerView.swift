import SwiftUI
import TreggaCore
import TreggaDesignSystem
import Observation

@MainActor
@Observable
final class DireccionPickerViewModel {
    private let repo: DireccionClienteRepository
    private let clienteId: UUID
    private let storage: StorageService
    private let userId: UUID

    private(set) var direcciones: [DireccionCliente] = []
    private(set) var loading = true

    init(repo: DireccionClienteRepository, clienteId: UUID, storage: StorageService, userId: UUID) {
        self.repo = repo
        self.clienteId = clienteId
        self.storage = storage
        self.userId = userId
    }

    /// La dirección activa de entrega (principal) y el resto.
    var activa: DireccionCliente? { direcciones.first(where: \.isDefault) ?? direcciones.first }
    var otras: [DireccionCliente] { direcciones.filter { $0.id != activa?.id } }

    func cargar() async {
        direcciones = (try? await repo.fetchDelCliente(clienteId: clienteId)) ?? []
        loading = false
    }

    func seleccionar(_ dir: DireccionCliente) async {
        guard !dir.isDefault else { return }
        try? await repo.hacerDefault(id: dir.id, clienteId: clienteId)
        await cargar()
    }

    func eliminar(_ dir: DireccionCliente) async {
        try? await repo.eliminar(id: dir.id)
        await cargar()
    }

    /// Centro inicial del selector de mapa: la dirección activa (si tiene coords)
    /// o el centro de Zinapécuaro como respaldo.
    var centroInicial: TrackCoord {
        if let a = activa, let la = a.lat, let lo = a.lng { return TrackCoord(lat: la, lng: lo) }
        return TrackCoord(lat: 19.8642, lng: -100.8225)
    }

    /// Alta con coordenadas + instrucciones + fotos (desde el selector de pin).
    /// Sube las fotos al storage y guarda sus URLs. La deja como principal.
    func crearConUbicacion(
        label: String, address: String, referencias: String?,
        instrucciones: String?, fotosData: [Data], place: GeocodedPlace?
    ) async {
        var urls: [String] = []
        for (i, data) in fotosData.enumerated() {
            if let url = try? await storage.uploadAvatar(
                data: data, userId: userId, fileName: "direcciones/\(UUID().uuidString)-\(i).jpg"
            ) {
                urls.append(url.absoluteString)
            }
        }
        let nueva = try? await repo.crear(
            clienteId: clienteId, label: label, address: address, referencias: referencias, isDefault: false,
            lat: place?.lat, lng: place?.lng,
            calle: place?.calle,
            codigoPostal: place?.codigoPostal, colonia: place?.colonia, municipio: place?.municipio, estado: place?.estado,
            instrucciones: instrucciones, fotos: urls
        )
        if let nueva { try? await repo.hacerDefault(id: nueva.id, clienteId: clienteId) }
        await cargar()
    }

    /// Edición con coordenadas + instrucciones + fotos (desde el selector de pin).
    /// Conserva las fotos existentes elegidas y sube las nuevas. No cambia la principal.
    func editarConUbicacion(
        id: UUID, label: String, address: String, referencias: String?,
        instrucciones: String?, nuevasFotos: [Data], fotosExistentes: [String], place: GeocodedPlace?
    ) async {
        var urls = fotosExistentes
        for (i, data) in nuevasFotos.enumerated() {
            if let url = try? await storage.uploadAvatar(
                data: data, userId: userId, fileName: "direcciones/\(UUID().uuidString)-\(i).jpg"
            ) {
                urls.append(url.absoluteString)
            }
        }
        _ = try? await repo.actualizar(
            id: id, label: label, address: address, referencias: referencias,
            lat: place?.lat, lng: place?.lng,
            calle: place?.calle,
            codigoPostal: place?.codigoPostal, colonia: place?.colonia,
            municipio: place?.municipio, estado: place?.estado,
            instrucciones: instrucciones, fotos: urls
        )
        await cargar()
    }
}

/// Selector de dirección de entrega (estilo Uber): abre desde el header de Home.
/// Permite seleccionar la dirección activa, agregar nuevas y editarlas.
struct DireccionPickerView: View {
    @State private var viewModel: DireccionPickerViewModel
    @State private var sheet: DireccionSheet?
    /// Se llama cuando cambia la dirección activa, para que Home se refresque.
    let onSelected: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// Una sola presentación (agregar/editar). Evita el bug de SwiftUI de tener
    /// dos `.fullScreenCover` en la misma vista: el de editar se presentaba y se
    /// cerraba de inmediato ("baja la pantalla y regresa").
    private enum DireccionSheet: Identifiable {
        case agregar
        case editar(DireccionCliente)
        var id: String {
            switch self {
            case .agregar: return "agregar"
            case .editar(let d): return d.id.uuidString
            }
        }
    }

    init(viewModel: DireccionPickerViewModel, onSelected: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelected = onSelected
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    agregarButton
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                if viewModel.loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    if let activa = viewModel.activa {
                        Section {
                            fila(activa, esActual: true)
                        } header: {
                            SectionHeader("Dirección actual")
                                .textCase(nil)
                                .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
                        }
                    }

                    if !viewModel.otras.isEmpty {
                        Section {
                            ForEach(viewModel.otras) { dir in
                                fila(dir, esActual: false)
                            }
                        } header: {
                            SectionHeader("Tus direcciones")
                                .textCase(nil)
                                .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
                        }
                    }

                    if viewModel.direcciones.isEmpty {
                        vacio
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(TreggaColors.bg)
            .navigationTitle("Direcciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        TreggaIcon(.chevL, size: 22, color: TreggaColors.text)
                    }
                }
            }
            .task { await viewModel.cargar() }
            .fullScreenCover(item: $sheet) { s in
                switch s {
                case .agregar:
                    LocationPickerView(center: viewModel.centroInicial) { label, address, refs, instrucciones, fotosData, _, place in
                        Task {
                            await viewModel.crearConUbicacion(
                                label: label, address: address, referencias: refs,
                                instrucciones: instrucciones, fotosData: fotosData, place: place
                            )
                            onSelected()
                        }
                    }
                case .editar(let dir):
                    LocationPickerView(editing: dir) { label, address, refs, instrucciones, nuevas, existentes, place in
                        Task {
                            await viewModel.editarConUbicacion(
                                id: dir.id, label: label, address: address, referencias: refs,
                                instrucciones: instrucciones, nuevasFotos: nuevas,
                                fotosExistentes: existentes, place: place
                            )
                            onSelected()
                        }
                    }
                }
            }
        }
    }

    private var agregarButton: some View {
        Button { sheet = .agregar } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(TreggaColors.primarySoft).frame(width: 40, height: 40)
                    TreggaIcon(.plus, size: 20, color: TreggaColors.primaryDark)
                }
                Text("Agregar dirección")
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                Spacer()
                TreggaIcon(.chevR, size: 18, color: TreggaColors.textTer)
            }
            .padding(14)
            .background(TreggaColors.card)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    /// Fila de la lista: la tarjeta + acciones por deslizamiento (Editar/Eliminar).
    private func fila(_ dir: DireccionCliente, esActual: Bool) -> some View {
        tarjeta(dir, esActual: esActual)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    Task { await viewModel.eliminar(dir); onSelected() }
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
                Button {
                    sheet = .editar(dir)
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                .tint(TreggaColors.primary)
            }
    }

    private func tarjeta(_ dir: DireccionCliente, esActual: Bool) -> some View {
        Button {
            sheet = .editar(dir)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(esActual ? TreggaColors.primarySoft : TreggaColors.surface)
                        .frame(width: 40, height: 40)
                    TreggaIcon(iconFor(dir.label), size: 20, color: esActual ? TreggaColors.primaryDark : TreggaColors.text)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(dir.label)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(TreggaColors.text)
                        if esActual { Tag("Actual", tone: .soft) }
                    }
                    Text(dir.address)
                        .font(.system(size: 13))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(TreggaColors.textSec)
                    if !dir.detalleLine.isEmpty {
                        Text(dir.detalleLine)
                            .font(.system(size: 12.5))
                            .foregroundStyle(TreggaColors.textTer)
                    }
                }
                Spacer(minLength: 4)
                TreggaIcon(.chevR, size: 16, color: TreggaColors.textTer)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(esActual ? TreggaColors.primarySoft.opacity(0.4) : TreggaColors.card)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(esActual ? TreggaColors.primary.opacity(0.4) : TreggaColors.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var vacio: some View {
        VStack(spacing: 8) {
            TreggaIcon(.pin, size: 36, color: TreggaColors.textTer)
            Text("Aún no guardas direcciones")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TreggaColors.textSec)
            Text("Agrega una para pedir a domicilio.")
                .font(.system(size: 13))
                .foregroundStyle(TreggaColors.textTer)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func iconFor(_ label: String) -> TreggaIcon.Name {
        switch label.lowercased() {
        case let l where l.contains("casa") || l.contains("hogar"): return .home
        case let l where l.contains("trabajo") || l.contains("oficina"): return .bag
        default: return .pin
        }
    }
}
