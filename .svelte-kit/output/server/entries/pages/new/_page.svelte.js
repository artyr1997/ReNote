import { e as escape_html, c as attr_style, d as stringify, h as derived } from "../../../chunks/root.js";
import "@sveltejs/kit/internal";
import "../../../chunks/exports.js";
import "../../../chunks/utils.js";
import "@sveltejs/kit/internal/server";
import "../../../chunks/state.svelte.js";
import "../../../chunks/db.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let { data } = $$props;
    let spaces = derived(() => data.spaces);
    let body = "";
    let selectedIdx = 0;
    let selectedSpace = derived(() => spaces()[selectedIdx]);
    $$renderer2.push(`<div class="frame svelte-1ax4549" aria-hidden="true"><div class="corner tl svelte-1ax4549"></div> <div class="corner tr svelte-1ax4549"></div> <div class="corner bl svelte-1ax4549"></div> <div class="corner br svelte-1ax4549"></div></div> <button class="nav-home svelte-1ax4549">BACK</button> <button class="nav-info svelte-1ax4549">INFO</button> <button class="nav-edit svelte-1ax4549">SAVE</button> <main class="screen new-screen fade-in svelte-1ax4549"><h1 class="new-title svelte-1ax4549">NEW NOTE</h1> <textarea placeholder="Begin writing…" class="body-input svelte-1ax4549">`);
    const $$body = escape_html(body);
    if ($$body) {
      $$renderer2.push(`${$$body}`);
    }
    $$renderer2.push(`</textarea></main> <div class="element-selector svelte-1ax4549"><button class="el-nav-btn svelte-1ax4549">—</button> <div class="el-center svelte-1ax4549">`);
    if (selectedSpace()) {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<span class="el-diamond svelte-1ax4549"${attr_style(`color: ${stringify(selectedSpace().color)}`)}>◆</span> <span class="el-name svelte-1ax4549">${escape_html(selectedSpace().kanji)} ${escape_html(selectedSpace().english)}</span>`);
    } else {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--></div> <button class="el-nav-btn svelte-1ax4549">+</button></div>`);
  });
}
export {
  _page as default
};
