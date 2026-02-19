//! AppCore: main entry point for the Rust side.
//!
//! Holds state, runs reducer on dispatch, produces effects and snapshots.

use std::path::PathBuf;
use std::sync::{Arc, RwLock};

use tracing::info;

use crate::commands::{Command, SettingValue};
use crate::config::{load_config, save_config, AppConfig};
use crate::effects::Effect;
use crate::state::{AppState, NookViewModel, ScreenMetrics, Surface, UiSnapshot};
use crate::tray::TrayEngine;
use crate::widgets::WidgetRuntime;

/// Main application core. Thread-safe, used from Swift via UniFFI.
pub struct AppCore {
    state: Arc<RwLock<AppState>>,
    config_path: PathBuf,
    config: Arc<RwLock<AppConfig>>,
    tray_engine: Arc<RwLock<TrayEngine>>,
    widget_runtime: Arc<RwLock<WidgetRuntime>>,
    log_buffer: Arc<RwLock<Vec<String>>>,
}

impl AppCore {
    /// Create a new AppCore. Called from Swift with app_support_dir and device_id.
    pub fn new(
        app_support_dir: String,
        _device_id: String,
        initial_screen_metrics: Vec<ScreenMetrics>,
    ) -> Self {
        let config_path = PathBuf::from(&app_support_dir).join("config.toml");
        let config = load_config(&config_path).unwrap_or_else(|_| AppConfig::default());
        let config = Arc::new(RwLock::new(config));

        let settings = config
            .read()
            .map(|c| crate::state::SettingsModel {
                start_at_login: c.general.start_at_login,
                hotkey: c.general.hotkey.clone(),
                show_in_fullscreen: c.general.show_in_fullscreen.clone(),
                media_source: c.general.media_source.clone(),
                prefer_round_buttons: c.general.prefer_round_buttons,
                translucent_notch_background: c.general.translucent_notch_background,
                always_open_on_hover: c.general.always_open_on_hover,
                disable_haptics: c.general.disable_haptics,
                prevent_close_on_mouse_leave: c.general.prevent_close_on_mouse_leave,
                lock_while_typing: c.general.lock_while_typing,
                content_padding: c.general.content_padding,
                notch_width_fine_tune: c.general.notch_width_fine_tune,
                notch_height_fine_tune: c.general.notch_height_fine_tune,
                handler_enable: c.general.handler_enable,
                handler_width: c.general.handler_width,
                handler_height: c.general.handler_height,
                transparent_handler: c.general.transparent_handler,
                demo_mode: c.general.demo_mode,
                hover_delay_ms: c.behavior.hover_delay_ms,
                gesture_sensitivity: c.behavior.gesture_sensitivity,
                reduced_motion: c.behavior.reduced_motion,
                appear_on_all_spaces: c.displays.appear_on_all_spaces,
                enabled_displays: c.displays.enabled_displays.clone(),
                allow_gestures_on_hover: c.gestures.allow_gestures_on_hover,
                open_close_vertical_gestures: c.gestures.open_close_vertical_gestures,
                control_media_horizontal: c.gestures.control_media_horizontal,
                invert_media_gestures: c.gestures.invert_media_gestures,
                live_activities_enable: c.live_activities.enable,
                live_activities_hide_in_non_notched: c.live_activities.hide_in_non_notched,
                live_activities_inactivity_timeout: c.live_activities.inactivity_timeout,
                live_activities_enable_interactive: c.live_activities.enable_interactive,
                live_activities_enable_quick_peek: c.live_activities.enable_quick_peek,
                live_activities_unhide_automatically: c.live_activities.unhide_automatically,
                live_activities_show_song_change: c.live_activities.show_song_change,
                live_activities_hud_replacement_enable: c.live_activities.hud_replacement_enable,
                live_activities_hud_disable_colors: c.live_activities.hud_disable_colors,
                live_activities_hud_show_all_screens: c.live_activities.hud_show_all_screens,
                live_activities_album_corner_radius: c.live_activities.album_corner_radius,
                live_activities_effect_type: c.live_activities.effect_type.clone(),
                live_activities_colored_effects: c.live_activities.colored_effects,
                live_activities_activities_enabled: c.live_activities.activities_enabled.clone(),
                nook_enable: c.nook.enable,
                nook_show_dividers: c.nook.show_dividers,
                tray_ephemeral: c.tray.ephemeral,
                tray_max_items: c.tray.max_items,
                tray_width: c.tray.width,
                drop_area_width: c.drop_area.width,
                drop_area_pipelines_enabled: c.drop_area.pipelines_enabled.clone(),
                widgets_enabled: c.widgets.enabled.clone(),
                widgets_order: c.widgets.order.clone(),
            })
            .unwrap_or_default();

        let mut state = AppState::default();
        state.screens = initial_screen_metrics;
        state.settings = settings;

        let tray_engine = Arc::new(RwLock::new(TrayEngine::new(
            config.read().map(|c| c.tray.max_items).unwrap_or(50),
        )));

        let notes_path = config_path.parent().map(|p| p.join("notes.db")).unwrap_or_else(|| PathBuf::from("notes.db"));
        let mut widget_runtime = WidgetRuntime::new()
            .with_notes_db(&notes_path)
            .with_platform_widgets();
        if let Ok(cfg) = config.read() {
            widget_runtime.configure(&cfg.widgets.enabled, &cfg.widgets.order);
        }
        let widget_runtime = Arc::new(RwLock::new(widget_runtime));

        let core = Self {
            state: Arc::new(RwLock::new(state)),
            config_path,
            config,
            tray_engine,
            widget_runtime,
            log_buffer: Arc::new(RwLock::new(vec![])),
        };

        info!("AppCore initialized");
        core
    }

