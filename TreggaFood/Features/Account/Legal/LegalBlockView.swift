import SwiftUI
import TreggaDesignSystem

struct LegalBlockView: View {
    let block: LegalBlock

    var body: some View {
        switch block {
        case .paragraph(let text):
            bodyText(text)
                .padding(.horizontal, 20)

        case .heading(let text):
            Text(text)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(TreggaColors.primary)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        bodyText(item)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)

        case .keyValues(let pairs):
            VStack(spacing: 0) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                    DKV(label: pair.0, value: pair.1, isLast: idx == pairs.count - 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TreggaRadius.md))
            .padding(.horizontal, 20)

        case .callout(let text):
            HStack(alignment: .top, spacing: 10) {
                TreggaIcon(.info, size: 15, color: TreggaColors.primary)
                    .padding(.top, 1)
                bodyText(text)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TreggaColors.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: TreggaRadius.md))
            .padding(.horizontal, 20)
        }
    }

    private func bodyText(_ markdown: String) -> some View {
        Text(attributed(markdown))
            .font(.system(size: 14.5, weight: .medium))
            .foregroundStyle(TreggaColors.text)
            .lineSpacing(14.5 * 0.65)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }

    private func attributed(_ markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(markdown)
    }
}
