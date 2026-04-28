

export const index = 3;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/edit/_id_/_page.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "load": null
};
export const universal_id = "src/routes/edit/[id]/+page.ts";
export const imports = ["_app/immutable/nodes/3.kvdZ8rMx.js","_app/immutable/chunks/Dp1pzeXC.js","_app/immutable/chunks/C8BZa76B.js","_app/immutable/chunks/CWeFt6jb.js","_app/immutable/chunks/DwadMotS.js","_app/immutable/chunks/7odOQd2j.js","_app/immutable/chunks/Db48WleP.js","_app/immutable/chunks/DXjiKqRb.js","_app/immutable/chunks/DPpxpsPt.js","_app/immutable/chunks/DpfbbdZY.js","_app/immutable/chunks/CY8AB-us.js","_app/immutable/chunks/BbKdMp3Y.js","_app/immutable/chunks/CkZfKkgA.js","_app/immutable/chunks/DkEbPPnV.js","_app/immutable/chunks/FJ9bvqr_.js","_app/immutable/chunks/B4IzI7F0.js"];
export const stylesheets = ["_app/immutable/assets/3.PO9K9WNl.css"];
export const fonts = [];
