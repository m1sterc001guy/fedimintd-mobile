#!/usr/bin/env bash

unset CC_aarch64_linux_android
unset CXX_aarch64_linux_android
cargo build --release --manifest-path $ROOT/rust/fedimintd_mobile/Cargo.toml --target-dir $ROOT/rust/fedimintd_mobile/target
