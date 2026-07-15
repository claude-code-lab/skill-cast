# SkillCast 設計書

> 実装前の初期設計メモです。実装で変わった点(ターゲット5種への拡張、CGEvent Unicode タイプ方式、
> 多言語プロンプト、スキルフォルダ設定など)は README.md が正です。

macOS 用スキルランチャー。`~/.claude/skills/` 配下のスキルを一覧・検索し、選択したものだけを最前面ターミナルの Claude Code セッションへ「読み込んでください」プロンプトとしてキー送信する。

## 1. 技術選定

| 項目 | 選定 | 理由 |
|---|---|---|
| 言語/UI | Swift 5.9+ / SwiftUI | ネイティブ外観・ライト/ダーク自動対応・起動が軽い |
| アプリ形態 | メニューバー常駐 (`MenuBarExtra` + `NSPanel`) | Dock 非表示 (`LSUIElement=true`)、Spotlight 風パネルは `NSPanel`(nonactivating) で実装 |
| ホットキー | Carbon `RegisterEventHotKey`(依存ゼロ)| デフォルト ⌥⌘K。サードパーティ依存を避ける |
| キー注入 | AppleScript(各ターミナルの scripting)+ System Events フォールバック | 後述 §5 |
| 設定/履歴 | `UserDefaults`(JSON エンコード) | 単純な KV で十分 |
| ビルド | Swift Package(`swift build`)+ 手動 .app バンドル化スクリプト | Xcode プロジェクト不要で CLI 完結 |

## 2. モジュール構成

```
SkillCast/
├── Package.swift
├── Sources/SkillCast/
│   ├── App.swift              # @main, MenuBarExtra, パネル生成
│   ├── HotKey.swift           # Carbon ホットキー登録
│   ├── Panel/
│   │   ├── FloatingPanel.swift    # nonactivating NSPanel(画面中央上、ESCで閉じる)
│   │   ├── SkillListView.swift    # 検索ボックス+一覧+フッター(SwiftUI)
│   │   └── SkillRowView.swift     # チェックボックス+name+description 2行
│   ├── Core/
│   │   ├── SkillScanner.swift     # ~/.claude/skills/*/SKILL.md 走査
│   │   ├── FrontmatterParser.swift# YAML frontmatter の name/description 抽出
│   │   ├── SkillStore.swift       # ObservableObject: 一覧・選択・検索・エラー状態
│   │   ├── TerminalTarget.swift   # enum: ghostty / iterm2 / terminal + 前面検出
│   │   ├── Injector.swift         # プロンプト組立+キー送信
│   │   └── Settings.swift         # テンプレート・履歴・既定ターミナル
│   └── Resources/Info.plist       # LSUIElement, NSAppleEventsUsageDescription
├── scripts/make_dummy_skills.sh   # E2E 用ダミースキル3件生成
└── README.md
```

## 3. データモデル

```swift
struct Skill: Identifiable, Hashable {
    let id: String        // ディレクトリパス
    let name: String      // frontmatter name(欠損時はディレクトリ名)
    let description: String
    let path: String      // SKILL.md の絶対パス
    let warning: String?  // frontmatter 欠損などの行内警告
}

struct AppSettings: Codable {
    var promptTemplate: String
      // 既定: "{paths} これらのスキルを読み込んで、この後のタスクで使ってください"
      // {paths} は選択スキルの SKILL.md パスをスペース区切りで展開
    var defaultTerminal: TerminalTarget?   // nil = 前面ターミナル自動
    var lastSelection: [String]            // 前回選択のスキル id 群(起動時復元)
}
```

`SkillStore`(単一の ObservableObject)が UI の唯一の状態源:
`skills` / `query` / `selectedIDs` / `errorMessage: String?`(パネル下部に赤字表示)。

## 4. 走査とパース

- `SkillScanner`: `FileManager` で `~/.claude/skills/` の直下ディレクトリを列挙し、各 `SKILL.md` の先頭 `---`〜`---` を読む。リロードボタン・パネル表示時に再走査。
- `FrontmatterParser`: 依存ライブラリなしの簡易 YAML(`key: value` の1階層のみ、`>`/`|` 複数行 description 対応)。`name` 欠損 → ディレクトリ名で代替+ `warning` 設定。frontmatter 自体がない → 一覧に警告付きで表示(落とさない)。
- スキル 0 件 → `errorMessage = "~/.claude/skills/ にスキルが見つかりません"`。

