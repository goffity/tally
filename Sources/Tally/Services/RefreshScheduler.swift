import Foundation

@MainActor
final class RefreshScheduler {
    private weak var store: UsageStore?
    private var timer: Timer?
    private let interval: TimeInterval

    init(store: UsageStore, interval: TimeInterval = 30) {
        self.store = store
        self.interval = interval
    }

    func start() {
        stop()
        store?.refresh()
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.store?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
