import Foundation

/// Reads Gemini CLI session files under `~/.gemini/tmp/<project-hash>/chats/`.
///
/// Gemini's local logs don't carry token counts, only message arrays with
/// timestamps. We approximate plan usage by counting user-initiated messages
/// in the last 24 hours and comparing to a configurable daily quota
/// (defaults to 1000 — the free tier's documented daily request limit).
///
/// Sample message:
/// ```
/// { "id": "...", "timestamp": "2025-12-03T18:07:39.515Z", "type": "user", "content": "..." }
/// ```
struct GeminiUsageReader: Sendable {
    struct Limits: Sendable {
        var dailyRequests: Double = 1000
    }

    var sessionsRoot: URL = URL(fileURLWithPath: NSString(string: "~/.gemini/tmp").expandingTildeInPath)

    func read(limits: Limits, now: Date = .now) -> ProviderSummary? {
        guard FileManager.default.fileExists(atPath: sessionsRoot.path) else { return nil }

        let dayStart = now.addingTimeInterval(-24 * 3600)
        let userMessagesInWindow = countUserMessages(since: dayStart)

        let calendar = Calendar.current
        let nextMidnight =
            calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            ) ?? now

        let snapshot = UsageSnapshot(
            provider: .gemini,
            title: "Daily",
            subtitle: "rolling 24-hour window",
            window: .rollingHours(24),
            used: Double(userMessagesInWindow),
            limit: limits.dailyRequests,
            unit: .requests,
            resetsAt: nextMidnight,
            isEstimate: true
        )
        return ProviderSummary(provider: .gemini, snapshots: [snapshot])
    }

    private func countUserMessages(since cutoff: Date) -> Int {
        let fm = FileManager.default
        guard
            let enumerator = fm.enumerator(at: sessionsRoot, includingPropertiesForKeys: [.isRegularFileKey])
        else {
            return 0
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var total = 0
        for case let url as URL in enumerator
        where url.lastPathComponent.hasPrefix("session-") && url.pathExtension == "json" {
            total += countUserMessages(in: url, since: cutoff, iso: iso)
        }
        return total
    }

    private func countUserMessages(in url: URL, since cutoff: Date, iso: ISO8601DateFormatter) -> Int {
        guard let data = try? Data(contentsOf: url),
            let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let messages = raw["messages"] as? [[String: Any]]
        else {
            return 0
        }

        var count = 0
        for message in messages {
            guard (message["type"] as? String) == "user",
                let tsString = message["timestamp"] as? String,
                let ts = iso.date(from: tsString),
                ts >= cutoff
            else { continue }
            count += 1
        }
        return count
    }
}
