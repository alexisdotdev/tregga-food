import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Eliminar cuenta: warning irreversible + confirmación. Al confirmar llama el
/// RPC `delete_my_account` y, en éxito, cierra sesión (vuelve a unauthenticated).
struct AccountDeletionView: View {
    @Bindable var viewModel: AccountViewModel
    /// Tras borrar, ContentView vuelve la app a `.unauthenticated`.
    let onDeleted: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var entiendo = false
    @State private var procesando = false
    @State private var showConfirm = false
    @State private var errorMsg: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Eliminar mi cuenta")

                warning
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                SectionHeader("Qué pasa cuando eliminas").padding(.top, 16)
                VStack(spacing: 0) {
                    ForEach(consecuencias, id: \.self) { txt in
                        consecuencia(txt)
                    }
                }
                .padding(.horizontal, 16)

                Button {
                    entiendo.toggle()
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(entiendo ? TreggaColors.danger : TreggaColors.surface)
                                .frame(width: 22, height: 22)
                            if entiendo {
                                TreggaIcon(.check, size: 12, color: .white)
                            } else {
                                RoundedRectangle(cornerRadius: 6).stroke(TreggaColors.border, lineWidth: 2).frame(width: 22, height: 22)
                            }
                        }
                        Text("Entiendo que no se puede deshacer")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TreggaColors.text)
                        Spacer()
                    }
                    .padding(14)
                    .background(TreggaColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if let errorMsg {
                    Text(errorMsg)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TreggaColors.danger)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }

                eliminarButton
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                Button("Cancelar y volver") { dismiss() }
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(TreggaColors.text)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("¿Eliminar tu cuenta de forma permanente?",
                            isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Eliminar definitivamente", role: .destructive) { Task { await eliminar() } }
            Button("Cancelar", role: .cancel) {}
        }
        .swipeBackToDismiss()
    }

    private let consecuencias = [
        "Tu historial de pedidos se borra",
        "Pierdes promociones y cupones activos",
        "Tus direcciones se eliminan",
        "Pedidos en curso se cancelan automáticamente",
    ]

    private var warning: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(TreggaColors.danger).frame(width: 56, height: 56)
                TreggaIcon(.trash, size: 28, color: .white)
            }
            Text("Esto es irreversible")
                .treggaStyle(.h2)
                .foregroundStyle(TreggaColors.danger)
            Text("Al eliminar tu cuenta perderás acceso inmediato. No la podemos recuperar después.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TreggaColors.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(TreggaColors.dangerBg)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(TreggaColors.danger, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func consecuencia(_ txt: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(TreggaColors.dangerBg).frame(width: 22, height: 22)
                TreggaIcon(.info, size: 12, color: TreggaColors.danger)
            }
            Text(txt)
                .font(.system(size: 13.5))
                .foregroundStyle(TreggaColors.text)
            Spacer()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { RowDivider() }
    }

    private var eliminarButton: some View {
        Button {
            showConfirm = true
        } label: {
            Text(procesando ? "Eliminando…" : "Eliminar mi cuenta")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: TreggaRadius.lg).fill(TreggaColors.danger))
                .opacity(entiendo && !procesando ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!entiendo || procesando)
    }

    private func eliminar() async {
        procesando = true
        errorMsg = nil
        let ok = await viewModel.eliminarCuenta()
        procesando = false
        if ok {
            onDeleted()
        } else {
            errorMsg = "No pudimos eliminar tu cuenta. Intenta más tarde."
        }
    }
}
