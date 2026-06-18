import SwiftUI
import PhotosUI
import TreggaCore
import TreggaDesignSystem

/// Datos personales: editar nombre/apellidos/correo/teléfono/fecha nac, con
/// guardado real sobre `profiles`. Incluye entrada a "Eliminar mi cuenta".
struct PersonalDataView: View {
    @Bindable var viewModel: AccountViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Campo: Hashable { case nombre, apellidoP, apellidoM, correo, telefono }
    @FocusState private var foco: Campo?

    @State private var fullName = ""
    @State private var apellidoPaterno = ""
    @State private var apellidoMaterno = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var fechaNacimiento = Date()
    @State private var tieneFecha = false
    @State private var guardando = false
    @State private var showDeleteConfirm = false

    @State private var pickerItem: PhotosPickerItem?
    @State private var cropImage: AvatarCropImage?
    @State private var subiendo = false
    @State private var showSourceDialog = false
    @State private var showLibrary = false
    @State private var showCamera = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountHeader(title: "Datos personales")

                avatar
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)

                VStack(spacing: 12) {
                    campo("Nombre(s)", text: $fullName, foco: .nombre)
                    campo("Apellido paterno", text: $apellidoPaterno, foco: .apellidoP)
                    campo("Apellido materno", text: $apellidoMaterno, foco: .apellidoM)
                    campo("Correo electrónico", text: $email, mode: .correo, foco: .correo)
                    campo("Teléfono", text: $phone, mode: .telefono, foco: .telefono)
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
        .keyboardNavToolbar($foco, order: [.nombre, .apellidoP, .apellidoM, .correo, .telefono])
        .onAppear(perform: hidratar)
        .confirmationDialog("¿Eliminar tu cuenta?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            NavigationLink("Continuar", value: AccountRoute.accountDeletion)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción es irreversible.")
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePicked(newItem) }
        }
        .fullScreenCover(item: $cropImage) { item in
            AvatarCropView(
                image: item.image,
                onCancel: { cropImage = nil },
                onDone: { cropped in
                    cropImage = nil
                    Task {
                        subiendo = true
                        _ = await viewModel.actualizarAvatar(cropped)
                        subiendo = false
                    }
                }
            )
        }
        .confirmationDialog("Foto de perfil", isPresented: $showSourceDialog, titleVisibility: .visible) {
            if CameraPicker.disponible {
                Button("Tomar selfie") { showCamera = true }
            }
            Button("Elegir de la galería") { showLibrary = true }
            Button("Cancelar", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in cropImage = AvatarCropImage(image: img) }
                .ignoresSafeArea()
        }
        .swipeBackToDismiss()
    }

    private var avatar: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                avatarImage
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())

                Button { showSourceDialog = true } label: {
                    ZStack {
                        Circle().fill(TreggaColors.primary).frame(width: 30, height: 30)
                        if subiendo {
                            ProgressView().tint(TreggaColors.onPrimary)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(TreggaColors.onPrimary)
                        }
                    }
                    .overlay(Circle().stroke(TreggaColors.bg, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(subiendo)
            }
            Text(viewModel.displayName)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let urlString = viewModel.perfil?.avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(TreggaColors.primarySoft)
            Text(viewModel.initials)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(TreggaColors.primaryDeep)
        }
    }

    private func handlePicked(_ item: PhotosPickerItem) async {
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: raw) else { return }
        cropImage = AvatarCropImage(image: uiImage)
    }

    /// Modo de campo: aplica las mismas reglas que Tregga Delivery —
    /// nombres capitalizados, teléfono con máscara, correo sin capitalizar.
    enum CampoMode { case nombre, correo, telefono, plano }

    private func campo(
        _ label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        mode: CampoMode = .nombre,
        foco campo: Campo
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(TreggaColors.textSec)
            TextField("", text: text)
                .focused($foco, equals: campo)
                .keyboardType(mode == .telefono ? .phonePad : (mode == .correo ? .emailAddress : keyboard))
                .textInputAutocapitalization(mode == .nombre ? .words : .never)
                .autocorrectionDisabled()
                .onChange(of: text.wrappedValue) { _, new in
                    switch mode {
                    case .nombre:
                        let c = NameFormatter.capitalizedWords(new)
                        if c != new { text.wrappedValue = c }
                    case .telefono:
                        let f = PhoneFormatter.format(new)
                        if f != new { text.wrappedValue = f }
                    case .correo, .plano:
                        break
                    }
                }
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
            phone = PhoneFormatter.displayMX(viewModel.cliente?.phone ?? "")
            fullName = viewModel.cliente?.fullName ?? ""
            return
        }
        fullName = p.fullName
        apellidoPaterno = p.apellidoPaterno
        apellidoMaterno = p.apellidoMaterno
        email = p.email ?? ""
        phone = PhoneFormatter.displayMX(p.phone ?? viewModel.cliente?.phone ?? "")
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
