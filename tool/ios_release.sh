#!/usr/bin/env bash
# Builds the App Store IPA and, given an App Store Connect API key, uploads it.
#
#   bash tool/ios_release.sh                 # build only
#   ASC_KEY_ID=ABC123XYZ ASC_ISSUER_ID=69a6de7f-... bash tool/ios_release.sh
#
# macOS with Xcode only. The API key's .p8 must be saved as
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 — altool looks there.
# See IOS_RELEASE.md, sections 2 and 5.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "$(uname)" != "Darwin" ]]; then
  echo "iOS builds need macOS with Xcode." >&2
  exit 1
fi

version=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
echo "Building Teleconsult $version for the App Store"

flutter pub get
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

ipa=$(ls build/ios/ipa/*.ipa | head -n 1)
echo "IPA: $ipa"

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
  echo "ASC_KEY_ID / ASC_ISSUER_ID not set — skipping upload."
  echo "Upload with Transporter, or re-run with both set."
  exit 0
fi

xcrun altool --upload-app --type ios --file "$ipa" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "Uploaded. It appears in App Store Connect → TestFlight once processed (5–30 min)."
