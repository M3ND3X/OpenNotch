//! UniFFI bridge for OpenNotch.
//!
//! Exposes AppCore and types to Swift via proc macros.

use opennotch_core::commands::{
    SettingValue as CoreSettingValue, TrayAddPayload as CoreTrayAddPayload,
};
use opennotch_core::{AppCore as CoreAppCore, Command as CoreCommand, Effect as CoreEffect};
use std::sync::Arc;

uniffi::setup_scaffolding!();

// FFI types with uniffi::Record - convert to/from core
#[derive(uniffi::Record, Clone)]
pub struct ScreenMetrics {
    pub screen_id: String,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub safe_area_top: f64,
    pub safe_area_left: f64,
    pub safe_area_right: f64,
    pub safe_area_bottom: f64,
}

impl From<opennotch_core::state::ScreenMetrics> for ScreenMetrics {
    fn from(s: opennotch_core::state::ScreenMetrics) -> Self {
        Self {
            screen_id: s.screen_id,
            x: s.x,
            y: s.y,
            width: s.width,
            height: s.height,
            safe_area_top: s.safe_area_top,
            safe_area_left: s.safe_area_left,
            safe_area_right: s.safe_area_right,
            safe_area_bottom: s.safe_area_bottom,
        }
    }
}

impl From<ScreenMetrics> for opennotch_core::state::ScreenMetrics {
    fn from(s: ScreenMetrics) -> Self {
        Self {
            screen_id: s.screen_id,
            x: s.x,
            y: s.y,
            width: s.width,
            height: s.height,
            safe_area_top: s.safe_area_top,
            safe_area_left: s.safe_area_left,
            safe_area_right: s.safe_area_right,
            safe_area_bottom: s.safe_area_bottom,
        }
    }
}

#[derive(uniffi::Record, Clone)]
pub struct PermissionStatus {
    pub calendar: bool,
    pub camera: bool,
    pub automation: bool,
}

impl From<opennotch_core::state::PermissionStatus> for PermissionStatus {
    fn from(p: opennotch_core::state::PermissionStatus) -> Self {
        Self {
            calendar: p.calendar,
            camera: p.camera,
            automation: p.automation,
        }
    }
}

#[derive(uniffi::Record, Clone, Default)]
pub struct WidgetViewModel {
    pub id: String,
    pub name: String,
    pub compact_title: String,
    pub compact_content: String,
    pub expanded_content: String,
    pub is_expanded: bool,
}

impl From<opennotch_core::state::WidgetViewModel> for WidgetViewModel {
    fn from(w: opennotch_core::state::WidgetViewModel) -> Self {
        Self {
            id: w.id,
            name: w.name,
            compact_title: w.compact_title,
            compact_content: w.compact_content,
            expanded_content: w.expanded_content,
            is_expanded: w.is_expanded,
        }
    }
}

#[derive(uniffi::Record, Clone)]
pub struct TrayItemViewModel {
    pub id: String,
    pub display_name: String,
    pub item_type: String,
    pub size_hint: String,
    pub source_value: String,
    pub is_selected: bool,
}

impl From<opennotch_core::state::TrayItemViewModel> for TrayItemViewModel {
    fn from(t: opennotch_core::state::TrayItemViewModel) -> Self {
        Self {
            id: t.id,
            display_name: t.display_name,
            item_type: t.item_type,
            size_hint: t.size_hint,
            source_value: t.source_value,
            is_selected: t.is_selected,
        }
    }
}

#[derive(uniffi::Record, Clone, Default)]
pub struct TrayViewModel {
    pub items: Vec<TrayItemViewModel>,
    pub selected_ids: Vec<String>,
}

impl From<opennotch_core::state::TrayViewModel> for TrayViewModel {
    fn from(t: opennotch_core::state::TrayViewModel) -> Self {
        Self {
            items: t.items.into_iter().map(Into::into).collect(),
            selected_ids: t.selected_ids,
        }
    }
}

#[derive(uniffi::Record, Clone, Default)]
pub struct NookViewModel {
    pub widgets: Vec<WidgetViewModel>,
}

