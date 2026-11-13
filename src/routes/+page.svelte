<script lang="ts">
	import { onMount } from 'svelte';
	import { openExternal } from '$lib/store';

	// The Re apps, as ReDesk names them in the corners of the desktop
	const APPS = [
		{
			name: 'ReNote',
			word: 'Note',
			kanji: '記',
			line: 'Just notes.',
			description:
				'記 / Note. A thought needs a place to land, not a system to learn. Four spaces, as old as the elements: Feel for what you absorb, Body for what must be done, Mind for what is being born, Soul for who you are when nothing is required. Write, mark what matters with ink, and let it settle.',
			tags: ['Feel', 'Body', 'Mind', 'Soul', 'Ink highlights', 'Autosave', 'Import', 'Export'],
		},
		{
			name: 'ReSurf',
			word: 'Surf',
			kanji: '波',
			line: 'Just the page.',
			description:
				'波 / Surf. The web was meant to be read. Somewhere it became a place that reads you. ReSurf gives the page back: no ads, no trackers, no history kept. Favourites on the left, open tabs on the right, and in the middle only what you came for. A video can fill the page. A page can turn to quiet grey ink.',
			tags: ['Tabs', 'Favourites', 'No ads', 'No tracking', 'No history', 'E-ink', 'Video fill'],
		},
		{
			name: 'ReFile',
			word: 'File',
			kanji: '箱',
			line: 'Just your files.',
			description:
				'箱 / File. Every file is something you once decided to keep. Folders as columns or as a list, a search that stays in the folder you are in. Pictures and text open right where they are, and text can be written in place. Music goes where music belongs: to RePlay.',
			tags: ['Columns', 'List', 'Search', 'Images', 'Text editing', 'Trash', 'Music to RePlay'],
		},
		{
			name: 'RePlay',
			word: 'Play',
			kanji: '音',
			line: 'Just music.',
			description:
				'音 / Play. Music you own, played the way it was made: from start to end, without a feed deciding what comes next. RePlay reads your music folder and nothing else. Albums, artists, songs, your own lists. Play, queue, shuffle, repeat. The rest is silence between the tracks.',
			tags: ['Albums', 'Artists', 'Songs', 'Playlists', 'Queue', 'Shuffle', 'FLAC', 'ALAC'],
		},
		{
			name: 'ReDesk',
			word: 'Desk',
			kanji: '机',
			line: 'Just the desk.',
			description:
				'机 / Desk. The place where everything else is laid out. The apps as four words in the corners. The day as a line that fills from midnight to midnight, the battery as one that rises, sound as a soft wave. Wallpapers that move, ink that follows the light behind it, and windows that find their places on their own.',
			tags: ['Corners', 'Day line', 'Battery', 'Sound wave', 'Video wallpapers', 'Tiling', 'Light / Dark'],
		},
	];

	let scroller: HTMLDivElement;

	// line the scroller up exactly on a slide (on start and whenever the window is resized)
	function snapToSlide() {
		const h = scroller.clientHeight;
		if (h) scroller.scrollTo({ top: Math.round(scroller.scrollTop / h) * h });
	}

	function toApps() {
		scroller.scrollTo({ top: scroller.clientHeight * 3, behavior: 'smooth' });
	}

	onMount(() => {
		scroller.focus({ preventScroll: true });
		snapToSlide();
		document.fonts?.ready.then(snapToSlide);
		window.addEventListener('resize', snapToSlide);
		return () => window.removeEventListener('resize', snapToSlide);
	});

	// light / dark: follows the Mac until picked here, then the pick is remembered (see app.html)
	let theme = $state(document.documentElement.dataset.theme ?? 'light');

	function toggleTheme() {
		theme = theme === 'dark' ? 'light' : 'dark';
		try {
			localStorage.setItem('theme', theme);
		} catch {}
		(window as unknown as { setTheme: (t: string) => void }).setTheme(theme);
	}

	function chunkTags(tags: string[], size = 4): string[] {
		const rows = [];
		for (let i = 0; i < tags.length; i += size) {
			rows.push(tags.slice(i, i + size).join(' · '));
		}
		return rows;
	}
</script>

<button class="theme-button" onclick={toggleTheme}>{theme === 'dark' ? 'LIGHT' : 'DARK'}</button>

