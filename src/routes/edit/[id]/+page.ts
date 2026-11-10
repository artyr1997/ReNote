import { browser } from '$app/environment';
import { error } from '@sveltejs/kit';

export const ssr = false;

export async function load({ params }) {
	if (!browser) return { note: null, space: null };

	const { store, getSpace } = await import('$lib/store');
	const id = parseInt(params.id);
	const note = await store.getNote(id);
	if (!note) throw error(404, 'Note not found');

	const space = await getSpace(note.spaceId);
	return { note, space };
}
