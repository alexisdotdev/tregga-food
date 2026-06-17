import Foundation
import SwiftUI
import TreggaCore

/// Composition root de Tregga Food (cliente).
///
/// Flags en `UserDefaults`:
/// - `USE_SUPABASE_BACKEND=1` → repos reales contra Supabase; si no, Mock.
/// - `BYPASS_OTP=1` (con USE_SUPABASE_BACKEND=1) → `BypassOTPAuthService`.
@MainActor
public final class AppDependencies {
    public let authService: AuthService
    public let authStorage: AuthSecureStorage
    public let authSession: AuthSession
    public let clienteRepository: ClienteRepository
    public let catalogRepository: CatalogRepository
    public let pedidoRepository: PedidoRepository
    public let direccionRepository: DireccionClienteRepository
    public let trackingRepository: TrackingRepository
    public let mensajeRepository: MensajeRepository
    public let calificacionRepository: CalificacionRepository
    public let profileRepository: ProfileRepository
    public let preferenciasRepository: PreferenciasRepository
    public let accountRepository: AccountRepository
    public let notificacionRepository: NotificacionRepository
    public let ofertaRepository: OfertaRepository
    public let appConfigRepository: AppConfigRepository
    public let feedbackRepository: FeedbackRepository
    public let favoritoRepository: FavoritoRepository
    public let storageService: StorageService
    /// Lookup de CP (SEPOMEX, servicio público) → estado/municipio/colonias.
    public let postalCodeRepository: PostalCodeRepository

    public init(defaults: UserDefaults = .standard) {
        // En release (TestFlight/App Store) SIEMPRE backend real y OTP real: los
        // launch arguments del scheme no existen en una build archivada. En debug
        // se respetan los flags para desarrollo/preview.
        #if DEBUG
        // Real por default también en debug (para probar de verdad en device);
        // -USE_MOCK YES fuerza Mock para trabajar layouts sin red. (Antes el
        // default era Mock y daba "datos dummy" + Google auth que no registraba.)
        let useSupabase = !defaults.bool(forKey: "USE_MOCK")
        let bypassOTP = defaults.bool(forKey: "BYPASS_OTP")
        #else
        let useSupabase = true
        let bypassOTP = false
        #endif
        if useSupabase {
            self.authService = bypassOTP ? BypassOTPAuthService() : SupabaseAuthService()
            self.authStorage = KeychainAuthStorage()
            self.clienteRepository = SupabaseClienteRepository()
            self.catalogRepository = SupabaseCatalogRepository()
            self.pedidoRepository = SupabasePedidoRepository()
            self.direccionRepository = SupabaseDireccionClienteRepository()
            self.trackingRepository = SupabaseTrackingRepository()
            self.mensajeRepository = SupabaseMensajeRepository()
            self.calificacionRepository = SupabaseCalificacionRepository()
            self.profileRepository = SupabaseProfileRepository()
            self.preferenciasRepository = SupabasePreferenciasRepository()
            self.accountRepository = SupabaseAccountRepository()
            self.notificacionRepository = SupabaseNotificacionRepository()
            self.ofertaRepository = SupabaseOfertaRepository()
            self.appConfigRepository = SupabaseAppConfigRepository()
            self.feedbackRepository = SupabaseFeedbackRepository()
            self.favoritoRepository = SupabaseFavoritoRepository()
            self.storageService = SupabaseStorageService()
        } else {
            self.authService = MockAuthService()
            self.authStorage = MockAuthStorage()
            self.clienteRepository = MockClienteRepository()
            self.catalogRepository = MockCatalogRepository()
            self.pedidoRepository = MockPedidoRepository()
            self.direccionRepository = MockDireccionClienteRepository()
            self.trackingRepository = MockTrackingRepository()
            self.mensajeRepository = MockMensajeRepository()
            self.calificacionRepository = MockCalificacionRepository()
            self.profileRepository = MockProfileRepository()
            self.preferenciasRepository = MockPreferenciasRepository()
            self.accountRepository = MockAccountRepository()
            self.notificacionRepository = MockNotificacionRepository()
            self.ofertaRepository = MockOfertaRepository()
            self.appConfigRepository = MockAppConfigRepository()
            self.feedbackRepository = MockFeedbackRepository()
            self.favoritoRepository = MockFavoritoRepository()
            self.storageService = MockStorageService()
        }
        // SEPOMEX es un servicio público (sin auth): se usa igual en ambos modos.
        self.postalCodeRepository = SepomexPostalCodeRepository()
        self.authSession = AuthSession(storage: self.authStorage)
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependencies? = nil
}

public extension EnvironmentValues {
    var appDependencies: AppDependencies? {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
