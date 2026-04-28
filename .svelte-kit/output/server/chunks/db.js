import Dexie from "dexie";
const SPACES = [
  {
    element: "water",
    kanji: "水",
    english: "Feel",
    color: "#2980B9",
    description: "Everything you've learned, read, heard, and kept. Knowledge that settles slowly, layer by layer, like sediment. The deeper you go, the clearer it gets.",
    types: ["Summaries", "Quotes", "Facts", "Instructions", "Glossaries", "Research", "References"]
  },
  {
    element: "earth",
    kanji: "土",
    english: "Body",
    color: "#3B6D11",
    description: "The weight of real life — tasks, plans, deadlines, habits. What needs a hand, a step, a decision. Grounded, concrete, and always waiting.",
    types: ["Tasks", "Plans", "Deadlines", "Meetings", "Goals", "Priorities", "Habits"]
  },
  {
    element: "fire",
    kanji: "火",
    english: "Mind",
    color: "#C0392B",
    description: "The place where ideas ignite before they have a name. Raw thoughts, wild questions, half-formed concepts that demand to exist. Nothing is finished here — and that's the point.",
    types: ["Ideas", "Concepts", "Hypotheses", "Plots", "Associations", "Questions", "Brainstorm"]
  },
  {
    element: "air",
    kanji: "風",
    english: "Soul",
    color: "#7F77DD",
    description: "The invisible layer of who you are when no one's watching. Dreams, values, reflections — things you don't do, you simply hold. The lightest category, and somehow the heaviest.",
    types: ["Journal", "Emotions", "Reflection", "Dreams", "Memories", "Values", "Letters"]
  }
];
class ReNoteDB extends Dexie {
  notes;
  spaces;
  constructor() {
    super("renote");
    this.version(1).stores({
      notes: "++id, spaceId, title, body, createdAt, updatedAt",
      spaces: "++id, element, kanji, english, color"
    });
  }
}
new ReNoteDB();
export {
  SPACES as S
};
