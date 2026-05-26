import Foundation
import Observation

/// User-tunable settings persisted to UserDefaults. Values are stored in their
/// raw cost-weighted-token units; the Settings UI converts to/from millions
/// for readability.
@MainActor
@Observable
final class AppSettings {
    struct Defaults {
        static let claudeSessionLimit: Double = 130_000_000
        static let claudeWeeklyAllLimit: Double = 400_000_000
        static let claudeWeeklySonnetLimit: Double = 300_000_000
        static let geminiDailyRequests: Double = 1000
    }

    private enum Key {
        static let claudeSessionLimit = "claude.sessionLimit"
        static let claudeWeeklyAllLimit = "claude.weeklyAllLimit"
        static let claudeWeeklySonnetLimit = "claude.weeklySonnetLimit"
        static let geminiDailyRequests = "gemini.dailyRequests"
    }

    var claudeSessionLimit: Double {
        didSet { UserDefaults.standard.set(claudeSessionLimit, forKey: Key.claudeSessionLimit) }
    }

    var claudeWeeklyAllLimit: Double {
        didSet { UserDefaults.standard.set(claudeWeeklyAllLimit, forKey: Key.claudeWeeklyAllLimit) }
    }

    var claudeWeeklySonnetLimit: Double {
        didSet { UserDefaults.standard.set(claudeWeeklySonnetLimit, forKey: Key.claudeWeeklySonnetLimit) }
    }

    var geminiDailyRequests: Double {
        didSet { UserDefaults.standard.set(geminiDailyRequests, forKey: Key.geminiDailyRequests) }
    }

    init() {
        let d = UserDefaults.standard
        self.claudeSessionLimit = Self.load(d, Key.claudeSessionLimit, default: Defaults.claudeSessionLimit)
        self.claudeWeeklyAllLimit = Self.load(d, Key.claudeWeeklyAllLimit, default: Defaults.claudeWeeklyAllLimit)
        self.claudeWeeklySonnetLimit = Self.load(d, Key.claudeWeeklySonnetLimit, default: Defaults.claudeWeeklySonnetLimit)
        self.geminiDailyRequests = Self.load(d, Key.geminiDailyRequests, default: Defaults.geminiDailyRequests)
    }

    func resetClaudeLimits() {
        claudeSessionLimit = Defaults.claudeSessionLimit
        claudeWeeklyAllLimit = Defaults.claudeWeeklyAllLimit
        claudeWeeklySonnetLimit = Defaults.claudeWeeklySonnetLimit
    }

    /// Snapshot the limits as the value type the reader consumes.
    var claudeLimits: ClaudeUsageReader.Limits {
        var limits = ClaudeUsageReader.Limits()
        limits.sessionFiveHourTokens = claudeSessionLimit
        limits.weeklyAllTokens = claudeWeeklyAllLimit
        limits.weeklySonnetTokens = claudeWeeklySonnetLimit
        return limits
    }

    var geminiLimits: GeminiUsageReader.Limits {
        var limits = GeminiUsageReader.Limits()
        limits.dailyRequests = geminiDailyRequests
        return limits
    }

    private static func load(_ d: UserDefaults, _ key: String, default fallback: Double) -> Double {
        guard d.object(forKey: key) != nil else { return fallback }
        return d.double(forKey: key)
    }
}
