//! Configuration schema, persistence, and migrations.

use serde::{Deserialize, Serialize};
use std::path::Path;
use thiserror::Error;

const CONFIG_VERSION: u32 = 2;

fn default_show_in_fullscreen() -> String {
    "on_notched".to_string()
}
fn default_media_source() -> String {
    "system".to_string()
}
fn default_effect_type() -> String {
    "audio_spectrograph".to_string()
}
fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub version: u32,
    pub general: GeneralConfig,
    pub displays: DisplaysConfig,
    pub behavior: BehaviorConfig,
    #[serde(default)]
    pub gestures: GesturesConfig,
    #[serde(default)]
    pub live_activities: LiveActivitiesConfig,
    pub widgets: WidgetsConfig,
    #[serde(default)]
    pub nook: NookConfig,
    pub tray: TrayConfig,
    #[serde(default)]
    pub drop_area: DropAreaConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeneralConfig {
    pub start_at_login: bool,
    pub hotkey: String,
    #[serde(default = "default_show_in_fullscreen")]
    pub show_in_fullscreen: String, // "on_notched" | "always" | "never"
    #[serde(default = "default_media_source")]
    pub media_source: String, // "system"
    #[serde(default = "default_true")]
    pub prefer_round_buttons: bool,
    #[serde(default)]
    pub translucent_notch_background: bool,
    #[serde(default)]
    pub always_open_on_hover: bool,
    #[serde(default)]
    pub disable_haptics: bool,
    #[serde(default = "default_true")]
    pub prevent_close_on_mouse_leave: bool,
    #[serde(default)]
    pub lock_while_typing: bool,
    #[serde(default = "default_content_padding")]
    pub content_padding: u32,
    #[serde(default)]
    pub notch_width_fine_tune: i32,
    #[serde(default)]
    pub notch_height_fine_tune: i32,
    #[serde(default = "default_true")]
    pub handler_enable: bool,
    #[serde(default = "default_handler_width")]
    pub handler_width: u32,
    #[serde(default = "default_handler_height")]
    pub handler_height: u32,
    #[serde(default)]
    pub transparent_handler: bool,
    #[serde(default)]
    pub demo_mode: bool,
}

