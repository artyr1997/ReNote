<script lang="ts">
	import { scrollFade } from './scrollFade';
	import { DRAWING, GROW, HEIGHT, decode, encode, paint, segment, themeInk, type Drawing, type Stroke } from './draw/ink';

	// Plain-text note editor with highlighter marks and drawings.
	// Highlights are stored in the text as ==marked text== so notes stay plain text; a drawing is a line of its
	// own, ⟦drawing {…}⟧ (draw/ink.ts), a place between the words drawn on right there: the pen dragged,
	// the rubber with ⌥; it grows as it is drawn near its bottom. ⌘D makes a new one where the caret is.
	let {
		value = $bindable(''),
		placeholder = '',
		disabled = false,
		class: className = '',
		element = $bindable(),
		oninput,
	}: {
		value?: string;
		placeholder?: string;
		disabled?: boolean;
		class?: string;
		element?: HTMLDivElement;
		oninput?: () => void;
	} = $props();

	const MARK = '==';

	function escapeHtml(text: string): string {
		return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
	}

	function wordsHtml(text: string): string {
		return escapeHtml(text).replace(/==([\s\S]+?)==/g, '<mark>$1</mark>');
	}

	const attribute = (text: string) => escapeHtml(text).replace(/"/g, '&quot;');

	/** a drawing's place marked at its corners with a +, as ReDesk marks the windows' */
	const PLUSES = ['tl', 'tr', 'bl', 'br'].map((at) => `<i class="plus ${at}"></i>`).join('');

	/** the words as they are written, the drawings as drawings */
	function toHtml(text: string): string {
		let out = '';
		let last = 0;
		for (const m of text.matchAll(DRAWING)) {
			out += wordsHtml(text.slice(last, m.index));
			out += `<figure class="drawing" contenteditable="false" data-drawing="${attribute(m[1])}"><canvas></canvas>${PLUSES}</figure>`;
			last = m.index! + m[0].length;
		}
		return out + wordsHtml(text.slice(last));
	}

	/** the drawings drawn, as wide as the text (their lines with it) */
	function paintDrawings() {
		element?.querySelectorAll<HTMLElement>('figure.drawing').forEach((figure) => {
			const canvas = figure.querySelector('canvas');
			if (canvas) paint(canvas, decode(figure.dataset.drawing ?? ''), figure.clientWidth);
		});
	}

	function render(text: string) {
		if (!element) return;
		element.innerHTML = toHtml(text);
		paintDrawings();
	}

	function serialize(root: Node, withMarks = true): string {
		let out = '';
		root.childNodes.forEach(node => {
			if (node.nodeType === Node.TEXT_NODE) {
				out += node.textContent;
			} else if (node.nodeName === 'BR') {
				out += '\n';
			} else if (node.nodeName === 'FIGURE' && (node as HTMLElement).dataset.drawing !== undefined) {
				// a drawing: a line of its own
				if (withMarks) {
					if (out && !out.endsWith('\n')) out += '\n';
					out += `⟦drawing ${(node as HTMLElement).dataset.drawing}⟧\n`;
				}
			} else if (node.nodeName === 'MARK') {
				const inner = serialize(node, withMarks);
				if (inner) out += withMarks ? MARK + inner + MARK : inner;
			} else if (node.nodeName === 'DIV' || node.nodeName === 'P') {
				if (out && !out.endsWith('\n')) out += '\n';
				out += serialize(node, withMarks);
			} else {
				out += serialize(node, withMarks);
			}
		});
		return out;
	}

	// Re-render only when the value changes from outside (e.g. another note loaded),
	// so typing doesn't reset the caret.
	$effect(() => {
		if (element && serialize(element) !== value) {
			render(value);
			// a different note was loaded — its history starts fresh
			undoStack = [];
			redoStack = [];
		}
	});

	// ── Undo / redo ──
	// Highlights edit the DOM directly, which the browser's own undo can't see,
	// so the editor keeps its own history of text + selection snapshots.
	type Snapshot = { value: string; start: number; end: number };
	let undoStack: Snapshot[] = [];
	let redoStack: Snapshot[] = [];
	let lastTypingAt = 0;
	const TYPING_GROUP_MS = 800;
	const HISTORY_LIMIT = 200;

	// selection as character offsets in the visible text (marks don't count)
	function getOffsets(): [number, number] {
		const selection = getSelection();
		if (!element || !selection || selection.rangeCount === 0) return [0, 0];
		const range = selection.getRangeAt(0);
		if (!element.contains(range.startContainer)) return [0, 0];
		const before = document.createRange();
		before.selectNodeContents(element);
		before.setEnd(range.startContainer, range.startOffset);
		const start = before.toString().length;
		return [start, start + range.toString().length];
	}

	function setOffsets(start: number, end: number) {
		if (!element) return;
		const range = document.createRange();
		const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
		let pos = 0;
		let startSet = false;
		range.setStart(element, 0);
		range.setEnd(element, 0);
		for (let node = walker.nextNode(); node; node = walker.nextNode()) {
			const len = node.textContent?.length ?? 0;
			if (!startSet && start <= pos + len) {
				range.setStart(node, start - pos);
				startSet = true;
			}
			if (end <= pos + len) {
				range.setEnd(node, end - pos);
				break;
			}
			pos += len;
		}
		const selection = getSelection();
		selection?.removeAllRanges();
		selection?.addRange(range);
	}

	function snapshot(): Snapshot {
		const [start, end] = getOffsets();
		return { value, start, end };
	}

	function pushHistory() {
		undoStack.push(snapshot());
		if (undoStack.length > HISTORY_LIMIT) undoStack.shift();
		redoStack = [];
	}

	function restore(snap: Snapshot) {
		if (!element) return;
		render(snap.value);
		value = snap.value;
		setOffsets(snap.start, snap.end);
		lastTypingAt = 0;
		oninput?.();
	}

	function undo() {
		const snap = undoStack.pop();
		if (!snap) return;
		redoStack.push(snapshot());
		restore(snap);
	}

	function redo() {
		const snap = redoStack.pop();
		if (!snap) return;
		undoStack.push(snapshot());
		restore(snap);
	}

	function handleBeforeInput(e: InputEvent) {
		if (e.inputType === 'historyUndo') {
			e.preventDefault();
			undo();
			return;
		}
		if (e.inputType === 'historyRedo') {
			e.preventDefault();
			redo();
			return;
		}
		// one history step per burst of typing
		const now = Date.now();
		if (now - lastTypingAt > TYPING_GROUP_MS) pushHistory();
		lastTypingAt = now;
	}

	// A highlight with text right next to it on the same line gets a narrower
	// stroke on that side (.tight-left / .tight-right), so the ink doesn't cover
	// the neighbouring letters. At a line start/end the full stroke stays.
	function hasNeighbour(node: Node | null, side: 'left' | 'right'): boolean {
		if (!node || node.nodeName === 'BR') return false;
		if (node.nodeType !== Node.TEXT_NODE) return true;
		const text = node.textContent ?? '';
		if (!text) return hasNeighbour(side === 'left' ? node.previousSibling : node.nextSibling, side);
		return side === 'left' ? !text.endsWith('\n') : !text.startsWith('\n');
	}

	function markSides(node: HTMLElement) {
		const update = () => {
			node.querySelectorAll('mark').forEach(mark => {
				mark.classList.toggle('tight-left', hasNeighbour(mark.previousSibling, 'left'));
				mark.classList.toggle('tight-right', hasNeighbour(mark.nextSibling, 'right'));
			});
		};
		// class changes are attribute mutations, which this observer ignores → no loop
		const observer = new MutationObserver(update);
		observer.observe(node, { childList: true, subtree: true, characterData: true });
		update();
		return { destroy: () => observer.disconnect() };
	}

	function commit() {
		if (!element) return;
		value = serialize(element);
		oninput?.();
	}

	function closestMark(node: Node | null): HTMLElement | null {
		while (node && node !== element) {
			if (node.nodeName === 'MARK') return node as HTMLElement;
			node = node.parentNode;
		}
		return null;
	}

	function unwrap(mark: HTMLElement) {
		mark.replaceWith(...Array.from(mark.childNodes));
	}

	function toggleMark() {
		const selection = getSelection();
		if (!element || !selection || selection.rangeCount === 0) return;
		const range = selection.getRangeAt(0);
		if (!element.contains(range.commonAncestorContainer)) return;

		pushHistory();
		lastTypingAt = 0;

		const startMark = closestMark(range.startContainer);
		const endMark = closestMark(range.endContainer);

		if (startMark && (range.collapsed || startMark === endMark)) {
			// caret or selection inside a highlight → remove that highlight
			unwrap(startMark);
		} else if (!range.collapsed) {
			const mark = document.createElement('mark');
			mark.textContent = serialize(range.extractContents(), false);
			range.insertNode(mark);
			selection.selectAllChildren(mark);
		} else {
			undoStack.pop();
			return;
		}

		element.querySelectorAll('mark').forEach(m => {
			if (!m.textContent) m.remove();
		});
		element.normalize();
		commit();
	}

	// ── drawings: drawn on where they are ──

	/** a new, empty drawing where the caret is (or at the end), as wide as the text */
	export function draw() {
		if (disabled || !element) return;
		pushHistory();
		lastTypingAt = 0;
		const figure = document.createElement('figure');
		figure.className = 'drawing';
		figure.contentEditable = 'false';
		const selection = getSelection();
		const range = selection?.rangeCount ? selection.getRangeAt(0) : null;
		if (range && element.contains(range.startContainer)) {
			range.collapse(true);
			range.insertNode(figure);
		} else {
			element.appendChild(figure);
		}
		// as wide as the text is, where it went
		figure.dataset.drawing = encode({ w: Math.max(200, figure.clientWidth || element.clientWidth), h: HEIGHT, strokes: [] });
		commit();
		// written again from the text: each drawing a line of its own
		render(value);
	}

	/** the stroke being drawn, on which drawing */
	let stroke: { figure: HTMLElement; canvas: HTMLCanvasElement; drawing: Drawing; scale: number; live: Stroke } | null = null;

	function place(e: PointerEvent, canvas: HTMLCanvasElement, scale: number): [number, number] {
		const box = canvas.getBoundingClientRect();
		return [(e.clientX - box.left) / scale, (e.clientY - box.top) / scale];
	}

	function context(canvas: HTMLCanvasElement, scale: number) {
		const c = canvas.getContext('2d');
		const dpr = window.devicePixelRatio || 1;
		c?.setTransform(dpr * scale, 0, 0, dpr * scale, 0, 0);
		return c;
	}

	function pointerDown(e: PointerEvent) {
		if (disabled || e.button !== 0) return;
		const canvas = e.target as HTMLElement;
		if (canvas.nodeName !== 'CANVAS') return;
		const figure = canvas.closest('figure.drawing') as HTMLElement | null;
		if (!figure || !element?.contains(figure)) return;
		e.preventDefault();
		canvas.setPointerCapture(e.pointerId);
		const drawing = decode(figure.dataset.drawing ?? '');
		const scale = figure.clientWidth / drawing.w;
		// the drawing as it was, for ⌘Z
		pushHistory();
		lastTypingAt = 0;
		const live: Stroke = { tool: e.altKey ? 'rub' : 'pen', points: [place(e, canvas as HTMLCanvasElement, scale)] };
		stroke = { figure, canvas: canvas as HTMLCanvasElement, drawing, scale, live };
		const c = context(stroke.canvas, scale);
		if (c) segment(c, live, 0, themeInk());
	}

	function pointerMove(e: PointerEvent) {
		if (!stroke) return;
		const { canvas, scale, live } = stroke;
		const c = context(canvas, scale);
		const coalesced = e.getCoalescedEvents?.() ?? [];
		for (const ev of coalesced.length ? coalesced : [e]) {
			const p = place(ev, canvas, scale);
			const last = live.points[live.points.length - 1];
			if (Math.hypot(p[0] - last[0], p[1] - last[1]) * scale < 0.8) continue;
			live.points.push(p);
			// the piece before the new point can be drawn now that the next one is known
			if (c) segment(c, live, live.points.length - 2, themeInk());
		}
	}

	function pointerUp() {
		const s = stroke;
		stroke = null;
		if (!s) return;
		s.drawing.strokes.push(s.live);
		// drawn near its bottom: more room under it
		const lowest = Math.max(...s.live.points.map((p) => p[1]));
		if (s.live.tool === 'pen' && lowest > s.drawing.h - 40) s.drawing.h = Math.ceil(lowest + GROW);
		s.figure.dataset.drawing = encode(s.drawing);
		paint(s.canvas, s.drawing, s.figure.clientWidth);
		commit();
	}

		// drawn again as wide as the text is now, and in the theme's ink
	function repaints(node: HTMLElement) {
		let width = node.clientWidth;
		const resized = new ResizeObserver(() => {
			if (node.clientWidth === width) return;
			width = node.clientWidth;
			paintDrawings();
		});
		resized.observe(node);
		addEventListener('themechange', paintDrawings);
		return {
			destroy() {
				resized.disconnect();
				removeEventListener('themechange', paintDrawings);
			},
		};
	}

	function handleKeydown(e: KeyboardEvent) {
		const mod = e.metaKey || e.ctrlKey;
		if (mod && e.code === 'KeyD') {
			e.preventDefault();
			draw();
		} else if (mod && e.code === 'KeyB') {
			e.preventDefault();
			toggleMark();
		} else if (mod && e.code === 'KeyZ') {
			e.preventDefault();
			if (e.shiftKey) redo();
			else undo();
		} else if (e.ctrlKey && !e.metaKey && e.code === 'KeyY') {
			e.preventDefault();
			redo();
		}
	}
</script>

<div
	bind:this={element}
	class="note-editor {className}"
	class:disabled
	contenteditable={disabled ? 'false' : 'plaintext-only'}
	role="textbox"
	aria-multiline="true"
	tabindex={disabled ? -1 : 0}
	data-placeholder={placeholder}
	data-empty={value === '' ? '' : undefined}
	use:scrollFade
	use:markSides
	use:repaints
	onbeforeinput={handleBeforeInput}
	oninput={commit}
	onkeydown={handleKeydown}
	onpointerdown={pointerDown}
	onpointermove={pointerMove}
	onpointerup={pointerUp}
	onpointercancel={pointerUp}
></div>

<style>
	.note-editor {
		white-space: pre-wrap;
		overflow-wrap: break-word;
		overflow-y: auto;
		outline: none;
		cursor: text;
	}

	.note-editor[data-empty]::before {
		content: attr(data-placeholder);
		color: var(--line);
		opacity: 0.25;
		font-style: italic;
		pointer-events: none;
	}

	.note-editor[data-empty]:focus::before {
		opacity: 0;
	}

	.note-editor.disabled {
		cursor: default;
		opacity: 0.3;
	}

	/* a drawing between the words: a line of its own, as wide as the text, drawn on right there. No frame:
	   its corners are marked with a thin +, as ReDesk marks the windows' (clearer while the pointer is over it) */
	.note-editor :global(figure.drawing) {
		position: relative;
		display: block;
		margin: 0.9em 0;
		user-select: none;
	}

	.note-editor :global(figure.drawing .plus) {
		position: absolute;
		width: 15px;
		height: 15px;
		transform: translate(-50%, -50%);
		background:
			linear-gradient(var(--line), var(--line)) center / 100% 1px no-repeat,
			linear-gradient(var(--line), var(--line)) center / 1px 100% no-repeat;
		opacity: 0.45;
		pointer-events: none;
		transition: opacity 200ms ease;
	}

	.note-editor :global(figure.drawing .plus.tl) { left: 0; top: 0; }
	.note-editor :global(figure.drawing .plus.tr) { left: 100%; top: 0; }
	.note-editor :global(figure.drawing .plus.bl) { left: 0; top: 100%; }
	.note-editor :global(figure.drawing .plus.br) { left: 100%; top: 100%; }

	.note-editor:not(.disabled) :global(figure.drawing:hover .plus) {
		opacity: 0.9;
	}

	.note-editor :global(figure.drawing canvas) {
		display: block;
		touch-action: none;
		cursor: crosshair;
	}

	.note-editor.disabled :global(figure.drawing canvas) {
		cursor: default;
	}

	/* highlight look lives in app.css (.ink-mark); here only the narrower side
	   used when a highlight sits right next to other text */
	.note-editor :global(mark.tight-left) {
		padding-left: 0.18em;
		margin-left: -0.18em;
	}

	.note-editor :global(mark.tight-right) {
		padding-right: 0.18em;
		margin-right: -0.18em;
	}
</style>
