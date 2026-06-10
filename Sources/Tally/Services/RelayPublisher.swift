import Foundation

/// Publishes the latest Claude usage snapshot to the user's relay endpoint so
/// the iPhone StandBy widget can read it.
///
/// Opt-in: callers must only invoke this when the user has enabled publishing.
/// Only derived numbers leave the machine — percentages, reset times, a source
/// label, and a capture timestamp. Neither the OAuth token nor the relay token
/// is ever placed in the payload or logged.
struct RelayPublisher: Sendable {
    struct Config: Sendable {
        let endpoint: URL
        let token: String
    }

    enum PublishError: Error, Equatable {
        case encoding
        case transport
        case http(Int)
    }

    var session: URLSession = .shared

    // MARK: - Mapping

    /// Builds the relay payload from a Claude summary, or nil when there's no
    /// recognizable window to publish.
    static func makePayload(
        from summary: ProviderSummary,
        source: UsageStore.Source,
        capturedAt: Date
    ) -> RelayPayload? {
        func window(_ title: String) -> RelayPayload.Window? {
            guard let snap = summary.snapshots.first(where: { $0.title == title }) else { return nil }
            let pct = (snap.percent * 1000).rounded() / 10  // 0–100, 1 decimal
            return RelayPayload.Window(
                usedPercentage: pct, resetsAt: Int(snap.resetsAt.timeIntervalSince1970))
        }

        let five = window("Session")
        let seven = window("Weekly")
        let sonnet = window("Weekly · Sonnet")
        guard five != nil || seven != nil || sonnet != nil else { return nil }

        return RelayPayload(
            fiveHour: five,
            sevenDay: seven,
            sevenDaySonnet: sonnet,
            source: source.isOfficial ? "official" : "local",
            capturedAt: Int(capturedAt.timeIntervalSince1970)
        )
    }

    // MARK: - Publish

    func publish(_ payload: RelayPayload, config: Config) async -> Result<Void, PublishError> {
        guard let body = try? JSONEncoder().encode(payload) else {
            return .failure(.encoding)
        }

        var request = URLRequest(url: config.endpoint.appendingPathComponent("usage"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 10

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            return .failure(.transport)
        }
        guard let http = response as? HTTPURLResponse else {
            return .failure(.transport)
        }
        guard (200...299).contains(http.statusCode) else {
            return .failure(.http(http.statusCode))
        }
        return .success(())
    }
}
