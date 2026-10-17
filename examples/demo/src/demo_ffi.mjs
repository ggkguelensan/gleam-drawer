export function on_click(selector, callback) {
  const element = document.querySelector(selector);
  // Safari does not focus buttons on pointer activation. Make the demo's
  // trigger an explicit focus origin before the modal acquires its focus lease.
  const listener = () => { element.focus({ preventScroll: true }); callback(); };
  element.addEventListener('click', listener);
  return () => element.removeEventListener('click', listener);
}
export function on_dispose(callback) {
  window.addEventListener('pagehide', event => { if (!event.persisted) callback(); }, { once: true });
  if (import.meta.hot) import.meta.hot.dispose(callback);
}
export function set_status(status) {
  document.querySelector('#status').textContent = status;
}
