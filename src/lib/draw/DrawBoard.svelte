<script lang="ts">
	// A drawing in a note, drawn on the whole window (ReDraw's paper, moved here): the pen, the brush (as a
	// kanji is written), the rubber, with the mouse, the trackpad pressed (its Force Touch for the line's
	// weight) or PAD (the trackpad as a tablet: src-tauri/src/pad.rs). Pinch or ⌘+ / ⌘− nearer and further,
	// two fingers move the paper. DONE (or Esc) gives the drawing back to the note.
	import { onMount, tick, untrack } from 'svelte';
	import { invoke } from '@tauri-apps/api/core';
	import { listen } from '@tauri-apps/api/event';
	import { t } from '$lib/lang.svelte';
	import { SIZES, bounds, drawStroke, segment, themeInk, use, type Point, type Stroke, type Tool } from './ink';

	let { strokes: given = [], ondone }: { strokes?: Stroke[]; ondone: (strokes: Stroke[]) => void } = $props();

	interface Contact {
		id: number;
		x: number;
		y: number;
		size: number;
		down: boolean;
	}

	let sizeAt = $state(1);
	let tool: Tool = $state('pen');
	// its strokes when it opens: drawn on from there
	let strokes: Stroke[] = $state.raw(untrack(() => [...given]));
	let undone: Stroke[] = $state.raw([]);
	let live: Stroke | null = null;

	let canvas: HTMLCanvasElement | undefined = $state();
	let ctx: CanvasRenderingContext2D | null = null;
	let width = $state(window.innerWidth);
	let height = $state(window.innerHeight);
	let zoom = 1;
	let panX = 0;
	let panY = 0;
	const ZOOM_MIN = 0.2;
	const ZOOM_MAX = 8;

	let toast = $state('');
	let toastTimer: ReturnType<typeof setTimeout> | null = null;
	function showToast(text: string) {
		toast = text;
		if (toastTimer) clearTimeout(toastTimer);
		toastTimer = setTimeout(() => (toast = ''), 1400);
	}

	const desktop = '__TAURI_INTERNALS__' in window;

	// ── drawing ──

	function prepare() {
		if (!canvas) return;
		const dpr = window.devicePixelRatio || 1;
		canvas.width = Math.round(width * dpr);
		canvas.height = Math.round(height * dpr);
		ctx = canvas.getContext('2d');
		ctx?.setTransform(dpr * zoom, 0, 0, dpr * zoom, dpr * (width / 2 + panX), dpr * (height / 2 + panY));
		redraw();
	}

	function ready() {
		use(ctx, { zoom, color: themeInk(), live });
	}

	function redraw() {
		if (!ctx || !canvas) return;
		ctx.save();
		ctx.setTransform(1, 0, 0, 1, 0, 0);
		ctx.clearRect(0, 0, canvas.width, canvas.height);
		ctx.restore();
		ready();
		for (const s of strokes) drawStroke(s);
		if (live) drawStroke(live);
		ctx.globalCompositeOperation = 'source-over';
	}

	function begin(x: number, y: number, p: number, t: number) {
		x = (x - width / 2 - panX) / zoom;
		y = (y - height / 2 - panY) / zoom;
		live = { tool, size: SIZES[sizeAt], points: [[x, y, p, Math.round(t)]], seed: tool === 'brush' ? Math.floor(Math.random() * 2 ** 31) : undefined };
		ready();
		segment(live, 0);
	}

	function extend(x: number, y: number, p: number, t: number) {
		if (!live) return;
		x = (x - width / 2 - panX) / zoom;
		y = (y - height / 2 - panY) / zoom;
		const last = live.points[live.points.length - 1];
		// too close to the last point: nothing new
		if (Math.hypot(x - last[0], y - last[1]) * zoom < 0.8) return;
		live.points.push([x, y, p, Math.round(t)]);
		ready();
		// the piece before the new point can be drawn now that the next one is known
		segment(live, live.points.length - 2);
	}

	function end() {
		if (!live) return;
		const done = live;
		live = null;
		strokes = [...strokes, done];
		undone = [];
		// the brush's end thins out: drawn again with it
		if (done.tool === 'brush') redraw();
		else if (done.points.length > 1) {
			ready();
			segment(done, done.points.length - 1);
		}
	}

	function undo() {
		if (!strokes.length) return;
		undone = [...undone, strokes[strokes.length - 1]];
		strokes = strokes.slice(0, -1);
		redraw();
	}

	function redo() {
		if (!undone.length) return;
		strokes = [...strokes, undone[undone.length - 1]];
		undone = undone.slice(0, -1);
		redraw();
	}

	/** the paper cleared; ⇧⌘Z brings it back */
	function clear() {
		if (!strokes.length) return;
		undone = [...strokes].reverse();
		strokes = [];
		redraw();
		showToast('⇧⌘Z');
	}

	async function done() {
		if (padOn) await setPad(false);
		end();
		ondone(strokes);
	}

	// ── the mouse, the trackpad pressed ──

	/** Force Touch: 1 when the trackpad clicks, up to 3 pressed through (WebKit's webkitForce) */
	let force = 1;
	const pressure = () => Math.min(1.8, Math.max(0.5, 0.6 + (force - 1) * 0.6));

	function pointerdown(e: PointerEvent) {
		if (padOn || e.button !== 0) return;
		canvas?.setPointerCapture(e.pointerId);
		force = (e as unknown as { webkitForce?: number }).webkitForce ?? 1;
		begin(e.clientX, e.clientY, e.pointerType === 'pen' ? e.pressure * 2 : pressure(), e.timeStamp);
	}

	function pointermove(e: PointerEvent) {
		if (!live || padOn) return;
		for (const ev of e.getCoalescedEvents?.() ?? [e]) {
			extend(ev.clientX, ev.clientY, e.pointerType === 'pen' ? ev.pressure * 2 : pressure(), ev.timeStamp);
		}
	}

	function pointerup() {
		if (!padOn) end();
	}

	// ── PAD: the trackpad as a tablet ──

	let padOn = $state(false);
	/** where the trackpad lands on the paper: its shape (a MacBook's, 1.6 : 1), as big as fits */
	let area = $derived.by(() => {
		const small = width < 760 || height < 560;
		const margin = small ? 28 : width * 0.0625 + 60;
		const top = small ? 28 : height * 0.0625 + 40;
		const w = width - 2 * margin, h = height - 2 * top;
		const fw = Math.max(40, Math.min(w, h * 1.6)), fh = fw / 1.6;
		return { x: (width - fw) / 2, y: (height - fh) / 2, w: fw, h: fh };
	});
	/** the one contact drawing (others, a palm, are let be) */
	let drawing: number | null = null;
	/** where the stylus is, touching or near: a ring */
	let hover: { x: number; y: number; down: boolean } | null = $state(null);

	async function setPad(on: boolean) {
		if (on === padOn || !desktop) return;
		if (on) {
			const ok = await invoke<boolean>('pad_start').catch(() => false);
			if (!ok) return showToast('NO PAD');
			padOn = true;
			showToast('PAD');
		} else {
			padOn = false;
			end();
			drawing = null;
			hover = null;
			await invoke('pad_stop').catch(() => {});
		}
	}

	function padFrame(contacts: Contact[]) {
		if (!padOn || !document.hasFocus()) return;
		const c = contacts.find((c) => c.id === drawing) ?? (drawing === null ? contacts[0] : undefined);
		if (!c) {
			end();
			drawing = null;
			hover = null;
			return;
		}
		const x = area.x + c.x * area.w;
		const y = area.y + c.y * area.h;
		hover = { x, y, down: c.down };
		// a light touch thin, a firmer (wider) one heavier
		const p = Math.min(1.8, Math.max(0.45, c.size / 0.9));
		if (c.down) {
			if (drawing !== c.id || !live) {
				drawing = c.id;
				begin(x, y, p, performance.now());
			} else {
				extend(x, y, p, performance.now());
			}
		} else if (drawing === c.id) {
			end();
			drawing = null;
		}
	}

	// ── nearer and further: the drawing grows and shrinks round a point that stays where it is ──

	function zoomAt(factor: number, cx = width / 2, cy = height / 2) {
		const to = Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, zoom * factor));
		if (to === zoom) return;
		const wx = (cx - width / 2 - panX) / zoom;
		const wy = (cy - height / 2 - panY) / zoom;
		zoom = to;
		panX = cx - width / 2 - wx * zoom;
		panY = cy - height / 2 - wy * zoom;
		prepare();
	}

	/** the drawing in the middle of the paper, as large as drawn */
	function centre() {
		zoom = 1;
		const box = bounds(strokes);
		panX = box ? -(box.x + box.w / 2) : 0;
		panY = box ? -(box.y + box.h / 2) : 0;
		prepare();
	}

	const showZoom = () => showToast(`${Math.round(zoom * 100)}%`);

	/** pinch (the wheel with ctrl, as WebKit gives it) grows and shrinks; two fingers or the wheel move the paper */
	function wheel(e: WheelEvent) {
		if (padOn) return;
		e.preventDefault();
		if (e.ctrlKey) {
			if (pinching) return;
			zoomAt(Math.exp(-e.deltaY * 0.01), e.clientX, e.clientY);
			showZoom();
		} else {
			panX -= e.deltaX;
			panY -= e.deltaY;
			prepare();
		}
	}

	let pinching = false;
	let pinchFrom = 1;
	function gesture(e: Event) {
		if (padOn) return;
		const g = e as unknown as { scale: number; clientX: number; clientY: number; type: string };
		e.preventDefault();
		if (g.type === 'gesturestart') {
			pinching = true;
			pinchFrom = zoom;
		} else if (g.type === 'gesturechange') {
			zoomAt((pinchFrom * g.scale) / zoom, g.clientX, g.clientY);
			showZoom();
		} else {
			pinching = false;
		}
	}

	// ── keys: the board's alone while it is open (the note under it hears none) ──

	function keydown(e: KeyboardEvent) {
		const mod = e.metaKey || e.ctrlKey;
		// the window's own (⌘W, ⌘N, ⌘Q) are let through
		if (e.metaKey && ['KeyW', 'KeyN', 'KeyQ', 'KeyH', 'KeyM'].includes(e.code)) return;
		e.stopImmediatePropagation();
		if (mod && e.code === 'KeyZ') {
			e.shiftKey ? redo() : undo();
		} else if (e.ctrlKey && e.code === 'KeyY') {
			redo();
		} else if (mod && (e.key === '=' || e.key === '+' || e.key === '-' || e.key === '0')) {
			if (e.key === '0') centre();
			else zoomAt(e.key === '-' ? 1 / 1.25 : 1.25);
			showZoom();
		} else if ((mod && e.key === 'Enter') || (mod && e.code === 'KeyS')) {
			done();
		} else if (mod) {
			return;
		} else if (e.code === 'KeyB' || e.code === 'KeyP') {
			tool = 'pen';
		} else if (e.code === 'KeyK') {
			tool = 'brush';
		} else if (e.code === 'KeyE') {
			tool = 'rub';
		} else if (e.code === 'KeyT') {
			setPad(!padOn);
		} else if (e.key === 'Escape') {
			if (padOn) setPad(false);
			else done();
		} else if (e.key === '[' || e.key === ']') {
			sizeAt = Math.min(SIZES.length - 1, Math.max(0, sizeAt + (e.key === ']' ? 1 : -1)));
		} else if (/^[1-4]$/.test(e.key)) {
			sizeAt = Number(e.key) - 1;
		} else if (e.key === 'Backspace' || e.key === 'Delete') {
			clear();
		} else {
			return;
		}
		e.preventDefault();
	}

	onMount(() => {
		(document.activeElement as HTMLElement | null)?.blur?.();
		// the note under it out of sight while it is drawn on (its own glass shows through otherwise)
		document.documentElement.classList.add('drawing-board');
		centre();
		addEventListener('keydown', keydown, true);
		addEventListener('wheel', wheel, { passive: false });
		addEventListener('gesturestart', gesture);
		addEventListener('gesturechange', gesture);
		addEventListener('gestureend', gesture);
		const forceChanged = (e: Event) => (force = (e as unknown as { webkitForce?: number }).webkitForce ?? 1);
		addEventListener('webkitmouseforcechanged', forceChanged);
		const recolor = () => redraw();
		addEventListener('themechange', recolor);
		// PAD only while this window is the one in use: elsewhere the trackpad is the pointer again
		const blur = () => setPad(false);
		addEventListener('blur', blur);
		const unlisten = desktop ? listen<Contact[]>('pad', (e) => padFrame(e.payload)) : null;
		return () => {
			removeEventListener('keydown', keydown, true);
			removeEventListener('wheel', wheel);
			removeEventListener('gesturestart', gesture);
			removeEventListener('gesturechange', gesture);
			removeEventListener('gestureend', gesture);
			removeEventListener('webkitmouseforcechanged', forceChanged);
			removeEventListener('themechange', recolor);
			removeEventListener('blur', blur);
			unlisten?.then((f) => f());
			if (padOn) invoke('pad_stop').catch(() => {});
			document.documentElement.classList.remove('drawing-board');
		};
	});

	// the paper's size: the canvas drawn again at it
	$effect(() => {
		width;
		height;
		tick().then(prepare);
	});
