# OpenNotch Setup

## Prerequisites

- macOS 14.6+ (Sonoma)
- Rust (via rustup): `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Swift 5.9+ / Xcode 15+
- [just](https://github.com/casey/just) (optional): `cargo install just`

## Build

```bash
cd OpenNotch
just build
```

Or manually:

```bash
cargo build --workspace --release
cargo run -p opennotch-bindgen --bin uniffi-bindgen -- generate --library --language swift --out-dir apps/macos/Sources/Generated target/release/libopennotch_ffi.dylib
cd apps/macos && swift build -c release
```

## Run

```bash
just run
# or
./apps/macos/.build/release/OpenNotch
```

## Troubleshooting

- **"library 'opennotch_ffi' not found"**: Ensure `cargo build --workspace --release` completed and `target/release/libopennotch_ffi.dylib` exists
- **"uniffi-bindgen not found"**: Use `cargo run -p opennotch-bindgen --bin uniffi-bindgen` from the workspace root
- **Swift build fails**: Ensure you're building from the OpenNotch root or that `../../target/release` resolves correctly
