#!/usr/bin/env bash

cd $ROOT/rust/fedimintd_mobile
# Platform 28 required: aws-lc-sys uses getentropy() which needs Android API 28+
cargo ndk -t arm64-v8a --platform 28 -o $ROOT/android/app/src/main/jniLibs build --release --target aarch64-linux-android
cp $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so $ROOT/android/app/src/main/jniLibs/arm64-v8a/
chmod +w $ROOT/android/app/src/main/jniLibs/arm64-v8a/libc++_shared.so
