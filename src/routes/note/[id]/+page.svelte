<script lang="ts">
	import SpaceIcon from '$lib/SpaceIcon.svelte';
	import NoteEditor from '$lib/NoteEditor.svelte';
	import { onDestroy, onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { db, TITLE_MAX } from '$lib/db';
	import type { Space } from '$lib/db';

	let { data } = $props();
	let { note, space, spaces } = $derived(data);

	let title = $state(note?.title ?? '');
	let body = $state(note?.body ?? '');
	let showSaved = $state(false);
	let editor: HTMLDivElement | undefined = $state();

	// full mode opens straight into editing, caret at the end of the text
	onMount(() => {
		requestAnimationFrame(() => {
			if (!editor) return;
			editor.focus();
			const range = document.createRange();
			range.selectNodeContents(editor);
			range.collapse(false);
			const selection = getSelection();
			selection?.removeAllRanges();
			selection?.addRange(range);
		});
	});
	let selectedIdx = $state(spaces.findIndex((s: Space) => s.id === note?.spaceId) ?? 0);

	let selectedSpace: Space = $derived(spaces[selectedIdx] ?? spaces[0]);

	function prev() { selectedIdx = (selectedIdx - 1 + spaces.length) % spaces.length; }
	function next() { selectedIdx = (selectedIdx + 1) % spaces.length; }

	async function persist() {
		if (!note?.id) return;
		await db.notes.update(note.id, {
			title: title.trim().slice(0, TITLE_MAX),
			body: body.trim(),
			spaceId: selectedSpace.id!,
			updatedAt: Date.now(),
		});
	}

	// autosave: any change to title, text or space is written shortly after
	let saveTimer: ReturnType<typeof setTimeout> | null = null;
	let loaded = false;

	$effect(() => {
		title; body; selectedSpace;
		if (!loaded) {
			loaded = true;
			return;
		}
		if (saveTimer) clearTimeout(saveTimer);
		saveTimer = setTimeout(() => {
			saveTimer = null;
			persist();
		}, 600);
	});

	function flushSave() {
		if (!saveTimer) return;
		clearTimeout(saveTimer);
		saveTimer = null;
		persist();
	}

	onDestroy(flushSave);

	async function save() {
		if (saveTimer) clearTimeout(saveTimer);
		saveTimer = null;
		await persist();
		showSaved = true;
		setTimeout(() => goto(`/space/${selectedSpace.element}`), 1000);
	}

	function back() {
		if (space) goto(`/space/${space.element}`);
	}

	function handleKeydown(e: KeyboardEvent) {
		if ((e.metaKey || e.ctrlKey) && e.code === 'KeyS') {
			e.preventDefault();
			save();
		} else if (e.key === 'Escape') {
			back();
		} else if (e.altKey && e.key === 'ArrowLeft') {
			e.preventDefault();
			prev();
		} else if (e.altKey && e.key === 'ArrowRight') {
			e.preventDefault();
			next();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} onpagehide={flushSave} />

{#if showSaved}
	<div class="saved-toast"><span>SAVED</span></div>
{/if}

<!-- BACK left-center -->
<button class="nav-btn nav-back" onclick={back} title="Back (Esc)">
	<p>BACK</p>
</button>

<!-- NEW right-center (changes are autosaved) -->
<a class="nav-btn nav-new" href="/new?space={selectedSpace.element}" title="New note">
	<p>NEW</p>
</a>

<main class="note-screen fade-in">
	<div class="content-block">

		<input
			class="title-input"
			type="text"
			maxlength={TITLE_MAX}
			placeholder="Title"
			bind:value={title}
		/>

		<NoteEditor
			bind:element={editor}
			class="note-body"
			bind:value={body}
			placeholder="Begin writing…"
		/>

		<div class="element-selector">
			<button class="el-nav-btn" onclick={prev} title="Previous space (Option/Alt+←)">←</button>
			<div class="el-center" title="{selectedSpace.kanji} {selectedSpace.english}">
				<SpaceIcon element={selectedSpace.element} size={20} />
			</div>
			<button class="el-nav-btn" onclick={next} title="Next space (Option/Alt+→)">→</button>
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

	.nav-btn {
		position: fixed;
		width: 42px;
		height: 164px;
		border: 2px solid #57585A;
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
		background: #57585A;
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

	.nav-new {
		right: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
	}

	/* Content block */
	.content-block {
		position: absolute;
		/* top aligned with HOME, same margin at the bottom */
		top: calc(6.25% + 1px);
		bottom: calc(6.25% + 1px);
		left: calc(6.25% + 56px);
		right: calc(6.25% + 56px);
	}

	.content-block :global(.note-body) {
		position: absolute;
		top: 56px;
		left: 40px;
		right: 40px;
		bottom: 72px;
		width: calc(100% - 80px);
		height: calc(100% - 128px);
		background: transparent;
		border: none;
		resize: none;
		outline: none;
		font-family: 'Kurale', serif;
		font-size: 18px;
		line-height: 1.85;
		color: #474747;
		/* room for highlight strokes that start/end at the line edge */
		padding: 0 0.5em;
		overflow-y: auto;
	}

	.title-input {
		position: absolute;
		top: 0;
		left: 40px;
		right: 40px;
		width: calc(100% - 80px);
		background: transparent;
		border: none;
		outline: none;
		font-family: 'Kurale', serif;
		font-size: 24px;
		line-height: 32px;
		letter-spacing: 0.05em;
		text-align: center;
		color: #474747;
		padding: 0;
	}

	.title-input::placeholder {
		color: #57585A;
		opacity: 0.25;
		font-style: italic;
	}

	.element-selector {
		position: absolute;
		bottom: 0;
		left: 50%;
		transform: translateX(-50%);
		display: flex;
		align-items: center;
		gap: 0.5rem;
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
		/* fixed width so the arrows don't shift between spaces */
		width: 48px;
	}


	.saved-toast {
		position: fixed;
		top: 0;
		left: 50%;
		transform: translateX(-50%);
		width: 42px;
		height: 200px;
		border: 2px solid #57585A;
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

		.nav-btn {
			width: 36px;
			height: 120px;
			font-size: 16px;
		}

		.saved-toast {
			width: auto;
			min-width: 140px;
			height: 42px;
			border: 2px solid #57585A;
			border-bottom: none;
			padding: 0 1.5rem;
		}

		.saved-toast span {
			writing-mode: horizontal-tb;
			letter-spacing: 0.3em;
		}
	}
</style>
