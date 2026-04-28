import { browser } from '$app/environment';
import { error } from '@sveltejs/kit';

export const ssr = false;

export async function load({ params }) {
	if (!browser) return { note: null, space: null, nextId: null, prevId: null };

	const { db } = await import('$lib/db');
	const id = parseInt(params.id);
	const note = await db.notes.get(id);
	if (!note) throw error(404, 'Note not found');

	const space = await db.spaces.get(note.spaceId);
	const siblings = await db.notes
		.where('spaceId')
		.equals(note.spaceId)
		.sortBy('updatedAt');
	siblings.reverse();

	const idx = siblings.findIndex(n => n.id === id);
	const nextId = idx >= 0 && idx < siblings.length - 1 ? siblings[idx + 1].id : null;

	return { note, space, nextId };
}
