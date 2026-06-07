import Foundation

/// The wire format published to the relay and read by the Scriptable widget.
///
/// Mirrors the project data contract exactly. Window fields are optional: a
/// window with no data is omitted entirely (synthesized `Codable` drops nil
/// optionals), and the widget is expected to handle missing windows. Only
/// derived numbers travel — never any token.
struct RelayPayload: Codable, Equatable {
    struct Window: Codable, Equatable {
        let usedPercentage: Double  // 0–100
        let resetsAt: Int  // Unix epoch seconds

        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case resetsAt = "resets_at"
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let sevenDaySonnet: Window?
    let source: String  // "official" | "local"
    let capturedAt: Int  // Unix epoch seconds

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case source
        case capturedAt = "captured_at"
    }

    /// Identity of the *content* (everything except the capture timestamp), used
    /// to avoid republishing when nothing meaningful changed.
    var contentKey: String {
        func part(_ w: Window?) -> String {
            guard let w else { return "-" }
            return "\(w.usedPercentage):\(w.resetsAt)"
        }
        return [part(fiveHour), part(sevenDay), part(sevenDaySonnet), source].joined(separator: "|")
    }
}
