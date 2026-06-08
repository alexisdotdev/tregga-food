import Foundation
import TreggaCore
import Supabase

public enum FeedbackKind: String, Sendable, Identifiable {
    case bug
    case feedback
    public var id: String { rawValue }
}

/// Envía reportes de bug y sugerencias del usuario a la tabla `reportes`.
public protocol FeedbackRepository: Sendable {
    func submit(
        userId: UUID,
        kind: FeedbackKind,
        message: String,
        appVersion: String,
        buildNumber: String,
        deviceModel: String,
        osVersion: String
    ) async throws
}

// MARK: - Supabase

public final class SupabaseFeedbackRepository: FeedbackRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    public func submit(
        userId: UUID,
        kind: FeedbackKind,
        message: String,
        appVersion: String,
        buildNumber: String,
        deviceModel: String,
        osVersion: String
    ) async throws {
        struct Row: Encodable {
            let user_id: String
            let kind: String
            let message: String
            let app_version: String
            let build_number: String
            let device_model: String
            let os_version: String
        }
        let row = Row(
            user_id: userId.uuidString,
            kind: kind.rawValue,
            message: message,
            app_version: appVersion,
            build_number: buildNumber,
            device_model: deviceModel,
            os_version: osVersion
        )
        try await client.from("reportes").insert(row).execute()
    }
}

// MARK: - Mock

public struct MockFeedbackRepository: FeedbackRepository {
    public init() {}
    public func submit(
        userId: UUID,
        kind: FeedbackKind,
        message: String,
        appVersion: String,
        buildNumber: String,
        deviceModel: String,
        osVersion: String
    ) async throws {}
}
