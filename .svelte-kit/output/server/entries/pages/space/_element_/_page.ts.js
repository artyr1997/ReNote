import "@sveltejs/kit";
const ssr = false;
async function load({ params }) {
  return { space: null, notes: [] };
}
export {
  load,
  ssr
};
