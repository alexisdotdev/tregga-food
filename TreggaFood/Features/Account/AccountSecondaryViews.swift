import SwiftUI
import TreggaCore
import TreggaDesignSystem

// MARK: - Métodos de pago

/// Métodos de pago v1: efectivo + transferencia disponibles; tarjeta "próximamente".
struct PaymentMethodsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Métodos de pago")

                SectionHeader("Disponibles").padding(.top, 8)
                AccountCard {
                    metodo(.cash, "Efectivo a la entrega", "Paga al recibir tu pedido.")
                    RowDivider()
                    metodo(.wallet, "Transferencia", "Te compartimos los datos al confirmar.")
                }

                SectionHeader("Próximamente").padding(.top, 16)
                AccountCard {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(TreggaColors.surface).frame(width: 34, height: 34)
                            TreggaIcon(.card, size: 18, color: TreggaColors.textTer)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tarjeta de crédito/débito")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(TreggaColors.textSec)
                            Text("Próximamente podrás guardar tarjetas.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(TreggaColors.textTer)
                        }
                        Spacer()
                        Tag("Pronto", tone: .default)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                }

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
    }

    private func metodo(_ icon: TreggaIcon.Name, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(TreggaColors.surface).frame(width: 34, height: 34)
                TreggaIcon(icon, size: 18, color: TreggaColors.text)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(TreggaColors.text)
                Text(sub).font(.system(size: 12.5)).foregroundStyle(TreggaColors.textSec)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

// MARK: - Seguridad (cambiar contraseña real)

struct SecuritySettingsView: View {
    @Environment(\.appDependencies) private var deps
    @State private var showChangePassword = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Seguridad")

                SectionHeader("Inicio de sesión").padding(.top, 8)
                AccountCard {
                    Button { showChangePassword = true } label: {
                        AccountNavRow(icon: .info, label: "Cambiar contraseña",
                                      sub: "Si usas correo y contraseña")
                    }
                    .buttonStyle(.plain)
                    RowDivider()
                    AccountNavRow(icon: .user, label: "Face ID / Touch ID",
                                  sub: "Para iniciar y autorizar pagos", tail: "Pronto", showChevron: false)
                }

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet(authService: deps?.authService ?? MockAuthService())
        }
    }
}

