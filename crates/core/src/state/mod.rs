//! Application state and UI snapshot types.
//!
//! These types are designed to be UniFFI-compatible for Swift consumption.

use serde::{Deserialize, Serialize};

/// Active surface: Nook (widget strip) or Tray (file shelf).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
pub enum Surface {
    #[default]
    Nook,
    Tray,
}

/// Screen metrics from Swift (NSScreen safe area, frame, etc.).
#[derive(Debug, Clone, Serialize, Deserialize)]
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

/// Permission status for a feature.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PermissionStatus {
    pub calendar: bool,
    pub camera: bool,
    pub automation: bool,
}

/// Widget view model for rendering.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WidgetViewModel {
    pub id: String,
    pub name: String,
    pub compact_title: String,
    pub compact_content: String,
    pub expanded_content: String,
    pub is_expanded: bool,
}

/// Tray item view model.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrayItemViewModel {
    pub id: String,
    pub display_name: String,
    pub item_type: String,
    pub size_hint: String,
    pub is_selected: bool,
}

/// Tray view model.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TrayViewModel {
    pub items: Vec<TrayItemViewModel>,
    pub selected_ids: Vec<String>,
}

/// Nook (widget strip) view model.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct NookViewModel {
    pub widgets: Vec<WidgetViewModel>,
}

/// Settings model for preferences UI.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SettingsModel {
    // General
    pub start_at_login: bool,
    pub hotkey: String,
    pub show_in_fullscreen: String, // "on_notched" | "always" | "never"
    pub media_source: String,       // "system"
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
    // Behavior
    pub hover_delay_ms: u32,
    pub gesture_sensitivity: f32,
    pub reduced_motion: bool,
    // Displays
    pub appear_on_all_spaces: bool,
    pub enabled_displays: Vec<String>,
    // Gestures
    pub allow_gestures_on_hover: bool,
    pub open_close_vertical_gestures: bool,
    pub control_media_horizontal: bool,
    pub invert_media_gestures: bool,
    // Live Activities
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
    // Nook
    pub nook_enable: bool,
    pub nook_show_dividers: bool,
    // Tray
    pub tray_ephemeral: bool,
    pub tray_max_items: u32,
    pub tray_width: u32,
    // Drop Area
    pub drop_area_width: u32,
    pub drop_area_pipelines_enabled: Vec<String>,
    // Widgets (for Nook customize)
    pub widgets_enabled: Vec<String>,
    pub widgets_order: Vec<String>,
}

impl Default for SettingsModel {
    fn default() -> Self {
        Self {
            start_at_login: false,
            hotkey: "⌘⇧N".to_string(),
            show_in_fullscreen: "on_notched".to_string(),
            media_source: "system".to_string(),
            prefer_round_buttons: true,
            translucent_notch_background: false,
            always_open_on_hover: false,
            disable_haptics: false,
            prevent_close_on_mouse_leave: true,
            lock_while_typing: false,
            content_padding: 12,
            notch_width_fine_tune: 0,
            notch_height_fine_tune: 0,
            handler_enable: true,
            handler_width: 184,
            handler_height: 8,
            transparent_handler: false,
            demo_mode: false,
            hover_delay_ms: 200,
            gesture_sensitivity: 1.0,
            reduced_motion: false,
            appear_on_all_spaces: true,
            enabled_displays: vec![],
            allow_gestures_on_hover: true,
            open_close_vertical_gestures: true,
            control_media_horizontal: true,
            invert_media_gestures: false,
            live_activities_enable: true,
            live_activities_hide_in_non_notched: false,
            live_activities_inactivity_timeout: 10,
            live_activities_enable_interactive: true,
            live_activities_enable_quick_peek: true,
            live_activities_unhide_automatically: true,
            live_activities_show_song_change: false,
            live_activities_hud_replacement_enable: false,
            live_activities_hud_disable_colors: false,
            live_activities_hud_show_all_screens: false,
            live_activities_album_corner_radius: 5,
            live_activities_effect_type: "audio_spectrograph".to_string(),
            live_activities_colored_effects: true,
            live_activities_activities_enabled: vec![
                "media".to_string(),
                "files_tray".to_string(),
                "calendar".to_string(),
                "notes".to_string(),
                "new_update".to_string(),
            ],
            nook_enable: true,
            nook_show_dividers: true,
            tray_ephemeral: true,
            tray_max_items: 50,
            tray_width: 11,
            drop_area_width: 11,
            drop_area_pipelines_enabled: vec![
                "compress_images".to_string(),
                "zip_unzip".to_string(),
            ],
            widgets_enabled: vec![],
            widgets_order: vec![],
        }
    }
}

/// Full UI snapshot for Swift to render.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UiSnapshot {
    pub expansion_progress: f32,
    pub reduced_motion: bool,
    pub active_surface: String,
    pub nook: NookViewModel,
    pub tray: TrayViewModel,
    pub settings: SettingsModel,
    pub permissions: PermissionStatus,
}

impl Default for UiSnapshot {
    fn default() -> Self {
        Self {
            expansion_progress: 0.0,
            reduced_motion: false,
            active_surface: "Nook".to_string(),
            nook: NookViewModel::default(),
            tray: TrayViewModel::default(),
            settings: SettingsModel::default(),
            permissions: PermissionStatus::default(),
        }
    }
}

/// Full application state (internal).
#[derive(Debug, Clone)]
pub struct AppState {
    pub overlay_expanded: bool,
    pub active_surface: Surface,
    pub screens: Vec<ScreenMetrics>,
    pub reduced_motion: bool,
    pub nook: NookViewModel,
    pub tray: TrayViewModel,
    pub settings: SettingsModel,
    pub permissions: PermissionStatus,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            overlay_expanded: false,
            active_surface: Surface::Nook,
            screens: vec![],
            reduced_motion: false,
            nook: NookViewModel::default(),
            tray: TrayViewModel::default(),
            settings: SettingsModel::default(),
            permissions: PermissionStatus::default(),
        }
    }
}

impl AppState {
    pub fn to_snapshot(&self) -> UiSnapshot {
        UiSnapshot {
            expansion_progress: if self.overlay_expanded { 1.0 } else { 0.0 },
            reduced_motion: self.reduced_motion,
            active_surface: match self.active_surface {
                Surface::Nook => "Nook",
                Surface::Tray => "Tray",
            }
            .to_string(),
            nook: self.nook.clone(),
            tray: self.tray.clone(),
            settings: self.settings.clone(),
            permissions: self.permissions.clone(),
        }
    }
}
