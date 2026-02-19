# OpenNotch Architecture

## Overview

OpenNotch follows a **Rust-heavy, SwiftUI-thin** architecture:

- **Rust** owns all business logic: state machine, config, tray, notes, widgets
- **Swift** is a thin host: NSPanel/window plumbing, SwiftUI rendering, Apple API calls
- **UniFFI** bridges the two via a stable FFI

## Data Flow

```
User Input (Swift) → dispatch(Command) → Rust Reducer → (State, Effects)
                                                              ↓
Swift UI ← snapshot() ← Rust State                    Swift executes Effects
```

- Swift **never** mutates state directly
- All mutations go through `dispatch(Command)`
- Effects (open URL, Quick Look, share) are returned from `dispatch` and executed by Swift

## Module Layout

| Crate | Responsibility |
|-------|----------------|
| `opennotch-core` | State machine, config, tray, notes, widgets |
| `opennotch-ffi` | UniFFI types, AppCore bridge |
| `opennotch-platform` | Paths, file ops (public APIs only) |
| `apps/macos` | NSPanel overlay, SwiftUI views, effects executor |

## Threading

- Rust core runs on a dedicated background thread (future)
- UniFFI calls are thread-safe (Arc/RwLock in Rust)
- Swift marshals snapshot updates to main thread
