import SwiftUI
import TreggaDesignSystem

/// Opciones de contacto con soporte: Chat, WhatsApp, Llamada, Email.
/// WhatsApp/Llamada/Email abren la app correspondiente vía URL.
struct ScreenContactOptions: View {
    @Environment(\.openURL) private var openURL

    private let whatsapp = "521234567890"
    private let phone = "8000000000"
    private let email = "soporte@tregga.app"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Hablar con soporte")

                Text("Elige cómo prefieres contactarnos. Respondemos lo más rápido posible.")
                    .font(.system(size: 14))
                    .foregroundStyle(TreggaColors.textSec)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                SectionHeader("Canales").padding(.top, 16)
                AccountCard {
                    opcion(.message, "Chat con soporte", "Tiempo de respuesta ~5 min") {
                        // Chat in-app: placeholder hasta tener canal dedicado.
                    }
                    RowDivider()
                    opcion(.phone, "WhatsApp", "Escríbenos por WhatsApp") {
                        if let url = URL(string: "https://wa.me/\(whatsapp)") { openURL(url) }
                    }
                    RowDivider()
                    opcion(.phone, "Llamada", "Lun a Dom, 8am - 10pm") {
                        if let url = URL(string: "tel://\(phone)") { openURL(url) }
                    }
                    RowDivider()
                    opcion(.info, "Correo electrónico", email) {
                        if let url = URL(string: "mailto:\(email)") { openURL(url) }
                    }
                }
                .padding(.horizontal, 0)
            }
            .padding(.bottom, 40)
        }
        .background(TreggaColors.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .swipeBackToDismiss()
    }

    private func opcion(_ icon: TreggaIcon.Name, _ label: String, _ sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AccountNavRow(icon: icon, label: label, sub: sub)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Contacto") {
    NavigationStack {
        ScreenContactOptions()
    }
}
