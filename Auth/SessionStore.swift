import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var user: User?

    private let tokenKey = "itproject.jwt"
    private let userKey = "itproject.user"
    private let tokens: KeychainTokenStore
    private let defaults: UserDefaults

    var isLoggedIn: Bool { token != nil && user != nil }

    init(tokens: KeychainTokenStore = KeychainTokenStore(), defaults: UserDefaults = .standard) {
        self.tokens = tokens
        self.defaults = defaults
        let decision = TokenBootstrap.decide(
            keychain: tokens.readToken(),
            defaults: defaults.string(forKey: tokenKey)
        )
        token = decision.token
        if let migrated = decision.writeToKeychain {
            do {
                try tokens.writeToken(migrated)
                if decision.clearDefaults {
                    defaults.removeObject(forKey: tokenKey)
                }
            } catch {
                // Leave the legacy copy in place so a failed keychain write
                // does not drop the only copy of the token.
                Log.sync("keychain migration failed: \(error.localizedDescription)")
            }
        } else if decision.clearDefaults {
            defaults.removeObject(forKey: tokenKey)
        }
        if let data = defaults.data(forKey: userKey) {
            user = try? JSONDecoder().decode(User.self, from: data)
        }
        if token == nil { user = nil }
    }

    func apply(_ payload: AuthPayload) {
        token = payload.token
        user = payload.user
        do {
            try tokens.writeToken(payload.token)
        } catch {
            Log.sync("keychain write failed: \(error.localizedDescription)")
        }
        defaults.removeObject(forKey: tokenKey)
        if let data = try? JSONEncoder().encode(payload.user) {
            defaults.set(data, forKey: userKey)
        }
    }

    func signOut() {
        token = nil
        user = nil
        tokens.deleteToken()
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: userKey)
    }

    func client() -> GraphQLClient {
        GraphQLClient(token: token)
    }
}
