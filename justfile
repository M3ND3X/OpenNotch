# OpenNotch build and run commands
# Requires: Rust (rustup), Swift/Xcode, just

# Default recipe - full build
build: build-rust build-ffi build-swift

# Build Rust workspace
build-rust:
    cargo build --workspace --release

# Generate UniFFI Swift bindings from built cdylib
build-ffi: build-rust
    mkdir -p apps/macos/Sources/Generated
    cargo run -p opennotch-bindgen --bin uniffi-bindgen -- generate --library target/release/libopennotch_ffi.dylib --language swift --out-dir apps/macos/Sources/Generated

# Build Swift macOS app (requires build-ffi first)
# Run from OpenNotch root: just build-swift
build-swift: build-ffi
    cd apps/macos && swift build -c release

# Run tests
test:
    cargo test --workspace

# Format code
fmt:
    cargo fmt --all

# Lint
lint:
    cargo clippy --workspace --all-targets -- -D warnings

# Run the app (build first)
run: build
    ./apps/macos/.build/release/OpenNotch
