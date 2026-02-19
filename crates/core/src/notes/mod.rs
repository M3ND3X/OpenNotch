//! Notes database (SQLite).
//!
//! Local notes, NOT Apple Notes. Schema, migrations, search.

use rusqlite::Connection;
use std::path::Path;
use thiserror::Error;

const SCHEMA_VERSION: u32 = 1;

#[derive(Error, Debug)]
pub enum NotesError {
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

pub struct NotesRepo {
    conn: Connection,
}

impl NotesRepo {
    pub fn new(path: &Path) -> Result<Self, NotesError> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let conn = Connection::open(path)?;
        Self::migrate(&conn)?;
        Ok(Self { conn })
    }

    fn migrate(conn: &Connection) -> Result<(), NotesError> {
        conn.execute(
            "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)",
            [],
        )?;
        let version: u32 = conn
            .query_row("SELECT version FROM schema_version LIMIT 1", [], |r| {
                r.get(0)
            })
            .unwrap_or(0);

        if version < SCHEMA_VERSION {
            conn.execute(
                "CREATE TABLE IF NOT EXISTS notes (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL
                )",
                [],
            )?;
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC)",
                [],
            )?;
            conn.execute(
                "INSERT OR REPLACE INTO schema_version (version) VALUES (?1)",
                [SCHEMA_VERSION],
            )?;
        }

        Ok(())
    }

    pub fn create(&self, id: &str, title: &str, content: &str) -> Result<(), NotesError> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;
        self.conn.execute(
            "INSERT INTO notes (id, title, content, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?4)",
            [id, title, content, &now.to_string()],
        )?;
        Ok(())
    }

    pub fn update(&self, id: &str, title: &str, content: &str) -> Result<(), NotesError> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;
        self.conn.execute(
            "UPDATE notes SET title = ?1, content = ?2, updated_at = ?3 WHERE id = ?4",
            rusqlite::params![title, content, now, id],
        )?;
        Ok(())
    }

    pub fn search(&self, query: &str) -> Result<Vec<(String, String, String)>, NotesError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, title, content FROM notes WHERE title LIKE ?1 OR content LIKE ?1 ORDER BY updated_at DESC",
        )?;
        let pattern = format!("%{}%", query.replace('%', "\\%").replace('_', "\\_"));
        let rows = stmt.query_map([&pattern], |r| {
            Ok((
                r.get::<_, String>(0)?,
                r.get::<_, String>(1)?,
                r.get::<_, String>(2)?,
            ))
        })?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }

    pub fn list_all(&self) -> Result<Vec<(String, String)>, NotesError> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, title FROM notes ORDER BY updated_at DESC")?;
        let rows = stmt.query_map([], |r| Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?)))?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    }
}
