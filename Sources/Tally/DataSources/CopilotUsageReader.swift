import Foundation

/// Reads GitHub Copilot CLI session events under
/// `~/.copilot/session-state/<session-id>/events.jsonl`. Each session writes a
/// single `session.shutdown` event on clean exit that rolls up the session's
/// total premium-request count — exactly what Copilot Pro caps at 300/month.
///
/// Caveat: in-flight sessions that haven't shut down yet are not counted.
/// For a tally that doesn't break apart by model, this is usually close
/// enough since premium requests are debited on use, not on session close.
struct CopilotUsageReader: Sendable {
    struct Limits: Sendable {
        var monthlyPremiumRequests: Double = 300
    }

    var sessionStateRoot: URL = URL(fileURLWithPath: NSString(string: "~/.copilot/session-state").expandingTildeInPath)

    func read(limits: Limits, now: Date = .now) -> ProviderSummary? {
        guard FileManager.default.fileExists(atPath: sessionStateRoot.path) else { return nil }

        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now

        let used = sumPremiumRequests(since: monthStart)

        let snapshot = UsageSnapshot(
            provider: .copilot,
            title: "Monthly",
            subtitle: "premium requests this month",
            window: .calendarMonth,
            used: Double(used),
            limit: limits.monthlyPremiumRequests,
            unit: .requests,
            resetsAt: nextMonthStart,
            isEstimate: true
        )
        return ProviderSummary(provider: .copilot, snapshots: [snapshot])
    }

    private func sumPremiumRequests(since cutoff: Date) -> Int {
        let fm = FileManager.default
        guard let subdirs = try? fm.contentsOfDirectory(at: sessionStateRoot, includingPropertiesForKeys: nil) else {
            return 0
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var total = 0
        for dir in subdirs where dir.hasDirectoryPath {
            let eventsFile = dir.appendingPathComponent("events.jsonl")
            total += premiumRequests(in: eventsFile, since: cutoff, iso: iso)
        }
        return total
    }

    private func premiumRequests(in url: URL, since cutoff: Date, iso: ISO8601DateFormatter) -> Int {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return 0
        }

        var total = 0
        text.enumerateLines { line, _ in
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  (raw["type"] as? String) == "session.shutdown"
            else { return }

            let tsString = (raw["timestamp"] as? String) ?? ""
            guard let ts = iso.date(from: tsString), ts >= cutoff else { return }

            guard let payload = raw["data"] as? [String: Any] else { return }
            if let premium = payload["totalPremiumRequests"] as? Int {
                total += premium
            } else if let premium = payload["totalPremiumRequests"] as? Double {
                total += Int(premium)
            }
        }
        return total
    }
}
