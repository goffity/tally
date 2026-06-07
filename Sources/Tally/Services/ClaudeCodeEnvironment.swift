import Foundation

/// Resolves the installed Claude Code CLI version so requests to the official
/// usage endpoint can send the mandatory `User-Agent: claude-code/<version>`
/// header. Anthropic hands out a harsh 429 bucket to callers that omit it.
///
/// A menu-bar app launched at login does **not** inherit the shell `PATH`, so we
/// search well-known install locations by absolute path instead of relying on
/// `claude` being resolvable by name. Resolution runs once and is cached for the
/// process lifetime (the CLI version rarely changes mid-session).
enum ClaudeCodeEnvironment {
    /// Used when the CLI can't be located or parsed — still a plausible
    /// claude-code UA so the endpoint accepts the request.
    static let fallbackVersion = "2.0.0"

    /// Cached, resolved once on first access.
    static let version: String = resolveVersion()

    static var userAgent: String { "claude-code/\(version)" }

    // MARK: - Resolution

    private static func resolveVersion() -> String {
        guard let binary = locateBinary(),
            let raw = run(binary, ["--version"]),
            let parsed = parse(raw)
        else { return fallbackVersion }
        return parsed
    }

    private static func locateBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.claude/local/claude",
            "\(home)/.bun/bin/claude",
            "\(home)/.npm-global/bin/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func run(_ path: String, _ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()  // swallow stderr noise
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// `"2.1.168 (Claude Code)\n"` -> `"2.1.168"`. Returns nil if the leading
    /// token doesn't look like a dotted version.
    private static func parse(_ raw: String) -> String? {
        guard
            let token =
                raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ", maxSplits: 1)
                .first
                .map(String.init)
        else { return nil }

        let looksLikeVersion = token.contains(".") && token.allSatisfy { $0.isNumber || $0 == "." }
        return looksLikeVersion ? token : nil
    }
}
