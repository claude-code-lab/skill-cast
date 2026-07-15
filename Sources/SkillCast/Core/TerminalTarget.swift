import AppKit

enum TerminalTarget: String, CaseIterable, Codable, Identifiable {
    case ghostty
    case iterm2
    case terminal
    case wezterm
    case tmux

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ghostty: return "Ghostty"
        case .iterm2: return "iTerm2"
        case .terminal: return "Terminal"
        case .wezterm: return "WezTerm"
        case .tmux: return "tmux"
        }
    }

    /// nil for tmux, since it is not an app
    var bundleID: String? {
        switch self {
        case .ghostty: return "com.mitchellh.ghostty"
        case .iterm2: return "com.googlecode.iterm2"
        case .terminal: return "com.apple.Terminal"
        case .wezterm: return "com.github.wez.wezterm"
        case .tmux: return nil
        }
    }

    static func from(bundleID: String?) -> TerminalTarget? {
        guard let bundleID else { return nil }
        return allCases.first { $0.bundleID == bundleID }
    }

    var isRunning: Bool {
        switch self {
        case .tmux:
            return CLIRunner.tmuxServerRunning()
        default:
            guard let bundleID else { return false }
            return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        }
    }

    var notRunningMessage: String {
        switch self {
        case .tmux: return L10n.t("tmux サーバが起動していません(セッションがあるか確認してください)", "tmux server is not running (check that a session exists)")
        default: return L10n.t("\(displayName) が起動していません", "\(displayName) is not running")
        }
    }
}
