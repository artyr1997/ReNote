import { browser } from '$app/environment';

export const ssr = false;

export async function load() {
	if (!browser) return { spaces: [], noteCounts: {}, notes: [] };

	const { store } = await import('$lib/store');
	const [spaces, notes] = await Promise.all([store.getSpaces(), store.getNotes()]);

	const noteCounts: Record<number, number> = {};
	for (const note of notes) {
		noteCounts[note.spaceId] = (noteCounts[note.spaceId] ?? 0) + 1;
	}

	return { spaces, noteCounts, notes };
}
