import { readdir, readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const files = (await readdir('src', {recursive:true, withFileTypes:true})).filter(e=>e.isFile()).map(e=>`${e.parentPath}/${e.name}`);
const native = files.filter(f=>!f.endsWith('.gleam'));
assert.deepEqual(native, ['src/gleam_drawer/browser/platform_ffi.mjs'], 'Only the primitive platform FFI may contain handwritten runtime JS');
for (const path of files.filter(f=>f.endsWith('.gleam'))) {
  const source = await readFile(path,'utf8');
  if (source.includes('@external(')) assert.equal(path,'src/gleam_drawer/browser/platform.gleam');
}
const ffi = await readFile(native[0],'utf8');
assert.ok(!/from ['"].*(?:core|motion|gesture|registry|runtime|model)\.mjs/.test(ffi), 'FFI must not import drawer policy');
assert.ok(!/(?:requestSnap|requestClose|beginTransition|settleTransition|targetId|snapPoint)/.test(ffi), 'FFI must not implement drawer decisions');
console.log('Boundary OK: all drawer policy is Gleam; one primitive JS FFI.');
