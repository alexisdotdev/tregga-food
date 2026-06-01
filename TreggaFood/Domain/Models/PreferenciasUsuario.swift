import Foundation

/// Preferencias del usuario (tabla `preferencias_usuario`, 1:1 con `auth.users`).
/// Cubre sonidos/movimiento, privacidad y notificaciones. La app cachea local
/// y rehidrata desde el backend.
public struct PreferenciasUsuario: Equatable, Sendable {
    public let userId: UUID

    // Sonidos y movimiento
    public var soundsEnabled: Bool
    public var vibrationEnabled: Bool
    public var voiceAnnouncements: Bool

    // Privacidad
    public var showFullName: Bool
    public var showPhoneNumber: Bool
    public var showProfilePhoto: Bool
    public var shareLocationActive: Bool
    public var shareLocationIdle: Bool
    public var shareUsageData: Bool
    public var shareErrorReports: Bool

    // Notificaciones (categorías de negocio)
    public var notifOfertas: Bool
    public var notifPagos: Bool
    public var notifPromos: Bool
    public var notifSistema: Bool

    public init(
        userId: UUID,
        soundsEnabled: Bool = true,
        vibrationEnabled: Bool = true,
        voiceAnnouncements: Bool = false,
        showFullName: Bool = false,
        showPhoneNumber: Bool = false,
        showProfilePhoto: Bool = true,
        shareLocationActive: Bool = true,
        shareLocationIdle: Bool = false,
        shareUsageData: Bool = true,
        shareErrorReports: Bool = true,
        notifOfertas: Bool = true,
        notifPagos: Bool = true,
        notifPromos: Bool = true,
        notifSistema: Bool = true
    ) {
        self.userId = userId
        self.soundsEnabled = soundsEnabled
        self.vibrationEnabled = vibrationEnabled
        self.voiceAnnouncements = voiceAnnouncements
        self.showFullName = showFullName
        self.showPhoneNumber = showPhoneNumber
        self.showProfilePhoto = showProfilePhoto
        self.shareLocationActive = shareLocationActive
        self.shareLocationIdle = shareLocationIdle
        self.shareUsageData = shareUsageData
        self.shareErrorReports = shareErrorReports
        self.notifOfertas = notifOfertas
        self.notifPagos = notifPagos
        self.notifPromos = notifPromos
        self.notifSistema = notifSistema
    }

    /// `true` si al menos una categoría de notificaciones está activa.
    public var notificacionesActivas: Bool {
        notifOfertas || notifPagos || notifPromos || notifSistema
    }
}
