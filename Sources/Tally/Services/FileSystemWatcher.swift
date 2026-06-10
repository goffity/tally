import CoreServices
import Foundation

/// Lightweight FSEvents wrapper. Calls `onChange` (on the main queue) whenever
/// any file under the watched paths is created, modified, or removed. Callers
/// are responsible for debouncing — typically via a Timer on the receiving side.
@MainActor
final class FileSystemWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void
    private let paths: [String]

    init(paths: [String], onChange: @escaping () -> Void) {
        self.paths = paths.filter { FileManager.default.fileExists(atPath: $0) }
        self.onChange = onChange
    }

    func start() {
        guard stream == nil, !paths.isEmpty else { return }

        let info = Unmanaged.passUnretained(self).toOpaque()
        var context = FSEventStreamContext(
            version: 0,
            info: info,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
            guard let clientCallBackInfo else { return }
            let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            DispatchQueue.main.async {
                watcher.onChange()
            }
        }

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            /* latency */ 1.0,
            flags
        )

        if let stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    // Intentional: no deinit cleanup. Swift 6 forbids touching MainActor
    // state from a nonisolated deinit, and our only owner (RefreshScheduler)
    // calls `stop()` explicitly on tear-down.
}
