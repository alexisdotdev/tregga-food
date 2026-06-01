import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Carrito: líneas con stepper + quitar, nota para el negocio, subtotal + envío
/// estimado y CTA "Ir a pagar" hacia el checkout.
struct CartView: View {
    @Bindable var cart: CartStore
    /// Empuja el checkout.
    let onCheckout: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var nota: String = ""
    private let deliveryFeeEstimado: Decimal = 25

    var body: some View {
        ZStack(alignment: .bottom) {
            if cart.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        lineas
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        TreggaDivider().padding(.vertical, 16)
                        notaSection
                            .padding(.horizontal, 16)
                        TreggaDivider().padding(.vertical, 16)
                        totales
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 120)
                }
                .background(TreggaColors.bg)

                cta
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    TreggaIcon(.close, size: 18, color: TreggaColors.text)
                        .frame(width: 36, height: 36)
                        .background(TreggaColors.surface, in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            Text("Tu carrito")
                .treggaStyle(.h2)
                .foregroundStyle(TreggaColors.text)
                .padding(.top, 4)
            if !cart.negocioName.isEmpty {
                Text(cart.negocioName)
                    .treggaStyle(.sub)
                    .foregroundStyle(TreggaColors.textSec)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var lineas: some View {
        VStack(spacing: 14) {
            ForEach(cart.items) { line in
                CartLineRow(
                    line: line,
                    onIncrement: { cart.increment(lineId: line.id) },
                    onDecrement: { cart.decrement(lineId: line.id) },
                    onRemove: { withAnimation { cart.remove(lineId: line.id) } }
                )
            }
        }
    }

    private var notaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TreggaIcon(.edit, size: 18, color: TreggaColors.text)
                Text("Nota para el negocio")
                    .font(.system(size: 14.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
            }
            TextField("Ej. sin cebolla, por favor", text: $nota, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TreggaColors.text)
                .padding(12)
                .background(TreggaColors.surface, in: RoundedRectangle(cornerRadius: TreggaRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: TreggaRadius.lg).stroke(TreggaColors.border, lineWidth: 1)
                )
        }
    }

    private var totales: some View {
        VStack(spacing: 8) {
            row("Subtotal", PriceFormat.pesos(cart.subtotal))
            row("Envío estimado", PriceFormat.pesos(deliveryFeeEstimado))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TreggaColors.textSec)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
        }
    }

    private var cta: some View {
        VStack {
            TreggaButton(
                "Ir a pagar · \(PriceFormat.pesos(cart.subtotal + deliveryFeeEstimado))",
                kind: .dark,
                iconRight: TreggaIcon.image(.arrow),
                height: 56
            ) { onCheckout() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.bar)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    TreggaIcon(.close, size: 18, color: TreggaColors.text)
                        .frame(width: 36, height: 36)
                        .background(TreggaColors.surface, in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            Spacer()
            TreggaIcon(.bag, size: 44, color: TreggaColors.textTer)
            Text("Tu carrito está vacío")
                .treggaStyle(.h3)
                .foregroundStyle(TreggaColors.text)
            Text("Agrega productos desde un negocio para empezar tu pedido.")
                .treggaStyle(.sub)
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Una línea del carrito con stepper y botón de quitar.
private struct CartLineRow: View {
    let line: CartLine
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(line.producto.nombre)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                    Spacer()
                    Text(PriceFormat.pesos(line.subtotal))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                }
                if !line.modificadoresLabel.isEmpty {
                    Text(line.modificadoresLabel)
                        .treggaStyle(.caption)
                        .foregroundStyle(TreggaColors.textSec)
                }
                if let nota = line.nota, !nota.isEmpty {
                    Text("“\(nota)”")
                        .treggaStyle(.caption)
                        .italic()
                        .foregroundStyle(TreggaColors.textSec)
                }
                HStack(spacing: 12) {
                    stepper
                    Button(action: onRemove) {
                        HStack(spacing: 4) {
                            TreggaIcon(.trash, size: 13, color: TreggaColors.danger)
                            Text("Quitar")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(TreggaColors.danger)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            Button(action: onDecrement) {
                TreggaIcon(line.cantidad <= 1 ? .trash : .minus, size: 13, color: TreggaColors.text, weight: .bold)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            Text("\(line.cantidad)")
                .font(.system(size: 14, weight: .heavy))
                .monospacedDigit()
                .frame(minWidth: 16)
                .foregroundStyle(TreggaColors.text)
            Button(action: onIncrement) {
                TreggaIcon(.plus, size: 13, color: TreggaColors.text, weight: .bold)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .frame(height: 36)
        .background(TreggaColors.surface, in: Capsule())
        .overlay(Capsule().stroke(TreggaColors.border, lineWidth: 1))
    }
}

/// Botón flotante "Ver carrito · N · $total" que aparece sobre Home/Restaurant.
struct CartFloatingBar: View {
    @Bindable var cart: CartStore
    let onTap: () -> Void

    var body: some View {
        if !cart.isEmpty {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text("\(cart.count)")
                        .font(.system(size: 14, weight: .heavy))
                        .monospacedDigit()
                        .frame(minWidth: 26, minHeight: 26)
                        .background(Color.white.opacity(0.22), in: Circle())
                    Text("Ver carrito")
                        .font(.system(size: 16, weight: .heavy))
                    Spacer()
                    Text(PriceFormat.pesos(cart.subtotal))
                        .font(.system(size: 16, weight: .heavy))
                        .monospacedDigit()
                }
                .foregroundStyle(TreggaColors.onPrimary)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(TreggaColors.primary, in: Capsule())
                .shadow(color: TreggaColors.primary.opacity(0.32), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
