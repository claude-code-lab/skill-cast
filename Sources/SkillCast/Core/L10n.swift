import Foundation

/// UI/error message localization (switches ja / en by system language)
enum L10n {
    static var isJa: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    static func t(_ ja: String, _ en: String) -> String {
        isJa ? ja : en
    }
}

/// Language of the injected prompt (selectable independently of the UI language)
enum PromptLanguage: String, CaseIterable, Codable, Identifiable {
    case ja
    case en
    case zhHans = "zh-Hans"
    case ko

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ja: return "日本語"
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .ko: return "한국어"
        }
    }

    var defaultTemplate: String {
        switch self {
        case .ja:
            return "{paths} これらのスキルを読み込んで、この後のタスクで使ってください"
        case .en:
            return "{paths} Please load these skills and use them for the upcoming tasks"
        case .zhHans:
            return "{paths} 请加载这些技能,并在接下来的任务中使用"
        case .ko:
            return "{paths} 이 스킬들을 읽어들여 이후 작업에 사용해 주세요"
        }
    }

    /// Default matching the system language
    static var systemDefault: PromptLanguage {
        let lang = Locale.preferredLanguages.first ?? "en"
        if lang.hasPrefix("ja") { return .ja }
        if lang.hasPrefix("zh") { return .zhHans }
        if lang.hasPrefix("ko") { return .ko }
        return .en
    }
}
