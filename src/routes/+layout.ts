import { browser } from '$app/environment';
import { redirect } from '@sveltejs/kit';

export const prerender = false;
export const ssr = false;

export async function load({ url, route }) {
	if (!browser) return {};

	const path = url.pathname;
	const { store, isDesktop } = await import('$lib/store');

	// The desktop app has no landing page: set up the spaces and go straight home
	if (isDesktop) {
		await store.seedSpaces();
		// matched by route, not URL: the desktop webview opens the landing as /index.html
		if (route.id === '/') throw redirect(302, '/home');
		return {};
	}

	// The website is only ReSpace's landing; the notes live in the desktop app
	if (path !== '/') throw redirect(302, '/');

	return {};
}
