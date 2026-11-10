<script lang="ts">
	import { scrollFade } from './scrollFade';

	// Plain-text note editor with highlighter marks.
	// Highlights are stored in the text as ==marked text== so notes stay plain text.
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

	function toHtml(text: string): string {
		return escapeHtml(text).replace(/==([\s\S]+?)==/g, '<mark>$1</mark>');
	}

	function serialize(root: Node, withMarks = true): string {
		let out = '';
		root.childNodes.forEach(node => {
			if (node.nodeType === Node.TEXT_NODE) {
				out += node.textContent;
			} else if (node.nodeName === 'BR') {
				out += '\n';
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
			element.innerHTML = toHtml(value);
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
		element.innerHTML = toHtml(snap.value);
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

	function handleKeydown(e: KeyboardEvent) {
		const mod = e.metaKey || e.ctrlKey;
		if (mod && e.code === 'KeyB') {
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
	onbeforeinput={handleBeforeInput}
	oninput={commit}
	onkeydown={handleKeydown}
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
