import SwiftUI
import TreggaCore
import TreggaDesignSystem

// MARK: - Notificaciones (P1.00)

/// Lista de notificaciones reales del usuario con ícono por tipo, punto de
/// no-leída y "marcar todas leídas".
struct ScreenNotifications: View {
    @State private var viewModel: NotificationsViewModel
    @State private var selected: Notificacion?

    /// Posee el VM con `@State` (creado una sola vez por identidad de vista) para
    /// que NO se recree en cada redibujo del padre — eso reseteaba el estado a
    /// `.loading` y dejaba el loader colgado tras la primera carga.
    init(userId: UUID?, repo: NotificacionRepository) {
        _viewModel = State(initialValue: NotificationsViewModel(userId: userId, repo: repo))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(TreggaColors.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selected) { n in
            NotificationDetailView(notificacion: n, onEliminar: { Task { await viewModel.eliminar(n.id) } })
        }
        .task { await viewModel.cargar() }
        .swipeBackToDismiss()
    }

    private var header: some View {
        HStack(spacing: 12) {
            AccountBackButton()
            Text("Notificaciones")
                .treggaStyle(.h3)
                .foregroundStyle(TreggaColors.text)
            Spacer()
            if viewModel.noLeidas > 0 {
                Button { Task { await viewModel.marcarTodasLeidas() } } label: {
                    Text("Marcar leídas")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(TreggaColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        case .empty:
            NeutralStateView(
                icon: .bell,
                title: "Sin notificaciones",
                subtitle: "Aquí verás avisos de tus pedidos, pagos y promociones."
            )
            .padding(.top, 40)
        case .error(let msg):
            NoConnectionView(message: msg) { Task { await viewModel.cargar() } }
                .padding(.top, 40)
        case .loaded(let items):
            List {
                ForEach(items) { n in
                    NotificacionRow(notificacion: n)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onTapGesture {
                            selected = n
                            Task { await viewModel.marcarLeida(n.id) }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.eliminar(n.id) }
                            } label: {
                                Label("Borrar", systemImage: "trash")
                            }
                            .tint(TreggaColors.danger)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.cargar() }
        }
    }
}

// MARK: - Inbox (P1.01)

/// Bandeja de avisos de Tregga. Comparte fuente con notificaciones, filtrando a
/// categorías de "avisos" (sistema/promos/ofertas) y con filtro por categoría.
struct ScreenInbox: View {
    @State private var viewModel: NotificationsViewModel
    @State private var filtro: Filtro = .todas

    enum Filtro: String, CaseIterable {
        case todas = "Todas"
        case promos = "Promos"
        case pedidos = "Pedidos"
    }

    /// VM propio con `@State` (ver nota en `ScreenNotifications`).
    init(userId: UUID?, repo: NotificacionRepository) {
        _viewModel = State(initialValue: NotificationsViewModel(userId: userId, repo: repo))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            filtros
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(TreggaColors.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.cargar() }
        .swipeBackToDismiss()
    }

    private var header: some View {
        HStack(spacing: 12) {
            AccountBackButton()
            Text("Inbox")
                .treggaStyle(.h3)
                .foregroundStyle(TreggaColors.text)
            Spacer()
            if viewModel.noLeidas > 0 {
                Button { Task { await viewModel.marcarTodasLeidas() } } label: {
                    Text("Marcar leídas")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(TreggaColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var filtros: some View {
        HStack(spacing: 8) {
            ForEach(Filtro.allCases, id: \.self) { f in
                Chip(f.rawValue, isActive: filtro == f) { filtro = f }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func aplica(_ n: Notificacion) -> Bool {
        switch filtro {
        case .todas: return true
        case .promos: return n.category == .promos || n.category == .ofertas
        case .pedidos: return n.category == .sistema
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
        case .empty:
            NeutralStateView(
                icon: .message,
                title: "Tu inbox está vacío",
                subtitle: "Aquí llegan los avisos y novedades de Tregga."
            )
            .padding(.top, 40)
        case .error(let msg):
            NoConnectionView(message: msg) { Task { await viewModel.cargar() } }
                .padding(.top, 40)
        case .loaded(let items):
            let filtradas = items.filter(aplica)
            if filtradas.isEmpty {
                NeutralStateView(
                    icon: .message,
                    title: "Nada por aquí",
                    subtitle: "No hay avisos en esta categoría."
                )
                .padding(.top, 40)
            } else {
                List {
                    ForEach(filtradas) { n in
                        NotificacionRow(notificacion: n)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onTapGesture { Task { await viewModel.marcarLeida(n.id) } }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.eliminar(n.id) }
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                                .tint(TreggaColors.danger)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.cargar() }
            }
        }
    }
}

// MARK: - Fila compartida

struct NotificacionRow: View {
    let notificacion: Notificacion

    private var icono: TreggaIcon.Name {
        switch notificacion.category {
        case .ofertas, .promos: return .gift
        case .pagos: return .wallet
        case .sistema: return notificacion.referenceType != nil ? .bag : .info
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(notificacion.read ? TreggaColors.surface : TreggaColors.onPrimary)
                    .frame(width: 40, height: 40)
                TreggaIcon(icono, size: 20,
                           color: notificacion.read ? TreggaColors.text : TreggaColors.primaryDark)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(notificacion.category.remitente)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(notificacion.read ? TreggaColors.textSec : TreggaColors.primaryDark)
                Text(notificacion.title)
                    .font(.system(size: 14.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.text)
                if let body = notificacion.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 12.5))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineLimit(3)
                        .padding(.top, 1)
                }
                Text(notificacion.cuando)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TreggaColors.textTer)
                    .padding(.top, 3)
            }
            Spacer(minLength: 4)
            if !notificacion.read {
                Circle()
                    .fill(TreggaColors.primary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(notificacion.read ? Color.clear : TreggaColors.primarySoft)
        .overlay(alignment: .top) {
            Rectangle().fill(TreggaColors.divider).frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

/// Botón atrás reutilizable (usa dismiss del NavigationStack).
struct AccountBackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button { dismiss() } label: {
            ZStack {
                Circle().fill(TreggaColors.surface).frame(width: 40, height: 40)
                TreggaIcon(.chevL, size: 20, color: TreggaColors.text)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Notificaciones") {
    NavigationStack {
        ScreenNotifications(userId: UUID(), repo: MockNotificacionRepository())
    }
}

#Preview("Inbox") {
    NavigationStack {
        ScreenInbox(userId: UUID(), repo: MockNotificacionRepository())
    }
}
