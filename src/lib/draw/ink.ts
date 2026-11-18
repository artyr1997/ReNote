// The ink of ReNote's drawings: the pen, the rubber, and the brush as an ink brush writes (ReDraw's, moved
// here). It is many hairs, each holding its own ink, more in the middle than at the edges; the middle writes
// a solid body, the hairs its ragged edges. Ink is spent as the brush goes (faster when it moves fast): the
// body narrows and the hairs run dry one by one, leaving the white streaks of a brush going dry (飛白). Wide
// when slow, thin when fast, as hard as pressed; it swells in and thins out at its end. Each stroke has its
// own seed, so it is drawn the same again.
//
// Before drawing, `use` says on what (a 2D context, its transform set), how near (the zoom: finer steps
// nearer), in what ink, and which stroke is still being drawn (its end not yet known).

export type Tool = 'pen' | 'brush' | 'rub';
/** a point: where (CSS px from the drawing's middle), how hard (1 is plain), and when (ms: the brush's speed) */
export type Point = [x: number, y: number, p: number, t?: number];
export interface Stroke {
	tool: Tool;
	size: number;
	points: Point[];
	/** the brush's hairs come from it */
	seed?: number;
}

export const SIZES = [1.5, 3, 6, 12];

let ctx: CanvasRenderingContext2D | null = null;
let zoom = 1;
let color = '#474747';
let live: Stroke | null = null;
const ink = () => color;

export function use(context: CanvasRenderingContext2D | null, options: { zoom?: number; color: string; live?: Stroke | null }) {
	ctx = context;
	zoom = options.zoom ?? 1;
	color = options.color;
	live = options.live ?? null;
}

/** The theme's ink (app.css): on glass the desk's white, solid (the brush lays its ink over itself). */
export function themeInk(): string {
	return document.documentElement.classList.contains('glass')
		? '#f4f4f4'
		: getComputedStyle(document.documentElement).getPropertyValue('--text').trim() || '#474747';
}

/** Where a drawing's lines reach (with their width), from its middle. */
export function bounds(strokes: Stroke[]): { x: number; y: number; w: number; h: number } | null {
	let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
	for (const s of strokes) {
		if (s.tool === 'rub') continue;
		const pad = s.size * (s.tool === 'brush' ? 5 : 1);
		for (const [x, y] of s.points) {
			minX = Math.min(minX, x - pad);
			minY = Math.min(minY, y - pad);
			maxX = Math.max(maxX, x + pad);
			maxY = Math.max(maxY, y + pad);
		}
	}
	return minX === Infinity ? null : { x: minX, y: minY, w: maxX - minX, h: maxY - minY };
}

/** A drawing on a canvas of `width` CSS px: as large as it is drawn (never larger), smaller if it doesn't fit;
 * the canvas as tall as the drawing then is. */
export function paint(canvas: HTMLCanvasElement, strokes: Stroke[], width: number, color = themeInk()) {
	const box = bounds(strokes);
	const dpr = window.devicePixelRatio || 1;
	if (!box || width <= 0) {
		canvas.width = 0;
		canvas.height = 0;
		canvas.style.height = '0px';
		return;
	}
	const scale = Math.min(1, width / box.w);
	const height = Math.ceil(box.h * scale);
	canvas.style.width = `${width}px`;
	canvas.style.height = `${height}px`;
	canvas.width = Math.round(width * dpr);
	canvas.height = Math.round(height * dpr);
	const c = canvas.getContext('2d');
	if (!c) return;
	// the drawing's left edge at the left, as the text is
	c.setTransform(dpr * scale, 0, 0, dpr * scale, -box.x * dpr * scale, -box.y * dpr * scale);
	use(c, { zoom: scale, color });
	for (const s of strokes) drawStroke(s);
	c.globalCompositeOperation = 'source-over';
	use(null, { color });
}

const HAIRS = 40;
interface Hair {
	/** where across the brush, −0.5 … 0.5 */
	o: number;
	/** ink at the start, and how fast it goes */
	ink: number;
	rate: number;
	alpha: number;
	/** where its own unevenness starts */
	phase: number;
	/** how thick */
	w: number;
}

