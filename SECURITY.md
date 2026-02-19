# Security and Privacy

## Privacy Model

- **No telemetry**: OpenNotch does not collect or transmit any analytics.
- **No network**: The app does not require network access. All data stays local.
- **Explicit permissions**: Permissions are requested only when the user enables a widget that needs them:
  - Calendar widget → EventKit (user must grant)
  - Camera widget → AVFoundation (user must grant)
  - Media/Spotify control → Automation (user must grant)

## Data Storage

- Config: `~/Library/Application Support/OpenNotch/config.toml`
- Notes: `~/Library/Application Support/OpenNotch/notes.db`
- Tray: Ephemeral by default; optional persistence in config

## Threat Model

- No private APIs; public macOS APIs only.
- No code signing bypass or undocumented calls.
- Report vulnerabilities via GitHub Issues (private if sensitive).
