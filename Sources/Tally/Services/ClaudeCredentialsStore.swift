import Foundation

/// Reads OAuth credentials that Claude Code persists at
/// `~/.claude/.credentials.json` after the user runs `claude` and logs in.
/// We piggyback on those tokens to call `/api/oauth/usage` without
/// asking the user to authenticate Tally separately.
struct ClaudeCredentialsStore: Sendable {
    struct Credentials: Sendable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date?
    }

    var credentialsURL: URL = URL(fileURLWithPath: NSString(string: "~/.claude/.credentials.json").expandingTildeInPath)

    func load() -> Credentials? {
        guard let data = try? Data(contentsOf: credentialsURL),
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
                // Some versions store as string; treat as ms.
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
