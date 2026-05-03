import Foundation

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
        case .saglik: return "cross.case"
        case .hukuk: return "scale.3d"
        case .isletme: return "storefront"
        case .finans: return "francsign.circle"
        case .tercume: return "character.bubble"
        case .meslek: return "hammer"
        case .okullar: return "graduationcap"
        case .camiler: return "moon.stars"
        case .mezunlar: return "person.2"
        case .destek_dersi: return "book"
        }
    }

    /// Phase 1: only Sağlık was wired. Phase 2: all 10 directories share the same
    /// list/detail/submit code paths against the backend.
    var isActive: Bool { true }

    @available(*, deprecated, renamed: "isActive")
    var isPhase1Active: Bool { isActive }
}
