import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Configuración de notificaciones: master + categorías de negocio
/// (Pedidos/Pagos, Promos/Ofertas, Sistema) sobre `preferencias_usuario`.
struct NotificationsConfigView: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Notificaciones")

                masterCard
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                SectionHeader("Pedidos y pagos").padding(.top, 12)
                VStack(spacing: 0) {
                    AccountToggleRow(icon: .bag, label: "Updates de mi pedido",
                                     sub: "Cuando el negocio acepta, prepara y manda tu pedido.",
                                     isOn: bind(\.notifPagos))
                }
                .padding(.horizontal, 16)

                SectionHeader("Ofertas y promociones").padding(.top, 8)
                VStack(spacing: 0) {
                    AccountToggleRow(icon: .gift, label: "Promos personalizadas",
                                     sub: "Descuentos en negocios que te interesan.",
                                     isOn: bind(\.notifPromos))
                    RowDivider()
                    AccountToggleRow(icon: .tag, label: "Ofertas cerca de mí",
                                     sub: "Cuando haya promos en negocios nuevos cerca.",
                                     isOn: bind(\.notifOfertas))
                }
                .padding(.horizontal, 16)

                SectionHeader("Sistema").padding(.top, 8)
                VStack(spacing: 0) {
                    AccountToggleRow(icon: .info, label: "Novedades de la app",
                                     sub: "Nuevas funciones y avisos importantes.",
                                     isOn: bind(\.notifSistema))
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .swipeBackToDismiss()
    }

    private var masterActiva: Bool {
        viewModel.prefs?.notificacionesActivas ?? true
    }

    private var masterCard: some View {
        HStack(spacing: 12) {
            TreggaIcon(.bell, size: 22, color: TreggaColors.primaryDark)
            VStack(alignment: .leading, spacing: 1) {
                Text(masterActiva ? "Notificaciones activas" : "Notificaciones en pausa")
                    .font(.system(size: 14.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.primaryDeep)
                Text("Te enviamos solo lo importante.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TreggaColors.primaryDark)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { masterActiva },
                set: { nuevo in
                    Task {
                        await viewModel.actualizarPrefs { p in
                            p.notifOfertas = nuevo
                            p.notifPagos = nuevo
                            p.notifPromos = nuevo
                            p.notifSistema = nuevo
                        }
                    }
                }
            ))
            .labelsHidden()
            .tint(TreggaColors.primary)
        }
        .padding(14)
        .background(TreggaColors.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func bind(_ key: WritableKeyPath<PreferenciasUsuario, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.prefs?[keyPath: key] ?? false },
            set: { nuevo in
                Task { await viewModel.actualizarPrefs { $0[keyPath: key] = nuevo } }
            }
        )
    }
}
