generate:
  flutter_rust_bridge_codegen generate --rust-input=crate --rust-root=$ROOT/rust/fedimintd_mobile --dart-output=$ROOT/lib/
  # `freezed_annotation` requires this build step, which gives us rust-like pattern matching in dart's codegen
  flutter pub run build_runner build --delete-conflicting-outputs

build-android-x86_64:
  $ROOT/scripts/build-android.sh

build-android-arm:
  $ROOT/scripts/build-arm-android.sh

build-linux:
  $ROOT/scripts/build-linux.sh

build-debug-apk:
  $ROOT/docker/build-apk.sh debug

build-release-apk:
  $ROOT/docker/build-apk.sh release

# Scan the latest APK for F-Droid compatibility (checks for Google Play Services dependencies)
scan-apk:
  #!/usr/bin/env bash
  set -euo pipefail
  APK=$(ls -t build/app/outputs/flutter-apk/fedimintd_mobile-*.apk 2>/dev/null | head -1)
  if [ -z "$APK" ]; then
    echo "No APK found. Run 'just build-debug-apk' first."
    exit 1
  fi
  echo "Scanning: $APK"
  fdroid scanner -v --exit-code "$APK"

test-fdroid:
  $ROOT/scripts/test-fdroid.sh

run: build-linux
  flutter run

test:
  flutter test
