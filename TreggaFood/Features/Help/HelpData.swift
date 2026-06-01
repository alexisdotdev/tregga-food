import Foundation
import TreggaDesignSystem
import SwiftUI

/// Centro de ayuda data-driven: categorías + artículos estáticos en es-MX.
/// Sin backend. Source of truth de `ScreenHelpCenter` / `ScreenHelpArticle`.

struct HelpArticle: Identifiable, Hashable {
    let id: String
    let categoryId: String
    let title: String
    let readMinutes: Int
    /// Párrafos de cuerpo (texto plano).
    let body: [String]
    /// Lista de puntos clave opcional (con viñeta de check).
    let bullets: [String]
}

struct HelpCategory: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: TreggaIcon.Name

    func iconColor() -> Color {
        switch id {
        case "pedido": return TreggaColors.primary
        case "pagos": return TreggaColors.accent
        case "entregas": return TreggaColors.primaryDark
        case "cuenta": return TreggaColors.text
        case "problemas": return TreggaColors.danger
        default: return TreggaColors.primary
        }
    }

    func iconBg() -> Color {
        switch id {
        case "pedido": return TreggaColors.primarySoft
        case "pagos": return TreggaColors.accentSoft
        case "problemas": return TreggaColors.dangerBg
        default: return TreggaColors.surface
        }
    }
}

enum HelpData {
    static let categories: [HelpCategory] = [
        HelpCategory(id: "pedido", label: "Mi pedido", icon: .bag),
        HelpCategory(id: "pagos", label: "Pagos", icon: .wallet),
        HelpCategory(id: "entregas", label: "Entregas", icon: .truck),
        HelpCategory(id: "cuenta", label: "Mi cuenta", icon: .user),
        HelpCategory(id: "problemas", label: "Problemas", icon: .info),
    ]

    static func category(_ id: String) -> HelpCategory? {
        categories.first { $0.id == id }
    }

    static func categoryLabel(_ id: String) -> String {
        category(id)?.label ?? "Ayuda"
    }

