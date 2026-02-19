# OpenNotch Permissions

## Default: Zero Permissions

OpenNotch requests **no permissions** by default. All features work without any system access until you enable widgets that need them.

## Permission Model

| Feature | Permission | When Requested |
|---------|------------|----------------|
| Calendar widget | EventKit (Calendars) | When user enables Calendar widget |
| Camera widget | AVFoundation (Camera) | When user enables Camera widget |
| Media/Spotify control | Automation | When user enables Music/Spotify control |

## Request Flow

1. User enables a widget in Settings
2. Rust sets feature flag; Swift checks permission status
3. If not granted, Swift prompts via system APIs (EventKit, AVFoundation)
4. Swift reports result to Rust via `Command::PermissionStatusChanged`
5. Rust stores status; UI reflects it

## Privacy

- No telemetry
- No network calls
- All data local to `~/Library/Application Support/OpenNotch/`
