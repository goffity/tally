import Foundation
import Security

/// Reads OAuth credentials that Claude Code persists for its `/usage` calls.
///
/// On macOS the CLI stores the JSON blob in the user's Keychain (service name
/// `Claude Code-credentials`); on Linux and in some legacy installs it lands
/// on disk at `~/.claude/.credentials.json`. We try the Keychain first since
/// that's the modern path on this app's only platform, then fall back to the
/// file so Linux users (or anyone with both) still works.
struct ClaudeCredentialsStore: Sendable {
    struct Credentials: Sendable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date?
    }

    var keychainService: String = "Claude Code-credentials"
    var credentialsURL: URL = URL(fileURLWithPath: NSString(string: "~/.claude/.credentials.json").expandingTildeInPath)

    func load() -> Credentials? {
        if let creds = decode(loadFromKeychain()) {
            return creds
        }
        return decode(loadFromFile())
    }

    // MARK: - Sources

    private func loadFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    private func loadFromFile() -> Data? {
        try? Data(contentsOf: credentialsURL)
    }

    // MARK: - Decode

    private func decode(_ data: Data?) -> Credentials? {
        guard let data,
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = raw["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              !accessToken.isEmpty
        else { return nil }

        let refreshToken = oauth["refreshToken"] as? String
        let expiresAt: Date? = {
            if let ms = oauth["expiresAt"] as? Double {
                return Date(timeIntervalSince1970: ms / 1000)
            }
            if let s = oauth["expiresAt"] as? String, let interval = TimeInterval(s) {
                return Date(timeIntervalSince1970: interval / 1000)
            }
            return nil
        }()

        return Credentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }
}
