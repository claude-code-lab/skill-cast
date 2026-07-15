# Skill Cast

[English](README.en.md) | **日本語**

Claude Code のスキル(`~/.claude/skills/*/SKILL.md`)を一覧・検索し、選択したものだけを最前面ターミナル(Ghostty / iTerm2 / Terminal.app / WezTerm / tmux)の Claude Code セッションに「読み込んでください」プロンプトとして注入する、macOS 用の Spotlight 風スキルランチャーです。スキル本体はコンテキストに常駐させず、必要な時だけロードします。

## 必要環境

- macOS 13 以降(Apple Silicon / Intel)
- Xcode Command Line Tools(`swift build` が使えること)

## ビルドと起動

```bash
./scripts/make_app.sh --install   # ビルドして /Applications に配置・起動(推奨)
```

`--install` なしなら `build/SkillCast.app` の生成だけ行います。メニューバー常駐アプリです(Dock には出ません)。
開発中は `swift run` でも起動できます。単体テストは `swift test`。

> アプリは `/Applications` に置いてください。ユーザーフォルダ配下の ad-hoc 署名アプリは
> アクセシビリティ権限の登録(TCC)に失敗することがあります。

## 使い方

1. **⌥⌘K**(Option+Command+K)でパネルを表示(メニューバーの杖アイコンからも可)
2. 検索ボックスでインクリメンタル検索(name / description の部分一致。大文字小文字・全角半角は無視)
3. チェックボックスでスキルを選択(前回の選択は自動復元)
4. 右下のドロップダウンでプロンプト言語とロード先ターミナルを選択(ロード先の既定はホットキー押下時に前面だったターミナル)
5. ロードボタン(または **⌘Enter**)で送信 — 選択スキルの SKILL.md パスを列挙した1行プロンプト + Enter が対象ターミナルに入力されます
6. **ESC** でパネルを閉じる。⟳ ボタンでスキル一覧を再走査

## スキルフォルダの変更

既定では `~/.claude/skills/` を走査します。メニューバーアイコン → 「スキルフォルダを変更…」で
任意のフォルダ(直下に `SKILL.md` を含むディレクトリが並ぶ構成)に切り替えられます。
「スキルフォルダを既定に戻す」で `~/.claude/skills/` に戻ります。

## 多言語プロンプト / ローカライズ

パネル右下の言語ピッカーで、注入するプロンプトの言語を選べます(選択は記憶されます):

| 言語 | 既定テンプレート |
|---|---|
| 日本語 | `{paths} これらのスキルを読み込んで、この後のタスクで使ってください` |
| English | `{paths} Please load these skills and use them for the upcoming tasks` |
| 简体中文 | `{paths} 请加载这些技能,并在接下来的任务中使用` |
| 한국어 | `{paths} 이 스킬들을 읽어들여 이후 작업에 사용해 주세요` |

UI とエラーメッセージはシステム言語に追従します(日本語 / 英語)。

### テンプレートのカスタマイズ

設定は `UserDefaults`(キー `SkillCast.settings`)に JSON で保存されており、`promptTemplates` に
言語コード(`ja` / `en` / `zh-Hans` / `ko`)をキーとしたカスタムテンプレートを設定できます。
`{paths}` が選択スキルの SKILL.md パス(スペース区切り)に展開されます。

一度アプリを使った後に `defaults read com.skillcast.app` で現在の JSON を確認し、
`promptTemplates` を書き換えて戻すのが確実です(アプリ終了中に行うこと)。

## 権限設定(重要)

### アクセシビリティ(Ghostty / Terminal.app への送信に必要)

初回起動時に許可ダイアログが出ます。
**システム設定 > プライバシーとセキュリティ > アクセシビリティ** で SkillCast を ON にしてください。

> **再ビルド後は許可の取り直しが必要です。** `make_app.sh` は ad-hoc 署名のため、
> 再ビルドするとバイナリの識別子が変わり、既存の許可エントリが無効になります
> (設定画面で ON に見えていても効きません)。以下でリセットして再許可してください:
>
> ```bash
> ./scripts/make_app.sh --install   # 再ビルド + TCC リセット + 再起動まで実施
> ```
>
> その後、ロード実行時に出る許可ダイアログ(または設定画面の「+」)で再許可してください。

### オートメーション(iTerm2 への送信に必要)

iTerm2 へ初めてロードする際に「SkillCast が iTerm2 を制御しようとしています」の
ダイアログが出るので許可してください。

## 送信の仕組み

