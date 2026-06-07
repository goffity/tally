import Foundation

/// Reads Codex CLI session JSONL files under `~/.codex/sessions/`. Codex
/// publishes its plan-limit usage directly inside each `event_msg` of type
/// `token_count`, so we don't have to estimate anything — we just locate the
/// most recent such event across all session files and surface it verbatim.
///
/// Relevant JSONL shape:
/// ```
/// {
///   "timestamp": "2025-11-29T12:12:24.267Z",
///   "type": "event_msg",
///   "payload": {
///     "type": "token_count",
///     "info": {
///       "total_token_usage": { "total_tokens": 6894, ... },
///       "model_context_window": 272000
///     },
///     "rate_limits": {
///       "primary":   { "used_percent": 0.0,  "window_minutes": 300,    "resets_in_seconds": 18000  },
///       "secondary": { "used_percent": 13.0, "window_minutes": 10080, "resets_in_seconds": 168410 }
///     }
///   }
/// }
/// ```
struct CodexUsageReader: Sendable {
    var sessionsRoot: URL = URL(fileURLWithPath: NSString(string: "~/.codex/sessions").expandingTildeInPath)

    func read(now: Date = .now) -> ProviderSummary? {
        guard let latest = locateLatestEvent() else { return nil }

        let primary = makeSnapshot(
            from: latest,
            limit: latest.primary,
            title: "Session",
            subtitleFallback: "5-hour window",
            now: now
        )
        let secondary = makeSnapshot(
            from: latest,
            limit: latest.secondary,
            title: "Weekly",
            subtitleFallback: "7-day window",
            now: now
        )

        let snapshots = [primary, secondary].compactMap { $0 }
        guard !snapshots.isEmpty else { return nil }
        return ProviderSummary(provider: .codex, snapshots: snapshots)
    }

    // MARK: - Snapshot assembly

    private func makeSnapshot(
        from event: LatestEvent,
        limit: RateLimit?,
        title: String,
        subtitleFallback: String,
        now: Date
    ) -> UsageSnapshot? {
        guard let limit else { return nil }

        // Codex only knows its rate-limit state at the moment an event was
        // logged. Project that forward: if the event is older than its window,
        // treat the window as fully reset (0%); otherwise reduce the remaining
        // time by however much has elapsed since the snapshot.
        let elapsed = now.timeIntervalSince(event.timestamp)
        let remaining = max(0, limit.resetsInSeconds - elapsed)
        let isStale = remaining <= 0
        let percent = isStale ? 0 : limit.usedPercent / 100.0
        let resets = isStale ? now : now.addingTimeInterval(remaining)

        let baseSubtitle: String
        switch limit.windowMinutes {
        case ..<60: baseSubtitle = "\(limit.windowMinutes)-minute window"
        case 60..<1440: baseSubtitle = "\(limit.windowMinutes / 60)-hour window"
        default: baseSubtitle = "\(limit.windowMinutes / 1440)-day window"
        }
        let subtitle =
            isStale
            ? "\(baseSubtitle.isEmpty ? subtitleFallback : baseSubtitle) · no recent usage"
            : (baseSubtitle.isEmpty ? subtitleFallback : baseSubtitle)

        let window: UsageWindow =
            limit.windowMinutes >= 1440
            ? .rollingHours(limit.windowMinutes / 60)
            : .rollingHours(max(1, limit.windowMinutes / 60))

        return UsageSnapshot(
            provider: .codex,
            title: title,
            subtitle: subtitle,
            window: window,
            used: 0,  // Codex events don't carry per-window token sums; only %.
            limit: 0,
            unit: .tokens,
            resetsAt: resets,
            directPercent: percent
        )
    }

    // MARK: - File scanning

    private struct RateLimit: Sendable {
        let usedPercent: Double
        let windowMinutes: Int
        let resetsInSeconds: TimeInterval
    }

    private struct LatestEvent: Sendable {
        let timestamp: Date
        let totalTokensThisSession: Double
        let primary: RateLimit?
        let secondary: RateLimit?
    }

    private func locateLatestEvent() -> LatestEvent? {
        let fm = FileManager.default
        guard
            let enumerator = fm.enumerator(
                at: sessionsRoot,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )
        else { return nil }

        // Walk every jsonl, find the newest `token_count` event by event timestamp.
        var newest: LatestEvent?
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            if let event = lastTokenCountEvent(in: url) {
                if newest == nil || event.timestamp > newest!.timestamp {
                    newest = event
                }
            }
        }
        return newest
    }

    private func lastTokenCountEvent(in url: URL) -> LatestEvent? {
        guard let data = try? Data(contentsOf: url),
            let text = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var latest: LatestEvent?
        text.enumerateLines { line, _ in
            guard !line.isEmpty,
                let lineData = line.data(using: .utf8),
                let raw = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                (raw["type"] as? String) == "event_msg",
                let payload = raw["payload"] as? [String: Any],
                (payload["type"] as? String) == "token_count"
            else { return }

            let info = payload["info"] as? [String: Any]
            let totalUsage = info?["total_token_usage"] as? [String: Any]
            let total = (totalUsage?["total_tokens"] as? Double) ?? 0

            let rateLimits = payload["rate_limits"] as? [String: Any]
            let primary = parseRateLimit(rateLimits?["primary"] as? [String: Any])
            let secondary = parseRateLimit(rateLimits?["secondary"] as? [String: Any])

            let tsString = (raw["timestamp"] as? String) ?? ""
            guard let ts = iso.date(from: tsString) else { return }

            // Only keep the last event in this file (line order is chronological).
            latest = LatestEvent(
                timestamp: ts,
                totalTokensThisSession: total,
                primary: primary,
                secondary: secondary
            )
        }
        return latest
    }

    private func parseRateLimit(_ dict: [String: Any]?) -> RateLimit? {
        guard let dict,
            let used = dict["used_percent"] as? Double,
            let window = dict["window_minutes"] as? Int,
            let resets = dict["resets_in_seconds"] as? Double
        else { return nil }
        return RateLimit(
            usedPercent: used,
            windowMinutes: window,
            resetsInSeconds: resets
        )
    }
}
