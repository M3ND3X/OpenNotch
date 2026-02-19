//! Side effects that Swift must execute.
//!
//! Rust returns these from dispatch(); Swift performs the actual Apple API calls.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Effect {
    // Navigation
    OpenUrl { url: String },

    // Tray actions
    ShowQuickLook { paths: Vec<String> },
    RevealInFinder { path: String },
    CopyToPasteboard { paths: Vec<String> },
    ShareItems { item_ids: Vec<String> },
    RenameFile { old_path: String, new_path: String },

    // Permissions
    RequestPermission { permission: String },

    // Shortcuts
    RunShortcut { name: String },

    // No-op (e.g. for commands that only update state)
    None,
}
