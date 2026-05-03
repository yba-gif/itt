import Foundation

struct Event: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String?
    let startsAt: Date
    let endsAt: Date?
    let kanton: String
    let venue: String?
    let address: String?
    let imageURL: String?
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case kanton
        case venue
        case address
        case imageURL = "image_url"
        case status
        case createdAt = "created_at"
    }
}

struct EventListResponse: Codable {
    let items: [Event]
    let total: Int
}

struct EventSubmitInput: Codable {
    var title: String
    var description: String?
    var startsAt: Date
    var endsAt: Date?
    var kanton: String
    var venue: String?
    var address: String?
    var imageURL: String?
    var submitterEmail: String?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case kanton
        case venue
        case address
        case imageURL = "image_url"
        case submitterEmail = "submitter_email"
    }
}
