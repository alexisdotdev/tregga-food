import SwiftUI
import TreggaCore
import TreggaDesignSystem

enum HelpRoute: Hashable {
    case category(String)
    case article(String)
    case contact
}

/// Centro de ayuda (P1.07): búsqueda + categorías + más buscado. Data-driven,
/// sin backend. Contenedor con su propio stack de navegación interno.
struct ScreenHelpCenter: View {
    @State private var path: [HelpRoute] = []
    @State private var query: String = ""

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: HelpRoute.self) { route in
                    switch route {
                    case .category(let id):
                        HelpCategoryListView(categoryId: id, onArticle: { path.append(.article($0)) })
                    case .article(let id):
                        ScreenHelpArticle(articleId: id, onContact: { path.append(.contact) })
                    case .contact:
                        ScreenContactOptions()
                    }
                }
        }
        .tint(TreggaColors.primary)
    }

    private var resultados: [HelpArticle] { HelpData.search(query) }

    private var root: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Centro de ayuda")

                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if !query.isEmpty {
                    resultadosBusqueda
                } else {
                    categorias
                    masBuscado
                }
            }
            .padding(.bottom, 40)
        }
        .background(TreggaColors.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            TreggaIcon(.search, size: 20, color: TreggaColors.primary)
            TextField("Busca tu pregunta o problema…", text: $query)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TreggaColors.text)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    TreggaIcon(.close, size: 16, color: TreggaColors.textSec)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(RoundedRectangle(cornerRadius: 16).fill(TreggaColors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TreggaColors.primary, lineWidth: 1.5))
    }

    @ViewBuilder
    private var resultadosBusqueda: some View {
        if resultados.isEmpty {
            NeutralStateView(
                icon: .search,
                title: "Sin resultados",
                subtitle: "No encontramos artículos para \"\(query)\". Intenta con otras palabras o contáctanos."
            )
            .padding(.top, 50)
        } else {
            VStack(spacing: 0) {
                SectionHeader("Resultados").padding(.top, 16)
                ForEach(resultados) { art in
                    Button { path.append(.article(art.id)) } label: {
                        HelpArticleRow(article: art)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var categorias: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Categorías").padding(.top, 16)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(HelpData.categories) { c in
                    Button { path.append(.category(c.id)) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: 32, height: 32)
                                TreggaIcon(c.icon, size: 18, color: c.iconColor())
                            }
                            Text(c.label)
                                .font(.system(size: 13.5, weight: .heavy))
                                .foregroundStyle(c.iconColor())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(c.iconBg()))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var masBuscado: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Más buscado").padding(.top, 18)
            VStack(spacing: 0) {
                ForEach(HelpData.masBuscado) { art in
                    Button { path.append(.article(art.id)) } label: {
                        HelpArticleRow(article: art)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Lista por categoría

struct HelpCategoryListView: View {
    let categoryId: String
    let onArticle: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: HelpData.categoryLabel(categoryId))
                VStack(spacing: 0) {
                    ForEach(HelpData.articles(in: categoryId)) { art in
                        Button { onArticle(art.id) } label: {
                            HelpArticleRow(article: art)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
        .background(TreggaColors.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Fila de artículo

struct HelpArticleRow: View {
    let article: HelpArticle
    var body: some View {
        HStack(spacing: 10) {
            TreggaIcon(.info, size: 16, color: TreggaColors.textSec)
            Text(article.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TreggaColors.text)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            TreggaIcon(.chevR, size: 16, color: TreggaColors.textSec)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(TreggaColors.divider).frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

#Preview("Centro de ayuda") {
    ScreenHelpCenter()
}
