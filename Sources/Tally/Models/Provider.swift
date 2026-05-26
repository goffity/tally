import Foundation

enum Provider: String, CaseIterable, Identifiable, Hashable {
    case claude
    case gemini
    case codex
    case copilot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .codex: return "Codex"
        case .copilot: return "Copilot"
        }
    }
}
