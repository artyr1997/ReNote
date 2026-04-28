const ssr = false;
async function load({ url }) {
  return { spaces: [], preselectedElement: null };
}
export {
  load,
  ssr
};
