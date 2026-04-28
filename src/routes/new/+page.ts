import { browser } from '$app/environment';

export const ssr = false;

export async function load({ url }) {
	if (!browser) return { spaces: [], preselectedElement: null };

	const { db } = await import('$lib/db');
	const spaces = await db.spaces.toArray();
	const preselectedElement = url.searchParams.get('space');

	return { spaces, preselectedElement };
}
