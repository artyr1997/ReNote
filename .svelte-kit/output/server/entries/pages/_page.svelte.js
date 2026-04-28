import { a as ensure_array_like, b as attr_class, c as attr_style, d as stringify, e as escape_html, f as attr } from "../../chunks/root.js";
import "@sveltejs/kit/internal";
import "../../chunks/exports.js";
import "../../chunks/utils.js";
import "@sveltejs/kit/internal/server";
import "../../chunks/state.svelte.js";
import { S as SPACES } from "../../chunks/db.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    $$renderer2.push(`<div class="landing-page svelte-1uha8ag"><div class="hero svelte-1uha8ag"><p class="hero-meta svelte-1uha8ag">nothing else</p> <p class="hero-label svelte-1uha8ag">HOME</p> <div class="hero-title svelte-1uha8ag"><span class="svelte-1uha8ag">Re:</span> <span class="svelte-1uha8ag">note</span></div> <p class="hero-tagline svelte-1uha8ag">just notes.</p></div> <main class="content svelte-1uha8ag"><section class="section philosophy svelte-1uha8ag"><p class="section-heading svelte-1uha8ag">PHILOSOPHY</p> <div class="section-copy svelte-1uha8ag"><p class="svelte-1uha8ag">Thinking has become a public act. Every idea you form, every moment of reflection — captured, catalogued, and quietly sold. Your attention is a currency. Your habits are data. We were promised tools that would extend the mind. What we got were traps dressed as convenience — platforms that fragment thought, reward distraction, and profit from who you're performing to be.</p> <p class="svelte-1uha8ag">This is different. No feeds, no friction, no agenda. Just the four oldest forces in the world and a place to think the way humans always have. Slowly. Privately. Honestly. Your mind was never meant to be a product. It still isn't.</p></div></section> <section class="section no-section svelte-1uha8ag"><p class="section-heading svelte-1uha8ag">NO</p> <div class="no-box svelte-1uha8ag"><div class="no-corner top-left svelte-1uha8ag"></div> <div class="no-corner top-right svelte-1uha8ag"></div> <div class="no-copy svelte-1uha8ag">Ads · Notifications · Paywalls · Tracking<br/> Algorithms · Manipulation · Accounts · Profiles</div> <div class="no-corner bottom-left svelte-1uha8ag"></div> <div class="no-corner bottom-right svelte-1uha8ag"></div></div></section> <section class="section space-section svelte-1uha8ag"><p class="section-heading svelte-1uha8ag">SPACE</p> <div class="space-grid svelte-1uha8ag"><!--[-->`);
    const each_array = ensure_array_like(SPACES);
    for (let index = 0, $$length = each_array.length; index < $$length; index++) {
      let space = each_array[index];
      $$renderer2.push(`<div${attr_class(`space-card ${stringify(index % 2 === 0 ? "odd" : "even")}`, "svelte-1uha8ag")}><div class="space-panel svelte-1uha8ag"><div class="space-dot svelte-1uha8ag"${attr_style(`background: ${stringify(space.color)}`)}></div> <p class="space-label svelte-1uha8ag">${escape_html(space.english.toUpperCase())}</p></div> <div class="space-content svelte-1uha8ag"><img${attr("src", `/kanji/${stringify(space.element)}.png`)}${attr("alt", space.element)} class="space-image svelte-1uha8ag"/> <div class="space-kanji svelte-1uha8ag">${escape_html(space.kanji)}</div> <p class="space-copy svelte-1uha8ag">${escape_html(space.description)}</p> <p class="space-tags svelte-1uha8ag">${escape_html(space.types.join(" · "))}</p></div></div>`);
    }
    $$renderer2.push(`<!--]--></div></section></main> <button class="start-button svelte-1uha8ag">START</button></div>`);
  });
}
export {
  _page as default
};
