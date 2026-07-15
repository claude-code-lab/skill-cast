import XCTest
@testable import SkillCast

final class FrontmatterParserTests: XCTestCase {
    func testSimple() {
        let md = """
        ---
        name: my-skill
        description: シンプルな説明
        ---
        # body
        """
        let f = FrontmatterParser.parse(md)
        XCTAssertEqual(f?["name"], "my-skill")
        XCTAssertEqual(f?["description"], "シンプルな説明")
    }

    func testQuotedValue() {
        let md = """
        ---
        name: "quoted"
        description: 'single: quoted'
        ---
        """
        let f = FrontmatterParser.parse(md)
        XCTAssertEqual(f?["name"], "quoted")
        XCTAssertEqual(f?["description"], "single: quoted")
    }

    func testMultilineBlock() {
        let md = """
        ---
        name: multi
        description: >
          1行目の説明
          2行目の説明
        ---
        """
        let f = FrontmatterParser.parse(md)
        XCTAssertEqual(f?["description"], "1行目の説明 2行目の説明")
    }

    func testNoFrontmatter() {
        XCTAssertNil(FrontmatterParser.parse("# ただのMarkdown"))
    }

    func testUnclosedFrontmatter() {
        XCTAssertNil(FrontmatterParser.parse("---\nname: broken\n"))
    }

    func testNormalize() {
        XCTAssertEqual(SkillStore.normalize("ABC DEF"), "abc def")
        XCTAssertTrue(SkillStore.normalize("スキルAbc").contains("abc"))
    }

    func testLanguageTemplates() {
        for lang in PromptLanguage.allCases {
            XCTAssertTrue(lang.defaultTemplate.contains("{paths}"), "\(lang.rawValue) に {paths} がない")
        }
        var settings = AppSettings()
        XCTAssertEqual(settings.template(for: .en), PromptLanguage.en.defaultTemplate)
        settings.promptTemplates["en"] = "{paths} custom"
        XCTAssertEqual(settings.template(for: .en), "{paths} custom")
        XCTAssertEqual(settings.template(for: .ko), PromptLanguage.ko.defaultTemplate)
    }

    func testBuildPrompt() {
        let s1 = Skill(id: "/a", name: "a", description: "", path: "/a/SKILL.md", warning: nil)
        let s2 = Skill(id: "/b", name: "b", description: "", path: "/b/SKILL.md", warning: nil)
        let p = Injector.buildPrompt(
            template: "{paths} これらのスキルを読み込んで、この後のタスクで使ってください",
            skills: [s1, s2]
        )
        XCTAssertEqual(p, "/a/SKILL.md /b/SKILL.md これらのスキルを読み込んで、この後のタスクで使ってください")
        XCTAssertFalse(p.contains("\n"))
    }
}
