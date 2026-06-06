import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Destinos de navegación dentro de la sección Cuenta.
enum AccountRoute: Hashable {
    case personalData
    case addresses
    case paymentMethods
    case notifications
    case privacy
    case security
    case language
    case appPreferences
    case about
    case dataDownload
    case accountDeletion
    case inbox
}

/// Tab Cuenta: hub + stack de subvistas (F6).
struct CuentaTab: View {
    @Environment(\.appDependencies) private var deps
    /// Acción real de cierre de sesión (usada por eliminar cuenta).
    let onSignOut: () -> Void
    /// Pide mostrar el diálogo de confirmación — se presenta a nivel del TabView
    /// (por encima del bottom bar), no como overlay dentro del tab.
    var onRequestSignOut: () -> Void = {}

    @State private var viewModel: AccountViewModel?
    @State private var path: [AccountRoute] = []
    @State private var showHelp = false
    @Environment(\.clientShell) private var shell

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let viewModel {
                    AccountHubView(viewModel: viewModel, onRequestSignOut: onRequestSignOut, onHelp: { showHelp = true })
                } else if deps?.authSession.tokens?.userId == nil {
                    noSessionState
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(TreggaColors.bg)
                }
            }
            .navigationDestination(for: AccountRoute.self) { route in
                if let viewModel {
                    destination(route, viewModel: viewModel)
                }
            }
            .onChange(of: path) { _, p in shell?.barHidden = !p.isEmpty }
        }
        .tint(TreggaColors.primary)
        .sheet(isPresented: $showHelp) {
            ScreenHelpCenter()
        }
        // Reactivo al userId: carga en cuanto haya sesión (y recarga si cambia),
        // en vez de rendirse para siempre si aún no estaba lista al montar.
        .task(id: deps?.authSession.tokens?.userId) {
            guard let deps, let uid = deps.authSession.tokens?.userId else { return }
            if viewModel == nil {
                viewModel = AccountViewModel(
                    userId: uid,
                    profileRepo: deps.profileRepository,
                    clienteRepo: deps.clienteRepository,
                    direccionRepo: deps.direccionRepository,
                    preferenciasRepo: deps.preferenciasRepository,
                    accountRepo: deps.accountRepository,
                    storageService: deps.storageService,
                    pedidoRepository: deps.pedidoRepository
                )
            }
            await viewModel?.cargar()
        }
    }

    /// Sin sesión activa (p.ej. previsualizando el shell sin login): estado neutro
    /// en vez de un spinner infinito.
    private var noSessionState: some View {
        VStack(spacing: 12) {
            TreggaIcon(.user, size: 44, color: TreggaColors.textTer)
            Text("Inicia sesión para ver tu cuenta")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
            Text("Aquí verás tu perfil, direcciones y preferencias.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(TreggaColors.textSec)
                .padding(.horizontal, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TreggaColors.bg)
    }

    @ViewBuilder
    private func destination(_ route: AccountRoute, viewModel: AccountViewModel) -> some View {
        switch route {
        case .personalData:
            PersonalDataView(viewModel: viewModel)
        case .addresses:
            AddressesView(viewModel: viewModel)
        case .paymentMethods:
            PaymentMethodsView()
        case .notifications:
            NotificationsConfigView(viewModel: viewModel)
        case .privacy:
            PrivacySettingsView(viewModel: viewModel, onDelete: { path.append(.accountDeletion) })
        case .security:
            SecuritySettingsView()
        case .language:
            LanguageSettingsView()
        case .appPreferences:
            AppPreferencesView(viewModel: viewModel)
        case .about:
            AboutAppView()
        case .dataDownload:
            DataDownloadView(viewModel: viewModel)
        case .accountDeletion:
            AccountDeletionView(viewModel: viewModel, onDeleted: onSignOut)
        case .inbox:
            ScreenInbox(
                viewModel: NotificationsViewModel(
                    userId: deps?.authSession.tokens?.userId,
                    repo: deps?.notificacionRepository ?? MockNotificacionRepository()
                )
            )
        }
    }
}

// MARK: - Hub

struct AccountHubView: View {
    @Bindable var viewModel: AccountViewModel
    let onRequestSignOut: () -> Void
    var onHelp: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                profileCard
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                grupo(title: "Pedidos y pagos", rows: [
                    .nav(.receipt, "Historial de pedidos", tail: "\(viewModel.pedidosCount)", route: nil),
                    .nav(.card, "Métodos de pago", tail: "Efectivo", route: .paymentMethods),
                ])

                grupo(title: "Preferencias", rows: [
                    .nav(.pin, "Direcciones guardadas", tail: "\(viewModel.direcciones.count)", route: .addresses),
                    .nav(.user, "Datos personales", tail: nil, route: .personalData),
                    .nav(.bell, "Notificaciones", tail: nil, route: .notifications),
                    .nav(.grid, "Preferencias de la app", tail: nil, route: .appPreferences),
                    .nav(.info, "Privacidad", tail: nil, route: .privacy),
                    .nav(.user, "Seguridad", tail: nil, route: .security),
                    .nav(.message, "Idioma", tail: "Español (MX)", route: .language),
                ])

                grupo(title: "Mensajes", rows: [
                    .nav(.message, "Inbox", tail: nil, route: .inbox),
                ])

                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("Soporte y legal").padding(.top, 16)
                    AccountCard {
                        Button { onHelp() } label: {
                            AccountNavRow(icon: .info, label: "Ayuda y soporte", sub: "Centro de ayuda y contacto")
                        }
                        .buttonStyle(.plain)
                        RowDivider()
                        NavigationLink(value: AccountRoute.about) {
                            AccountNavRow(icon: .info, label: "Acerca de Tregga")
                        }
                        .buttonStyle(.plain)
                        RowDivider()
                        NavigationLink(value: AccountRoute.dataDownload) {
                            AccountNavRow(icon: .share, label: "Descargar mis datos")
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button { onRequestSignOut() } label: {
                    HStack(spacing: 8) {
                        TreggaIcon(.logout, size: 18, color: TreggaColors.danger)
                        Text("Cerrar sesión")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(TreggaColors.danger)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: TreggaRadius.lg).fill(TreggaColors.dangerBg))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer(minLength: 24)
            }
            .padding(.bottom, 24)
        }
        .background(TreggaColors.bg)
        .refreshable { await viewModel.cargar() }
    }

    private var header: some View {
        HStack {
            Text("Cuenta")
                .treggaStyle(.h1)
                .foregroundStyle(TreggaColors.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(TreggaColors.onPrimary.opacity(0.95)).frame(width: 58, height: 58)
                Text(viewModel.initials)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(TreggaColors.primaryDeep)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.displayName)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                Text(viewModel.contactoLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [TreggaColors.primary, TreggaColors.primaryDark, TreggaColors.primaryDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private enum Row {
        case nav(TreggaIcon.Name, String, tail: String?, route: AccountRoute?)
    }

    @ViewBuilder
    private func grupo(title: String, rows: [Row]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title).padding(.top, 16)
            AccountCard {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    if case let .nav(icon, label, tail, route) = row {
                        if let route {
                            NavigationLink(value: route) {
                                AccountNavRow(icon: icon, label: label, tail: tail)
                            }
                            .buttonStyle(.plain)
                        } else {
                            AccountNavRow(icon: icon, label: label, tail: tail)
                        }
                        if idx < rows.count - 1 { RowDivider() }
                    }
                }
            }
        }
    }
}
