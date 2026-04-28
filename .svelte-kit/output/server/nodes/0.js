

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "load": null
};
export const universal_id = "src/routes/+layout.ts";
export const imports = ["_app/immutable/nodes/0.B89M1P_j.js","_app/immutable/chunks/Dp1pzeXC.js","_app/immutable/chunks/C8BZa76B.js","_app/immutable/chunks/CWeFt6jb.js","_app/immutable/chunks/DwadMotS.js","_app/immutable/chunks/7odOQd2j.js","_app/immutable/chunks/DPpxpsPt.js"];
export const stylesheets = ["_app/immutable/assets/0.CLUpYWf7.css"];
export const fonts = [];
