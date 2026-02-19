# OpenNotch Threat Model

## Scope

- Local macOS app
- No network
- No telemetry
- Public APIs only

## Assets

- User config (preferences)
- Notes (SQLite)
- Tray items (file references, bookmarks)
- Screen layout preferences

## Threats

| Threat | Mitigation |
|--------|------------|
| Private API abuse | No private APIs; public frameworks only |
| Data exfiltration | No network; all data local |
| Malicious config | Rust validates schema; migrations are additive |
| File access abuse | Security-scoped bookmarks; Swift resolves |
| Permission creep | Request only when widget enabled |

## Out of Scope

- Network-based attacks (no network)
- Supply chain (assume trusted build)
- Physical access (OS-level protection)
