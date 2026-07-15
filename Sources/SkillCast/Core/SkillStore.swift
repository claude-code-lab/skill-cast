import AppKit
import SwiftUI

@MainActor
final class SkillStore: ObservableObject {
    @Published var skills: [Skill] = []
    @Published var query = ""
    @Published var selectedIDs: Set<String> = []
    @Published var errorMessage: String?
    @Published var target: TerminalTarget = .ghostty {
        didSet {
            guard target != oldValue else { return }
            settings = AppSettings.mutate { $0.defaultTerminal = target }
        }
    }
    @Published var language: PromptLanguage = .systemDefault {
        didSet {
            guard language != oldValue else { return }
            settings = AppSettings.mutate { $0.promptLanguage = language }
        }
    }

    var settings = AppSettings.load()

    init() {
        target = settings.defaultTerminal ?? .ghostty
        language = settings.promptLanguage
    }

    func reload() {
        errorMessage = nil
        // Reload the latest state from disk (to reflect changes from another process/prior launch)
        settings = AppSettings.load()
        do {
            skills = try SkillScanner.scan(root: settings.skillsDirURL)
            // Restore the previous selection (only entries that still exist)
            if selectedIDs.isEmpty {
                let ids = Set(skills.map(\.id))
                selectedIDs = Set(settings.lastSelection).intersection(ids)
            }
        } catch {
            skills = []
            selectedIDs = []
            errorMessage = error.localizedDescription
        }
    }

    var filtered: [Skill] {
        let q = Self.normalize(query)
        guard !q.isEmpty else { return skills }
        return skills.filter {
            Self.normalize($0.name).contains(q) || Self.normalize($0.description).contains(q)
        }
    }

    /// Normalization that ignores case and full/half-width differences
    nonisolated static func normalize(_ s: String) -> String {
        let lowered = s.lowercased()
        return lowered.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? lowered
    }

    func toggle(_ skill: Skill) {
        if selectedIDs.contains(skill.id) {
            selectedIDs.remove(skill.id)
        } else {
            selectedIDs.insert(skill.id)
        }
    }

    /// Records the frontmost terminal at hotkey trigger time as the load-target candidate
    func recordFrontmostTerminal() {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let t = TerminalTarget.from(bundleID: front) {
            target = t
        } else if let d = settings.defaultTerminal {
            target = d
        }
    }

    /// Performs the load. Returns true on success (caller closes the panel)
    func performLoad() -> Bool {
        errorMessage = nil
        let selected = skills.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else {
            errorMessage = L10n.t("スキルが選択されていません", "No skills selected")
            return false
        }
        let prompt = Injector.buildPrompt(template: settings.template(for: language), skills: selected)
        do {
            try Injector.inject(prompt: prompt, into: target)
            let selection = Array(selectedIDs)
            settings = AppSettings.mutate {
                $0.lastSelection = selection
                $0.defaultTerminal = target
                $0.promptLanguage = language
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
