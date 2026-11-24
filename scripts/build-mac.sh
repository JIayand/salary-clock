#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# The former SwiftPM-only packaging path signed with an ad-hoc identity and
# omitted the WidgetKit extension. That is no longer valid now that the app
# uses a team-scoped App Group shared with its sandboxed Widget extension.
# Keep this entry point for compatibility, but route all packaging through
# the single signed Xcode project so the app, extension, icon and localizations
# always ship together.
"$ROOT/scripts/build-xcode.sh"
