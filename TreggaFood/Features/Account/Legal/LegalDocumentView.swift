import SwiftUI
import TreggaDesignSystem

struct LegalDocumentView: View {
    let document: LegalDocument
    var onBack: (() -> Void)? = nil

    private var eyebrow: String {
        "VERSIÓN \(document.version) · \(document.effectiveDate.uppercased())"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DriverHeader(title: "", onBack: onBack)

                Spacer().frame(height: 8)

                VStack(alignment: .leading, spacing: 0) {
                    Text(eyebrow)
                        .font(.system(size: 11.5, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(TreggaColors.primary)

                    Spacer().frame(height: 8)

                    Text(document.title)
                        .treggaStyle(.h2)
                        .foregroundStyle(TreggaColors.text)
                        .lineSpacing(24 * 0.2)

                    if !document.summary.isEmpty {
                        Spacer().frame(height: 8)
                        Text(document.summary)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TreggaColors.textSec)
                            .lineSpacing(14 * 0.5)
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 20)

                ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                    LegalBlockView(block: block)
                    Spacer().frame(height: 14)
                }

                Spacer().frame(height: 8)

                disclaimerCard

                Spacer().frame(height: 90)
            }
        }
        .background(TreggaColors.bg)
    }

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            TreggaIcon(.info, size: 14, color: TreggaColors.textSec)
            Text("Versión \(document.version) · vigente desde \(document.effectiveDate). Te avisamos por correo cuando actualicemos este documento.")
                .font(.system(size: 12))
                .foregroundStyle(TreggaColors.textSec)
                .lineSpacing(12 * 0.45)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TreggaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }
}
