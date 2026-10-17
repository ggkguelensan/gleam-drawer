# Upstream provenance

`core/` preserves the TypeScript core from
[bottom-sheet commit 0ad6309d34f0f2547be443e2452a2f2d51438309](https://github.com/ggkguelensan/bottom-sheet/tree/0ad6309d34f0f2547be443e2452a2f2d51438309/packages/core/src),
exclusively for differential tests. Update this oracle deliberately when adopting
upstream contract changes.

Production behavior is implemented in Gleam: `src/gleam_drawer/core.gleam`,
`geometry.gleam`, `internal/validate.gleam`, the imperative controller and
`browser/*.gleam`. The former adapted TypeScript DOM driver and its generated
bundle have been removed. Only primitive browser/runtime operations use JS FFI.
React, Effector and Motion adapters are not included.

The port retains the drag fixes: early pointer capture, one displacement per
frame, translation below the lowest snap, interruption of active animations,
and continuous reconciliation after release. Browser tests cover these behaviors.

The upstream repository has no license file at this revision. This adaptation
does not assign a new license to its code.
