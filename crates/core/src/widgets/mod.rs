//! Widget runtime and registry.
//!
//! Widgets are modular, reorderable components in the Nook strip.

use crate::state::WidgetViewModel;
use std::collections::HashMap;
use std::path::Path;
use std::sync::{Arc, RwLock};

/// Widget protocol - each widget implements this.
pub trait WidgetProtocol: Send + Sync {
    fn id(&self) -> &str;
    fn name(&self) -> &str;
    fn compact_view_model(&self) -> WidgetViewModel;
    fn expanded_view_model(&self) -> WidgetViewModel;
    fn on_tick(&mut self, _delta_ms: u64) {}
    fn on_action(&mut self, _action: &str) {}
}

/// Widget registry - manages enabled widgets and ordering.
#[derive(Debug, Default)]
pub struct WidgetRegistry {
    pub enabled: Vec<String>,
    pub order: Vec<String>,
}

impl WidgetRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_order(&mut self, order: Vec<String>) {
        self.order = order;
    }

    pub fn set_enabled(&mut self, enabled: Vec<String>) {
        self.enabled = enabled;
    }
}

/// Placeholder widget for development.
#[derive(Debug)]
pub struct PlaceholderWidget {
    id: String,
    name: String,
    expanded: bool,
}

impl PlaceholderWidget {
    pub fn new(id: impl Into<String>, name: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            expanded: false,
        }
    }
}

/// Notes widget - placeholder; full SQLite integration in NotesRepo.
#[derive(Debug)]
pub struct NotesWidget;

impl NotesWidget {
    pub fn new() -> Self {
        Self
    }
}

impl Default for NotesWidget {
    fn default() -> Self {
        Self::new()
    }
}

impl WidgetProtocol for NotesWidget {
    fn id(&self) -> &str {
        "notes"
    }
    fn name(&self) -> &str {
        "Notes"
    }
    fn compact_view_model(&self) -> WidgetViewModel {
        WidgetViewModel {
            id: "notes".to_string(),
            name: "Notes".to_string(),
            compact_title: "Notes".to_string(),
            compact_content: "0 notes".to_string(),
            expanded_content: "Tap to add note".to_string(),
            is_expanded: false,
        }
    }
    fn expanded_view_model(&self) -> WidgetViewModel {
        let mut vm = self.compact_view_model();
        vm.is_expanded = true;
        vm.expanded_content = "Search and view notes".to_string();
        vm
    }
}

/// Calendar widget - receives events from Swift EventKit.
#[derive(Debug)]
pub struct CalendarWidget {
    events_json: Arc<RwLock<String>>,
}

impl CalendarWidget {
    pub fn new(events_json: Arc<RwLock<String>>) -> Self {
        Self { events_json }
    }
}

impl WidgetProtocol for CalendarWidget {
    fn id(&self) -> &str {
        "calendar"
    }
    fn name(&self) -> &str {
        "Calendar"
    }
    fn compact_view_model(&self) -> WidgetViewModel {
        let count = self
            .events_json
            .read()
            .ok()
            .and_then(|s| serde_json::from_str::<Vec<serde_json::Value>>(&s).ok())
            .map(|v: Vec<serde_json::Value>| v.len())
            .unwrap_or(0);
        WidgetViewModel {
            id: "calendar".to_string(),
            name: "Calendar".to_string(),
            compact_title: "Calendar".to_string(),
            compact_content: format!("{} events", count),
            expanded_content: "Upcoming events".to_string(),
            is_expanded: false,
        }
    }
    fn expanded_view_model(&self) -> WidgetViewModel {
        let mut vm = self.compact_view_model();
        vm.is_expanded = true;
        vm
    }
}

/// Shortcuts widget - runs shortcuts via Swift.
#[derive(Debug)]
pub struct ShortcutsWidget {
    shortcuts: Arc<RwLock<Vec<String>>>,
}

impl ShortcutsWidget {
    pub fn new() -> Self {
        Self {
            shortcuts: Arc::new(RwLock::new(vec![])),
        }
    }
}

