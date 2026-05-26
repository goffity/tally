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
    let limit: Double           // configured cap for this window
    let unit: Unit
    let resetsAt: Date
    let isEstimate: Bool

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
        isEstimate: Bool = false
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
    }

    var percent: Double {
        guard limit > 0 else { return 0 }
        return min(used / limit, 1.0)
    }
}

struct ProviderSummary: Identifiable, Hashable {
    let provider: Provider
    var snapshots: [UsageSnapshot]

    var id: Provider { provider }
}
