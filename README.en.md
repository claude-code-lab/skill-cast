# Skill Cast

**English** | [日本語](README.md)

A Spotlight-style skill launcher for macOS. It lists and searches your Claude Code
skills (`~/.claude/skills/*/SKILL.md`) and injects only the ones you pick into the
Claude Code session running in the frontmost terminal (Ghostty / iTerm2 /
Terminal.app / WezTerm / tmux), as a "please load these" prompt. The skill bodies
never stay resident in context — they are loaded only when you need them.

## Requirements

- macOS 13 or later (Apple Silicon / Intel)
- Xcode Command Line Tools (`swift build` must work)

## Build & launch

```bash
./scripts/make_app.sh --install   # build, place in /Applications, and launch (recommended)
```

Without `--install` it only produces `build/SkillCast.app`. It is a menu-bar app
(no Dock icon). During development you can also launch with `swift run`. Unit tests
run with `swift test`.

> Put the app in `/Applications`. An ad-hoc-signed app under your home folder can
> fail to register for Accessibility permission (TCC).

## Usage

1. **⌥⌘K** (Option+Command+K) shows the panel (also available from the wand icon in
   the menu bar)
2. Incremental search in the search box (partial match on name / description;
   case- and full/half-width-insensitive)
3. Check the skills you want (your previous selection is restored automatically)
4. Pick the prompt language and target terminal from the dropdowns at the bottom
   right (the target defaults to whichever terminal was frontmost when you pressed
   the hotkey)
5. The Load button (or **⌘Enter**) sends it — a one-line prompt listing the SKILL.md
   paths of the selected skills, plus Enter, is typed into the target terminal
6. **ESC** closes the panel. The ⟳ button re-scans the skill list

## Changing the skill folder

By default it scans `~/.claude/skills/`. Via the menu-bar icon → "Change skill
folder…" you can switch to any folder (a layout where directories each containing a
`SKILL.md` sit directly under it). "Reset skill folder to default" returns to
`~/.claude/skills/`.

## Multilingual prompts / localization

The language picker at the bottom right of the panel lets you choose the language of
the injected prompt (the choice is remembered):

| Language | Default template |
|---|---|
| 日本語 | `{paths} これらのスキルを読み込んで、この後のタスクで使ってください` |
| English | `{paths} Please load these skills and use them for the upcoming tasks` |
| 简体中文 | `{paths} 请加载这些技能,并在接下来的任务中使用` |
| 한국어 | `{paths} 이 스킬들을 읽어들여 이후 작업에 사용해 주세요` |

The UI and error messages follow the system language (Japanese / English).

### Customizing templates

Settings are stored as JSON in `UserDefaults` (key `SkillCast.settings`). Under
`promptTemplates` you can set custom templates keyed by language code (`ja` / `en` /
`zh-Hans` / `ko`). `{paths}` expands to the SKILL.md paths of the selected skills
(space-separated).

After using the app once, the reliable way is to inspect the current JSON with
`defaults read com.skillcast.app`, edit `promptTemplates`, and write it back (do this
while the app is not running).

## Permissions (important)

### Accessibility (required to send to Ghostty / Terminal.app)

A permission dialog appears on first launch. Turn SkillCast ON under
**System Settings > Privacy & Security > Accessibility**.

> **After a rebuild you must re-grant permission.** `make_app.sh` uses ad-hoc
> signing, so rebuilding changes the binary's identifier and invalidates the existing
> permission entry (it may still look ON in the settings pane but has no effect).
> Reset and re-grant with:
>
> ```bash
> ./scripts/make_app.sh --install   # rebuild + TCC reset + relaunch
> ```
>
> Then re-grant via the permission dialog shown at load time (or the "+" in the
> settings pane).

### Automation (required to send to iTerm2)

The first time you load into iTerm2, a "SkillCast wants to control iTerm2" dialog
appears — allow it.

## How injection works

