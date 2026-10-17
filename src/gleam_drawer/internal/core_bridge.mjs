// Representation adapter for the browser driver. All algorithms live in Gleam.
import * as geometry from '../geometry.mjs';
import * as m from '../model.mjs';
import { Ok, toList } from '../../gleam.mjs';
import { Some, None } from '../../../gleam_stdlib/gleam/option.mjs';
const option = value => value == null ? new None() : new Some(value);
const unwrap = result => { if (result instanceof Ok) return result[0]; throw new Error(result[0]); };
export function resolveSnapPoints(points, v) {
  const definitions = toList(points.map(p => new m.SnapPoint(p.id,
    p.size.type === 'ratio' ? new m.Ratio(p.size.value)
      : p.size.type === 'pixels' ? new m.Pixels(p.size.value)
      : new m.ContentSize(option(p.size.maxRatio)))));
  return unwrap(geometry.resolve_snap_points(definitions, new m.Metrics(
    v.viewportHeight, v.insetTop, v.insetBottom, v.headerHeight,
    v.bodyNaturalHeight, v.footerHeight, option(v.minHeight), option(v.maxHeight),
  ))).toArray().map(p => ({ id: p.id, height: p.height, declarationIndex: p.declaration_index }));
}
export function selectReleaseDestination(o) {
  const lowest = Math.min(...o.snapPoints.map(p => p.height));
  const destination = unwrap(geometry.select_release(new m.ReleaseOptions(
    o.currentHeight, o.activeSnapPoint, o.velocity, o.dragDistance,
    toList(o.snapPoints.map(p => new m.ResolvedSnapPoint(p.id, p.height, p.declarationIndex))),
    o.allowClose ?? false, o.snapToSequentialPoints ?? false,
    o.projectionTime ?? 180, o.closeVelocityThreshold ?? 0.7,
    o.closeDistanceThreshold ?? Math.min(96, lowest * 0.25),
  )));
  return destination instanceof m.CloseDestination ? { type: 'close' } : { type: 'snap', snapPoint: destination.id };
}
export function applyRubberBand(o) {
  return unwrap(geometry.rubber_band(o.value, o.min, o.max, o.dimension, o.constant ?? 0.55));
}
