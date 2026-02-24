#!/usr/bin/env bash

#
# Test F-Droid build locally using the fdroidserver Docker image
#
# This script simulates the F-Droid build environment by:
# 1. Installing system dependencies (sudo section)
# 2. Running the prebuild phase
# 3. Running the build phase
#
# Usage:
#   ./scripts/test-fdroid.sh [version] [versionCode]
#
# Examples:
#   ./scripts/test-fdroid.sh                    # Uses version from pubspec.yaml
#   ./scripts/test-fdroid.sh 0.1.3 10390        # Explicit version
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments or read from pubspec.yaml
if [[ -n "$1" && -n "$2" ]]; then
    VERSION_NAME="$1"
    VERSION_CODE="$2"
else
    FULL_VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: //')
    VERSION_NAME=$(echo "$FULL_VERSION" | cut -d'+' -f1)
    VERSION_CODE=$(echo "$FULL_VERSION" | cut -d'+' -f2)
fi

ARCH="arm64-v8a"
IMAGE="registry.gitlab.com/fdroid/fdroidserver:buildserver"

echo "========================================"
echo "F-Droid Build Test"
echo "========================================"
echo "Version: $VERSION_NAME ($VERSION_CODE)"
echo "Architecture: $ARCH"
echo "Image: $IMAGE"
echo "========================================"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Pull the image if not present
echo "Pulling F-Droid buildserver image (if needed)..."
docker pull "$IMAGE"

echo ""
echo "Starting F-Droid build test..."
echo ""

# Run the build in Docker
docker run --rm \
    -v "$PROJECT_ROOT":/repo \
    -w /repo \
    "$IMAGE" \
    bash -c "
        set -ex

        echo '=== Installing system dependencies (sudo section) ==='
        apt-get update
        apt-get install -y \
            build-essential \
            clang \
            libclang-dev \
            cmake \
            ninja-build \
            pkg-config \
            make \
            wget \
            curl \
            git \
            unzip

        echo ''
        echo '=== Running prebuild phase ==='
        ./scripts/build-fdroid.sh '$VERSION_NAME' '$VERSION_CODE' '$ARCH' prebuild

        echo ''
        echo '=== Running build phase ==='
        ./scripts/build-fdroid.sh '$VERSION_NAME' '$VERSION_CODE' '$ARCH' build

        echo ''
        echo '=== Build complete ==='
        ls -la build/app/outputs/flutter-apk/
    "

echo ""
echo "========================================"
echo "F-Droid build test completed!"
echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
echo "========================================"
