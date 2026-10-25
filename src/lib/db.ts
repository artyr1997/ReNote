import Dexie, { type Table } from 'dexie';

export interface Space {
	id?: number;
	element: string;
	kanji: string;
	english: string;
	color: string;
	description: string;
	types: string[];
}

export interface Note {
	id?: number;
	spaceId: number;
	title: string;
	body: string;
	createdAt: number;
	updatedAt: number;
}

export const TITLE_MAX = 40;

export const SPACES: Omit<Space, 'id'>[] = [
	{
		element: 'water',
		kanji: '水',
		english: 'Feel',
		color: '#3FB5D3',
		description: '水 / Feel.   Everything you absorb. Everything that stays. Knowledge does not arrive complete. It settles. Layer by layer. Thought by thought. Over time, it becomes clarity. This is where you keep what the world has already said so you can understand it on your own terms.',
		types: ['Summaries', 'Quotes', 'Facts', 'Instructions', 'Glossaries', 'Research', 'References'],
	},
	{
		element: 'earth',
		kanji: '土',
		english: 'Body',
		color: '#E6B422',
		description: '土 / Body. Reality lives here. Things that require action, movement, decisions. Not ideas, but execution. This is the weight you carry every day. Plans that need structure. Tasks that need completion. Grounded. Practical. Unavoidable.',
		types: ['Tasks', 'Plans', 'Deadlines', 'Meetings', 'Goals', 'Priorities', 'Habits'],
	},
	{
		element: 'fire',
		kanji: '火',
		english: 'Mind',
		color: '#EA5550',
		description: '火 / Mind. Before clarity, there is chaos. This is where thoughts are born. Unfinished. Unfiltered. Alive. Ideas do not need permission here. They do not need structure. Not yet. This is the space of creation where something begins without knowing what it will become.',
		types: ['Ideas', 'Concepts', 'Hypotheses', 'Plots', 'Associations', 'Questions', 'Brainstorm'],
	},
	{
		element: 'air',
		kanji: '風',
		english: 'Soul',
		color: '#00CFB0',
		description: '風 / Soul. The quiet layer beneath everything else. Not what you do, but who you are when nothing is required. This is where meaning lives. Where you process, remember, and feel. Invisible, but essential.',
		types: ['Journal', 'Emotions', 'Reflection', 'Dreams', 'Memories', 'Values', 'Letters'],
	},
];

class ReNoteDB extends Dexie {
	notes!: Table<Note, number>;
	spaces!: Table<Space, number>;

	constructor() {
		super('renote');
		this.version(1).stores({
			notes: '++id, spaceId, title, body, createdAt, updatedAt',
			spaces: '++id, element, kanji, english, color',
		});
		this.version(2).stores({
			notes: '++id, spaceId, title, body, createdAt, updatedAt',
			spaces: '++id, element, kanji, english, color',
		}).upgrade(tx => {
			return tx.table('spaces').toCollection().modify((space: Space) => {
				const seed = SPACES.find(s => s.element === space.element);
				if (seed) {
					space.color = seed.color;
					space.kanji = seed.kanji;
					space.english = seed.english;
				}
			});
		});
	}
}

export const db = new ReNoteDB();

export async function seedSpaces() {
	const count = await db.spaces.count();
	if (count === 0) {
		await db.spaces.bulkAdd(SPACES);
	}
}

export async function isInitialized(): Promise<boolean> {
	try {
		const count = await db.spaces.count();
		return count > 0;
	} catch {
		return false;
	}
}
