#!/bin/bash
set -euo pipefail

# Creates local signed archives. Upload separately through Xcode Organizer.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

case "${1:-ios}" in
  ios) scheme=Max; destination='generic/platform=iOS' ;;
  watchos) scheme=MaxWatch; destination='generic/platform=watchOS' ;;
  macos) scheme=MaxMac; destination='generic/platform=macOS' ;;
  *) echo "Usage: $0 [ios|watchos|macos]"; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then echo "Usage: $0 [ios|watchos|macos]"; exit 2; fi

for tool in xcodebuild xcodegen python3 codesign; do
  command -v "$tool" >/dev/null || { echo "Install $tool on your Mac first."; exit 1; }
done
test -f Configuration/Public.xcconfig || { echo "Configure Public.xcconfig first; see docs/APPLE_DEVICES_V1.md."; exit 1; }
: "${MAX_APPLE_TEAM_ID:?Set MAX_APPLE_TEAM_ID to your Apple Developer team ID}"
: "${MAX_BUILD_NUMBER:?Set MAX_BUILD_NUMBER to an unused TestFlight build number for this app version}"
[[ "$MAX_APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "The Apple team ID must contain 10 capital letters or digits."; exit 1; }
[[ "$MAX_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "The TestFlight build number must be a positive integer."; exit 1; }

output="$project_root/build/internal-beta/$scheme-$MAX_BUILD_NUMBER"
archive="$output/$scheme.xcarchive"
[[ ! -e "$archive" ]] || { echo "This archive already exists: $archive"; exit 1; }
mkdir -p "$output"
xcodegen generate
xcodebuild -project Max.xcodeproj -scheme "$scheme" -configuration Release \
  -destination "$destination" -archivePath "$archive" \
  DEVELOPMENT_TEAM="$MAX_APPLE_TEAM_ID" CURRENT_PROJECT_VERSION="$MAX_BUILD_NUMBER" \
  -allowProvisioningUpdates archive

python3 scripts/verify_beta_archive.py "$archive" "$scheme" "$MAX_BUILD_NUMBER"
codesign --verify --deep --strict "$archive/Products/Applications/$scheme.app"
echo "Signed archive passed metadata and signature checks: $archive"
echo "Open it in Xcode Organizer to upload as TestFlight Internal Only."
