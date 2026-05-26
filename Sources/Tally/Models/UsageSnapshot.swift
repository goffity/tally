import Foundation

struct UsageSnapshot: Identifiable, Hashable {
    enum Unit: Hashable {
        case tokens
        case requests
    }

    let id: UUID
    let provider: Provider
    let title: String           // e.g. "Session", "Weekly", "Weekly · Sonnet"
    let subtitle: String        // e.g. "5-hour window", "all models"
    let window: UsageWindow
    let used: Double            // tokens or requests consumed in window
    let limit: Double           // configured cap for this window (0 when unknown)
    let unit: Unit
    let resetsAt: Date
    let isEstimate: Bool
    /// When the data source reports a percent directly (e.g. Codex `rate_limits`),
    /// use that instead of computing `used / limit`. Range 0…1.
    let directPercent: Double?

    init(
        id: UUID = UUID(),
        provider: Provider,
        title: String,
        subtitle: String,
        window: UsageWindow,
        used: Double,
        limit: Double,
        unit: Unit = .tokens,
        resetsAt: Date,
        isEstimate: Bool = false,
        directPercent: Double? = nil
    ) {
        self.id = id
        self.provider = provider
        self.title = title
        self.subtitle = subtitle
        self.window = window
        self.used = used
        self.limit = limit
        self.unit = unit
        self.resetsAt = resetsAt
        self.isEstimate = isEstimate
        self.directPercent = directPercent
    }

    var percent: Double {
        if let p = directPercent {
            return min(max(p, 0), 1)
        }
        guard limit > 0 else { return 0 }
        return min(used / limit, 1.0)
    }

    /// True when this snapshot's percent comes from the data source itself
    /// (no synthetic limit needed). Lets the UI render a compact row.
    var hasDirectPercent: Bool { directPercent != nil }
}

struct ProviderSummary: Identifiable, Hashable {
    let provider: Provider
    var snapshots: [UsageSnapshot]

    var id: Provider { provider }
}
