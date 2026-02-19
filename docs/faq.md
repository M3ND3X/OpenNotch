# OpenNotch FAQ

## Why Rust + Swift?

Rust provides memory safety, performance, and a strong type system for business logic. Swift/SwiftUI excels at macOS UI and Apple framework integration. UniFFI bridges them cleanly.

## Why not SwiftUI for everything?

The spec requires Rust to own all non-UI logic for testability, portability, and a single source of truth. Swift is kept minimal to avoid logic duplication.

## Does it work on Intel Macs?

Yes. The Rust crate builds for both `aarch64-apple-darwin` and `x86_64-apple-darwin`. The Swift app is universal.

## How do I add a new widget?

1. Implement `WidgetProtocol` in `crates/core/src/widgets/`
2. Register in `WidgetRegistry`
3. Add SwiftUI renderer in `WidgetShellView`
4. If the widget needs Apple APIs, add a Platform Provider in Swift

## Where is the config stored?

`~/Library/Application Support/OpenNotch/config.toml`
