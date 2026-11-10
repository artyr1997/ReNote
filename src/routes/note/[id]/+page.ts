import { browser } from '$app/environment';
import { error } from '@sveltejs/kit';

export const ssr = false;

export async function load({ params }) {
	if (!browser) return { note: null, space: null, nextId: null, prevId: null };

	const { store } = await import('$lib/store');
	const id = parseInt(params.id);
	const note = await store.getNote(id);
	if (!note) throw error(404, 'Note not found');

	const spaces = await store.getSpaces();
	const space = spaces.find(s => s.id === note.spaceId);

	return { note, space, spaces };
}
