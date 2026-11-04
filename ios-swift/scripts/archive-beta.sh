#!/bin/bash
set -euo pipefail

# Run on a Mac signed into the app owner's Apple Developer account in Xcode.
# Produces an IPA for review. It does not upload or publish the app.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
command -v xcodebuild >/dev/null || { echo "Install Xcode on a Mac first."; exit 1; }
command -v xcodegen >/dev/null || { echo "Install XcodeGen first."; exit 1; }
test -f Configuration/Public.xcconfig || { echo "Configure Public.xcconfig first; see docs/RELEASE_SETUP.md."; exit 1; }
: "${MAX_APPLE_TEAM_ID:?Set MAX_APPLE_TEAM_ID to your Apple Developer team ID}"
[[ "$MAX_APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "The Apple team ID must contain 10 letters or digits."; exit 1; }

xcodegen generate
xcodebuild -project Max.xcodeproj -scheme Max -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Max.xcarchive \
  DEVELOPMENT_TEAM="$MAX_APPLE_TEAM_ID" -allowProvisioningUpdates archive

python3 - <<'PY'
import os, plistlib
with open('build/ExportOptions.plist', 'wb') as file:
    plistlib.dump({'method': 'app-store-connect', 'destination': 'export',
                  'signingStyle': 'automatic', 'teamID': os.environ['MAX_APPLE_TEAM_ID']}, file)
PY
xcodebuild -exportArchive -archivePath build/Max.xcarchive \
  -exportPath build/Beta -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates
echo "IPA exported to ios-swift/build/Beta. Review it before uploading through Xcode or Transporter."
