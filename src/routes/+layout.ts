import { browser } from '$app/environment';
import { redirect } from '@sveltejs/kit';

export const prerender = false;
export const ssr = false;

export async function load({ url }) {
	if (!browser) return {};

	const path = url.pathname;

	// Always allow landing and home
	if (path === '/' || path === '/home') return {};

	// For all other routes, ensure DB is initialized
	const { isInitialized } = await import('$lib/db');
	const initialized = await isInitialized();
	if (!initialized) {
		throw redirect(302, '/');
	}

	return {};
}
