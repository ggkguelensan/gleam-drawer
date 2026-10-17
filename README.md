# Gleam Drawer

A Gleam port of [Shell Sheet bottom-sheet](https://github.com/ggkguelensan/bottom-sheet).
All drawer behavior is implemented in Gleam, including the browser driver.
The pure state machine and geometry run on **JavaScript and Erlang**; the
imperative controller and DOM binding target browser JavaScript.

## Architecture

```text
Original bottom-sheet                 gleam-drawer
TypeScript core                       Gleam core + geometry + validation
  └─ TypeScript DOM driver              └─ Gleam controller + browser runtime
      └─ React / Effector adapters          ├─ gesture / motion / view
                                           ├─ registry / modality / ledger
                                           └─ platform.gleam
                                               └─ primitive browser FFI
```

- Atomic targets, application-owned open/close/snap decisions, queued subscriber
  delivery, stale transition protection, cancellation and idempotent teardown.
- Ratio, pixel and content snap points; velocity projection, sequential snapping
  and rubber-band resistance.
- Pointer capture, frame scheduling, drag tracking and animation interruption.
- Keyed region crossfades, sheet/dialog morphing, content resize policies and
  reduced motion, using the browser's Web Animations API.
- Focus trapping/restoration, background isolation, reference-counted scroll
  locking, registration cleanup and restoration of owned styles/attributes.
- No TypeScript runtime, bundled upstream driver, React, Effector, Motion or npm
  runtime dependencies.

`src/gleam_drawer/browser/platform_ffi.mjs` is the sole handwritten JavaScript
file in the library. It exposes DOM access, event listeners, mutable references,
observers, animation clocks and other browser primitives. Gesture thresholds,
animation keyframes, state transitions and accessibility policy live in Gleam.
`npm run check:boundary` guards this source boundary.

`tests/reference/core` preserves the upstream TypeScript core **only as a test
oracle**, never as production code. See [source provenance](tests/reference/README.md).

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

The native Gleam binding exposes dismissal options and insets. Custom
animation/environment injection and framework-specific Lustre components are
not part of this API.

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

The checks enforce the primitive FFI boundary, build the library and demo,
run Gleam tests on JavaScript and Erlang, exercise controller subscriptions and
SSR imports, compare geometry against the original on 1000 deterministic cases,
and compare lifecycle events/snapshots.

Browser scenarios run in desktop Chromium and mobile WebKit. They cover
open/close, snapping, morphing, input preservation, focus restoration, reduced
motion, fast drag tracking, release continuity, interrupted animations, dynamic
region registration, superseded targets, resize policies, nested lock ownership
and teardown. The CDP touch-input scenario runs only in Chromium.

`npm run build` needs no generated engine or vendored DOM sources. Browser-test
fixtures are bundled separately into `dist` by `npm run test:browser`; they are
not library runtime code. No package or website is published by the build.
