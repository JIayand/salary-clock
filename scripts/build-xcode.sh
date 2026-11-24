#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo "错误：需要安装完整 Xcode.app，并通过 xcode-select -s /Applications/Xcode.app/Contents/Developer 指定开发目录。" >&2
  exit 1
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "错误：缺少 XcodeGen。可通过 brew install xcodegen 安装。" >&2
  exit 1
fi

xcodegen generate --spec project.yml
# 没有开发团队/有效签名配置时，可用 CODE_SIGNING_ALLOWED=NO 完成编译验证；
# 该模式生成的 App 未签名，不能作为正式安装包分发。
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-YES}"
xcodebuild \
  -project SalaryClock.xcodeproj \
  -scheme SalaryClock \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$ROOT/.derivedData" \
  CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
  build

APP="$ROOT/.derivedData/Build/Products/Release/SalaryClock.app"
if [[ ! -d "$APP" ]]; then
  echo "错误：构建完成但未找到应用包：$APP" >&2
  exit 1
fi
if [[ ! -f "$APP/Contents/Resources/AppIcon.icns" ]]; then
  echo "错误：应用图标未打入资源目录，拒绝生成不完整安装包。" >&2
  exit 1
fi
for LANGUAGE in zh-Hans zh-Hant en; do
  if [[ ! -f "$APP/Contents/Resources/$LANGUAGE.lproj/Localizable.strings" ]]; then
    echo "错误：缺少本地化资源 $LANGUAGE.lproj/Localizable.strings" >&2
    exit 1
  fi
done
codesign --verify --deep --strict "$APP"
# Xcode automatically registers the app/extension from DerivedData with LaunchServices.
# Keep development build products out of the user's app and WidgetKit catalogs;
# the installed copy in ~/Applications is the only production entry point.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
fi
if command -v pluginkit >/dev/null 2>&1; then
  pluginkit -r "$APP/Contents/PlugIns/SalaryClockWidgetExtension.appex" >/dev/null 2>&1 || true
fi
echo "Xcode 构建完成并通过资源/签名检查：$APP"
echo "已注销 DerivedData 开发副本，避免与 ~/Applications 中的正式应用重复。"
