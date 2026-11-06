import SwiftUI
import TreggaDesignSystem

/// Catálogo curado + "Pedir algo que no está en la lista". Invitado: ve, pero agregar pide login.
struct CostcoCatalogView: View {
    let model: CostcoFlowModel
    let onCarrito: () -> Void
    let onBack: () -> Void

    @Environment(\.costcoCart) private var cartEnv
    @Environment(\.clientShell) private var shell
    @State private var showLibre = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CostcoUI.header(CostcoCopy.catalogoTitulo, subtitulo: subtitulo, onBack: onBack)
                    contenido.padding(.horizontal, 16)
                }
                .padding(.bottom, 120)
            }
            .refreshable { await model.cargar(cart: cartEnv) }

            if let cart = cartEnv, !cart.isEmpty {
                TreggaButton("\(CostcoCopy.verCarrito) (\(cart.cantidadTotal))", kind: .dark,
                             iconRight: TreggaIcon.image(.arrow), height: 56, action: onCarrito)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
        }
        .background(TreggaColors.bg)
        .toolbar(.hidden, for: .navigationBar)
        .swipeToGoBack { onBack() }
        .task { await model.cargar(cart: cartEnv) }
        .sheet(isPresented: $showLibre) {
            CostcoLibreSheet { descripcion, cantidad, precio in
                if let viajeId = model.estado?.viaje?.id {
                    cartEnv?.agregarLibre(descripcion: descripcion, cantidad: cantidad, precioEstimado: precio, viajeId: viajeId)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .alert(model.aviso ?? "", isPresented: Binding(get: { model.aviso != nil }, set: { if !$0 { model.aviso = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var subtitulo: String? {
        model.config.map { CostcoCopy.catalogoComision(pct: CostcoFormat.pct($0.comisionPct)) }
    }

    @ViewBuilder
    private var contenido: some View {
        switch model.phase {
        case .cargando:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
        case .error(let msg):
            VStack(spacing: 12) {
                Text(msg).treggaStyle(.sub).foregroundStyle(TreggaColors.textSec).multilineTextAlignment(.center)
                TreggaButton(CostcoCopy.reintentar, kind: .secondary, isFullWidth: false) {
                    Task { await model.cargar(cart: cartEnv) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        case .listo:
            CostcoUI.banner(CostcoHomeCard.subtitulo(model.estado), icon: .calendar,
                            tono: model.puedePedir ? TreggaColors.primary : TreggaColors.textSec)
            if model.puedePedir {
                botonLibre
            }
            // Sin viaje no hay "Pedir algo que no está en la lista", así que el texto no aplica.
            if model.catalogo.isEmpty && model.puedePedir {
                Text(CostcoCopy.catalogoVacio)
                    .treggaStyle(.sub).foregroundStyle(TreggaColors.textSec)
            }
            ForEach(model.catalogo) { producto in
                fila(producto)
                TreggaDivider()
            }
        }
    }

    private var botonLibre: some View {
        Button { agregar { showLibre = true } } label: {
            HStack(spacing: 10) {
                TreggaIcon(.edit, size: 18, color: TreggaColors.primaryDark)
                Text(CostcoCopy.catalogoPedirLibre)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(TreggaColors.primaryDark)
                Spacer()
                TreggaIcon(.plus, size: 18, color: TreggaColors.primaryDark)
            }
            .padding(14)
            .background(TreggaColors.primarySoft, in: RoundedRectangle(cornerRadius: TreggaRadius.lg))
        }
        .buttonStyle(.plain)
    }

    private func fila(_ p: CostcoProducto) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: p.fotoURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                TreggaIcon(.box, size: 22, color: TreggaColors.textTer)
            }
            .frame(width: 64, height: 64)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TreggaRadius.md))

            VStack(alignment: .leading, spacing: 2) {
                Text(p.nombre).font(.system(size: 15, weight: .heavy)).foregroundStyle(TreggaColors.text)
                if let pres = p.presentacion {
                    Text(pres).font(.system(size: 13, weight: .medium)).foregroundStyle(TreggaColors.textSec)
                }
                Text(PriceFormat.pesos(p.precioConComision))
                    .font(.system(size: 15, weight: .heavy)).foregroundStyle(TreggaColors.text)
                Text("Costco \(PriceFormat.pesos(p.precio))")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(TreggaColors.textTer)
            }
            Spacer(minLength: 0)
            if model.puedePedir, let viajeId = model.estado?.viaje?.id {
                let cantidad = cartEnv?.cantidad(de: p.id) ?? 0
                if cantidad == 0 {
                    TreggaButton(CostcoCopy.agregar, kind: .primary, isFullWidth: false, height: 38) {
                        agregar { cartEnv?.setCantidad(1, productoId: p.id, viajeId: viajeId) }
                    }
                } else {
                    CostcoStepper(cantidad: cantidad) { cartEnv?.setCantidad($0, productoId: p.id, viajeId: viajeId) }
                }
            }
        }
    }

    private func agregar(_ action: () -> Void) {
        if shell?.isGuest == true { shell?.requestLogin() } else { action() }
    }
}

/// Hoja para un renglón libre: producto, cantidad y precio aproximado.
struct CostcoLibreSheet: View {
    let onAgregar: (String, Int, Decimal) -> Void
    var titulo: String = CostcoCopy.libreTitulo
    var cta: String = CostcoCopy.libreAgregar
    @Environment(\.dismiss) private var dismiss
    @State private var descripcion = ""
    @State private var cantidad = 1
    @State private var precioTexto = ""

    private var precio: Decimal? {
        Decimal(string: precioTexto.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
            .flatMap { $0 > 0 ? $0 : nil }
    }
    private var valido: Bool {
        !descripcion.trimmingCharacters(in: .whitespaces).isEmpty && precio != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(titulo).treggaStyle(.h3).foregroundStyle(TreggaColors.text)
            campo(CostcoCopy.libreDescripcion) {
                TextField(CostcoCopy.libreDescripcionPlaceholder, text: $descripcion)
                    .onChange(of: descripcion) { _, v in if v.count > 200 { descripcion = String(v.prefix(200)) } }
            }
            campo(CostcoCopy.librePrecio) {
                TextField("$0.00", text: $precioTexto).keyboardType(.decimalPad)
            }
            HStack {
                Text("Cantidad").font(.system(size: 15, weight: .semibold)).foregroundStyle(TreggaColors.text)
                Spacer()
                CostcoStepper(cantidad: cantidad) { cantidad = min(max($0, 1), CostcoCartStore.maxCantidad) }
            }
            Text(CostcoCopy.libreAviso).treggaStyle(.sub).foregroundStyle(TreggaColors.textSec)
            Spacer(minLength: 0)
            TreggaButton(cta, kind: .primary) {
                guard let precio else { return }
                onAgregar(descripcion.trimmingCharacters(in: .whitespacesAndNewlines), cantidad, precio)
                dismiss()
            }
            .disabled(!valido)
            .opacity(valido ? 1 : 0.5)
        }
        .padding(20)
        .background(TreggaColors.bg)
        .keyboardDismissToolbar()
    }

    private func campo<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(TreggaColors.textSec)
            content()
                .font(.system(size: 15, weight: .medium))
                .padding(12)
                .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.lg))
        }
    }
}
