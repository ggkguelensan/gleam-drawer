import * as m from './gleam_drawer/model.mjs';
import * as engine from './gleam_drawer/internal/engine.mjs';
import * as core from './gleam_drawer/core.mjs';
import { Ok, Error as GleamError, toList } from './gleam.mjs';
import { Some, None } from '../gleam_stdlib/gleam/option.mjs';

const attempt = fn => { try { return new Ok(fn()); } catch (error) { return new GleamError(String(error.message ?? error)); } };
const optional = value => value == null ? new None() : new Some(value);
const unwrap = value => value instanceof Some ? value[0] : undefined;
const mapOptional = (value, fn) => value == null ? new None() : new Some(fn(value));
const enumValues = new Map([
  [m.OpenCause, 'open'],
  [m.CloseCause, 'close'],
  [m.NavigateCause, 'navigate'],
  [m.SnapCause, 'snap'],
  [m.ContentCause, 'content'],
  [m.PresentationCause, 'presentation'],
  [m.HydrateCause, 'hydrate'],
  [m.ApiCause, 'api'],
  [m.Forward, 'forward'],
  [m.Backward, 'backward'],
  [m.ReplaceDirection, 'replace'],
  [m.SnapDirection, 'snap'],
  [m.NoDirection, 'none'],
  [m.Auto, 'auto'],
  [m.Instant, 'instant'],
  [m.Preserve, 'preserve'],
  [m.Crossfade, 'crossfade'],
  [m.ReplaceRegion, 'replace'],
  [m.Sheet, 'sheet'],
  [m.Dialog, 'dialog'],
  [m.Modal, 'modal'],
  [m.NonModal, 'non-modal'],
  [m.Animate, 'animate'],
  [m.Immediate, 'immediate'],
  [m.KeepSnapAndScroll, 'keep-snap-and-scroll'],
  [m.ClosedPhase, 'closed'],
  [m.Preparing, 'preparing'],
  [m.Opening, 'opening'],
  [m.OpenPhase, 'open'],
  [m.Dragging, 'dragging'],
  [m.Transitioning, 'transitioning'],
  [m.Closing, 'closing'],
  [m.DestroyedPhase, 'destroyed'],
  [m.HandleOrigin, 'handle'],
  [m.DragAreaOrigin, 'drag-area'],
  [m.Trigger, 'trigger'],
  [m.Api, 'api'],
  [m.Gesture, 'gesture'],
  [m.Keyboard, 'keyboard'],
  [m.BackdropOrigin, 'backdrop'],
  [m.CloseButtonOrigin, 'close-button'],
  [m.Escape, 'escape'],
  [m.BackdropClose, 'backdrop'],
  [m.GestureClose, 'gesture'],
  [m.CloseButton, 'close-button'],
  [m.ApiClose, 'api'],
  [m.RouteChange, 'route-change'],
  [m.TransitionDestroyed, 'destroyed'],
  [m.DriverCancelled, 'driver-cancelled'],
  [m.RegistryLost, 'registry-lost'],
  [m.PointerCancelled, 'pointer-cancelled'],
  [m.CaptureLost, 'capture-lost'],
  [m.VisibilityLost, 'visibility-lost'],
  [m.TargetChanged, 'target-changed'],
  [m.InteractionDestroyed, 'destroyed'],
  [m.Portal, 'portal'],
  [m.Backdrop, 'backdrop'],
  [m.Viewport, 'viewport'],
  [m.Popup, 'popup'],
  [m.Content, 'content'],
  [m.Header, 'header'],
  [m.Body, 'body'],
  [m.Footer, 'footer'],
  [m.Handle, 'handle'],
  [m.InertTarget, 'inert-target'],
  [m.HeaderRegion, 'header'],
  [m.BodyRegion, 'body'],
  [m.FooterRegion, 'footer'],
  [m.Settled, 'settled'],
  [m.Outgoing, 'outgoing'],
  [m.Incoming, 'incoming'],
 ]);
