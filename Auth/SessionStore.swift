import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var user: User?

    private let tokenKey = "itproject.jwt"
    private let userKey = "itproject.user"

    var isLoggedIn: Bool { token != nil && user != nil }

    init() {
        token = UserDefaults.standard.string(forKey: tokenKey)
        if let data = UserDefaults.standard.data(forKey: userKey) {
            user = try? JSONDecoder().decode(User.self, from: data)
        }
        if token == nil { user = nil }
    }

    func apply(_ payload: AuthPayload) {
        token = payload.token
        user = payload.user
        UserDefaults.standard.set(payload.token, forKey: tokenKey)
        if let data = try? JSONEncoder().encode(payload.user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    func signOut() {
        token = nil
        user = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    func client() -> GraphQLClient {
        GraphQLClient(token: token)
    }
}
