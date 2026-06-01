import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Direcciones guardadas: lista + agregar/editar/eliminar/hacer principal.
struct AddressesView: View {
    @Bindable var viewModel: AccountViewModel
    @State private var editor: EditorState?
    @State private var accionesPara: DireccionCliente?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Direcciones guardadas")

                SectionHeader("Tus lugares").padding(.top, 8)

                if viewModel.direcciones.isEmpty {
                    vacio
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.direcciones) { dir in
                            tarjeta(dir)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                TreggaButton("Agregar nueva dirección", icon: TreggaIcon.image(.plus)) {
                    editor = EditorState()
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .sheet(item: $editor) { state in
            AddressEditorSheet(state: state) { label, address, refs, isDefault in
                Task {
                    if let id = state.id {
                        await viewModel.editarDireccion(id: id, label: label, address: address, referencias: refs)
                    } else {
                        await viewModel.crearDireccion(label: label, address: address, referencias: refs, isDefault: isDefault)
                    }
                }
            }
        }
        .confirmationDialog(accionesPara?.label ?? "", isPresented: .init(
            get: { accionesPara != nil },
            set: { if !$0 { accionesPara = nil } }
        ), titleVisibility: .visible) {
            if let dir = accionesPara {
                if !dir.isDefault {
                    Button("Hacer principal") { Task { await viewModel.hacerDireccionPrincipal(id: dir.id) } }
                }
                Button("Editar") { editor = EditorState(from: dir) }
                Button("Eliminar", role: .destructive) { Task { await viewModel.eliminarDireccion(id: dir.id) } }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    private var vacio: some View {
        VStack(spacing: 8) {
            TreggaIcon(.pin, size: 36, color: TreggaColors.textTer)
            Text("Aún no guardas direcciones")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TreggaColors.textSec)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func tarjeta(_ dir: DireccionCliente) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(dir.isDefault ? TreggaColors.primarySoft : TreggaColors.surface)
                    .frame(width: 40, height: 40)
                TreggaIcon(iconFor(dir.label), size: 20, color: dir.isDefault ? TreggaColors.primaryDark : TreggaColors.text)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(dir.label)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                    if dir.isDefault { Tag("Principal", tone: .soft) }
                }
                Text(dir.address)
                    .font(.system(size: 13))
                    .foregroundStyle(TreggaColors.textSec)
                if !dir.detalleLine.isEmpty {
                    Text(dir.detalleLine)
                        .font(.system(size: 12.5))
                        .foregroundStyle(TreggaColors.textTer)
                }
            }
            Spacer(minLength: 4)
            Button { accionesPara = dir } label: {
                TreggaIcon(.more, size: 20, color: TreggaColors.textSec)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(TreggaColors.card)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func iconFor(_ label: String) -> TreggaIcon.Name {
        switch label.lowercased() {
        case let l where l.contains("casa") || l.contains("hogar"): return .home
        case let l where l.contains("trabajo") || l.contains("oficina"): return .bag
        default: return .pin
        }
    }
}

/// Estado del editor de dirección (alta o edición).
struct EditorState: Identifiable {
    let id: UUID?
    var label: String
    var address: String
    var referencias: String
    var isDefault: Bool

    init() {
        id = nil; label = "Casa"; address = ""; referencias = ""; isDefault = false
    }
    init(from dir: DireccionCliente) {
        id = dir.id; label = dir.label; address = dir.address
        referencias = dir.referencias ?? ""; isDefault = dir.isDefault
    }
}

private struct AddressEditorSheet: View {
    let state: EditorState
    let onSave: (_ label: String, _ address: String, _ refs: String?, _ isDefault: Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var address = ""
    @State private var referencias = ""
    @State private var isDefault = false

    private let etiquetas = ["Casa", "Trabajo", "Otro"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ETIQUETA")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(TreggaColors.textSec)
                        HStack(spacing: 8) {
                            ForEach(etiquetas, id: \.self) { e in
                                Chip(e, isActive: label == e) { label = e }
                            }
                        }
                    }
                    campo("Dirección", text: $address, placeholder: "Calle, número, colonia")
                    campo("Referencias", text: $referencias, placeholder: "Casa azul, frente al parque")
                    Toggle(isOn: $isDefault) {
                        Text("Marcar como principal")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(TreggaColors.text)
                    }
                    .tint(TreggaColors.primary)

                    TreggaButton("Guardar dirección") {
                        onSave(label, address, referencias.isEmpty ? nil : referencias, isDefault)
                        dismiss()
                    }
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(TreggaColors.bg)
            .navigationTitle(state.id == nil ? "Nueva dirección" : "Editar dirección")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear {
                label = etiquetas.contains(state.label) ? state.label : "Otro"
                address = state.address
                referencias = state.referencias
                isDefault = state.isDefault
            }
        }
    }

    private func campo(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(TreggaColors.textSec)
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TreggaColors.text)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(TreggaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
