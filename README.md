# OpenNotch

A notch-anchored top-center overlay hub for macOS, inspired by Dynamic Island patterns. Built with Rust (business logic) and SwiftUI (rendering).

## Features

- **Nook**: Configurable widget strip (Calendar, Shortcuts, Camera, Notes, Media)
- **Tray**: Temporary file shelf with drag-and-drop, Quick Look, share
- **Overlay**: Top-center anchored, multi-monitor support
- **Privacy**: No telemetry, no network, all data local

## Requirements

- macOS 14.6+ (Sonoma)
- Apple Silicon or Intel
- Rust (via rustup)
- Swift 5.9+ / Xcode 15+

## Build

```bash
# Install just (optional): cargo install just
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

## Project Structure

```
OpenNotch/
├── crates/
│   ├── core/      # State machine, config, tray, notes, widgets
│   ├── ffi/       # UniFFI bridge (Rust → Swift)
│   └── platform/  # macOS-safe helpers
├── apps/
│   └── macos/     # SwiftUI app
├── docs/          # Architecture, setup, permissions
└── justfile       # Build commands
```

## License

Apache-2.0
