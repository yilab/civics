// Loads the app's sources in plain Node: CSS imports, which esbuild inlines for
// the browser, resolve to an empty module. Passed to node via --import.
import { register } from 'node:module';

register('./css-hooks.mjs', import.meta.url);
