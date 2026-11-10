<script lang="ts">
	import { goto, invalidateAll } from '$app/navigation';
	import type { Note, Space } from '$lib/db';
	import { SPACES } from '$lib/db';
	import { store, getNoteStats, isDesktop } from '$lib/store';
	import SpaceIcon from '$lib/SpaceIcon.svelte';

	let { data } = $props();
	let { spaces, noteCounts, notes } = $derived(data);

	let searchQuery = $state('');
	let searchInput: HTMLInputElement | undefined = $state();

	let searchResults = $derived.by(() => {
		const q = searchQuery.trim().toLowerCase();
		if (!q) return [];
		return notes
			.filter(n => n.title.toLowerCase().includes(q) || n.body.toLowerCase().includes(q))
			.slice(0, 8)
			.map(n => ({ note: n, space: spaces.find(s => s.id === n.spaceId) }));
	});

	let selectedResult = $state(0);

	// new query → highlight the first result again
	$effect(() => {
		searchQuery;
		selectedResult = 0;
	});

	function openNote(note: Note, space: Space | undefined) {
		if (!space) return;
		goto(`/space/${space.element}?note=${note.id}`);
	}

	function handleSearchKeydown(e: KeyboardEvent) {
		const count = searchResults.length;
		if (e.key === 'ArrowDown' && count > 0) {
			e.preventDefault();
			selectedResult = (selectedResult + 1) % count;
		} else if (e.key === 'ArrowUp' && count > 0) {
			e.preventDefault();
			selectedResult = (selectedResult - 1 + count) % count;
		} else if (e.key === 'Enter' && count > 0) {
			const { note, space } = searchResults[selectedResult];
			openNote(note, space);
		} else if (e.key === 'Escape') {
			searchQuery = '';
			searchInput?.blur();
		}
	}

	let showExportConfirm = $state(false);
	let exportNoteCount = $state(0);
	let exportSpaceCounts: Record<string, number> = $state({});

	async function openExportConfirm() {
		const stats = await getNoteStats();
		exportNoteCount = stats.total;
		exportSpaceCounts = stats.bySpace;
		showExportConfirm = true;
	}

	async function exportNotes() {
		const [notes, spacesData] = await Promise.all([store.getNotes(), store.getSpaces()]);

		const exportData = {
			version: 1,
			exportedAt: Date.now(),
			notes: notes.map(note => {
				const space = spacesData.find(s => s.id === note.spaceId);
				return {
					spaceElement: space?.element ?? 'water',
					title: note.title,
					body: note.body,
					createdAt: note.createdAt,
					updatedAt: note.updatedAt,
				};
			}),
		};

		const fileName = `renote-backup-${new Date().toISOString().slice(0, 10)}.json`;
		const saved = await store.saveExport(JSON.stringify(exportData, null, 2), fileName);
		if (saved) showExportConfirm = false;
	}

	let fileInput: HTMLInputElement;

	const spaceShortcuts: Record<string, string> = {
		KeyF: 'water', // Feel
		KeyB: 'earth', // Body
		KeyM: 'fire', // Mind
		KeyS: 'air', // Soul
	};

	const shortcutKeys: Record<string, string> = {
		water: 'F',
		earth: 'B',
		fire: 'M',
		air: 'S',
	};

	function handleKeydown(e: KeyboardEvent) {
		// export popup is modal: Enter exports, Esc closes, nothing else reacts
		if (showExportConfirm) {
			if (e.key === 'Enter') {
				e.preventDefault();
				exportNotes();
			} else if (e.key === 'Escape') {
				showExportConfirm = false;
			}
			return;
		}
		// typing in the search field must not trigger space shortcuts
		if ((e.target as HTMLElement)?.tagName === 'INPUT') return;
		if (e.code === 'Slash') {
			e.preventDefault();
			searchInput?.focus();
			return;
		}
		const element = spaceShortcuts[e.code];
		if (element) {
			goto(`/space/${element}`);
		}
	}

	async function importNotes(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;

		try {
			const text = await file.text();
			const parsed = JSON.parse(text);
			if (!parsed.notes || !Array.isArray(parsed.notes)) return;

			const spacesData = await store.getSpaces();

			const notesToAdd = parsed.notes.map((n: any) => {
				const space = spacesData.find(s => s.element === n.spaceElement) ?? spacesData[0];
				return {
					spaceId: space.id!,
					title: n.title ?? 'Untitled',
					body: n.body ?? '',
					createdAt: n.createdAt ?? Date.now(),
					updatedAt: n.updatedAt ?? Date.now(),
				};
			});

			await store.addNotes(notesToAdd);
			await invalidateAll();
		} finally {
			fileInput.value = '';
		}
	}

	const positions = [
		{
			bottomBox: { left: 'calc(18.75% + 2px)', top: 'calc(50% + 15px)', width: '98px', height: '151px' },
			label: { left: 'calc(21.88% + 6px)', top: 'calc(50% + 26px)', text: 'FEEL' },
			topBox: { left: 'calc(18.75% + 2px)', top: 'calc(18.75% + 29px)', width: '98px', height: '82px' },
			diamond: { left: 'calc(18.75% + 40px)', top: 'calc(25% - 5px)', color: '#3fb5d3' },
			image: { left: 'calc(18.75% - 61px)', top: 'calc(25% + 47px)', size: '224px' }
		},
		{
			bottomBox: { left: 'calc(37.5% + 2px)', top: 'calc(62.5% + 14px)', width: '98px', height: '151px' },
			label: { left: 'calc(40.63% + 6px)', top: 'calc(62.5% + 25px)', text: 'BODY' },
			topBox: { left: 'calc(37.5% + 2px)', top: 'calc(31.25% + 28px)', width: '98px', height: '82px' },
			diamond: { left: 'calc(37.5% + 40px)', top: 'calc(37.5% - 6px)', color: '#e6b422' },
			image: { left: 'calc(37.5% - 61px)', top: 'calc(37.5% + 46px)', size: '224px' }
		},
		{
			bottomBox: { left: 'calc(56.25% + 2px)', top: 'calc(50% + 15px)', width: '98px', height: '151px' },
			label: { left: 'calc(59.38% + 6px)', top: 'calc(50% + 26px)', text: 'MIND' },
			topBox: { left: 'calc(56.25% + 2px)', top: 'calc(18.75% + 29px)', width: '98px', height: '82px' },
			diamond: { left: 'calc(56.25% + 40px)', top: 'calc(25% - 5px)', color: '#ea5550' },
			image: { left: 'calc(56.25% - 61px)', top: 'calc(25% + 47px)', size: '224px' }
		},
		{
			bottomBox: { left: 'calc(68.75% + 79px)', top: 'calc(62.5% + 6px)', width: '98px', height: '151px' },
			label: { left: 'calc(78.13% - 7px)', top: 'calc(62.5% + 6px)', text: 'SOUL' },
			topBox: { left: 'calc(68.75% + 79px)', top: 'calc(31.25% + 20px)', width: '98px', height: '82px' },
			diamond: { left: 'calc(75% + 27px)', top: 'calc(31.25% + 50px)', color: '#00cfb0' },
			image: { left: 'calc(68.75% + 16px)', top: 'calc(37.5% + 38px)', size: '224px' }
		}
	];
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- SEARCH: outside <main> so its backdrop blur covers the whole page (main's fade-in animation would clip it) -->
{#if searchQuery.trim()}
	<div class="home-search-overlay" onclick={() => searchQuery = ''} aria-hidden="true"></div>
{/if}
<div class="home-search">
	<input
		bind:this={searchInput}
		bind:value={searchQuery}
		onkeydown={handleSearchKeydown}
		class="home-search-input"
		type="text"
		placeholder="Search"
		title="Search all notes (/)"
	/>
	{#if searchQuery.trim()}
		<div class="home-search-results">
			{#if searchResults.length === 0}
				<p class="home-search-empty">Nothing found.</p>
			{:else}
				{#each searchResults as { note, space }, i (note.id)}
					<button
						class="home-search-row"
						class:active={i === selectedResult}
						onclick={() => openNote(note, space)}
						onmouseenter={() => selectedResult = i}
					>
						{#if space}
							<SpaceIcon element={space.element} filled={i === selectedResult} size={14} />
						{/if}
						<span class="home-search-title">{note.title || 'Untitled'}</span>
					</button>
				{/each}
			{/if}
		</div>
	{/if}
</div>

<!-- outside <main> so the backdrop blur covers the whole page, like INFO -->
{#if showExportConfirm}
	<div class="exp-overlay" onclick={() => showExportConfirm = false} aria-hidden="true"></div>
	<div class="exp-box">
		<p class="exp-heading">EXPORT</p>
		<div class="exp-divider"></div>
		<div class="exp-stats">
			<p class="exp-total">{exportNoteCount} {exportNoteCount === 1 ? 'note' : 'notes'}</p>
			<div class="exp-spaces">
				{#each SPACES as s}
					<div class="exp-space-row">
						<SpaceIcon element={s.element} size={12} />
						<span class="exp-space-name">{s.english.toUpperCase()}</span>
						<span class="exp-space-count">{exportSpaceCounts[s.english] ?? 0}</span>
					</div>
				{/each}
			</div>
		</div>
		<div class="exp-divider"></div>
		<button class="exp-confirm-btn" onclick={exportNotes}>EXPORT</button>
	</div>
{/if}

<main class="home fade-in">
	<!-- Background -->
	<div class="background" aria-hidden="true"></div>

	<!-- top left: NEW note on desktop; EXIT back to the landing on the web (the desktop app has no landing) -->
	{#if isDesktop}
		<a href="/new" class="exit wide-only" title="New note">NEW</a>
	{:else}
		<a href="/" class="exit wide-only">EXIT</a>
	{/if}

	<!-- IMP -->
	<input bind:this={fileInput} type="file" accept=".json" onchange={importNotes} class="file-input" />
	<button class="imp wide-only" onclick={() => fileInput.click()} title="Import">IMP</button>

	<!-- EXP -->
	<button class="exp wide-only" onclick={openExportConfirm} title="Export">EXP</button>

	<!-- a small window: NEW and EXP in the corners, the four spaces in a row -->
	{#if isDesktop}
		<a href="/new" class="compact-btn top-right" title="New note">NEW</a>
	{/if}
	<button class="compact-btn bottom-right" onclick={openExportConfirm} title="Export">EXP</button>
	<div class="compact-spaces">
		{#each spaces as space, i}
			<button
				class="compact-space"
				onclick={() => goto(`/space/${space.element}`)}
				title="{space.english} ({shortcutKeys[space.element]}) — {noteCounts[space.id!] ?? 0} notes"
			>
				<img src="/kanji/{space.element}.png" alt={space.kanji} draggable="false" />
				<span class="compact-label"><SpaceIcon element={space.element} size={12} />{positions[i].label.text}</span>
			</button>
		{/each}
	</div>

	{#each spaces as space, i}
		{@const pos = positions[i]}
		<div class="bottom-box wide-only" style="left: {pos.bottomBox.left}; top: {pos.bottomBox.top}; width: {pos.bottomBox.width}; height: {pos.bottomBox.height};">
			<p class="label">{pos.label.text}</p>
		</div>
		<div class="top-box wide-only" style="left: {pos.topBox.left}; top: {pos.topBox.top}; width: {pos.topBox.width}; height: {pos.topBox.height};">
			<SpaceIcon element={space.element} size={20} />
		</div>
		<img
			class="kanji-image wide-only"
			style="left: {pos.image.left}; top: {pos.image.top}; width: {pos.image.size}; height: {pos.image.size};"
			src="/kanji/{space.element}.png"
			alt="{space.kanji}"
			onclick={() => goto(`/space/${space.element}`)}
			title="{space.english} ({shortcutKeys[space.element]}) — {noteCounts[space.id!] ?? 0} notes"
		/>
	{/each}
</main>

<style>
	.home {
		position: relative;
		width: 100%;
		height: 100vh;
		background: transparent;
	}

	.background {
		position: absolute;
		inset: 0;
		pointer-events: none;
	}

	.exit {
		position: absolute;
		left: calc(6.25% - 7px);
		top: calc(6.25% + 1px);
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: var(--text);
		text-decoration: none;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
	}

	.edit,
	.info {
		position: absolute;
		border: 2px solid var(--line);
		width: 42px;
		height: 164px;
		display: flex;
		align-items: center;
		justify-content: center;
		text-decoration: none;
		color: var(--text);
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		transition: background 200ms ease, color 200ms ease;
	}

	.edit:hover,
	.info:hover {
		background: var(--line);
		color: var(--bg);
	}

	.edit {
		right: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
	}

	.edit span {
		display: inline-block;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
		padding-top: 0.64em;
	}

	.bottom-box,
	.top-box {
		position: absolute;
		border: 2px solid var(--line);
		border-top: none;
		border-bottom: none;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.bottom-box {
		border-bottom: 2px solid var(--line);
	}

	.top-box {
		border-top: 2px solid var(--line);
	}

	.label {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: var(--text);
		margin: 0;
		writing-mode: vertical-rl;
		text-orientation: upright;
		line-height: 32px;
		letter-spacing: 0.64em;
	}

	.kanji-image {
		position: absolute;
		opacity: 0.8;
		cursor: pointer;
		transition: opacity 0.3s;
	}

	.kanji-image:hover {
		opacity: 1;
	}

	.file-input {
		display: none;
	}

	/* Blurs the page behind open search results */
	.home-search-overlay {
		position: fixed;
		inset: 0;
		z-index: 55; /* above INFO (50), below popups (60+) */
		backdrop-filter: blur(6px);
		-webkit-backdrop-filter: blur(6px);
	}

	/* Search across all notes, top center */
	.home-search {
		position: absolute;
		top: 30px;
		left: 50%;
		transform: translateX(-50%);
		width: 360px;
		max-width: calc(100% - 160px);
		z-index: 56;
	}

	.home-search-input {
		width: 100%;
		background: transparent;
		border: none;
		outline: none;
		font-family: 'Kurale', serif;
		font-size: 24px;
		line-height: 32px;
		text-align: center;
		color: var(--text);
		padding: 0;
	}

	.home-search-input::placeholder {
		color: var(--line);
		opacity: 0.4;
	}

	.home-search-results {
		margin-top: 1rem;
		padding: 1.25rem 1.5rem;
		background: var(--bg) url('/noise.svg') repeat;
		border: 2px solid var(--line);
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.home-search-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		background: transparent;
		border: none;
		padding: 0;
		color: var(--line);
		font-family: 'Kurale', serif;
		font-size: 16px;
		line-height: 1.2;
		text-align: left;
		cursor: pointer;
		opacity: 0.8;
		transition: opacity 200ms ease;
	}

	.home-search-row.active {
		opacity: 1;
	}

	.home-search-title {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		min-width: 0;
	}

	.home-search-empty {
		font-family: 'Kurale', serif;
		font-size: 16px;
		color: var(--line);
		opacity: 0.4;
		text-align: center;
	}

	.imp,
	.exp {
		position: absolute;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: var(--text);
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
		background: transparent;
		border: none;
		cursor: pointer;
		padding: 0;
	}

	.imp {
		right: calc(6.25% - 7px);
		top: calc(6.25% + 1px);
	}

	.exp {
		right: calc(6.25% - 7px);
		bottom: calc(6.25% + 1px);
	}

	/* same look as the INFO popup: blurred page behind, paper box */
	.exp-overlay {
		position: fixed;
		inset: 0;
		z-index: 60;
		backdrop-filter: blur(6px);
		-webkit-backdrop-filter: blur(6px);
	}

	.exp-box {
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
		min-width: 280px;
	}

	.exp-heading {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 18px;
		letter-spacing: 0.4em;
		color: var(--text);
		margin: 0;
	}

	.exp-divider {
		width: 100%;
		height: 1px;
		background: var(--line);
		opacity: 0.3;
	}

	.exp-stats {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		width: 100%;
	}

	.exp-total {
		font-family: 'Kurale', serif;
		font-size: 32px;
		color: var(--text);
		margin: 0;
		letter-spacing: 0.05em;
	}

	.exp-spaces {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		width: 100%;
	}

	.exp-space-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.exp-space-name {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 13px;
		letter-spacing: 0.2em;
		color: var(--text);
		flex: 1;
	}

	.exp-space-count {
		font-family: 'Kurale', serif;
		font-size: 18px;
		color: var(--text);
		opacity: 0.6;
	}

	.exp-confirm-btn {
		background: transparent;
		border: 2px solid var(--line);
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 16px;
		color: var(--text);
		letter-spacing: 0.3em;
		padding: 0.5rem 2rem;
		cursor: pointer;
		transition: background 200ms ease, color 200ms ease;
	}

	.exp-confirm-btn:hover {
		background: var(--line);
		color: var(--bg);
	}

	/* ── a small desktop window: the four spaces side by side ── */
	.compact-spaces { display: none; }

	@media (max-width: 759px), (max-height: 559px) {
		:global(html.desktop) .compact-spaces {
			position: absolute;
			inset: 64px 24px 44px;
			display: flex;
			align-items: center;
			justify-content: center;
			gap: 4vw;
		}

		.compact-space {
			display: flex;
			flex-direction: column;
			align-items: center;
			gap: 12px;
			background: transparent;
			border: none;
			padding: 0;
			cursor: pointer;
			opacity: 0.8;
			transition: opacity 0.3s;
		}

		.compact-space:hover { opacity: 1; }

		.compact-space img {
			width: min(17vw, 34vh);
			height: min(17vw, 34vh);
			object-fit: contain;
		}

		.compact-label {
			display: flex;
			align-items: center;
			gap: 8px;
			font-family: 'Noto Sans JP', sans-serif;
			font-size: 12px;
			letter-spacing: 0.3em;
			color: var(--text);
		}

		:global(html.desktop) .home-search { top: 14px; }
		:global(html.desktop) .home-search-input { font-size: 18px; transition: opacity 200ms ease; }
		/* only in the window in use, while nothing is typed in it */
		:global(html.desktop.blurred) .home-search-input:placeholder-shown { opacity: 0; pointer-events: none; }
	}

	@media (max-width: 640px) {
		:global(html:not(.desktop)) .exit, :global(html:not(.desktop)) .imp, :global(html:not(.desktop)) .exp { font-size: 16px; }

		:global(html:not(.desktop)) .info {
			width: 36px;
			height: 120px;
			font-size: 16px;
		}

		:global(html:not(.desktop)) .edit {
			width: 36px;
			height: 120px;
			font-size: 16px;
		}

		:global(html:not(.desktop)) .home { display: block; }

		/* Kanji – 2×2: ліва центр 32vw, права центр 68vw (±18vw від 50vw) */
		:global(html:not(.desktop)) .kanji-image:nth-of-type(1) { left: 16vw !important; top: 17vh !important; width: 32vw !important; height: 32vw !important; }
		:global(html:not(.desktop)) .kanji-image:nth-of-type(2) { left: 52vw !important; top: 17vh !important; width: 32vw !important; height: 32vw !important; }
		:global(html:not(.desktop)) .kanji-image:nth-of-type(3) { left: 16vw !important; top: 58vh !important; width: 32vw !important; height: 32vw !important; }
		:global(html:not(.desktop)) .kanji-image:nth-of-type(4) { left: 52vw !important; top: 58vh !important; width: 32vw !important; height: 32vw !important; }

		/* Top-boxes */
		:global(html:not(.desktop)) .home > :nth-child(1 of .top-box) { left: 20vw !important; top: calc(17vh - 78px) !important; width: 24vw !important; height: 70px !important; }
		:global(html:not(.desktop)) .home > :nth-child(2 of .top-box) { left: 56vw !important; top: calc(17vh - 78px) !important; width: 24vw !important; height: 70px !important; }
		:global(html:not(.desktop)) .home > :nth-child(3 of .top-box) { left: 20vw !important; top: calc(58vh - 78px) !important; width: 24vw !important; height: 70px !important; }
		:global(html:not(.desktop)) .home > :nth-child(4 of .top-box) { left: 56vw !important; top: calc(58vh - 78px) !important; width: 24vw !important; height: 70px !important; }

		/* Bottom-boxes */
		:global(html:not(.desktop)) .home > :nth-child(1 of .bottom-box) { left: 20vw !important; top: calc(17vh + 32vw + 8px) !important; width: 24vw !important; height: 130px !important; }
		:global(html:not(.desktop)) .home > :nth-child(2 of .bottom-box) { left: 56vw !important; top: calc(17vh + 32vw + 8px) !important; width: 24vw !important; height: 130px !important; }
		:global(html:not(.desktop)) .home > :nth-child(3 of .bottom-box) { left: 20vw !important; top: calc(58vh + 32vw + 8px) !important; width: 24vw !important; height: 130px !important; }
		:global(html:not(.desktop)) .home > :nth-child(4 of .bottom-box) { left: 56vw !important; top: calc(58vh + 32vw + 8px) !important; width: 24vw !important; height: 130px !important; }

		:global(html:not(.desktop)) .label {
			writing-mode: vertical-rl;
			text-orientation: upright;
			font-size: 18px;
			letter-spacing: 0.5em;
			line-height: 28px;
		}
	}
</style>