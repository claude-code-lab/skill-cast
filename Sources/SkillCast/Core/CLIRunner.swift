import Foundation

/// GUI apps have a minimal PATH, so resolve CLIs from an explicit list of directories.
enum CLIRunner {
    enum CLIError: LocalizedError {
        case notFound(String)
        case failed(String, String)

        var errorDescription: String? {
            switch self {
            case .notFound(let name):
                return L10n.t("\(name) コマンドが見つかりません(Homebrew 等でインストールされているか確認してください)", "\(name) command not found (is it installed via Homebrew?)")
            case .failed(let name, let message):
                return L10n.t("\(name) の実行に失敗しました: \(message)", "\(name) failed: \(message)")
            }
        }
    }

    private static let searchDirs = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/Applications/WezTerm.app/Contents/MacOS",
    ]

    static func find(_ name: String) throws -> String {
        for dir in searchDirs {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        throw CLIError.notFound(name)
    }

    /// Runs and returns stdout. Throws with stderr attached on non-zero exit.
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let name = (executable as NSString).lastPathComponent
            throw CLIError.failed(name, err.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return out
    }

    static func tmuxServerRunning() -> Bool {
        guard let tmux = try? find("tmux") else { return false }
        return (try? run(tmux, ["has-session"])) != nil
    }
}