const encodeEnum = value => enumValues.get(value.constructor);
const TransitionCause = {'open': () => new m.OpenCause(), 'close': () => new m.CloseCause(), 'navigate': () => new m.NavigateCause(), 'snap': () => new m.SnapCause(), 'content': () => new m.ContentCause(), 'presentation': () => new m.PresentationCause(), 'hydrate': () => new m.HydrateCause(), 'api': () => new m.ApiCause()};
const Direction = {'forward': () => new m.Forward(), 'backward': () => new m.Backward(), 'replace': () => new m.ReplaceDirection(), 'snap': () => new m.SnapDirection(), 'none': () => new m.NoDirection()};
const Motion = {'auto': () => new m.Auto(), 'instant': () => new m.Instant()};
const RegionTransition = {'preserve': () => new m.Preserve(), 'crossfade': () => new m.Crossfade(), 'replace': () => new m.ReplaceRegion()};
const Presentation = {'sheet': () => new m.Sheet(), 'dialog': () => new m.Dialog()};
const Modality = {'modal': () => new m.Modal(), 'non-modal': () => new m.NonModal()};
const ResizeBehavior = {'animate': () => new m.Animate(), 'immediate': () => new m.Immediate(), 'keep-snap-and-scroll': () => new m.KeepSnapAndScroll()};
const Phase = {'closed': () => new m.ClosedPhase(), 'preparing': () => new m.Preparing(), 'opening': () => new m.Opening(), 'open': () => new m.OpenPhase(), 'dragging': () => new m.Dragging(), 'transitioning': () => new m.Transitioning(), 'closing': () => new m.Closing(), 'destroyed': () => new m.DestroyedPhase()};
const InteractionOrigin = {'handle': () => new m.HandleOrigin(), 'drag-area': () => new m.DragAreaOrigin()};
const RequestOrigin = {'trigger': () => new m.Trigger(), 'api': () => new m.Api(), 'gesture': () => new m.Gesture(), 'keyboard': () => new m.Keyboard(), 'backdrop': () => new m.BackdropOrigin(), 'close-button': () => new m.CloseButtonOrigin()};
const CloseReason = {'escape': () => new m.Escape(), 'backdrop': () => new m.BackdropClose(), 'gesture': () => new m.GestureClose(), 'close-button': () => new m.CloseButton(), 'api': () => new m.ApiClose(), 'route-change': () => new m.RouteChange()};
const TransitionCancelReason = {'destroyed': () => new m.TransitionDestroyed(), 'driver-cancelled': () => new m.DriverCancelled(), 'registry-lost': () => new m.RegistryLost()};
const InteractionCancelReason = {'pointer-cancelled': () => new m.PointerCancelled(), 'capture-lost': () => new m.CaptureLost(), 'visibility-lost': () => new m.VisibilityLost(), 'target-changed': () => new m.TargetChanged(), 'destroyed': () => new m.InteractionDestroyed()};
const Part = {'portal': () => new m.Portal(), 'backdrop': () => new m.Backdrop(), 'viewport': () => new m.Viewport(), 'popup': () => new m.Popup(), 'content': () => new m.Content(), 'header': () => new m.Header(), 'body': () => new m.Body(), 'footer': () => new m.Footer(), 'handle': () => new m.Handle(), 'inert-target': () => new m.InertTarget()};
const Region = {'header': () => new m.HeaderRegion(), 'body': () => new m.BodyRegion(), 'footer': () => new m.FooterRegion()};
const Layer = {'settled': () => new m.Settled(), 'outgoing': () => new m.Outgoing(), 'incoming': () => new m.Incoming()};

