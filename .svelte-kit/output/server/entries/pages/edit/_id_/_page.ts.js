import "@sveltejs/kit";
const ssr = false;
async function load({ params }) {
  return { note: null, space: null };
}
export {
  load,
  ssr
};
