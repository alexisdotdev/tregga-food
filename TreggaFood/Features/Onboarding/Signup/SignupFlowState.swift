import Foundation
import TreggaCore
import Observation

/// Estado compartido del flujo signup-correo del cliente (8 pantallas).
/// Acumula los campos capturados a lo largo de los pasos para hacer un único
/// submit al final. El cliente NO captura CURP, género, INE ni vehículo.
@MainActor
@Observable
public final class SignupFlowState {
    public var phoneE164: String = ""

    // Paso 1: nombre
    public var nombres: String = ""
    public var apellidoPaterno: String = ""
    public var apellidoMaterno: String = ""

    // Paso 2: correo + fecha de nacimiento + teléfono
    public var email: String = ""
    public var fechaNacimiento: Date?
    /// Error de duplicados (correo/teléfono ya registrados) para el paso 2.
    public var emailDuplicadoError: String?

    // Paso 3: foto de perfil
    public var fotoPerfilURL: URL?

    // Paso 4: dirección
    public var direccionCalle: String = ""
    public var colonia: String = ""
    public var codigoPostal: String = ""
    public var municipio: String = ""
    public var estado: String = ""
    public var referencias: String = ""

    // Paso 5: password
    public var password: String = ""

    // Paso 6: términos
    public var acceptedTerms: Bool = false
    public var optInMarketing: Bool = false

    public init() {}

    public func reset() {
        phoneE164 = ""
        nombres = ""
        apellidoPaterno = ""
        apellidoMaterno = ""
        email = ""
        fechaNacimiento = nil
        emailDuplicadoError = nil
        fotoPerfilURL = nil
        direccionCalle = ""
        colonia = ""
        codigoPostal = ""
        municipio = ""
        estado = ""
        referencias = ""
        password = ""
        acceptedTerms = false
        optInMarketing = false
    }

    // MARK: - Validaciones por paso

    public var nameStepValid: Bool {
        !nombres.trimmingCharacters(in: .whitespaces).isEmpty
            && !apellidoPaterno.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var emailStepValid: Bool {
        emailLooksValid(email) && telefonoValid && fechaNacimiento != nil && esMayorDeEdad
    }

    /// El teléfono es obligatorio: vía de contacto y método de login.
    /// Acepta `phoneE164` ya en E.164 (+52…) o 10 dígitos nacionales.
    public var telefonoValid: Bool {
        var d = phoneE164.filter(\.isNumber)
        if d.count == 12, d.hasPrefix("52") { d = String(d.dropFirst(2)) }
        return d.count == 10
    }

    public var photoStepValid: Bool {
        fotoPerfilURL != nil
    }

    public var addressStepValid: Bool {
        !direccionCalle.trimmingCharacters(in: .whitespaces).isEmpty
            && !colonia.trimmingCharacters(in: .whitespaces).isEmpty
            && codigoPostal.filter(\.isNumber).count == 5
            && !municipio.trimmingCharacters(in: .whitespaces).isEmpty
            && !estado.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var passwordStepValid: Bool {
        password.count >= 8
            && password.rangeOfCharacter(from: .uppercaseLetters) != nil
            && password.rangeOfCharacter(from: .decimalDigits) != nil
    }

    public var termsStepValid: Bool {
        acceptedTerms
    }

    public var esMayorDeEdad: Bool {
        guard let f = fechaNacimiento else { return false }
        let years = Calendar.current.dateComponents([.year], from: f, to: Date()).year ?? 0
        return years >= 18
    }

    /// E.164 normalizado del teléfono capturado (vacío si no hay 10 dígitos).
    public var phoneE164Normalized: String {
        var d = phoneE164.filter(\.isNumber)
        if d.count == 12, d.hasPrefix("52") { d = String(d.dropFirst(2)) }
        guard d.count == 10 else { return "" }
        return "+52\(d)"
    }

    private func emailLooksValid(_ s: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return s.range(of: pattern, options: [.caseInsensitive, .regularExpression]) != nil
    }
}
