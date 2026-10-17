import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
import * as bridge from './helpers/geometry.mjs';
import { nativeSnapshot, nativeEvent } from './helpers/representation.mjs';
import * as d from '../build/dev/javascript/gleam_drawer/gleam_drawer.mjs';
import * as m from '../build/dev/javascript/gleam_drawer/gleam_drawer/model.mjs';
import { Ok, toList } from '../build/dev/javascript/gleam_drawer/gleam.mjs';
import { Some, None } from '../build/dev/javascript/gleam_stdlib/gleam/option.mjs';
await build({ entryPoints: ['tests/reference/core/index.ts'], outfile: 'build/reference-core.mjs', bundle: true, format: 'esm', platform: 'node' });
const upstream = await import('../build/reference-core.mjs');
const ok = r => { assert.ok(r instanceof Ok, r[0]); return r[0]; };
const none = new None();
const points = [
  { id: 'small', size: { type: 'ratio', value: 0.25 } },
  { id: 'content', size: { type: 'content', maxRatio: 0.8 } },
  { id: 'large', size: { type: 'pixels', value: 700 } },
];
let seed = 123456789;
const random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 2 ** 32; };
const near = (a,b) => assert.ok(Math.abs(a-b) < 1e-9, `${a} != ${b}`);

test('Gleam geometry matches the frozen TypeScript oracle across 1000 deterministic cases', () => {
  for (let i = 0; i < 1000; i++) {
    const metrics = { viewportHeight: random()*1200, insetTop: random()*80,
      insetBottom: random()*80, headerHeight: random()*100,
      bodyNaturalHeight: random()*1500, footerHeight: random()*100,
      minHeight: random()*200, maxHeight: 200 + random()*1000 };
    const expected = upstream.resolveSnapPoints(points, metrics);
    const actual = bridge.resolveSnapPoints(points, metrics);
    assert.deepEqual(actual, expected);
    const release = { currentHeight: random()*1000, activeSnapPoint: expected[i%3].id,
      velocity: random()*4-2, dragDistance: random()*600-300, snapPoints: expected,
      allowClose: i%2 === 0, snapToSequentialPoints: i%3 === 0 };
    assert.deepEqual(bridge.selectReleaseDestination(release), upstream.selectReleaseDestination(release));
    const band = { value: random()*2000-500, min: 100, max: 800,
      dimension: random()*1000, constant: random()+0.1 };
    near(bridge.applyRubberBand(band), upstream.applyRubberBand(band));
  }
});

test('physical ties, sequential snaps, zero viewport and invalid geometry', () => {
  const ties = [{id:'a',height:100,declarationIndex:0},{id:'b',height:100,declarationIndex:1},{id:'c',height:300,declarationIndex:2}];
  for (const activeSnapPoint of ['a','b','c']) for (const velocity of [-2,0,2]) {
    const input = {currentHeight:200,activeSnapPoint,velocity,dragDistance:0,snapPoints:ties,snapToSequentialPoints:true};
    assert.deepEqual(bridge.selectReleaseDestination(input), upstream.selectReleaseDestination(input));
  }
  const metrics = {viewportHeight:0,insetTop:30,insetBottom:40,headerHeight:40,bodyNaturalHeight:100,footerHeight:30};
  assert.deepEqual(bridge.resolveSnapPoints(points, metrics), upstream.resolveSnapPoints(points, metrics));
  for (const value of [NaN, Infinity, -Infinity]) {
    assert.throws(() => bridge.resolveSnapPoints(points, {...metrics, viewportHeight:value}));
    assert.throws(() => bridge.applyRubberBand({value,min:0,max:1,dimension:1}));
  }
  assert.throws(() => bridge.resolveSnapPoints([], metrics));
  assert.throws(() => bridge.resolveSnapPoints([points[0],points[0]], metrics));
});

function target(id, open = true) {
  return open ? d.opened(id, d.options(toList([new m.SnapPoint('small', new m.Ratio(0.25))]), 'small')) : d.closed(id);
}
function nativeTarget(id, open = true) {
  return { targetId:id, open, transition:{cause:open?'open':'close',direction:'none',motion:'auto'},
    ...(open ? {snapPoints:[points[0]],snapPoint:'small',presentation:'sheet',modality:'modal',draggable:true,
      snapToSequentialPoints:false,contentResizeBehavior:'animate',regions:Object.fromEntries(['header','body','footer'].map(key=>[key,{key,transition:'preserve'}]))}: {}) };
}
const normalize = value => JSON.parse(JSON.stringify(value));

test('native Gleam lifecycle matches upstream requests, snapshots, token replacement and destruction', () => {
  const g = ok(d.create(new Some(target('a'))));
  const t = upstream.createShellSheetController(nativeTarget('a'));
  const ge = [], te = [];
  d.subscribe(g, (s,e)=>ge.push(normalize([nativeSnapshot(s),nativeEvent(e)])));
  t.subscribe((s,e)=>te.push(normalize([s,e])));
  const compare = () => { assert.deepEqual(normalize(nativeSnapshot(d.snapshot(g))), normalize(t.getSnapshot())); assert.deepEqual(ge,te); };
  compare();
  for (const [method,args] of [
    ['requestOpen',['trigger']], ['beginTransition',['a']], ['settleTransition',[1]],
    ['beginInteraction',['handle']], ['endInteraction',[1]],
    ['requestSnap',['small',{origin:'gesture',release:{interactionId:1,distance:12,velocity:0.1,projectedHeight:300}}]],
    ['beginTransition',['a']], ['beginTransition',['a']], ['settleTransition',[2]],
    ['cancelTransition',[3,'driver-cancelled']], ['requestClose',['escape']],
  ]) { assert.equal(invoke(g,method,args),t[method](...args)); compare(); }
  ok(d.sync(g,target('b'))); t.sync(nativeTarget('b')); compare();
  ok(d.begin_interaction(g,new m.DragAreaOrigin())); t.beginInteraction('drag-area'); compare();
  ok(d.sync(g,target('c',false))); t.sync(nativeTarget('c',false)); compare();
  ok(d.begin_transition(g,'c')); t.beginTransition('c'); compare();
  ok(d.destroy(g)); t.destroy(); compare();
  ok(d.destroy(g)); t.destroy(); compare();
  assert.equal(d.request_open(g,new m.Api()).isOk(), false); assert.throws(()=>t.requestOpen());
});

function invoke(c, method, args) {
  switch (method) {
    case 'requestOpen': return ok(d.request_open(c,new m.Trigger()));
    case 'beginTransition': return ok(d.begin_transition(c,args[0]));
    case 'settleTransition': return ok(d.settle_transition(c,args[0]));
    case 'beginInteraction': return ok(d.begin_interaction(c,new m.HandleOrigin()));
    case 'endInteraction': return ok(d.end_interaction(c,args[0]));
    case 'requestSnap': { const r=args[1].release; return ok(d.request_snap(c,args[0],new m.Gesture(),new Some(new m.Release(r.interactionId,r.distance,r.velocity,r.projectedHeight)))); }
    case 'cancelTransition': return ok(d.cancel_transition(c,args[0],new m.DriverCancelled()));
    case 'requestClose': return ok(d.request_close(c,new m.Escape(),new m.Keyboard(),none));
    default: throw new Error(method);
  }
}
