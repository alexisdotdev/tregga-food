import Foundation

// Bloques renderizables de un documento legal. El texto admite **markdown**
// en línea (negritas) que el renderer interpreta.
enum LegalBlock {
    case paragraph(String)
    case heading(String)
    case bullets([String])
    case keyValues([(String, String)])
    case callout(String)
}

struct LegalDocument: Identifiable {
    let id: String
    let title: String
    let version: String
    let effectiveDate: String
    let summary: String
    let blocks: [LegalBlock]
}

enum FoodLegalContent {
    /// Documentos vigentes, en orden de presentación.
    static var all: [LegalDocument] {
        [
            LegalDocuments.terminosServicio,
            LegalDocuments.politicaPrivacidad,
            LegalDocuments.licenciasOSS,
        ]
    }

    static func document(id: String) -> LegalDocument? {
        all.first { $0.id == id }
    }
}
