import Foundation
import GoogleSignIn
import UIKit

/// Sign-in nativo con Google (SDK `GoogleSignIn`): muestra el selector de cuenta
/// nativo de Google —NO el diálogo con el dominio de Supabase— y devuelve el
/// `idToken` para canjearlo con Supabase (`signInWithIdToken`).
///
/// El `clientID` se lee del `GoogleService-Info.plist` del bundle (clave
/// `CLIENT_ID`). El URL scheme `REVERSED_CLIENT_ID` debe estar registrado en el
/// Info.plist para que el callback vuelva a la app.
enum GoogleSignInHelper {
    struct Result {
        let idToken: String
        let accessToken: String
    }

    enum SignInError: LocalizedError {
        case noClientID
        case noPresenter
        case noIdToken

        var errorDescription: String? {
            switch self {
            case .noClientID:  return "Falta la configuración de Google (CLIENT_ID)."
            case .noPresenter: return "No se pudo presentar el inicio de sesión."
            case .noIdToken:   return "Google no devolvió el token de identidad."
            }
        }
    }

    @MainActor
    static func signIn() async throws -> Result {
        guard let clientID = clientIDFromPlist() else { throw SignInError.noClientID }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = topViewController() else { throw SignInError.noPresenter }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else { throw SignInError.noIdToken }
            return Result(idToken: idToken, accessToken: result.user.accessToken.tokenString)
        } catch let error as GIDSignInError where error.code == .canceled {
            throw CancellationError()
        }
    }

    /// Procesa el callback OAuth (llamar desde `application(_:open:options:)`).
    @MainActor
    static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    private static func clientIDFromPlist() -> String? {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url),
              let clientID = dict["CLIENT_ID"] as? String else { return nil }
        return clientID
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
