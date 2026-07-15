#!/bin/bash
# Builds the SkillCast.app bundle from the swift build output.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/SkillCast.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/SkillCast "$APP/Contents/MacOS/SkillCast"

if [ ! -f Resources/AppIcon.icns ]; then
  ./scripts/build_icon.sh
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.skillcast.app</string>
    <key>CFBundleName</key>
    <string>SkillCast</string>
    <key>CFBundleExecutable</key>
    <string>SkillCast</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>選択したスキルをターミナルの Claude Code セッションに送信するために使用します。</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP"
echo "built: $APP"

# Install to /Applications (for stable TCC registration and easy discovery in permission settings)
if [ "${1:-}" = "--install" ]; then
  osascript -e 'quit app "SkillCast"' 2>/dev/null || true
  sleep 1
  rm -rf /Applications/SkillCast.app
  cp -R "$APP" /Applications/
  tccutil reset Accessibility com.skillcast.app || true
  open /Applications/SkillCast.app
  echo "installed: /Applications/SkillCast.app (アクセシビリティを再許可してください)"
fi
