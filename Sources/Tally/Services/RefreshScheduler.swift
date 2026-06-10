import Foundation

/// Drives `UsageStore.refresh()` from two sources:
///
/// 1. **Filesystem events** — fires within `debounceDelay` of any change under
///    the providers' log roots. Keeps the menu in sync in near-realtime while
///    a session is active.
/// 2. **Safety poll** — every `safetyInterval` (default 5 min) the store
///    refreshes regardless, so rolling-window reset countdowns keep ticking
///    even when no new data is being written.
@MainActor
final class RefreshScheduler {
    private weak var store: UsageStore?
    private let debounceDelay: TimeInterval
    private let safetyInterval: TimeInterval

    private var watcher: FileSystemWatcher?
    private var safetyTimer: Timer?
    private var debounceTimer: Timer?

    init(
        store: UsageStore,
        debounceDelay: TimeInterval = 1.0,
        safetyInterval: TimeInterval = 5 * 60
    ) {
        self.store = store
        self.debounceDelay = debounceDelay
        self.safetyInterval = safetyInterval
    }

    func start() {
        stop()

        // Initial paint.
        store?.refresh()

        let home = NSString(string: "~").expandingTildeInPath
        let watchedPaths = [
            "\(home)/.claude/projects",
            "\(home)/.codex/sessions",
            "\(home)/.gemini/tmp",
        ]

        watcher = FileSystemWatcher(paths: watchedPaths) { [weak self] in
            self?.scheduleDebouncedRefresh()
        }
        watcher?.start()

        let safety = Timer.scheduledTimer(withTimeInterval: safetyInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.store?.refresh() }
        }
        RunLoop.main.add(safety, forMode: .common)
        safetyTimer = safety
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        safetyTimer?.invalidate()
        safetyTimer = nil
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    private func scheduleDebouncedRefresh() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) {
            [weak self] _ in
            Task { @MainActor in self?.store?.refresh() }
        }
    }
}