// Preserve object identity across repeated Gleam -> JS conversion. Upstream
// treats a different object with the same target id as a programming error.
const targets = new WeakMap();
const originals = new WeakMap();
const encodeTransition = t => ({ cause: encodeEnum(t.cause), direction: encodeEnum(t.direction), motion: encodeEnum(t.motion) });
const encodeRegion = r => ({ key: r.key, transition: encodeEnum(r.transition) });
const encodePoint = p => ({ id: p.id, size: p.size instanceof m.Ratio
  ? { type: 'ratio', value: p.size.value }
  : p.size instanceof m.Pixels ? { type: 'pixels', value: p.size.value }
  : { type: 'content', maxRatio: unwrap(p.size.max_ratio) } });
function encodeTarget(t) {
  if (targets.has(t)) return targets.get(t);
  const result = { targetId: t.id, open: t instanceof m.Open,
    transition: encodeTransition(t.transition), causeRequestId: unwrap(t.cause_request_id) };
  if (result.open) {
    const o = t.options;
    Object.assign(result, {
      snapPoints: o.snap_points.toArray().map(encodePoint), snapPoint: o.snap_point,
      presentation: encodeEnum(o.presentation), modality: encodeEnum(o.modality),
      draggable: o.draggable, snapToSequentialPoints: o.sequential,
      contentResizeBehavior: encodeEnum(o.resize_behavior),
      regions: { header: encodeRegion(o.regions.header), body: encodeRegion(o.regions.body), footer: encodeRegion(o.regions.footer) },
    });
  }
  targets.set(t, result);
  originals.set(result, t);
  return result;
}
function decodeSnapshot(s) {
  return new m.Snapshot(mapOptional(s.authoritativeTarget, t => originals.get(t)),
    mapOptional(s.settledTarget, t => originals.get(t)), Phase[s.phase](),
    optional(s.transitionId), mapOptional(s.interaction, i => new m.Interaction(i.interactionId, InteractionOrigin[i.origin]())));
}
const decodeRelease = r => new m.Release(r.interactionId, r.distance, r.velocity, r.projectedHeight);
const encodeRelease = r => r instanceof Some ? {
  interactionId: r[0].interaction_id, distance: r[0].distance,
  velocity: r[0].velocity, projectedHeight: r[0].projected_height,
} : undefined;
function decodeEvent(e) {
  const s = e.sequence;
  switch (e.type) {
    case 'open-requested': return new m.OpenRequested(s, e.requestId, RequestOrigin[e.origin]());
    case 'close-requested': return new m.CloseRequested(s, e.requestId, RequestOrigin[e.origin](), CloseReason[e.reason](), mapOptional(e.release, decodeRelease));
    case 'snap-requested': return new m.SnapRequested(s, e.requestId, RequestOrigin[e.origin](), e.snapPoint, mapOptional(e.release, decodeRelease));
    case 'target-synced': return new m.TargetSynced(s, originals.get(e.target));
    case 'transition-started': return new m.TransitionStarted(s, e.targetId, e.transitionId);
    case 'transition-settled': return new m.TransitionSettled(s, e.targetId, e.transitionId);
    case 'transition-replaced': return new m.TransitionReplaced(s, e.targetId, e.transitionId, e.replacedBy);
    case 'transition-cancelled': return new m.TransitionCancelled(s, e.targetId, e.transitionId, TransitionCancelReason[e.reason]());
    case 'interaction-started': return new m.InteractionStarted(s, e.interactionId, InteractionOrigin[e.origin]());
    case 'interaction-ended': return new m.InteractionEnded(s, e.interactionId, InteractionOrigin[e.origin]());
    case 'interaction-cancelled': return new m.InteractionCancelled(s, e.interactionId, InteractionOrigin[e.origin](), InteractionCancelReason[e.reason]());
    case 'destroyed': return new m.Destroyed(s);
    default: throw new Error(`Unsupported Shell Sheet event: ${e.type}`);
  }
}
export const create = initial => attempt(() => createController(initial));
export const sync = (c, t) => attempt(() => c.sync(encodeTarget(t)));
export const snapshot = c => decodeSnapshot(c.getSnapshot());
export const subscribe = (c, listener) => c.subscribe((s, e) => listener(decodeSnapshot(s), decodeEvent(e)));
export const request_open = (c, origin) => attempt(() => c.requestOpen(encodeEnum(origin)));
export const request_close = (c, reason, origin, release) => attempt(() => c.requestClose(encodeEnum(reason), { origin: encodeEnum(origin), release: encodeRelease(release) }));
export const request_snap = (c, point, origin, release) => attempt(() => c.requestSnap(point, { origin: encodeEnum(origin), release: encodeRelease(release) }));
export const begin_transition = (c, id) => attempt(() => c.beginTransition(id));
export const settle_transition = (c, id) => attempt(() => c.settleTransition(id));
export const cancel_transition = (c, id, reason) => attempt(() => c.cancelTransition(id, encodeEnum(reason)));
export const begin_interaction = (c, origin) => attempt(() => c.beginInteraction(encodeEnum(origin)));
export const end_interaction = (c, id) => attempt(() => c.endInteraction(id));
export const cancel_interaction = (c, id, reason) => attempt(() => c.cancelInteraction(id, encodeEnum(reason)));
export const destroy = c => attempt(() => c.destroy());
export const find_element = selector => attempt(() => {
  const element = globalThis.document?.querySelector(selector);
  if (!element || !(element instanceof element.ownerDocument.defaultView.HTMLElement)) throw new Error(`HTMLElement not found: ${selector}`);
  return element;
});
export const bind = (c, o) => attempt(() => engine.bindShellSheetToDom(c, { closeOnEscape: o.close_on_escape, closeOnBackdrop: o.close_on_backdrop }));
export const register_part = (b, part, element) => attempt(() => b.registerPart(encodeEnum(part), element));
export const register_layer = (b, region, key, layer, element) => attempt(() => b.registerRegionLayer(encodeEnum(region), { key, layer: encodeEnum(layer) }, element));
export const register_surface = (b, region, element) => attempt(() => b.registerRegionTransitionSurface(encodeEnum(region), element));
export const register_drag_area = (b, element, id) => attempt(() => b.registerDragArea(element, { id }));
export const set_insets = (b, top, bottom) => attempt(() => b.setInsets({ top, bottom }));
export const refresh = b => attempt(() => b.refresh());
export const destroy_binding = b => attempt(() => b.destroy());

