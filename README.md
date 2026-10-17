# Gleam Drawer

A Gleam port of the [Shell Sheet bottom-sheet](https://github.com/ggkguelensan/bottom-sheet)
core, with its browser driver adapted through FFI. The controller state machine,
target validation, snap resolution, release selection and rubber-band algorithm
are implemented in Gleam. The pure core runs on **JavaScript and Erlang**; the
DOM binding runs in the browser.

## Architecture

```text
Original bottom-sheet                 gleam-drawer
TypeScript core                       Gleam core + geometry + validation
  └─ TypeScript DOM driver              └─ representation / event-delivery FFI
      └─ React / Effector adapters          └─ existing DOM driver (WAAPI)
                                                └─ Gleam application
```

- Atomic targets, application-owned open/close/snap decisions, ordered requests
  and facts, stale transition protection, cancellation and idempotent teardown.
- Ratio, pixel and content snap points; velocity projection, sequential snapping
  and rubber-band resistance.
- Browser drag gestures, independently scrolling body, keyed region transitions,
  sheet/dialog morphing, reduced motion, focus trapping/restoration, background
  isolation and scroll locking from the upstream DOM driver.
- No React, Effector, Motion or npm runtime dependencies. The browser driver is
  bundled in the package; rebuilding it requires the development tools below.

`tests/reference/core` contains the frozen TypeScript core **only as a test
oracle**. It is never imported by the shipped driver. Source provenance and the
upstream revision are recorded in [vendor/README.md](vendor/README.md).

## Run the example

Install Gleam 1.19.2 and Node 24 or newer, then:

```sh
npm ci
npm run dev
```

Open the URL printed by Vite. The example's state decisions and event handling
are in [drawer_demo.gleam](examples/demo/src/drawer_demo.gleam). Try dragging the
handle, Resize, Fit content, Sheet ↔ Dialog, Escape and Done. Input state survives
presentation changes.

## Use from Gleam

Until a package release is published, clone this repository beside your app and
add a path dependency to the application's `gleam.toml`:

```toml
[dependencies]
gleam_drawer = { path = "../gleam-drawer" }
```

Create a controller and accept requests in your application:

```gleam
import gleam/int
import gleam/option.{None, Some}
import gleam_drawer as drawer
import gleam_drawer/model as m

pub fn start() {
  let options = drawer.options([
    m.SnapPoint("half", m.Ratio(0.5)),
    m.SnapPoint("full", m.Ratio(0.9)),
  ], "half")
  let assert Ok(controller) = drawer.create(Some(drawer.closed("initial")))
  let unsubscribe = drawer.subscribe(controller, fn(_, event) {
    case event {
      m.OpenRequested(_, id, _) -> {
        let assert Ok(_) = drawer.sync(controller,
          m.Open("open-" <> int.to_string(id), options,
            drawer.transition(m.OpenCause), Some(id)))
        Nil
      }
      m.CloseRequested(_, id, _, _, _) -> {
        let assert Ok(_) = drawer.sync(controller,
          m.Closed("close-" <> int.to_string(id),
            drawer.transition(m.CloseCause), Some(id)))
        Nil
      }
      _ -> Nil
    }
  })
  // Register the browser parts before opening. This example rejects snap
  // requests by leaving the authoritative target unchanged.
  #(controller, unsubscribe)
}
```

Requests never change the target themselves. Accept one with `drawer.sync`, or
leave the target unchanged to reject it. Every observable target change needs a
new ID. **Equal current targets are no-ops by Gleam value semantics** (upstream
uses JavaScript reference identity); previously used IDs cannot be recycled.
`Preserve` regions must retain their keys.

Fallible operations return `Result(_, String)`. Subscriber exceptions are
reported after the remaining listeners have received their queued publications;
a listener failure does not roll back an already accepted command.

### Browser registration

`gleam_drawer/dom` accepts opaque DOM elements; `find_element` provides a simple
selector-based entry point. Call `bind`, then register `Portal` first, followed
by `Viewport`, `Popup`, `Content`, `Header`, `Body`, `Footer`, and `Backdrop` for
modal targets. Register a matching `Settled` layer for **each region key**, even
if a region is empty. Add `Handle` and an explicit `InertTarget` as needed.

```text
Portal
├── Backdrop
└── Viewport
    └── Popup [aria-labelledby="title"]
        └── Content
            ├── Header → Handle + header layer
            ├── Body   → body layer (scrollable)
            └── Footer → footer layer
```

The app supplies the accessible name, markup and theme CSS. Keep the inert
background outside the portal. The driver owns geometry/transform timing; do
not add CSS transitions to those properties. The example stylesheet demonstrates
`data-presentation`, `--drawer-height`, and `--drawer-swipe-movement-y`.

Registration functions return cleanup callbacks. On unmount, unsubscribe,
release registrations, destroy the binding, then destroy the controller. Bind
and register after the browser framework mounts the elements; destroy before
it removes them. No browser globals are read at module import time.

The initial adapter uses the stock WAAPI/environment/modality drivers and
exposes dismissal options and insets. Custom animation/environment injection
and framework-specific Lustre components are not part of this API.

### Pure state machine

For application-owned state or server-side testing, use `gleam_drawer/core`:

```gleam
let assert Ok(state) = core.new(Some(drawer.closed("initial")))
let assert Ok(change) = core.update(state, core.RequestOpen(m.Trigger))
// change.state is the new immutable state.
// change.publications contain typed events with their original snapshots.
// change.token contains a request/transition/interaction ID when applicable.
```

This module and `gleam_drawer/geometry` use no FFI. The imperative controller
only hosts that state and delivers its publications to browser subscribers.

## Verification

```sh
npx playwright install chromium webkit
npm run check
```

The checks build the library and demo, run Gleam tests on JavaScript and Erlang,
exercise the FFI and SSR import, compare geometry against the original on 1000
deterministic cases, compare lifecycle events/snapshots, and run browser scenarios
in desktop Chromium and mobile WebKit. Browser tests cover open/close, snapping,
presentation morphing, state preservation, focus restoration, backdrop dismissal,
reduced motion and dragging.

Run `npm run build:engine` after updating the vendored DOM sources. The generated
`src/gleam_drawer/internal/engine.mjs` is checked in for Gleam-only consumers.
CI verifies regeneration produces no diff. No package or website is published
by the build.
