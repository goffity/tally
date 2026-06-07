import Foundation

/// Fetches Claude plan usage from Anthropic's undocumented
/// `GET https://api.anthropic.com/api/oauth/usage` endpoint — the same
/// data source the Claude Code CLI uses to render `/usage`.
///
/// Response shape (subset we parse):
/// ```
/// {
///   "five_hour":        { "utilization": 6.0, "resets_at": "2026-06-01T14:00:00Z" },
///   "seven_day":        { "utilization": 4.0, "resets_at": "2026-06-05T08:00:00Z" },
///   "seven_day_sonnet": { "utilization": 0.0, "resets_at": null },
///   "extra_usage":      { "is_enabled": true, "monthly_limit": 20000, "used_credits": 0.0, "currency": "USD" }
/// }
/// ```
///
/// `utilization` is already a percent (0–100) — no calibration needed.
struct ClaudeApiUsageReader: Sendable {
    enum ReadError: Error, Equatable {
        case missingCredentials
        case unauthorized  // 401 — token expired/invalid; need refresh
        case http(Int)
        case transport
        case decode
    }

    var credentials: ClaudeCredentialsStore = ClaudeCredentialsStore()
    var endpoint: URL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    var session: URLSession = .shared

    func read() async -> Result<ProviderSummary, ReadError> {
        guard let creds = credentials.load() else {
            return .failure(.missingCredentials)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Mandatory: without a claude-code User-Agent the endpoint drops us into
        // a harsh 429 bucket immediately. Version is resolved from the installed CLI.
        request.setValue(ClaudeCodeEnvironment.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(.transport)
        }

        guard let http = response as? HTTPURLResponse else {
            return .failure(.transport)
        }
        switch http.statusCode {
        case 200:
            break
        case 401:
            return .failure(.unauthorized)
        default:
            return .failure(.http(http.statusCode))
        }

        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.decode)
        }

        let snapshots = buildSnapshots(from: raw)
        guard !snapshots.isEmpty else {
            return .failure(.decode)
        }
        return .success(ProviderSummary(provider: .claude, snapshots: snapshots))
    }

    // MARK: - Mapping

    private func buildSnapshots(from raw: [String: Any]) -> [UsageSnapshot] {
        var out: [UsageSnapshot] = []

        if let snap = mapWindow(
            raw[Key.fiveHour] as? [String: Any],
            title: "Session",
            subtitle: "5-hour window"
        ) {
            out.append(snap)
        }
        if let snap = mapWindow(
            raw[Key.sevenDay] as? [String: Any],
            title: "Weekly",
            subtitle: "all models · 7-day window"
        ) {
            out.append(snap)
        }
        if let snap = mapWindow(
            raw[Key.sevenDaySonnet] as? [String: Any],
            title: "Weekly · Sonnet",
            subtitle: "Sonnet only · 7-day window"
        ) {
            out.append(snap)
        }
        if let extra = mapOverage(raw[Key.extraUsage] as? [String: Any]) {
            out.append(extra)
        }
        return out
    }

    private func mapWindow(
        _ dict: [String: Any]?,
        title: String,
        subtitle: String
    ) -> UsageSnapshot? {
        guard let dict, let utilization = dict["utilization"] as? Double else { return nil }
        let resets = parseDate(dict["resets_at"] as? String) ?? Date()

        return UsageSnapshot(
            provider: .claude,
            title: title,
            subtitle: subtitle,
            window: .rollingHours(title == "Session" ? 5 : 7 * 24),
            used: 0,  // API gives us the % directly
            limit: 0,
            unit: .tokens,
            resetsAt: resets,
            directPercent: utilization / 100.0
        )
    }

    private func mapOverage(_ dict: [String: Any]?) -> UsageSnapshot? {
        guard let dict,
            (dict["is_enabled"] as? Bool) == true,
            let monthlyLimit = dict["monthly_limit"] as? Double,
            monthlyLimit > 0
        else { return nil }

        let used = (dict["used_credits"] as? Double) ?? 0
        let currency = (dict["currency"] as? String) ?? "USD"

        let calendar = Calendar.current
        let monthStart =
            calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? Date()

        return UsageSnapshot(
            provider: .claude,
            title: "Overage",
            subtitle: "extra credits · \(currency)",
            window: .calendarMonth,
            used: used,
            limit: monthlyLimit,
            unit: .requests,  // shows as plain number with comma separator
            resetsAt: nextMonth,
            isEstimate: false
        )
    }

    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        // The endpoint returns microsecond precision (6 fractional digits), which
        // ISO8601DateFormatter can't parse — it only handles 3. Normalize and retry.
        if let normalized = Self.normalizeFractionalSeconds(s) {
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return iso.date(from: normalized)
        }
        return nil
    }

    /// Truncates over-long fractional seconds to 3 digits, e.g.
    /// `…:00.812095+00:00` -> `…:00.812+00:00`. Returns nil when there's nothing
    /// to normalize.
    private static func normalizeFractionalSeconds(_ s: String) -> String? {
        guard let dot = s.firstIndex(of: ".") else { return nil }
        var end = s.index(after: dot)
        var digits = 0
        while end < s.endIndex, s[end].isNumber {
            end = s.index(after: end)
            digits += 1
        }
        guard digits > 3 else { return nil }
        let keep = s.index(dot, offsetBy: 4)  // dot + 3 digits
        return String(s[s.startIndex..<keep]) + String(s[end...])
    }

    private enum Key {
        static let fiveHour = "five_hour"
        static let sevenDay = "seven_day"
        static let sevenDaySonnet = "seven_day_sonnet"
        static let extraUsage = "extra_usage"
    }
}
