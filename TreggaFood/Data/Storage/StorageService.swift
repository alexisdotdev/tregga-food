import Foundation

/// Sube binarios al bucket público `avatars` con path `{userId}/avatar.jpg`.
/// Devuelve la URL pública del archivo.
public protocol StorageService: Sendable {
    func uploadAvatar(data: Data, userId: UUID, fileName: String) async throws -> URL
}

public enum StorageError: Error, Equatable, Sendable {
    case uploadFailed
    case invalidFile
}

@MainActor
public final class MockStorageService: StorageService {
    public var uploads: [(userId: UUID, fileName: String, bytes: Int)] = []

    public init() {}

    public func uploadAvatar(data: Data, userId: UUID, fileName: String) async throws -> URL {
        guard !data.isEmpty else { throw StorageError.invalidFile }
        uploads.append((userId, fileName, data.count))
        let urlString = "https://mock-storage.tregga.app/avatars/\(userId.uuidString.lowercased())/\(fileName)"
        guard let url = URL(string: urlString) else { throw StorageError.uploadFailed }
        return url
    }
}
