
// this file is generated — do not edit it


declare module "svelte/elements" {
	export interface HTMLAttributes<T> {
		'data-sveltekit-keepfocus'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-noscroll'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-preload-code'?:
			| true
			| ''
			| 'eager'
			| 'viewport'
			| 'hover'
			| 'tap'
			| 'off'
			| undefined
			| null;
		'data-sveltekit-preload-data'?: true | '' | 'hover' | 'tap' | 'off' | undefined | null;
		'data-sveltekit-reload'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-replacestate'?: true | '' | 'off' | undefined | null;
	}
}

export {};


declare module "$app/types" {
	type MatcherParam<M> = M extends (param : string) => param is (infer U extends string) ? U : string;

	export interface AppTypes {
		RouteId(): "/" | "/edit" | "/edit/[id]" | "/home" | "/new" | "/note" | "/note/[id]" | "/space" | "/space/[element]";
		RouteParams(): {
			"/edit/[id]": { id: string };
			"/note/[id]": { id: string };
			"/space/[element]": { element: string }
		};
		LayoutParams(): {
			"/": { id?: string; element?: string };
			"/edit": { id?: string };
			"/edit/[id]": { id: string };
			"/home": Record<string, never>;
			"/new": Record<string, never>;
			"/note": { id?: string };
			"/note/[id]": { id: string };
			"/space": { element?: string };
			"/space/[element]": { element: string }
		};
		Pathname(): "/" | `/edit/${string}` & {} | "/home" | "/new" | `/note/${string}` & {} | `/space/${string}` & {};
		ResolvedPathname(): `${"" | `/${string}`}${ReturnType<AppTypes['Pathname']>}`;
		Asset(): "/favicon.svg" | "/kanji/air.png" | "/kanji/cursor.svg" | "/kanji/earth.png" | "/kanji/fire.png" | "/kanji/hand.svg" | "/kanji/ibeam.svg" | "/kanji/water.png" | "/noise.svg" | "/noise1.svg" | string & {};
	}
}