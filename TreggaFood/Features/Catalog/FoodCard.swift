import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Tarjeta de negocio para el Home (imagen + rating + nombre + tipo + tiempo).
struct FoodCard: View {
    let negocio: Negocio
    var large: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                CoverImage(url: negocio.coverImageURL ?? negocio.logoURL, seed: negocio.name)
                    .frame(height: large ? 200 : 130)
                    .frame(maxWidth: .infinity)
                    .clipped()

                HStack(spacing: 4) {
                    TreggaIcon(.star, size: 12, color: TreggaColors.star)
                    Text(negocio.ratingLabel)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.05))
                    if negocio.totalOrders > 0 {
                        Text("(\(ordersLabel))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TreggaColors.textSec)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: TreggaRadius.sm))
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: TreggaRadius.lg))

            VStack(alignment: .leading, spacing: 3) {
                Text(negocio.name)
                    .font(.system(size: large ? 17 : 15, weight: .heavy))
                    .tracking(-0.2)
                    .foregroundStyle(TreggaColors.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let tipo = negocio.tipo, !tipo.isEmpty {
                        Text(tipo).lineLimit(1)
                        Text("·").foregroundStyle(TreggaColors.textTer)
                    }
                    Text(negocio.tiempoLabel)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(TreggaColors.textSec)
            }
            .padding(.top, large ? 12 : 10)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ordersLabel: String {
        negocio.totalOrders >= 1000
            ? "\(negocio.totalOrders / 1000)k+"
            : "\(negocio.totalOrders)"
    }
}

/// Imagen de portada con placeholder de marca cuando no hay URL o falla la carga.
struct CoverImage: View {
    let url: String?
    var seed: String = ""

    var body: some View {
        Group {
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [TreggaColors.primarySoft, TreggaColors.surface2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            TreggaIcon(.bag, size: 34, color: TreggaColors.primary.opacity(0.45))
        )
    }
}
