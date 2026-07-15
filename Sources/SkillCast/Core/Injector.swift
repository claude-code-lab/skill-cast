import AppKit

enum InjectError: LocalizedError {
    case notRunning(String)
    case scriptFailed(String)
    case notTrusted
    case activateFailed(String)

    var errorDescription: String? {
        switch self {
        case .notRunning(let message):
            return message
        case .scriptFailed(let msg):
            return L10n.t("送信に失敗しました: \(msg)", "Failed to send: \(msg)")
        case .notTrusted:
            return L10n.t("アクセシビリティ権限がありません。システム設定 > プライバシーとセキュリティ > アクセシビリティ で SkillCast を ON にしてください", "Accessibility permission is missing. Enable SkillCast in System Settings > Privacy & Security > Accessibility")
        case .activateFailed(let name):
            return L10n.t("\(name) を前面にできませんでした", "Could not bring \(name) to front")
        }
    }
}

enum Injector {
    /// Builds a one-line prompt string from the selected skills. Newlines are stripped since they'd send early.
    static func buildPrompt(template: String, skills: [Skill]) -> String {
        let paths = skills.map(\.path).joined(separator: " ")
        return template
            .replacingOccurrences(of: "{paths}", with: paths)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    static func inject(prompt: String, into target: TerminalTarget) throws {
        guard target.isRunning else {
            throw InjectError.notRunning(target.notRunningMessage)
        }
        switch target {
        case .wezterm:
            // Send directly via the official CLI (no permission/clipboard needed).
            // Send the body in paste mode, then Enter with --no-paste to confirm it
            let wezterm = try CLIRunner.find("wezterm")
            let paneID = try weztermFocusedPaneID(wezterm)
            try CLIRunner.run(wezterm, ["cli", "send-text", "--pane-id", paneID, prompt])
            try CLIRunner.run(wezterm, ["cli", "send-text", "--pane-id", paneID, "--no-paste", "\r"])
        case .tmux:
            // Send to the active pane of the most recently used attached client
            let tmux = try CLIRunner.find("tmux")
            let session = try tmuxActiveSession(tmux)
            try CLIRunner.run(tmux, ["send-keys", "-t", session, "-l", prompt])
            try CLIRunner.run(tmux, ["send-keys", "-t", session, "Enter"])
        case .iterm2:
            // AppleScript write text (includes Enter, the most robust option)
            try runAppleScript("""
            tell application "iTerm2"
                tell current session of current window to write text "\(escape(prompt))"
            end tell
            """)
        case .ghostty, .terminal:
            // Activate the target and type directly via CGEvent Unicode string input
            // (no clipboard/⌘V needed; non-ASCII is not garbled)
            guard AXIsProcessTrusted() else {
                // If not yet registered with TCC, show the system permission dialog and also surface an error
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
                throw InjectError.notTrusted
            }

            guard let bundleID = target.bundleID else { throw InjectError.notRunning(target.notRunningMessage) }
            try activateAndWait(bundleID: bundleID, name: target.displayName)

            typeUnicode(prompt)
            usleep(300_000)
            postKey(36, flags: [])            // Enter (kVK_Return)
        }
    }

    /// Types an arbitrary string directly via CGEvent's keyboardSetUnicodeString
    /// (independent of virtual key codes, IME, or keyboard layout)
    private static func typeUnicode(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Send in chunks of 20 UTF-16 units (some implementations drop input if it's too long at once)
        let units = Array(text.utf16)
        var i = 0
        while i < units.count {
            let chunk = Array(units[i..<min(i + 20, units.count)])
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                up.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
            }
            usleep(15_000)
            i += 20
        }
    }

    /// Activates the target app and waits up to 2s for it to become frontmost.
    /// If the OS-side transition from a prior action (panel open/close, previous load)
    /// hasn't finished yet, grabbing the first matching instant and proceeding can send
    /// the CGEvent before keyboard focus has actually settled, so the input is lost
    /// (this caused a first-attempt-only miss). So after detecting a match, we
    /// re-confirm it still holds after a short wait before proceeding.
    private static func activateAndWait(bundleID: String, name: String) throws {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first
        else { throw InjectError.notRunning(L10n.t("\(name) が起動していません", "\(name) is not running")) }

        app.activate(options: [.activateIgnoringOtherApps])
        for _ in 0..<60 {
            usleep(50_000)
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID else { continue }
            // Right after a match it can be unstable, so wait briefly and re-check
            usleep(250_000)
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
                usleep(150_000) // final grace period for focus to settle
                return
            }
        }
        throw InjectError.activateFailed(name)
    }

    private static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cgSessionEventTap)
        usleep(30_000)
        up?.post(tap: .cgSessionEventTap)
    }

    /// The focused WezTerm pane ID. Falls back to the first pane if client info is unavailable
    private static func weztermFocusedPaneID(_ wezterm: String) throws -> String {
        func firstJSONArray(_ out: String) -> [[String: Any]]? {
            guard let data = out.data(using: .utf8),
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { return nil }
            return arr
        }
        if let out = try? CLIRunner.run(wezterm, ["cli", "list-clients", "--format", "json"]),
           let clients = firstJSONArray(out),
           let paneID = clients.compactMap({ $0["focused_pane_id"] as? Int }).first {
            return String(paneID)
        }
        let out = try CLIRunner.run(wezterm, ["cli", "list", "--format", "json"])
        guard let panes = firstJSONArray(out),
              let paneID = panes.compactMap({ $0["pane_id"] as? Int }).first else {
            throw InjectError.scriptFailed(L10n.t("WezTerm のペインが見つかりません", "No WezTerm pane found"))
        }
        return String(paneID)
    }

    /// Session name of the most recently used attached client (send-keys reaches its active pane)
    private static func tmuxActiveSession(_ tmux: String) throws -> String {
        let out = try CLIRunner.run(tmux, ["list-clients", "-F", "#{client_activity}\t#{session_name}"])
        let clients = out.split(separator: "\n").compactMap { line -> (activity: Int, session: String)? in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let activity = Int(parts[0]) else { return nil }
            return (activity, String(parts[1]))
        }
        guard let latest = clients.max(by: { $0.activity < $1.activity }) else {
            throw InjectError.scriptFailed(L10n.t("tmux にアタッチ中のクライアントがありません(tmux attach してください)", "No attached tmux client (run tmux attach first)"))
        }
        return latest.session
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func runAppleScript(_ source: String) throws {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw InjectError.scriptFailed(L10n.t("スクリプト生成エラー", "Failed to create script"))
        }
        script.executeAndReturnError(&error)
        if let error {
            let msg = (error[NSAppleScript.errorMessage] as? String) ?? "\(error)"
            throw InjectError.scriptFailed(L10n.t("\(msg)(オートメーション許可を確認してください)", "\(msg) (check Automation permission)"))
        }
    }
}
