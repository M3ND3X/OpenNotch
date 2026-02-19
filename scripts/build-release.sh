#!/bin/bash
# Full release build: Rust FFI -> regenerate bindings -> Swift app
# Run this to avoid UniFFI bufferOverflow (Rust/Swift ABI mismatch)
set -e
cd "$(dirname "$0")/.."

echo "Building Rust FFI (release)..."
cargo build -p opennotch-ffi --release

echo "Regenerating Swift bindings..."
mkdir -p apps/macos/Sources/Generated
cargo run -p opennotch-bindgen --bin uniffi-bindgen -- \
  generate --library target/release/libopennotch_ffi.dylib \
  --language swift --out-dir apps/macos/Sources/Generated

echo "Building Swift app (release)..."
cd apps/macos && swift build -c release

echo "Done. Run with: apps/macos/.build/release/OpenNotch"
