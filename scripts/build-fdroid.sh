#!/usr/bin/env bash

#
# F-Droid build script for Fedimint Mobile
#
# This script is invoked by F-Droid's buildserver in two phases:
#   1. prebuild: Install toolchains and download dependencies (network available)
#   2. build: Compile everything (network disabled)
#
# Usage:
#   ./scripts/build_fdroid.sh <versionName> <versionCode> <arch> <phase>
#
# Arguments:
#   versionName: e.g., "0.1.2"
#   versionCode: e.g., "10290"
#   arch: "arm64-v8a" (only supported architecture)
#   phase: "prebuild" or "build"
#
# Example:
#   ./scripts/build_fdroid.sh "0.1.2" "10290" arm64-v8a prebuild
#   ./scripts/build_fdroid.sh "0.1.2" "10290" arm64-v8a build
#

set -ex

# Parse arguments
VERSION_NAME="${1}"
VERSION_CODE="${2}"
ANDROID_ABI="${3}"
BUILD_PHASE="${4}"

if [[ -z "$VERSION_NAME" || -z "$VERSION_CODE" || -z "$ANDROID_ABI" || -z "$BUILD_PHASE" ]]; then
    echo "Usage: $0 <versionName> <versionCode> <arch> <phase>"
    echo "Example: $0 0.1.2 10290 arm64-v8a prebuild"
    exit 1
fi

# Validate architecture
if [[ "$ANDROID_ABI" != "arm64-v8a" ]]; then
    echo "Error: Only arm64-v8a architecture is supported"
    exit 1
fi

# Validate phase
if [[ "$BUILD_PHASE" != "prebuild" && "$BUILD_PHASE" != "build" ]]; then
    echo "Error: Phase must be 'prebuild' or 'build'"
    exit 1
fi

# Set up paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read versions from project files
FLUTTER_VERSION=$(cat "$PROJECT_ROOT/.flutter-version")
NDK_VERSION=$(grep 'ndkVersion' "$PROJECT_ROOT/android/app/build.gradle.kts" | sed 's/.*"\(.*\)".*/\1/')

# Rust target for arm64
RUST_TARGET="aarch64-linux-android"

# Set up environment
export PATH="$HOME/.cargo/bin:$HOME/.flutter/bin:$PATH"

echo "========================================"
echo "Fedimint Mobile F-Droid Build"
echo "========================================"
echo "Version: $VERSION_NAME ($VERSION_CODE)"
echo "Architecture: $ANDROID_ABI"
echo "Phase: $BUILD_PHASE"
echo "Flutter version: $FLUTTER_VERSION"
echo "NDK version: $NDK_VERSION"
echo "========================================"

# Set up Android SDK environment (needed for both phases)
if [[ -z "$ANDROID_SDK_ROOT" ]]; then
    if [[ -d "/opt/android-sdk" ]]; then
        export ANDROID_SDK_ROOT="/opt/android-sdk"
    elif [[ -d "$HOME/android-sdk" ]]; then
        export ANDROID_SDK_ROOT="$HOME/android-sdk"
    fi
fi
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

case "$BUILD_PHASE" in
    prebuild)
        #
        # PREBUILD PHASE
        # Network is available. Install toolchains and download dependencies.
        #

        echo "=== Installing Rust toolchain ==="
        if [[ ! -f "$HOME/.cargo/bin/rustc" ]]; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
                --default-toolchain stable \
                --target "$RUST_TARGET"
        else
            echo "Rust already installed, adding target..."
            rustup target add "$RUST_TARGET"
        fi

        # Reload PATH to pick up cargo
        export PATH="$HOME/.cargo/bin:$PATH"

        echo "=== Installing cargo-ndk ==="
        cargo install cargo-ndk --locked || echo "cargo-ndk already installed"

        echo "=== Installing Flutter SDK ==="
        if [[ ! -d "$HOME/.flutter" ]]; then
            git clone https://github.com/flutter/flutter.git "$HOME/.flutter"
        fi

        cd "$HOME/.flutter"
        git fetch --all --tags
        git checkout "$FLUTTER_VERSION"
        flutter precache --android
        flutter config --no-analytics

        cd "$PROJECT_ROOT"

        echo "=== Installing Flutter dependencies ==="
        flutter pub get

        echo "=== Installing Android NDK ==="
        if [[ ! -d "$ANDROID_SDK_ROOT/ndk/$NDK_VERSION" ]]; then
            yes | sdkmanager --install "ndk;$NDK_VERSION"
        else
            echo "NDK $NDK_VERSION already installed"
        fi

        echo "=== Pre-fetching Rust dependencies ==="
        cd "$PROJECT_ROOT/rust/fedimintd_mobile"
        cargo fetch

        echo "=== Prebuild complete ==="
        ;;

    build)
        #
        # BUILD PHASE
        # Network is disabled. Compile from cached dependencies.
        #

        # Set up Android NDK paths
        # Check various possible locations
        if [[ -n "$ANDROID_NDK_HOME" ]]; then
            : # Already set
        elif [[ -n "$ANDROID_SDK_ROOT" ]]; then
            export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"
        elif [[ -n "$ANDROID_HOME" ]]; then
            export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"
        elif [[ -d "/opt/android-sdk/ndk/$NDK_VERSION" ]]; then
            # F-Droid buildserver location
            export ANDROID_NDK_HOME="/opt/android-sdk/ndk/$NDK_VERSION"
        elif [[ -d "$HOME/android-sdk/ndk/$NDK_VERSION" ]]; then
            export ANDROID_NDK_HOME="$HOME/android-sdk/ndk/$NDK_VERSION"
        else
            echo "Error: No Android NDK found. Set ANDROID_SDK_ROOT or ANDROID_NDK_HOME"
            echo "Looked for NDK version: $NDK_VERSION"
            echo "Searched in: /opt/android-sdk/ndk, \$HOME/android-sdk/ndk"
            exit 1
        fi
        export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"

        echo "Using NDK at: $ANDROID_NDK_HOME"

        # Set up bindgen for cross-compilation
        export BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android="--sysroot=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot -I$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include -I$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/aarch64-linux-android"

        # Create jniLibs directory
        JNI_LIBS_DIR="$PROJECT_ROOT/android/app/src/main/jniLibs/arm64-v8a"
        mkdir -p "$JNI_LIBS_DIR"

        echo "=== Building Rust library ==="
        cd "$PROJECT_ROOT/rust/fedimintd_mobile"

        # Platform 28 required: aws-lc-sys uses getentropy() which needs Android API 28+
        cargo ndk \
            -t arm64-v8a \
            --platform 28 \
            -o "$JNI_LIBS_DIR" \
            build --release --locked --target "$RUST_TARGET"

        # Move .so files from nested directories to JNI_LIBS_DIR root
        find "$JNI_LIBS_DIR" -mindepth 2 -type f -name '*.so' -exec mv {} "$JNI_LIBS_DIR" \;
        find "$JNI_LIBS_DIR" -mindepth 1 -type d -empty -delete

        # Copy libc++_shared.so (required for Android)
        cp "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" \
            "$JNI_LIBS_DIR/" 2>/dev/null || true

        echo "=== Building Flutter APK ==="
        cd "$PROJECT_ROOT"

        flutter build apk \
            --release \
            --build-number="$VERSION_CODE" \
            --build-name="$VERSION_NAME"

        echo "=== Build complete ==="
        echo "APK location: $PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
        ;;
esac

echo "Done!"
