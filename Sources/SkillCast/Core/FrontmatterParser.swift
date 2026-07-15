import Foundation

/// A minimal parser that extracts SKILL.md's YAML frontmatter (flat key: value pairs only).
/// Supports `>` / `|` (and `>-` / `|-`) multi-line values. Returns nil if there's no frontmatter.
enum FrontmatterParser {
    static func parse(_ content: String) -> [String: String]? {
        let lines = content.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var fields: [String: String] = [:]
        var currentKey: String?
        var blockLines: [String] = []
        var inBlock = false

        func flushBlock() {
            if let key = currentKey {
                fields[key] = blockLines.joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
            }
            currentKey = nil
            blockLines = []
            inBlock = false
        }

        var i = 1
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                if inBlock { flushBlock() }
                return fields
            }
            if inBlock {
                if line.isEmpty || line.hasPrefix(" ") || line.hasPrefix("\t") {
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { blockLines.append(t) }
                    i += 1
                    continue
                }
                flushBlock()
            }
            if !line.hasPrefix(" "), !line.hasPrefix("\t"),
               let colon = line.firstIndex(of: ":") {
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                var value = String(line[line.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
                if ["|", ">", "|-", ">-"].contains(value) {
                    inBlock = true
                    currentKey = key
                } else {
                    if value.count >= 2,
                       (value.hasPrefix("\"") && value.hasSuffix("\""))
                        || (value.hasPrefix("'") && value.hasSuffix("'")) {
                        value = String(value.dropFirst().dropLast())
                    }
                    fields[key] = value
                }
            }
            i += 1
        }
        return nil // no closing ---
    }
}
