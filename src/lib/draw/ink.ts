// A drawing in a note: drawn right there, between the words, with a pen (one thin line) and a rubber (⌥).
// It is kept in the note's text as a line of its own, ⟦drawing {"w":…,"h":…,"s":[…]}⟧: how wide the place
// was when drawn (it grows and shrinks with the text, its lines with it), how tall, and its strokes (rounded:
// a tenth of a pixel), so the note stays one text (exported, imported, searched as it is).

export type Tool = 'pen' | 'rub';
/** a point: where, in the drawing's own pixels from its top left */
export type Point = [x: number, y: number];
export interface Stroke {
	tool: Tool;
	points: Point[];
}
export interface Drawing {
	/** its width when drawn, and its height then (its lines are laid out in them) */
	w: number;
	h: number;
	strokes: Stroke[];
}

/** the pen's line, and the rubber's, in the drawing's pixels */
export const PEN = 1.5;
export const RUB = 14;
/** a new drawing's height, and how much it grows when drawn near its bottom */
export const HEIGHT = 220;
export const GROW = 120;

/** a drawing's line in a note's text, with the line's end after it */
export const DRAWING = /⟦drawing (\{.*?\})⟧\n?/g;

/** The theme's ink (app.css): on glass the desk's white. */
export function themeInk(): string {
	return document.documentElement.classList.contains('glass')
		? '#f4f4f4'
		: getComputedStyle(document.documentElement).getPropertyValue('--text').trim() || '#474747';
}

function setup(c: CanvasRenderingContext2D, tool: Tool, color: string) {
	c.globalCompositeOperation = tool === 'rub' ? 'destination-out' : 'source-over';
	c.strokeStyle = color;
	c.fillStyle = color;
	c.lineCap = 'round';
	c.lineJoin = 'round';
	c.lineWidth = tool === 'rub' ? RUB : PEN;
}

/** the piece of `s` around its point `i`: a curve through the middles (drawn as the stroke comes) */
export function segment(c: CanvasRenderingContext2D, s: Stroke, i: number, color = themeInk()) {
	const pts = s.points;
	const p = pts[i];
	if (!p) return;
	setup(c, s.tool, color);
	if (pts.length === 1) {
		c.beginPath();
		c.arc(p[0], p[1], c.lineWidth / 2, 0, Math.PI * 2);
		c.fill();
		return;
	}
	const before = pts[i - 1] ?? p;
	const after = pts[i + 1] ?? p;
	c.beginPath();
	c.moveTo((before[0] + p[0]) / 2, (before[1] + p[1]) / 2);
	c.quadraticCurveTo(p[0], p[1], (after[0] + p[0]) / 2, (after[1] + p[1]) / 2);
	c.stroke();
}

export function drawStroke(c: CanvasRenderingContext2D, s: Stroke, color = themeInk()) {
	for (let i = 0; i < s.points.length; i++) segment(c, s, i, color);
	c.globalCompositeOperation = 'source-over';
}

/** A drawing on its canvas, `width` CSS px wide: its lines as large as that makes them. Its scale. */
export function paint(canvas: HTMLCanvasElement, drawing: Drawing, width: number): number {
	const scale = width > 0 ? width / drawing.w : 1;
	const height = Math.round(drawing.h * scale);
	const dpr = window.devicePixelRatio || 1;
	canvas.style.width = `${width}px`;
	canvas.style.height = `${height}px`;
	canvas.width = Math.max(1, Math.round(width * dpr));
	canvas.height = Math.max(1, Math.round(height * dpr));
	const c = canvas.getContext('2d');
	if (!c) return scale;
	c.setTransform(dpr * scale, 0, 0, dpr * scale, 0, 0);
	const color = themeInk();
	for (const s of drawing.strokes) drawStroke(c, s, color);
	return scale;
}

export function encode(d: Drawing): string {
	const r = (n: number) => Math.round(n * 10) / 10;
	return JSON.stringify({
		w: Math.round(d.w),
		h: Math.round(d.h),
		s: d.strokes.map((st) => ({ ...(st.tool === 'rub' ? { k: 'rub' } : {}), p: st.points.map(([x, y]) => [r(x), r(y)]) })),
	});
}

export function decode(json: string): Drawing {
	try {
		const d = JSON.parse(json);
		const strokes: Stroke[] = (d.s ?? []).map((st: { k?: string; p: number[][] }) => ({
			tool: st.k === 'rub' ? 'rub' : 'pen',
			points: (st.p ?? []).map((p) => [p[0], p[1]] as Point),
		}));
		if (d.w && d.h) return { w: d.w, h: d.h, strokes };
		// drawn before on a page of its own (from its middle): moved to start at its top left
		let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
		for (const s of strokes) for (const [x, y] of s.points) {
			minX = Math.min(minX, x); minY = Math.min(minY, y); maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
		}
		if (minX === Infinity) return { w: 600, h: HEIGHT, strokes: [] };
		const pad = 16;
		for (const s of strokes) s.points = s.points.map(([x, y]) => [x - minX + pad, y - minY + pad]);
		return { w: Math.max(900, maxX - minX + 2 * pad), h: maxY - minY + 2 * pad, strokes };
	} catch {
		return { w: 600, h: HEIGHT, strokes: [] };
	}
}

/** a note's words, without its drawings (for search, counting) */
export const withoutDrawings = (text: string) => text.replace(DRAWING, '');
