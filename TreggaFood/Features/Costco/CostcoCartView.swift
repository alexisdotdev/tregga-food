import SwiftUI
import TreggaDesignSystem

/// Carrito Costco: renglones de catálogo y libres, desglose con comisión y avance al mínimo.
struct CostcoCartView: View {
    let model: CostcoFlowModel
    let onContinuar: () -> Void
    let onBack: () -> Void

    @Environment(\.costcoCart) private var cartEnv

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CostcoUI.header(CostcoCopy.carritoTitulo, onBack: onBack)
                    if let cart = cartEnv, !cart.isEmpty, let config = model.config {
                        lineas(cart).padding(.horizontal, 16)
                        TreggaDivider()
                        desglose(cart.totales(catalogo: model.catalogo, config: config), config: config)
                            .padding(.horizontal, 16)
                    } else {
                        Text(CostcoCopy.carritoVacio)
                            .treggaStyle(.sub).foregroundStyle(TreggaColors.textSec)
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(.bottom, 120)
            }
            if let cart = cartEnv, !cart.isEmpty, let config = model.config {
                let t = cart.totales(catalogo: model.catalogo, config: config)
                TreggaButton(CostcoCopy.continuar, kind: .dark, iconRight: TreggaIcon.image(.arrow), height: 56,
                             action: onContinuar)
                    .disabled(t.faltaParaMinimo > 0 || !model.puedePedir)
                    .opacity(t.faltaParaMinimo > 0 || !model.puedePedir ? 0.5 : 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
        }
        .background(TreggaColors.bg)
        .toolbar(.hidden, for: .navigationBar)
        .swipeToGoBack { onBack() }
        .task { await model.cargar(cart: cartEnv) }
        .alert(model.aviso ?? "", isPresented: Binding(get: { model.aviso != nil }, set: { if !$0 { model.aviso = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func lineas(_ cart: CostcoCartStore) -> some View {
        VStack(spacing: 14) {
            ForEach(cart.snapshot.catalogo.sorted(by: { $0.key.uuidString < $1.key.uuidString }), id: \.key) { id, cantidad in
                if let p = model.producto(id), let viajeId = cart.snapshot.viajeId {
                    linea(titulo: p.nombre, sub: p.presentacion, importe: p.precio * Decimal(cantidad),
                          tag: nil, cantidad: cantidad) { cart.setCantidad($0, productoId: id, viajeId: viajeId) }
                }
            }
            ForEach(cart.snapshot.libres) { l in
                linea(titulo: l.descripcion, sub: nil,
                      importe: l.precioEstimado * Decimal(l.cantidad),
                      tag: CostcoCopy.precioEstimadoTag, cantidad: l.cantidad) { cart.setCantidadLibre($0, id: l.id) }
            }
        }
    }

    private func linea(titulo: String, sub: String?, importe: Decimal, tag: String?, cantidad: Int,
                       onChange: @escaping (Int) -> Void) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo).font(.system(size: 15, weight: .heavy)).foregroundStyle(TreggaColors.text)
                if let sub { Text(sub).font(.system(size: 13, weight: .medium)).foregroundStyle(TreggaColors.textSec) }
                if let tag {
                    Text(tag).font(.system(size: 11, weight: .bold)).foregroundStyle(TreggaColors.accent)
                }
                Text(PriceFormat.pesos(CostcoCartStore.redondear(importe)))
                    .font(.system(size: 14, weight: .heavy)).foregroundStyle(TreggaColors.text)
            }
            Spacer()
            CostcoStepper(cantidad: cantidad, onChange: onChange)
        }
    }

    private func desglose(_ t: CostcoCartStore.Totales, config: CostcoConfig) -> some View {
        VStack(spacing: 8) {
            CostcoUI.row(CostcoCopy.subtotal, PriceFormat.pesos(t.subtotal))
            CostcoUI.row(CostcoCopy.comision(pct: CostcoFormat.pct(config.comisionPct)), PriceFormat.pesos(t.comision))
            CostcoUI.row(CostcoCopy.envio, CostcoCopy.envioIncluido)
            CostcoUI.row(CostcoCopy.totalEstimado, PriceFormat.pesos(t.total), fuerte: true)
            minimo(t, config: config).padding(.top, 6)
        }
    }

    private func minimo(_ t: CostcoCartStore.Totales, config: CostcoConfig) -> some View {
        let progreso = config.minimo > 0
            ? min(1, NSDecimalNumber(decimal: t.subtotal / config.minimo).doubleValue) : 1
        return VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progreso).tint(t.faltaParaMinimo > 0 ? TreggaColors.accent : TreggaColors.primary)
            Text(t.faltaParaMinimo > 0
                 ? CostcoCopy.faltaMinimo(falta: PriceFormat.pesos(t.faltaParaMinimo), minimo: PriceFormat.pesos(config.minimo))
                 : CostcoCopy.minimoAlcanzado)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(t.faltaParaMinimo > 0 ? TreggaColors.accent : TreggaColors.primaryDark)
        }
    }
}
