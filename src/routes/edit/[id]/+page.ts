import { browser } from '$app/environment';
import { error } from '@sveltejs/kit';

export const ssr = false;

export async function load({ params }) {
	if (!browser) return { note: null, space: null };

	const { db } = await import('$lib/db');
	const id = parseInt(params.id);
	const note = await db.notes.get(id);
	if (!note) throw error(404, 'Note not found');

	const space = await db.spaces.get(note.spaceId);
	return { note, space };
}
