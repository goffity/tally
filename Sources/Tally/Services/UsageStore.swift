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

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let claude = claudeReader
        let codex = codexReader
        Task {
            let results = await Task.detached(priority: .userInitiated) {
                let optionals: [ProviderSummary?] = [
                    claude.read(),
                    codex.read()
                ]
                return optionals.compactMap { $0 }
            }.value
            self.summaries = results
            self.lastUpdated = Date()
            self.isRefreshing = false
        }
    }
}
