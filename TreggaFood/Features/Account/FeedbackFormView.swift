import SwiftUI
import TreggaCore
import TreggaDesignSystem
import UIKit

/// Formulario para "Reportar un bug" y "Sugerencia o feedback". Inserta en la
/// tabla `reportes` adjuntando versión de app y datos del dispositivo.
struct FeedbackFormView: View {
    let kind: FeedbackKind
    let userId: UUID?
    let repo: FeedbackRepository

    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var sending = false
    @State private var sent = false
    @State private var errorText: String?

    private var title: String {
        kind == .bug ? "Reportar un bug" : "Sugerencia o feedback"
    }
    private var subtitle: String {
        kind == .bug
        ? "Cuéntanos qué falló y, si puedes, cómo reproducirlo."
        : "¿Qué mejorarías? Toda idea suma."
    }
    private var placeholder: String {
        kind == .bug
        ? "Ej. La app se cierra al abrir Pedidos…"
        : "Ej. Me gustaría poder…"
    }
    private var canSend: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
            && userId != nil && !sending
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: title)
                Spacer().frame(height: 8)

                if sent {
                    successState
                } else {
                    formState
                }
            }
            .padding(.bottom, 40)
        }
        .background(TreggaColors.bg)
    }

    private var formState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 20)

            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(TreggaColors.textTer)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                }
                TextEditor(text: $message)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 160)
            }
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)

            Text("Adjuntaremos la versión de la app y el modelo de tu dispositivo para ayudarnos a resolverlo.")
                .font(.system(size: 12))
                .foregroundStyle(TreggaColors.textTer)
                .padding(.horizontal, 20)

            if let errorText {
                Text(errorText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TreggaColors.danger)
                    .padding(.horizontal, 20)
            }

            TreggaButton(sending ? "Enviando…" : "Enviar", kind: .primary) {
                Task { await send() }
            }
            .disabled(!canSend)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var successState: some View {
        VStack(spacing: 14) {
            TreggaIcon(.checkCircle, size: 56, color: TreggaColors.primary)
            Text("¡Gracias!")
                .treggaStyle(.h2)
                .foregroundStyle(TreggaColors.text)
            Text(kind == .bug
                 ? "Recibimos tu reporte. Lo revisaremos pronto."
                 : "Recibimos tu sugerencia. ¡Gracias por ayudarnos a mejorar!")
                .font(.system(size: 14.5))
                .foregroundStyle(TreggaColors.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            TreggaButton("Listo", kind: .primary) { dismiss() }
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func send() async {
        guard let userId else { return }
        sending = true
        errorText = nil
        defer { sending = false }
        do {
            try await repo.submit(
                userId: userId,
                kind: kind,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                appVersion: Self.appVersion,
                buildNumber: Self.buildNumber,
                deviceModel: Self.deviceModel,
                osVersion: Self.osVersion
            )
            withAnimation { sent = true }
        } catch {
            errorText = "No pudimos enviar tu mensaje. Revisa tu conexión e intenta de nuevo."
        }
    }

    // MARK: - Metadata del dispositivo

    private static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }
    private static var buildNumber: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "—"
    }
    private static var osVersion: String {
        "iOS \(UIDevice.current.systemVersion)"
    }
    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            if let value = element.value as? Int8, value != 0 {
                result.append(Character(UnicodeScalar(UInt8(value))))
            }
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }
}