fn default_content_padding() -> u32 {
    12
}
fn default_handler_width() -> u32 {
    184
}
fn default_handler_height() -> u32 {
    8
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplaysConfig {
    pub enabled_displays: Vec<String>,
    pub show_in_fullscreen: bool,
    pub appear_on_all_spaces: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BehaviorConfig {
    pub hover_delay_ms: u32,
    pub gesture_sensitivity: f32,
    pub reduced_motion: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GesturesConfig {
    #[serde(default = "default_true")]
    pub allow_gestures_on_hover: bool,
    #[serde(default = "default_true")]
    pub open_close_vertical_gestures: bool,
    #[serde(default = "default_true")]
    pub control_media_horizontal: bool,
    #[serde(default)]
    pub invert_media_gestures: bool,
}

impl Default for GesturesConfig {
    fn default() -> Self {
        Self {
            allow_gestures_on_hover: true,
            open_close_vertical_gestures: true,
            control_media_horizontal: true,
            invert_media_gestures: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LiveActivitiesConfig {
    #[serde(default = "default_true")]
    pub enable: bool,
    #[serde(default = "default_activities_enabled")]
    pub activities_enabled: Vec<String>, // "media", "files_tray", "calendar", "new_update"
    #[serde(default)]
    pub hide_in_non_notched: bool,
    #[serde(default = "default_inactivity_timeout")]
    pub inactivity_timeout: u32,
    pub enable_interactive: bool,
    pub enable_quick_peek: bool,
    pub unhide_automatically: bool,
    pub show_song_change: bool,
    pub hud_replacement_enable: bool,
    pub hud_disable_colors: bool,
    pub hud_show_all_screens: bool,
    #[serde(default = "default_album_corner_radius")]
    pub album_corner_radius: u32,
    #[serde(default = "default_effect_type")]
    pub effect_type: String, // "audio_spectrograph" | "waves" | "vibrating_circle" | "gif"
    #[serde(default = "default_true")]
    pub colored_effects: bool,
}

fn default_activities_enabled() -> Vec<String> {
    vec![
        "media".to_string(),
        "files_tray".to_string(),
        "calendar".to_string(),
        "notes".to_string(),
        "new_update".to_string(),
    ]
}

fn default_inactivity_timeout() -> u32 {
    10
}
fn default_album_corner_radius() -> u32 {
    5
}

impl Default for LiveActivitiesConfig {
    fn default() -> Self {
        Self {
            enable: true,
            activities_enabled: default_activities_enabled(),
            hide_in_non_notched: false,
            inactivity_timeout: 10,
            enable_interactive: true,
            enable_quick_peek: true,
            unhide_automatically: true,
            show_song_change: false,
            hud_replacement_enable: false,
            hud_disable_colors: false,
            hud_show_all_screens: false,
            album_corner_radius: 5,
            effect_type: "audio_spectrograph".to_string(),
            colored_effects: true,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WidgetsConfig {
    pub enabled: Vec<String>,
    pub order: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NookConfig {
    #[serde(default = "default_true")]
    pub enable: bool,
    #[serde(default = "default_true")]
    pub show_dividers: bool,
}

impl Default for NookConfig {
    fn default() -> Self {
        Self {
            enable: true,
            show_dividers: true,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrayConfig {
    pub ephemeral: bool,
    pub max_items: u32,
    #[serde(default = "default_tray_width")]
    pub width: u32,
}

fn default_tray_width() -> u32 {
    11
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DropAreaConfig {
    #[serde(default = "default_drop_area_width")]
    pub width: u32,
    #[serde(default = "default_pipelines_enabled")]
    pub pipelines_enabled: Vec<String>, // "compress_images", "zip_unzip"
}

fn default_pipelines_enabled() -> Vec<String> {
    vec!["compress_images".to_string(), "zip_unzip".to_string()]
}

fn default_drop_area_width() -> u32 {
    11
}

impl Default for DropAreaConfig {
    fn default() -> Self {
        Self {
            width: 11,
            pipelines_enabled: default_pipelines_enabled(),
        }
    }
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            version: CONFIG_VERSION,
            general: GeneralConfig {
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
            },
            displays: DisplaysConfig {
                enabled_displays: vec![],
                show_in_fullscreen: true,
                appear_on_all_spaces: true,
            },
            behavior: BehaviorConfig {
                hover_delay_ms: 200,
                gesture_sensitivity: 1.0,
                reduced_motion: false,
            },
            gestures: GesturesConfig {
                allow_gestures_on_hover: true,
                open_close_vertical_gestures: true,
                control_media_horizontal: true,
                invert_media_gestures: false,
            },
            live_activities: LiveActivitiesConfig {
                enable: true,
                activities_enabled: default_activities_enabled(),
                hide_in_non_notched: false,
                inactivity_timeout: 10,
                enable_interactive: true,
                enable_quick_peek: true,
                unhide_automatically: true,
                show_song_change: false,
                hud_replacement_enable: false,
                hud_disable_colors: false,
                hud_show_all_screens: false,
                album_corner_radius: 5,
                effect_type: "audio_spectrograph".to_string(),
                colored_effects: true,
            },
            widgets: WidgetsConfig {
                enabled: vec![],
                order: vec![],
            },
            nook: NookConfig {
                enable: true,
                show_dividers: true,
            },
            tray: TrayConfig {
                ephemeral: true,
                max_items: 50,
                width: 11,
            },
            drop_area: DropAreaConfig::default(),
        }
    }
}

#[derive(Error, Debug)]
pub enum ConfigError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("TOML error: {0}")]
    Toml(#[from] toml::de::Error),
    #[error("TOML serialize error: {0}")]
    TomlSerialize(#[from] toml::ser::Error),
}

/// Load config from path, or return default if not found.
pub fn load_config(path: &Path) -> Result<AppConfig, ConfigError> {
    let contents = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Ok(AppConfig::default());
        }
        Err(e) => return Err(e.into()),
    };
    let config: AppConfig = toml::from_str(&contents)?;
    Ok(migrate_config(config))
}

/// Save config to path.
pub fn save_config(path: &Path, config: &AppConfig) -> Result<(), ConfigError> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let contents = toml::to_string_pretty(config)?;
    std::fs::write(path, contents)?;
    Ok(())
}

fn migrate_config(mut config: AppConfig) -> AppConfig {
    if config.version < CONFIG_VERSION {
        config.version = CONFIG_VERSION;
    }
    config
}