impl Default for ShortcutsWidget {
    fn default() -> Self {
        Self::new()
    }
}

impl WidgetProtocol for ShortcutsWidget {
    fn id(&self) -> &str {
        "shortcuts"
    }
    fn name(&self) -> &str {
        "Shortcuts"
    }
    fn compact_view_model(&self) -> WidgetViewModel {
        let count = self.shortcuts.read().map(|s| s.len()).unwrap_or(0);
        WidgetViewModel {
            id: "shortcuts".to_string(),
            name: "Shortcuts".to_string(),
            compact_title: "Shortcuts".to_string(),
            compact_content: format!("{} shortcuts", count),
            expanded_content: "Tap to run".to_string(),
            is_expanded: false,
        }
    }
    fn expanded_view_model(&self) -> WidgetViewModel {
        let mut vm = self.compact_view_model();
        vm.is_expanded = true;
        vm
    }
}

/// Media widget - now playing from Swift.
#[derive(Debug)]
pub struct MediaWidget {
    state_json: Arc<RwLock<String>>,
}

impl MediaWidget {
    pub fn new(state_json: Arc<RwLock<String>>) -> Self {
        Self { state_json }
    }
}

impl WidgetProtocol for MediaWidget {
    fn id(&self) -> &str {
        "media"
    }
    fn name(&self) -> &str {
        "Media"
    }
    fn compact_view_model(&self) -> WidgetViewModel {
        let title = self
            .state_json
            .read()
            .ok()
            .and_then(|s| serde_json::from_str::<serde_json::Value>(&s).ok())
            .and_then(|v| v.get("title").and_then(|t| t.as_str()).map(String::from))
            .unwrap_or_else(|| "—".to_string());
        WidgetViewModel {
            id: "media".to_string(),
            name: "Media".to_string(),
            compact_title: "Now Playing".to_string(),
            compact_content: title,
            expanded_content: "Music controls".to_string(),
            is_expanded: false,
        }
    }
    fn expanded_view_model(&self) -> WidgetViewModel {
        let mut vm = self.compact_view_model();
        vm.is_expanded = true;
        vm
    }
}

/// Camera widget - camera list from Swift.
#[derive(Debug)]
pub struct CameraWidget {
    cameras_json: Arc<RwLock<String>>,
}

impl CameraWidget {
    pub fn new(cameras_json: Arc<RwLock<String>>) -> Self {
        Self { cameras_json }
    }
}

impl WidgetProtocol for CameraWidget {
    fn id(&self) -> &str {
        "camera"
    }
    fn name(&self) -> &str {
        "Camera"
    }
    fn compact_view_model(&self) -> WidgetViewModel {
        let count = self
            .cameras_json
            .read()
            .ok()
            .and_then(|s| serde_json::from_str::<Vec<serde_json::Value>>(&s).ok())
            .map(|v: Vec<serde_json::Value>| v.len())
            .unwrap_or(0);
        WidgetViewModel {
            id: "camera".to_string(),
            name: "Camera".to_string(),
            compact_title: "Camera".to_string(),
            compact_content: format!("{} cameras", count),
            expanded_content: "Camera preview".to_string(),
            is_expanded: false,
        }
    }
    fn expanded_view_model(&self) -> WidgetViewModel {
        let mut vm = self.compact_view_model();
        vm.is_expanded = true;
        vm
    }
}

impl WidgetProtocol for PlaceholderWidget {
    fn id(&self) -> &str {
        &self.id
    }
    fn name(&self) -> &str {
        &self.name
    }
    fn compact_view_model(&self) -> WidgetViewModel {
        let mut vm = WidgetViewModel {
            id: self.id.clone(),
            name: self.name.clone(),
            compact_title: self.name.clone(),
            compact_content: "—".to_string(),
            expanded_content: "Placeholder widget".to_string(),
            is_expanded: self.expanded,
        };
        if self.expanded {
            vm.compact_content = "Expanded".to_string();
        }
        vm
    }
    fn expanded_view_model(&self) -> WidgetViewModel {
        let mut vm = self.compact_view_model();
        vm.is_expanded = true;
        vm
    }
    fn on_action(&mut self, action: &str) {
        if action == "tap" {
            self.expanded = !self.expanded;
        }
    }
}

