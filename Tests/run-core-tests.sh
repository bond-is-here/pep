#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

# A configured Xcode installation only needs the standard Swift package command.
if [[ "${1:-}" != "--command-line-tools" ]]; then
    exec swift test
fi

# Optional local fallback: use installed Command Line Tools and the XCTest
# frameworks already bundled with Xcode. This changes no system settings.
repcomet_platform="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer"
repcomet_frameworks="$repcomet_platform/Library/Frameworks"
repcomet_libraries="$repcomet_platform/usr/lib"

DEVELOPER_DIR=/Library/Developer/CommandLineTools \
    /Library/Developer/CommandLineTools/usr/bin/swift build --build-tests \
    -Xswiftc -gnone \
    -Xswiftc -F -Xswiftc "$repcomet_frameworks" \
    -Xswiftc -I -Xswiftc "$repcomet_libraries" \
    -Xlinker -F -Xlinker "$repcomet_frameworks" \
    -Xlinker -L -Xlinker "$repcomet_libraries" \
    -Xlinker -rpath -Xlinker "$repcomet_frameworks" \
    -Xlinker -rpath -Xlinker "$repcomet_libraries"

DYLD_FRAMEWORK_PATH="$repcomet_frameworks:$repcomet_platform/Library/PrivateFrameworks" \
    DYLD_LIBRARY_PATH="$repcomet_libraries" \
    /Applications/Xcode.app/Contents/Developer/usr/bin/xctest \
    .build/debug/RepCometCorePackageTests.xctest