<div class="landing-page" bind:this={scroller} tabindex="-1">
	<section class="slide hero">
		<button class="start-button" onclick={toApps}>
			<span>APPS</span>
		</button>
		<a
			class="kofi-button"
			href="https://ko-fi.com/artursavytskyi"
			target="_blank"
			rel="noopener noreferrer"
			onclick={e => { e.preventDefault(); openExternal(e.currentTarget.href); }}
		>
			<span>KOFI</span>
		</a>
		<div class="hero-block">
			<div class="block-corner tr"></div>
			<div class="block-corner bl"></div>
			<p class="hero-meta">nothing else</p>
			<div class="hero-title">
				<span>Re:</span>
				<span>space</span>
			</div>
			<p class="hero-tagline">just what you need.</p>
		</div>
	</section>

	<section class="slide section philosophy">
		<p class="section-heading">PHILOSOPHY</p>
		<div class="section-copy">
			<p>
				We live in a time of endless features. Apps promise everything but slowly take your time with them.
			</p>
			<p>
				A note became a system. A browser became a shop window. Music became a feed. What was meant to be simple turned into something you have to learn, and something that learns you.
			</p>
			<p>
				ReSpace is different. A few quiet apps for the Mac, each doing one thing, all speaking the same language: paper, ink, and nothing that is not needed.
			</p>
		</div>
	</section>

	<section class="slide section no-section">
		<p class="section-heading">NO</p>
		<div class="no-box">
			<div class="no-copy">
				Ads · Notifications · Paywalls · Tracking<br>
				Algorithms · Manipulation · Accounts · AI
			</div>
		</div>
		<p class="no-after"><span class="ink-mark">Only you and your things.</span></p>
	</section>

	{#each APPS as app, index}
		<section class="slide section app-section">
			<p class="section-heading">{app.name.toUpperCase()}</p>
			<div class="app-card {index % 2 === 0 ? 'odd' : 'even'}">
				<div class="app-visual">
					<div class="app-top-box">
						<span class="app-re">Re</span>
					</div>
					<span class="app-kanji">{app.kanji}</span>
					<div class="app-bottom-box">
						<p class="app-label">{app.word.toUpperCase()}</p>
					</div>
				</div>
				<div class="app-content">
					<p class="app-line"><span class="ink-mark">{app.line}</span></p>
					<p class="app-copy">{app.description}</p>
					<div class="tags-block">
						{#each chunkTags(app.tags) as row}
							<p class="app-tags">{row}</p>
						{/each}
					</div>
				</div>
			</div>
		</section>
	{/each}

	<section class="slide section local-section">
		<p class="section-heading">LOCAL</p>
		<div class="section-copy">
			<p>
				Everything lives on your Mac. Your notes, your files, your music, your desk. No cloud in between, no account to open, nothing sent anywhere.
			</p>
			<p>
				The apps work offline, follow the Mac's light and dark, and open one another when it makes sense. Each one alone is enough. Together they are a space.
			</p>
			<p>
				<span class="ink-mark">Your space is yours, always.</span>
			</p>
		</div>
	</section>

	<section class="slide credits-section">
		<div class="credits-block">
			<div class="block-corner tr"></div>
			<div class="block-corner bl"></div>
			<p class="credits">
				<span>Designed by <span class="ink-mark">Human</span></span>
				<span>Developed by <span class="ink-mark">AI</span></span>
			</p>
		</div>
		<p class="copyright">© 2026 Re:Space</p>
	</section>
</div>

<style>
	/* Each section is a full-screen slide; scrolling snaps to one at a time */
	.landing-page {
		position: relative;
		width: 100%;
		height: 100vh;
		height: 100dvh;
		overflow-y: auto;
		overflow-x: hidden;
		scroll-snap-type: y mandatory;
		outline: none;
	}

	.slide {
		position: relative;
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem calc(6.25% + 80px);
		scroll-snap-align: center;
		scroll-snap-stop: always;
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
		background: var(--line);
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

	.block-corner.tr { top: 0; right: 0; transform: rotate(90deg); }
	.block-corner.bl { bottom: 0; left: 0; transform: rotate(-90deg); }

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

	.section > * {
		width: min(1120px, 100%);
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
		color: var(--text);
		opacity: 0.9;
		letter-spacing: 0.15em;
		text-align: center;
		position: absolute;
		bottom: 3rem;
		left: 0;
		right: 0;
		width: auto;
	}

	.credits-block {
		position: relative;
		width: 420px;
		height: 260px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.credits {
		display: flex;
		flex-direction: column;
		gap: 1.2rem;
		margin: 0;
		font-family: 'Kurale', serif;
		font-size: clamp(1.3rem, 1.6vw, 1.8rem);
		letter-spacing: 0.04em;
		text-align: center;
	}

	/* the stroke's own left margin would run it into "by" */
	.credits .ink-mark {
		margin-left: 0.1em;
	}

	.theme-button {
		position: fixed;
		top: calc(6.25% - 1.6rem);
		right: calc(6.25% - 7px);
		z-index: 10;
		background: transparent;
		border: none;
		padding: 0.4em 0;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 0.8rem;
		letter-spacing: 0.5em;
		color: var(--text);
		opacity: 0.75;
		cursor: pointer;
		transition: opacity 200ms ease;
	}

	.theme-button:hover {
		opacity: 1;
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

	.no-after {
		margin: 3rem auto 0;
		font-family: 'Kurale', serif;
		font-size: clamp(1rem, 1.1vw, 1.35rem);
		line-height: 1.95;
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

	.app-card {
		display: grid;
		grid-template-columns: 98px 1fr;
		gap: 14rem;
		align-items: stretch;
		max-width: 860px;
		margin: 0 auto;
		width: 100%;
	}

	.app-card.even {
		grid-template-columns: 1fr 98px;
	}

	.app-card.even .app-visual {
		order: 2;
	}

	.app-card.even .app-content {
		order: 1;
	}

	/* the same boxed column as ReNote's spaces: a mark above, the word below, the kanji between */
	.app-visual {
		position: relative;
		width: 98px;
		height: 413px; /* 82 + 180 + 151 */
		flex-shrink: 0;
		overflow: visible;
	}

	.app-top-box {
		position: absolute;
		top: 0;
		left: 0;
		width: 98px;
		height: 82px;
		border: 2px solid var(--line);
		border-bottom: none;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.app-re {
		font-family: 'Kurale', serif;
		font-size: 1.1rem;
		letter-spacing: 0.04em;
	}

	.app-kanji {
		position: absolute;
		top: 40%;
		left: 50%;
		transform: translate(-50%, -50%);
		font-family: 'Noto Sans JP', sans-serif;
		font-weight: 300;
		font-size: 128px;
		line-height: 1;
		opacity: 0.8;
	}

	.app-bottom-box {
		position: absolute;
		bottom: 0;
		left: 0;
		width: 98px;
		height: 151px;
		border: 2px solid var(--line);
		border-top: none;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.app-label {
		margin: 0;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		letter-spacing: 0.64em;
		color: var(--text);
		writing-mode: vertical-rl;
		text-orientation: upright;
		line-height: 32px;
	}

	.app-content {
		display: flex;
		flex-direction: column;
		gap: 0;
		justify-content: flex-start;
	}

	.app-line {
		margin: 0 0 1.4rem;
		font-family: 'Kurale', serif;
		font-size: clamp(1.1rem, 1.3vw, 1.45rem);
		line-height: 1.6;
	}

	.app-copy {
		font-family: 'Kurale', serif;
		font-size: clamp(1rem, 1.2vw, 1.3rem);
		line-height: 1.95;
		margin: 0;
		text-align: left;
	}

	.app-tags {
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
		border: 2px solid var(--line);
		background: transparent;
		color: var(--text);
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
		background: var(--line);
		color: var(--bg);
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
		border: 2px solid var(--line);
		background: transparent;
		color: var(--text);
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
		background: var(--line);
		color: var(--bg);
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
		.hero-meta {
			left: 1rem;
		}

		.hero-tagline {
			top: auto;
			bottom: 1.5rem;
			right: 1rem;
			text-align: right;
		}

		.app-card,
		.app-card.even {
			grid-template-columns: 1fr;
			gap: 3rem;
			text-align: center;
		}

		.app-label {
			writing-mode: horizontal-tb;
			letter-spacing: 0.22em;
		}
	}

	@media (max-width: 640px) {
		.slide { padding: 3rem 1rem 4rem; }

		.start-button {
			position: static;
			transform: none;
			width: 120px;
			height: 36px;
			font-size: 16px;
			margin: 2.5rem auto 0;
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
			margin: 0 auto 2.5rem;
			order: 0;
		}

		.kofi-button span {
			writing-mode: horizontal-tb;
			text-orientation: mixed;
			letter-spacing: 0.3em;
			padding-top: 0;
		}

		.hero-block {
			width: 85vw;
			height: 85vw;
			order: 1;
		}

		.hero-title {
			font-size: clamp(2rem, 13vw, 3rem);
		}

		.credits-block {
			width: 85vw;
			height: 55vw;
		}

		.theme-button {
			top: 1rem;
			right: 1rem;
		}

		.section-heading { margin-bottom: 2rem; }

		.app-card,
		.app-card.even {
			display: flex;
			flex-direction: column;
			gap: 1.5rem;
		}

		.app-card.even .app-visual,
		.app-card.even .app-content {
			order: unset;
		}

		.app-visual {
			width: 100%;
			height: 88px;
			display: flex;
			flex-direction: row;
			align-items: stretch;
		}

		.app-top-box {
			position: static;
			width: 56px;
			height: 88px;
			border: 2px solid var(--line);
			border-right: none;
			flex-shrink: 0;
		}

		.app-kanji {
			position: static;
			width: 88px;
			height: 88px;
			transform: none;
			font-size: 56px;
			display: flex;
			align-items: center;
			justify-content: center;
			flex-shrink: 0;
		}

		.app-bottom-box {
			position: static;
			flex: 1;
			height: 88px;
			border: 2px solid var(--line);
			border-left: none;
		}

		.app-label {
			font-size: 14px;
			letter-spacing: 0.3em;
		}

		.app-line { margin-bottom: 1rem; text-align: center; }

		.tags-block { margin-top: 1.5rem; }

		.app-tags { font-size: 0.75rem; }

		.section-copy p,
		.app-copy { font-size: 1rem; }
	}
</style>
