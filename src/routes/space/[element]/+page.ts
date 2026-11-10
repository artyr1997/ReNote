import { browser } from '$app/environment';
import { error } from '@sveltejs/kit';

export const ssr = false;

export async function load({ params, url }) {
	if (!browser) return { space: null, notes: [], selectedId: null };

	const { store, getSpaceByElement } = await import('$lib/store');
	const space = await getSpaceByElement(params.element);
	if (!space) throw error(404, 'Space not found');

	const notes = await store.getNotes(space.id!);

	const selectedId = Number(url.searchParams.get('note')) || null;

	return { space, notes, selectedId };
}
