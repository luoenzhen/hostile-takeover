#!/bin/bash
set -euo pipefail
mkdir -p validation
# Report the exact stage and fail with diagnostics instead of hanging.
set -x
timed() {
  python3 -c 'import subprocess,sys; subprocess.run(sys.argv[1:], check=True, timeout=180)' "$@"
}
xcodebuild -project game/wi.xcodeproj -target wi -configuration Distribution \
  -sdk iphonesimulator ARCHS=arm64 VALID_ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=15.0 \
  CLANG_CXX_LANGUAGE_STANDARD=gnu++11 CLANG_CXX_LIBRARY=libc++ \
  SYMROOT="$PWD/build-simulator" build > validation/simulator-build.log 2>&1
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import sys,json; d=json.load(sys.stdin); a=[v for vs in d["devices"].values() for v in vs if "Pro Max" in v["name"]]; assert a,"No Pro Max simulator"; print(a[0]["udid"])')
timed xcrun simctl boot "$DEVICE"
timed xcrun simctl bootstatus "$DEVICE" -b
timed xcrun simctl install "$DEVICE" build-simulator/Distribution-iphonesimulator/wi.app
export SIMCTL_CHILD_WI_CAPTURE_STARTUP=1
LAUNCH=$(timed xcrun simctl launch --stdout="$PWD/validation/app-stdout.log" --stderr="$PWD/validation/app-stderr.log" "$DEVICE" com.luoenzhen.warfare)
printf '%s\n' "$LAUNCH"
PID=${LAUNCH##*: }
trap 'xcrun simctl spawn "$DEVICE" log show --last 5m --style compact --predicate '\''process == "wi"'\'' > validation/app-system.log 2>&1 || true' EXIT
APP_DATA=$(xcrun simctl get_app_container "$DEVICE" com.luoenzhen.warfare data)
VISIBLE=0
for attempt in 1 2 3; do
  sleep 30
  timed xcrun simctl io "$DEVICE" screenshot validation/iphone-launch.png
  if [[ -f "$APP_DATA/tmp/wi-startup.png" ]]; then
    cp "$APP_DATA/tmp/wi-startup.png" validation/iphone-app-view.png
  fi
  if swift scripts/check_screenshot.swift validation/iphone-launch.png; then
    VISIBLE=1
    break
  fi
done
if [[ "$VISIBLE" != 1 ]]; then
  /usr/bin/sample "$PID" 3 -file validation/app-stack.txt || true
  cat validation/app-stdout.log validation/app-stderr.log
  exit 1
fi
# Terminate succeeds only if the app survived startup.
xcrun simctl terminate "$DEVICE" com.luoenzhen.warfare
