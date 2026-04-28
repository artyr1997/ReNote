import { f as attr, d as stringify, e as escape_html, a as ensure_array_like, b as attr_class, h as derived } from "../../../../chunks/root.js";
import "@sveltejs/kit/internal";
import "../../../../chunks/exports.js";
import "../../../../chunks/utils.js";
import "@sveltejs/kit/internal/server";
import "../../../../chunks/state.svelte.js";
import "../../../../chunks/db.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let { data } = $$props;
    let space = derived(() => data.space), notes = derived(() => data.notes);
    let activeNote = null;
    let noteBody = "";
    let searchQuery = "";
    let filteredNotes = derived(() => searchQuery.trim() ? notes().filter((n) => n.title.toLowerCase().includes(searchQuery.toLowerCase()) || n.body.toLowerCase().includes(searchQuery.toLowerCase())) : notes());
    function truncate(text, chars = 40) {
      const normalized = text.replace(/\s+/g, " ").trim();
      return normalized.length > chars ? normalized.slice(0, chars) + "…" : normalized;
    }
    $$renderer2.push(`<main class="screen space-screen fade-in svelte-1uuaxjk"><a class="nav-home svelte-1uuaxjk" href="/home">HOME</a> <a class="nav-button nav-new svelte-1uuaxjk"${attr("href", `/new?space=${stringify(space()?.element)}`)}><p class="svelte-1uuaxjk">NEW</p></a> <a class="nav-button nav-del svelte-1uuaxjk" href="/info"><p class="svelte-1uuaxjk">DEL</p></a> <div class="center-divider svelte-1uuaxjk" aria-hidden="true"></div> `);
    if (space()) {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<div class="left-column svelte-1uuaxjk"><div class="kanji-block svelte-1uuaxjk"><img class="space-kanji-img svelte-1uuaxjk"${attr("src", `/kanji/${stringify(space().element)}.png`)}${attr("alt", space().kanji)}/> <div class="kanji-divider svelte-1uuaxjk"></div> <p class="kanji-name svelte-1uuaxjk">${escape_html(space().english.toUpperCase())}</p></div> <div class="search-row svelte-1uuaxjk"><input class="search-input svelte-1uuaxjk" type="text" placeholder="Search quotes.."${attr("value", searchQuery)}/></div> <div class="notes-list svelte-1uuaxjk">`);
      if (filteredNotes().length === 0) {
        $$renderer2.push("<!--[0-->");
        $$renderer2.push(`<p class="empty svelte-1uuaxjk">No quotes yet.</p>`);
      } else {
        $$renderer2.push("<!--[-1-->");
        $$renderer2.push(`<!--[-->`);
        const each_array = ensure_array_like(filteredNotes());
        for (let i = 0, $$length = each_array.length; i < $$length; i++) {
          let note = each_array[i];
          $$renderer2.push(`<button${attr_class(`note-row ${stringify(activeNote?.id === note.id ? "active" : "")}`, "svelte-1uuaxjk")}><span${attr_class(`note-icon ${stringify(activeNote?.id === note.id ? "filled" : "outline")}`, "svelte-1uuaxjk")}>${escape_html(activeNote?.id === note.id ? "◆" : "◇")}</span> <span class="note-title svelte-1uuaxjk">${escape_html(truncate(note.body || note.title || "Untitled", 40))}</span></button>`);
        }
        $$renderer2.push(`<!--]-->`);
      }
      $$renderer2.push(`<!--]--></div></div> <div class="right-column svelte-1uuaxjk"><div class="quote-card svelte-1uuaxjk"><div class="quote-corner top-left svelte-1uuaxjk"></div> <div class="quote-corner top-right svelte-1uuaxjk"></div> <div class="quote-corner bottom-left svelte-1uuaxjk"></div> <div class="quote-corner bottom-right svelte-1uuaxjk"></div> <!---->`);
      {
        $$renderer2.push(`<textarea class="note-textarea svelte-1uuaxjk"${attr("placeholder", "Select a note…")}>`);
        const $$body = escape_html(noteBody);
        if ($$body) {
          $$renderer2.push(`${$$body}`);
        }
        $$renderer2.push(`</textarea>`);
      }
      $$renderer2.push(`<!----></div></div>`);
    } else {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--></main>`);
  });
}
export {
  _page as default
};
