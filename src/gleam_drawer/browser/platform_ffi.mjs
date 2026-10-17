// Runtime/DOM interop only. Drawer decisions and lifecycle live in Gleam.
import { Ok, Error as GleamError, toList } from '../../gleam.mjs';
import { Some, None } from '../../../gleam_stdlib/gleam/option.mjs';
import { Rect, Viewport } from './platform.mjs';
const option = value => value == null ? new None() : new Some(value);
export const ref = value => ({ value });
export const get = ref => ref.value;
export const set = (ref, value) => { ref.value = value; };
export const attempt = fn => { try { return new Ok(fn()); } catch (e) { return new GleamError(String(e?.message ?? e)); } };
export const raise = message => { throw new Error(message); };
const stores = new WeakMap();
export function shared(element, key, initial) {
  let entries = stores.get(element);
  if (!entries) { entries = new Map(); stores.set(element, entries); }
  if (!entries.has(key)) entries.set(key, ref(initial()));
  return entries.get(key);
}
export const same = (a, b) => a === b;
export const find = selector => attempt(() => {
  const el = globalThis.document?.querySelector(selector);
  if (!el || !(el instanceof el.ownerDocument.defaultView.HTMLElement)) throw new Error(`HTMLElement not found: ${selector}`);
  return el;
});
export const query = (el, selector) => toList([...el.querySelectorAll(selector)]);
export const closest = (el, selector) => option(el.closest(selector));
export const siblings = el => toList([...(el.parentElement?.children ?? [])]);
export const contains = (a, b) => a.contains(b);
export const connected = el => el.isConnected;
export const body = el => el.ownerDocument.body;
export const active_element = el => option(el.ownerDocument.activeElement);
export const focus = el => { el.focus({ preventScroll: true }); };
export const attribute = (el, name) => option(el.getAttribute(name));
export const set_attribute = (el, name, value) => { if (value instanceof Some) el.setAttribute(name, value[0]); else el.removeAttribute(name); };
export const style = (el, name) => [el.style.getPropertyValue(name), el.style.getPropertyPriority(name)];
export const set_style = (el, name, value, priority) => { el.style.setProperty(name, value, priority); };
export const computed = (el, name) => el.ownerDocument.defaultView.getComputedStyle(el).getPropertyValue(name);
export const rect = el => { const r = el.getBoundingClientRect(); return new Rect(r.x, r.y, r.width, r.height); };
export const scroll_height = el => el.scrollHeight;
export const layout_viewport = el => { const w = el.ownerDocument.defaultView; return new Viewport(0, 0, w.innerWidth, w.innerHeight); };
export const visual_viewport = el => { const v = el.ownerDocument.defaultView.visualViewport; return v ? new Some(new Viewport(v.offsetLeft, v.offsetTop, v.width, v.height)) : new None(); };
export const client_width = el => el.ownerDocument.documentElement.clientWidth;
export const scroll_position = el => { const w = el.ownerDocument.defaultView; return [w.scrollX, w.scrollY]; };
export const scroll_to = (el, x, y) => { el.ownerDocument.defaultView.scrollTo(x, y); };
export const reduced_motion = el => el.ownerDocument.defaultView.matchMedia('(prefers-reduced-motion: reduce)').matches;
export const visible = el => el.ownerDocument.visibilityState === 'visible';
export const supported = el => { const w = el.ownerDocument.defaultView; return !!(w?.ResizeObserver && w.requestAnimationFrame && w.PointerEvent && w.matchMedia && el.animate); };
export const frame = (el, fn) => el.ownerDocument.defaultView.requestAnimationFrame(() => fn());
export const cancel_frame = (el, id) => { el.ownerDocument.defaultView.cancelAnimationFrame(id); };
export const microtask = fn => { queueMicrotask(fn); };
export const listen = (el, name, fn) => { el.addEventListener(name, fn); return () => { el.removeEventListener(name, fn); }; };
export const listen_document = (el, name, fn) => listen(el.ownerDocument, name, fn);
export const listen_viewport = (el, fn) => {
  const w = el.ownerDocument.defaultView, v = w.visualViewport;
  const off = [listen(w, 'resize', fn), listen(w, 'orientationchange', fn)];
  if (v) off.push(listen(v, 'resize', fn), listen(v, 'scroll', fn));
  return () => { for (const remove of off) remove(); };
};
export const observe_size = (el, nodes, fn) => {
  const observer = new el.ownerDocument.defaultView.ResizeObserver(() => fn());
  for (const node of nodes) observer.observe(node);
  return () => { observer.disconnect(); };
};
export const number = (event, field) => event[field];
export const integer = (event, field) => event[field];
export const boolean = (event, field) => event[field];
export const text = (event, field) => event[field];
export const event_target = event => option(event.target?.nodeType === 1 ? event.target : event.target?.parentElement);
export const prevent = event => { event.preventDefault(); };
export const capture = (el, id) => attempt(() => el.setPointerCapture(id));
export const release_capture = (el, id) => { el.releasePointerCapture(id); };
export const has_capture = (el, id) => el.hasPointerCapture(id);
export const animate = (el, frames, duration, easing, finished) => {
  const animation = el.animate(frames.toArray().map(frame => Object.fromEntries(frame.toArray().map(([k,v]) => [k, k === 'offset' ? Number(v) : v]))), { duration, easing, fill: 'both' });
  animation.finished.then(() => finished(true), () => finished(false));
  return animation;
};
export const stop = animation => { animation.cancel(); };
export const translation = el => { const value = computed(el, 'transform'); const m = new el.ownerDocument.defaultView.DOMMatrixReadOnly(value === 'none' ? undefined : value); return [m.m41, m.m42]; };
export const css_supports = (el, key, value) => el.ownerDocument.defaultView.CSS.supports(key, value);