| Terminal | Method |
|---|---|
| iTerm2 | AppleScript `write text` (includes Enter; no Accessibility needed) |
| Ghostty / Terminal.app | Activates the target (waits until it is frontmost) and types directly via CGEvent Unicode string input + Enter. Does not touch the clipboard, and Japanese is not garbled |
| WezTerm | `wezterm cli send-text` sends directly to the focused pane (no permission/clipboard needed, no activation needed) |
| tmux | `tmux send-keys` sends to the active pane of the most recently used attached client (no permission needed; the outer terminal does not matter) |

## E2E check

```bash
./scripts/make_dummy_skills.sh   # creates dummy-{alpha,beta,gamma} under ~/.claude/skills/
./scripts/make_app.sh --install
```

1. Launch `claude` in Ghostty ahead of time
2. ⌥⌘K → search "dummy" → confirm 3 entries appear
3. Check 2–3 of them → set the target to Ghostty → "Load"
4. Confirm that `.../dummy-alpha/SKILL.md ... これらのスキルを読み込んで、この後のタスクで使ってください`
   is typed into the Ghostty prompt and Enter is pressed
5. Cleanup: `rm -rf ~/.claude/skills/dummy-{alpha,beta,gamma}`

You can also verify just the injection path headlessly from the CLI:

```bash
/Applications/SkillCast.app/Contents/MacOS/SkillCast --e2e ghostty   # or iterm2 / terminal / wezterm / tmux
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| "No Accessibility permission" | Check the permission steps above. After a rebuild, re-grant from `tccutil reset` |
| Granted permission but nothing is typed | A stale permission entry from an old build remains. `tccutil reset Accessibility com.skillcast.app` → re-grant. Keep the app in /Applications (`make_app.sh --install`) |
| "Ghostty is not running" | Launch the target terminal first |
| "Could not bring Ghostty to the front" | Check that the target terminal's window is not minimized |
| "Failed to send" (iTerm2) | Check System Settings > Privacy & Security > Automation |
| Empty list / red error | Check that the skill folder has directories containing `SKILL.md`. Skills missing frontmatter (`name:` / `description:` inside `---`) are shown with a warning |
| Hotkey does not work | Check that no other app has claimed ⌥⌘K |
| Loading seems to do nothing (Ghostty/Claude Code) | If Claude Code is busy with another task, the Enter you sent isn't executed — it just queues (shown as `Press up to edit queued messages`). The input itself succeeded; it will run once the current task finishes |
| "wezterm / tmux command not found" | It searches `/opt/homebrew/bin` and `/usr/local/bin` (and inside the `.app` for WezTerm). If yours is elsewhere, add a symlink |
| "No client attached to tmux" | Run `tmux attach` in some terminal first |

## Project layout

```
Sources/SkillCast/
├── App.swift              # @main, menu bar, AppDelegate, --e2e mode
├── HotKey.swift           # Carbon global hotkey (⌥⌘K)
├── Panel/
│   ├── FloatingPanel.swift    # Spotlight-style nonactivating NSPanel
│   ├── SkillListView.swift    # search + list + footer
│   └── SkillRowView.swift     # checkbox + name + 2-line description
└── Core/
    ├── SkillScanner.swift     # scans the skill folder
    ├── FrontmatterParser.swift# minimal YAML frontmatter parser
    ├── SkillStore.swift       # UI state (list / selection / search / errors)
    ├── TerminalTarget.swift   # target terminal definitions (5 kinds)
    ├── Injector.swift         # prompt assembly + key injection
    ├── CLIRunner.swift        # wezterm / tmux CLI execution
    ├── L10n.swift             # UI language (ja/en) + prompt language (ja/en/zh-Hans/ko)
    └── Settings.swift         # templates / history / skill folder (UserDefaults)
```

---

*Made with [Claude Code](https://claude.ai/code) (Claude Fable 5, low effort)*