/// Shared data for platform-backed widgets.
struct PlatformWidgetData {
    calendar_events: Arc<RwLock<String>>,
    media_state: Arc<RwLock<String>>,
    cameras: Arc<RwLock<String>>,
}

/// Widget runtime - holds widget instances and produces view models.
pub struct WidgetRuntime {
    registry: WidgetRegistry,
    widgets: HashMap<String, Box<dyn WidgetProtocol>>,
    platform_data: Option<PlatformWidgetData>,
}

impl WidgetRuntime {
    pub fn new() -> Self {
        let mut runtime = Self {
            registry: WidgetRegistry::default(),
            widgets: HashMap::new(),
            platform_data: None,
        };
        runtime.register_default_widgets();
        runtime
    }

    fn register_default_widgets(&mut self) {
        self.widgets.insert(
            "placeholder".to_string(),
            Box::new(PlaceholderWidget::new("placeholder", "Widget")),
        );
    }

    pub fn with_notes_db(mut self, _notes_path: &Path) -> Self {
        self.widgets
            .insert("notes".to_string(), Box::new(NotesWidget::new()));
        self
    }

    pub fn with_platform_widgets(mut self) -> Self {
        let calendar_events = Arc::new(RwLock::new("[]".to_string()));
        let media_state = Arc::new(RwLock::new("{}".to_string()));
        let cameras = Arc::new(RwLock::new("[]".to_string()));

        self.widgets.insert(
            "calendar".to_string(),
            Box::new(CalendarWidget::new(calendar_events.clone())),
        );
        self.widgets
            .insert("shortcuts".to_string(), Box::new(ShortcutsWidget::new()));
        self.widgets.insert(
            "media".to_string(),
            Box::new(MediaWidget::new(media_state.clone())),
        );
        self.widgets.insert(
            "camera".to_string(),
            Box::new(CameraWidget::new(cameras.clone())),
        );
        self.platform_data = Some(PlatformWidgetData {
            calendar_events,
            media_state,
            cameras,
        });
        self
    }

    pub fn receive_calendar_events(&self, json: &str) {
        if let Some(ref data) = self.platform_data {
            if let Ok(mut g) = data.calendar_events.write() {
                *g = json.to_string();
            }
        }
    }

    pub fn receive_media_state(&self, json: &str) {
        if let Some(ref data) = self.platform_data {
            if let Ok(mut g) = data.media_state.write() {
                *g = json.to_string();
            }
        }
    }

    pub fn receive_cameras(&self, json: &str) {
        if let Some(ref data) = self.platform_data {
            if let Ok(mut g) = data.cameras.write() {
                *g = json.to_string();
            }
        }
    }

    pub fn configure(&mut self, enabled: &[String], order: &[String]) {
        self.registry.set_enabled(enabled.to_vec());
        self.registry.set_order(order.to_vec());
    }

    pub fn get_view_models(&self) -> Vec<WidgetViewModel> {
        let order = if self.registry.order.is_empty() {
            self.registry.enabled.clone()
        } else {
            self.registry.order.clone()
        };
        let enabled: std::collections::HashSet<_> = self.registry.enabled.iter().collect();
        if enabled.is_empty() {
            return self
                .widgets
                .values()
                .map(|w| w.compact_view_model())
                .collect();
        }
        order
            .iter()
            .filter(|id| enabled.contains(id))
            .filter_map(|id| self.widgets.get(id))
            .map(|w| w.compact_view_model())
            .collect()
    }

    pub fn on_tick(&mut self, delta_ms: u64) {
        for w in self.widgets.values_mut() {
            w.on_tick(delta_ms);
        }
    }

    pub fn on_action(&mut self, widget_id: &str, action: &str) {
        if let Some(w) = self.widgets.get_mut(widget_id) {
            w.on_action(action);
        }
    }
}

impl Default for WidgetRuntime {
    fn default() -> Self {
        Self::new()
    }
}
