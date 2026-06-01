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

    public init(defaults: UserDefaults = .standard) {
        let useSupabase = defaults.bool(forKey: "USE_SUPABASE_BACKEND")
        let bypassOTP = defaults.bool(forKey: "BYPASS_OTP")
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
        }
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
