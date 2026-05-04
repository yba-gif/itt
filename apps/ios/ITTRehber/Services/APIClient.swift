import Foundation

enum APIError: LocalizedError {
    case http(Int, String)
    case decoding(Error)
    case offline

    var errorDescription: String? {
        switch self {
        case .http(let status, let body): return "HTTP \(status): \(body)"
        case .decoding(let error): return "Yanıt çözümlenemedi: \(error.localizedDescription)"
        case .offline: return "Bağlantı yok."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Token-provider callback so APIClient can stay decoupled from SessionStore.
    var tokenProvider: () -> String? = { nil }

    private init() {
        let urlString =
            (Bundle.main.object(forInfoDictionaryKey: "ITTAPIBaseURL") as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "http://localhost:8000"
        self.baseURL = URL(string: urlString)!

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public listings

    func listings(
        directory: Directory? = nil,
        kanton: String? = nil,
        query: String? = nil,
        page: Int = 1,
        pageSize: Int = 50
    ) async throws -> ListingPage {
        var components = URLComponents(url: baseURL.appendingPathComponent("listings"),
                                       resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)"),
        ]
        if let directory { items.append(.init(name: "directory", value: directory.rawValue)) }
        if let kanton { items.append(.init(name: "kanton", value: kanton)) }
        if let query, !query.isEmpty { items.append(.init(name: "q", value: query)) }
        components.queryItems = items
        return try await get(url: components.url!)
    }

    func listing(id: UUID) async throws -> Listing {
        try await get(url: baseURL.appendingPathComponent("listings/\(id.uuidString)"))
    }

    func submitListing(_ input: ListingSubmitInput) async throws -> Listing {
        try await post(url: baseURL.appendingPathComponent("listings"), body: input)
    }

    // MARK: - Auth

    func emailSignup(email: String, password: String, displayName: String?) async throws -> AuthToken {
        struct Body: Encodable {
            let email: String
            let password: String
            let display_name: String?
        }
        return try await post(
            url: baseURL.appendingPathComponent("auth/email/signup"),
            body: Body(email: email, password: password, display_name: displayName)
        )
    }

    func emailLogin(email: String, password: String) async throws -> AuthToken {
        struct Body: Encodable { let email: String; let password: String }
        return try await post(
            url: baseURL.appendingPathComponent("auth/email/login"),
            body: Body(email: email, password: password)
        )
    }

    func me() async throws -> UserMe {
        try await get(url: baseURL.appendingPathComponent("auth/me"))
    }

    func deleteMe() async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("auth/me"))
        req.httpMethod = "DELETE"
        attachAuth(&req)
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp, data: data)
    }

    // MARK: - Events

    func events(kanton: String? = nil, past: Bool = false) async throws -> EventListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("events"),
                                       resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [.init(name: "past", value: past ? "true" : "false")]
        if let kanton { items.append(.init(name: "kanton", value: kanton)) }
        components.queryItems = items
        return try await get(url: components.url!)
    }

    func submitEvent(_ input: EventSubmitInput) async throws -> Event {
        try await post(url: baseURL.appendingPathComponent("events"), body: input)
    }

    // MARK: - Content

    func contentPages() async throws -> [ContentPage] {
        try await get(url: baseURL.appendingPathComponent("content"))
    }

    func contentPage(slug: String) async throws -> ContentPage {
        try await get(url: baseURL.appendingPathComponent("content/\(slug)"))
    }

    // MARK: - Global search

    func globalSearch(query: String) async throws -> SearchResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "q", value: query)]
        return try await get(url: components.url!)
    }

    // MARK: - Favorites + Saved searches + Claim

    func favorites() async throws -> [Listing] {
        try await get(url: baseURL.appendingPathComponent("me/favorites"))
    }

    func addFavorite(listingId: UUID) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("me/favorites/\(listingId.uuidString)"))
        req.httpMethod = "PUT"
        attachAuth(&req)
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp, data: data)
    }

    func removeFavorite(listingId: UUID) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("me/favorites/\(listingId.uuidString)"))
        req.httpMethod = "DELETE"
        attachAuth(&req)
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp, data: data)
    }

    func savedSearches() async throws -> [SavedSearch] {
        try await get(url: baseURL.appendingPathComponent("me/saved-searches"))
    }

    func createSavedSearch(query: String?, filters: [String: String]) async throws -> SavedSearch {
        struct Body: Encodable {
            let query: String?
            let filters: [String: String]
            let notify_on_new: Bool
        }
        return try await post(
            url: baseURL.appendingPathComponent("me/saved-searches"),
            body: Body(query: query, filters: filters, notify_on_new: true)
        )
    }

    func deleteSavedSearch(id: UUID) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("me/saved-searches/\(id.uuidString)"))
        req.httpMethod = "DELETE"
        attachAuth(&req)
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp, data: data)
    }

    func claimableListings() async throws -> [Listing] {
        try await get(url: baseURL.appendingPathComponent("listings/claimable/mine"))
    }

    func claimListing(id: UUID) async throws -> Listing {
        struct Empty: Encodable {}
        return try await post(
            url: baseURL.appendingPathComponent("listings/\(id.uuidString)/claim"),
            body: Empty()
        )
    }

    // MARK: - Push registration

    func registerPush(token: String, categories: [String], kanton: String?) async throws {
        struct Body: Encodable {
            let token: String
            let categories: [String]
            let kanton: String?
        }
        var req = URLRequest(url: baseURL.appendingPathComponent("push/register"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        attachAuth(&req)
        req.httpBody = try encoder.encode(Body(token: token, categories: categories, kanton: kanton))
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp, data: data)
    }

    // MARK: - Image upload (multipart)

    func uploadImage(data: Data, filename: String, mime: String) async throws -> String {
        let boundary = "ITT-\(UUID().uuidString)"
        var req = URLRequest(url: baseURL.appendingPathComponent("uploads/image"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        attachAuth(&req)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (respData, resp) = try await session.data(for: req)
        try ensureOK(resp, data: respData)
        struct Out: Decodable { let image_url: String }
        let decoded = try decoder.decode(Out.self, from: respData)
        return decoded.image_url
    }

    // MARK: - Generic

    private func get<T: Decodable>(url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        attachAuth(&req)
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp, data: data)
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    private func post<Body: Encodable, T: Decodable>(url: URL, body: Body) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        attachAuth(&req)
        req.httpBody = try encoder.encode(body)
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp, data: data)
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    private func attachAuth(_ req: inout URLRequest) {
        if let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func ensureOK(_ resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { throw APIError.offline }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(http.statusCode, body)
        }
    }
}

// MARK: - ISO8601 with fractional seconds

extension JSONDecoder.DateDecodingStrategy {
    static let iso8601WithFractionalSeconds: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: raw) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: raw) { return d }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Bad date: \(raw)"
        )
    }
}
