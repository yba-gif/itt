import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    private static let tokenKey = "auth_token"
    private static let userIdKey = "auth_user_id"

    @Published private(set) var token: String?
    @Published private(set) var user: UserMe?

    init() {
        self.token = Keychain.read(Self.tokenKey)
        APIClient.shared.tokenProvider = { [weak self] in self?.token }
        if token != nil { Task { await refreshMe() } }
    }

    var isAuthenticated: Bool { token != nil && user?.id != nil }

    func adopt(_ tokenValue: String) async {
        Keychain.write(Self.tokenKey, value: tokenValue)
        self.token = tokenValue
        await refreshMe()
    }

    func signOut() {
        Keychain.delete(Self.tokenKey)
        Keychain.delete(Self.userIdKey)
        token = nil
        user = nil
    }

    func refreshMe() async {
        do {
            self.user = try await APIClient.shared.me()
        } catch {
            // Token may have been revoked or expired — clear it.
            signOut()
        }
    }

    func deleteAccount() async throws {
        try await APIClient.shared.deleteMe()
        signOut()
    }
}
