import Foundation

struct ContentPage: Codable, Identifiable, Hashable {
    let slug: String
    let title: String
    let bodyMarkdown: String
    let updatedAt: Date

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case title
        case bodyMarkdown = "body_markdown"
        case updatedAt = "updated_at"
    }
}

struct SearchGroup: Codable, Hashable {
    let directory: String
    let items: [Listing]
    let count: Int
}

struct SearchResponse: Codable {
    let query: String
    let total: Int
    let groups: [SearchGroup]
}

struct SavedSearch: Codable, Identifiable, Hashable {
    let id: UUID
    let query: String?
    let filters: [String: SavedSearchFilterValue]
    let notifyOnNew: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case query
        case filters
        case notifyOnNew = "notify_on_new"
        case createdAt = "created_at"
    }
}

/// JSON values in a saved search filters dict are arbitrary; we accept the
/// common scalars and stringify for display.
enum SavedSearchFilterValue: Codable, Hashable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case array([String])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        if let a = try? c.decode([String].self) { self = .array(a); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .bool(let b): try c.encode(b)
        case .number(let d): try c.encode(d)
        case .array(let a): try c.encode(a)
        case .null: try c.encodeNil()
        }
    }

    var display: String {
        switch self {
        case .string(let s): return s
        case .bool(let b): return b ? "✓" : "—"
        case .number(let d): return String(d)
        case .array(let a): return a.joined(separator: ", ")
        case .null: return "—"
        }
    }
}