private struct ChangePasswordSheet: View {
    let authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var actual = ""
    @State private var nueva = ""
    @State private var confirma = ""
    @State private var procesando = false
    @State private var mensaje: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    campo("Contraseña actual", text: $actual)
                    campo("Nueva contraseña", text: $nueva)
                    campo("Confirmar nueva", text: $confirma)
                    if let mensaje {
                        Text(mensaje)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TreggaColors.danger)
                    }
                    TreggaButton(procesando ? "Guardando…" : "Cambiar contraseña") {
                        Task { await cambiar() }
                    }
                    .disabled(procesando || !valido)
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(TreggaColors.bg)
            .navigationTitle("Cambiar contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
        }
    }

    private var valido: Bool {
        nueva.count >= 8 && nueva == confirma && !actual.isEmpty
    }

    private func campo(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(TreggaColors.textSec)
            SecureField("", text: text)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(TreggaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func cambiar() async {
        procesando = true
        mensaje = nil
        do {
            try await authService.updatePassword(currentPassword: actual, newPassword: nueva)
            procesando = false
            dismiss()
        } catch {
            procesando = false
            mensaje = "No pudimos cambiar la contraseña. Verifica tus datos."
        }
    }
}

// MARK: - Idioma

struct LanguageSettingsView: View {
    private let langs: [(code: String, label: String, sub: String, on: Bool)] = [
        ("es-MX", "Español (México)", "Idioma de la app", true),
        ("en-US", "English (United States)", "", false),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Idioma")

                VStack(spacing: 0) {
                    ForEach(langs, id: \.code) { l in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(l.label).font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(l.on ? TreggaColors.text : TreggaColors.textSec)
                                if !l.sub.isEmpty {
                                    Text(l.sub).font(.system(size: 12)).foregroundStyle(TreggaColors.textSec)
                                }
                            }
                            Spacer()
                            if l.on { TreggaIcon(.check, size: 20, color: TreggaColors.primary) }
                            else { Tag("Pronto", tone: .default) }
                        }
                        .padding(.vertical, 14)
                        if l.code != langs.last?.code { RowDivider() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                HStack(spacing: 10) {
                    TreggaIcon(.info, size: 16, color: TreggaColors.textSec)
                    Text("Los precios siempre van en MXN sin importar el idioma.")
                        .font(.system(size: 12))
                        .foregroundStyle(TreggaColors.textSec)
                }
                .padding(14)
                .background(TreggaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 18)

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Acerca de (sin RFC ni dirección fija)

struct AboutAppView: View {
    @State private var selectedDoc: LegalDocument? = nil

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Versión \(v) (build \(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Acerca de Tregga")

                VStack(spacing: 8) {
                    Image("logo-tregga")
                        .resizable().scaledToFit().frame(height: 48)
                    Text("COMIDA A DOMICILIO")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(TreggaColors.textSec)
                    Text(version)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(TreggaColors.text)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)

                SectionHeader("Información").padding(.top, 4)
                AccountCard {
                    legalRow("Términos de servicio", id: "terminos-servicio")
                    RowDivider()
                    legalRow("Política de privacidad", id: "politica-privacidad")
                    RowDivider()
                    legalRow("Licencias de software libre", id: "licencias-oss")
                }

                Text("Hecho con 🍊 en México")
                    .font(.system(size: 12))
                    .foregroundStyle(TreggaColors.textTer)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .sheet(item: $selectedDoc) { doc in
            LegalDocumentView(document: doc, onBack: { selectedDoc = nil })
        }
    }

    @ViewBuilder
    private func legalRow(_ label: String, id: String) -> some View {
        Button { selectedDoc = FoodLegalContent.document(id: id) } label: {
            AccountNavRow(icon: .info, label: label, showChevron: true)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Descargar mis datos

struct DataDownloadView: View {
    @Bindable var viewModel: AccountViewModel
    @State private var solicitado = false
    @State private var procesando = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Descargar mis datos")

                Text("Te enviaremos un ZIP con todos tus datos a tu correo. Puede tardar de 1 a 3 días.")
                    .font(.system(size: 15))
                    .foregroundStyle(TreggaColors.textSec)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                SectionHeader("Qué incluye").padding(.top, 16)
                VStack(spacing: 0) {
                    incluye("Datos personales", "Nombre, contacto, foto")
                    incluye("Historial de pedidos", "Tus pedidos completados")
                    incluye("Direcciones guardadas", "Todas tus direcciones")
                }
                .padding(.horizontal, 16)

                if solicitado {
                    HStack(spacing: 10) {
                        TreggaIcon(.check, size: 18, color: TreggaColors.primaryDark)
                        Text("Solicitud enviada. Revisa tu correo en los próximos días.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TreggaColors.primaryDeep)
                    }
                    .padding(14)
                    .background(TreggaColors.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                } else {
                    TreggaButton(procesando ? "Enviando…" : "Solicitar descarga") {
                        Task {
                            procesando = true
                            await viewModel.solicitarDescargaDatos()
                            procesando = false
                            solicitado = true
                        }
                    }
                    .disabled(procesando)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                }

                if let email = viewModel.perfil?.email {
                    Text("Llegará a \(email)")
                        .font(.system(size: 12))
                        .foregroundStyle(TreggaColors.textTer)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
    }

    private func incluye(_ title: String, _ sub: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(TreggaColors.primary).frame(width: 22, height: 22)
                TreggaIcon(.check, size: 12, color: .white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(TreggaColors.text)
                Text(sub).font(.system(size: 12)).foregroundStyle(TreggaColors.textSec)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { RowDivider() }
    }
}
