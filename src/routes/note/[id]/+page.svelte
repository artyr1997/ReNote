<script lang="ts">
	import { goto } from '$app/navigation';
	import { db } from '$lib/db';
	import type { Space } from '$lib/db';

	let { data } = $props();
	let { note, space, spaces } = $derived(data);

	let body = $state(note?.body ?? '');
	let showSaved = $state(false);
	let selectedIdx = $state(spaces.findIndex((s: Space) => s.id === note?.spaceId) ?? 0);

	let selectedSpace: Space = $derived(spaces[selectedIdx] ?? spaces[0]);

	function prev() { selectedIdx = (selectedIdx - 1 + spaces.length) % spaces.length; }
	function next() { selectedIdx = (selectedIdx + 1) % spaces.length; }

	async function save() {
		if (!note?.id) return;
		await db.notes.update(note.id, {
			title: body.split('\n')[0].trim().slice(0, 60) || 'Untitled',
			body: body.trim(),
			spaceId: selectedSpace.id!,
			updatedAt: Date.now(),
		});
		showSaved = true;
		setTimeout(() => goto(`/space/${selectedSpace.element}`), 1000);
	}
</script>

<!-- HOME top-left -->
<a class="nav-home" href="/home">HOME</a>

{#if showSaved}
	<div class="saved-toast"><span>SAVED</span></div>
{/if}

<!-- BACK left-center -->
<button class="nav-btn nav-back" onclick={() => space && goto(`/space/${space.element}`)}>
	<p>BACK</p>
</button>

<!-- SAVE right-center -->
<button class="nav-btn nav-save" onclick={save}>
	<p>SAVE</p>
</button>

<main class="note-screen fade-in">
	<div class="content-block">
		<div class="block-corner tl"></div>
		<div class="block-corner tr"></div>
		<div class="block-corner bl"></div>
		<div class="block-corner br"></div>

		<textarea
			class="note-body"
			bind:value={body}
			placeholder="Begin writing…"
		></textarea>

		<div class="element-selector">
			<button class="el-nav-btn" onclick={prev}>←</button>
			<div class="el-center">
				<span class="el-diamond" style="color: {selectedSpace.color}">◆</span>
				<span class="el-name">{selectedSpace.kanji} {selectedSpace.english.toUpperCase()}</span>
			</div>
			<button class="el-nav-btn" onclick={next}>→</button>
		</div>
	</div>
</main>

<style>
	.note-screen {
		position: relative;
		min-height: 100vh;
		width: 100%;
		max-width: 1280px;
		margin: 0 auto;
		background: transparent;
		overflow: hidden;
	}

	/* Navigation */
	.nav-home {
		position: fixed;
		left: calc(6.25% - 7px);
		top: calc(6.25% + 1px);
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: #474747;
		text-decoration: none;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
		z-index: 10;
	}

	.nav-btn {
		position: fixed;
		width: 42px;
		height: 164px;
		border: 2px solid #413f3f;
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		color: #474747;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		cursor: pointer;
		text-decoration: none;
		z-index: 10;
		transition: background 200ms ease, color 200ms ease;
	}

	.nav-btn:hover {
		background: #413f3f;
		color: #f5f0e8;
	}

	.nav-btn p {
		margin: 0;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
		padding-top: 0.64em;
	}

	.nav-back {
		left: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
	}

	.nav-save {
		right: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
	}

	/* Content block */
	.content-block {
		position: absolute;
		top: calc(6.25% + 2px);
		bottom: calc(6.25% + 2px);
		left: calc(6.25% + 56px);
		right: calc(6.25% + 56px);
	}

	.block-corner {
		position: absolute;
		width: 18px;
		height: 18px;
	}

	.block-corner::before,
	.block-corner::after {
		content: '';
		position: absolute;
		background: #413f3f;
	}

	.block-corner::before {
		width: 100%;
		height: 2px;
		top: 0;
		left: 0;
	}

	.block-corner::after {
		width: 2px;
		height: 100%;
		top: 0;
		left: 0;
	}

	.block-corner.tl { top: 0; left: 0; }
	.block-corner.tr { top: 0; right: 0; transform: rotate(90deg); }
	.block-corner.bl { bottom: 0; left: 0; transform: rotate(-90deg); }
	.block-corner.br { bottom: 0; right: 0; transform: rotate(180deg); }

	.note-body {
		position: absolute;
		top: 40px;
		left: 40px;
		right: 40px;
		bottom: 80px;
		width: calc(100% - 48px);
		height: calc(100% - 104px);
		background: transparent;
		border: none;
		resize: none;
		outline: none;
		font-family: 'Kurale', serif;
		font-size: 18px;
		line-height: 1.85;
		color: #413f3f;
		padding: 0;
		overflow-y: auto;
	}

	.note-body::placeholder {
		color: #413f3f;
		opacity: 0.25;
		font-style: italic;
	}

	.element-selector {
		position: absolute;
		bottom: 24px;
		left: 50%;
		transform: translateX(-50%);
		display: flex;
		align-items: center;
		gap: 2rem;
	}

	.el-nav-btn {
		background: transparent;
		border: none;
		cursor: pointer;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 2rem;
		color: #474747;
		padding: 0.5rem;
		line-height: 1;
	}

	.el-center {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.2rem;
		min-width: 60px;
	}

	.el-diamond {
		font-size: 1rem;
	}

	.el-name {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 1rem;
		letter-spacing: 0.2em;
		white-space: nowrap;
		color: #474747;
	}

	.saved-toast {
		position: fixed;
		top: 0;
		left: 50%;
		transform: translateX(-50%);
		width: 42px;
		height: 200px;
		border: 2px solid #413f3f;
		border-top: none;
		padding-top: 1.5rem;
		padding-bottom: 1.5rem;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 50;
		animation: toastIn 300ms cubic-bezier(0.22, 1, 0.36, 1) both;
	}

	.saved-toast span {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: #474747;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
	}

	@keyframes toastIn {
		from { opacity: 0; transform: translateX(-50%) translateY(-100%); }
		to   { opacity: 1; transform: translateX(-50%) translateY(0); }
	}

	@media (max-width: 640px) {
		.note-screen { overflow: visible; }

		.nav-home { font-size: 16px; }

		.nav-btn {
			width: 36px;
			height: 120px;
			font-size: 16px;
		}

		.saved-toast {
			width: auto;
			min-width: 140px;
			height: 42px;
			border: 2px solid #413f3f;
			border-bottom: none;
			padding: 0 1.5rem;
		}

		.saved-toast span {
			writing-mode: horizontal-tb;
			letter-spacing: 0.3em;
		}
	}
</style>
