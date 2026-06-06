import SwiftUI
import TreggaCore
import PhotosUI
import TreggaDesignSystem

// MARK: - Step 0: Intro

public struct SignupIntroView: View {
    public let onBack: () -> Void
    public let onContinue: () -> Void

    public init(onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.onBack = onBack
        self.onContinue = onContinue
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                backButton
                Spacer().frame(height: 10)
                logoCircle
                Text("¡Bienvenido a Tregga!")
                    .font(.system(size: 30, weight: .heavy))
                    .padding(.top, 22)
                    .padding(.horizontal, 24)
                Text("Vamos a crear tu cuenta para que pidas tu comida favorita en minutos.")
                    .font(.system(size: 15))
                    .foregroundStyle(TreggaColors.textSec)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                Spacer().frame(height: 24)

                sectionLabel("Esto es lo que sigue")
                pasos
                tipBox
            }
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .background(TreggaColors.bg)
    }

    private var backButton: some View {
        Button(action: onBack) {
            TreggaIcon(.chevL, size: 18, color: TreggaColors.text)
                .frame(width: 36, height: 36)
                .background(TreggaColors.surface, in: Circle())
                .overlay(Circle().stroke(TreggaColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.leading, 14)
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var logoCircle: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(TreggaColors.primarySoft)
                .frame(width: 76, height: 76)
            Image("logo-tregga")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
        }
        .padding(.horizontal, 24)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy))
            .tracking(0.3)
            .textCase(.uppercase)
            .foregroundStyle(TreggaColors.textSec)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
    }

    private var pasos: some View {
        VStack(spacing: 0) {
            ForEach(Array(SignupIntroView.pasoLista.enumerated()), id: \.offset) { _, paso in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(TreggaColors.primarySoft).frame(width: 28, height: 28)
                        Text("\(paso.num)")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(TreggaColors.primaryDeep)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(paso.label).font(.system(size: 14, weight: .heavy))
                        Text(paso.sub).font(.system(size: 12)).foregroundStyle(TreggaColors.textSec)
                    }
                    Spacer()
                }
                .padding(.vertical, 11)
                .overlay(alignment: .top) {
                    Rectangle().fill(TreggaColors.divider).frame(height: 1)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private static let pasoLista: [(num: Int, label: String, sub: String)] = [
        (1, "Tu nombre completo", "Para tu perfil y tus pedidos"),
        (2, "Correo y fecha de nacimiento", "Para tu cuenta y recibos"),
        (3, "Foto de perfil", "Opcional, para personalizar tu cuenta"),
        (4, "Tu dirección", "A dónde te entregamos"),
        (5, "Contraseña segura", "Para entrar después"),
        (6, "Aceptar términos", "Términos y privacidad de Tregga")
    ]

    private var tipBox: some View {
        HStack(alignment: .top, spacing: 10) {
            TreggaIcon(.clock, size: 16, color: TreggaColors.textSec)
            Text("Toma aproximadamente **3 minutos**. Después podrás pedir de inmediato.")
                .font(.system(size: 12.5))
                .foregroundStyle(TreggaColors.textSec)
                .lineSpacing(2)
        }
        .padding(12)
        .background(TreggaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var bottomBar: some View {
        TreggaButton("Empezar registro", kind: .primary, action: onContinue)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(TreggaColors.bg)
    }
}

// MARK: - Step 1: Name

public struct SignupNameView: View {
    @Bindable var state: SignupFlowState
    let onBack: () -> Void
    let onContinue: () -> Void

    public init(state: SignupFlowState, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.state = state
        self.onBack = onBack
        self.onContinue = onContinue
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DriverHeader(title: "Tu nombre", subtitle: "Como quieres que te llamemos", onBack: onBack)
                SignupProgress(step: 1)

                Group {
                    Text("¿Cómo te llamas?").treggaStyle(.h3)
                    Text("Tu nombre aparece en tus pedidos y recibos.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineSpacing(13.5 * 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Spacer().frame(height: 18)

                VStack(spacing: 14) {
                    nameField("Nombre(s)", text: $state.nombres)
                    nameField("Apellido paterno", text: $state.apellidoPaterno)
                    nameField("Apellido materno (opcional)", text: $state.apellidoMaterno)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) { backContinueBar(canContinue: state.nameStepValid, onContinue: onContinue) }
        .background(TreggaColors.bg)
    }
}

// MARK: - Step 2: Email + Fecha + Teléfono

public struct SignupEmailView: View {
    @Bindable var state: SignupFlowState
    let onBack: () -> Void
    let onContinue: () -> Void

    public init(state: SignupFlowState, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.state = state
        self.onBack = onBack
        self.onContinue = onContinue
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DriverHeader(title: "Tus datos", subtitle: "Correo, teléfono y fecha de nacimiento", onBack: onBack)
                SignupProgress(step: 2)

                Group {
                    Text("Casi listo").treggaStyle(.h3)
                    Text("Usamos tu correo y teléfono para confirmaciones, soporte y para iniciar sesión.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineSpacing(13.5 * 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Spacer().frame(height: 18)

                VStack(spacing: 14) {
                    emailField
                    phoneField
                    fechaNacimientoField

                    if let error = state.emailDuplicadoError {
                        Text(error)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TreggaColors.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) { backContinueBar(canContinue: state.emailStepValid, onContinue: onContinue) }
        .background(TreggaColors.bg)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Correo electrónico")
            // Placeholder SIN forma de correo: una cadena con `@`/dominio dispara
            // los data detectors de iOS y se pinta azul (como enlace). Un texto
            // genérico queda gris, igual que en Tregga Delivery.
            TextField("Tu correo electrónico", text: $state.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(14)
                .background(TreggaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .font(.system(size: 15.5, weight: .heavy))
        }
    }

    // Teléfono MX con máscara. Obligatorio: contacto y método de login.
    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Teléfono")
            HStack(spacing: 10) {
                Text("+52")
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.textSec)
                Rectangle().fill(TreggaColors.border).frame(width: 1, height: 22)
                TextField("(55) 123 4567", text: phoneBinding)
                    .keyboardType(.numberPad)
                    .font(.system(size: 15.5, weight: .heavy))
            }
            .padding(14)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var phoneBinding: Binding<String> {
        Binding(
            get: { PhoneFormatter.format(Self.nationalDigits(state.phoneE164)) },
            set: { state.phoneE164 = PhoneFormatter.e164MX($0) ?? PhoneFormatter.digits($0) }
        )
    }

    private static func nationalDigits(_ s: String) -> String {
        var d = s.filter(\.isNumber)
        if d.count == 12, d.hasPrefix("52") { d = String(d.dropFirst(2)) }
        return String(d.prefix(10))
    }

    private var fechaNacimientoField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Fecha de nacimiento")
            DatePicker(
                "",
                selection: Binding(
                    get: { state.fechaNacimiento ?? Date(timeIntervalSince1970: 0) },
                    set: { state.fechaNacimiento = $0 }
                ),
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if !state.esMayorDeEdad && state.fechaNacimiento != nil {
                Text("Debes ser mayor de 18 años")
                    .font(.system(size: 12))
                    .foregroundStyle(TreggaColors.danger)
            }
        }
    }
}

// MARK: - Step 3: Photo

public struct SignupPhotoView: View {
    @Bindable var state: SignupFlowState
    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var cropImage: AvatarCropImage?
    @State private var uploading = false
    @State private var uploadError: String?
    @State private var showSourceDialog = false
    @State private var showLibrary = false
    @State private var showCamera = false
    let onBack: () -> Void
    let onContinue: () -> Void
    let storage: StorageService
    let userId: UUID?

    public init(
        state: SignupFlowState,
        storage: StorageService,
        userId: UUID?,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.state = state
        self.storage = storage
        self.userId = userId
        self.onBack = onBack
        self.onContinue = onContinue
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DriverHeader(title: "Foto de perfil", subtitle: "Opcional · personaliza tu cuenta", onBack: onBack)
                SignupProgress(step: 3)

                Group {
                    Text("Una foto tuya (opcional)").treggaStyle(.h3)
                    Text("Personaliza tu cuenta con una foto. Puedes saltarte este paso y agregarla después.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineSpacing(13.5 * 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Spacer().frame(height: 20)

                fotoPreview

                if let err = uploadError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(TreggaColors.danger)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                }
            }
            .padding(.bottom, 140)
        }
        .safeAreaInset(edge: .bottom) {
            let hasPhoto = state.fotoPerfilURL != nil
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button { showSourceDialog = true } label: {
                        Text(uploading ? "Subiendo…" : (hasPhoto ? "Cambiar foto" : "Elegir foto"))
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(TreggaColors.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(TreggaColors.surface)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(TreggaColors.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(uploading)

                    TreggaButton("Continuar", kind: .primary, action: onContinue)
                        .disabled(uploading)
                }
                Button("Saltar por ahora", action: onContinue)
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.textSec)
                    .disabled(uploading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(TreggaColors.bg)
        }
        .background(TreggaColors.bg)
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
                    Task { await uploadImage(cropped) }
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
    }

    private func handlePicked(_ item: PhotosPickerItem) async {
        uploadError = nil
        do {
            guard let raw = try await item.loadTransferable(type: Data.self) else {
                uploadError = "No se pudo leer la imagen seleccionada."
                return
            }
            guard let uiImage = UIImage(data: raw) else {
                uploadError = "Formato de imagen no soportado."
                return
            }
            cropImage = AvatarCropImage(image: uiImage)
        } catch {
            uploadError = "Error al cargar la foto: \(error.localizedDescription)"
        }
    }

    private func uploadImage(_ uiImage: UIImage) async {
        uploadError = nil
        uploading = true
        defer { uploading = false }
        let resized = resizeIfNeeded(uiImage, maxSide: 1080)
        guard let jpeg = resized.jpegData(compressionQuality: 0.85), !jpeg.isEmpty else {
            uploadError = "No se pudo convertir la imagen a JPEG."
            return
        }
        previewImage = resized
        guard let uid = userId else {
            uploadError = "Sin sesión. Reabre la app."
            return
        }
        do {
            let url = try await storage.uploadAvatar(data: jpeg, userId: uid, fileName: "avatar.jpg")
            state.fotoPerfilURL = url
        } catch {
            print("[SignupPhoto] storage upload error:", error)
            uploadError = "No se pudo subir la foto: \(error.localizedDescription)"
        }
    }

    private func resizeIfNeeded(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let maxDim = max(image.size.width, image.size.height)
        guard maxDim > maxSide else { return image }
        let scale = maxSide / maxDim
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private var fotoPreview: some View {
        ZStack {
            Circle()
                .fill(TreggaColors.primarySoft)
                .frame(width: 220, height: 220)
                .overlay(
                    Circle().strokeBorder(TreggaColors.border, style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
                )

            if let img = previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 220)
                    .clipShape(Circle())
            } else {
                TreggaIcon(.user, size: 90, color: TreggaColors.border)
            }

            if uploading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(TreggaColors.primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step 4: Address

public struct SignupAddressView: View {
    @Bindable var state: SignupFlowState
    let postalCodeRepo: PostalCodeRepository?
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var colonias: [String] = []
    @State private var lookupTask: Task<Void, Never>?
    @State private var lookupError: String?
    @State private var loadingCP = false

    public init(
        state: SignupFlowState,
        postalCodeRepo: PostalCodeRepository? = nil,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.state = state
        self.postalCodeRepo = postalCodeRepo
        self.onBack = onBack
        self.onContinue = onContinue
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DriverHeader(title: "Tu dirección", subtitle: "A dónde te entregamos", onBack: onBack)
                SignupProgress(step: 4)

                Group {
                    Text("¿Dónde te entregamos?").treggaStyle(.h3)
                    Text("Escribe tu C.P. y autocompletamos estado, municipio y colonias. Podrás agregar más direcciones después.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineSpacing(13.5 * 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Spacer().frame(height: 16)

                miniMapa

                Spacer().frame(height: 16)

                VStack(spacing: 14) {
                    plainField("Calle y número", text: $state.direccionCalle)
                    plainField("C.P.", text: $state.codigoPostal, keyboard: .numberPad)
                        .onChange(of: state.codigoPostal) { _, new in handleCPChange(new) }

                    if loadingCP {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Buscando colonias…")
                                .font(.system(size: 12.5))
                                .foregroundStyle(TreggaColors.textSec)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let lookupError {
                        Text(lookupError)
                            .font(.system(size: 12.5))
                            .foregroundStyle(TreggaColors.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    coloniaField

                    if !state.municipio.isEmpty || !state.estado.isEmpty {
                        HStack(spacing: 10) {
                            readonlyField("Municipio", value: state.municipio)
                            readonlyField("Estado", value: state.estado)
                        }
                    }

                    plainField("Referencias (opcional)", text: $state.referencias, autocapitalization: .sentences)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) { backContinueBar(canContinue: state.addressStepValid, onContinue: onContinue) }
        .background(TreggaColors.bg)
    }

    private var miniMapa: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(TreggaColors.mapBg)
            Canvas { ctx, size in
                var road1 = Path()
                road1.move(to: CGPoint(x: 0, y: size.height * 0.46))
                road1.addQuadCurve(
                    to: CGPoint(x: size.width, y: size.height * 0.77),
                    control: CGPoint(x: size.width * 0.67, y: size.height * 0.38)
                )
                ctx.stroke(road1, with: .color(TreggaColors.mapRoad), lineWidth: 22)

                var road2 = Path()
                road2.move(to: CGPoint(x: size.width * 0.42, y: 0))
                road2.addQuadCurve(
                    to: CGPoint(x: size.width * 0.28, y: size.height),
                    control: CGPoint(x: size.width * 0.44, y: size.height * 0.62)
                )
                ctx.stroke(road2, with: .color(TreggaColors.mapRoad), lineWidth: 18)
            }
            Circle()
                .fill(TreggaColors.primary)
                .overlay(Circle().stroke(TreggaColors.bg, lineWidth: 3))
                .frame(width: 28, height: 28)
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var coloniaField: some View {
        if colonias.isEmpty {
            plainField("Colonia", text: $state.colonia)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("COLONIA")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(TreggaColors.textSec)
                Menu {
                    ForEach(colonias, id: \.self) { c in
                        Button(c) { state.colonia = c }
                    }
                } label: {
                    HStack {
                        Text(state.colonia.isEmpty ? "Selecciona…" : state.colonia)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(state.colonia.isEmpty ? TreggaColors.textTer : TreggaColors.text)
                        Spacer()
                        TreggaIcon(.chevUD, size: 13, color: TreggaColors.textSec)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(TreggaColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func readonlyField(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(TreggaColors.textSec)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TreggaColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(TreggaColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func handleCPChange(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        lookupError = nil
        guard digits.count == 5, let repo = postalCodeRepo else {
            if digits.count < 5 {
                colonias = []
                state.municipio = ""
                state.estado = ""
            }
            return
        }
        lookupTask?.cancel()
        lookupTask = Task {
            loadingCP = true
            defer { loadingCP = false }
            do {
                if let info = try await repo.lookup(cp: digits) {
                    guard !Task.isCancelled else { return }
                    colonias = info.colonias
                    state.municipio = info.municipio
                    state.estado = info.estado
                    if !info.colonias.contains(state.colonia) { state.colonia = "" }
                } else {
                    colonias = []
                    state.municipio = ""
                    state.estado = ""
                    lookupError = "Código postal no encontrado"
                }
            } catch PostalCodeError.invalidFormat {
                lookupError = "C.P. inválido"
            } catch {
                lookupError = "Error al consultar el C.P."
            }
        }
    }
}

// MARK: - Step 5: Password

public struct SignupPasswordView: View {
    @Bindable var state: SignupFlowState
    @State private var revealed = false
    @State private var faceIDOn = true
    let onBack: () -> Void
    let onContinue: () -> Void

    public init(state: SignupFlowState, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.state = state
        self.onBack = onBack
        self.onContinue = onContinue
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DriverHeader(title: "Contraseña", subtitle: "Para entrar la próxima vez", onBack: onBack)
                SignupProgress(step: 5)

                Group {
                    Text("Crea una contraseña segura").treggaStyle(.h3)
                    Text("La usarás si entras desde otro dispositivo o si no te llega el código por SMS.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineSpacing(13.5 * 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Spacer().frame(height: 18)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        fieldLabel("Contraseña")
                        Spacer()
                        Button(revealed ? "OCULTAR" : "MOSTRAR") { revealed.toggle() }
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(TreggaColors.primary)
                    }
                    Group {
                        if revealed {
                            TextField("", text: $state.password)
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("", text: $state.password)
                        }
                    }
                    .autocorrectionDisabled(true)
                    .font(.system(size: 16, weight: .heavy))
                    .padding(14)
                    .background(TreggaColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 12)

                requirements

                if BiometricAuthService.shared.isAvailable {
                    Spacer().frame(height: 14)
                    faceIDRow
                }
            }
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) { backContinueBar(canContinue: state.passwordStepValid, onContinue: onContinue) }
        .background(TreggaColors.bg)
    }

    private var faceIDRow: some View {
        HStack(spacing: 12) {
            TreggaIcon(.faceId, size: 22, color: TreggaColors.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Habilitar \(BiometricAuthService.shared.availableKind == .touchID ? "Touch ID" : "Face ID")")
                    .font(.system(size: 14.5, weight: .heavy))
                    .foregroundStyle(TreggaColors.primaryDeep)
                Text("Para entrar más rápido")
                    .font(.system(size: 12))
                    .foregroundStyle(TreggaColors.primaryDeep.opacity(0.8))
            }
            Spacer()
            // Visual: el candado real se confirma con la oferta post-registro
            // (necesita autenticación biométrica para activarse).
            Toggle("", isOn: $faceIDOn)
                .labelsHidden()
                .tint(TreggaColors.primary)
        }
        .padding(14)
        .background(TreggaColors.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    private var requirements: some View {
        let reqs: [(label: String, ok: Bool)] = [
            ("8+ caracteres", state.password.count >= 8),
            ("Una letra mayúscula", state.password.rangeOfCharacter(from: .uppercaseLetters) != nil),
            ("Un número", state.password.rangeOfCharacter(from: .decimalDigits) != nil)
        ]
        return VStack(alignment: .leading, spacing: 0) {
            fieldLabel("Requisitos")
                .padding(.bottom, 8)
            ForEach(reqs, id: \.label) { req in
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(req.ok ? TreggaColors.primary : TreggaColors.surface2)
                            .frame(width: 18, height: 18)
                        TreggaIcon(sfSymbol: req.ok ? "checkmark" : "xmark", size: 9, color: req.ok ? .white : TreggaColors.textSec)
                    }
                    Text(req.label)
                        .font(.system(size: 12.5))
                        .foregroundStyle(req.ok ? TreggaColors.text : TreggaColors.textSec)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TreggaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }
}

// MARK: - Step 6: Terms

public struct SignupTermsView: View {
    @Bindable var state: SignupFlowState
    let onBack: () -> Void
    let onCrearCuenta: () -> Void
    let submitting: Bool
    let errorMessage: String?

    @State private var selectedDoc: LegalDocument? = nil

    public init(
        state: SignupFlowState,
        submitting: Bool,
        errorMessage: String?,
        onBack: @escaping () -> Void,
        onCrearCuenta: @escaping () -> Void
    ) {
        self.state = state
        self.submitting = submitting
        self.errorMessage = errorMessage
        self.onBack = onBack
        self.onCrearCuenta = onCrearCuenta
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DriverHeader(title: "Términos de servicio", subtitle: "Términos y privacidad de Tregga", onBack: onBack)
                SignupProgress(step: 6)

                Group {
                    Text("Casi listo").treggaStyle(.h3)
                    Text("Antes de crear tu cuenta, acepta los Términos y la Política de privacidad de Tregga.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineSpacing(13.5 * 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Spacer().frame(height: 18)

                documentLinks
                Spacer().frame(height: 14)
                acceptanceCheckbox
                Spacer().frame(height: 12)
                marketingCheckbox

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12.5))
                        .foregroundStyle(TreggaColors.danger)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                }
            }
            .padding(.bottom, 160)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                TreggaButton(
                    submitting ? "Creando cuenta…" : "Crear mi cuenta",
                    kind: .primary,
                    action: onCrearCuenta
                )
                .disabled(!state.termsStepValid || submitting)
                Text("Al continuar, generamos tu cuenta y aceptas nuestros términos.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TreggaColors.textSec)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(TreggaColors.bg)
        }
        .background(TreggaColors.bg)
        .sheet(item: $selectedDoc) { doc in
            LegalDocumentView(document: doc, onBack: { selectedDoc = nil })
        }
    }

    private var documentLinks: some View {
        let rows: [(id: String, sub: String)] = [
            ("terminos-servicio", "Cómo funciona Tregga y tus responsabilidades"),
            ("politica-privacidad", "Cómo cuidamos tus datos"),
        ]
        let docs = rows.compactMap { row -> (doc: LegalDocument, sub: String)? in
            guard let doc = FoodLegalContent.document(id: row.id) else { return nil }
            return (doc, row.sub)
        }
        return VStack(spacing: 0) {
            ForEach(Array(docs.enumerated()), id: \.offset) { _, item in
                Button { selectedDoc = item.doc } label: {
                    documentRow(title: item.doc.title, sub: item.sub)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(TreggaColors.divider).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func documentRow(title: String, sub: String) -> some View {
        HStack(spacing: 10) {
            TreggaIcon(.info, size: 14, color: TreggaColors.textSec)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(TreggaColors.text)
                Text(sub)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TreggaColors.textSec)
            }
            Spacer()
            TreggaIcon(.chevR, size: 13, color: TreggaColors.textSec)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var acceptanceCheckbox: some View {
        Button { state.acceptedTerms.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(state.acceptedTerms ? TreggaColors.primary : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(state.acceptedTerms ? TreggaColors.primary : TreggaColors.border, lineWidth: 2)
                        )
                    if state.acceptedTerms {
                        TreggaIcon(.check, size: 12, color: .white)
                    }
                }
                Text("Acepto los **Términos del servicio** y la **Política de privacidad** de Tregga.")
                    .font(.system(size: 13))
                    .foregroundStyle(TreggaColors.primaryDeep)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(TreggaColors.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var marketingCheckbox: some View {
        Button { state.optInMarketing.toggle() } label: {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(state.optInMarketing ? TreggaColors.primary : Color.clear)
                    .frame(width: 22, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(TreggaColors.border, lineWidth: 2)
                    )
                Text("Quiero recibir ofertas y novedades por correo (opcional)")
                    .font(.system(size: 12))
                    .foregroundStyle(TreggaColors.textSec)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(12)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

// MARK: - Step 7: Success

public struct SignupSuccessView: View {
    public let nombres: String
    public let onContinuar: () -> Void

    public init(nombres: String, onContinuar: @escaping () -> Void) {
        self.nombres = nombres
        self.onContinuar = onContinuar
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 70)
                heroCard
            }
            .padding(.bottom, 140)
        }
        .safeAreaInset(edge: .bottom) {
            TreggaButton("Empezar a pedir", kind: .primary, action: onContinuar)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .background(TreggaColors.bg)
        }
        .background(TreggaColors.bg)
    }

    private var heroCard: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: TreggaColors.primary, location: 0),
                    .init(color: TreggaColors.primaryDark, location: 0.6),
                    .init(color: TreggaColors.primaryDeep, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.22), Color.clear],
                center: .init(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: 200
            )
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.22)).frame(width: 80, height: 80)
                    TreggaIcon(.check, size: 38, color: .white)
                }
                Text("¡Cuenta creada!")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                    .padding(.top, 16)
                Text("Hola **\(firstName)**, ya formas parte de Tregga. ¡A pedir!")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineSpacing(14.5 * 0.45)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 16)
    }

    private var firstName: String {
        nombres.isEmpty ? "cliente" : (nombres.split(separator: " ").first.map(String.init) ?? nombres)
    }
}

// MARK: - Helpers compartidos

private func fieldLabel(_ label: String) -> some View {
    Text(label)
        .font(.system(size: 12, weight: .heavy))
        .tracking(0.3)
        .textCase(.uppercase)
        .foregroundStyle(TreggaColors.textSec)
}

/// Campo de texto para nombres/apellidos: capitaliza palabras en onChange.
@ViewBuilder
fileprivate func nameField(_ label: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        fieldLabel(label)
        TextField("Toca para escribir…", text: text)
            .textInputAutocapitalization(.words)
            .onChange(of: text.wrappedValue) { _, new in
                let c = NameFormatter.capitalizedWords(new)
                if c != new { text.wrappedValue = c }
            }
            .padding(14)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .font(.system(size: 15.5, weight: .heavy))
    }
}

@ViewBuilder
fileprivate func plainField(
    _ label: String,
    text: Binding<String>,
    keyboard: UIKeyboardType = .default,
    autocapitalization: TextInputAutocapitalization = .words
) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        fieldLabel(label)
        TextField("Toca para escribir…", text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocapitalization)
            .padding(14)
            .background(TreggaColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .font(.system(size: 15.5, weight: .heavy))
    }
}

@ViewBuilder
fileprivate func backContinueBar(canContinue: Bool, onContinue: @escaping () -> Void) -> some View {
    TreggaButton(
        "Continuar",
        kind: .primary,
        iconRight: TreggaIcon.image(.arrow),
        action: onContinue
    )
    .disabled(!canContinue)
    .padding(.horizontal, 20)
    .padding(.bottom, 24)
    .background(TreggaColors.bg)
}
