#!/bin/bash
# 构建 人脉簿 (Peoplebook) 的可双击启动 .app
# 用法: ./scripts/make-app.sh [输出目录，默认 dist/]
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="人脉簿"
BUNDLE_ID="com.lebrosoft.peoplebook"
OUT_DIR="${1:-dist}"
BUILD_DIR=".build/release"

swift build -c release

APP="$OUT_DIR/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>PeoplebookApp</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

cp "$BUILD_DIR/PeoplebookApp" "$APP/Contents/MacOS/PeoplebookApp"

echo "Built: $APP"
echo "启动方式: open \"$APP\""
