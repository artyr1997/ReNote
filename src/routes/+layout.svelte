<script lang="ts">
	import '../app.css';
	import { page } from '$app/stores';
	import InfoPopup from '$lib/InfoPopup.svelte';
	let { children } = $props();

	let showInfo = $derived($page.url.pathname !== '/');
</script>

{@render children()}
{#if showInfo}
	<InfoPopup />
{/if}
