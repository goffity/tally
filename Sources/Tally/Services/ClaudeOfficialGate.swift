import Foundation

/// Rate-limit governor for Anthropic's official `/usage` endpoint.
///
/// Two responsibilities:
///
/// 1. **Throttle** — official network calls happen at most once per
///    `baseInterval` (≥ 180s per access token), *decoupled* from how often the
///    UI refreshes. File-watch events can fire many times a minute; they must
///    not each turn into a network call or we rate-limit ourselves.
/// 2. **Backoff** — this endpoint 429s easily, can stay limited for a whole
///    session, and sends no `Retry-After`. On 429 we back off exponentially
///    (`baseInterval`, ×2, ×4, …) capped at `maxBackoff`, staying on the local
///    fallback in the meantime.
///
/// Successful reads are cached so refreshes *inside* the throttle window reuse
/// the last official snapshot (usage only moves with activity, so it's stable).
@MainActor
final class ClaudeOfficialGate {
    enum Decision: Equatable {
        /// Eligible to hit the network now.
        case attempt
        /// Inside throttle window with cached official data — reuse it.
        case serveCached(ProviderSummary)
        /// Backing off, or no cache yet — use the local reader instead.
        case useLocal(reason: String)
    }

    /// Minimum seconds between official calls. Synced from user settings.
    var baseInterval: TimeInterval
    private let maxBackoff: TimeInterval

    private var nextEligible: Date = .distantPast
    private var backoffStep: Int = 0
    private(set) var lastOfficial: ProviderSummary?
    private(set) var lastOfficialAt: Date?

    init(baseInterval: TimeInterval = 180, maxBackoff: TimeInterval = 30 * 60) {
        self.baseInterval = baseInterval
        self.maxBackoff = maxBackoff
    }

    private var isBackingOff: Bool { backoffStep > 0 }

    func decide(now: Date = .now) -> Decision {
        if now >= nextEligible {
            return .attempt
        }
        if isBackingOff {
            return .useLocal(reason: "rate limited — backing off")
        }
        if let cached = lastOfficial {
            return .serveCached(cached)
        }
        return .useLocal(reason: "waiting for official poll window")
    }

    func recordSuccess(_ summary: ProviderSummary, now: Date = .now) {
        backoffStep = 0
        lastOfficial = summary
        lastOfficialAt = now
        nextEligible = now.addingTimeInterval(baseInterval)
    }

    /// 429 — escalate the exponential backoff ladder and stay off the endpoint.
    func recordRateLimited(now: Date = .now) {
        backoffStep += 1
        let factor = pow(2.0, Double(backoffStep - 1))
        let delay = min(baseInterval * factor, maxBackoff)
        nextEligible = now.addingTimeInterval(delay)
    }

    /// Network / decode / auth failures: retry next interval without escalating
    /// the 429 ladder (these aren't rate-limit signals).
    func recordTransientFailure(now: Date = .now) {
        nextEligible = now.addingTimeInterval(baseInterval)
    }
}
