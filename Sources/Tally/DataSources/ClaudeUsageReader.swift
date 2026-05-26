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
    /// Cost-weighted token limits per window. Defaults mirror Claude Max plan
    /// observations; users can tune them in Settings.
    struct Limits: Sendable {
        var sessionFiveHourTokens: Double = 130_000_000
        var weeklyAllTokens: Double = 400_000_000
        var weeklySonnetTokens: Double = 300_000_000
    }

    /// Anthropic pricing-derived weights for converting raw token counts
    /// into a single comparable "cost unit" that mirrors what counts
    /// toward Claude Code's session/weekly plan limits.
    private static let inputWeight: Double = 1.0
    private static let cacheCreateWeight: Double = 1.25
    private static let cacheReadWeight: Double = 0.1
    private static let outputWeight: Double = 5.0

    var projectsRoot: URL = URL(fileURLWithPath: NSString(string: "~/.claude/projects").expandingTildeInPath)

    func read(limits: Limits, now: Date = .now) -> ProviderSummary {
        let events = loadEvents()

        let sessionStart = now.addingTimeInterval(-5 * 3600)
        let weekStart = now.addingTimeInterval(-7 * 24 * 3600)

        var sessionTokens: Double = 0
        var weeklyAll: Double = 0
        var weeklySonnet: Double = 0
        var oldestInSession: Date?
        var oldestInWeek: Date?

        for ev in events {
            if ev.timestamp >= sessionStart {
                sessionTokens += ev.totalTokens
                if oldestInSession == nil || ev.timestamp < oldestInSession! {
                    oldestInSession = ev.timestamp
                }
            }
            if ev.timestamp >= weekStart {
                weeklyAll += ev.totalTokens
                if oldestInWeek == nil || ev.timestamp < oldestInWeek! {
                    oldestInWeek = ev.timestamp
                }
                if ev.model.lowercased().contains("sonnet") {
                    weeklySonnet += ev.totalTokens
                }
            }
        }

        // Rolling windows: reset is when the oldest in-window event drops off.
        let sessionReset = (oldestInSession ?? now).addingTimeInterval(5 * 3600)
        let weeklyReset = (oldestInWeek ?? now).addingTimeInterval(7 * 24 * 3600)

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
                window: .rollingHours(7 * 24),
                used: weeklyAll,
                limit: limits.weeklyAllTokens,
                resetsAt: weeklyReset
            ),
            UsageSnapshot(
                provider: .claude,
                title: "Weekly · Sonnet",
                subtitle: "Sonnet only",
                window: .rollingHours(7 * 24),
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
            let total = inTok * Self.inputWeight
                + cacheCreate * Self.cacheCreateWeight
                + cacheRead * Self.cacheReadWeight
                + outTok * Self.outputWeight
            guard total > 0 else { return }

            let model = (message["model"] as? String) ?? (raw["model"] as? String) ?? ""

            let tsString = (raw["timestamp"] as? String) ?? (message["timestamp"] as? String) ?? ""
            guard let ts = iso.date(from: tsString) else { return }

            out.append(AssistantEvent(timestamp: ts, model: model, totalTokens: total))
        }
        return out
    }
}
