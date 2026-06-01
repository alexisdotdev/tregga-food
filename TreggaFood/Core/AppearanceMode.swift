import SwiftUI

/// Apariencia elegida por el usuario en Cuenta → Preferencias.
/// Persistida en `@AppStorage("APPEARANCE_MODE")` y aplicada en el root vía
/// `.preferredColorScheme`.
public enum AppearanceMode: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    public var label: String {
        switch self {
        case .system: return "Automático"
        case .light:  return "Claro"
        case .dark:   return "Oscuro"
        }
    }

    public var sub: String {
        switch self {
        case .system: return "Sigue el sistema"
        case .light:  return "Siempre claro"
        case .dark:   return "Siempre oscuro"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