## 5. 検索

正規化関数 `normalize(s)` = 小文字化 + `applyingTransform(.fullwidthToHalfwidth)` +(かな→カナ統一は不要、部分一致のみ)。`normalize(name).contains(normalize(query)) || normalize(description).contains(...)` でインクリメンタルフィルタ。選択状態はフィルタと独立に保持。

## 6. ロード(キー注入)

1. 対象ターミナル決定: ドロップダウン指定 > 前面アプリ検出(`NSWorkspace.frontmostApplication` は自分なので、直前の前面アプリを hotkey 発火時に記録しておき、その bundle id が3種のどれかなら採用)> 既定 Ghostty。
2. プロンプト組立: テンプレートの `{paths}` を展開し**1行**にする(改行は途中送信になるため除去)。
3. 送信方法(ターミナル別):
   - **iTerm2**: `tell current session of current window to write text "…"`(Enter 込み、最も堅牢)
   - **Terminal.app**: `do script "…" in front window` は新コマンド実行になるため不可。`activate` → System Events `keystroke`+`key code 36`(Enter)
   - **Ghostty**: AppleScript 辞書なし。`activate` → System Events `keystroke`(日本語を含む場合は `set the clipboard` → `keystroke "v" using command down` → `key code 36` のペースト方式を既定にする。keystroke は非 ASCII に弱いため)
4. ターミナル未起動 / 権限未許可(Automation・Accessibility)→ エラーを捕捉して赤字表示。初回はシステムの許可ダイアログが出る旨も表示。
5. 成功時: 選択 id 群を `lastSelection` に保存し、パネルを閉じる。

## 7. UI 仕様(パネル)

```
┌─ SkillCast ────────────────────────────┐
│ 🔍 スキルを検索…            [全解除] [⟳] │
├──────────────────────────────────────────┤
│ ☑ skill-forge                            │
│   任意のテーマからClaude Code用の…       │
│ ☐ dataviz                                │
│   Use this skill whenever…               │
│              (スクロール)                │
├──────────────────────────────────────────┤
│ (エラー時: 赤字メッセージ)               │
│ 2 / 14 選択   [Ghostty ▾]                │
│ [ 選択した 2 件を「Ghostty」にロード ]    │
└──────────────────────────────────────────┘
```

- サイズ ~560×420、画面中央・上から 20% の位置。ESC / フォーカス喪失で閉じる。
- パネルは `.nonactivatingPanel` にし、検索フィールドにのみキーフォーカス(前面ターミナルのアクティブ状態をなるべく壊さない。ただし送信時は対象を `activate` する)。
- ↑↓ で行移動、Space でチェックトグル、⌘Enter でロード。

## 8. エラーハンドリング方針

すべて `SkillStore.errorMessage` に集約し赤字表示、アプリは落とさない:
skills ディレクトリなし / 0件 / frontmatter 欠損(行内警告) / 選択0件でロード押下 / ターミナル未起動 / osascript 失敗(権限含む)。

## 9. E2E 確認と README

- `scripts/make_dummy_skills.sh`: `~/.claude/skills/dummy-{a,b,c}/SKILL.md` を name/日本語 description 付きで生成。
- 手順: アプリ起動 → ⌥⌘K → 「dummy」検索 → 2件選択 → Ghostty を対象にロード → Ghostty の Claude Code セッションにプロンプト+Enter が入ることを確認 → ダミー削除。
- README.md: ビルド方法(`swift build` + bundle スクリプト)、初回の Automation/Accessibility 許可手順、ホットキー、テンプレート編集、トラブルシュート。

## 10. 実装順序

1. SkillScanner + FrontmatterParser(単体テスト付き)
2. SkillStore + パネル UI(検索・選択・エラー表示)
3. ホットキー + FloatingPanel 挙動
4. Injector(iTerm2 → Ghostty → Terminal.app の順)
5. 設定(テンプレート・履歴復元)
6. ダミースキルで E2E → README
