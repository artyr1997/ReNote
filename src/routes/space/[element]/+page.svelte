<script lang="ts">
	import { onDestroy, tick } from 'svelte';
	import { goto, invalidateAll } from '$app/navigation';
	import type { Note, Space } from '$lib/db';
	import { SPACES, TITLE_MAX } from '$lib/db';
	import { store } from '$lib/store';
	import SpaceIcon from '$lib/SpaceIcon.svelte';
	import NoteEditor from '$lib/NoteEditor.svelte';
	import { scrollFade } from '$lib/scrollFade';

	let { data } = $props();
	let { space, notes, selectedId } = $derived(data);

	let activeNote: Note | null = $state(null);
	let noteBody = $state('');
	let noteTitle = $state('');
	let searchQuery = $state('');
	let saveTimeout: ReturnType<typeof setTimeout> | null = null;
	let showDeleteConfirm = $state(false);
	let showSaved = $state(false);
	let savedTimeout: ReturnType<typeof setTimeout> | null = null;
	let searchInput: HTMLInputElement | undefined = $state();
	let noteTextarea: HTMLDivElement | undefined = $state();
	let notesList: HTMLDivElement | undefined = $state();

	$effect(() => {
		if (notes.length > 0 && activeNote === null) {
			const initial = notes.find(n => n.id === selectedId) ?? notes[0];
			activeNote = initial;
			noteTitle = initial.title;
			noteBody = initial.body;
		}
	});

	function selectNote(note: Note) {
		if (saveTimeout) clearTimeout(saveTimeout);
		saveNote();
		activeNote = note;
		noteTitle = note.title;
		noteBody = note.body;
	}

	let filteredNotes = $derived(
		searchQuery.trim()
			? notes.filter(n =>
				n.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
				n.body.toLowerCase().includes(searchQuery.toLowerCase())
			)
			: notes
	);

	async function saveNote() {
		if (!activeNote?.id) return;
		const id = activeNote.id;
		const changes = {
			title: noteTitle.trim().slice(0, TITLE_MAX),
			body: noteBody,
			updatedAt: Date.now(),
		};
		// keep the loaded list in sync so switching back shows the saved text
		const loaded = notes.find(n => n.id === id);
		if (loaded) Object.assign(loaded, changes);
		await store.updateNote(id, changes);
	}

	// autosave: never lose a pending change when leaving the page or closing the tab
	function flushSave() {
		if (!saveTimeout) return;
		clearTimeout(saveTimeout);
		saveTimeout = null;
		saveNote();
	}

	onDestroy(flushSave);

	async function saveNoteWithToast() {
		await saveNote();
		await invalidateAll();
		if (savedTimeout) clearTimeout(savedTimeout);
		showSaved = true;
		savedTimeout = setTimeout(() => { showSaved = false; }, 1500);
	}

	function handleInput() {
		if (saveTimeout) clearTimeout(saveTimeout);
		saveTimeout = setTimeout(() => {
			saveTimeout = null;
			saveNote();
		}, 800);
	}

	async function deleteNote() {
		if (!activeNote?.id) return;
		if (saveTimeout) clearTimeout(saveTimeout);
		await store.deleteNote(activeNote.id);
		activeNote = null;
		noteTitle = '';
		noteBody = '';
		showDeleteConfirm = false;
		await invalidateAll();
	}

	function selectRelative(delta: number) {
		if (filteredNotes.length === 0) return;
		const idx = filteredNotes.findIndex(n => n.id === activeNote?.id);
		// selected note not in the (filtered) list → start from its first/last row
		const nextIdx = idx < 0
			? (delta > 0 ? 0 : filteredNotes.length - 1)
			: (idx + delta + filteredNotes.length) % filteredNotes.length;
		selectNote(filteredNotes[nextIdx]);
		// keep the keyboard-selected note in view
		tick().then(() => {
			notesList?.querySelector('.note-row.active')?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
		});
	}

	function switchSpace(delta: number) {
		if (!space) return;
		const idx = SPACES.findIndex(s => s.element === space.element);
		const nextIdx = ((idx < 0 ? 0 : idx) + delta + SPACES.length) % SPACES.length;
		goto(`/space/${SPACES[nextIdx].element}`);
	}

	// focus the note text with the caret at the end
	function editActiveNote() {
		if (!noteTextarea) return;
		noteTextarea.focus();
		const range = document.createRange();
		range.selectNodeContents(noteTextarea);
		range.collapse(false);
		const selection = getSelection();
		selection?.removeAllRanges();
		selection?.addRange(range);
	}

	function isTypingTarget(e: KeyboardEvent): boolean {
		const tag = (e.target as HTMLElement)?.tagName;
		return tag === 'INPUT' || tag === 'TEXTAREA' || !!(e.target as HTMLElement)?.isContentEditable;
	}

	function handleKeydown(e: KeyboardEvent) {
		// delete popup is modal: Enter confirms, Esc closes, nothing else reacts
		if (showDeleteConfirm) {
			if (e.key === 'Enter') {
				e.preventDefault();
				deleteNote();
			} else if (e.key === 'Escape') {
				showDeleteConfirm = false;
			}
			return;
		}
		if ((e.metaKey || e.ctrlKey) && e.code === 'KeyS') {
			e.preventDefault();
			saveNoteWithToast();
			return;
		}
		if (e.key === 'Escape') {
			goto('/home');
			return;
		}
		if ((e.metaKey || e.ctrlKey) && e.code === 'KeyF') {
			e.preventDefault();
			if (document.activeElement === noteTextarea && activeNote) {
				goto(`/note/${activeNote.id}`);
			} else {
				searchInput?.focus();
			}
			return;
		}
		// in the search field: arrows move through the results, Enter edits the selected one
		if (e.target === searchInput) {
			if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
				e.preventDefault();
				selectRelative(e.key === 'ArrowDown' ? 1 : -1);
			} else if (e.key === 'Enter' && activeNote) {
				e.preventDefault();
				editActiveNote();
			}
			return;
		}
		if (isTypingTarget(e)) return;
		if (e.code === 'KeyN') {
			goto(`/new?space=${space?.element}`);
		} else if ((e.code === 'KeyE' || e.key === 'Enter') && activeNote) {
			e.preventDefault();
			editActiveNote();
		} else if (e.code === 'Slash') {
			e.preventDefault();
			searchInput?.focus();
		} else if (e.key === 'ArrowDown') {
			e.preventDefault();
			selectRelative(1);
		} else if (e.key === 'ArrowUp') {
			e.preventDefault();
			selectRelative(-1);
		} else if (e.key === 'ArrowLeft') {
			e.preventDefault();
			switchSpace(-1);
		} else if (e.key === 'ArrowRight') {
			e.preventDefault();
			switchSpace(1);
		} else if ((e.key === 'Backspace' || e.key === 'Delete') && activeNote) {
			showDeleteConfirm = true;
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} onpagehide={flushSave} />

