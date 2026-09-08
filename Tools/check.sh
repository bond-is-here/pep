#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p .build
plutil -lint Pep.xcodeproj/project.pbxproj RepComet/PrivacyInfo.xcprivacy
xmllint --noout Pep.xcodeproj/xcshareddata/xcschemes/Pep.xcscheme

# Typecheck the native source against the local macOS SDK. The app itself is
# built by the workflow against iPhoneOS and the iPhone Simulator SDKs.
xcrun swiftc -swift-version 5 -warnings-as-errors -typecheck \
  -target "$(uname -m)-apple-macosx14.0" \
  RepComet/Appearance.swift RepComet/Core/*.swift RepComet/DesignSystem.swift \
  RepComet/Views/*.swift RepComet/RepCometApp.swift

bash Tests/run-core-tests.sh
