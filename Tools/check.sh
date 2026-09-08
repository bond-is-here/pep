#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p .build
plutil -lint Pep.xcodeproj/project.pbxproj RepComet/PrivacyInfo.xcprivacy
xmllint --noout Pep.xcodeproj/xcshareddata/xcschemes/Pep.xcscheme

# Typecheck the native source against the local macOS SDK. The app itself is
# built by the workflow against iPhoneOS and the iPhone Simulator SDKs.
pep_swiftc=(/Library/Developer/CommandLineTools/usr/bin/swiftc)
pep_target="$(uname -m)-apple-macosx26.0"
pep_sdk=( -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk )
if pep_xcode_swiftc="$(/usr/bin/xcrun --find swiftc 2>/dev/null)"; then
  pep_swiftc=("$pep_xcode_swiftc")
  pep_target="$(uname -m)-apple-macosx14.0"
  pep_sdk=()
fi
"${pep_swiftc[@]}" -swift-version 5 -warnings-as-errors -typecheck \
  -target "$pep_target" \
  "${pep_sdk[@]}" \
  RepComet/Appearance.swift RepComet/Core/*.swift RepComet/DesignSystem.swift \
  RepComet/Views/*.swift RepComet/RepCometApp.swift

bash Tests/run-core-tests.sh
