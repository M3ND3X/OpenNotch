//! OpenNotch core: state machine, event bus, config, tray, notes, widgets.
//!
//! All business logic lives here. Swift is a thin UI host.

pub mod app_core;
pub mod commands;
pub mod config;
pub mod effects;
pub mod state;
pub mod tray;
pub mod notes;
pub mod widgets;

pub use app_core::AppCore;
pub use commands::Command;
pub use effects::Effect;
pub use state::{AppState, UiSnapshot, ScreenMetrics, NookViewModel, TrayViewModel, WidgetViewModel, SettingsModel, PermissionStatus, Surface};
