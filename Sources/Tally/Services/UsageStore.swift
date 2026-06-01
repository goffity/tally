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
    }

    private(set) var summaries: [ProviderSummary] = []
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing: Bool = false
    private(set) var sources: [Provider: Source] = [:]

    private let claudeLocalReader = ClaudeUsageReader()
    private let claudeApiReader = ClaudeApiUsageReader()
    private let codexReader = CodexUsageReader()
    private let geminiReader = GeminiUsageReader()
    private let copilotReader = CopilotUsageReader()
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
            // Claude: API first, fall back to the local log reader on any failure.
            let (claudeSummary, claudeSource) = await Self.fetchClaude(
                api: apiClaude,
                local: localClaude,
                localLimits: claudeLimits
            )

            // Other providers stay on local-only readers for now.
            let others = await Task.detached(priority: .userInitiated) {
                let optionals: [ProviderSummary?] = [
                    codex.read(),
                    gemini.read(limits: geminiLimits),
                    copilot.read(limits: copilotLimits)
                ]
                return optionals.compactMap { $0 }
            }.value

            var summariesNext: [ProviderSummary] = []
            if let claudeSummary { summariesNext.append(claudeSummary) }
            summariesNext.append(contentsOf: others)

            self.summaries = summariesNext
            self.sources = [
                .claude: claudeSource,
                .codex: .localOnly,
                .gemini: .localOnly,
                .copilot: .localOnly
            ]
            self.lastUpdated = Date()
            self.isRefreshing = false
        }
    }

    private static func fetchClaude(
        api: ClaudeApiUsageReader,
        local: ClaudeUsageReader,
        localLimits: ClaudeUsageReader.Limits
    ) async -> (ProviderSummary?, Source) {
        let apiResult = await api.read()
        switch apiResult {
        case .success(let summary):
            return (summary, .api)
        case .failure(let err):
            let reason = Self.describe(err)
            let fallback = await Task.detached(priority: .userInitiated) {
                local.read(limits: localLimits)
            }.value
            return (fallback, .localFallback(reason: reason))
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
