import Foundation

/// Where the session token lives on launch.
///
/// The keychain wins. A token still sitting in UserDefaults is copied across
/// and then removed, including when the keychain already has one, so the
/// secret does not stay in defaults.
enum TokenBootstrap {
    struct Decision: Equatable {
        var token: String?
        var writeToKeychain: String?
        var clearDefaults: Bool
    }

    static func decide(keychain: String?, defaults: String?) -> Decision {
        if let keychain {
            return Decision(
                token: keychain,
                writeToKeychain: nil,
                clearDefaults: defaults != nil
            )
        }
        if let defaults {
            return Decision(
                token: defaults,
                writeToKeychain: defaults,
                clearDefaults: true
            )
        }
        return Decision(token: nil, writeToKeychain: nil, clearDefaults: false)
    }
}