</script>

<svelte:window bind:innerWidth={width} bind:innerHeight={height} />

<div class="board fade-in">
	<canvas
		bind:this={canvas}
		class="paper"
		class:pad={padOn}
		class:rub={tool === 'rub'}
		style="width: {width}px; height: {height}px;"
		onpointerdown={pointerdown}
		onpointermove={pointermove}
		onpointerup={pointerup}
		onpointercancel={pointerup}
	></canvas>

	{#if padOn}
		<!-- where the trackpad lands on the paper -->
		<div class="pad-area" style="left: {area.x}px; top: {area.y}px; width: {area.w}px; height: {area.h}px;"></div>
		{#if hover}
			<div
				class="nib"
				class:down={hover.down}
				class:rub={tool === 'rub'}
				style="left: {hover.x}px; top: {hover.y}px; --d: {Math.max(6, SIZES[sizeAt] * (tool === 'rub' ? 4 : 1) + 4)}px;"
			></div>
		{/if}
	{/if}

	<!-- the tools, as ReNote's side buttons -->
	<button class="side switch at-pen" class:ink-mark-v={tool === 'pen'} onclick={() => (tool = 'pen')} title="Pen (B)">{t('PEN')}</button>
	<button class="side switch at-brush" class:ink-mark-v={tool === 'brush'} onclick={() => (tool = 'brush')} title="Brush, for kanji (K)">{t('BRUSH')}</button>
	<button class="side plain at-undo" onclick={undo} disabled={!strokes.length} title="Undo (⌘Z)">{t('UNDO')}</button>
	{#if desktop}
		<button class="side switch at-pad" class:ink-mark-v={padOn} onclick={() => setPad(!padOn)} title="The trackpad as a tablet (T)">{t('PAD')}</button>
	{/if}
	<button class="side plain at-clear" onclick={clear} disabled={!strokes.length} title="Clear the paper (⌫)">{t('CLEAR')}</button>
	<button class="side plain at-done" onclick={done} title="Back to the note (Esc)">{t('DONE')}</button>

	<!-- the line's weight, and the rubber -->
	<div class="sizes">
		{#each SIZES as s, i}
			<button class="size" onclick={() => (sizeAt = i)} title="Line {i + 1}">
				<span class="size-dot" class:on={i === sizeAt} style="--d: {Math.max(3, s * 1.6)}px;"></span>
			</button>
		{/each}
		<button class="rub-word" onclick={() => (tool = tool === 'rub' ? 'pen' : 'rub')} title="Rubber (E)">
			<span class:ink-mark={tool === 'rub'}>{t('RUB')}</span>
		</button>
	</div>

	{#if toast}
		<div class="toast"><span>{toast}</span></div>
	{/if}
</div>

<style>
	/* over the note, all of it: the paper (or the glass, darker, so the note under it doesn't show) */
	:global(html.drawing-board body) {
		visibility: hidden;
	}

	.board {
		position: fixed;
		inset: 0;
		z-index: 200;
		visibility: visible;
		background: var(--bg) url('/noise.svg') repeat;
	}

	:global(html.glass) .board {
		background: transparent;
	}

	.paper {
		position: absolute;
		inset: 0;
		touch-action: none;
		cursor: crosshair;
	}

	.paper.rub { cursor: cell; }
	/* PAD: the pointer stays still, out of sight */
	.paper.pad { cursor: none; }

	.pad-area {
		position: absolute;
		border: 2px dashed var(--line);
		border-radius: 18px;
		opacity: 0.22;
		pointer-events: none;
	}

	.nib {
		position: absolute;
		width: var(--d);
		height: var(--d);
		transform: translate(-50%, -50%);
		border-radius: 50%;
		border: 1.5px solid var(--text);
		opacity: 0.55;
		pointer-events: none;
	}

	.nib.down { background: var(--text); opacity: 0.35; }
	.nib.rub { border-style: dashed; }

	/* ── the side buttons, as the other Re apps' ── */
	.side {
		position: absolute;
		z-index: 10;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 20px;
		line-height: 32px;
		color: var(--text);
		writing-mode: vertical-rl;
		text-orientation: upright;
		letter-spacing: 0.6em;
		background: transparent;
		border: none;
		padding: 0;
		cursor: pointer;
		opacity: 0.75;
		transition: opacity 200ms ease;
	}

	.side:hover { opacity: 1; }
	.side:disabled { opacity: 0.3; pointer-events: none; }

	.side.switch {
		width: 42px;
		padding: 0.55em 0 0;
	}

	.side.switch.ink-mark-v {
		opacity: 1;
		background:
			url('/ink/brush-top.svg') center top / 100% auto no-repeat,
			url('/ink/brush-bottom.svg') center bottom / 100% auto no-repeat,
			url('/ink/brush-mid-v.svg') center 0.65em / 100% calc(100% - 1.3em) no-repeat;
		color: var(--bg);
	}

	:global(:root[data-theme='dark']) .side.switch.ink-mark-v {
		background:
			url('/ink/dark/brush-top.svg') center top / 100% auto no-repeat,
			url('/ink/dark/brush-bottom.svg') center bottom / 100% auto no-repeat,
			url('/ink/dark/brush-mid-v.svg') center 0.65em / 100% calc(100% - 1.3em) no-repeat;
	}

	/* on glass no brush: a chosen button is framed in white */
	:global(html.glass) .side.switch.ink-mark-v {
		background: none;
		color: var(--text);
		box-shadow: inset 0 0 0 1px var(--text);
	}

	.at-pen { left: calc(6.25% - 28px); top: calc(6.25% + 8px); }
	.at-brush { right: calc(6.25% - 28px); top: calc(6.25% + 8px); }
	.at-undo { left: calc(6.25% - 28px); top: 50%; transform: translateY(-50%); width: 42px; }
	.at-pad { right: calc(6.25% - 28px); top: 50%; transform: translateY(-50%); }
	.at-clear { left: calc(6.25% - 28px); bottom: 6.25%; width: 42px; }
	.at-done { right: calc(6.25% - 28px); bottom: 6.25%; width: 42px; }

	.sizes {
		position: absolute;
		left: 50%;
		bottom: calc(6.25% - 10px);
		transform: translateX(-50%);
		display: flex;
		align-items: center;
		gap: 26px;
		z-index: 10;
	}

	.size {
		width: 28px;
		height: 28px;
		display: grid;
		place-items: center;
		background: transparent;
		border: none;
		padding: 0;
		cursor: pointer;
	}

	.size-dot {
		width: var(--d);
		height: var(--d);
		border-radius: 50%;
		background: var(--text);
		opacity: 0.3;
		transition: opacity 200ms ease, transform 200ms ease;
	}

	.size:hover .size-dot { opacity: 0.6; }
	.size-dot.on { opacity: 1; transform: scale(1.25); }

	.rub-word {
		margin-left: 10px;
		background: transparent;
		border: none;
		padding: 0.25em 0.35em;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 12px;
		letter-spacing: 0.3em;
		color: var(--text);
		opacity: 0.75;
		cursor: pointer;
	}

	.rub-word:hover { opacity: 1; }

	/* a small window: the paper only, the keys still work */
	@media (max-width: 759px), (max-height: 559px) {
		.side,
		.sizes { display: none; }
	}

	.toast {
		position: absolute;
		top: 0;
		left: 50%;
		transform: translateX(-50%);
		padding: 1rem 1.2rem;
		border: 2px solid var(--line);
		border-top: none;
		background: var(--bg) url('/noise.svg') repeat;
		font-family: 'Noto Sans JP', sans-serif;
		font-size: 14px;
		letter-spacing: 0.3em;
		color: var(--text);
		z-index: 20;
	}

	:global(html.glass) .toast {
		background: rgba(0, 0, 0, 0.32);
		border-width: 1px;
	}
</style>
