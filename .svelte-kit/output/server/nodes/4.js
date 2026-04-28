

export const index = 4;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/home/_page.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "load": null
};
export const universal_id = "src/routes/home/+page.ts";
export const imports = ["_app/immutable/nodes/4.Cvr628lj.js","_app/immutable/chunks/Dp1pzeXC.js","_app/immutable/chunks/DwadMotS.js","_app/immutable/chunks/7odOQd2j.js","_app/immutable/chunks/Db48WleP.js","_app/immutable/chunks/0ZY8SooO.js","_app/immutable/chunks/DpfbbdZY.js","_app/immutable/chunks/CY8AB-us.js","_app/immutable/chunks/CkZfKkgA.js","_app/immutable/chunks/DkEbPPnV.js","_app/immutable/chunks/FJ9bvqr_.js","_app/immutable/chunks/CWeFt6jb.js"];
export const stylesheets = ["_app/immutable/assets/4.SzXUzTpJ.css"];
export const fonts = [];
