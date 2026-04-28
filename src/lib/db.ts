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

export const SPACES: Omit<Space, 'id'>[] = [
	{
		element: 'water',
		kanji: '水',
		english: 'Feel',
		color: '#3FB5D3',
		description: 'Everything you\'ve learned, read, heard, and kept. Knowledge that settles slowly, layer by layer, like sediment. The deeper you go, the clearer it gets.',
		types: ['Summaries', 'Quotes', 'Facts', 'Instructions', 'Glossaries', 'Research', 'References'],
	},
	{
		element: 'earth',
		kanji: '土',
		english: 'Body',
		color: '#E6B422',
		description: 'The weight of real life — tasks, plans, deadlines, habits. What needs a hand, a step, a decision. Grounded, concrete, and always waiting.',
		types: ['Tasks', 'Plans', 'Deadlines', 'Meetings', 'Goals', 'Priorities', 'Habits'],
	},
	{
		element: 'fire',
		kanji: '火',
		english: 'Mind',
		color: '#EA5550',
		description: 'The place where ideas ignite before they have a name. Raw thoughts, wild questions, half-formed concepts that demand to exist. Nothing is finished here — and that\'s the point.',
		types: ['Ideas', 'Concepts', 'Hypotheses', 'Plots', 'Associations', 'Questions', 'Brainstorm'],
	},
	{
		element: 'air',
		kanji: '風',
		english: 'Soul',
		color: '#00CFB0',
		description: 'The invisible layer of who you are when no one\'s watching. Dreams, values, reflections — things you don\'t do, you simply hold. The lightest category, and somehow the heaviest.',
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
