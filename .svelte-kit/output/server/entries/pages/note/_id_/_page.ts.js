import "@sveltejs/kit";
const ssr = false;
async function load({ params }) {
  return { note: null, space: null, nextId: null, prevId: null };
}
export {
  load,
  ssr
};
