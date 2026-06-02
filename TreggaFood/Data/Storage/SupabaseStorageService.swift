import Foundation
import TreggaCore
import Supabase
import Storage

/// Sube la foto de perfil del cliente al bucket público `avatars`
/// (`{userId}/avatar.jpg`) y devuelve la URL pública.
public final class SupabaseStorageService: StorageService {
    private let client: SupabaseClient
    private let bucketId = "avatars"

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    public func uploadAvatar(data: Data, userId: UUID, fileName: String) async throws -> URL {
        guard !data.isEmpty else { throw StorageError.invalidFile }
        // Usamos el `auth.uid()` actual como prefijo del path: si difiere del
        // `userId` que nos pasaron (re-signIn/restore), la RLS del bucket falla con 403.
        let currentUserId = (try? await client.auth.user())?.id
        let pathUserId = currentUserId ?? userId
        // `auth.uid()::text` en Postgres es lowercase; normalizamos para que la RLS empate.
        let path = "\(pathUserId.uuidString.lowercased())/\(fileName)"
        let bucket = client.storage.from(bucketId)
        do {
            _ = try await bucket.upload(
                path,
                data: data,
                options: FileOptions(contentType: contentType(for: fileName), upsert: true)
            )
        } catch {
            print("[SupabaseStorage] upload failed at \(path):", error)
            throw StorageError.uploadFailed
        }
        do {
            // Bucket público → URL directa, sin firma ni expiración.
            return try bucket.getPublicURL(path: path)
        } catch {
            print("[SupabaseStorage] getPublicURL failed at \(path):", error)
            throw StorageError.uploadFailed
        }
    }

    private func contentType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png":         return "image/png"
        case "heic":        return "image/heic"
        default:            return "application/octet-stream"
        }
    }
}
