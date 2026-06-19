#!/usr/bin/env bash
# inputlock 빌드 스크립트 — InputLock.app 번들 생성 + 코드서명 + zip 패키징.
#
# 사용법:
#   ./build.sh [VERSION]
#
# 환경변수:
#   SIGN_IDENTITY  코드서명 ID. 미설정 시 ad-hoc("-") 서명.
#                  Developer ID로 공증하려면 "Developer ID Application: 이름 (TEAMID)" 지정.
set -euo pipefail

VERSION="${1:-dev}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP="InputLock.app"
BIN_DIR="$APP/Contents/MacOS"
BIN="$BIN_DIR/inputlock"

echo "==> 빌드 (version=$VERSION)"
rm -rf "$APP"
mkdir -p "$BIN_DIR"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>inputlock</string>
    <key>CFBundleIdentifier</key>
    <string>com.onggi.inputlock</string>
    <key>CFBundleName</key>
    <string>InputLock</string>
    <key>CFBundleDisplayName</key>
    <string>InputLock</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> swiftc 컴파일"
swiftc main.swift -O -o "$BIN" \
    -framework CoreGraphics -framework IOKit -framework Foundation -framework ApplicationServices

echo "==> 코드서명 (${SIGN_IDENTITY:-ad-hoc})"
codesign -s "${SIGN_IDENTITY:--}" -f --deep "$APP"
codesign -dv "$APP" 2>&1 | grep -E "Identifier|Authority|Signature" || true

ZIP="InputLock-${VERSION}.zip"
echo "==> 패키징 $ZIP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> 완료"
shasum -a 256 "$ZIP"
