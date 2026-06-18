import SwiftUI
import TreggaDesignSystem

/// Ofertas y promociones del cliente. Datos reales desde `promociones` (RLS filtra
/// activas y vigentes). "Aprovechar" es cosmético por ahora.
struct ScreenOffers: View {
    @Environment(\.appDependencies) private var deps
    @State private var promos: [Promocion] = []
    @State private var loading = true

    private var repo: OfertaRepository { deps?.ofertaRepository ?? MockOfertaRepository() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Ofertas")

                banner
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                SectionHeader("Promociones activas").padding(.top, 18)
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                } else if promos.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(promos) { promo in
                            promoCard(promo)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 40)
        }
        .background(TreggaColors.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            promos = (try? await repo.fetchActivas()) ?? []
            loading = false
        }
        .swipeBackToDismiss()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            TreggaIcon(.gift, size: 36, color: TreggaColors.textTer)
            Text("No hay promociones activas")
                .font(.system(size: 14.5, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
            Text("Vuelve pronto: los negocios irán publicando sus ofertas.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func icono(_ tipo: String) -> TreggaIcon.Name {
        switch tipo {
        case "envio_gratis": return .truck
        case "descuento":    return .tag
        case "dos_por_uno":  return .gift
        case "combo":        return .bag
        default:             return .gift
        }
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

    private func promoCard(_ promo: Promocion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(TreggaColors.accentSoft).frame(width: 52, height: 52)
                    TreggaIcon(icono(promo.tipo), size: 24, color: TreggaColors.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(promo.titulo)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(TreggaColors.text)
                            .lineLimit(1)
                        if let tag = promo.tag, !tag.isEmpty {
                            Tag(tag, tone: .accent)
                        }
                    }
                    if let descripcion = promo.descripcion, !descripcion.isEmpty {
                        Text(descripcion)
                            .font(.system(size: 12.5))
                            .foregroundStyle(TreggaColors.textSec)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
            }
            HStack {
                Spacer()
                Text("Aprovechar")
                    .font(.system(size: 12.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.primary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(TreggaColors.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.border, lineWidth: 1))
    }
}

#Preview("Ofertas") {
    NavigationStack {
        ScreenOffers()
    }
}
