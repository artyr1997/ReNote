//! Notes storage for the desktop app: a single SQLite file in the app data folder.
//! Field names mirror the web app's Dexie records (camelCase over IPC), so the
//! same Svelte UI and the same JSON export/import work on both.

use rusqlite::{params, Connection, OptionalExtension, Row};
use serde::{Deserialize, Serialize};
use std::path::Path;

pub type Result<T> = std::result::Result<T, rusqlite::Error>;

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Space {
    pub id: i64,
    pub element: String,
    pub kanji: String,
    pub english: String,
    pub color: String,
    pub description: String,
    pub types: Vec<String>,
}

/// A space as seeded from the UI (`SPACES` in src/lib/db.ts), before it has an id.
#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct NewSpace {
    pub element: String,
    pub kanji: String,
    pub english: String,
    pub color: String,
    pub description: String,
    pub types: Vec<String>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Note {
    pub id: i64,
    pub space_id: i64,
    pub title: String,
    pub body: String,
    pub created_at: i64,
    pub updated_at: i64,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct NewNote {
    pub space_id: i64,
    pub title: String,
    pub body: String,
    pub created_at: i64,
    pub updated_at: i64,
}

/// Partial update: only the fields that are present change.
#[derive(Deserialize, Debug, Default)]
#[serde(rename_all = "camelCase")]
pub struct NoteChanges {
    pub space_id: Option<i64>,
    pub title: Option<String>,
    pub body: Option<String>,
    pub updated_at: Option<i64>,
}

pub struct Db {
    conn: Connection,
}

const NOTE_COLUMNS: &str = "id, space_id, title, body, created_at, updated_at";

fn note_from_row(row: &Row) -> rusqlite::Result<Note> {
    Ok(Note {
        id: row.get(0)?,
        space_id: row.get(1)?,
        title: row.get(2)?,
        body: row.get(3)?,
        created_at: row.get(4)?,
        updated_at: row.get(5)?,
    })
}

impl Db {
    pub fn open(path: &Path) -> Result<Self> {
        Self::init(Connection::open(path)?)
    }

    #[cfg(test)]
    pub fn open_in_memory() -> Result<Self> {
        Self::init(Connection::open_in_memory()?)
    }

    fn init(conn: Connection) -> Result<Self> {
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS spaces (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                element     TEXT NOT NULL UNIQUE,
                kanji       TEXT NOT NULL,
                english     TEXT NOT NULL,
                color       TEXT NOT NULL,
                description TEXT NOT NULL,
                types       TEXT NOT NULL          -- JSON array
            );
            CREATE TABLE IF NOT EXISTS notes (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                space_id    INTEGER NOT NULL REFERENCES spaces(id),
                title       TEXT NOT NULL,
                body        TEXT NOT NULL,
                created_at  INTEGER NOT NULL,
                updated_at  INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS notes_by_space ON notes(space_id, updated_at DESC);",
        )?;
        Ok(Self { conn })
    }

    pub fn is_initialized(&self) -> Result<bool> {
        let count: i64 = self.conn.query_row("SELECT COUNT(*) FROM spaces", [], |r| r.get(0))?;
        Ok(count > 0)
    }

    /// Inserts the spaces once; later calls leave existing data alone.
    pub fn seed_spaces(&mut self, spaces: &[NewSpace]) -> Result<()> {
        if self.is_initialized()? {
            return Ok(());
        }
        let tx = self.conn.transaction()?;
        for s in spaces {
            tx.execute(
                "INSERT INTO spaces (element, kanji, english, color, description, types)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                params![
                    s.element,
                    s.kanji,
                    s.english,
                    s.color,
                    s.description,
                    serde_json::to_string(&s.types).unwrap_or_else(|_| "[]".into())
                ],
            )?;
        }
        tx.commit()
    }

    pub fn get_spaces(&self) -> Result<Vec<Space>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, element, kanji, english, color, description, types FROM spaces ORDER BY id",
        )?;
        let rows = stmt.query_map([], |r| {
            let types: String = r.get(6)?;
            Ok(Space {
                id: r.get(0)?,
                element: r.get(1)?,
                kanji: r.get(2)?,
                english: r.get(3)?,
                color: r.get(4)?,
                description: r.get(5)?,
                types: serde_json::from_str(&types).unwrap_or_default(),
            })
        })?;
        rows.collect()
    }

    /// Newest first; every note when `space_id` is `None`.
    pub fn get_notes(&self, space_id: Option<i64>) -> Result<Vec<Note>> {
        let sql = format!(
            "SELECT {NOTE_COLUMNS} FROM notes
             WHERE ?1 IS NULL OR space_id = ?1
             ORDER BY updated_at DESC, id DESC"
        );
        let mut stmt = self.conn.prepare(&sql)?;
        let rows = stmt.query_map(params![space_id], note_from_row)?;
        rows.collect()
    }

    pub fn get_note(&self, id: i64) -> Result<Option<Note>> {
        self.conn
            .query_row(
                &format!("SELECT {NOTE_COLUMNS} FROM notes WHERE id = ?1"),
                params![id],
                note_from_row,
            )
            .optional()
    }

    pub fn add_note(&self, note: &NewNote) -> Result<i64> {
        self.conn.execute(
            "INSERT INTO notes (space_id, title, body, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![note.space_id, note.title, note.body, note.created_at, note.updated_at],
        )?;
        Ok(self.conn.last_insert_rowid())
    }

    pub fn add_notes(&mut self, notes: &[NewNote]) -> Result<()> {
        let tx = self.conn.transaction()?;
        for n in notes {
            tx.execute(
                "INSERT INTO notes (space_id, title, body, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                params![n.space_id, n.title, n.body, n.created_at, n.updated_at],
            )?;
        }
        tx.commit()
    }

    pub fn update_note(&self, id: i64, changes: &NoteChanges) -> Result<()> {
        self.conn.execute(
            "UPDATE notes SET
                space_id   = COALESCE(?1, space_id),
                title      = COALESCE(?2, title),
                body       = COALESCE(?3, body),
                updated_at = COALESCE(?4, updated_at)
             WHERE id = ?5",
            params![changes.space_id, changes.title, changes.body, changes.updated_at, id],
        )?;
        Ok(())
    }

    pub fn delete_note(&self, id: i64) -> Result<()> {
        self.conn.execute("DELETE FROM notes WHERE id = ?1", params![id])?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seeded() -> Db {
        let mut db = Db::open_in_memory().unwrap();
        let space = |element: &str| NewSpace {
            element: element.into(),
            kanji: "水".into(),
            english: "Feel".into(),
            color: "#3FB5D3".into(),
            description: "d".into(),
            types: vec!["Quotes".into()],
        };
        db.seed_spaces(&[space("water"), space("earth")]).unwrap();
        db
    }

    fn note(space_id: i64, title: &str, t: i64) -> NewNote {
        NewNote { space_id, title: title.into(), body: "body".into(), created_at: t, updated_at: t }
    }

    #[test]
    fn seeds_spaces_once() {
        let mut db = seeded();
        assert!(db.is_initialized().unwrap());
        db.seed_spaces(&[]).unwrap();
        let spaces = db.get_spaces().unwrap();
        assert_eq!(spaces.len(), 2);
        assert_eq!(spaces[0].types, vec!["Quotes".to_string()]);
    }

    #[test]
    fn notes_crud_and_ordering() {
        let mut db = seeded();
        let a = db.add_note(&note(1, "old", 1)).unwrap();
        let b = db.add_note(&note(1, "new", 2)).unwrap();
        db.add_notes(&[note(2, "other", 3)]).unwrap();

        let in_space: Vec<_> = db.get_notes(Some(1)).unwrap().into_iter().map(|n| n.id).collect();
        assert_eq!(in_space, vec![b, a]);
        assert_eq!(db.get_notes(None).unwrap().len(), 3);

        db.update_note(a, &NoteChanges { title: Some("edited".into()), updated_at: Some(10), ..Default::default() })
            .unwrap();
        let edited = db.get_note(a).unwrap().unwrap();
        assert_eq!(edited.title, "edited");
        assert_eq!(edited.body, "body", "fields not in the change stay as they were");
        assert_eq!(db.get_notes(Some(1)).unwrap()[0].id, a, "edited note moves to the top");

        db.delete_note(a).unwrap();
        assert!(db.get_note(a).unwrap().is_none());
    }
}
