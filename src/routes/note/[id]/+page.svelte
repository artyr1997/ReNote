<script lang="ts">
	import { goto } from '$app/navigation';
	import { db } from '$lib/db';

	let { data } = $props();
	let { note, space } = $derived(data);

	let body = $state(note?.body ?? '');
	let showSaved = $state(false);

	async function save() {
		if (!note?.id) return;
		await db.notes.update(note.id, {
			title: body.split('\n')[0].trim().slice(0, 60) || 'Untitled',
			body: body.trim(),
			updatedAt: Date.now(),
		});
		showSaved = true;
		setTimeout(() => goto(`/space/${space?.element}`), 1000);
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

<main class="note-screen">
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

		{#if space}
			<div class="space-tag">
				<span class="el-diamond" style="color: {space.color}">◆</span>
				<span class="el-name">{space.kanji} {space.english.toUpperCase()}</span>
			</div>
		{/if}
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
	}

	.nav-btn p {
		margin: 0;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
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
		width: 100%;
		height: 100%;
		background: transparent;
		border: none;
		resize: none;
		outline: none;
		font-family: 'Kurale', serif;
		font-size: 18px;
		line-height: 1.85;
		color: #413f3f;
		padding: 2rem 3rem 4rem;
		box-sizing: border-box;
	}

	.note-body::placeholder {
		color: #413f3f;
		opacity: 0.25;
		font-style: italic;
	}

	/* Space tag bottom-center */
	.space-tag {
		position: absolute;
		bottom: 24px;
		left: 50%;
		transform: translateX(-50%);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.2rem;
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
		height: 164px;
		border: 2px solid #413f3f;
		border-top: none;
		padding-top: 1.5rem;
		padding-bottom: 1.5rem;
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--bg, #f5f0e8);
		z-index: 50;
		animation: toastIn 150ms ease-out both;
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
		from { opacity: 0; transform: translateX(-50%) translateY(-12px); }
		to   { opacity: 1; transform: translateX(-50%) translateY(0); }
	}
</style>
