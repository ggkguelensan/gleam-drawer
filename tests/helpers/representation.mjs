import * as m from '../../build/dev/javascript/gleam_drawer/gleam_drawer/model.mjs';
import { Some } from '../../build/dev/javascript/gleam_stdlib/gleam/option.mjs';
const unwrap = value => value instanceof Some ? value[0] : undefined;
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


export { nativeSnapshot, nativeEvent };

function encodeRelease(r) {
  return { interactionId: r[0].interaction_id, distance: r[0].distance,
    velocity: r[0].velocity, projectedHeight: r[0].projected_height };
}
