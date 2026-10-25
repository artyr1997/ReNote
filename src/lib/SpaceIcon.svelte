<script lang="ts">
	let {
		element,
		filled = false,
		size = 16,
		strokeWidth = 1.5,
	}: { element: string; filled?: boolean; size?: number; strokeWidth?: number } = $props();

	const stroke = '#57585A';

	let fill = $derived(filled ? stroke : 'none');
</script>

<svg
	class="space-icon"
	width={size}
	height={size}
	viewBox="0 0 16 16"
	{stroke}
	stroke-width={strokeWidth}
	stroke-linejoin="miter"
	aria-hidden="true"
>
	{#if element === 'water'}
		<!-- Feel: diamond -->
		<polygon points="8,1 15,8 8,15 1,8" {fill} vector-effect="non-scaling-stroke" />
	{:else if element === 'earth'}
		<!-- Body: square -->
		<rect x="2" y="2" width="12" height="12" {fill} vector-effect="non-scaling-stroke" />
	{:else if element === 'fire'}
		<!-- Mind: pentagon -->
		<polygon points="8,1.67 14.66,6.51 12.11,14.33 3.89,14.33 1.34,6.51" {fill} vector-effect="non-scaling-stroke" />
	{:else}
		<!-- Soul: circle -->
		<circle cx="8" cy="8" r="6.25" {fill} vector-effect="non-scaling-stroke" />
	{/if}
</svg>

<style>
	.space-icon {
		display: block;
		flex-shrink: 0;
		transition: fill 200ms ease;
	}
</style>
