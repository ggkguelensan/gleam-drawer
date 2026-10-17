# Upstream provenance

`dom/` is adapted from the browser driver at
https://github.com/ggkguelensan/bottom-sheet/tree/0ad6309d34f0f2547be443e2452a2f2d51438309/packages/dom/src
(commit `0ad6309d34f0f2547be443e2452a2f2d51438309`).

The original TypeScript core is preserved separately in `tests/reference/core`
from the same commit, exclusively for differential tests. Production core
behavior is implemented in `src/gleam_drawer/core.gleam`, `geometry.gleam` and
`internal/validate.gleam`.

`npm run build:engine` bundles only the DOM driver. Imports of
`@shell-sheet/core` are redirected to `core_bridge.mjs`, which converts values
and calls Gleam geometry. Generated output is checked into
`src/gleam_drawer/internal/engine.mjs`; do not edit it by hand.

Local changes fix gesture ownership: early pointer capture, one displacement per
frame, translation below the lowest snap, interruption of active animations, and
continuous reconciliation after release. Preserve these changes when updating.

To update the browser driver, reconcile `dom/` from a single upstream revision,
update this provenance, rebuild, and run the complete checks. Update the test
oracle deliberately when adopting core contract changes. React, Effector and
Motion adapters are not included.

The upstream repository has no license file at this revision. This adaptation
does not assign a new license to its code.