    /// Dispatch a command. Returns effects for Swift to execute.
    pub fn dispatch(&self, cmd: Command) -> Vec<Effect> {
        let mut effects = vec![];

        match &cmd {
            Command::HoverEntered { screen_id: _ } => {
                let mut state = self.state.write().unwrap();
                state.overlay_expanded = true;
            }
            Command::HoverExited { screen_id: _ } => {
                let mut state = self.state.write().unwrap();
                state.overlay_expanded = false;
            }
            Command::ToggleOverlay => {
                let mut state = self.state.write().unwrap();
                state.overlay_expanded = !state.overlay_expanded;
            }
            Command::ToggleSurface => {
                let mut state = self.state.write().unwrap();
                state.active_surface = match state.active_surface {
                    Surface::Nook => Surface::Tray,
                    Surface::Tray => Surface::Nook,
                };
            }
            Command::SwipeDown { .. } => {
                let mut state = self.state.write().unwrap();
                state.overlay_expanded = true;
            }
            Command::ScreenMetricsChanged { screens } => {
                let mut state = self.state.write().unwrap();
                state.screens = screens.clone();
            }
            Command::UpdateSetting { key, value } => {
                if let Err(e) = self.apply_setting(key, value) {
                    self.log(&format!("UpdateSetting error: {}", e));
                }
            }
            Command::ResetSettings => {
                if let Err(e) = self.reset_settings() {
                    self.log(&format!("ResetSettings error: {}", e));
                }
            }
            Command::TrayAddItems { payload } => {
                let max_items = self
                    .config
                    .read()
                    .map(|c| c.tray.max_items)
                    .unwrap_or(50);
                let mut tray = self.tray_engine.write().unwrap();
                tray.add_items(payload.clone(), max_items);
                let vm = tray.to_view_model();
                let mut state = self.state.write().unwrap();
                state.tray = vm;
            }
            Command::TrayRemove { item_ids } => {
                let mut tray = self.tray_engine.write().unwrap();
                tray.remove_items(item_ids);
                let vm = tray.to_view_model();
                let mut state = self.state.write().unwrap();
                state.tray = vm;
            }
            Command::TraySelect {
                item_id,
                add_to_selection,
            } => {
                let mut tray = self.tray_engine.write().unwrap();
                tray.select(item_id, *add_to_selection);
                let vm = tray.to_view_model();
                let mut state = self.state.write().unwrap();
                state.tray = vm;
            }
            Command::TraySelectAll => {
                let mut tray = self.tray_engine.write().unwrap();
                tray.select_all();
                let vm = tray.to_view_model();
                let mut state = self.state.write().unwrap();
                state.tray = vm;
            }
            Command::TrayClearSelection => {
                let mut tray = self.tray_engine.write().unwrap();
                tray.clear_selection();
                let vm = tray.to_view_model();
                let mut state = self.state.write().unwrap();
                state.tray = vm;
            }
            Command::TrayRename { item_id, new_name } => {
                let tray = self.tray_engine.read().unwrap();
                if let Some(old_path) = tray.get_item_path(item_id) {
                    let parent = std::path::Path::new(&old_path).parent();
                    if let Some(p) = parent {
                        let new_path = p.join(&new_name);
                        effects.push(Effect::RenameFile {
                            old_path,
                            new_path: new_path.to_string_lossy().to_string(),
                        });
                    }
                }
            }
            Command::TrayQuickLook { item_ids } => {
                let tray = self.tray_engine.read().unwrap();
                let paths = tray.get_paths_for_ids(item_ids);
                if !paths.is_empty() {
                    effects.push(Effect::ShowQuickLook { paths });
                }
            }
            Command::TrayRevealInFinder { item_id } => {
                let tray = self.tray_engine.read().unwrap();
                if let Some(path) = tray.get_item_path(item_id) {
                    effects.push(Effect::RevealInFinder { path });
                }
            }
            Command::TrayCopy => {
                let tray = self.tray_engine.read().unwrap();
                let paths = tray.get_selected_paths();
                if !paths.is_empty() {
                    effects.push(Effect::CopyToPasteboard { paths });
                }
            }
            Command::TrayShare { item_ids } => {
                let tray = self.tray_engine.read().unwrap();
                let paths = tray.get_paths_for_ids(item_ids);
                if !paths.is_empty() {
                    effects.push(Effect::ShareItems {
                        item_ids: paths,
                    });
                }
            }
            Command::WidgetAction { widget_id, action } => {
                let mut runtime = self.widget_runtime.write().unwrap();
                runtime.on_action(widget_id, action);
            }
            Command::CalendarEventsReceived { events_json } => {
                self.widget_runtime
                    .read()
                    .map(|r| r.receive_calendar_events(events_json))
                    .ok();
            }
            Command::MediaStateReceived { state_json } => {
                self.widget_runtime
                    .read()
                    .map(|r| r.receive_media_state(state_json))
                    .ok();
            }
            Command::CameraListReceived { cameras_json } => {
                self.widget_runtime
                    .read()
                    .map(|r| r.receive_cameras(cameras_json))
                    .ok();
            }
            Command::VolumeChanged { .. } => {}
            Command::PermissionStatusChanged {
                calendar,
                camera,
                automation,
            } => {
                let mut state = self.state.write().unwrap();
                state.permissions.calendar = *calendar;
                state.permissions.camera = *camera;
                state.permissions.automation = *automation;
            }
        }

        effects
    }

