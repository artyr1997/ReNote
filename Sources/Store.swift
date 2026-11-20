import Foundation
import SQLite3

// The notes: one SQLite file in the app's data folder, the same the app kept before
// (~/Library/Application Support/com.artursavytskyi.renote/renote.sqlite), so nothing moves.

struct Space {
    let id: Int64
    let element: String
    let kanji: String
    let english: String
    let color: String
    let description: String
    let types: [String]
}

struct Note {
    let id: Int64
    var spaceId: Int64
    var title: String
    var body: String
    let createdAt: Int64
    var updatedAt: Int64
}

let TITLE_MAX = 40

/// now, in milliseconds (as the notes have always kept their times)
func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

/// the four spaces, in their order
let SPACES: [(element: String, kanji: String, english: String, color: String, description: String, types: [String])] = [
    ("water", "水", "Feel", "#3FB5D3",
     "Feel.   Everything you absorb. Everything that stays. Knowledge does not arrive complete. It settles. Layer by layer. Thought by thought. Over time, it becomes clarity. This is where you keep what the world has already said so you can understand it on your own terms.",
     ["Summaries", "Quotes", "Facts", "Instructions", "Glossaries", "Research", "References"]),
    ("earth", "土", "Body", "#E6B422",
     "Body. Reality lives here. Things that require action, movement, decisions. Not ideas, but execution. This is the weight you carry every day. Plans that need structure. Tasks that need completion. Grounded. Practical. Unavoidable.",
     ["Tasks", "Plans", "Deadlines", "Meetings", "Goals", "Priorities", "Habits"]),
    ("fire", "火", "Mind", "#EA5550",
     "Mind. Before clarity, there is chaos. This is where thoughts are born. Unfinished. Unfiltered. Alive. Ideas do not need permission here. They do not need structure. Not yet. This is the space of creation where something begins without knowing what it will become.",
     ["Ideas", "Concepts", "Hypotheses", "Plots", "Associations", "Questions", "Brainstorm"]),
    ("air", "気", "Soul", "#00CFB0",
     "Soul. The quiet layer beneath everything else. Not what you do, but who you are when nothing is required. This is where meaning lives. Where you process, remember, and feel. Invisible, but essential.",
     ["Journal", "Emotions", "Reflection", "Dreams", "Memories", "Values", "Letters"]),
]

