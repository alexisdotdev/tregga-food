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
}

/// Tab Cuenta: hub + stack de subvistas (F6).
struct CuentaTab: View {
    @Environment(\.appDependencies) private var deps
    let onSignOut: () -> Void

    @State private var viewModel: AccountViewModel?
    @State private var path: [AccountRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let viewModel {
                    AccountHubView(viewModel: viewModel, onSignOut: onSignOut)
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
        }
        .tint(TreggaColors.primary)
        .task {
            guard viewModel == nil, let deps, let uid = deps.authSession.tokens?.userId else { return }
            let vm = AccountViewModel(
                userId: uid,
                profileRepo: deps.profileRepository,
                clienteRepo: deps.clienteRepository,
                direccionRepo: deps.direccionRepository,
                preferenciasRepo: deps.preferenciasRepository,
                accountRepo: deps.accountRepository
            )
            viewModel = vm
            await vm.cargar()
        }
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
        }
    }
}

// MARK: - Hub

struct AccountHubView: View {
    @Bindable var viewModel: AccountViewModel
    let onSignOut: () -> Void
    @State private var showSignOutConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                profileCard
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                grupo(title: "Pedidos y pagos", rows: [
                    .nav(.receipt, "Historial de pedidos", tail: viewModel.cliente.map { "\($0.totalOrders)" }, route: nil),
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

                grupo(title: "Soporte y legal", rows: [
                    .nav(.info, "Acerca de Tregga", tail: nil, route: .about),
                    .nav(.share, "Descargar mis datos", tail: nil, route: .dataDownload),
                ])

                Button { showSignOutConfirm = true } label: {
                    HStack(spacing: 8) {
                        TreggaIcon(.refresh, size: 18, color: TreggaColors.danger)
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
        .confirmationDialog("¿Cerrar sesión?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { onSignOut() }
            Button("Cancelar", role: .cancel) {}
        }
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
