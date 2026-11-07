import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import TreggaDesignSystem

extension Notification.Name {
    /// Llegó un push de Costco con la app abierta: los detalles visibles se recargan.
    static let costcoPushRecibido = Notification.Name("costcoPushRecibido")
}

@MainActor
@Observable
final class CostcoPedidoDetailModel {
    private(set) var pedido: CostcoPedido?
    private(set) var config: CostcoConfig?
    private(set) var catalogo: [CostcoProducto] = []
    private(set) var cargando = false
    var error: String?
    var trabajando = false

    let pedidoId: UUID
    let repo: CostcoRepository

    init(pedidoId: UUID, repo: CostcoRepository, inicial: CostcoPedido? = nil) {
        self.pedidoId = pedidoId
        self.repo = repo
        self.pedido = inicial
    }

    func cargar() async {
        cargando = pedido == nil
        defer { cargando = false }
        do {
            async let p = repo.detalle(pedidoId: pedidoId)
            async let e = repo.estado()
            pedido = try await p
            config = try? await e.config
            if pedido?.pendientesDeDecision.isEmpty == false, catalogo.isEmpty {
                catalogo = (try? await repo.catalogo()) ?? []
            }
        } catch {
            if pedido == nil { self.error = (error as? CostcoError)?.mensaje ?? CostcoCopy.errorCarga }
        }
    }

    func ejecutar(_ op: () async throws -> CostcoPedido) async {
        guard !trabajando else { return }
        trabajando = true
        defer { trabajando = false }
        do {
            pedido = try await op()
        } catch {
            self.error = (error as? CostcoError)?.mensaje ?? CostcoCopy.errorRed
            await cargar()
        }
    }
}

