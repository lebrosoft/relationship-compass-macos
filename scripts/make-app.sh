#!/bin/bash
# 构建 人脉簿 (Peoplebook) 的可双击启动 .app
# 用法: ./scripts/make-app.sh [输出目录] [--universal] [--dmg]
#   --universal  构建 arm64 + x86_64 通用二进制（分发用）
#   --dmg        额外打一个 Peoplebook-macOS.dmg（UDZO 压缩镜像；ASCII 资产名，下载链接稳）
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="人脉簿"
BUNDLE_ID="com.lebrosoft.peoplebook"
OUT_DIR="dist"
UNIVERSAL=0
MAKE_DMG=0

for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=1 ;;
    --dmg) MAKE_DMG=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) OUT_DIR="$arg" ;;
  esac
done

if [[ "$UNIVERSAL" == 1 ]]; then
  swift build -c release --arch arm64 --arch x86_64
  # SwiftPM 布局随版本变化：Xcode 16 时代在 .build/apple/，6.4+ 在 .build/out/
  for dir in ".build/apple/Products/Release" ".build/out/Products/Release"; do
    if [[ -x "$dir/PeoplebookApp" ]]; then
      BUILD_DIR="$dir"
      break
    fi
  done
  if [[ -z "${BUILD_DIR:-}" ]]; then
    echo "错误：找不到 universal 产物（.build/apple 或 .build/out 都没有）" >&2
    exit 1
  fi
else
  swift build -c release
  BUILD_DIR=".build/release"
fi

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

# ad-hoc 签名：本地开发无证书，保证 bundle 签名一致性（分发公证是后续票）
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "Built: $APP"

if [[ "$MAKE_DMG" == 1 ]]; then
  DMG="$OUT_DIR/Peoplebook-macOS.dmg"
  rm -f "$DMG"
  hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null
  echo "DMG: $DMG"
fi
