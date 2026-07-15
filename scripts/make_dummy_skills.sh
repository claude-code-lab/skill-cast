#!/bin/bash
# Creates 3 dummy skills under ~/.claude/skills/ for E2E verification.
# Cleanup: rm -rf ~/.claude/skills/dummy-{alpha,beta,gamma}
set -euo pipefail

ROOT="$HOME/.claude/skills"
mkdir -p "$ROOT"

make_skill() {
  local dir="$1" name="$2" desc="$3"
  mkdir -p "$ROOT/$dir"
  cat > "$ROOT/$dir/SKILL.md" <<EOF
---
name: $name
description: $desc
---

# $name

これは SkillCast の E2E 確認用ダミースキルです。
EOF
  echo "created: $ROOT/$dir/SKILL.md"
}

make_skill dummy-alpha dummy-alpha "ダミースキルA。検索・選択・ロードのE2E確認用。"
make_skill dummy-beta  dummy-beta  "ダミースキルB。日本語説明の表示確認用。"
make_skill dummy-gamma dummy-gamma "ダミースキルC。複数選択のロード確認用。"
