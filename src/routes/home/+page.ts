import { browser } from '$app/environment';

export const ssr = false;

export async function load() {
	if (!browser) return { spaces: [], noteCounts: {} };

	const { db } = await import('$lib/db');
	const spaces = await db.spaces.toArray();
	const notes  = await db.notes.toArray();

	const noteCounts: Record<number, number> = {};
	for (const note of notes) {
		noteCounts[note.spaceId] = (noteCounts[note.spaceId] ?? 0) + 1;
	}

	return { spaces, noteCounts };
}