impl From<opennotch_core::state::NookViewModel> for NookViewModel {
    fn from(n: opennotch_core::state::NookViewModel) -> Self {
        Self {
            widgets: n.widgets.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(uniffi::Record, Clone)]
pub struct SettingsModel {
    pub start_at_login: bool,
    pub hotkey: String,
    pub show_in_fullscreen: String,
    pub media_source: String,
    pub prefer_round_buttons: bool,
    pub translucent_notch_background: bool,
    pub always_open_on_hover: bool,
    pub disable_haptics: bool,
    pub prevent_close_on_mouse_leave: bool,
    pub lock_while_typing: bool,
    pub content_padding: u32,
    pub notch_width_fine_tune: i32,
    pub notch_height_fine_tune: i32,
    pub handler_enable: bool,
    pub handler_width: u32,
    pub handler_height: u32,
    pub transparent_handler: bool,
    pub demo_mode: bool,
    pub hover_delay_ms: u32,
    pub gesture_sensitivity: f32,
    pub reduced_motion: bool,
    pub appear_on_all_spaces: bool,
    pub enabled_displays: Vec<String>,
    pub allow_gestures_on_hover: bool,
    pub open_close_vertical_gestures: bool,
    pub control_media_horizontal: bool,
    pub invert_media_gestures: bool,
    pub live_activities_enable: bool,
    pub live_activities_hide_in_non_notched: bool,
    pub live_activities_inactivity_timeout: u32,
    pub live_activities_enable_interactive: bool,
    pub live_activities_enable_quick_peek: bool,
    pub live_activities_unhide_automatically: bool,
    pub live_activities_show_song_change: bool,
    pub live_activities_hud_replacement_enable: bool,
    pub live_activities_hud_disable_colors: bool,
    pub live_activities_hud_show_all_screens: bool,
    pub live_activities_album_corner_radius: u32,
    pub live_activities_effect_type: String,
    pub live_activities_colored_effects: bool,
    pub live_activities_activities_enabled: Vec<String>,
    pub nook_enable: bool,
    pub nook_show_dividers: bool,
    pub tray_ephemeral: bool,
    pub tray_max_items: u32,
    pub tray_width: u32,
    pub drop_area_width: u32,
    pub drop_area_pipelines_enabled: Vec<String>,
    pub widgets_enabled: Vec<String>,
    pub widgets_order: Vec<String>,
}

impl From<opennotch_core::state::SettingsModel> for SettingsModel {
    fn from(s: opennotch_core::state::SettingsModel) -> Self {
        Self {
            start_at_login: s.start_at_login,
            hotkey: s.hotkey,
            show_in_fullscreen: s.show_in_fullscreen,
            media_source: s.media_source,
            prefer_round_buttons: s.prefer_round_buttons,
            translucent_notch_background: s.translucent_notch_background,
            always_open_on_hover: s.always_open_on_hover,
            disable_haptics: s.disable_haptics,
            prevent_close_on_mouse_leave: s.prevent_close_on_mouse_leave,
            lock_while_typing: s.lock_while_typing,
            content_padding: s.content_padding,
            notch_width_fine_tune: s.notch_width_fine_tune,
            notch_height_fine_tune: s.notch_height_fine_tune,
            handler_enable: s.handler_enable,
            handler_width: s.handler_width,
            handler_height: s.handler_height,
            transparent_handler: s.transparent_handler,
            demo_mode: s.demo_mode,
            hover_delay_ms: s.hover_delay_ms,
            gesture_sensitivity: s.gesture_sensitivity,
            reduced_motion: s.reduced_motion,
            appear_on_all_spaces: s.appear_on_all_spaces,
            enabled_displays: s.enabled_displays,
            allow_gestures_on_hover: s.allow_gestures_on_hover,
            open_close_vertical_gestures: s.open_close_vertical_gestures,
            control_media_horizontal: s.control_media_horizontal,
            invert_media_gestures: s.invert_media_gestures,
            live_activities_enable: s.live_activities_enable,
            live_activities_hide_in_non_notched: s.live_activities_hide_in_non_notched,
            live_activities_inactivity_timeout: s.live_activities_inactivity_timeout,
            live_activities_enable_interactive: s.live_activities_enable_interactive,
            live_activities_enable_quick_peek: s.live_activities_enable_quick_peek,
            live_activities_unhide_automatically: s.live_activities_unhide_automatically,
            live_activities_show_song_change: s.live_activities_show_song_change,
            live_activities_hud_replacement_enable: s.live_activities_hud_replacement_enable,
            live_activities_hud_disable_colors: s.live_activities_hud_disable_colors,
            live_activities_hud_show_all_screens: s.live_activities_hud_show_all_screens,
            live_activities_album_corner_radius: s.live_activities_album_corner_radius,
            live_activities_effect_type: s.live_activities_effect_type,
            live_activities_colored_effects: s.live_activities_colored_effects,
            live_activities_activities_enabled: s.live_activities_activities_enabled,
            nook_enable: s.nook_enable,
            nook_show_dividers: s.nook_show_dividers,
            tray_ephemeral: s.tray_ephemeral,
            tray_max_items: s.tray_max_items,
            tray_width: s.tray_width,
            drop_area_width: s.drop_area_width,
            drop_area_pipelines_enabled: s.drop_area_pipelines_enabled,
            widgets_enabled: s.widgets_enabled,
            widgets_order: s.widgets_order,
        }
    }
}

#[derive(uniffi::Record, Clone)]
pub struct UiSnapshot {
    pub expansion_progress: f32,
    pub reduced_motion: bool,
    pub active_surface: String,
    pub nook: NookViewModel,
    pub tray: TrayViewModel,
    pub settings: SettingsModel,
    pub permissions: PermissionStatus,
}

impl From<opennotch_core::state::UiSnapshot> for UiSnapshot {
    fn from(s: opennotch_core::state::UiSnapshot) -> Self {
        Self {
            expansion_progress: s.expansion_progress,
            reduced_motion: s.reduced_motion,
            active_surface: s.active_surface,
            nook: s.nook.into(),
            tray: s.tray.into(),
            settings: s.settings.into(),
            permissions: s.permissions.into(),
        }
    }
}

/// Setting value for UpdateSetting (StringValue avoids Swift keyword clash)
#[derive(uniffi::Enum, Clone)]
pub enum SettingValue {
    Bool { value: bool },
    StringValue { value: String },
    U32 { value: u32 },
    I32 { value: i32 },
    F32 { value: f32 },
    StringList { value: Vec<String> },
}

impl From<SettingValue> for CoreSettingValue {
    fn from(s: SettingValue) -> Self {
        match s {
            SettingValue::Bool { value } => CoreSettingValue::Bool(value),
            SettingValue::StringValue { value } => CoreSettingValue::String(value),
            SettingValue::U32 { value } => CoreSettingValue::U32(value),
            SettingValue::I32 { value } => CoreSettingValue::I32(value),
            SettingValue::F32 { value } => CoreSettingValue::F32(value),
            SettingValue::StringList { value } => CoreSettingValue::StringList(value),
        }
    }
}

/// Tray add payload (simplified - no bookmark_data in FFI for now)
#[derive(uniffi::Record, Clone)]
pub struct TrayAddPayload {
    pub file_paths: Vec<String>,
    pub urls: Vec<String>,
    pub text_items: Vec<String>,
}

impl From<TrayAddPayload> for CoreTrayAddPayload {
    fn from(p: TrayAddPayload) -> Self {
        CoreTrayAddPayload {
            file_paths: p.file_paths,
            urls: p.urls,
            text_items: p.text_items,
            bookmark_data: vec![],
        }
    }
}

/// Commands from Swift to Rust
#[derive(uniffi::Enum, Clone)]
pub enum Command {
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
    UpdateSetting {
        key: String,
        value: SettingValue,
    },
    ResetSettings,
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
    WidgetAction {
        widget_id: String,
        action: String,
    },
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

impl From<Command> for CoreCommand {
    fn from(c: Command) -> Self {
        match c {
            Command::HoverEntered { screen_id } => CoreCommand::HoverEntered { screen_id },
            Command::HoverExited { screen_id } => CoreCommand::HoverExited { screen_id },
            Command::ToggleOverlay => CoreCommand::ToggleOverlay,
            Command::ToggleSurface => CoreCommand::ToggleSurface,
            Command::SwipeDown { screen_id, delta_y } => {
                CoreCommand::SwipeDown { screen_id, delta_y }
            }
            Command::ScreenMetricsChanged { screens } => CoreCommand::ScreenMetricsChanged {
                screens: screens.into_iter().map(Into::into).collect(),
            },
            Command::UpdateSetting { key, value } => CoreCommand::UpdateSetting {
                key,
                value: value.into(),
            },
            Command::ResetSettings => CoreCommand::ResetSettings,
            Command::TrayAddItems { payload } => CoreCommand::TrayAddItems {
                payload: payload.into(),
            },
            Command::TrayRemove { item_ids } => CoreCommand::TrayRemove { item_ids },
            Command::TraySelect {
                item_id,
                add_to_selection,
            } => CoreCommand::TraySelect {
                item_id,
                add_to_selection,
            },
            Command::TraySelectAll => CoreCommand::TraySelectAll,
            Command::TrayClearSelection => CoreCommand::TrayClearSelection,
            Command::TrayRename { item_id, new_name } => {
                CoreCommand::TrayRename { item_id, new_name }
            }
            Command::TrayQuickLook { item_ids } => CoreCommand::TrayQuickLook { item_ids },
            Command::TrayRevealInFinder { item_id } => CoreCommand::TrayRevealInFinder { item_id },
            Command::TrayCopy => CoreCommand::TrayCopy,
            Command::TrayShare { item_ids } => CoreCommand::TrayShare { item_ids },
            Command::WidgetAction { widget_id, action } => {
                CoreCommand::WidgetAction { widget_id, action }
            }
            Command::CalendarEventsReceived { events_json } => {
                CoreCommand::CalendarEventsReceived { events_json }
            }
            Command::MediaStateReceived { state_json } => {
                CoreCommand::MediaStateReceived { state_json }
            }
            Command::CameraListReceived { cameras_json } => {
                CoreCommand::CameraListReceived { cameras_json }
            }
            Command::VolumeChanged { level } => CoreCommand::VolumeChanged { level },
            Command::PermissionStatusChanged {
                calendar,
                camera,
                automation,
            } => CoreCommand::PermissionStatusChanged {
                calendar,
                camera,
                automation,
            },
        }
    }
}

/// Effects for Swift to execute
#[derive(uniffi::Enum, Clone)]
pub enum Effect {
    OpenUrl { url: String },
    ShowQuickLook { paths: Vec<String> },
    RevealInFinder { path: String },
    CopyToPasteboard { paths: Vec<String> },
    ShareItems { item_ids: Vec<String> },
    RenameFile { old_path: String, new_path: String },
    RequestPermission { permission: String },
    RunShortcut { name: String },
    None,
}

impl From<CoreEffect> for Effect {
    fn from(e: CoreEffect) -> Self {
        match e {
            CoreEffect::OpenUrl { url } => Effect::OpenUrl { url },
            CoreEffect::ShowQuickLook { paths } => Effect::ShowQuickLook { paths },
            CoreEffect::RevealInFinder { path } => Effect::RevealInFinder { path },
            CoreEffect::CopyToPasteboard { paths } => Effect::CopyToPasteboard { paths },
            CoreEffect::ShareItems { item_ids } => Effect::ShareItems { item_ids },
            CoreEffect::RenameFile { old_path, new_path } => {
                Effect::RenameFile { old_path, new_path }
            }
            CoreEffect::RequestPermission { permission } => {
                Effect::RequestPermission { permission }
            }
            CoreEffect::RunShortcut { name } => Effect::RunShortcut { name },
            CoreEffect::None => Effect::None,
        }
    }
}

/// AppCore - main entry point. Wraps opennotch_core::AppCore.
#[derive(uniffi::Object)]
pub struct AppCore {
    inner: Arc<CoreAppCore>,
}

#[uniffi::export]
impl AppCore {
    #[uniffi::constructor]
    fn new(
        app_support_dir: String,
        device_id: String,
        initial_screen_metrics: Vec<ScreenMetrics>,
    ) -> Arc<Self> {
        Arc::new(Self {
            inner: Arc::new(CoreAppCore::new(
                app_support_dir,
                device_id,
                initial_screen_metrics
                    .into_iter()
                    .map(|s| s.into())
                    .collect(),
            )),
        })
    }

    fn dispatch(&self, cmd: Command) -> Vec<Effect> {
        self.inner
            .dispatch(cmd.into())
            .into_iter()
            .map(Into::into)
            .collect()
    }

    fn snapshot(&self) -> UiSnapshot {
        self.inner.snapshot().into()
    }

    fn take_logs(&self) -> String {
        self.inner.take_logs()
    }
}
