import Foundation

struct AppSettings: Codable {
    /// Custom template per language (keyed by PromptLanguage.rawValue).
    /// Languages without one fall back to PromptLanguage.defaultTemplate. {paths} expands to the SKILL.md paths
    var promptTemplates: [String: String] = [:]
    var promptLanguage: PromptLanguage = .systemDefault
    var defaultTerminal: TerminalTarget?
    var lastSelection: [String] = []
    /// Skills directory (nil = ~/.claude/skills)
    var skillsDir: String?

    var skillsDirURL: URL {
        if let skillsDir, !skillsDir.isEmpty {
            return URL(fileURLWithPath: (skillsDir as NSString).expandingTildeInPath)
        }
        return SkillScanner.defaultRoot
    }

    func template(for language: PromptLanguage) -> String {
        promptTemplates[language.rawValue] ?? language.defaultTemplate
    }

    // MARK: - Codable (backward-compatible with older settings)

    private enum CodingKeys: String, CodingKey {
        case promptTemplates, promptLanguage, defaultTerminal, lastSelection, skillsDir
        case legacyTemplate = "promptTemplate"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        promptTemplates = try c.decodeIfPresent([String: String].self, forKey: .promptTemplates) ?? [:]
        promptLanguage = try c.decodeIfPresent(PromptLanguage.self, forKey: .promptLanguage) ?? .systemDefault
        defaultTerminal = try c.decodeIfPresent(TerminalTarget.self, forKey: .defaultTerminal)
        lastSelection = try c.decodeIfPresent([String].self, forKey: .lastSelection) ?? []
        skillsDir = try c.decodeIfPresent(String.self, forKey: .skillsDir)
        // Carry over the old single-template format as the Japanese custom template
        if let legacy = try c.decodeIfPresent(String.self, forKey: .legacyTemplate),
           promptTemplates[PromptLanguage.ja.rawValue] == nil {
            promptTemplates[PromptLanguage.ja.rawValue] = legacy
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(promptTemplates, forKey: .promptTemplates)
        try c.encode(promptLanguage, forKey: .promptLanguage)
        try c.encodeIfPresent(defaultTerminal, forKey: .defaultTerminal)
        try c.encode(lastSelection, forKey: .lastSelection)
        try c.encodeIfPresent(skillsDir, forKey: .skillsDir)
    }

    private static let key = "SkillCast.settings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    /// Reloads the latest state from disk before applying a change and saving.
    /// Saving a stale in-memory copy wholesale could roll back fields updated
    /// concurrently through another path (e.g. the skills folder setting), so
    /// any "change just one field" operation must go through this.
    @discardableResult
    static func mutate(_ change: (inout AppSettings) -> Void) -> AppSettings {
        var current = load()
        change(&current)
        current.save()
        return current
    }
}