private let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class Store {
    static let shared = Store()
    static var path: String?

    private var db: OpaquePointer?
    private(set) var spaces: [Space] = []

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("com.artursavytskyi.renote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // another file in its place (--render draws its pages from made-up notes)
        let path = Store.path ?? dir.appendingPathComponent("renote.sqlite").path
        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        exec("PRAGMA journal_mode=WAL")
        exec("""
            CREATE TABLE IF NOT EXISTS spaces (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                element     TEXT NOT NULL UNIQUE,
                kanji       TEXT NOT NULL,
                english     TEXT NOT NULL,
                color       TEXT NOT NULL,
                description TEXT NOT NULL,
                types       TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS notes (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                space_id    INTEGER NOT NULL REFERENCES spaces(id),
                title       TEXT NOT NULL,
                body        TEXT NOT NULL,
                created_at  INTEGER NOT NULL,
                updated_at  INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS notes_by_space ON notes(space_id, updated_at DESC);
            """)
        seed()
        spaces = loadSpaces()
    }

    // ── SQLite, plainly ──

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private enum Value { case int(Int64), text(String), null }

    @discardableResult
    private func run(_ sql: String, _ values: [Value] = [], row: ((OpaquePointer) -> Void)? = nil) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return false }
        defer { sqlite3_finalize(stmt) }
        for (i, value) in values.enumerated() {
            let at = Int32(i + 1)
            switch value {
            case .int(let n): sqlite3_bind_int64(stmt, at, n)
            case .text(let s): sqlite3_bind_text(stmt, at, s, -1, TRANSIENT)
            case .null: sqlite3_bind_null(stmt, at)
            }
        }
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_ROW { row?(stmt); continue }
            return step == SQLITE_DONE
        }
    }

    private func text(_ stmt: OpaquePointer, _ col: Int32) -> String {
        sqlite3_column_text(stmt, col).map { String(cString: $0) } ?? ""
    }

    // ── spaces ──

    /// the spaces once; later the ones there stay
    private func seed() {
        var count: Int64 = 0
        run("SELECT COUNT(*) FROM spaces") { count = sqlite3_column_int64($0, 0) }
        guard count == 0 else { return }
        exec("BEGIN")
        for s in SPACES {
            let types = (try? JSONSerialization.data(withJSONObject: s.types)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            run("INSERT INTO spaces (element, kanji, english, color, description, types) VALUES (?, ?, ?, ?, ?, ?)",
                [.text(s.element), .text(s.kanji), .text(s.english), .text(s.color), .text(s.description), .text(types)])
        }
        exec("COMMIT")
    }

    private func loadSpaces() -> [Space] {
        var out: [Space] = []
        run("SELECT id, element, kanji, english, color, description, types FROM spaces ORDER BY id") { s in
            let types = (try? JSONSerialization.jsonObject(with: Data(self.text(s, 6).utf8))) as? [String] ?? []
            out.append(Space(id: sqlite3_column_int64(s, 0), element: self.text(s, 1), kanji: self.text(s, 2),
                             english: self.text(s, 3), color: self.text(s, 4), description: self.text(s, 5), types: types))
        }
        return out
    }

    func space(_ element: String) -> Space? { spaces.first { $0.element == element } }
    func space(id: Int64) -> Space? { spaces.first { $0.id == id } }

    // ── notes ──

    private func note(_ s: OpaquePointer) -> Note {
        Note(id: sqlite3_column_int64(s, 0), spaceId: sqlite3_column_int64(s, 1), title: text(s, 2), body: text(s, 3),
             createdAt: sqlite3_column_int64(s, 4), updatedAt: sqlite3_column_int64(s, 5))
    }

    /// newest first; every note when `space` is nil
    func notes(in space: Int64? = nil) -> [Note] {
        var out: [Note] = []
        run("SELECT id, space_id, title, body, created_at, updated_at FROM notes WHERE ?1 IS NULL OR space_id = ?1 ORDER BY updated_at DESC, id DESC",
            [space.map { .int($0) } ?? .null]) { out.append(self.note($0)) }
        return out
    }

    func note(_ id: Int64) -> Note? {
        var out: Note?
        run("SELECT id, space_id, title, body, created_at, updated_at FROM notes WHERE id = ?", [.int(id)]) { out = self.note($0) }
        return out
    }

    @discardableResult
    func add(space: Int64, title: String, body: String, createdAt: Int64, updatedAt: Int64) -> Int64 {
        run("INSERT INTO notes (space_id, title, body, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
            [.int(space), .text(title), .text(body), .int(createdAt), .int(updatedAt)])
        return sqlite3_last_insert_rowid(db)
    }

    func addMany(_ notes: [(space: Int64, title: String, body: String, createdAt: Int64, updatedAt: Int64)]) {
        exec("BEGIN")
        for n in notes { add(space: n.space, title: n.title, body: n.body, createdAt: n.createdAt, updatedAt: n.updatedAt) }
        exec("COMMIT")
    }

    /// only the fields given change
    func update(_ id: Int64, space: Int64? = nil, title: String? = nil, body: String? = nil, updatedAt: Int64? = nil) {
        run("""
            UPDATE notes SET space_id = COALESCE(?1, space_id), title = COALESCE(?2, title),
                body = COALESCE(?3, body), updated_at = COALESCE(?4, updated_at) WHERE id = ?5
            """, [space.map { .int($0) } ?? .null, title.map { .text($0) } ?? .null, body.map { .text($0) } ?? .null,
                  updatedAt.map { .int($0) } ?? .null, .int(id)])
    }

    func delete(_ id: Int64) {
        run("DELETE FROM notes WHERE id = ?", [.int(id)])
    }

    /// how many notes, and how many in each space (by its English name)
    func stats() -> (total: Int, bySpace: [String: Int]) {
        let all = notes()
        var by: [String: Int] = [:]
        for s in spaces { by[s.english] = all.filter { $0.spaceId == s.id }.count }
        return (all.count, by)
    }
}
