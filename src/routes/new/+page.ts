import { browser } from '$app/environment';

export const ssr = false;

export async function load({ url }) {
	if (!browser) return { spaces: [], preselectedElement: null };

	const { store } = await import('$lib/store');
	const spaces = await store.getSpaces();
	const preselectedElement = url.searchParams.get('space');

	return { spaces, preselectedElement };
}
