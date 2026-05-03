import Foundation

struct AuthToken: Codable {
    let accessToken: String
    let userId: UUID
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
        case isAdmin = "is_admin"
    }
}

struct UserMe: Codable {
    let id: UUID
    let email: String
    let displayName: String?
    let isAdmin: Bool
    let language: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case isAdmin = "is_admin"
        case language
    }
}
