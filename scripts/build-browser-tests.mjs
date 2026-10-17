import { build } from 'esbuild';
import { writeFile } from 'node:fs/promises';
await build({entryPoints:['tests/browser/harness.mjs'],outfile:'dist/__driver_test.mjs',bundle:true,format:'esm',platform:'browser'});
await writeFile('dist/__driver_test.html', '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Driver conformance</title></head><body><main id="background"><button id="trigger">Open</button></main><script type="module" src="/__driver_test.mjs"></script></body></html>');