const unresult = result => {
  if (result instanceof Ok) return result[0];
  throw new Error(result[0]);
};
const nativeSnapshots = new WeakMap();
function nativeSnapshot(s) {
  if (nativeSnapshots.has(s)) return nativeSnapshots.get(s);
  const value = Object.freeze({
    authoritativeTarget: s.target instanceof Some ? encodeTarget(s.target[0]) : null,
    settledTarget: s.settled_target instanceof Some ? encodeTarget(s.settled_target[0]) : null,
    phase: encodeEnum(s.phase), transitionId: unwrap(s.transition_id) ?? null,
    interaction: s.interaction instanceof Some ? Object.freeze({ interactionId: s.interaction[0].id, origin: encodeEnum(s.interaction[0].origin) }) : null,
  });
  nativeSnapshots.set(s, value);
  return value;
}
function nativeEvent(e) {
  const base = { sequence: e.sequence };
  if (e instanceof m.OpenRequested) return { ...base, type: 'open-requested', requestId: e.request_id, origin: encodeEnum(e.origin) };
  if (e instanceof m.CloseRequested) return { ...base, type: 'close-requested', requestId: e.request_id, origin: encodeEnum(e.origin), reason: encodeEnum(e.reason), ...(e.release instanceof Some ? { release: encodeRelease(e.release) } : {}) };
  if (e instanceof m.SnapRequested) return { ...base, type: 'snap-requested', requestId: e.request_id, origin: encodeEnum(e.origin), snapPoint: e.snap_point, ...(e.release instanceof Some ? { release: encodeRelease(e.release) } : {}) };
  if (e instanceof m.TargetSynced) return { ...base, type: 'target-synced', target: encodeTarget(e.target) };
  if (e instanceof m.Destroyed) return { ...base, type: 'destroyed' };
  if (e instanceof m.InteractionStarted || e instanceof m.InteractionEnded || e instanceof m.InteractionCancelled) {
    return { ...base, interactionId: e.interaction_id, origin: encodeEnum(e.origin),
      type: e instanceof m.InteractionStarted ? 'interaction-started' : e instanceof m.InteractionEnded ? 'interaction-ended' : 'interaction-cancelled',
      ...(e instanceof m.InteractionCancelled ? { reason: encodeEnum(e.reason) } : {}),
    };
  }
  return { ...base, targetId: e.target_id, transitionId: e.transition_id,
    type: e instanceof m.TransitionStarted ? 'transition-started' : e instanceof m.TransitionSettled ? 'transition-settled' : e instanceof m.TransitionReplaced ? 'transition-replaced' : 'transition-cancelled',
    ...(e instanceof m.TransitionReplaced ? { replacedBy: e.replaced_by } : {}),
    ...(e instanceof m.TransitionCancelled ? { reason: encodeEnum(e.reason) } : {}),
  };
}

