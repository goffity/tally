import Foundation
import Observation

@MainActor
@Observable
final class UsageStore {
    /// Tracks the data source actually used for a provider on the last refresh
    /// so the UI can surface "using local logs · API failed" hints.
    enum Source: Sendable, Equatable {
        case api
        case localFallback(reason: String)
        case localOnly

        /// True only for live/cached official endpoint data. Drives the
        /// `official` vs `local` label in the relay payload.
        var isOfficial: Bool {
            if case .api = self { return true }
            return false
        }
    }

    private(set) var summaries: [ProviderSummary] = []
    /// Trailing-7-day per-model split, always counted from local logs — the
    /// official endpoint only reports aggregate percentages per bucket.
    private(set) var claudeModelBreakdown: [ClaudeUsageReader.ModelUsage] = []
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing: Bool = false
    private(set) var sources: [Provider: Source] = [:]
    /// Human-readable outcome of the last relay publish attempt, for the
    /// Settings UI. Never contains tokens or payload data.
    private(set) var relayStatus: String?

    private let claudeLocalReader = ClaudeUsageReader()
    private let claudeApiReader = ClaudeApiUsageReader()
    private let codexReader = CodexUsageReader()
    private let geminiReader = GeminiUsageReader()
    private let copilotReader = CopilotUsageReader()
    private let officialGate = ClaudeOfficialGate()
    private let relayPublisher = RelayPublisher()
    private var lastPublishedKey: String?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        let localClaude = claudeLocalReader
        let apiClaude = claudeApiReader
        let codex = codexReader
        let gemini = geminiReader
        let copilot = copilotReader
        let claudeLimits = settings.claudeLimits
        let geminiLimits = settings.geminiLimits
        let copilotLimits = settings.copilotLimits

        Task {
            // Claude: governed official poll first, fall back to the local log
            // reader on backoff / failure / before the poll window opens.
            let (claudeSummary, claudeSource) = await self.fetchClaude(
                api: apiClaude,
                local: localClaude,
                localLimits: claudeLimits
            )

            // Other providers stay on local-only readers for now.
            let others = await Task.detached(priority: .userInitiated) {
                let optionals: [ProviderSummary?] = [
                    codex.read(),
                    gemini.read(limits: geminiLimits),
                    copilot.read(limits: copilotLimits),
                ]
                return optionals.compactMap { $0 }
            }.value

            // Per-model split comes from local logs even when the official
            // endpoint drives the window bars — the API has no per-model data.
            let breakdown = await Task.detached(priority: .userInitiated) {
                localClaude.modelBreakdown()
            }.value

            var summariesNext: [ProviderSummary] = []
            if let claudeSummary { summariesNext.append(claudeSummary) }
            summariesNext.append(contentsOf: others)

            self.summaries = summariesNext
            self.claudeModelBreakdown = breakdown
            self.sources = [
                .claude: claudeSource,
                .codex: .localOnly,
                .gemini: .localOnly,
                .copilot: .localOnly,
            ]
            self.lastUpdated = Date()
            self.isRefreshing = false

            self.maybePublish(claudeSummary, source: claudeSource)
        }
    }

    // MARK: - Relay publishing (opt-in)

    /// Pushes the Claude snapshot to the relay when the user has enabled it.
    /// No-op (zero outbound) when publishing is off or unconfigured.
    private func maybePublish(_ summary: ProviderSummary?, source: Source) {
        guard settings.relayPublishEnabled else {
            relayStatus = nil
            return
        }
        guard let summary,
            !settings.relayEndpointURL.isEmpty,
            let endpoint = URL(string: settings.relayEndpointURL),
            !settings.relayToken.isEmpty
        else {
            relayStatus = "not configured"
            return
        }

        let capturedAt = source.isOfficial ? (officialGate.lastOfficialAt ?? Date()) : Date()
        guard let payload = RelayPublisher.makePayload(from: summary, source: source, capturedAt: capturedAt)
        else {
            return
        }
        // Skip when nothing meaningful changed — avoids spamming on file-watch churn.
        guard payload.contentKey != lastPublishedKey else { return }

        let publisher = relayPublisher
        let config = RelayPublisher.Config(endpoint: endpoint, token: settings.relayToken)
        let key = payload.contentKey

        Task { [weak self] in
            let result = await publisher.publish(payload, config: config)
            switch result {
            case .success:
                self?.lastPublishedKey = key
                self?.relayStatus = "published ✓"
            case .failure(let err):
                // Retry next refresh even if content is unchanged.
                self?.lastPublishedKey = nil
                self?.relayStatus = "publish failed — \(Self.describePublish(err))"
            }
        }
    }

    private static func describePublish(_ err: RelayPublisher.PublishError) -> String {
        switch err {
        case .encoding: return "encode error"
        case .transport: return "network error"
        case .http(let code): return "relay error \(code)"
        }
    }

    private func fetchClaude(
        api: ClaudeApiUsageReader,
        local: ClaudeUsageReader,
        localLimits: ClaudeUsageReader.Limits
    ) async -> (ProviderSummary?, Source) {
        // Honor the user's configured poll interval before each decision,
        // never faster than the endpoint's per-token floor.
        officialGate.baseInterval = max(
            AppSettings.Defaults.minOfficialPollInterval, settings.officialPollInterval)

        func readLocal() async -> ProviderSummary {
            await Task.detached(priority: .userInitiated) {
                local.read(limits: localLimits)
            }.value
        }

        switch officialGate.decide() {
        case .serveCached(let summary):
            // Still official data, just reused within the throttle window.
            return (summary, .api)

        case .useLocal(let reason):
            return (await readLocal(), .localFallback(reason: reason))

        case .attempt:
            switch await api.read() {
            case .success(let summary):
                officialGate.recordSuccess(summary)
                return (summary, .api)
            case .failure(let err):
                if case .http(429) = err {
                    officialGate.recordRateLimited()
                } else {
                    officialGate.recordTransientFailure()
                }
                return (await readLocal(), .localFallback(reason: Self.describe(err)))
            }
        }
    }

    private static func describe(_ err: ClaudeApiUsageReader.ReadError) -> String {
        switch err {
        case .missingCredentials: return "no Claude Code login found"
        case .unauthorized: return "token expired — re-login claude"
        case .http(let code): return "API error \(code)"
        case .transport: return "network error"
        case .decode: return "unexpected API response"
        }
    }
}
