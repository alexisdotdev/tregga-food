import SwiftUI
import TreggaCore
import TreggaDesignSystem
import Observation

@MainActor
@Observable
final class DireccionPickerViewModel {
    private let repo: DireccionClienteRepository
    private let clienteId: UUID

    private(set) var direcciones: [DireccionCliente] = []
    private(set) var loading = true

    init(repo: DireccionClienteRepository, clienteId: UUID) {
        self.repo = repo
        self.clienteId = clienteId
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

    func crear(label: String, address: String, referencias: String?, isDefault: Bool) async {
        _ = try? await repo.crear(clienteId: clienteId, label: label, address: address, referencias: referencias, isDefault: isDefault)
        await cargar()
    }

    func editar(id: UUID, label: String, address: String, referencias: String?) async {
        _ = try? await repo.editar(id: id, label: label, address: address, referencias: referencias)
        await cargar()
    }

    func eliminar(_ dir: DireccionCliente) async {
        try? await repo.eliminar(id: dir.id)
        await cargar()
    }
}

/// Selector de dirección de entrega (estilo Uber): abre desde el header de Home.
/// Permite seleccionar la dirección activa, agregar nuevas y editarlas.
struct DireccionPickerView: View {
    @State private var viewModel: DireccionPickerViewModel
    @State private var editor: EditorState?
    @State private var accionesPara: DireccionCliente?
    /// Se llama cuando cambia la dirección activa, para que Home se refresque.
    let onSelected: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(viewModel: DireccionPickerViewModel, onSelected: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelected = onSelected
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    agregarButton
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if viewModel.loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        if let activa = viewModel.activa {
                            SectionHeader("Dirección actual").padding(.top, 22)
                            tarjeta(activa, esActual: true)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                        }

                        if !viewModel.otras.isEmpty {
                            SectionHeader("Tus direcciones").padding(.top, 22)
                            VStack(spacing: 12) {
                                ForEach(viewModel.otras) { dir in
                                    tarjeta(dir, esActual: false)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }

                        if viewModel.direcciones.isEmpty {
                            vacio
                        }
                    }

                    Spacer(minLength: 24)
                }
            }
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
            .sheet(item: $editor) { state in
                AddressEditorSheet(state: state) { label, address, refs, isDefault in
                    Task {
                        if let id = state.id {
                            await viewModel.editar(id: id, label: label, address: address, referencias: refs)
                        } else {
                            await viewModel.crear(label: label, address: address, referencias: refs, isDefault: isDefault)
                        }
                        onSelected()
                    }
                }
            }
            .confirmationDialog(accionesPara?.label ?? "", isPresented: .init(
                get: { accionesPara != nil },
                set: { if !$0 { accionesPara = nil } }
            ), titleVisibility: .visible) {
                if let dir = accionesPara {
                    Button("Editar") { editor = EditorState(from: dir) }
                    Button("Eliminar", role: .destructive) {
                        Task { await viewModel.eliminar(dir); onSelected() }
                    }
                    Button("Cancelar", role: .cancel) {}
                }
            }
        }
    }

    private var agregarButton: some View {
        Button { editor = EditorState() } label: {
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

    private func tarjeta(_ dir: DireccionCliente, esActual: Bool) -> some View {
        Button {
            if esActual {
                dismiss()
            } else {
                Task {
                    await viewModel.seleccionar(dir)
                    onSelected()
                    dismiss()
                }
            }
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
                Button { accionesPara = dir } label: {
                    TreggaIcon(.edit, size: 18, color: TreggaColors.textSec)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
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
