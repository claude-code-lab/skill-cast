import SwiftUI

struct SkillListView: View {
    @ObservedObject var store: SkillStore
    weak var panel: NSPanel?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 560, height: 420)
        .onAppear {
            searchFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L10n.t("スキルを検索…", "Search skills…"), text: $store.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            Button(L10n.t("全解除", "Clear All")) { store.selectedIDs.removeAll() }
                .disabled(store.selectedIDs.isEmpty)
            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(L10n.t("スキル一覧を再読み込み", "Rescan skills"))
        }
        .padding(10)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(store.filtered) { skill in
                    SkillRowView(
                        skill: skill,
                        isSelected: store.selectedIDs.contains(skill.id),
                        toggle: { store.toggle(skill) }
                    )
                }
                if store.filtered.isEmpty && store.errorMessage == nil {
                    Text(L10n.t("該当するスキルがありません", "No matching skills"))
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text(L10n.t("\(store.selectedIDs.count) / \(store.skills.count) 選択",
                            "\(store.selectedIDs.count) / \(store.skills.count) selected"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $store.language) {
                    ForEach(PromptLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                .help(L10n.t("プロンプトの言語", "Prompt language"))
                Picker("", selection: $store.target) {
                    ForEach(TerminalTarget.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }
            Button {
                // SkillCast's panel is an NSPanel at level = .floating. If we close it
                // after sending, activate()-ing Ghostty can still leave the floating panel
                // on screen without keyboard focus having actually been released. So close
                // the panel first (fully releasing keyboard focus), then send.
                // Scheduled via a .common-mode timer so it also runs after the button
                // click's own event-handling chain has fully exited.
                panel?.close()
                let timer = Timer(timeInterval: 0.3, repeats: false) { _ in
                    if !store.performLoad() {
                        panel?.makeKeyAndOrderFront(nil) // re-show the panel to surface the error on failure
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
            } label: {
                Text(L10n.t("選択した \(store.selectedIDs.count) 件を「\(store.target.displayName)」にロード",
                            "Load \(store.selectedIDs.count) selected into \(store.target.displayName)"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.selectedIDs.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(10)
    }
}
