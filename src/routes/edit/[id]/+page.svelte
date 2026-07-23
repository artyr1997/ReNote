<script lang="ts">
	import { goto } from '$app/navigation';
	import { db } from '$lib/db';

	let { data } = $props();
	let { note, space } = $derived(data);

	let body = $state('');
	let showInfo = $state(false);

	$effect(() => {
		if (note?.body !== undefined && body === '') {
			body = note.body;
		}
	});

	function deriveTitle(text: string): string {
		const firstLine = text.split('\n')[0].trim();
		return firstLine.slice(0, 60) || 'Untitled';
	}

	function wordCount(text: string): number {
		return text.trim().split(/\s+/).filter(Boolean).length;
	}

	function formatDate(ts: number): string {
		return new Date(ts).toLocaleDateString('en-US', {
			year: 'numeric', month: 'long', day: 'numeric'
		});
	}

	async function save() {
		if (!note?.id) return;
		await db.notes.update(note.id, {
			title: deriveTitle(body),
			body: body.trim(),
			updatedAt: Date.now(),
		});
		goto(`/note/${note.id}`);
	}

	function exit() {
		if (note) goto(`/note/${note.id}`);
	}
</script>

<!-- Frame corners -->
<div class="frame" aria-hidden="true">
	<div class="corner tl"></div>
	<div class="corner tr"></div>
	<div class="corner bl"></div>
	<div class="corner br"></div>
</div>

<!-- Left top nav: EXIT -->
<button class="nav-home" onclick={exit}>EXIT</button>

<!-- Left action button: INFO -->
<button class="nav-info" onclick={() => showInfo = !showInfo}>INFO</button>

<!-- Right button: SAVE -->
<button class="nav-edit" onclick={save}>SAVE</button>

<main class="screen edit-screen fade-in">
	<h1 class="edit-title">EDIT</h1>

	{#if showInfo && note}
		<div class="info-panel fade-in">
			<div class="info-row">
				<span class="info-label">Words</span>
				<span class="info-value">{wordCount(body)}</span>
			</div>
			<div class="info-row">
				<span class="info-label">Created</span>
				<span class="info-value">{formatDate(note.createdAt)}</span>
			</div>
			<div class="info-row">
				<span class="info-label">Updated</span>
				<span class="info-value">{formatDate(note.updatedAt)}</span>
			</div>
			{#if space}
				<div class="info-row">
					<span class="info-label">Space</span>
					<span class="info-value" style="color: {space.color}">{space.english}</span>
				</div>
			{/if}
		</div>
	{/if}

	<textarea
		bind:value={body}
		class="body-input"
		placeholder="Start editing…"
	></textarea>
</main>

<style>
	.edit-screen {
		position: relative;
		min-height: 100vh;
		width: 100%;
		background: var(--bg) url('/noise.svg') repeat;
		background-size: auto;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 60px 80px;
	}

	.frame {
		position: fixed;
		inset: 0;
		pointer-events: none;
		z-index: 100;
	}

	.corner {
		position: absolute;
		width: 18px;
		height: 18px;
	}

	.corner::before,
	.corner::after {
		content: '';
		position: absolute;
		background: #413f3f;
	}

	.corner::before {
		width: 100%;
		height: 1px;
		top: 0;
		left: 0;
	}

	.corner::after {
		width: 1px;
		height: 100%;
		top: 0;
		left: 0;
	}

	.corner.tl {
		top: 20px;
		left: 20px;
		transform: rotate(-90deg);
	}

	.corner.tr {
		top: 20px;
		right: 20px;
		transform: rotate(90deg);
	}

	.corner.bl {
		bottom: 20px;
		left: 20px;
		transform: rotate(-180deg);
	}

	.corner.br {
		bottom: 20px;
		right: 20px;
		transform: rotate(180deg);
	}

	.nav-home {
		position: absolute;
		left: calc(6.25% - 7px);
		top: calc(6.25% + 1px);
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: #474747;
		text-decoration: none;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.32em;
		line-height: 32px;
		background: transparent;
		border: none;
		cursor: pointer;
	}

	.nav-edit,
	.nav-info {
		position: absolute;
		width: 42px;
		height: 137px;
		border: 2px solid #413f3f;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-decoration: none;
		color: #474747;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		background: transparent;
		cursor: pointer;
	}

	.nav-edit {
		right: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
	}

	.nav-info {
		left: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
	}

	.nav-edit,
	.nav-info {
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.32em;
		line-height: 32px;
	}

	.body-input {
		flex: 1;
		width: 100%;
		max-width: 560px;
		background: transparent;
		border: none;
		border-top: 1px solid var(--border);
		border-bottom: 1px solid var(--border);
		resize: none;
		font-family: 'Kurale', serif;
		font-size: 1.05rem;
		line-height: 1.85;
		color: var(--text);
		padding: 1.5rem 0;
		outline: none;
		min-height: 55vh;
	}

	.body-input::placeholder {
		opacity: 0.22;
		font-style: italic;
	}

	.info-panel {
		width: 100%;
		max-width: 560px;
		border: 1px solid var(--border);
		padding: 1rem 1.25rem;
		margin-bottom: 0.5rem;
		display: flex;
		flex-direction: column;
		gap: 0.6rem;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.info-label {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 0.6rem;
		letter-spacing: 0.25em;
		text-transform: uppercase;
		opacity: 0.4;
	}

	.info-value {
		font-family: 'Kurale', serif;
		font-size: 0.85rem;
	}

	.edit-title {
		font-family: 'Noto Sans JP', sans-serif;
		font-weight: 350;
		font-size: 36px;
		color: #413f3f;
		text-align: center;
		letter-spacing: 0.08em;
		margin: 0;
		margin-bottom: 3rem;
	}

	@media (max-width: 640px) {
		.nav-home { font-size: 16px; }

		.nav-edit,
		.nav-info {
			width: 36px !important;
			height: 120px !important;
			font-size: 16px !important;
		}

		.edit-screen {
			padding: 60px calc(6.25% + 50px);
		}
	}
</style>
