import SwiftUI
import TreggaDesignSystem

/// Ofertas y promociones (UI estática, sin backend). Cupones/wallet/puntos
/// están omitidos en v1; "Aprovechar" es cosmético.
struct ScreenOffers: View {
    struct Promo: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let tag: String
        let icon: TreggaIcon.Name
    }

    private let promos: [Promo] = [
        Promo(title: "Envío gratis esta semana", subtitle: "En negocios seleccionados de tu zona.", tag: "Envío $0", icon: .truck),
        Promo(title: "2x1 en postres", subtitle: "Pide tu postre favorito y llévate otro gratis.", tag: "2x1", icon: .gift),
        Promo(title: "$50 de descuento", subtitle: "En tu primer pedido del mes, sin mínimo.", tag: "-$50", icon: .tag),
        Promo(title: "Combo familiar", subtitle: "Precios especiales para pedidos grandes.", tag: "Combo", icon: .bag),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Ofertas")

                banner
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                SectionHeader("Promociones activas").padding(.top, 18)
                VStack(spacing: 12) {
                    ForEach(promos) { promo in
                        promoCard(promo)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 40)
        }
        .background(TreggaColors.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var banner: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("COMBOS Y PROMOS")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(TreggaColors.primaryDark)
                Text("Antojos con descuento")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                Text("Aprovecha las promos de esta semana cerca de ti.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TreggaColors.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image("combo-offer")
                .resizable()
                .scaledToFit()
                .frame(width: 124, height: 124)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22).fill(TreggaColors.primarySoft))
    }

    private func promoCard(_ promo: ScreenOffers.Promo) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(TreggaColors.accentSoft).frame(width: 52, height: 52)
                TreggaIcon(promo.icon, size: 24, color: TreggaColors.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(promo.title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                    Tag(promo.tag, tone: .accent)
                }
                Text(promo.subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(TreggaColors.textSec)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(TreggaColors.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.border, lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Text("Aprovechar")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(TreggaColors.primary)
                .padding(12)
        }
    }
}

#Preview("Ofertas") {
    NavigationStack {
        ScreenOffers()
    }
}
