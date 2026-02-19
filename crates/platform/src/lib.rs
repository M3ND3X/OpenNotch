//! macOS-safe platform helpers: paths, file operations, bookmarks.
//!
//! This crate provides abstractions that do NOT require private APIs.
//! All operations use public macOS/Foundation APIs only.

use std::path::PathBuf;

/// Returns the Application Support directory for OpenNotch.
/// Path: `~/Library/Application Support/OpenNotch/`
pub fn app_support_dir() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."))
        .join("Library")
        .join("Application Support")
        .join("OpenNotch")
}

/// Creates the app support directory if it does not exist.
pub fn ensure_app_support_dir() -> std::io::Result<PathBuf> {
    let path = app_support_dir();
    std::fs::create_dir_all(&path)?;
    Ok(path)
}

/// Opaque bookmark data for security-scoped file access.
/// Swift obtains bookmarks and passes bytes; Rust stores them.
#[derive(Clone, Debug, Default)]
pub struct BookmarkData(pub Vec<u8>);

impl BookmarkData {
    pub fn new(data: Vec<u8>) -> Self {
        Self(data)
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.0
    }
}