| ターミナル | 方式 |
|---|---|
| iTerm2 | AppleScript `write text`(Enter 込み。アクセシビリティ不要) |
| Ghostty / Terminal.app | 対象をアクティブ化(最前面になるまで待機)し、CGEvent の Unicode 文字列入力で直接タイプ + Enter。クリップボードを汚さず、日本語も化けません |
| WezTerm | `wezterm cli send-text` でフォーカス中ペインへ直接送信(権限・クリップボード不要、アクティブ化も不要) |
| tmux | `tmux send-keys` で最後に操作されたアタッチ中クライアントのアクティブペインへ送信(権限不要。外側のターミナルは問わない) |

## E2E 確認手順

```bash
./scripts/make_dummy_skills.sh   # ~/.claude/skills/ に dummy-{alpha,beta,gamma} を生成
./scripts/make_app.sh --install
```

1. Ghostty で `claude` を起動しておく
2. ⌥⌘K → 「dummy」で検索 → 3件表示されることを確認
3. 2〜3件チェック → ロード先を Ghostty にして「ロード」
4. Ghostty のプロンプトに `.../dummy-alpha/SKILL.md ... これらのスキルを読み込んで、この後のタスクで使ってください` が入力され Enter されることを確認
5. 後片付け: `rm -rf ~/.claude/skills/dummy-{alpha,beta,gamma}`

CLI からヘッドレスで注入経路だけ確認することもできます:

```bash
/Applications/SkillCast.app/Contents/MacOS/SkillCast --e2e ghostty   # または iterm2 / terminal / wezterm / tmux
```

## トラブルシュート

| 症状 | 対処 |
|---|---|
| 「アクセシビリティ権限がありません」 | 上記の権限設定を確認。再ビルド後なら `tccutil reset` から取り直し |
| 権限を許可したのに入力されない | 古いビルドの許可エントリが残っている。`tccutil reset Accessibility com.skillcast.app` → 再許可。アプリは /Applications に置くこと(`make_app.sh --install`) |
| 「Ghostty が起動していません」 | 対象ターミナルを先に起動する |
| 「Ghostty を前面にできませんでした」 | 対象ターミナルのウィンドウが最小化されていないか確認 |
| 「送信に失敗しました」(iTerm2) | システム設定 > プライバシーとセキュリティ > オートメーション を確認 |
| 一覧が空 / 赤字エラー | スキルフォルダ配下に `SKILL.md` を含むディレクトリがあるか確認。frontmatter(`---` で囲まれた `name:` / `description:`)が欠損したスキルは警告付きで表示される |
| ホットキーが効かない | 他アプリが ⌥⌘K を専有していないか確認 |
| ロードしても何も起きたように見えない(Ghostty/Claude Code) | Claude Code が別タスクを処理中だと、送信した Enter は実行されず「キューイング済みメッセージ」として溜まるだけになる(`Press up to edit queued messages` 表示)。入力自体は成功しているので、現在のタスクが終われば順に処理される |
| 「wezterm / tmux コマンドが見つかりません」 | `/opt/homebrew/bin`・`/usr/local/bin`(WezTerm は `.app` 内も)を探します。それ以外の場所ならシンボリックリンクを張ってください |
| 「tmux にアタッチ中のクライアントがありません」 | どこかのターミナルで `tmux attach` してから実行 |

## プロジェクト構成

```
Sources/SkillCast/
├── App.swift              # @main, メニューバー, AppDelegate, --e2e モード
├── HotKey.swift           # Carbon グローバルホットキー (⌥⌘K)
├── Panel/
│   ├── FloatingPanel.swift    # Spotlight 風 nonactivating NSPanel
│   ├── SkillListView.swift    # 検索 + 一覧 + フッター
│   └── SkillRowView.swift     # チェックボックス + name + 説明2行
└── Core/
    ├── SkillScanner.swift     # スキルフォルダ走査
    ├── FrontmatterParser.swift# YAML frontmatter 簡易パーサ
    ├── SkillStore.swift       # UI 状態(一覧・選択・検索・エラー)
    ├── TerminalTarget.swift   # ロード先ターミナル定義(5種)
    ├── Injector.swift         # プロンプト組立 + キー注入
    ├── CLIRunner.swift        # wezterm / tmux CLI 実行
    ├── L10n.swift             # UI 言語 (ja/en) + プロンプト言語 (ja/en/zh-Hans/ko)
    └── Settings.swift         # テンプレート・履歴・スキルフォルダ(UserDefaults)
```

---

*Made with [Claude Code](https://claude.ai/code) (Claude Fable 5, low effort)*