    static let articles: [HelpArticle] = [
        // Pedido
        HelpArticle(
            id: "como-pedir", categoryId: "pedido",
            title: "Cómo hacer un pedido", readMinutes: 2,
            body: [
                "Pedir en Tregga es muy sencillo. Desde Inicio elige un negocio cercano, agrega los productos que quieras al carrito y revisa tu orden.",
                "Antes de confirmar, verifica tu dirección de entrega y el método de pago. Al tocar \"Confirmar pedido\" el negocio lo recibe al instante."
            ],
            bullets: []
        ),
        HelpArticle(
            id: "cancelar-pedido", categoryId: "pedido",
            title: "Cancelar un pedido antes de la entrega", readMinutes: 2,
            body: [
                "Puedes cancelar mientras el negocio aún no comienza a preparar tu pedido. Ve a Pedidos, abre el pedido en curso y toca \"Cancelar pedido\".",
                "Si el negocio ya empezó a prepararlo, la cancelación puede no estar disponible o aplicar un cargo. En ese caso contáctanos y lo revisamos."
            ],
            bullets: []
        ),
        HelpArticle(
            id: "cambiar-direccion", categoryId: "pedido",
            title: "Cambiar mi dirección de entrega", readMinutes: 1,
            body: [
                "Puedes cambiar la dirección antes de confirmar el pedido, desde la pantalla de checkout.",
                "Una vez confirmado, la dirección no se puede modificar por seguridad del repartidor. Si te equivocaste, cancela (si es posible) o escríbenos."
            ],
            bullets: []
        ),
        HelpArticle(
            id: "agendar-pedido", categoryId: "pedido",
            title: "Agendar un pedido para más tarde", readMinutes: 1,
            body: [
                "Algunos negocios permiten programar tu pedido. Si está disponible, verás la opción de horario en el checkout.",
                "Te avisaremos cuando el negocio comience a prepararlo a la hora elegida."
            ],
            bullets: []
        ),
        // Pagos
        HelpArticle(
            id: "metodos-pago", categoryId: "pagos",
            title: "Métodos de pago disponibles", readMinutes: 1,
            body: [
                "Por ahora aceptamos efectivo a la entrega y transferencia. Al confirmar tu pedido te indicamos cómo pagar.",
                "El pago con tarjeta dentro de la app llegará próximamente."
            ],
            bullets: []
        ),
        HelpArticle(
            id: "pago-efectivo", categoryId: "pagos",
            title: "Pagar en efectivo a la entrega", readMinutes: 1,
            body: [
                "Al elegir efectivo, pagas directamente al repartidor cuando recibes tu pedido.",
                "Te recomendamos tener el monto lo más exacto posible para agilizar la entrega."
            ],
            bullets: []
        ),
        HelpArticle(
            id: "reembolso", categoryId: "pagos",
            title: "Pedí un reembolso, ¿cuándo llega?", readMinutes: 2,
            body: [
                "Cuando aprobamos un reembolso, el tiempo depende de tu método de pago.",
                "Si pagaste en efectivo, normalmente se acredita como saldo Tregga para tu próximo pedido."
            ],
            bullets: [
                "Efectivo: saldo Tregga inmediato",
                "Transferencia: de 1 a 3 días hábiles"
            ]
        ),
        // Entregas
        HelpArticle(
            id: "seguir-pedido", categoryId: "entregas",
            title: "Seguir mi pedido en tiempo real", readMinutes: 1,
            body: [
                "Desde Pedidos abre el pedido en curso para ver el mapa con la ubicación del repartidor y el tiempo estimado de llegada.",
                "También puedes chatear con tu repartidor desde esa misma pantalla."
            ],
            bullets: []
        ),
        HelpArticle(
            id: "contactar-repartidor", categoryId: "entregas",
            title: "Contactar a mi repartidor", readMinutes: 1,
            body: [
                "Mientras tu pedido está en camino, toca el botón de chat para escribirle al repartidor.",
                "Úsalo para indicar referencias de tu domicilio o coordinar la entrega."
            ],
            bullets: []
        ),
        HelpArticle(
            id: "no-llego", categoryId: "entregas",
            title: "Mi pedido no llegó", readMinutes: 2,
            body: [
                "Si el tiempo estimado pasó y tu pedido no llega, primero revisa el chat y el mapa del repartidor.",
                "Si no logras contacto, repórtalo desde el pedido o escríbenos a soporte para resolverlo de inmediato."
            ],
            bullets: []
        ),
        // Cuenta
        HelpArticle(
            id: "editar-perfil", categoryId: "cuenta",
            title: "Editar mis datos personales", readMinutes: 1,
            body: [
                "Ve a Cuenta → Datos personales para actualizar tu nombre, teléfono y foto.",
                "Tu teléfono se usa para verificar tu identidad y para que el repartidor te contacte."
            ],
            bullets: []
        ),
        HelpArticle(
            id: "eliminar-cuenta", categoryId: "cuenta",
            title: "Eliminar mi cuenta", readMinutes: 1,
            body: [
                "Puedes solicitar la eliminación desde Cuenta → Privacidad → Eliminar cuenta.",
                "Es permanente: se borran tus datos y no podrás recuperar tu historial."
            ],
            bullets: []
        ),
        // Problemas
        HelpArticle(
            id: "comida-fria", categoryId: "problemas",
            title: "Mi comida llegó fría o incorrecta", readMinutes: 2,
            body: [
                "Lamentamos mucho esto. Reportarlo es rápido y siempre hay una solución.",
                "Toma una foto de lo que recibiste, ve a Pedidos → el pedido afectado → Reportar problema, elige el motivo y sube la foto. Revisamos en menos de 1 hora."
            ],
            bullets: [
                "Reembolso al método de pago",
                "Saldo Tregga para tu próximo pedido",
                "Reenvío de los productos faltantes"
            ]
        ),
        HelpArticle(
            id: "app-falla", categoryId: "problemas",
            title: "La app no funciona o se cierra", readMinutes: 1,
            body: [
                "Intenta cerrar y volver a abrir la app, y verifica que tengas la última versión instalada.",
                "Si el problema continúa, escríbenos a soporte con tu modelo de teléfono y qué estabas haciendo."
            ],
            bullets: []
        ),
    ]

    static func articles(in categoryId: String) -> [HelpArticle] {
        articles.filter { $0.categoryId == categoryId }
    }

    /// Las más buscadas (curado).
    static let masBuscado: [HelpArticle] = [
        articles.first { $0.id == "cancelar-pedido" },
        articles.first { $0.id == "comida-fria" },
        articles.first { $0.id == "reembolso" },
        articles.first { $0.id == "cambiar-direccion" },
    ].compactMap { $0 }

    static func search(_ query: String) -> [HelpArticle] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return articles.filter {
            $0.title.lowercased().contains(q)
                || $0.body.contains { $0.lowercased().contains(q) }
                || HelpData.categoryLabel($0.categoryId).lowercased().contains(q)
        }
    }
}
