import "@sveltejs/kit";
const prerender = false;
const ssr = false;
async function load({ url }) {
  return {};
}
export {
  load,
  prerender,
  ssr
};
