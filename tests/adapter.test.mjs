import test from 'node:test';
import assert from 'node:assert/strict';
import * as d from '../build/dev/javascript/gleam_drawer/gleam_drawer.mjs';
import * as m from '../build/dev/javascript/gleam_drawer/gleam_drawer/model.mjs';
import * as dom from '../build/dev/javascript/gleam_drawer/gleam_drawer/dom.mjs';
import { Ok, Error as GleamError, toList } from '../build/dev/javascript/gleam_drawer/gleam.mjs';
import { Some, None } from '../build/dev/javascript/gleam_stdlib/gleam/option.mjs';
const none = new None();
const ok = result => { assert.ok(result instanceof Ok, result[0]); return result[0]; };
const opened = id => d.opened(id, d.options(toList([new m.SnapPoint('half', new m.Ratio(0.5))]), 'half'));

test('SSR import, initial targets and errors have real Gleam representations', () => {
  assert.equal(globalThis.document, undefined);
  const c = ok(d.create(none));
  assert.ok(d.snapshot(c).target instanceof None);
  assert.ok(d.snapshot(c).phase instanceof m.ClosedPhase);
  assert.ok(dom.find_element('#absent') instanceof GleamError);
  const b = ok(dom.bind(c, dom.defaults()));
  ok(dom.destroy(b));
  ok(dom.destroy(b));
  assert.ok(dom.refresh(b) instanceof GleamError);
  ok(d.destroy(c));
});

test('events preserve every native Gleam variant, including release evidence and terminal facts', () => {
  const first = opened('first');
  const c = ok(d.create(new Some(first)));
  const events = [];
  const unsubscribe = d.subscribe(c, (snapshot, event) => events.push({ snapshot, event }));
  ok(d.request_open(c, new m.Trigger()));
  ok(d.sync(c, opened('second')));
  const a = ok(d.begin_transition(c, 'second'));
  const b = ok(d.begin_transition(c, 'second'));
  ok(d.cancel_transition(c, b, new m.DriverCancelled()));
  const t = ok(d.begin_transition(c, 'second'));
  ok(d.settle_transition(c, a)); // stale
  ok(d.settle_transition(c, t));
  let i = ok(d.begin_interaction(c, new m.HandleOrigin()));
  ok(d.end_interaction(c, i));
  const release = new Some(new m.Release(i, 50, 0.2, 330));
  ok(d.request_snap(c, 'half', new m.Gesture(), release));
  assert.ok(d.request_snap(c, 'half', new m.Gesture(), release) instanceof GleamError);
  i = ok(d.begin_interaction(c, new m.DragAreaOrigin()));
  ok(d.cancel_interaction(c, i, new m.PointerCancelled()));
  ok(d.request_close(c, new m.Escape(), new m.Keyboard(), none));
  ok(d.destroy(c));
  for (const name of ['OpenRequested', 'TargetSynced', 'TransitionStarted', 'TransitionReplaced',
    'TransitionCancelled', 'TransitionSettled', 'InteractionStarted', 'InteractionEnded',
    'SnapRequested', 'InteractionCancelled', 'CloseRequested', 'Destroyed']) {
    assert.ok(events.some(({ event }) => event instanceof m[name]), `missing ${name}`);
  }
  const snap = events.find(({ event }) => event instanceof m.SnapRequested).event;
  assert.ok(snap.release instanceof Some);
  assert.deepEqual(snap.release[0], release[0]);
  assert.ok(snap.origin instanceof m.Gesture);
  const sequences = events.map(({ event }) => event.sequence);
  assert.deepEqual(sequences, sequences.map((_, index) => index + 1));
  assert.ok(events.at(-1).snapshot.phase instanceof m.DestroyedPhase);
  unsubscribe(); unsubscribe();
});

test('reentrant acceptance preserves event snapshots and target identity', () => {
  const c = ok(d.create(none));
  const target = opened('accepted');
  const events = [];
  d.subscribe(c, (_, event) => {
    if (event instanceof m.OpenRequested) ok(d.sync(c, target));
  });
  const stop = d.subscribe(c, (s, e) => events.push([s, e]));
  ok(d.request_open(c, new m.Api()));
  assert.ok(events[0][0].target instanceof None);
  assert.equal(events[1][0].target[0], target);
  assert.equal(events[1][1].target, target);
  ok(d.sync(c, target));
  assert.equal(events.length, 2);
  stop();
  ok(d.destroy(c));
  assert.equal(events.length, 2);
});

test('subscriber failures drain queued publications and leave dispatch reusable', () => {
  const c = ok(d.create(none));
  const events = [];
  const stop = d.subscribe(c, (_, event) => {
    if (event instanceof m.OpenRequested) ok(d.sync(c, opened('accepted')));
    throw new Error('subscriber failed');
  });
  d.subscribe(c, (_, event) => events.push(event));
  const failure = d.request_open(c, new m.Api());
  assert.ok(failure instanceof GleamError);
  assert.match(failure[0], /subscriber failed/);
  assert.deepEqual(events.map(e => e.constructor.name), ['OpenRequested', 'TargetSynced']);
  assert.equal(d.snapshot(c).target[0].id, 'accepted');
  stop(); stop();
  ok(d.request_close(c, new m.Escape(), new m.Keyboard(), none));
  assert.ok(events.at(-1) instanceof m.CloseRequested);
  ok(d.destroy(c));
});
