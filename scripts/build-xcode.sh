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
xcodebuild \
  -project SalaryClock.xcodeproj \
  -scheme SalaryClock \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$ROOT/.derivedData" \
  build

APP="$ROOT/.derivedData/Build/Products/Release/SalaryClock.app"
if [[ ! -d "$APP" ]]; then
  echo "错误：构建完成但未找到应用包：$APP" >&2
  exit 1
fi
echo "Xcode 构建完成：$APP"
