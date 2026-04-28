import { a as ensure_array_like, c as attr_style, d as stringify, e as escape_html, f as attr, h as derived } from "../../../chunks/root.js";
import "@sveltejs/kit/internal";
import "../../../chunks/exports.js";
import "../../../chunks/utils.js";
import "@sveltejs/kit/internal/server";
import "../../../chunks/state.svelte.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let { data } = $$props;
    let spaces = derived(() => data.spaces), noteCounts = derived(() => data.noteCounts);
    const positions = [
      {
        bottomBox: {
          left: "calc(18.75% + 2px)",
          top: "calc(50% + 15px)",
          width: "98px",
          height: "151px"
        },
        label: {
          left: "calc(21.88% + 6px)",
          top: "calc(50% + 26px)",
          text: "FEEL"
        },
        topBox: {
          left: "calc(18.75% + 2px)",
          top: "calc(18.75% + 29px)",
          width: "98px",
          height: "82px"
        },
        diamond: {
          left: "calc(18.75% + 40px)",
          top: "calc(25% - 5px)",
          color: "#3fb5d3"
        },
        image: {
          left: "calc(18.75% - 61px)",
          top: "calc(25% + 47px)",
          size: "224px"
        }
      },
      {
        bottomBox: {
          left: "calc(37.5% + 2px)",
          top: "calc(62.5% + 14px)",
          width: "98px",
          height: "151px"
        },
        label: {
          left: "calc(40.63% + 6px)",
          top: "calc(62.5% + 25px)",
          text: "BODY"
        },
        topBox: {
          left: "calc(37.5% + 2px)",
          top: "calc(31.25% + 28px)",
          width: "98px",
          height: "82px"
        },
        diamond: {
          left: "calc(37.5% + 40px)",
          top: "calc(37.5% - 6px)",
          color: "#e6b422"
        },
        image: {
          left: "calc(37.5% - 61px)",
          top: "calc(37.5% + 46px)",
          size: "224px"
        }
      },
      {
        bottomBox: {
          left: "calc(56.25% + 2px)",
          top: "calc(50% + 15px)",
          width: "98px",
          height: "151px"
        },
        label: {
          left: "calc(59.38% + 6px)",
          top: "calc(50% + 26px)",
          text: "MIND"
        },
        topBox: {
          left: "calc(56.25% + 2px)",
          top: "calc(18.75% + 29px)",
          width: "98px",
          height: "82px"
        },
        diamond: {
          left: "calc(56.25% + 40px)",
          top: "calc(25% - 5px)",
          color: "#ea5550"
        },
        image: {
          left: "calc(56.25% - 61px)",
          top: "calc(25% + 47px)",
          size: "224px"
        }
      },
      {
        bottomBox: {
          left: "calc(68.75% + 79px)",
          top: "calc(62.5% + 6px)",
          width: "98px",
          height: "151px"
        },
        label: {
          left: "calc(78.13% - 7px)",
          top: "calc(62.5% + 6px)",
          text: "SOUL"
        },
        topBox: {
          left: "calc(68.75% + 79px)",
          top: "calc(31.25% + 20px)",
          width: "98px",
          height: "82px"
        },
        diamond: {
          left: "calc(75% + 27px)",
          top: "calc(31.25% + 50px)",
          color: "#00cfb0"
        },
        image: {
          left: "calc(68.75% + 16px)",
          top: "calc(37.5% + 38px)",
          size: "224px"
        }
      }
    ];
    $$renderer2.push(`<main class="home svelte-1j6ictg"><div class="background svelte-1j6ictg" aria-hidden="true"></div> <a href="/" class="exit svelte-1j6ictg">EXIT</a> <a href="/new" class="edit svelte-1j6ictg"><span class="svelte-1j6ictg">EDIT</span></a> <a href="/info" class="info svelte-1j6ictg"><span class="svelte-1j6ictg">INFO</span></a> <!--[-->`);
    const each_array = ensure_array_like(spaces());
    for (let i = 0, $$length = each_array.length; i < $$length; i++) {
      let space = each_array[i];
      const pos = positions[i];
      $$renderer2.push(`<div class="bottom-box svelte-1j6ictg"${attr_style(`left: ${stringify(pos.bottomBox.left)}; top: ${stringify(pos.bottomBox.top)}; width: ${stringify(pos.bottomBox.width)}; height: ${stringify(pos.bottomBox.height)};`)}><p class="label svelte-1j6ictg">${escape_html(pos.label.text)}</p></div> <div class="top-box svelte-1j6ictg"${attr_style(`left: ${stringify(pos.topBox.left)}; top: ${stringify(pos.topBox.top)}; width: ${stringify(pos.topBox.width)}; height: ${stringify(pos.topBox.height)};`)}><div class="diamond svelte-1j6ictg"${attr_style(`background-color: ${stringify(pos.diamond.color)};`)}></div></div> <img class="kanji-image svelte-1j6ictg"${attr_style(`left: ${stringify(pos.image.left)}; top: ${stringify(pos.image.top)}; width: ${stringify(pos.image.size)}; height: ${stringify(pos.image.size)};`)}${attr("src", `/kanji/${stringify(space.element)}.png`)}${attr("alt", space.kanji)}${attr("title", `${stringify(space.english)} — ${stringify(noteCounts()[space.id] ?? 0)} notes`)}/>`);
    }
    $$renderer2.push(`<!--]--></main>`);
  });
}
export {
  _page as default
};
