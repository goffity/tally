import Foundation
import Observation

@MainActor
@Observable
final class UsageStore {
    private(set) var summaries: [ProviderSummary] = []
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing: Bool = false

    private let claudeReader = ClaudeUsageReader()
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
        let claude = claudeReader
        let codex = codexReader
        let gemini = geminiReader
        let copilot = copilotReader
        let claudeLimits = settings.claudeLimits
        let geminiLimits = settings.geminiLimits
        let copilotLimits = settings.copilotLimits
        Task {
            let results = await Task.detached(priority: .userInitiated) {
                let optionals: [ProviderSummary?] = [
                    claude.read(limits: claudeLimits),
                    codex.read(),
                    gemini.read(limits: geminiLimits),
                    copilot.read(limits: copilotLimits)
                ]
                return optionals.compactMap { $0 }
            }.value
            self.summaries = results
            self.lastUpdated = Date()
            self.isRefreshing = false
        }
    }
}
