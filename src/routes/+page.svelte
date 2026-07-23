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
		<button class="start-button" onclick={start}>
			<span>OPEN</span>
		</button>
		<a class="kofi-button" href="https://ko-fi.com/artursavytskyi" target="_blank" rel="noopener noreferrer">
			<span>KOFI</span>
		</a>
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
					We live in a time of endless features. Apps promise everything but slowly take your time with them.
				</p>
				<p>
					Notes became systems but systems became noise. What was meant to be simple turned into something you have to learn.
				</p>
				<p>
					ReNote is different. Just you and your thoughts. Your notes stay where they belong: in your browser, under your control.
				</p>
				<p>
					This is your space again.
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
					Algorithms · Manipulation · Accounts · AI
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
					Your notes live entirely on your device. That means you are the only one responsible for keeping them safe. ReNote gives you two tools to do that: export your notes as a plain JSON file you can store anywhere, and import them back whenever you need.
				</p>
				<p>
					Use export before switching devices, clearing your browser, or simply as a personal archive. Use import to restore a backup or move your notes to a new machine.
				</p>
				<p>
					Your data is yours, always.
				</p>
			</div>
		</section>

		<p class="copyright">© 2026 Re:Note</p>
	</main>

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

	.hero-block .block-corner.tr {
		animation: cornerTR 2s ease-out both;
	}

	.hero-block .block-corner.bl {
		animation: cornerBL 2s ease-out both;
	}

	@keyframes cornerTR {
		0% {
			top: calc(50% - 9px);
			right: calc(50% - 9px);
			transform: rotate(270deg);
		}
		40% {
			top: calc(50% - 9px);
			right: calc(50% - 9px);
			transform: rotate(90deg);
		}
		100% {
			top: 0;
			right: 0;
			transform: rotate(90deg);
		}
	}

	@keyframes cornerBL {
		0% {
			bottom: calc(50% - 9px);
			left: calc(50% - 9px);
			transform: rotate(90deg);
		}
		40% {
			bottom: calc(50% - 9px);
			left: calc(50% - 9px);
			transform: rotate(-90deg);
		}
		100% {
			bottom: 0;
			left: 0;
			transform: rotate(-90deg);
		}
	}

	@keyframes heroContentFade {
		from { opacity: 0; }
		to   { opacity: 1; }
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
		animation: heroContentFade 0.5s ease-out 1.6s both;
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
		animation: heroContentFade 0.5s ease-out 1.6s both;
	}

	.hero-title span {
		display: block;
	}

	.hero-tagline {
		position: absolute;
		bottom: 0.1rem;
		right: 0.1rem;
		margin: 0;
		animation: heroContentFade 0.5s ease-out 1.6s both;
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
		text-align: center;
	}

	.section-copy p {
		font-family: 'Kurale', serif;
		font-size: clamp(1rem, 1.1vw, 1.35rem);
		line-height: 1.95;
		color: var(--text);
		margin: 0;
	}

	.copyright {
		font-family: 'Kurale', serif;
		font-size: 13px;
		color: #474747;
		opacity: 0.9;
		letter-spacing: 0.15em;
		text-align: center;
		margin: 6rem auto 4rem;
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
		position: relative;
		padding: 0.75rem 1rem;
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		text-align: center;
		margin-top: auto;
		margin-bottom: auto;
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
		margin: 0;
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
		animation: heroContentFade 0.5s ease-out 1.6s both;
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
		transition: background 200ms ease, color 200ms ease;
	}

	.start-button:hover {
		background: #413f3f;
		color: #f5f0e8;
	}

	.start-button span {
		display: inline-block;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
		padding-top: 0.64em;
	}

	.kofi-button {
		position: fixed;
		left: calc(6.25% - 7px);
		top: 50%;
		transform: translateY(-50%);
		animation: heroContentFade 0.5s ease-out 1.6s both;
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
		text-decoration: none;
		transition: background 200ms ease, color 200ms ease;
	}

	.kofi-button:hover {
		background: #413f3f;
		color: #f5f0e8;
	}

	.kofi-button span {
		display: inline-block;
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.64em;
		line-height: 32px;
		padding-top: 0.64em;
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
		.landing-page { padding: 1.5rem 1rem 2.5rem; }

		.start-button {
			position: static;
			transform: none;
			width: 120px;
			height: 36px;
			font-size: 16px;
			margin: 5rem auto 0;
			order: 2;
		}

		.start-button span {
			writing-mode: horizontal-tb;
			text-orientation: mixed;
			letter-spacing: 0.3em;
			padding-top: 0;
		}

		.kofi-button {
			position: static;
			transform: none;
			width: 120px;
			height: 36px;
			font-size: 16px;
			margin: 0 auto 5rem;
			order: 0;
		}

		.kofi-button span {
			writing-mode: horizontal-tb;
			text-orientation: mixed;
			letter-spacing: 0.3em;
			padding-top: 0;
		}

		.hero {
			margin-bottom: 4rem;
			display: flex;
			flex-direction: column;
			align-items: center;
		}

		.hero-block {
			width: 85vw;
			height: 85vw;
			order: 1;
		}

		.hero-title {
			font-size: clamp(2rem, 13vw, 3rem);
		}

		.content { gap: 4rem; }

		.section-heading { margin-bottom: 2rem; }

		.space-grid { gap: 4rem; }

		.space-card,
		.space-card.even {
			display: flex;
			flex-direction: column;
		}

		.space-card.even .space-visual,
		.space-card.even .space-content {
			order: unset;
		}

		.space-visual {
			width: 100%;
			height: 88px;
			display: flex;
			flex-direction: row;
			align-items: stretch;
		}

		.space-top-box {
			position: static;
			width: 56px;
			height: 88px;
			border: 2px solid #413f3f;
			border-right: none;
			flex-shrink: 0;
		}

		.space-kanji-img {
			position: static;
			width: 88px;
			height: 88px;
			transform: none;
			object-fit: contain;
			opacity: 0.8;
			flex-shrink: 0;
		}

		.space-bottom-box {
			position: static;
			flex: 1;
			height: 88px;
			border: 2px solid #413f3f;
			border-left: none;
		}

		.space-label {
			font-size: 14px;
			letter-spacing: 0.3em;
		}

		.tags-block { margin-top: 1.5rem; }

		.space-tags { font-size: 0.75rem; }

		.section-copy p,
		.space-copy { font-size: 1rem; }
	}
</style>