#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release
APP="$ROOT/dist/Salary Clock.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/SalaryClock" "$APP/Contents/MacOS/SalaryClock"

# Generate a native macOS application icon and package all required resolutions.
ICONSET="$ROOT/.build/SalaryClock.iconset"
mkdir -p "$ICONSET"
swift "$ROOT/scripts/generate-app-icon.swift" "$ROOT/.build/SalaryClock-1024.png"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" "$ROOT/.build/SalaryClock-1024.png" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" "$ROOT/.build/SalaryClock-1024.png" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
cp "$ROOT/.build/SalaryClock-1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SalaryClock</string>
<key>CFBundleIdentifier</key><string>com.jyd.salaryclock</string>
<key>CFBundleName</key><string>薪资时钟</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>0.1.0</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

# UserNotifications requires a registered, code-signed macOS app bundle.
# Use a stable bundle identifier even for local ad-hoc builds.
codesign --force --sign - --identifier com.jyd.salaryclock "$APP"
"/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" -f "$APP"

echo "已生成并签名：$APP"
