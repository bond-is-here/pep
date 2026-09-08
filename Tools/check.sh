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
pep_sources=(
  RepComet/Appearance.swift RepComet/Core/*.swift RepComet/DesignSystem.swift
  RepComet/Views/*.swift RepComet/RepCometApp.swift
)
if /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  pep_swiftc=(/usr/bin/xcrun swiftc)
  pep_target="$(uname -m)-apple-macosx14.0"
  "${pep_swiftc[@]}" -swift-version 5 -warnings-as-errors -typecheck \
    -target "$pep_target" "${pep_sources[@]}"
else
  "${pep_swiftc[@]}" -swift-version 5 -warnings-as-errors -typecheck \
    -target "$pep_target" -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
    "${pep_sources[@]}"
fi

bash Tests/run-core-tests.sh
