# Contributing to OpenNotch

## Code Standards

- **Rust**: Follow `cargo fmt` and `cargo clippy`. Use `thiserror` for errors, `tracing` for logging.
- **Swift**: Use Swift 5.9+, SwiftUI. Minimal logic in Swift—delegate to Rust via `dispatch(Command)`.
- **Architecture**: Rust owns all business logic. Swift is a thin UI host.

## Module Ownership

| Module | Owner | Responsibility |
|--------|-------|----------------|
| `crates/core` | Rust | State machine, config, tray, notes, widgets |
| `crates/ffi` | Rust | UniFFI types and AppCore bridge |
| `crates/platform` | Rust | Paths, file ops (public APIs only) |
| `apps/macos` | Swift | NSPanel, SwiftUI views, effects executor |

## Pull Request Process

1. Run `just fmt` and `just lint`
2. Run `just test`
3. Ensure `just build` succeeds