/// Detalle del pedido Costco: estado, datos de depósito + comprobante, productos, montos, cancelar.
struct CostcoPedidoDetailView: View {
    @State var model: CostcoPedidoDetailModel
    var abrirNoEncontrado = false
    let onBack: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var fotoItem: PhotosPickerItem?
    @State private var showFotos = false
    @State private var showArchivo = false
    @State private var showOpcionesComprobante = false
    @State private var showCancelar = false
    @State private var itemDecision: CostcoItem?
    @State private var copiado = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CostcoUI.header(CostcoCopy.detalleTitulo, subtitulo: subtitulo, onBack: onBack)
                if let p = model.pedido {
                    contenido(p).padding(.horizontal, 16)
                } else if model.cargando {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                }
            }
            .padding(.bottom, 40)
        }
        .background(TreggaColors.bg)
        .toolbar(.hidden, for: .navigationBar)
        .swipeToGoBack { onBack() }
        .refreshable { await model.cargar() }
        .task {
            await model.cargar()
            if abrirNoEncontrado { itemDecision = model.pedido?.pendientesDeDecision.first }
        }
        .onChange(of: scenePhase) { _, fase in if fase == .active { Task { await model.cargar() } } }
        // Excepción a §5.1 (spec §9.4): en ruta y con la pantalla abierta, recarga cada ~10 s.
        .task(id: model.pedido?.enCamino == true) {
            while model.pedido?.enCamino == true, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if Task.isCancelled { break }
                await model.cargar()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .costcoPushRecibido)) { _ in
            Task { await model.cargar() }
        }
        .photosPicker(isPresented: $showFotos, selection: $fotoItem, matching: .images)
        .onChange(of: fotoItem) { _, item in
            guard let item else { return }
            Task { await subirFoto(item) }
        }
        .fileImporter(isPresented: $showArchivo, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result { Task { await subirPDF(url) } }
        }
        .confirmationDialog(CostcoCopy.subirComprobante, isPresented: $showOpcionesComprobante) {
            Button(CostcoCopy.comprobanteFoto) { showFotos = true }
            Button(CostcoCopy.comprobantePDF) { showArchivo = true }
        }
        .alert(CostcoCopy.cancelarConfirmTitulo, isPresented: $showCancelar) {
            Button(CostcoCopy.cancelarConfirmSi, role: .destructive) {
                Task { await model.ejecutar { try await model.repo.cancelar(pedidoId: model.pedidoId) } }
            }
            Button(CostcoCopy.cancelarConfirmNo, role: .cancel) {}
        } message: {
            Text(model.pedido?.estado == .esperandoAnticipo
                 ? CostcoCopy.cancelarConfirmSinAnticipo : CostcoCopy.cancelarConfirmConAnticipo)
        }
        .alert(model.error ?? "", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .sheet(item: $itemDecision) { item in
            CostcoNoEncontradoSheet(item: item, catalogo: model.catalogo) { sustituto in
                Task { await model.ejecutar { try await model.repo.resolverNoEncontrado(itemId: item.id, sustituto: sustituto) } }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var subtitulo: String? {
        model.pedido.map { CostcoCopy.viajeDel(CostcoFormat.fechaCorta(dia: $0.fechaViaje)) }
    }

    @ViewBuilder
    private func contenido(_ p: CostcoPedido) -> some View {
        estadoCard(p)
        if p.enCamino { CostcoRutaCard(pedido: p) }
        if let nota = p.entregaFallidaNota, p.entregaFallidaAt != nil, p.estado == .comprado {
            CostcoUI.banner(CostcoCopy.entregaFallida(nota: nota), icon: .warning, tono: TreggaColors.accent)
        }
        if !p.pendientesDeDecision.isEmpty {
            Button { itemDecision = p.pendientesDeDecision.first } label: {
                CostcoUI.banner(CostcoCopy.noEncontradoBanner, icon: .warning, tono: TreggaColors.accent)
            }
            .buttonStyle(.plain)
        }
        if p.estado == .esperandoAnticipo { deposito(p) }
        productos(p)
        montos(p)
        cancelacion(p)
    }

    private func estadoCard(_ p: CostcoPedido) -> some View {
        let e = CostcoCopy.estado(p.estado)
        let detalle = p.estado == .cancelado
            ? CostcoCopy.motivoCancelacion(p.cancelMotivo)
            : e.detalle.replacingOccurrences(of: "{viaje}", with: CostcoFormat.fechaCorta(dia: p.fechaViaje))
        return CostcoUI.card {
            Text(e.titulo).treggaStyle(.h3).foregroundStyle(TreggaColors.text)
            if !detalle.isEmpty {
                Text(detalle).font(.system(size: 14, weight: .medium)).foregroundStyle(TreggaColors.textSec)
            }
            if let nota = p.cancelNota, p.estado == .cancelado {
                Text(nota).font(.system(size: 14, weight: .medium)).foregroundStyle(TreggaColors.textSec)
            }
            if let fecha = p.entregaAcordadaAt {
                Text(CostcoCopy.entregaAcordada(fecha: CostcoFormat.fechaHora(fecha)))
                    .font(.system(size: 14, weight: .heavy)).foregroundStyle(TreggaColors.primaryDark)
            }
            if let cobrado = p.restoCobrado, cobrado > 0, p.estado == .entregado {
                Text(CostcoCopy.cobrado(monto: PriceFormat.pesos(cobrado), metodo: p.restoMetodo))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(TreggaColors.text)
            }
            if let monto = p.reembolsoMonto, monto > 0 {
                Text(p.reembolsoPendiente
                     ? CostcoCopy.reembolsoPendiente(monto: PriceFormat.pesos(monto))
                     : CostcoCopy.reembolsoHecho(monto: PriceFormat.pesos(monto)))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(TreggaColors.text)
            }
        }
    }

    private func deposito(_ p: CostcoPedido) -> some View {
        CostcoUI.card {
            Text(CostcoCopy.datosTransferencia).font(.system(size: 15, weight: .heavy)).foregroundStyle(TreggaColors.text)
            if let motivo = p.anticipoRechazoMotivo {
                CostcoUI.banner(CostcoCopy.comprobanteRechazado(motivo: motivo), icon: .warning, tono: TreggaColors.danger)
            }
            CostcoUI.row(CostcoCopy.montoADepositar, PriceFormat.pesos(p.anticipo), fuerte: true)
            if let clabe = model.config?.clabe {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(CostcoCopy.clabe).font(.system(size: 12, weight: .semibold)).foregroundStyle(TreggaColors.textSec)
                        Text(clabe).font(.system(size: 16, weight: .heavy).monospacedDigit()).foregroundStyle(TreggaColors.text)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button(copiado ? CostcoCopy.copiado : CostcoCopy.copiar) {
                        UIPasteboard.general.string = clabe
                        copiado = true
                    }
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(TreggaColors.primaryDark)
                }
            }
            if let titular = model.config?.titular {
                CostcoUI.row(CostcoCopy.titular, titular)
            }
            TreggaButton(model.trabajando ? CostcoCopy.subiendo
                         : (p.comprobantePath == nil ? CostcoCopy.subirComprobante : CostcoCopy.cambiarComprobante),
                         kind: .primary, icon: TreggaIcon.image(.camera)) {
                showOpcionesComprobante = true
            }
            .disabled(model.trabajando)
            .padding(.top, 4)
        }
    }

    private func productos(_ p: CostcoPedido) -> some View {
        CostcoUI.card {
            Text(CostcoCopy.productos).font(.system(size: 15, weight: .heavy)).foregroundStyle(TreggaColors.text)
            ForEach(p.items) { item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.cantidad) × \(item.descripcion)")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(item.estado == .quitado || item.estado == .sustituido ? TreggaColors.textTer : TreggaColors.text)
                            .strikethrough(item.estado == .quitado || item.estado == .sustituido)
                        if let pres = item.presentacion {
                            Text(pres).font(.system(size: 12.5, weight: .medium)).foregroundStyle(TreggaColors.textSec)
                        }
                        if let tag = CostcoCopy.itemEstado(item.estado) {
                            Text(tag).font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(item.estado == .noEncontrado ? TreggaColors.accent : TreggaColors.textSec)
                        } else if item.esLibre {
                            Text(CostcoCopy.precioEstimadoTag).font(.system(size: 11.5, weight: .bold)).foregroundStyle(TreggaColors.accent)
                        }
                    }
                    Spacer()
                    Text(PriceFormat.pesos(item.precioReal.map { $0 * Decimal(item.cantidad) } ?? item.importeEstimado))
                        .font(.system(size: 14, weight: .heavy)).foregroundStyle(TreggaColors.text)
                }
            }
        }
    }

    private func montos(_ p: CostcoPedido) -> some View {
        CostcoUI.card {
            if let total = p.totalReal {
                CostcoUI.row(CostcoCopy.totalReal, PriceFormat.pesos(total))
                CostcoUI.row(CostcoCopy.anticipoPagado, "− \(PriceFormat.pesos(p.anticipo))")
                if let resto = p.resto, resto > 0 {
                    if p.estado == .entregado {
                        CostcoUI.row(CostcoCopy.pagadoAlRecibir, PriceFormat.pesos(resto))
                    } else {
                        CostcoUI.row(CostcoCopy.restoAPagar, PriceFormat.pesos(resto), fuerte: true)
                    }
                }
            } else {
                CostcoUI.row(CostcoCopy.subtotal, PriceFormat.pesos(p.subtotalEstimado))
                CostcoUI.row(CostcoCopy.comision(pct: CostcoFormat.pct(model.config?.comisionPct ?? 10)), PriceFormat.pesos(p.comision))
                CostcoUI.row(CostcoCopy.envio, CostcoCopy.envioIncluido)
                CostcoUI.row(CostcoCopy.totalEstimado, PriceFormat.pesos(p.totalEstimado), fuerte: true)
                if p.estado != .cancelado {
                    CostcoUI.row(CostcoCopy.anticipoAhora(pct: CostcoFormat.pct(model.config?.anticipoPct ?? 50)), PriceFormat.pesos(p.anticipo))
                }
            }
        }
    }

    @ViewBuilder
    private func cancelacion(_ p: CostcoPedido) -> some View {
        if p.puedeCancelar {
            if let limite = p.limiteCancelacion {
                Text(CostcoCopy.puedesCancelarHasta(CostcoFormat.fechaHora(limite)))
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(TreggaColors.textSec)
            }
            TreggaButton(CostcoCopy.cancelarPedido, kind: .ghost) { showCancelar = true }
                .foregroundStyle(TreggaColors.danger)
                .disabled(model.trabajando)
        } else if p.estado == .confirmado {
            Text(CostcoCopy.yaNoCancelable)
                .font(.system(size: 13, weight: .medium)).foregroundStyle(TreggaColors.textSec)
        }
    }

    // MARK: Comprobante

    private func subirFoto(_ item: PhotosPickerItem) async {
        defer { fotoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.7) else {
            model.error = CostcoCopy.errorRed
            return
        }
        await model.ejecutar { try await model.repo.subirComprobante(pedidoId: model.pedidoId, data: jpeg, fileExtension: "jpg") }
    }

    private func subirPDF(_ url: URL) async {
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), data.count <= 10 * 1024 * 1024 else {
            model.error = CostcoCopy.comprobanteMuyGrande
            return
        }
        await model.ejecutar { try await model.repo.subirComprobante(pedidoId: model.pedidoId, data: data, fileExtension: "pdf") }
    }
}