    fn apply_setting(&self, key: &str, value: &SettingValue) -> Result<(), String> {
        let mut config = self.config.write().map_err(|e| e.to_string())?;
        let mut state = self.state.write().map_err(|e| e.to_string())?;

        match key {
            // General
            "start_at_login" => {
                if let SettingValue::Bool(v) = value {
                    config.general.start_at_login = *v;
                    state.settings.start_at_login = *v;
                }
            }
            "hotkey" => {
                if let SettingValue::String(v) = value {
                    config.general.hotkey = v.clone();
                    state.settings.hotkey = v.clone();
                }
            }
            "show_in_fullscreen" => {
                if let SettingValue::String(v) = value {
                    config.general.show_in_fullscreen = v.clone();
                    state.settings.show_in_fullscreen = v.clone();
                }
            }
            "media_source" => {
                if let SettingValue::String(v) = value {
                    config.general.media_source = v.clone();
                    state.settings.media_source = v.clone();
                }
            }
            "prefer_round_buttons" => {
                if let SettingValue::Bool(v) = value {
                    config.general.prefer_round_buttons = *v;
                    state.settings.prefer_round_buttons = *v;
                }
            }
            "translucent_notch_background" => {
                if let SettingValue::Bool(v) = value {
                    config.general.translucent_notch_background = *v;
                    state.settings.translucent_notch_background = *v;
                }
            }
            "always_open_on_hover" => {
                if let SettingValue::Bool(v) = value {
                    config.general.always_open_on_hover = *v;
                    state.settings.always_open_on_hover = *v;
                }
            }
            "disable_haptics" => {
                if let SettingValue::Bool(v) = value {
                    config.general.disable_haptics = *v;
                    state.settings.disable_haptics = *v;
                }
            }
            "prevent_close_on_mouse_leave" => {
                if let SettingValue::Bool(v) = value {
                    config.general.prevent_close_on_mouse_leave = *v;
                    state.settings.prevent_close_on_mouse_leave = *v;
                }
            }
            "lock_while_typing" => {
                if let SettingValue::Bool(v) = value {
                    config.general.lock_while_typing = *v;
                    state.settings.lock_while_typing = *v;
                }
            }
            "content_padding" => {
                if let SettingValue::U32(v) = value {
                    config.general.content_padding = *v;
                    state.settings.content_padding = *v;
                }
            }
            "notch_width_fine_tune" => {
                if let SettingValue::I32(v) = value {
                    config.general.notch_width_fine_tune = *v;
                    state.settings.notch_width_fine_tune = *v;
                }
            }
            "notch_height_fine_tune" => {
                if let SettingValue::I32(v) = value {
                    config.general.notch_height_fine_tune = *v;
                    state.settings.notch_height_fine_tune = *v;
                }
            }
            "handler_enable" => {
                if let SettingValue::Bool(v) = value {
                    config.general.handler_enable = *v;
                    state.settings.handler_enable = *v;
                }
            }
            "handler_width" => {
                if let SettingValue::U32(v) = value {
                    config.general.handler_width = *v;
                    state.settings.handler_width = *v;
                }
            }
            "handler_height" => {
                if let SettingValue::U32(v) = value {
                    config.general.handler_height = *v;
                    state.settings.handler_height = *v;
                }
            }
            "transparent_handler" => {
                if let SettingValue::Bool(v) = value {
                    config.general.transparent_handler = *v;
                    state.settings.transparent_handler = *v;
                }
            }
            "demo_mode" => {
                if let SettingValue::Bool(v) = value {
                    config.general.demo_mode = *v;
                    state.settings.demo_mode = *v;
                }
            }
            // Behavior
            "hover_delay_ms" => {
                if let SettingValue::U32(v) = value {
                    config.behavior.hover_delay_ms = *v;
                    state.settings.hover_delay_ms = *v;
                }
            }
            "gesture_sensitivity" => {
                if let SettingValue::F32(v) = value {
                    config.behavior.gesture_sensitivity = *v;
                    state.settings.gesture_sensitivity = *v;
                }
            }
            "reduced_motion" => {
                if let SettingValue::Bool(v) = value {
                    config.behavior.reduced_motion = *v;
                    state.reduced_motion = *v;
                    state.settings.reduced_motion = *v;
                }
            }
            // Displays
            "appear_on_all_spaces" => {
                if let SettingValue::Bool(v) = value {
                    config.displays.appear_on_all_spaces = *v;
                    state.settings.appear_on_all_spaces = *v;
                }
            }
            "enabled_displays" => {
                if let SettingValue::StringList(v) = value {
                    config.displays.enabled_displays = v.clone();
                    state.settings.enabled_displays = v.clone();
                }
            }
            // Gestures
            "allow_gestures_on_hover" => {
                if let SettingValue::Bool(v) = value {
                    config.gestures.allow_gestures_on_hover = *v;
                    state.settings.allow_gestures_on_hover = *v;
                }
            }
            "open_close_vertical_gestures" => {
                if let SettingValue::Bool(v) = value {
                    config.gestures.open_close_vertical_gestures = *v;
                    state.settings.open_close_vertical_gestures = *v;
                }
            }
            "control_media_horizontal" => {
                if let SettingValue::Bool(v) = value {
                    config.gestures.control_media_horizontal = *v;
                    state.settings.control_media_horizontal = *v;
                }
            }
            "invert_media_gestures" => {
                if let SettingValue::Bool(v) = value {
                    config.gestures.invert_media_gestures = *v;
                    state.settings.invert_media_gestures = *v;
                }
            }
            // Live Activities
            "live_activities_enable" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.enable = *v;
                    state.settings.live_activities_enable = *v;
                }
            }
            "live_activities_hide_in_non_notched" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.hide_in_non_notched = *v;
                    state.settings.live_activities_hide_in_non_notched = *v;
                }
            }
            "live_activities_inactivity_timeout" => {
                if let SettingValue::U32(v) = value {
                    config.live_activities.inactivity_timeout = *v;
                    state.settings.live_activities_inactivity_timeout = *v;
                }
            }
            "live_activities_enable_interactive" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.enable_interactive = *v;
                    state.settings.live_activities_enable_interactive = *v;
                }
            }
            "live_activities_enable_quick_peek" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.enable_quick_peek = *v;
                    state.settings.live_activities_enable_quick_peek = *v;
                }
            }
            "live_activities_unhide_automatically" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.unhide_automatically = *v;
                    state.settings.live_activities_unhide_automatically = *v;
                }
            }
            "live_activities_show_song_change" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.show_song_change = *v;
                    state.settings.live_activities_show_song_change = *v;
                }
            }
            "live_activities_hud_replacement_enable" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.hud_replacement_enable = *v;
                    state.settings.live_activities_hud_replacement_enable = *v;
                }
            }
            "live_activities_hud_disable_colors" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.hud_disable_colors = *v;
                    state.settings.live_activities_hud_disable_colors = *v;
                }
            }
            "live_activities_hud_show_all_screens" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.hud_show_all_screens = *v;
                    state.settings.live_activities_hud_show_all_screens = *v;
                }
            }
            "live_activities_album_corner_radius" => {
                if let SettingValue::U32(v) = value {
                    config.live_activities.album_corner_radius = *v;
                    state.settings.live_activities_album_corner_radius = *v;
                }
            }
            "live_activities_effect_type" => {
                if let SettingValue::String(v) = value {
                    config.live_activities.effect_type = v.clone();
                    state.settings.live_activities_effect_type = v.clone();
                }
            }
            "live_activities_colored_effects" => {
                if let SettingValue::Bool(v) = value {
                    config.live_activities.colored_effects = *v;
                    state.settings.live_activities_colored_effects = *v;
                }
            }
            "live_activities_activities_enabled" => {
                if let SettingValue::StringList(v) = value {
                    config.live_activities.activities_enabled = v.clone();
                    state.settings.live_activities_activities_enabled = v.clone();
                }
            }
            // Nook
            "nook_enable" => {
                if let SettingValue::Bool(v) = value {
                    config.nook.enable = *v;
                    state.settings.nook_enable = *v;
                }
            }
            "nook_show_dividers" => {
                if let SettingValue::Bool(v) = value {
                    config.nook.show_dividers = *v;
                    state.settings.nook_show_dividers = *v;
                }
            }
            // Tray
            "tray_ephemeral" => {
                if let SettingValue::Bool(v) = value {
                    config.tray.ephemeral = *v;
                    state.settings.tray_ephemeral = *v;
                }
            }
            "tray_max_items" => {
                if let SettingValue::U32(v) = value {
                    config.tray.max_items = *v;
                    state.settings.tray_max_items = *v;
                }
            }
            "tray_width" => {
                if let SettingValue::U32(v) = value {
                    config.tray.width = *v;
                    state.settings.tray_width = *v;
                }
            }
            // Drop Area
            "drop_area_width" => {
                if let SettingValue::U32(v) = value {
                    config.drop_area.width = *v;
                    state.settings.drop_area_width = *v;
                }
            }
            "drop_area_pipelines_enabled" => {
                if let SettingValue::StringList(v) = value {
                    config.drop_area.pipelines_enabled = v.clone();
                    state.settings.drop_area_pipelines_enabled = v.clone();
                }
            }
            "widgets_enabled" => {
                if let SettingValue::StringList(v) = value {
                    config.widgets.enabled = v.clone();
                    state.settings.widgets_enabled = v.clone();
                    let (enabled, order) = (config.widgets.enabled.clone(), config.widgets.order.clone());
                    if let Ok(mut runtime) = self.widget_runtime.write() {
                        runtime.configure(&enabled, &order);
                    }
                }
            }
            "widgets_order" => {
                if let SettingValue::StringList(v) = value {
                    config.widgets.order = v.clone();
                    state.settings.widgets_order = v.clone();
                    let (enabled, order) = (config.widgets.enabled.clone(), config.widgets.order.clone());
                    if let Ok(mut runtime) = self.widget_runtime.write() {
                        runtime.configure(&enabled, &order);
                    }
                }
            }
            _ => return Err(format!("Unknown setting key: {}", key)),
        }

        save_config(&self.config_path, &config).map_err(|e| e.to_string())?;
        Ok(())
    }

    fn reset_settings(&self) -> Result<(), String> {
        let default_config = AppConfig::default();
        save_config(&self.config_path, &default_config).map_err(|e| e.to_string())?;

        {
            let mut config = self.config.write().map_err(|e| e.to_string())?;
            *config = default_config.clone();
        }

        let mut state = self.state.write().map_err(|e| e.to_string())?;
        state.settings = crate::state::SettingsModel {
            start_at_login: default_config.general.start_at_login,
            hotkey: default_config.general.hotkey.clone(),
            show_in_fullscreen: default_config.general.show_in_fullscreen.clone(),
            media_source: default_config.general.media_source.clone(),
            prefer_round_buttons: default_config.general.prefer_round_buttons,
            translucent_notch_background: default_config.general.translucent_notch_background,
            always_open_on_hover: default_config.general.always_open_on_hover,
            disable_haptics: default_config.general.disable_haptics,
            prevent_close_on_mouse_leave: default_config.general.prevent_close_on_mouse_leave,
            lock_while_typing: default_config.general.lock_while_typing,
            content_padding: default_config.general.content_padding,
            notch_width_fine_tune: default_config.general.notch_width_fine_tune,
            notch_height_fine_tune: default_config.general.notch_height_fine_tune,
            handler_enable: default_config.general.handler_enable,
            handler_width: default_config.general.handler_width,
            handler_height: default_config.general.handler_height,
            transparent_handler: default_config.general.transparent_handler,
            demo_mode: default_config.general.demo_mode,
            hover_delay_ms: default_config.behavior.hover_delay_ms,
            gesture_sensitivity: default_config.behavior.gesture_sensitivity,
            reduced_motion: default_config.behavior.reduced_motion,
            appear_on_all_spaces: default_config.displays.appear_on_all_spaces,
            enabled_displays: default_config.displays.enabled_displays.clone(),
            allow_gestures_on_hover: default_config.gestures.allow_gestures_on_hover,
            open_close_vertical_gestures: default_config.gestures.open_close_vertical_gestures,
            control_media_horizontal: default_config.gestures.control_media_horizontal,
            invert_media_gestures: default_config.gestures.invert_media_gestures,
            live_activities_enable: default_config.live_activities.enable,
            live_activities_hide_in_non_notched: default_config.live_activities.hide_in_non_notched,
            live_activities_inactivity_timeout: default_config.live_activities.inactivity_timeout,
            live_activities_enable_interactive: default_config.live_activities.enable_interactive,
            live_activities_enable_quick_peek: default_config.live_activities.enable_quick_peek,
            live_activities_unhide_automatically: default_config.live_activities.unhide_automatically,
            live_activities_show_song_change: default_config.live_activities.show_song_change,
            live_activities_hud_replacement_enable: default_config.live_activities.hud_replacement_enable,
            live_activities_hud_disable_colors: default_config.live_activities.hud_disable_colors,
            live_activities_hud_show_all_screens: default_config.live_activities.hud_show_all_screens,
            live_activities_album_corner_radius: default_config.live_activities.album_corner_radius,
            live_activities_effect_type: default_config.live_activities.effect_type.clone(),
            live_activities_colored_effects: default_config.live_activities.colored_effects,
            live_activities_activities_enabled: default_config.live_activities.activities_enabled.clone(),
            nook_enable: default_config.nook.enable,
            nook_show_dividers: default_config.nook.show_dividers,
            tray_ephemeral: default_config.tray.ephemeral,
            tray_max_items: default_config.tray.max_items,
            tray_width: default_config.tray.width,
            drop_area_width: default_config.drop_area.width,
            drop_area_pipelines_enabled: default_config.drop_area.pipelines_enabled.clone(),
            widgets_enabled: default_config.widgets.enabled.clone(),
            widgets_order: default_config.widgets.order.clone(),
        };

        if let Ok(mut runtime) = self.widget_runtime.write() {
            runtime.configure(&default_config.widgets.enabled, &default_config.widgets.order);
        }
        if let Ok(mut tray) = self.tray_engine.write() {
            *tray = TrayEngine::new(default_config.tray.max_items);
        }

        info!("Settings reset to defaults");
        Ok(())
    }

    fn log(&self, msg: &str) {
        if let Ok(mut buf) = self.log_buffer.write() {
            buf.push(msg.to_string());
            if buf.len() > 1000 {
                buf.drain(0..500);
            }
        }
    }

    /// Get current UI snapshot for Swift to render.
    pub fn snapshot(&self) -> UiSnapshot {
        let state = self.state.read().unwrap().clone();
        let widget_vms = self
            .widget_runtime
            .read()
            .map(|r| r.get_view_models())
            .unwrap_or_default();
        let nook = NookViewModel {
            widgets: widget_vms,
        };
        let mut snap = state.to_snapshot();
        snap.nook = nook;
        snap
    }

    /// Take accumulated log messages.
    pub fn take_logs(&self) -> String {
        self.log_buffer
            .write()
            .map(|mut buf| {
                let out = buf.join("\n");
                buf.clear();
                out
            })
            .unwrap_or_default()
    }
}
