import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Detalle de producto: hero + descripción + grupos de modificadores + CTA con stepper.
/// El carrito real es F3; por ahora `onAdd` recibe la selección construida.
struct ItemDetailView: View {
    let negocioName: String
    let onAdd: (ProductSelection) -> Void

    @State private var viewModel: ItemDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        producto: Producto,
        negocioName: String,
        catalog: CatalogRepository,
        onAdd: @escaping (ProductSelection) -> Void
    ) {
        self.negocioName = negocioName
        self.onAdd = onAdd
        _viewModel = State(initialValue: ItemDetailViewModel(producto: producto, repository: catalog))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    head
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    TreggaDivider()
                    grupos
                }
                .padding(.bottom, 110)
            }
            .background(TreggaColors.bg)
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 8) {
                if viewModel.hayGrupoRequeridoSinOpciones {
                    // Un grupo obligatorio sin opciones disponibles: el CTA queda
                    // deshabilitado; explicamos por qué en vez de dejarlo opaco.
                    Text("Opciones no disponibles temporalmente")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TreggaColors.danger)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(TreggaColors.dangerBg, in: Capsule())
                        .padding(.horizontal, 16)
                }
                cta
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .swipeBackToDismiss()
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            CoverImage(url: viewModel.producto.imageURL, seed: viewModel.producto.nombre)
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .clipped()
            Button { dismiss() } label: {
                TreggaIcon(.close, size: 20, color: Color(red: 0.04, green: 0.06, blue: 0.05))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.95), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
    }

    private var head: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.producto.nombre)
                .treggaStyle(.h2)
                .foregroundStyle(TreggaColors.text)
            Text(PriceFormat.pesos(viewModel.producto.precio))
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
            if let desc = viewModel.producto.descripcion, !desc.isEmpty {
                Text(desc)
                    .treggaStyle(.body)
                    .foregroundStyle(TreggaColors.textSec)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var grupos: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        case .ready(let grupos):
            ForEach(grupos) { grupo in
                grupoSection(grupo)
                TreggaDivider()
            }
        case .error(let message):
            VStack(spacing: 12) {
                Text(message)
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
                    .multilineTextAlignment(.center)
                TreggaButton("Reintentar", kind: .secondary, isFullWidth: false) {
                    Task { await viewModel.load() }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 30)
        }
    }

    private func grupoSection(_ grupo: GrupoModificadores) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(grupo.nombre)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                Spacer()
                Tag(grupo.isRequired ? "Obligatorio" : "Opcional", tone: grupo.isRequired ? .soft : .default)
            }
            Text(reglaLabel(grupo))
                .treggaStyle(.caption)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.top, 4)
                .padding(.bottom, 6)

            ForEach(grupo.modificadores) { mod in
                modRow(grupo: grupo, mod: mod)
                if mod.id != grupo.modificadores.last?.id {
                    Divider().background(TreggaColors.divider)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func reglaLabel(_ grupo: GrupoModificadores) -> String {
        if grupo.isSingleChoice { return "Selecciona 1 opción" }
        if grupo.minSelecciones > 0 { return "Elige de \(grupo.minSelecciones) a \(grupo.maxSelecciones)" }
        return "Hasta \(grupo.maxSelecciones)"
    }

    private func modRow(grupo: GrupoModificadores, mod: Modificador) -> some View {
        let selected = viewModel.isSelected(grupo: grupo, modificador: mod)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.toggle(grupo: grupo, modificador: mod)
            }
        } label: {
            HStack(spacing: 12) {
                selector(isSingle: grupo.isSingleChoice, selected: selected)
                Text(mod.nombre)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(TreggaColors.text)
                Spacer()
                if mod.precioExtra > 0 {
                    Text("+\(PriceFormat.pesos(mod.precioExtra))")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(TreggaColors.textSec)
                }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!mod.isAvailable)
        .opacity(mod.isAvailable ? 1 : 0.4)
    }

    @ViewBuilder
    private func selector(isSingle: Bool, selected: Bool) -> some View {
        if isSingle {
            ZStack {
                Circle()
                    .stroke(selected ? TreggaColors.primary : TreggaColors.border, lineWidth: 2)
                    .background(Circle().fill(selected ? TreggaColors.primary : .clear))
                    .frame(width: 22, height: 22)
                if selected {
                    Circle().fill(.white).frame(width: 8, height: 8)
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(selected ? TreggaColors.primary : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? TreggaColors.primary : TreggaColors.border, lineWidth: 2)
                )
                .frame(width: 22, height: 22)
                .overlay(selected ? TreggaIcon(.check, size: 12, color: .white, weight: .bold) : nil)
        }
    }

    private var cta: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                stepperButton(.minus) { viewModel.decrementar() }
                Text("\(viewModel.cantidad)")
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(TreggaColors.onPrimary)
                    .frame(minWidth: 18)
                stepperButton(.plus) { viewModel.incrementar() }
            }
            .padding(.horizontal, 4)
            .frame(height: 44)
            .background(Color.white.opacity(0.22), in: Capsule())

            Button {
                onAdd(viewModel.buildSelection())
            } label: {
                Text("Agregar \(viewModel.cantidad) · \(PriceFormat.pesos(viewModel.total))")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(TreggaColors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.puedeAgregar)
            .opacity(viewModel.puedeAgregar ? 1 : 0.6)
        }
        .padding(8)
        .frame(height: 60)
        .background(TreggaColors.primary, in: Capsule())
        .shadow(color: TreggaColors.primary.opacity(0.32), radius: 14, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func stepperButton(_ icon: TreggaIcon.Name, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TreggaIcon(icon, size: 16, color: TreggaColors.onPrimary, weight: .bold)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.32), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