/// Producto no encontrado: elegir otro (del catálogo o libre) o quitarlo y reembolsar.
struct CostcoNoEncontradoSheet: View {
    let item: CostcoItem
    let catalogo: [CostcoProducto]
    /// `nil` = quitar y reembolsar.
    let onDecidir: (CostcoItemSolicitud?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showLibre = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(CostcoCopy.noEncontradoAviso).font(.system(size: 13.5, weight: .medium)).foregroundStyle(TreggaColors.textSec)
                    Button(CostcoCopy.quitarYReembolsar, role: .destructive) { decidir(nil) }
                }
                Section(CostcoCopy.elegirOtro) {
                    Button(CostcoCopy.catalogoPedirLibre) { showLibre = true }
                    ForEach(catalogo.filter { $0.id != item.productoId }) { p in
                        Button {
                            decidir(.catalogo(productoId: p.id, cantidad: item.cantidad))
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.nombre).foregroundStyle(TreggaColors.text)
                                    if let pres = p.presentacion {
                                        Text(pres).font(.caption).foregroundStyle(TreggaColors.textSec)
                                    }
                                }
                                Spacer()
                                Text(PriceFormat.pesos(p.precioConComision)).foregroundStyle(TreggaColors.text)
                            }
                        }
                    }
                }
            }
            .navigationTitle(CostcoCopy.noEncontradoTitulo(item.descripcion))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showLibre) {
            CostcoLibreSheet(onAgregar: { d, c, precio in
                decidir(.libre(descripcion: d, cantidad: c, precioEstimado: precio))
            }, titulo: CostcoCopy.elegirOtro, cta: CostcoCopy.elegirOtro)
            .presentationDetents([.medium, .large])
        }
    }

    private func decidir(_ s: CostcoItemSolicitud?) {
        onDecidir(s)
        dismiss()
    }
}
