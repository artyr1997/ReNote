import { browser } from '$app/environment';

export const ssr = false;

export async function load() {
	if (!browser) return { spaces: [], noteCounts: {}, notes: [] };

	const { db } = await import('$lib/db');
	const spaces = await db.spaces.toArray();
	const notes  = (await db.notes.toArray()).sort((a, b) => b.updatedAt - a.updatedAt);

	const noteCounts: Record<number, number> = {};
	for (const note of notes) {
		noteCounts[note.spaceId] = (noteCounts[note.spaceId] ?? 0) + 1;
	}

	return { spaces, noteCounts, notes };
}
