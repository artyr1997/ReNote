import { e as escape_html } from "../../../../chunks/root.js";
import "clsx";
import "@sveltejs/kit/internal";
import "../../../../chunks/exports.js";
import "../../../../chunks/utils.js";
import "@sveltejs/kit/internal/server";
import "../../../../chunks/state.svelte.js";
import "../../../../chunks/db.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let { data } = $$props;
    let body = "";
    $$renderer2.push(`<div class="frame svelte-1ul2axt" aria-hidden="true"><div class="corner tl svelte-1ul2axt"></div> <div class="corner tr svelte-1ul2axt"></div> <div class="corner bl svelte-1ul2axt"></div> <div class="corner br svelte-1ul2axt"></div></div> <button class="nav-home svelte-1ul2axt">EXIT</button> <button class="nav-info svelte-1ul2axt">INFO</button> <button class="nav-edit svelte-1ul2axt">SAVE</button> <main class="screen edit-screen fade-in svelte-1ul2axt"><h1 class="edit-title svelte-1ul2axt">EDIT</h1> `);
    {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--> <textarea class="body-input svelte-1ul2axt" placeholder="Start editing…">`);
    const $$body = escape_html(body);
    if ($$body) {
      $$renderer2.push(`${$$body}`);
    }
    $$renderer2.push(`</textarea></main>`);
  });
}
export {
  _page as default
};
