import { f as attr, d as stringify, c as attr_style, e as escape_html, a as ensure_array_like, h as derived } from "../../../../chunks/root.js";
import "@sveltejs/kit/internal";
import "../../../../chunks/exports.js";
import "../../../../chunks/utils.js";
import "@sveltejs/kit/internal/server";
import "../../../../chunks/state.svelte.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let { data } = $$props;
    let note = derived(() => data.note), space = derived(() => data.space), nextId = derived(() => data.nextId);
    let fontSize = 1;
    $$renderer2.push(`<div class="frame" aria-hidden="true"><div class="corner tl"></div> <div class="corner tr"></div> <div class="corner bl"></div> <div class="corner br"></div></div> <button class="v-nav">SPACE</button> <button class="v-btn-left">BACK</button> `);
    if (nextId()) {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<a class="v-btn"${attr("href", `/note/${stringify(nextId())}`)}>NEXT</a>`);
    } else {
      $$renderer2.push("<!--[-1-->");
      $$renderer2.push(`<a class="v-btn"${attr("href", `/edit/${stringify(note()?.id)}`)}>EDIT</a>`);
    }
    $$renderer2.push(`<!--]--> <main class="screen note-screen fade-in svelte-12uzpal">`);
    if (note() && space()) {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<span class="space-tag svelte-12uzpal"${attr_style(`color: ${stringify(space().color)}`)}>${escape_html(space().kanji)} ${escape_html(space().english)}</span> <h1 class="note-title svelte-12uzpal">${escape_html(note().title)}</h1> <div class="note-body svelte-12uzpal"${attr_style(`font-size: ${stringify(fontSize)}rem`)}><!--[-->`);
      const each_array = ensure_array_like(note().body.split("\n"));
      for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
        let para = each_array[$$index];
        if (para.trim()) {
          $$renderer2.push("<!--[0-->");
          $$renderer2.push(`<p class="svelte-12uzpal">${escape_html(para)}</p>`);
        } else {
          $$renderer2.push("<!--[-1-->");
          $$renderer2.push(`<br/>`);
        }
        $$renderer2.push(`<!--]-->`);
      }
      $$renderer2.push(`<!--]--></div>`);
    } else {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--></main> <div class="font-controls svelte-12uzpal"><button class="font-btn svelte-12uzpal">—</button> <span class="font-indicator svelte-12uzpal">◆</span> <button class="font-btn svelte-12uzpal">+</button></div>`);
  });
}
export {
  _page as default
};
