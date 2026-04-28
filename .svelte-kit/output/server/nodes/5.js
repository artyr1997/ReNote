

export const index = 5;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/info/_page.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "load": null
};
export const universal_id = "src/routes/info/+page.ts";
export const imports = ["_app/immutable/nodes/5.B18G-duX.js","_app/immutable/chunks/Dp1pzeXC.js","_app/immutable/chunks/DwadMotS.js","_app/immutable/chunks/7odOQd2j.js"];
export const stylesheets = ["_app/immutable/assets/5.DQQSkH95.css"];
export const fonts = [];