// This shell owns only subscriptions and delivery. State transitions, ids,
// validation, release consumption and publication snapshots belong to core.gleam.
function createController(initial) {
  let state = unresult(core.new$(initial));
  const listeners = new Set();
  const queue = [];
  let dispatching = false;
  function dispatch(command) {
    const change = unresult(core.update(state, command));
    state = change.state;
    for (const p of change.publications) queue.push([nativeSnapshot(p.snapshot), nativeEvent(p.event)]);
    if (!dispatching) {
      dispatching = true;
      const errors = [];
      try {
        while (queue.length) {
          const [snapshot, event] = queue.shift();
          for (const listener of [...listeners]) {
            try { listener(snapshot, event); } catch (error) { errors.push(error); }
          }
        }
      } finally {
        dispatching = false;
        if (core.snapshot(state).phase instanceof m.DestroyedPhase) listeners.clear();
      }
      if (errors.length === 1) throw errors[0];
      if (errors.length > 1) throw new AggregateError(errors, 'Drawer listeners failed');
    }
    return unwrap(change.token);
  }
  const closeOrigin = reason => ({ escape: 'keyboard', backdrop: 'backdrop', gesture: 'gesture', 'close-button': 'close-button' })[reason] ?? 'api';
  return {
    sync: target => dispatch(new core.Sync(originals.get(target))),
    getSnapshot: () => nativeSnapshot(core.snapshot(state)),
    subscribe(listener) {
      if (core.snapshot(state).phase instanceof m.DestroyedPhase) return () => {};
      listeners.add(listener);
      return () => { listeners.delete(listener); };
    },
    requestOpen: (origin = 'api') => dispatch(new core.RequestOpen(RequestOrigin[origin]())),
    requestClose: (reason, details = {}) => dispatch(new core.RequestClose(CloseReason[reason](), RequestOrigin[details.origin ?? closeOrigin(reason)](), mapOptional(details.release, decodeRelease))),
    requestSnap: (point, details) => dispatch(new core.RequestSnap(point, RequestOrigin[details.origin](), mapOptional(details.release, decodeRelease))),
    beginTransition: id => dispatch(new core.BeginTransition(id)),
    settleTransition: id => { dispatch(new core.SettleTransition(id)); },
    cancelTransition: (id, reason) => { dispatch(new core.CancelTransition(id, TransitionCancelReason[reason]())); },
    beginInteraction: origin => dispatch(new core.BeginInteraction(InteractionOrigin[origin]())),
    endInteraction: id => { dispatch(new core.EndInteraction(id)); },
    cancelInteraction: (id, reason) => { dispatch(new core.CancelInteraction(id, InteractionCancelReason[reason]())); },
    destroy: () => { dispatch(new core.Destroy()); },
  };
}
