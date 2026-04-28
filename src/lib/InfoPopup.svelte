<script lang="ts">
	import { db, SPACES } from './db';

	let open = $state(false);
	let noteCount = $state(0);
	let spaceCounts: Record<string, number> = $state({});

	async function loadStats() {
		noteCount = await db.notes.count();
		const spaces = await db.spaces.toArray();
		const counts: Record<string, number> = {};
		for (const s of spaces) {
			counts[s.english] = await db.notes.where('spaceId').equals(s.id!).count();
		}
		spaceCounts = counts;
	}

	function toggle() {
		if (!open) loadStats();
		open = !open;
	}
</script>

<button class="info-btn" onclick={toggle}>INFO</button>

{#if open}
	<div class="info-overlay" onclick={toggle} aria-hidden="true"></div>
	<div class="info-box">
		<p class="info-heading">RE:NOTE</p>
		<div class="info-divider"></div>
		<div class="info-stats">
			<p class="info-total">{noteCount} {noteCount === 1 ? 'note' : 'notes'}</p>
			<div class="info-spaces">
				{#each SPACES as s}
					<div class="info-space-row">
						<span class="info-dot" style="color: {s.color}">◆</span>
						<span class="info-space-name">{s.english.toUpperCase()}</span>
						<span class="info-space-count">{spaceCounts[s.english] ?? 0}</span>
					</div>
				{/each}
			</div>
		</div>
		<div class="info-divider"></div>
		<p class="info-footer">local · private · offline</p>
	</div>
{/if}

<style>
	.info-btn {
		position: fixed;
		left: calc(6.25% - 7px);
		bottom: calc(6.25% + 1px);
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
		z-index: 50;
		padding: 0;
	}

	.info-overlay {
		position: fixed;
		inset: 0;
		z-index: 60;
	}

	.info-box {
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

	.info-heading {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 18px;
		letter-spacing: 0.4em;
		color: #474747;
		margin: 0;
	}

	.info-divider {
		width: 100%;
		height: 1px;
		background: #413f3f;
		opacity: 0.3;
	}

	.info-stats {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		width: 100%;
	}

	.info-total {
		font-family: 'Kurale', serif;
		font-size: 32px;
		color: #474747;
		margin: 0;
		letter-spacing: 0.05em;
	}

	.info-spaces {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		width: 100%;
	}

	.info-space-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.info-dot {
		font-size: 0.75rem;
	}

	.info-space-name {
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 13px;
		letter-spacing: 0.2em;
		color: #474747;
		flex: 1;
	}

	.info-space-count {
		font-family: 'Kurale', serif;
		font-size: 18px;
		color: #474747;
		opacity: 0.6;
	}

	.info-footer {
		font-family: 'Kurale', serif;
		font-size: 13px;
		color: #474747;
		opacity: 0.4;
		letter-spacing: 0.1em;
		margin: 0;
	}
</style>
