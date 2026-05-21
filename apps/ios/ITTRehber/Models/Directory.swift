import Foundation
import SwiftUI

/// Ten directories per PRD §4.2. Codes match backend `directories[]` values.
enum Directory: String, CaseIterable, Identifiable, Codable {
    case saglik
    case hukuk
    case isletme
    case finans
    case tercume
    case meslek
    case okullar
    case camiler
    case mezunlar
    case destek_dersi

    var id: String { rawValue }

    var titleTR: String {
        switch self {
        case .saglik: return "Sağlık"
        case .hukuk: return "Hukuk"
        case .isletme: return "İşletme"
        case .finans: return "Finans"
        case .tercume: return "Tercüme"
        case .meslek: return "Meslek (Lehre)"
        case .okullar: return "Okullar"
        case .camiler: return "Diyanet Camiler"
        case .mezunlar: return "Mezunlar"
        case .destek_dersi: return "Destek Dersi"
        }
    }

    var systemImage: String {
        switch self {
        case .saglik: return "cross.case.fill"
        case .hukuk: return "scale.3d"
        case .isletme: return "storefront.fill"
        case .finans: return "francsign.circle.fill"
        case .tercume: return "character.bubble.fill"
        case .meslek: return "hammer.fill"
        case .okullar: return "graduationcap.fill"
        case .camiler: return "moon.stars.fill"
        case .mezunlar: return "person.2.fill"
        case .destek_dersi: return "book.fill"
        }
    }

    var color: Color {
        switch self {
        case .saglik:      return Color(red: 0.18, green: 0.73, blue: 0.47) // fresh green
        case .hukuk:       return Color(red: 0.15, green: 0.39, blue: 0.92) // royal blue
        case .isletme:     return Color(red: 0.98, green: 0.45, blue: 0.09) // vivid orange
        case .finans:      return Color(red: 0.49, green: 0.23, blue: 0.93) // violet
        case .tercume:     return Color(red: 0.03, green: 0.57, blue: 0.70) // teal
        case .meslek:      return Color(red: 0.85, green: 0.47, blue: 0.04) // amber
        case .okullar:     return Color(red: 0.05, green: 0.65, blue: 0.91) // sky blue
        case .camiler:     return Color(red: 0.02, green: 0.59, blue: 0.41) // emerald
        case .mezunlar:    return Color(red: 0.20, green: 0.27, blue: 0.40) // slate navy
        case .destek_dersi:return Color(red: 0.86, green: 0.15, blue: 0.15) // red
        }
    }

    /// Phase 1: only Sağlık was wired. Phase 2: all 10 directories share the same
    /// list/detail/submit code paths against the backend.
    var isActive: Bool { true }

    @available(*, deprecated, renamed: "isActive")
    var isPhase1Active: Bool { isActive }
}
