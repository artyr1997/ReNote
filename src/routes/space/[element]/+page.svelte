<script lang="ts">
	import { goto, invalidateAll } from '$app/navigation';
	import type { Note, Space } from '$lib/db';
	import { db } from '$lib/db';

	let { data } = $props();
	let { space, notes } = $derived(data);

	let activeNote: Note | null = $state(null);
	let noteBody = $state('');
	let searchQuery = $state('');
	let saveTimeout: ReturnType<typeof setTimeout> | null = null;
	let showDeleteConfirm = $state(false);
	let showSaved = $state(false);
	let savedTimeout: ReturnType<typeof setTimeout> | null = null;

	$effect(() => {
		if (notes.length > 0 && activeNote === null) {
			activeNote = notes[0];
			noteBody = notes[0].body;
		}
	});

	function selectNote(note: Note) {
		if (saveTimeout) clearTimeout(saveTimeout);
		saveNote();
		activeNote = note;
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

	function truncate(text: string, chars = 40) {
		const normalized = text.replace(/\s+/g, ' ').trim();
		return normalized.length > chars ? normalized.slice(0, chars) + '…' : normalized;
	}

	async function saveNote() {
		if (!activeNote?.id) return;
		await db.notes.update(activeNote.id, {
			title: noteBody.split('\n')[0].trim().slice(0, 60) || 'Untitled',
			body: noteBody,
			updatedAt: Date.now(),
		});
	}

	async function saveNoteWithToast() {
		await saveNote();
		await invalidateAll();
		if (savedTimeout) clearTimeout(savedTimeout);
		showSaved = true;
		savedTimeout = setTimeout(() => { showSaved = false; }, 1500);
	}

	function handleInput() {
		if (saveTimeout) clearTimeout(saveTimeout);
		saveTimeout = setTimeout(saveNote, 800);
	}

	async function deleteNote() {
		if (!activeNote?.id) return;
		if (saveTimeout) clearTimeout(saveTimeout);
		await db.notes.delete(activeNote.id);
		activeNote = null;
		noteBody = '';
		showDeleteConfirm = false;
		await invalidateAll();
	}
</script>

<main class="screen space-screen fade-in">
	<a class="nav-home" href="/home">HOME</a>

	{#if showSaved}
		<div class="saved-toast">
			<span>SAVED</span>
		</div>
	{/if}

	{#if activeNote}
		<button class="nav-corner nav-del" onclick={() => showDeleteConfirm = true}>DEL</button>
		<a class="nav-corner nav-full" href="/note/{activeNote.id}">FULL</a>
	{/if}

	<a class="nav-button nav-new" href="/new?space={space?.element}">
		<p>NEW</p>
	</a>

	<button class="nav-button nav-save" onclick={saveNoteWithToast}>
		<p>SAVE</p>
	</button>

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

	<div class="center-divider" aria-hidden="true"></div>

	{#if space}
		<div class="kanji-block">
			<img
				class="space-kanji-img"
				src="/kanji/{space.element}.png"
				alt={space.kanji}
			/>
			<div class="kanji-divider"></div>
			<p class="kanji-name"><span class="kanji-char">{space.kanji}</span><span class="kanji-slash"> / </span>{space.english.toUpperCase()}</p>
		</div>

		<div class="left-column">
			<div class="search-row">
				<input
					class="search-input"
					type="text"
					placeholder="Search quotes.."
					bind:value={searchQuery}
				/>
			</div>

			<div class="notes-list">
				{#if filteredNotes.length === 0}
					<p class="empty">No quotes yet.</p>
				{:else}
					{#each filteredNotes as note, i (note.id)}
						<button
							class="note-row {activeNote?.id === note.id ? 'active' : ''}"
							onclick={() => selectNote(note)}
						>
							<span
								class="note-icon {activeNote?.id === note.id ? 'filled' : 'outline'}"
								style={activeNote?.id === note.id ? `color: ${space.color}` : ''}
							>
								{activeNote?.id === note.id ? '◆' : '◇'}
							</span>
							<span class="note-title">{truncate(note.body || note.title || 'Untitled', 40)}</span>
						</button>
					{/each}
				{/if}
			</div>
		</div>

		<div class="right-column">
			<div class="quote-card">
				<div class="quote-corner top-left"></div>
				<div class="quote-corner top-right"></div>
				<div class="quote-corner bottom-left"></div>
				<div class="quote-corner bottom-right"></div>

				{#key activeNote?.id}
					<textarea
						class="note-textarea"
						bind:value={noteBody}
						oninput={handleInput}
						placeholder={notes.length === 0 ? '' : ''}
						disabled={notes.length === 0}
					></textarea>
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
		color: #474747;
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
		border: 2px solid #413f3f;
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
		background: #413f3f;
		color: #f5f0e8;
	}

	.nav-new {
		position: absolute;
		left: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
		letter-spacing: 0.64em;
	}

	.nav-save {
		position: absolute;
		right: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
		letter-spacing: 0.64em;
		z-index: 10;
		cursor: pointer;
	}

	.nav-corner {
		position: absolute;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: #474747;
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

	.center-divider {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		width: 2px;
		height: 64px;
		background: #413f3f;
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
		padding-top: calc(320px + 4rem);
	}

	.right-column {
		left: calc(71.875% - 216.5px);
	}

	.kanji-block {
		position: absolute;
		left: calc(28.125% - 181.5px);
		top: 82px;
		width: 398px;
		max-width: 440px;
		height: 320px;
		margin: 0;
	}

	.space-kanji-img {
		position: absolute;
		top: 48px;
		left: 48px;
		width: 124px;
		height: 124px;
		object-fit: contain;
		opacity: 0.8;
	}

	.kanji-divider {
		position: absolute;
		width: 334px;
		height: 2px;
		background: #413f3f;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%) rotate(-45deg);
	}

	.kanji-name {
		position: absolute;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 24px;
		letter-spacing: 7.68px;
		color: #474747;
		white-space: nowrap;
		right: 64px;
		bottom: 64px;
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
		border-bottom: 2px solid #413f3f;
		font-family: 'Kurale', serif;
		font-size: 16px;
		color: #413f3f;
		padding: 0.25rem 0;
		outline: none;
		opacity: 0.8;
	}

	.search-input::placeholder {
		color: #413f3f;
		opacity: 0.4;
	}

	.notes-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		width: 100%;
		max-width: 439px;
		flex: 1;
		overflow-y: auto;
		overflow-x: hidden;
		scrollbar-width: thin;
		scrollbar-color: #413f3f transparent;
	}

	:global(.notes-list::-webkit-scrollbar) { width: 2px; }
	:global(.notes-list::-webkit-scrollbar-track) { background: transparent; }
	:global(.notes-list::-webkit-scrollbar-thumb) { background: #413f3f; }

	.note-row {
		display: flex;
		align-items: center;
		gap: 1rem;
		background: transparent;
		border: none;
		padding: 0;
		color: #413f3f;
		font-family: 'Kurale', serif;
		font-size: 16px;
		line-height: 1.2;
		cursor: pointer;
		text-align: left;
	}

	.note-icon {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		font-size: 2rem;
		width: 2rem;
	}

	.note-icon.filled {
		color: #e6b422;
	}

	.note-icon.outline {
		color: #413f3f;
	}

	.note-title {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		width: calc(100% - 32px);
	}

	.empty {
		font-family: 'Kurale', serif;
		font-size: 16px;
		color: #413f3f;
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

	.quote-corner {
		position: absolute;
		width: 18px;
		height: 18px;
	}

	.quote-corner::before,
	.quote-corner::after {
		content: '';
		position: absolute;
		background: #413f3f;
	}

	.quote-corner::before {
		width: 100%;
		height: 2px;
		top: 0;
		left: 0;
	}

	.quote-corner::after {
		width: 2px;
		height: 100%;
		top: 0;
		left: 0;
	}

	.quote-corner.top-left { top: 0; left: 0; }
	.quote-corner.top-right { top: 0; right: 0; transform: rotate(90deg); }
	.quote-corner.bottom-left { bottom: 0; left: 0; transform: rotate(-90deg); }
	.quote-corner.bottom-right { bottom: 0; right: 0; transform: rotate(180deg); }

	.note-textarea {
		position: absolute;
		top: 24px;
		left: 24px;
		right: 24px;
		bottom: 24px;
		width: calc(100% - 48px);
		height: calc(100% - 48px);
		background: transparent;
		border: none;
		resize: none;
		outline: none;
		font-family: 'Kurale', serif;
		font-size: 16px;
		line-height: 1.8;
		color: #413f3f;
		opacity: 0.8;
		padding: 0;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: #413f3f transparent;
	}

	:global(.note-textarea::-webkit-scrollbar) { width: 2px; }
	:global(.note-textarea::-webkit-scrollbar-track) { background: transparent; }
	:global(.note-textarea::-webkit-scrollbar-thumb) { background: #413f3f; }

	.confirm-overlay {
		position: fixed;
		inset: 0;
		z-index: 20;
	}

	.confirm-box {
		position: fixed;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		background: var(--bg, #f5f0e8);
		border: 2px solid #413f3f;
		padding: 2rem 3rem;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1.5rem;
		z-index: 30;
	}

	.confirm-text {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 16px;
		color: #474747;
		letter-spacing: 0.2em;
		margin: 0;
	}

	.confirm-actions {
		display: flex;
		gap: 2rem;
	}

	.confirm-btn {
		background: transparent;
		border: 2px solid #413f3f;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 16px;
		color: #474747;
		letter-spacing: 0.2em;
		padding: 0.4rem 1.2rem;
		cursor: pointer;
		transition: background 200ms ease, color 200ms ease;
	}

	.confirm-btn:hover { background: #413f3f; color: #f5f0e8; }

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

	.note-textarea::placeholder {
		color: #413f3f;
		opacity: 0.4;
	}

	.note-textarea:disabled {
		cursor: default;
		opacity: 0.3;
	}

	@media (max-width: 640px) {
		.nav-home, .nav-corner { font-size: 16px; }

		.nav-button {
			width: 36px;
			height: 120px;
			font-size: 16px;
		}

		.space-screen {
			display: flex;
			flex-direction: column;
			min-height: 100vh;
			overflow: visible;
			padding: 0 calc(6.25% + 50px) 2rem;
		}

		.center-divider { display: none; }

		.left-column, .right-column {
			position: static;
			width: 100%;
			height: auto;
			gap: 1rem;
		}

		.kanji-block {
			position: static;
			order: -1;
			width: 100%;
			height: auto;
			margin-bottom: 0.5rem;
			padding-top: calc(6.25% + 40px);
			display: flex;
			justify-content: center;
		}

		.right-column { order: 0; margin-top: 1rem; }
		.left-column { order: 1; margin-top: 3rem; padding-top: 0; }
		.space-kanji-img { display: none; }
		.kanji-divider { display: none; }
		.kanji-char, .kanji-slash { display: inline; }
		.kanji-name {
			position: static;
			font-size: 22px;
			letter-spacing: 0.1em;
			text-align: center;
			width: 100%;
		}

		.notes-list { max-height: 30vh; }

		.right-column { padding-bottom: 1.5rem; }
		.quote-card { height: 40vh; min-height: 260px; }

		.saved-toast {
			width: auto;
			min-width: 140px;
			height: 42px;
			border: none;
			padding: 0 1.5rem;
		}
		.saved-toast span {
			writing-mode: horizontal-tb;
			letter-spacing: 0.3em;
		}
	}
</style>
