<script lang="ts">
	import '../app.css';
	import { page } from '$app/stores';
	import InfoPopup from '$lib/InfoPopup.svelte';
	let { children } = $props();

	// no INFO on the landing and on the note editors (full note, new note)
	let showInfo = $derived(
		$page.url.pathname !== '/' &&
		!$page.url.pathname.startsWith('/note/') &&
		$page.url.pathname !== '/new'
	);
</script>

{@render children()}
{#if showInfo}
	<InfoPopup />
{/if}