function random(seed: number) {
	let a = seed | 0;
	return () => {
		a = (a + 0x6d2b79f5) | 0;
		let t = Math.imul(a ^ (a >>> 15), 1 | a);
		t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

/** smooth unevenness along a hair, 0 … 1 */
function wave(x: number): number {
	const k = Math.floor(x);
	const f = x - k;
	const h = (n: number) => {
		const v = Math.sin(n * 127.1 + 311.7) * 43758.5453;
		return v - Math.floor(v);
	};
	const e = f * f * (3 - 2 * f);
	return h(k) * (1 - e) + h(k + 1) * e;
}

const hairsOf = new WeakMap<Stroke, Hair[]>();
function hairs(s: Stroke): Hair[] {
	let list = hairsOf.get(s);
	if (!list) {
		const r = random(s.seed ?? 1);
		list = Array.from({ length: HAIRS }, (_, k) => {
			const o = (k / (HAIRS - 1) - 0.5) * (0.92 + r() * 0.16);
			return {
				o,
				// the edges hold less: they go dry first
				ink: 1 - Math.abs(o) * 1.05 + r() * 0.3,
				rate: 0.6 + r() * 0.9,
				alpha: 0.6 + r() * 0.4,
				phase: r() * 1000,
				w: 0.7 + r() * 0.9,
			};
		});
		hairsOf.set(s, list);
	}
	return list;
}

/** A point of the brush's path, a pixel and a half from the next. */
interface Sample {
	x: number;
	y: number;
	/** the brush's width there */
	w: number;
	/** ink spent so far */
	used: number;
	/** the way come so far */
	along: number;
	/** which way across the brush is */
	nx: number;
	ny: number;
}

/** A Catmull–Rom curve through b and c (a and d around them), at u. */
function curve(a: Point, b: Point, c: Point, d: Point, u: number): [number, number] {
	const u2 = u * u;
	const u3 = u2 * u;
	const at = (k: 0 | 1) =>
		0.5 * (2 * b[k] + (c[k] - a[k]) * u + (2 * a[k] - 5 * b[k] + 4 * c[k] - d[k]) * u2 + (3 * b[k] - a[k] - 3 * c[k] + d[k]) * u3);
	return [at(0), at(1)];
}

/**
 * The brush's path: a smooth curve through the points, cut into steps a pixel and a half long, each with
 * the brush's width (wide when slow, thin when fast, as hard as pressed, changing softly), the ink spent
 * (faster when fast) and which way across it is. `starts[k]`: where point k's piece begins.
 */
function brushPath(s: Stroke, done: boolean): { samples: Sample[]; starts: number[] } {
	const pts = s.points;
	const n = pts.length;
	// how fast, at each point, smoothed
	const speeds: number[] = [];
	let v = 0;
	for (let k = 0; k < n; k++) {
		if (k === 0) {
			speeds.push(0);
			continue;
		}
		const a = pts[k - 1];
		const b = pts[k];
		const dt = a[3] !== undefined && b[3] !== undefined ? Math.max(4, b[3] - a[3]) : 16;
		const now = Math.hypot(b[0] - a[0], b[1] - a[1]) / dt;
		v = k === 1 ? now : v * 0.6 + now * 0.4;
		speeds.push(v);
	}
	const targets = pts.map((p, k) => s.size * 7 * p[2] * Math.min(1.15, Math.max(0.25, 1.15 - speeds[k] * 0.45)));

	// along the curve
	const raw: [number, number, number, number][] = [[pts[0][0], pts[0][1], targets[0], 0]];
	const starts = [0];
	for (let k = 1; k < n; k++) {
		const a = pts[Math.max(0, k - 2)];
		const b = pts[k - 1];
		const c = pts[k];
		const d = pts[Math.min(n - 1, k + 1)];
		const steps = Math.max(1, Math.ceil(Math.hypot(c[0] - b[0], c[1] - b[1]) / Math.min(1.5, 1.5 / zoom)));  // nearer: finer steps, as smooth on the screen
		starts.push(raw.length);
		for (let j = 1; j <= steps; j++) {
			const u = j / steps;
			const [x, y] = curve(a, b, c, d, u);
			raw.push([x, y, targets[k - 1] + (targets[k] - targets[k - 1]) * u, speeds[k - 1] + (speeds[k] - speeds[k - 1]) * u]);
		}
	}
	starts.push(raw.length);

	const samples: Sample[] = [];
	let along = 0;
	let used = 0;
	// it sets down narrower and opens over its first few pixels (not a blob where it is set down)
	let w = raw[0][2] * 0.7;
	for (let i = 0; i < raw.length; i++) {
		const [x, y, target, speed] = raw[i];
		const ds = i ? Math.hypot(x - raw[i - 1][0], y - raw[i - 1][1]) : 0;
		along += ds;
		used += (ds * (1 + speed)) / (s.size * 185 + 200);
		w = w * 0.9 + target * 0.1;
		samples.push({ x, y, w: w * Math.min(1, 0.55 + (0.45 * along) / (s.size * 8)), used, along, nx: 0, ny: 1 });
	}
	// lifted while moving fast, it sweeps out to a point (払い); stopped, it ends round (止め)
	if (done && speeds[n - 1] > 0.5) {
		const tail = Math.min(along * 0.45, s.size * 30);
		for (const sm of samples) {
			const left = along - sm.along;
			if (left < tail) sm.w *= 0.1 + 0.9 * (left / tail);
		}
	} else if (done) {
		// stopped: the brush lifts straight up, a little narrower at the very end, not swollen
		const tail = Math.min(along * 0.3, s.size * 6);
		for (const sm of samples) {
			const left = along - sm.along;
			if (left < tail) sm.w *= 0.7 + 0.3 * (left / tail);
		}
	}
	// which way it goes, over five pixels each side: the shaking of a hand setting down doesn't turn the hairs
	let back = 0;
	let ahead = 0;
	for (let i = 0; i < samples.length; i++) {
		const here = samples[i].along;
		while (back < i && samples[back + 1].along <= here - 5) back++;
		if (ahead < i) ahead = i;
		while (ahead < samples.length - 1 && samples[ahead].along < here + 5) ahead++;
		const a = samples[back];
		const b = samples[ahead];
		const dx = b.x - a.x;
		const dy = b.y - a.y;
		const d = Math.hypot(dx, dy);
		if (d > 0.01) {
			samples[i].nx = -dy / d;
			samples[i].ny = dx / d;
		} else if (i > 0) {
			samples[i].nx = samples[i - 1].nx;
			samples[i].ny = samples[i - 1].ny;
		}
	}
	return { samples, starts };
}

/** The brush over its samples `from` … `to`: the body while there is ink for it, the hairs over it. */
function brushSpan(s: Stroke, samples: Sample[], from: number, to: number) {
	if (!ctx || !samples.length) return;
	to = Math.min(to, samples.length - 1);
	const color = ink();
	ctx.globalCompositeOperation = 'source-over';
	ctx.fillStyle = color;
	ctx.strokeStyle = color;
	ctx.lineCap = 'round';
	ctx.lineJoin = 'round';

	// the body: solid, its edge a little uneven, narrowing as the ink is spent, gone once the brush is dry;
	// never past the stroke's ends (the hairs make them), so no round blob sticks out where it stopped
	ctx.globalAlpha = 1;
	const total = samples[samples.length - 1].along;
	for (let i = from; i <= to; i++) {
		const sm = samples[i];
		const body = 1 - sm.used;
		if (body <= 0) break;
		const r = Math.min(
			(sm.w / 2) * 0.6 * Math.sqrt(body) * (0.9 + 0.2 * wave((s.seed ?? 1) * 7.3 + sm.along / 14)),
			total - sm.along + 0.5,
			sm.along + 0.5,
		);
		if (r < 0.3) continue;
		ctx.beginPath();
		ctx.arc(sm.x, sm.y, r, 0, Math.PI * 2);
		ctx.fill();
	}

	// the hairs: each a thin line of its own, fading out where its ink runs out; drawn in runs of
	// one shade, so a long stroke is a few lines per hair, not one per step
	const start = Math.max(1, from);
	for (const h of hairs(s)) {
		let level = -1;
		let width = 0;
		for (let i = start; i <= to + 1; i++) {
			const sm = samples[i];
			let next = -1;
			let lw = 0;
			if (sm && i <= to) {
				const left = h.ink - sm.used * h.rate + (wave(h.phase + sm.along / 5) - 0.5) * 0.9;
				next = left <= 0 ? 0 : Math.round(Math.min(1, left * 2.5) * h.alpha * 6);
				lw = Math.max(0.5, (sm.w / HAIRS) * 2.4 * h.w);
			}
			// a new run: the shade changed, or the width did by a sixth
			if (next !== level || Math.abs(lw - width) > width / 6) {
				if (level > 0) ctx.stroke();
				level = next;
				width = lw;
				if (level > 0) {
					const p = samples[i - 1];
					ctx.globalAlpha = level / 6;
					ctx.lineWidth = width;
					ctx.beginPath();
					ctx.moveTo(p.x + p.nx * h.o * p.w, p.y + p.ny * h.o * p.w);
				}
			}
			if (level > 0 && sm) ctx.lineTo(sm.x + sm.nx * h.o * sm.w, sm.y + sm.ny * h.o * sm.w);
		}
	}
	ctx.globalAlpha = 1;
}

/** The piece of `s` around its point `i`: a curve through the middles, as thick as the point is pressed. */
export function segment(s: Stroke, i: number) {
	if (!ctx) return;
	if (s.tool === 'brush') {
		const { samples, starts } = brushPath(s, false);
		return brushSpan(s, samples, starts[i] ?? 0, (starts[i + 1] ?? samples.length) - 1);
	}
	const pts = s.points;
	const p = pts[i];
	const before = pts[i - 1] ?? p;
	const after = pts[i + 1] ?? p;
	const from: [number, number] = [(before[0] + p[0]) / 2, (before[1] + p[1]) / 2];
	const to: [number, number] = [(after[0] + p[0]) / 2, (after[1] + p[1]) / 2];
	const color = ink();
	ctx.globalCompositeOperation = s.tool === 'rub' ? 'destination-out' : 'source-over';
	ctx.strokeStyle = color;
	ctx.fillStyle = color;
	ctx.lineCap = 'round';
	ctx.lineJoin = 'round';
	ctx.lineWidth = Math.max(0.6, s.size * (s.tool === 'rub' ? 4 : 1) * p[2]);
	if (pts.length === 1) {
		ctx.beginPath();
		ctx.arc(p[0], p[1], ctx.lineWidth / 2, 0, Math.PI * 2);
		ctx.fill();
		return;
	}
	ctx.beginPath();
	ctx.moveTo(...from);
	ctx.quadraticCurveTo(p[0], p[1], ...to);
	ctx.stroke();
}

export function drawStroke(s: Stroke) {
	if (s.tool === 'brush') {
		const { samples } = brushPath(s, s !== live);
		brushSpan(s, samples, 0, samples.length - 1);
		return;
	}
	for (let i = 0; i < s.points.length; i++) segment(s, i);
}


// ── a drawing in a note's text ──
// A line of its own: ⟦drawing {"s":[…]}⟧, its strokes as JSON (rounded: a tenth of a pixel, a hundredth of
// pressure, times from the stroke's start), so the note stays one text (exported, imported, searched as it is).

/** a drawing's line in a note's text, with the line's end after it */
export const DRAWING = /⟦drawing (\{.*?\})⟧\n?/g;

export function encode(strokes: Stroke[]): string {
	const r1 = (n: number) => Math.round(n * 10) / 10;
	const r2 = (n: number) => Math.round(n * 100) / 100;
	const s = strokes.map((st) => {
		const t0 = st.points[0]?.[3] ?? 0;
		return {
			k: st.tool,
			z: st.size,
			...(st.seed !== undefined ? { e: st.seed } : {}),
			p: st.points.map(([x, y, p, t]) => (t === undefined ? [r1(x), r1(y), r2(p)] : [r1(x), r1(y), r2(p), Math.round(t - t0)])),
		};
	});
	return JSON.stringify({ s });
}

export function decode(json: string): Stroke[] {
	try {
		const d = JSON.parse(json);
		return (d.s ?? []).map((st: { k: Tool; z: number; e?: number; p: Point[] }) => ({ tool: st.k, size: st.z, seed: st.e, points: st.p }));
	} catch {
		return [];
	}
}

/** a note's words, without its drawings (for search, counting) */
export const withoutDrawings = (text: string) => text.replace(DRAWING, '');
