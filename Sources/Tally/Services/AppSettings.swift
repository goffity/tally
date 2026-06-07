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
        static let copilotMonthlyPremiumRequests: Double = 300
        /// Minimum seconds between official `/usage` polls. Per the endpoint's
        /// per-token rate limit, faster than this risks self-inflicted 429s.
        static let officialPollInterval: Double = 180
        /// Hard floor; the UI must not allow polling faster than this.
        static let minOfficialPollInterval: Double = 180
    }

    private enum Key {
        static let claudeSessionLimit = "claude.sessionLimit"
        static let claudeWeeklyAllLimit = "claude.weeklyAllLimit"
        static let claudeWeeklySonnetLimit = "claude.weeklySonnetLimit"
        static let geminiDailyRequests = "gemini.dailyRequests"
        static let copilotMonthlyPremiumRequests = "copilot.monthlyPremiumRequests"
        static let officialPollInterval = "claude.officialPollInterval"
        static let relayEndpointURL = "relay.endpointURL"
        static let relayPublishEnabled = "relay.publishEnabled"
    }

    /// Keychain-backed store for the relay token — kept out of UserDefaults.
    private let relaySecrets = RelaySecretStore()

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

    var copilotMonthlyPremiumRequests: Double {
        didSet {
            UserDefaults.standard.set(
                copilotMonthlyPremiumRequests, forKey: Key.copilotMonthlyPremiumRequests)
        }
    }

    // MARK: - Relay / official poll

    /// Seconds between official `/usage` polls. Clamped to the floor at the point
    /// of use (see `UsageStore`) and by the Settings UI.
    var officialPollInterval: Double {
        didSet { UserDefaults.standard.set(officialPollInterval, forKey: Key.officialPollInterval) }
    }

    /// Relay endpoint base URL (e.g. `https://codey-relay.example.workers.dev`).
    var relayEndpointURL: String {
        didSet { UserDefaults.standard.set(relayEndpointURL, forKey: Key.relayEndpointURL) }
    }

    /// Outbound publishing is opt-in and OFF by default — tally stays local-first
    /// until the user explicitly turns this on.
    var relayPublishEnabled: Bool {
        didSet { UserDefaults.standard.set(relayPublishEnabled, forKey: Key.relayPublishEnabled) }
    }

    /// Relay auth token. Backed by the Keychain, never UserDefaults.
    var relayToken: String {
        didSet { relaySecrets.save(relayToken) }
    }

    init() {
        let d = UserDefaults.standard
        self.claudeSessionLimit = Self.load(d, Key.claudeSessionLimit, default: Defaults.claudeSessionLimit)
        self.claudeWeeklyAllLimit = Self.load(
            d, Key.claudeWeeklyAllLimit, default: Defaults.claudeWeeklyAllLimit)
        self.claudeWeeklySonnetLimit = Self.load(
            d, Key.claudeWeeklySonnetLimit, default: Defaults.claudeWeeklySonnetLimit)
        self.geminiDailyRequests = Self.load(
            d, Key.geminiDailyRequests, default: Defaults.geminiDailyRequests)
        self.copilotMonthlyPremiumRequests = Self.load(
            d, Key.copilotMonthlyPremiumRequests, default: Defaults.copilotMonthlyPremiumRequests)
        self.officialPollInterval = Self.load(
            d, Key.officialPollInterval, default: Defaults.officialPollInterval)
        self.relayEndpointURL = d.string(forKey: Key.relayEndpointURL) ?? ""
        self.relayPublishEnabled = d.bool(forKey: Key.relayPublishEnabled)
        // didSet does not fire during init, so this read-back won't clobber the
        // Keychain with an empty value.
        self.relayToken = RelaySecretStore().read() ?? ""
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

    var copilotLimits: CopilotUsageReader.Limits {
        var limits = CopilotUsageReader.Limits()
        limits.monthlyPremiumRequests = copilotMonthlyPremiumRequests
        return limits
    }

    private static func load(_ d: UserDefaults, _ key: String, default fallback: Double) -> Double {
        guard d.object(forKey: key) != nil else { return fallback }
        return d.double(forKey: key)
    }
}
