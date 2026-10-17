/// Target-driven drawer controller. Browser effects live in gleam_drawer/dom.
/// All fallible operations return Result; requests never change the target.
import gleam/option
import gleam_drawer/model as m

pub type Controller

/// Cleanup functions are idempotent. Call these when unmounting a consumer.
pub type Cleanup =
  fn() -> Nil

pub fn transition(cause: m.TransitionCause) -> m.Transition {
  m.Transition(cause, m.NoDirection, m.Auto)
}

/// Start with a modal, draggable sheet and preserved region identities.
pub fn options(points: List(m.SnapPoint), selected: String) -> m.OpenOptions {
  m.OpenOptions(
    points,
    selected,
    m.Sheet,
    m.Modal,
    True,
    False,
    m.Animate,
    m.Regions(
      m.RegionTarget("header", m.Preserve),
      m.RegionTarget("body", m.Preserve),
      m.RegionTarget("footer", m.Preserve),
    ),
  )
}

pub fn closed(id: String) -> m.Target {
  m.Closed(id, transition(m.CloseCause), option.None)
}

pub fn opened(id: String, options: m.OpenOptions) -> m.Target {
  m.Open(id, options, transition(m.OpenCause), option.None)
}

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "create")
pub fn create(initial: option.Option(m.Target)) -> Result(Controller, String)

@target(javascript)
/// Equal current Target values are idempotent (Gleam value semantics). Every
/// change needs a new id; old ids cannot be reused during this lifecycle.
@external(javascript, "./gleam_drawer_ffi.mjs", "sync")
pub fn sync(controller: Controller, target: m.Target) -> Result(Nil, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "snapshot")
pub fn snapshot(controller: Controller) -> m.Snapshot

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "subscribe")
pub fn subscribe(
  controller: Controller,
  listener: fn(m.Snapshot, m.Event) -> Nil,
) -> Cleanup

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "request_open")
pub fn request_open(
  controller: Controller,
  origin: m.RequestOrigin,
) -> Result(Int, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "request_close")
pub fn request_close(
  controller: Controller,
  reason: m.CloseReason,
  origin: m.RequestOrigin,
  release: option.Option(m.Release),
) -> Result(Int, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "request_snap")
pub fn request_snap(
  controller: Controller,
  snap_point: String,
  origin: m.RequestOrigin,
  release: option.Option(m.Release),
) -> Result(Int, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "begin_transition")
pub fn begin_transition(
  controller: Controller,
  target_id: String,
) -> Result(Int, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "settle_transition")
pub fn settle_transition(controller: Controller, id: Int) -> Result(Nil, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "cancel_transition")
pub fn cancel_transition(
  controller: Controller,
  id: Int,
  reason: m.TransitionCancelReason,
) -> Result(Nil, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "begin_interaction")
pub fn begin_interaction(
  controller: Controller,
  origin: m.InteractionOrigin,
) -> Result(Int, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "end_interaction")
pub fn end_interaction(controller: Controller, id: Int) -> Result(Nil, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "cancel_interaction")
pub fn cancel_interaction(
  controller: Controller,
  id: Int,
  reason: m.InteractionCancelReason,
) -> Result(Nil, String)

@target(javascript)
@external(javascript, "./gleam_drawer_ffi.mjs", "destroy")
pub fn destroy(controller: Controller) -> Result(Nil, String)
