export const manifest = (() => {
function __memo(fn) {
	let value;
	return () => value ??= (value = fn());
}

return {
	appDir: "_app",
	appPath: "_app",
	assets: new Set(["favicon.svg","kanji/air.png","kanji/earth.png","kanji/fire.png","kanji/water.png","noise.svg","noise1.svg"]),
	mimeTypes: {".svg":"image/svg+xml",".png":"image/png"},
	_: {
		client: {start:"_app/immutable/entry/start.BYI_OQ_c.js",app:"_app/immutable/entry/app.BknF9zoK.js",imports:["_app/immutable/entry/start.BYI_OQ_c.js","_app/immutable/chunks/CkZfKkgA.js","_app/immutable/chunks/7odOQd2j.js","_app/immutable/chunks/DkEbPPnV.js","_app/immutable/chunks/FJ9bvqr_.js","_app/immutable/chunks/CWeFt6jb.js","_app/immutable/entry/app.BknF9zoK.js","_app/immutable/chunks/Dp1pzeXC.js","_app/immutable/chunks/7odOQd2j.js","_app/immutable/chunks/Db48WleP.js","_app/immutable/chunks/DwadMotS.js","_app/immutable/chunks/FJ9bvqr_.js","_app/immutable/chunks/DXjiKqRb.js","_app/immutable/chunks/DPpxpsPt.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
		nodes: [
			__memo(() => import('./nodes/0.js')),
			__memo(() => import('./nodes/1.js')),
			__memo(() => import('./nodes/2.js')),
			__memo(() => import('./nodes/3.js')),
			__memo(() => import('./nodes/4.js')),
			__memo(() => import('./nodes/5.js')),
			__memo(() => import('./nodes/6.js')),
			__memo(() => import('./nodes/7.js')),
			__memo(() => import('./nodes/8.js'))
		],
		remotes: {
			
		},
		routes: [
			{
				id: "/",
				pattern: /^\/$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 2 },
				endpoint: null
			},
			{
				id: "/edit/[id]",
				pattern: /^\/edit\/([^/]+?)\/?$/,
				params: [{"name":"id","optional":false,"rest":false,"chained":false}],
				page: { layouts: [0,], errors: [1,], leaf: 3 },
				endpoint: null
			},
			{
				id: "/home",
				pattern: /^\/home\/?$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 4 },
				endpoint: null
			},
			{
				id: "/info",
				pattern: /^\/info\/?$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 5 },
				endpoint: null
			},
			{
				id: "/new",
				pattern: /^\/new\/?$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 6 },
				endpoint: null
			},
			{
				id: "/note/[id]",
				pattern: /^\/note\/([^/]+?)\/?$/,
				params: [{"name":"id","optional":false,"rest":false,"chained":false}],
				page: { layouts: [0,], errors: [1,], leaf: 7 },
				endpoint: null
			},
			{
				id: "/space/[element]",
				pattern: /^\/space\/([^/]+?)\/?$/,
				params: [{"name":"element","optional":false,"rest":false,"chained":false}],
				page: { layouts: [0,], errors: [1,], leaf: 8 },
				endpoint: null
			}
		],
		prerendered_routes: new Set([]),
		matchers: async () => {
			
			return {  };
		},
		server_assets: {}
	}
}
})();
