import { browser } from '$app/environment';
import { error } from '@sveltejs/kit';

export const ssr = false;

export async function load({ params }) {
	if (!browser) return { space: null, notes: [] };

	const { db } = await import('$lib/db');
	const space = await db.spaces.where('element').equals(params.element).first();
	if (!space) throw error(404, 'Space not found');

	const notes = await db.notes
		.where('spaceId')
		.equals(space.id!)
		.reverse()
		.sortBy('updatedAt');

	return { space, notes };
}
