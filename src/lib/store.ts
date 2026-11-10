// One data API for the whole UI.
// In the browser notes live in IndexedDB (Dexie, see db.ts);
// in the desktop app (Tauri) they live in a SQLite file managed by Rust (src-tauri).
import type { Note, Space } from './db';
import { SPACES } from './db';

export type NewNote = Omit<Note, 'id'>;
export type NoteChanges = Partial<Omit<Note, 'id' | 'createdAt'>>;

interface Backend {
	isInitialized(): Promise<boolean>;
	seedSpaces(): Promise<void>;
	getSpaces(): Promise<Space[]>;
	/** newest first; all notes when spaceId is omitted */
	getNotes(spaceId?: number): Promise<Note[]>;
	getNote(id: number): Promise<Note | undefined>;
	addNote(note: NewNote): Promise<number>;
	addNotes(notes: NewNote[]): Promise<void>;
	updateNote(id: number, changes: NoteChanges): Promise<void>;
	deleteNote(id: number): Promise<void>;
	/** writes an export; false when the user cancelled */
	saveExport(json: string, fileName: string): Promise<boolean>;
}

export const isDesktop = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

const byNewest = (a: Note, b: Note) => b.updatedAt - a.updatedAt;

const web: Backend = {
	async isInitialized() {
		const { isInitialized } = await import('./db');
		return isInitialized();
	},
	async seedSpaces() {
		const { seedSpaces } = await import('./db');
		await seedSpaces();
	},
	async getSpaces() {
		const { db } = await import('./db');
		return db.spaces.toArray();
	},
	async getNotes(spaceId) {
		const { db } = await import('./db');
		const notes = spaceId === undefined
			? await db.notes.toArray()
			: await db.notes.where('spaceId').equals(spaceId).toArray();
		return notes.sort(byNewest);
	},
	async getNote(id) {
		const { db } = await import('./db');
		return db.notes.get(id);
	},
	async addNote(note) {
		const { db } = await import('./db');
		return db.notes.add(note);
	},
	async addNotes(notes) {
		const { db } = await import('./db');
		await db.notes.bulkAdd(notes);
	},
	async updateNote(id, changes) {
		const { db } = await import('./db');
		await db.notes.update(id, changes);
	},
	async deleteNote(id) {
		const { db } = await import('./db');
		await db.notes.delete(id);
	},
	async saveExport(json, fileName) {
		const blob = new Blob([json], { type: 'application/json' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = fileName;
		a.click();
		URL.revokeObjectURL(url);
		return true;
	},
};

async function call<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
	const { invoke } = await import('@tauri-apps/api/core');
	return invoke<T>(cmd, args);
}

const desktop: Backend = {
	isInitialized: () => call('is_initialized'),
	seedSpaces: () => call('seed_spaces', { spaces: SPACES }),
	getSpaces: () => call('get_spaces'),
	getNotes: spaceId => call('get_notes', { spaceId: spaceId ?? null }),
	getNote: async id => (await call<Note | null>('get_note', { id })) ?? undefined,
	addNote: note => call('add_note', { note }),
	addNotes: notes => call('add_notes', { notes }),
	updateNote: (id, changes) => call('update_note', { id, changes }),
	deleteNote: id => call('delete_note', { id }),
	async saveExport(json, fileName) {
		const { save } = await import('@tauri-apps/plugin-dialog');
		const path = await save({ defaultPath: fileName, filters: [{ name: 'JSON', extensions: ['json'] }] });
		if (!path) return false;
		await call('write_text_file', { path, contents: json });
		return true;
	},
};

export const store: Backend = isDesktop ? desktop : web;

// ── helpers built on the backend ──

export async function getSpaceByElement(element: string): Promise<Space | undefined> {
	return (await store.getSpaces()).find(s => s.element === element);
}

export async function getSpace(id: number): Promise<Space | undefined> {
	return (await store.getSpaces()).find(s => s.id === id);
}

/** total number of notes and per-space counts keyed by the space's English name */
export async function getNoteStats(): Promise<{ total: number; bySpace: Record<string, number> }> {
	const [spaces, notes] = await Promise.all([store.getSpaces(), store.getNotes()]);
	const bySpace: Record<string, number> = {};
	for (const s of spaces) bySpace[s.english] = notes.filter(n => n.spaceId === s.id).length;
	return { total: notes.length, bySpace };
}

/** opens a link in the system browser on desktop, a new tab on the web */
export async function openExternal(url: string) {
	if (isDesktop) {
		const { openUrl } = await import('@tauri-apps/plugin-opener');
		await openUrl(url);
	} else {
		window.open(url, '_blank', 'noopener,noreferrer');
	}
}
