import SwiftUI

@main
struct SkillCastApp: App {
    init() {
        // For E2E verification: headlessly runs scan -> select dummy -> build prompt -> inject
        // Usage: SkillCast --e2e [ghostty|iterm2|terminal]
        if CommandLine.arguments.contains("--e2e") {
            let targetName = CommandLine.arguments.last.flatMap(TerminalTarget.init(rawValue:)) ?? .ghostty
            do {
                let settings = AppSettings.load()
                let skills = try SkillScanner.scan(root: settings.skillsDirURL).filter { $0.name.hasPrefix("dummy-") }
                guard !skills.isEmpty else {
                    FileHandle.standardError.write(Data("E2E: dummy スキルが見つかりません\n".utf8))
                    exit(1)
                }
                let prompt = Injector.buildPrompt(
                    template: settings.template(for: settings.promptLanguage), skills: skills)
                print("E2E prompt: \(prompt)")
                try Injector.inject(prompt: prompt, into: targetName)
                print("E2E: \(targetName.displayName) への注入に成功")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("E2E 失敗: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Skill Cast", systemImage: "wand.and.stars") {
            Button(L10n.t("パネルを表示 (⌥⌘K)", "Show Panel (⌥⌘K)")) { appDelegate.togglePanel() }
            Button(L10n.t("スキルフォルダを変更…", "Change Skills Folder…")) { appDelegate.chooseSkillsFolder() }
            Button(L10n.t("スキルフォルダを既定に戻す", "Reset Skills Folder to Default")) {
                appDelegate.setSkillsFolder(nil)
            }
            Divider()
            Button(L10n.t("終了", "Quit")) { NSApp.terminate(nil) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SkillStore()
    private var panel: FloatingPanel?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Request Accessibility permission at launch, needed to send keys to Ghostty / Terminal.app
        // (this makes the app appear in System Settings > Accessibility)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // ⌥⌘K (kVK_ANSI_K = 40)
        hotKey = HotKey(keyCode: 40, modifiers: [.command, .option]) { [weak self] in
            self?.togglePanel()
        }
    }

    func chooseSkillsFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.settings.skillsDirURL
        panel.message = L10n.t("SKILL.md を含むスキルディレクトリの親フォルダを選択",
                               "Choose the folder containing skill directories (each with a SKILL.md)")
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            setSkillsFolder(url.path)
        }
    }

    func setSkillsFolder(_ path: String?) {
        store.settings = AppSettings.mutate { $0.skillsDir = path }
        store.selectedIDs = []
        store.reload()
    }

    func togglePanel() {
        if let p = panel, p.isVisible {
            p.close()
            return
        }
        store.recordFrontmostTerminal()
        store.reload()
        let p = panel ?? FloatingPanel(store: store)
        panel = p
        p.show()
    }
}
