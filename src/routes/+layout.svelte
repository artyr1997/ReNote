<script lang="ts">
	import '@fontsource/kurale/400.css';
	import '@fontsource/noto-sans-jp/300.css';
	import '@fontsource/noto-sans-jp/400.css';
	import '@fontsource/noto-sans-jp/500.css';
	import '../app.css';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import InfoPopup from '$lib/InfoPopup.svelte';
	import WindowControls from '$lib/WindowControls.svelte';
	import { isDesktop } from '$lib/store';
	let { children } = $props();

	// lets the styles tell the desktop app from the website (small windows, see app.css)
	if (isDesktop) document.documentElement.classList.add('desktop');

	// drawn, with its fonts (or not later than 300 ms): the desktop window fades in (it starts hidden)
	onMount(() => {
		if (!isDesktop) return;
		Promise.race([document.fonts.ready, new Promise((done) => setTimeout(done, 300))])
			.then(() => import('@tauri-apps/api/core'))
			.then(({ invoke }) => invoke('window_ready'));
		// ⌘N: another window (src-tauri/src/lib.rs, new_window), before the pages' own keys (N: a new note)
		const newWindow = (e: KeyboardEvent) => {
			if (e.metaKey && !e.shiftKey && !e.altKey && !e.ctrlKey && e.code === 'KeyN') {
				e.preventDefault();
				e.stopImmediatePropagation();
				import('@tauri-apps/api/core').then(({ invoke }) => invoke('new_window'));
			}
		};
		window.addEventListener('keydown', newWindow, true);
		return () => window.removeEventListener('keydown', newWindow, true);
	});

	// no INFO on the landing and on the note editors (full note, new note).
	// Matched by route id, not URL, so it holds in the desktop app's webview too.
	const noInfoRoutes = ['/', '/note/[id]', '/new'];
	let showInfo = $derived(!noInfoRoutes.includes($page.route.id ?? ''));
</script>

{#if isDesktop}
	<WindowControls />
{/if}

{@render children()}
{#if showInfo}
	<InfoPopup />
{/if}
