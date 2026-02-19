//! User and platform commands.
//!
//! Swift sends these to Rust via dispatch(). Rust never mutates state from Swift directly.

use serde::{Deserialize, Serialize};

use crate::state::ScreenMetrics;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Command {
    // Overlay / activation
    HoverEntered {
        screen_id: String,
    },
    HoverExited {
        screen_id: String,
    },
    ToggleOverlay,
    ToggleSurface,
    SwipeDown {
        screen_id: String,
        delta_y: f64,
    },
    ScreenMetricsChanged {
        screens: Vec<ScreenMetrics>,
    },

    // Settings
    UpdateSetting {
        key: String,
        value: SettingValue,
    },
    ResetSettings,

    // Tray
    TrayAddItems {
        payload: TrayAddPayload,
    },
    TrayRemove {
        item_ids: Vec<String>,
    },
    TraySelect {
        item_id: String,
        add_to_selection: bool,
    },
    TraySelectAll,
    TrayClearSelection,
    TrayRename {
        item_id: String,
        new_name: String,
    },
    TrayQuickLook {
        item_ids: Vec<String>,
    },
    TrayRevealInFinder {
        item_id: String,
    },
    TrayCopy,
    TrayShare {
        item_ids: Vec<String>,
    },

    // Widget interactions (placeholder for later)
    WidgetAction {
        widget_id: String,
        action: String,
    },

    // Platform data (from Swift providers)
    CalendarEventsReceived {
        events_json: String,
    },
    MediaStateReceived {
        state_json: String,
    },
    CameraListReceived {
        cameras_json: String,
    },
    VolumeChanged {
        level: f32,
    },
    PermissionStatusChanged {
        calendar: bool,
        camera: bool,
        automation: bool,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SettingValue {
    Bool(bool),
    String(String),
    U32(u32),
    I32(i32),
    F32(f32),
    StringList(Vec<String>),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrayAddPayload {
    pub file_paths: Vec<String>,
    pub urls: Vec<String>,
    pub text_items: Vec<String>,
    pub bookmark_data: Vec<Vec<u8>>,
}
