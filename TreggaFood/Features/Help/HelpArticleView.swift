import SwiftUI
import TreggaDesignSystem

/// Detalle de artículo (P1.08): cuerpo + "¿Te ayudó?" + CTA a contacto.
struct ScreenHelpArticle: View {
    let articleId: String
    let onContact: () -> Void

    @State private var feedback: Bool? = nil

    private var article: HelpArticle? {
        HelpData.articles.first { $0.id == articleId }
    }

    var body: some View {
        ScrollView {
            if let article {
                VStack(alignment: .leading, spacing: 0) {
                    AccountHeader(title: "")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(HelpData.categoryLabel(article.categoryId).uppercased()) · \(article.readMinutes) MIN")
                            .font(.system(size: 11.5, weight: .heavy))
                            .tracking(0.4)
                            .foregroundStyle(TreggaColors.primary)
                        Text(article.title)
                            .treggaStyle(.h2)
                            .foregroundStyle(TreggaColors.text)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(article.body.enumerated()), id: \.offset) { _, p in
                            Text(p)
                                .font(.system(size: 14.5))
                                .foregroundStyle(TreggaColors.text)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    if !article.bullets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(article.bullets, id: \.self) { b in
                                HStack(alignment: .top, spacing: 10) {
                                    TreggaIcon(.check, size: 14, color: TreggaColors.primary)
                                        .padding(.top, 2)
                                    Text(b)
                                        .font(.system(size: 14))
                                        .foregroundStyle(TreggaColors.text)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                    }

                    feedbackCard
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    VStack(spacing: 12) {
                        TreggaButton("Hablar con soporte", iconRight: nil) { onContact() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .padding(.bottom, 40)
            } else {
                NeutralStateView(icon: .info, title: "Artículo no disponible", subtitle: "No encontramos este artículo.")
                    .padding(.top, 80)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .swipeBackToDismiss()
    }

    private var feedbackCard: some View {
        VStack(spacing: 12) {
            if feedback == nil {
                Text("¿Te ayudó este artículo?")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                HStack(spacing: 10) {
                    feedbackPill("👍 Sí", value: true)
                    feedbackPill("👎 No", value: false)
                }
            } else {
                Text(feedback == true ? "¡Gracias por tu opinión!" : "Lamentamos no haber ayudado. Puedes contactarnos.")
                    .font(.system(size: 13, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TreggaColors.text)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(TreggaColors.surface))
    }

    private func feedbackPill(_ label: String, value: Bool) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { feedback = value } } label: {
            Text(label)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(TreggaColors.text)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(TreggaColors.bg))
                .overlay(Capsule().stroke(TreggaColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Artículo") {
    NavigationStack {
        ScreenHelpArticle(articleId: "comida-fria", onContact: {})
    }
}
