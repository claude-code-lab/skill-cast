#!/bin/bash
# Generates a 1024x1024 PNG via scripts/make_icon.swift, assembles an .iconset, and converts to .icns.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

swift scripts/make_icon.swift "$WORK/icon-1024.png"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

# (file name, output pixel size) pairs
declare -a SPECS=(
  "icon_16x16.png 16"
  "icon_16x16@2x.png 32"
  "icon_32x32.png 32"
  "icon_32x32@2x.png 64"
  "icon_128x128.png 128"
  "icon_128x128@2x.png 256"
  "icon_256x256.png 256"
  "icon_256x256@2x.png 512"
  "icon_512x512.png 512"
  "icon_512x512@2x.png 1024"
)

for spec in "${SPECS[@]}"; do
  name="${spec% *}"
  px="${spec#* }"
  sips -z "$px" "$px" "$WORK/icon-1024.png" --out "$ICONSET/$name" >/dev/null
done

mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "built: Resources/AppIcon.icns"