<!-- outside <main> so the backdrop blur covers the whole page, like INFO -->
{#if showDeleteConfirm}
	<div class="confirm-overlay" onclick={() => showDeleteConfirm = false} aria-hidden="true"></div>
	<div class="confirm-box">
		<p class="confirm-text">Delete this note?</p>
		<div class="confirm-actions">
			<button class="confirm-btn confirm-yes" onclick={deleteNote}>YES</button>
			<button class="confirm-btn confirm-no" onclick={() => showDeleteConfirm = false}>NO</button>
		</div>
	</div>
{/if}

<main class="screen space-screen fade-in">
	<a class="nav-home wide-only" href="/home">HOME</a>

	<!-- a small window: the list and the note side by side, HOME and NEW in the corners -->
	<a class="compact-btn top-right" href="/home" title="Home (Esc)">HOME</a>
	<a class="compact-btn bottom-right" href="/new?space={space?.element}" title="New note (N)">NEW</a>
	{#if space}
		<p class="compact-title">{space.kanji} / {space.english.toUpperCase()}</p>
	{/if}

	{#if showSaved}
		<div class="saved-toast">
			<span>SAVED</span>
		</div>
	{/if}

	{#if activeNote}
		<button class="nav-corner nav-del wide-only" onclick={() => showDeleteConfirm = true} title="Delete (Backspace)">DEL</button>
		<a class="nav-corner nav-full wide-only" href="/note/{activeNote.id}">FULL</a>
	{/if}

	<!-- NEXT left-center: go to the next space -->
	<button class="nav-button nav-next wide-only" onclick={() => switchSpace(1)} title="Next space (→)">
		<p>NEXT</p>
	</button>

	<!-- NEW right-center (notes are autosaved, so no SAVE button) -->
	<a class="nav-button nav-new wide-only" href="/new?space={space?.element}" title="New note (N)">
		<p>NEW</p>
	</a>

	{#if space}
		<div class="kanji-block">
			<div class="kanji-shape {space.element}">
				<SpaceIcon element={space.element} size={300} strokeWidth={2} />
				<div class="kanji-inner">
					<img
						class="space-kanji-img"
						src="/kanji/{space.element}.png"
						alt={space.kanji}
					/>
					<p class="kanji-name"><span class="kanji-char">{space.kanji}</span><span class="kanji-slash"> / </span>{space.english.toUpperCase()}</p>
				</div>
			</div>
		</div>

		<div class="left-column">
			<div class="search-row">
				<input
					bind:this={searchInput}
					class="search-input"
					type="text"
					placeholder="Search"
					title="Search (/)"
					bind:value={searchQuery}
				/>
			</div>

			<div class="notes-list" bind:this={notesList} use:scrollFade>
				{#if filteredNotes.length === 0}
					<p class="empty">No notes yet.</p>
				{:else}
					{#each filteredNotes as note, i (note.id)}
						<button
							class="note-row {activeNote?.id === note.id ? 'active' : ''}"
							onclick={() => selectNote(note)}
						>
							<span class="note-title" class:ink-mark={activeNote?.id === note.id}>{(activeNote?.id === note.id ? noteTitle : note.title) || 'Untitled'}</span>
						</button>
					{/each}
				{/if}
			</div>
		</div>

		<div class="right-column">
			<div class="quote-card">

				{#key activeNote?.id}
					<input
						class="title-input"
						type="text"
						maxlength={TITLE_MAX}
						placeholder="Title"
						bind:value={noteTitle}
						oninput={handleInput}
						disabled={notes.length === 0}
					/>
					<NoteEditor
						bind:element={noteTextarea}
						class="note-textarea"
						bind:value={noteBody}
						oninput={handleInput}
						disabled={notes.length === 0}
					/>
				{/key}

			</div>
		</div>
	{/if}
</main>

<style>
	.space-screen {
		position: relative;
		min-height: 100vh;
		width: 100%;
		background: transparent;
		overflow: hidden;
	}

	.nav-home,
	.nav-button {
		position: absolute;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: var(--text);
		text-decoration: none;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
	}

	.nav-home {
		position: absolute;
		left: calc(6.25% - 7px);
		top: calc(6.25% + 1px);
		line-height: 32px;
	}

	.nav-button {
		width: 42px;
		height: 164px;
		border: 2px solid var(--line);
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 0;
		background: transparent;
		cursor: pointer;
		z-index: 10;
		transition: background 200ms ease, color 200ms ease;
	}

	.nav-button:hover {
		background: var(--line);
		color: var(--bg);
	}

	.nav-next {
		position: absolute;
		left: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
		letter-spacing: 0.64em;
	}

	.nav-new {
		position: absolute;
		right: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
		letter-spacing: 0.64em;
	}

	.nav-corner {
		position: absolute;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: var(--text);
		text-decoration: none;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
		background: transparent;
		border: none;
		cursor: pointer;
		z-index: 10;
	}

	.nav-del {
		right: calc(6.25% - 7px);
		top: calc(6.25% + 1px);
	}

	.nav-full {
		right: calc(6.25% - 7px);
		bottom: calc(6.25% + 1px);
	}

	.nav-button p {
		margin: 0;
		writing-mode: vertical-rl;
		text-orientation: upright;
		line-height: 32px;
		padding-top: 0.64em;
	}

	.left-column,
	.right-column {
		position: absolute;
		top: 82px;
		width: 398px;
		height: 894px;
		display: flex;
		flex-direction: column;
		justify-content: flex-start;
		align-items: flex-start;
		gap: 2rem;
	}

	.left-column {
		left: calc(28.125% - 181.5px);
		/* starts right under the element shape (tallest one is ~264px), ends at FULL level */
		top: calc(6.25% + 1px);
		bottom: calc(6.25% + 1px);
		height: auto;
		padding-top: calc(264px + 1.5rem);
	}

	.right-column {
		/* from page center to the old right edge; top aligned with DEL, bottom with FULL */
		left: 50%;
		width: calc(21.875% + 181.5px);
		top: calc(6.25% + 1px);
		bottom: calc(6.25% + 1px);
		height: auto;
	}

	.kanji-block {
		position: absolute;
		left: calc(28.125% - 181.5px);
		top: calc(6.25% + 1px);
		width: 398px;
		max-width: 440px;
		height: 320px;
		margin: 0;
		display: flex;
		align-items: flex-start;
		justify-content: center;
	}

	/* Element outline with the kanji and name inside */
	.kanji-shape {
		position: relative;
		width: 300px;
		height: 300px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.kanji-shape :global(.space-icon) {
		position: absolute;
		inset: 0;
	}

	/* Pull each shape up so its top edge (not the SVG box) lines up with HOME / DEL.
	   Offsets = shape's top inset in the 16-unit viewBox × 300px, plus half the stroke. */
	.kanji-shape.water { margin-top: calc(-300px * 1 / 16 + 1px); }
	.kanji-shape.earth { margin-top: calc(-300px * 2 / 16 + 1px); }
	.kanji-shape.fire  { margin-top: calc(-300px * 1.67 / 16 + 1px); }
	.kanji-shape.air   { margin-top: calc(-300px * 1.75 / 16 + 1px); }

	.kanji-inner {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
	}

	.space-kanji-img {
		width: 96px;
		height: 96px;
		object-fit: contain;
		opacity: 0.8;
	}

	.kanji-name {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		letter-spacing: 0.32em;
		margin-right: -0.32em;
		color: var(--text);
		white-space: nowrap;
	}

	.kanji-char, .kanji-slash { display: none; }

	.search-row {
		width: 100%;
		max-width: 439px;
	}

	.search-input {
		width: 100%;
		background: transparent;
		border: none;
		font-family: 'Kurale', serif;
		font-size: 24px;
		line-height: 32px;
		text-align: center;
		color: var(--line);
		padding: 0;
		outline: none;
		opacity: 0.8;
	}

	.search-input::placeholder {
		color: var(--line);
		opacity: 0.4;
	}

	.notes-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		/* shifted right under "Search"; rows stay left-aligned.
		   Side padding leaves room for the ink stroke of the selected note,
		   which the scrolling list would otherwise clip. */
		width: calc(100% - 120px + 0.5em);
		margin-left: calc(120px - 0.5em);
		padding: 0.3em 0.5em;
		flex: 1;
		overflow-y: auto;
		overflow-x: hidden;
	}

	.note-row {
		/* scrolled-to rows stop clear of the faded edges */
		scroll-margin: 56px 0;
		display: flex;
		align-items: center;
		gap: 1rem;
		background: transparent;
		border: none;
		padding: 0;
		color: var(--line);
		font-family: 'Kurale', serif;
		font-size: 16px;
		line-height: 1.2;
		cursor: pointer;
		text-align: left;
	}

	.note-title {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		min-width: 0;
	}

	.empty {
		font-family: 'Kurale', serif;
		font-size: 16px;
		color: var(--line);
		opacity: 0.4;
	}

	.quote-card {
		position: relative;
		width: 100%;
		height: 100%;
		margin: 0;
		padding: 0;
		background: transparent;
		border: none;
	}

	.quote-card :global(.note-textarea) {
		position: absolute;
		top: 56px;
		left: 24px;
		right: 24px;
		bottom: 0;
		width: calc(100% - 48px);
		height: calc(100% - 56px);
		background: transparent;
		border: none;
		resize: none;
		outline: none;
		font-family: 'Kurale', serif;
		font-size: 16px;
		line-height: 1.8;
		color: var(--text);
		/* room for highlight strokes that start/end at the line edge */
		padding: 0 0.5em;
		overflow-y: auto;
	}

	.title-input {
		position: absolute;
		top: 0;
		left: 24px;
		right: 24px;
		width: calc(100% - 48px);
		background: transparent;
		border: none;
		outline: none;
		font-family: 'Kurale', serif;
		font-size: 24px;
		line-height: 32px;
		letter-spacing: 0.05em;
		text-align: center;
		color: var(--text);
		padding: 0;
	}

	.title-input::placeholder {
		color: var(--line);
		opacity: 0.25;
		font-style: italic;
	}

	/* same look as the INFO popup: blurred page behind, paper box */
	.confirm-overlay {
		position: fixed;
		inset: 0;
		z-index: 60;
		backdrop-filter: blur(6px);
		-webkit-backdrop-filter: blur(6px);
	}

	.confirm-box {
		position: fixed;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		background: var(--bg) url('/noise.svg') repeat;
		border: 2px solid var(--line);
		padding: 2.5rem 3rem;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1.5rem;
		z-index: 70;
	}

	.confirm-text {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 16px;
		color: var(--text);
		letter-spacing: 0.2em;
		margin: 0;
	}

	.confirm-actions {
		display: flex;
		gap: 2rem;
	}

	.confirm-btn {
		background: transparent;
		border: 2px solid var(--line);
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 16px;
		color: var(--text);
		letter-spacing: 0.2em;
		padding: 0.4rem 1.2rem;
		cursor: pointer;
		transition: background 200ms ease, color 200ms ease;
	}

	.confirm-btn:hover { background: var(--line); color: var(--bg); }

	.saved-toast {
		position: fixed;
		top: 0;
		left: 50%;
		transform: translateX(-50%);
		width: 42px;
		height: 200px;
		border: 2px solid var(--line);
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
		color: var(--text);
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
	}

	@keyframes toastIn {
		from { opacity: 0; transform: translateX(-50%) translateY(-100%); }
		to   { opacity: 1; transform: translateX(-50%) translateY(0); }
	}

	/* ── a small desktop window: no element shape, the list and the note side by side ── */
	.compact-title { display: none; }

	@media (max-width: 759px), (max-height: 559px) {
		:global(html.desktop) .compact-title {
			display: block;
			position: absolute;
			top: 16px;
			left: 50%;
			transform: translateX(-50%);
			font-family: 'Noto Sans JP', sans-serif;
			font-size: 12px;
			letter-spacing: 0.3em;
			color: var(--text);
			opacity: 0.6;
			white-space: nowrap;
		}

		:global(html.desktop) .kanji-block { display: none; }

		:global(html.desktop) .left-column {
			top: 48px;
			bottom: 44px;
			left: 36px;
			width: 34%;
			padding-top: 0;
			gap: 1rem;
		}

		:global(html.desktop) .right-column {
			top: 48px;
			bottom: 44px;
			left: calc(36px + 34% + 12px);
			right: 24px;
			width: auto;
		}

		/* the search lines up with the titles under it */
		:global(html.desktop) .search-input {
			padding: 0 0.5em;
			font-size: 18px;
			text-align: left;
		}

		:global(html.desktop) .notes-list {
			width: 100%;
			margin-left: 0;
		}

		:global(html.desktop) .title-input {
			font-size: 18px;
			line-height: 24px;
		}

		:global(html.desktop) .quote-card :global(.note-textarea) {
			top: 40px;
			height: calc(100% - 40px);
		}
	}

	@media (max-width: 640px) {
		:global(html:not(.desktop)) .nav-home, :global(html:not(.desktop)) .nav-corner { font-size: 16px; }

		:global(html:not(.desktop)) .nav-button {
			width: 36px;
			height: 120px;
			font-size: 16px;
		}

		:global(html:not(.desktop)) .space-screen {
			display: flex;
			flex-direction: column;
			min-height: 100vh;
			overflow: visible;
			padding: 0 calc(6.25% + 50px) 2rem;
		}

		:global(html:not(.desktop)) .left-column, :global(html:not(.desktop)) .right-column {
			position: static;
			width: 100%;
			height: auto;
			gap: 1rem;
		}

		:global(html:not(.desktop)) .kanji-block {
			position: static;
			order: -1;
			width: 100%;
			height: auto;
			margin-bottom: 0.5rem;
			padding-top: calc(6.25% + 40px);
			display: flex;
			justify-content: center;
		}

		:global(html:not(.desktop)) .right-column { order: 0; margin-top: 1rem; }
		:global(html:not(.desktop)) .left-column { order: 1; margin-top: 3rem; padding-top: 0; }
		:global(html:not(.desktop)) .space-kanji-img { display: none; }
		:global(html:not(.desktop)) .kanji-shape { width: auto; height: auto; margin-top: 0 !important; }
		:global(html:not(.desktop)) .kanji-shape :global(.space-icon) { display: none; }
		:global(html:not(.desktop)) .kanji-char, :global(html:not(.desktop)) .kanji-slash { display: inline; }
		:global(html:not(.desktop)) .kanji-name {
			position: static;
			font-size: 22px;
			letter-spacing: 0.1em;
			text-align: center;
			width: 100%;
		}

		:global(html:not(.desktop)) .notes-list { max-height: 30vh; width: 100%; margin-left: 0; }

		:global(html:not(.desktop)) .right-column { padding-bottom: 1.5rem; }
		:global(html:not(.desktop)) .quote-card { height: 40vh; min-height: 260px; }

		:global(html:not(.desktop)) .saved-toast {
			width: auto;
			min-width: 140px;
			height: 42px;
			border: none;
			padding: 0 1.5rem;
		}
		:global(html:not(.desktop)) .saved-toast span {
			writing-mode: horizontal-tb;
			letter-spacing: 0.3em;
		}
	}
</style>
