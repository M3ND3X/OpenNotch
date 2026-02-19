//! Tray (file shelf) engine.
//!
//! Handles items, selection, ordering. Swift handles drag-drop and Apple APIs.

use crate::commands::TrayAddPayload;
use crate::state::{TrayItemViewModel, TrayViewModel};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrayItem {
    pub id: String,
    pub path: Option<String>,
    pub url: Option<String>,
    pub text: Option<String>,
    pub item_type: String,
    pub size_hint: String,
    pub bookmark_data: Vec<u8>,
}

impl TrayItem {
    pub fn display_name(&self) -> String {
        if let Some(ref p) = self.path {
            std::path::Path::new(p)
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or(p)
                .to_string()
        } else if let Some(ref u) = self.url {
            u.clone()
        } else if let Some(ref t) = self.text {
            let preview = t.chars().take(50).collect::<String>();
            if t.len() > 50 {
                format!("{}…", preview)
            } else {
                preview
            }
        } else {
            "Unknown".to_string()
        }
    }

    pub fn to_view_model(&self, is_selected: bool) -> TrayItemViewModel {
        TrayItemViewModel {
            id: self.id.clone(),
            display_name: self.display_name(),
            item_type: self.item_type.clone(),
            size_hint: self.size_hint.clone(),
            is_selected,
        }
    }
}

#[derive(Debug, Default)]
pub struct TrayEngine {
    items: Vec<TrayItem>,
    selected_ids: HashSet<String>,
    max_items: u32,
}

impl TrayEngine {
    pub fn new(max_items: u32) -> Self {
        Self {
            items: vec![],
            selected_ids: HashSet::new(),
            max_items,
        }
    }

    pub fn add_items(&mut self, payload: TrayAddPayload, max_items: u32) {
        self.max_items = max_items;
        for path in payload.file_paths {
            if self.items.len() >= self.max_items as usize {
                break;
            }
            let id = Uuid::new_v4().to_string();
            let bookmark = payload
                .bookmark_data
                .get(self.items.len())
                .cloned()
                .unwrap_or_default();
            self.items.push(TrayItem {
                id: id.clone(),
                path: Some(path),
                url: None,
                text: None,
                item_type: "file".to_string(),
                size_hint: "".to_string(),
                bookmark_data: bookmark,
            });
        }
        for url in payload.urls {
            if self.items.len() >= self.max_items as usize {
                break;
            }
            self.items.push(TrayItem {
                id: Uuid::new_v4().to_string(),
                path: None,
                url: Some(url),
                text: None,
                item_type: "url".to_string(),
                size_hint: "".to_string(),
                bookmark_data: vec![],
            });
        }
        for text in payload.text_items {
            if self.items.len() >= self.max_items as usize {
                break;
            }
            self.items.push(TrayItem {
                id: Uuid::new_v4().to_string(),
                path: None,
                url: None,
                text: Some(text),
                item_type: "text".to_string(),
                size_hint: "".to_string(),
                bookmark_data: vec![],
            });
        }
    }

    pub fn remove_items(&mut self, item_ids: &[String]) {
        let to_remove: HashSet<_> = item_ids.iter().cloned().collect();
        self.items.retain(|i| !to_remove.contains(&i.id));
        for id in item_ids {
            self.selected_ids.remove(id);
        }
    }

    pub fn select(&mut self, item_id: &str, add_to_selection: bool) {
        if !add_to_selection {
            self.selected_ids.clear();
        }
        if self.items.iter().any(|i| i.id == item_id) {
            self.selected_ids.insert(item_id.to_string());
        }
    }

    pub fn select_all(&mut self) {
        self.selected_ids = self.items.iter().map(|i| i.id.clone()).collect();
    }

    pub fn clear_selection(&mut self) {
        self.selected_ids.clear();
    }

    pub fn to_view_model(&self) -> TrayViewModel {
        TrayViewModel {
            items: self
                .items
                .iter()
                .map(|i| i.to_view_model(self.selected_ids.contains(&i.id)))
                .collect(),
            selected_ids: self.selected_ids.iter().cloned().collect(),
        }
    }

    pub fn get_selected_paths(&self) -> Vec<String> {
        self.items
            .iter()
            .filter(|i| self.selected_ids.contains(&i.id) && i.path.is_some())
            .filter_map(|i| i.path.clone())
            .collect()
    }

    pub fn get_item_by_id(&self, id: &str) -> Option<&TrayItem> {
        self.items.iter().find(|i| i.id == id)
    }

    pub fn get_item_path(&self, id: &str) -> Option<String> {
        self.get_item_by_id(id).and_then(|i| i.path.clone())
    }

    pub fn get_paths_for_ids(&self, ids: &[String]) -> Vec<String> {
        ids.iter().filter_map(|id| self.get_item_path(id)).collect()
    }
}
