<script lang="ts">
	import { goto } from '$app/navigation';
	import { seedSpaces, SPACES } from '$lib/db';

	async function start() {
		await seedSpaces();
		goto('/home');
	}

	function chunkTags(types: string[], size = 4): string[] {
		const rows = [];
		for (let i = 0; i < types.length; i += size) {
			rows.push(types.slice(i, i + size).join(' · '));
		}
		return rows;
	}
</script>

<div class="landing-page">
	<div class="hero">
		<div class="hero-block">
			<div class="block-corner tr"></div>
			<div class="block-corner bl"></div>
			<p class="hero-meta">nothing else</p>
			<div class="hero-title">
				<span>Re:</span>
				<span>note</span>
			</div>
			<p class="hero-tagline">just notes.</p>
		</div>
	</div>

	<main class="content">
		<section class="section philosophy">
			<p class="section-heading">PHILOSOPHY</p>
			<div class="section-copy">
				<p>
					Thinking has become a public act. Every idea you form, every moment of reflection — captured, catalogued, and quietly sold. Your attention is a currency. Your habits are data. We were promised tools that would extend the mind. What we got were traps dressed as convenience — platforms that fragment thought, reward distraction, and profit from who you're performing to be.
				</p>
				<p>
					This is different. No feeds, no friction, no agenda. Just the four oldest forces in the world and a place to think the way humans always have. Slowly. Privately. Honestly. Your mind was never meant to be a product. It still isn't.
				</p>
			</div>
		</section>

		<section class="section no-section">
			<p class="section-heading">NO</p>
			<div class="no-box">
				<div class="block-corner tl"></div>
				<div class="block-corner tr"></div>
				<div class="block-corner bl"></div>
				<div class="block-corner br"></div>
				<div class="no-copy">
					Ads · Notifications · Paywalls · Tracking<br>
					Algorithms · Manipulation · Accounts · Profiles
				</div>
			</div>
		</section>

		<section class="section space-section">
			<p class="section-heading">SPACE</p>
			<div class="space-grid">
				{#each SPACES as space, index}
					<div class="space-card {index % 2 === 0 ? 'odd' : 'even'}">
						<div class="space-visual">
							<div class="space-top-box">
								<div class="space-diamond" style="background: {space.color}"></div>
							</div>
							<img src="/kanji/{space.element}.png" alt={space.kanji} class="space-kanji-img" />
							<div class="space-bottom-box">
								<p class="space-label">{space.english.toUpperCase()}</p>
							</div>
						</div>
						<div class="space-content">
							<p class="space-copy">{space.description}</p>
							<div class="tags-block">
							<div class="block-corner tr"></div>
							<div class="block-corner bl"></div>
							{#each chunkTags(space.types) as row}
								<p class="space-tags">{row}</p>
							{/each}
						</div>
						</div>
					</div>
				{/each}
			</div>
		</section>

		<section class="section backup-section">
			<p class="section-heading">IMPORT / EXPORT</p>
			<div class="section-copy">
				<p>
					Your notes live entirely on your device — no servers, no accounts, no cloud. That means you are the only one responsible for keeping them safe. ReNote gives you two tools to do that: export your notes as a plain JSON file you can store anywhere, and import them back whenever you need.
				</p>
				<p>
					Use export before switching devices, clearing your browser, or simply as a personal archive. Use import to restore a backup or move your notes to a new machine. The format is open and human-readable — your data is yours, always.
				</p>
			</div>
		</section>
	</main>

	<button class="start-button" onclick={start}>
		<span>OPEN</span>
	</button>
</div>

<style>
	.landing-page {
		position: relative;
		min-height: 100vh;
		width: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 2rem 1.5rem 4rem;
	}

	.hero {
		width: min(1120px, 100%);
		min-height: calc(100vh - 4rem);
		display: grid;
		place-items: center;
		margin-bottom: 16rem;
	}

	.hero-block {
		position: relative;
		width: 516px;
		height: 516px;
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

	.hero-meta {
		position: absolute;
		margin: 0;
		font-family: 'Kurale', serif;
		font-size: 1rem;
		letter-spacing: 0.02em;
	}

	.hero-title {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		font-family: 'Kurale', serif;
		font-size: clamp(3rem, 3vw, 3rem);
		line-height: 0.92;
		letter-spacing: 0.02em;
		margin: 0;
	}

	.hero-title span {
		display: block;
	}

	.hero-tagline {
		position: absolute;
		bottom: 1.5rem;
		right: 1.5rem;
		margin: 0;
		font-family: 'Kurale', serif;
		font-size: 1rem;
		letter-spacing: 0.12em;
	}

	.content {
		width: min(1120px, 100%);
		display: flex;
		flex-direction: column;
		gap: 16rem;
	}

	.section {
		width: 100%;
		padding: 0;
	}

	.section-heading {
		display: block;
		margin: 0 auto 4rem;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 0.9rem;
		letter-spacing: 0.5em;
		text-transform: uppercase;
		text-align: center;
	}

	.section-copy {
		max-width: 900px;
		margin: 0 auto;
		display: flex;
		flex-direction: column;
		gap: 1.6rem;
	}

	.section-copy p {
		font-family: 'Kurale', serif;
		font-size: clamp(1rem, 1.1vw, 1.35rem);
		line-height: 1.95;
		color: var(--text);
		margin: 0;
	}

	.no-section .no-box {
		position: relative;
		max-width: 900px;
		margin: 0 auto;
		padding: 2rem 2.5rem;
	}

	.no-copy {
		font-family: 'Kurale', serif;
		font-size: clamp(1.05rem, 1.1vw, 1.4rem);
		line-height: 2.1;
		text-align: center;
	}

	.tags-block {
		flex: 1;
		position: relative;
		padding: 0.75rem 1rem;
		display: flex;
		flex-direction: column;
		justify-content: center;
	}

	.space-section {
		padding: 0;
	}

	.space-grid {
		display: flex;
		flex-direction: column;
		gap: 6rem;
		overflow: visible;
	}

	.space-card {
		display: grid;
		grid-template-columns: 98px 1fr;
		gap: 4rem;
		align-items: stretch;
		max-width: 860px;
		margin: 0 auto;
		width: 100%;
	}

	.space-card.even {
		grid-template-columns: 1fr 98px;
	}

	.space-card.even .space-visual {
		order: 2;
	}

	.space-card.even .space-content {
		order: 1;
		text-align: left;
	}

	/* Visual block — mirrors home page style */
	.space-visual {
		position: relative;
		width: 98px;
		height: 413px; /* 82 + 180 + 151 */
		flex-shrink: 0;
		overflow: visible;
	}

	.space-top-box {
		position: absolute;
		top: 0;
		left: 0;
		width: 98px;
		height: 82px;
		border: 2px solid #413f3f;
		border-bottom: none;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.space-diamond {
		width: 14px;
		height: 14px;
		transform: rotate(-45deg);
	}

	.space-kanji-img {
		position: absolute;
		top: 40%;
		left: 50%;
		transform: translate(-50%, -50%);
		width: 224px;
		height: 224px;
		object-fit: contain;
		opacity: 0.8;
	}

	.space-bottom-box {
		position: absolute;
		bottom: 0;
		left: 0;
		width: 98px;
		height: 151px;
		border: 2px solid #413f3f;
		border-top: none;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.space-label {
		margin: 0;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		letter-spacing: 0.64em;
		color: #474747;
		writing-mode: vertical-rl;
		text-orientation: upright;
		line-height: 32px;
	}

	.space-content {
		display: flex;
		flex-direction: column;
		gap: 0;
		justify-content: flex-start;
	}

	.space-copy {
		font-family: 'Kurale', serif;
		font-size: clamp(1rem, 1.2vw, 1.3rem);
		line-height: 1.95;
		margin: 0 0 10rem; // AAAARRRRTTTT
		text-align: left;
	}

	.space-tags {
		margin: 0;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 1rem;
		letter-spacing: 0.2em;
		line-height: 1.9;
		text-align: center;
	}

	.start-button {
		position: fixed;
		right: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
		width: 42px;
		height: 164px;
		border: 2px solid #413f3f;
		background: transparent;
		color: #474747;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		z-index: 10;
		padding: 0;
	}

	.start-button span {
		display: inline-block;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
	}

	@media (max-width: 980px) {
		.hero {
			min-height: auto;
			padding: 4rem 0 2rem;
		}

		.hero-meta {
			left: 1rem;
		}

		.hero-tagline {
			top: auto;
			bottom: 1.5rem;
			right: 1rem;
			text-align: right;
		}

		.space-card,
		.space-card.even {
			grid-template-columns: 1fr;
			text-align: center;
		}

		.space-panel {
			flex-direction: row;
			justify-content: center;
			gap: 0.75rem;
		}

		.space-label {
			writing-mode: horizontal-tb;
			letter-spacing: 0.22em;
		}
	}

	@media (max-width: 640px) {
		.landing-page {
			padding: 1.5rem 1rem 2.5rem;
		}

		.start-button {
			right: 0.5rem;
			font-size: 0.85rem;
		}

		.hero-title {
			font-size: clamp(3.5rem, 18vw, 5.5rem);
		}

		.section-copy p,
		.space-copy {
			font-size: 1rem;
		}
	}
</style>