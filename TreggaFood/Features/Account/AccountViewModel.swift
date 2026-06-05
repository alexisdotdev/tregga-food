import Foundation
import Observation
import UIKit
import TreggaCore

/// Estado de la sección Cuenta (F6). Carga perfil + cliente + preferencias,
/// y centraliza las escrituras (perfil, direcciones, prefs, eliminar cuenta).
@MainActor
@Observable
public final class AccountViewModel {
    public enum Phase: Equatable { case cargando, cargado, error(String) }

    public private(set) var phase: Phase = .cargando
    public var perfil: PerfilCliente?
    public var cliente: Cliente?
    public var direcciones: [DireccionCliente] = []
    public var prefs: PreferenciasUsuario?

    private let userId: UUID
    private let profileRepo: ProfileRepository
    private let clienteRepo: ClienteRepository
    private let direccionRepo: DireccionClienteRepository
    private let preferenciasRepo: PreferenciasRepository
    private let accountRepo: AccountRepository
    private let storageService: StorageService

    public init(
        userId: UUID,
        profileRepo: ProfileRepository,
        clienteRepo: ClienteRepository,
        direccionRepo: DireccionClienteRepository,
        preferenciasRepo: PreferenciasRepository,
        accountRepo: AccountRepository,
        storageService: StorageService
    ) {
        self.userId = userId
        self.profileRepo = profileRepo
        self.clienteRepo = clienteRepo
        self.direccionRepo = direccionRepo
        self.preferenciasRepo = preferenciasRepo
        self.accountRepo = accountRepo
        self.storageService = storageService
    }

    public var displayName: String {
        perfil?.displayName ?? cliente?.displayName ?? "Cliente"
    }

    public var initials: String {
        perfil?.initials ?? "T"
    }

    public var contactoLine: String {
        let phone = perfil?.phone ?? cliente?.phone
        let pedidos = cliente?.totalOrders ?? 0
        let phonePart = phone.map { PhoneFormatter.displayMX($0) } ?? perfil?.email ?? ""
        if pedidos > 0 {
            return phonePart.isEmpty ? "\(pedidos) pedidos" : "\(phonePart) · \(pedidos) pedidos"
        }
        return phonePart
    }

    // MARK: - Carga

    public func cargar() async {
        phase = .cargando
        do {
            async let perfilTask = profileRepo.fetch(userId: userId)
            async let clienteTask = clienteRepo.fetchByUserId(userId)
            async let prefsTask = preferenciasRepo.get(userId: userId)
            let (p, c, pr) = try await (perfilTask, clienteTask, prefsTask)
            self.perfil = p
            self.cliente = c
            self.prefs = pr
            if let clienteId = c?.id {
                self.direcciones = (try? await direccionRepo.fetchDelCliente(clienteId: clienteId)) ?? []
            }
            phase = .cargado
        } catch {
            phase = .error("No pudimos cargar tu cuenta. Reintenta.")
        }
    }

    // MARK: - Perfil

    public func guardarPerfil(
        fullName: String,
        apellidoPaterno: String,
        apellidoMaterno: String,
        email: String?,
        phone: String?,
        fechaNacimiento: Date?
    ) async -> Bool {
        do {
            let updated = try await profileRepo.actualizar(
                userId: userId,
                fullName: fullName,
                apellidoPaterno: apellidoPaterno,
                apellidoMaterno: apellidoMaterno,
                email: email,
                phone: phone,
                fechaNacimiento: fechaNacimiento,
                avatarUrl: perfil?.avatarUrl,
                calle: perfil?.calle,
                colonia: perfil?.colonia,
                codigoPostal: perfil?.codigoPostal,
                municipio: perfil?.municipio,
                estado: perfil?.estado
            )
            self.perfil = updated
            return true
        } catch {
            return false
        }
    }

    /// Sube una nueva foto de perfil al bucket `avatars` y persiste su URL,
    /// preservando el resto de los campos del perfil.
    public func actualizarAvatar(_ image: UIImage) async -> Bool {
        guard let jpeg = image.jpegData(compressionQuality: 0.85), !jpeg.isEmpty else { return false }
        do {
            let url = try await storageService.uploadAvatar(data: jpeg, userId: userId, fileName: "avatar.jpg")
            let updated = try await profileRepo.actualizar(
                userId: userId,
                fullName: perfil?.fullName,
                apellidoPaterno: perfil?.apellidoPaterno,
                apellidoMaterno: perfil?.apellidoMaterno,
                email: perfil?.email,
                phone: perfil?.phone,
                fechaNacimiento: perfil?.fechaNacimiento,
                avatarUrl: url.absoluteString,
                calle: perfil?.calle,
                colonia: perfil?.colonia,
                codigoPostal: perfil?.codigoPostal,
                municipio: perfil?.municipio,
                estado: perfil?.estado
            )
            self.perfil = updated
            return true
        } catch {
            return false
        }
    }

    // MARK: - Direcciones

    public func recargarDirecciones() async {
        guard let clienteId = cliente?.id else { return }
        self.direcciones = (try? await direccionRepo.fetchDelCliente(clienteId: clienteId)) ?? []
    }

    public func crearDireccion(label: String, address: String, referencias: String?, isDefault: Bool) async {
        guard let clienteId = cliente?.id else { return }
        _ = try? await direccionRepo.crear(
            clienteId: clienteId, label: label, address: address,
            referencias: referencias, isDefault: isDefault
        )
        await recargarDirecciones()
    }

    public func editarDireccion(id: UUID, label: String, address: String, referencias: String?) async {
        _ = try? await direccionRepo.editar(id: id, label: label, address: address, referencias: referencias)
        await recargarDirecciones()
    }

    public func eliminarDireccion(id: UUID) async {
        try? await direccionRepo.eliminar(id: id)
        await recargarDirecciones()
    }

    public func hacerDireccionPrincipal(id: UUID) async {
        guard let clienteId = cliente?.id else { return }
        try? await direccionRepo.hacerDefault(id: id, clienteId: clienteId)
        await recargarDirecciones()
    }

    // MARK: - Preferencias

    /// Aplica una mutación local y persiste. Si falla, recarga el estado real.
    public func actualizarPrefs(_ mutate: (inout PreferenciasUsuario) -> Void) async {
        guard var p = prefs else { return }
        mutate(&p)
        self.prefs = p
        do {
            self.prefs = try await preferenciasRepo.set(p)
        } catch {
            self.prefs = try? await preferenciasRepo.get(userId: userId)
        }
    }

    // MARK: - Cuenta

    public func eliminarCuenta() async -> Bool {
        do {
            try await accountRepo.eliminarCuenta()
            return true
        } catch {
            return false
        }
    }

    public func solicitarDescargaDatos() async {
        try? await accountRepo.solicitarDescargaDatos(userId: userId)
    }
}
