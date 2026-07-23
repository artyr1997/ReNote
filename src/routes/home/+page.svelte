<script lang="ts">
	import { goto } from '$app/navigation';
	import type { Space } from '$lib/db';
	import { db, SPACES } from '$lib/db';

	let { data } = $props();
	let { spaces, noteCounts } = $derived(data);

	let showExportConfirm = $state(false);
	let exportNoteCount = $state(0);
	let exportSpaceCounts: Record<string, number> = $state({});

	async function openExportConfirm() {
		exportNoteCount = await db.notes.count();
		const spacesData = await db.spaces.toArray();
		const counts: Record<string, number> = {};
		for (const s of spacesData) {
			counts[s.english] = await db.notes.where('spaceId').equals(s.id!).count();
		}
		exportSpaceCounts = counts;
		showExportConfirm = true;
	}

	async function exportNotes() {
		const notes = await db.notes.toArray();
		const spacesData = await db.spaces.toArray();

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

		const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `renote-backup-${new Date().toISOString().slice(0, 10)}.json`;
		a.click();
		URL.revokeObjectURL(url);
		showExportConfirm = false;
	}

	let fileInput: HTMLInputElement;

	async function importNotes(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;

		try {
			const text = await file.text();
			const parsed = JSON.parse(text);
			if (!parsed.notes || !Array.isArray(parsed.notes)) return;

			const spacesData = await db.spaces.toArray();

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

			await db.notes.bulkAdd(notesToAdd);
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

<main class="home fade-in">
	<!-- Background -->
	<div class="background" aria-hidden="true"></div>

	<!-- EXIT -->
	<a href="/" class="exit">EXIT</a>

	<!-- IMP -->
	<input bind:this={fileInput} type="file" accept=".json" onchange={importNotes} class="file-input" />
	<button class="imp" onclick={() => fileInput.click()}>IMP</button>

	<!-- EXP -->
	<button class="exp" onclick={openExportConfirm}>EXP</button>

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
							<span class="exp-dot" style="color: {s.color}">◆</span>
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

	<!-- NEW -->
	<a href="/new" class="edit">
		<span>NEW</span>
	</a>

	{#each spaces as space, i}
		{@const pos = positions[i]}
		<div class="bottom-box" style="left: {pos.bottomBox.left}; top: {pos.bottomBox.top}; width: {pos.bottomBox.width}; height: {pos.bottomBox.height};">
			<p class="label">{pos.label.text}</p>
		</div>
		<div class="top-box" style="left: {pos.topBox.left}; top: {pos.topBox.top}; width: {pos.topBox.width}; height: {pos.topBox.height};">
			<div class="diamond" style="background-color: {space.color};"></div>
		</div>
		<img
			class="kanji-image"
			style="left: {pos.image.left}; top: {pos.image.top}; width: {pos.image.size}; height: {pos.image.size};"
			src="/kanji/{space.element}.png"
			alt="{space.kanji}"
			onclick={() => goto(`/space/${space.element}`)}
			title="{space.english} — {noteCounts[space.id!] ?? 0} notes"
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
		color: #474747;
		text-decoration: none;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
	}

	.edit,
	.info {
		position: absolute;
		border: 2px solid #413f3f;
		width: 42px;
		height: 164px;
		display: flex;
		align-items: center;
		justify-content: center;
		text-decoration: none;
		color: #474747;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		transition: background 200ms ease, color 200ms ease;
	}

	.edit:hover,
	.info:hover {
		background: #413f3f;
		color: #f5f0e8;
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
		border: 2px solid #413f3f;
		border-top: none;
		border-bottom: none;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.bottom-box {
		border-bottom: 2px solid #413f3f;
	}

	.top-box {
		border-top: 2px solid #413f3f;
	}

	.label {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: #474747;
		margin: 0;
		writing-mode: vertical-rl;
		text-orientation: upright;
		line-height: 32px;
		letter-spacing: 0.64em;
	}

	.diamond {
		width: 16px;
		height: 16px;
		transform: rotate(-45deg);
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

	.imp,
	.exp {
		position: absolute;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		color: #474747;
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

	.exp-overlay {
		position: fixed;
		inset: 0;
		z-index: 60;
	}

	.exp-box {
		position: fixed;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		background: var(--bg, #f5f0e8);
		border: 2px solid #413f3f;
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
		color: #474747;
		margin: 0;
	}

	.exp-divider {
		width: 100%;
		height: 1px;
		background: #413f3f;
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
		color: #474747;
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

	.exp-dot {
		font-size: 0.75rem;
	}

	.exp-space-name {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 13px;
		letter-spacing: 0.2em;
		color: #474747;
		flex: 1;
	}

	.exp-space-count {
		font-family: 'Kurale', serif;
		font-size: 18px;
		color: #474747;
		opacity: 0.6;
	}

	.exp-confirm-btn {
		background: transparent;
		border: 2px solid #413f3f;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 16px;
		color: #474747;
		letter-spacing: 0.3em;
		padding: 0.5rem 2rem;
		cursor: pointer;
		transition: background 200ms ease, color 200ms ease;
	}

	.exp-confirm-btn:hover {
		background: #413f3f;
		color: #f5f0e8;
	}

	@media (max-width: 640px) {
		.exit, .imp, .exp { font-size: 16px; }

		.info {
			width: 36px;
			height: 120px;
			font-size: 16px;
		}

		.edit {
			width: 36px;
			height: 120px;
			font-size: 16px;
		}

		.home { display: block; }

		/* Kanji – 2×2: ліва центр 32vw, права центр 68vw (±18vw від 50vw) */
		.kanji-image:nth-of-type(1) { left: 16vw !important; top: 17vh !important; width: 32vw !important; height: 32vw !important; }
		.kanji-image:nth-of-type(2) { left: 52vw !important; top: 17vh !important; width: 32vw !important; height: 32vw !important; }
		.kanji-image:nth-of-type(3) { left: 16vw !important; top: 58vh !important; width: 32vw !important; height: 32vw !important; }
		.kanji-image:nth-of-type(4) { left: 52vw !important; top: 58vh !important; width: 32vw !important; height: 32vw !important; }

		/* Top-boxes */
		.home > :nth-child(1 of .top-box) { left: 20vw !important; top: calc(17vh - 78px) !important; width: 24vw !important; height: 70px !important; }
		.home > :nth-child(2 of .top-box) { left: 56vw !important; top: calc(17vh - 78px) !important; width: 24vw !important; height: 70px !important; }
		.home > :nth-child(3 of .top-box) { left: 20vw !important; top: calc(58vh - 78px) !important; width: 24vw !important; height: 70px !important; }
		.home > :nth-child(4 of .top-box) { left: 56vw !important; top: calc(58vh - 78px) !important; width: 24vw !important; height: 70px !important; }

		/* Bottom-boxes */
		.home > :nth-child(1 of .bottom-box) { left: 20vw !important; top: calc(17vh + 32vw + 8px) !important; width: 24vw !important; height: 130px !important; }
		.home > :nth-child(2 of .bottom-box) { left: 56vw !important; top: calc(17vh + 32vw + 8px) !important; width: 24vw !important; height: 130px !important; }
		.home > :nth-child(3 of .bottom-box) { left: 20vw !important; top: calc(58vh + 32vw + 8px) !important; width: 24vw !important; height: 130px !important; }
		.home > :nth-child(4 of .bottom-box) { left: 56vw !important; top: calc(58vh + 32vw + 8px) !important; width: 24vw !important; height: 130px !important; }

		.label {
			writing-mode: vertical-rl;
			text-orientation: upright;
			font-size: 18px;
			letter-spacing: 0.5em;
			line-height: 28px;
		}
	}
</style>