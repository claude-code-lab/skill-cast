import Foundation

struct Skill: Identifiable, Hashable {
    let id: String          // absolute path of the skill directory
    let name: String
    let description: String
    let path: String        // absolute path of SKILL.md
    let warning: String?    // inline warning, e.g. missing frontmatter
}

enum SkillScanner {
    static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills")
    }

    enum ScanError: LocalizedError {
        case rootMissing(String)
        case empty(String)
        var errorDescription: String? {
            switch self {
            case .rootMissing(let p): return L10n.t("\(p) が見つかりません", "\(p) not found")
            case .empty(let p): return L10n.t("\(p) にスキルが見つかりません", "No skills found in \(p)")
            }
        }
    }

    static func scan(root: URL = defaultRoot) throws -> [Skill] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            throw ScanError.rootMissing(root.path)
        }
        let entries = try fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var skills: [Skill] = []
        for dir in entries {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let skillMD = dir.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillMD.path) else { continue }
            let dirName = dir.lastPathComponent

            guard let content = try? String(contentsOf: skillMD, encoding: .utf8) else {
                skills.append(Skill(id: dir.path, name: dirName, description: "",
                                    path: skillMD.path, warning: L10n.t("SKILL.md を読み込めません", "Cannot read SKILL.md")))
                continue
            }
            guard let fields = FrontmatterParser.parse(content) else {
                skills.append(Skill(id: dir.path, name: dirName, description: "",
                                    path: skillMD.path, warning: L10n.t("frontmatter がありません", "Missing frontmatter")))
                continue
            }
            let name = fields["name"].flatMap { $0.isEmpty ? nil : $0 } ?? dirName
            let warning = fields["name"] == nil ? L10n.t("frontmatter に name がありません", "Missing name in frontmatter") : nil
            skills.append(Skill(id: dir.path, name: name,
                                description: fields["description"] ?? "",
                                path: skillMD.path, warning: warning))
        }
        guard !skills.isEmpty else { throw ScanError.empty(root.path) }
        return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
