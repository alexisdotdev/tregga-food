import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Datos personales: editar nombre/apellidos/correo/teléfono/fecha nac, con
/// guardado real sobre `profiles`. Incluye entrada a "Eliminar mi cuenta".
struct PersonalDataView: View {
    @Bindable var viewModel: AccountViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var apellidoPaterno = ""
    @State private var apellidoMaterno = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var fechaNacimiento = Date()
    @State private var tieneFecha = false
    @State private var guardando = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Datos personales")

                avatar
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)

                VStack(spacing: 12) {
                    campo("Nombre(s)", text: $fullName)
                    campo("Apellido paterno", text: $apellidoPaterno)
                    campo("Apellido materno", text: $apellidoMaterno)
                    campo("Correo electrónico", text: $email, keyboard: .emailAddress)
                    campo("Teléfono", text: $phone, keyboard: .phonePad)
                    fechaField
                }
                .padding(.horizontal, 16)

                TreggaButton(guardando ? "Guardando…" : "Guardar cambios") {
                    Task { await guardar() }
                }
                .disabled(guardando)
                .padding(.horizontal, 16)
                .padding(.top, 18)

                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Text("Eliminar mi cuenta")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TreggaColors.danger)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Spacer(minLength: 24)
            }
        }
        .background(TreggaColors.bg)
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: hidratar)
        .confirmationDialog("¿Eliminar tu cuenta?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            NavigationLink("Continuar", value: AccountRoute.accountDeletion)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción es irreversible.")
        }
    }

    private var avatar: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(TreggaColors.primarySoft).frame(width: 96, height: 96)
                Text(viewModel.initials)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(TreggaColors.primaryDeep)
            }
            Text(viewModel.displayName)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
        }
    }

    private func campo(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(TreggaColors.textSec)
            TextField("", text: text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(TreggaColors.text)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(TreggaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var fechaField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FECHA DE NACIMIENTO")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(TreggaColors.textSec)
            HStack {
                if tieneFecha {
                    DatePicker("", selection: $fechaNacimiento, displayedComponents: .date)
                        .labelsHidden()
                        .tint(TreggaColors.primary)
                } else {
                    Button("Agregar fecha") { tieneFecha = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TreggaColors.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func hidratar() {
        guard let p = viewModel.perfil else {
            phone = viewModel.cliente?.phone ?? ""
            fullName = viewModel.cliente?.fullName ?? ""
            return
        }
        fullName = p.fullName
        apellidoPaterno = p.apellidoPaterno
        apellidoMaterno = p.apellidoMaterno
        email = p.email ?? ""
        phone = p.phone ?? viewModel.cliente?.phone ?? ""
        if let f = p.fechaNacimiento {
            fechaNacimiento = f
            tieneFecha = true
        }
    }

    private func guardar() async {
        guardando = true
        _ = await viewModel.guardarPerfil(
            fullName: fullName,
            apellidoPaterno: apellidoPaterno,
            apellidoMaterno: apellidoMaterno,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            fechaNacimiento: tieneFecha ? fechaNacimiento : nil
        )
        guardando = false
        dismiss()
    }
}
