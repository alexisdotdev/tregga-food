import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Lista "Mis pedidos": en curso arriba, anteriores abajo.
struct MyOrdersView: View {
    @State var viewModel: MyOrdersViewModel
    let onTap: (PedidoResumen) -> Void
    /// Si se presenta de forma modal (p.ej. desde Cuenta), muestra un botón atrás.
    var onClose: (() -> Void)? = nil

    var body: some View {
        Group {
            switch viewModel.phase {
            case .cargando:
                estadoCentral { ProgressView() } texto: { Text("Buscando tus pedidos…") }
            case .vacio:
                vacio
            case .error(let msg):
                errorView(msg)
            case .cargado:
                lista
            }
        }
        .background(TreggaColors.bg)
        .refreshable { await viewModel.cargar() }
    }

    private var lista: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if !viewModel.enCurso.isEmpty {
                    SectionHeader("En curso").padding(.top, 4)
                    VStack(spacing: 12) {
                        ForEach(viewModel.enCurso) { pedido in
                            Button { onTap(pedido) } label: { OrderRowCard(pedido: pedido) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                if !viewModel.anteriores.isEmpty {
                    SectionHeader("Anteriores").padding(.top, 18)
                    VStack(spacing: 12) {
                        ForEach(viewModel.anteriores) { pedido in
                            Button { onTap(pedido) } label: { OrderRowCard(pedido: pedido) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 120)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let onClose {
                Button { onClose() } label: {
                    ZStack {
                        Circle().fill(TreggaColors.surface).frame(width: 40, height: 40)
                        TreggaIcon(.chevL, size: 20, color: TreggaColors.text)
                    }
                }
                .buttonStyle(.plain)
            }
            Text("Pedidos")
                .treggaStyle(onClose == nil ? .h1 : .h2)
                .foregroundStyle(TreggaColors.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var vacio: some View {
        VStack(spacing: 12) {
            TreggaIcon(.bag, size: 40, color: TreggaColors.textTer)
            Text("Aún no tienes pedidos")
                .treggaStyle(.h3)
                .foregroundStyle(TreggaColors.text)
            Text("Cuando hagas tu primer pedido lo verás aquí con todo su detalle.")
                .treggaStyle(.sub)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            TreggaIcon(.info, size: 36, color: TreggaColors.danger)
            Text(msg)
                .treggaStyle(.sub)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 40)
            TreggaButton("Reintentar", kind: .secondary, isFullWidth: false, height: 44) {
                Task { await viewModel.cargar() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func estadoCentral<C: View, T: View>(@ViewBuilder _ content: () -> C, @ViewBuilder texto: () -> T) -> some View {
        VStack(spacing: 12) {
            content()
            texto()
                .treggaStyle(.sub)
                .foregroundStyle(TreggaColors.textSec)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Fila de un pedido en el historial.
private struct OrderRowCard: View {
    let pedido: PedidoResumen

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(OrderDateFormat.uppercaseWhen(pedido.fecha))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.2)
                    .textCase(.uppercase)
                    .foregroundStyle(TreggaColors.textSec)
                Spacer()
                Tag(pedido.status.tagLabel, tone: tone)
            }
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: TreggaRadius.md).fill(TreggaColors.primarySoft).frame(width: 52, height: 52)
                    TreggaIcon(.bag, size: 22, color: TreggaColors.primaryDark)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(pedido.negocioName)
                        .font(.system(size: 15.5, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                        .lineLimit(1)
                    Text(pedido.itemsResumen)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        Text(PriceFormat.pesos(pedido.total))
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(TreggaColors.text)
                        if let rating = pedido.rating {
                            HStack(spacing: 2) {
                                TreggaIcon(.star, size: 12, color: TreggaColors.star)
                                Text("\(rating)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(TreggaColors.textSec)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 4)
                TreggaIcon(.chevR, size: 18, color: TreggaColors.textSec)
            }
        }
        .padding(14)
        .background(TreggaColors.card, in: RoundedRectangle(cornerRadius: TreggaRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: TreggaRadius.xl).stroke(TreggaColors.border, lineWidth: 1))
    }

    private var tone: Tag.Tone {
        switch pedido.status {
        case .completed: return .soft
        case .cancelled: return .danger
        default:         return .warm
        }
    }
}

/// Formateo de fechas para el historial/detalle de pedidos.
enum OrderDateFormat {
    private static let full: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "d MMM · h:mm a"
        return f
    }()

    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "d MMM"
        return f
    }()

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "h:mm a"
        return f
    }()

    static func uppercaseWhen(_ date: Date?) -> String {
        guard let date else { return "—" }
        if Calendar.current.isDateInToday(date) {
            return "Hoy · \(time.string(from: date))"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Ayer · \(time.string(from: date))"
        }
        return dayMonth.string(from: date)
    }

    static func headerSub(_ date: Date?) -> String {
        guard let date else { return "" }
        if Calendar.current.isDateInToday(date) {
            return "Hoy · \(time.string(from: date))"
        }
        return full.string(from: date)
    }
}
