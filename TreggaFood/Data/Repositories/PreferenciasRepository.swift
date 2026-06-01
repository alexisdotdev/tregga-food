import Foundation
import TreggaCore
import Supabase

/// Acceso a `preferencias_usuario` (1:1 con `auth.users`) para la app de cliente.
/// Si la fila no existe aún, `get` devuelve los defaults y `set` la crea (upsert).
public protocol PreferenciasRepository: Sendable {
    func get(userId: UUID) async throws -> PreferenciasUsuario
    @discardableResult
    func set(_ prefs: PreferenciasUsuario) async throws -> PreferenciasUsuario
}

// MARK: - Supabase

public final class SupabasePreferenciasRepository: PreferenciasRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    struct PrefsDTO: Codable {
        let user_id: UUID
        let sounds_enabled: Bool?
        let vibration_enabled: Bool?
        let voice_announcements: Bool?
        let show_full_name: Bool?
        let show_phone_number: Bool?
        let show_profile_photo: Bool?
        let share_location_active: Bool?
        let share_location_idle: Bool?
        let share_usage_data: Bool?
        let share_error_reports: Bool?
        let notif_ofertas: Bool?
        let notif_pagos: Bool?
        let notif_promos: Bool?
        let notif_sistema: Bool?

        func toDomain() -> PreferenciasUsuario {
            PreferenciasUsuario(
                userId: user_id,
                soundsEnabled: sounds_enabled ?? true,
                vibrationEnabled: vibration_enabled ?? true,
                voiceAnnouncements: voice_announcements ?? false,
                showFullName: show_full_name ?? false,
                showPhoneNumber: show_phone_number ?? false,
                showProfilePhoto: show_profile_photo ?? true,
                shareLocationActive: share_location_active ?? true,
                shareLocationIdle: share_location_idle ?? false,
                shareUsageData: share_usage_data ?? true,
                shareErrorReports: share_error_reports ?? true,
                notifOfertas: notif_ofertas ?? true,
                notifPagos: notif_pagos ?? true,
                notifPromos: notif_promos ?? true,
                notifSistema: notif_sistema ?? true
            )
        }

        init(_ p: PreferenciasUsuario) {
            user_id = p.userId
            sounds_enabled = p.soundsEnabled
            vibration_enabled = p.vibrationEnabled
            voice_announcements = p.voiceAnnouncements
            show_full_name = p.showFullName
            show_phone_number = p.showPhoneNumber
            show_profile_photo = p.showProfilePhoto
            share_location_active = p.shareLocationActive
            share_location_idle = p.shareLocationIdle
            share_usage_data = p.shareUsageData
            share_error_reports = p.shareErrorReports
            notif_ofertas = p.notifOfertas
            notif_pagos = p.notifPagos
            notif_promos = p.notifPromos
            notif_sistema = p.notifSistema
        }
    }

    public func get(userId: UUID) async throws -> PreferenciasUsuario {
        let dtos: [PrefsDTO] = try await client.from("preferencias_usuario")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return dtos.first?.toDomain() ?? PreferenciasUsuario(userId: userId)
    }

    @discardableResult
    public func set(_ prefs: PreferenciasUsuario) async throws -> PreferenciasUsuario {
        let dto: PrefsDTO = try await client.from("preferencias_usuario")
            .upsert(PrefsDTO(prefs), onConflict: "user_id")
            .select()
            .single()
            .execute()
            .value
        return dto.toDomain()
    }
}

// MARK: - Mock

/// Mock con almacenamiento en memoria vía actor (evita NSLock en async).
public final class MockPreferenciasRepository: PreferenciasRepository {
    private actor Store {
        var prefs: [UUID: PreferenciasUsuario] = [:]
        func get(_ id: UUID) -> PreferenciasUsuario { prefs[id] ?? PreferenciasUsuario(userId: id) }
        func set(_ p: PreferenciasUsuario) { prefs[p.userId] = p }
    }
    private let store = Store()

    public init() {}

    public func get(userId: UUID) async throws -> PreferenciasUsuario {
        await store.get(userId)
    }

    @discardableResult
    public func set(_ prefs: PreferenciasUsuario) async throws -> PreferenciasUsuario {
        await store.set(prefs)
        return prefs
    }
}
