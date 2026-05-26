import Foundation

/// Reads Claude Code session JSONL files under `~/.claude/projects/` and aggregates
/// token usage into the windows shown in the menu bar (5h session, weekly, weekly Sonnet).
///
/// JSONL line shape (assistant messages only carry `usage`):
/// ```
/// {
///   "type": "assistant",
///   "timestamp": "2026-04-16T05:40:16.327Z",
///   "message": {
///     "model": "claude-opus-4-6[1m]",
///     "usage": {
///       "input_tokens": 3,
///       "cache_creation_input_tokens": 13922,
///       "cache_read_input_tokens": 0,
///       "output_tokens": 116
///     }
///   }
/// }
/// ```
struct ClaudeUsageReader: Sendable {
    /// Default limits — Claude Pro estimates. Override via Settings later.
    struct Limits: Sendable {
        var sessionFiveHourTokens: Double = 220_000
        var weeklyAllTokens: Double = 5_500_000
        var weeklySonnetTokens: Double = 4_400_000
    }

    var limits = Limits()
    var projectsRoot: URL = URL(fileURLWithPath: NSString(string: "~/.claude/projects").expandingTildeInPath)

    func read(now: Date = .now) -> ProviderSummary {
        let events = loadEvents()

        let sessionStart = UsageWindow.rollingHours(5).windowStart(now: now)
        let weekStart = UsageWindow.calendarWeek.windowStart(now: now)

        var sessionTokens: Double = 0
        var weeklyAll: Double = 0
        var weeklySonnet: Double = 0
        var oldestInSession: Date?

        for ev in events {
            if ev.timestamp >= sessionStart {
                sessionTokens += ev.totalTokens
                if oldestInSession == nil || ev.timestamp < oldestInSession! {
                    oldestInSession = ev.timestamp
                }
            }
            if ev.timestamp >= weekStart {
                weeklyAll += ev.totalTokens
                if ev.model.lowercased().contains("sonnet") {
                    weeklySonnet += ev.totalTokens
                }
            }
        }

        // Rolling 5h: reset is 5h after the oldest in-window event (when it "drops off").
        let sessionReset = (oldestInSession ?? now).addingTimeInterval(5 * 3600)
        let weeklyReset = UsageWindow.calendarWeek.resetsAt(now: now)

        let snapshots: [UsageSnapshot] = [
            UsageSnapshot(
                provider: .claude,
                title: "Session",
                subtitle: "5-hour window",
                window: .rollingHours(5),
                used: sessionTokens,
                limit: limits.sessionFiveHourTokens,
                resetsAt: sessionReset
            ),
            UsageSnapshot(
                provider: .claude,
                title: "Weekly",
                subtitle: "all models",
                window: .calendarWeek,
                used: weeklyAll,
                limit: limits.weeklyAllTokens,
                resetsAt: weeklyReset
            ),
            UsageSnapshot(
                provider: .claude,
                title: "Weekly · Sonnet",
                subtitle: "Sonnet only",
                window: .calendarWeek,
                used: weeklySonnet,
                limit: limits.weeklySonnetTokens,
                resetsAt: weeklyReset
            )
        ]
        return ProviderSummary(provider: .claude, snapshots: snapshots)
    }

    // MARK: - JSONL parsing

    private struct AssistantEvent {
        let timestamp: Date
        let model: String
        let totalTokens: Double
    }

    private func loadEvents() -> [AssistantEvent] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: projectsRoot, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }
        var events: [AssistantEvent] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            events.append(contentsOf: parse(file: url))
        }
        return events
    }

    private func parse(file url: URL) -> [AssistantEvent] {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var out: [AssistantEvent] = []
        out.reserveCapacity(64)

        text.enumerateLines { line, _ in
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { return }

            guard (raw["type"] as? String) == "assistant" else { return }
            guard let message = raw["message"] as? [String: Any] else { return }
            guard let usage = message["usage"] as? [String: Any] else { return }

            let inTok = (usage["input_tokens"] as? Double) ?? 0
            let cacheCreate = (usage["cache_creation_input_tokens"] as? Double) ?? 0
            let cacheRead = (usage["cache_read_input_tokens"] as? Double) ?? 0
            let outTok = (usage["output_tokens"] as? Double) ?? 0
            let total = inTok + cacheCreate + cacheRead + outTok
            guard total > 0 else { return }

            let model = (message["model"] as? String) ?? (raw["model"] as? String) ?? ""

            let tsString = (raw["timestamp"] as? String) ?? (message["timestamp"] as? String) ?? ""
            guard let ts = iso.date(from: tsString) else { return }

            out.append(AssistantEvent(timestamp: ts, model: model, totalTokens: total))
        }
        return out
    }
}
