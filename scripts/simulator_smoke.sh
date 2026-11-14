#!/bin/bash
set -euo pipefail
mkdir -p validation
xcodebuild -project game/wi.xcodeproj -target wi -configuration Distribution \
  -sdk iphonesimulator ARCHS=arm64 VALID_ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=15.0 \
  CLANG_CXX_LANGUAGE_STANDARD=gnu++11 CLANG_CXX_LIBRARY=libc++ \
  SYMROOT="$PWD/build-simulator" build > validation/simulator-build.log 2>&1
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import sys,json; d=json.load(sys.stdin); a=[v for vs in d["devices"].values() for v in vs if "Pro Max" in v["name"]]; assert a,"No Pro Max simulator"; print(a[0]["udid"])')
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" build-simulator/Distribution-iphonesimulator/wi.app
xcrun simctl launch "$DEVICE" com.luoenzhen.warfare
sleep 12
xcrun simctl io "$DEVICE" screenshot validation/iphone-launch.png
# Terminate succeeds only if the app survived startup.
xcrun simctl terminate "$DEVICE" com.luoenzhen.warfare
xcrun simctl shutdown "$DEVICE"
