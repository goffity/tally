import Foundation
import Observation

@MainActor
@Observable
final class UsageStore {
    private(set) var summaries: [ProviderSummary] = []
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing: Bool = false

    private let claudeReader = ClaudeUsageReader()

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let reader = claudeReader
        Task {
            let claude = await Task.detached(priority: .userInitiated) {
                reader.read()
            }.value
            self.summaries = [claude]
            self.lastUpdated = Date()
            self.isRefreshing = false
        }
    }
}
