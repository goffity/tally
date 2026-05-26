import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` so the view layer never imports
/// ServiceManagement directly. Reads current status from the system on demand
/// (the user may toggle the entry in System Settings → Login Items behind our
/// back, so we never cache the value).
@MainActor
enum LaunchAtLoginService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .notRegistered: return "Not registered"
        case .enabled: return "Enabled"
        case .requiresApproval: return "Requires approval in System Settings"
        case .notFound: return "App bundle not found"
        @unknown default: return "Unknown"
        }
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Result<Void, Error> {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
