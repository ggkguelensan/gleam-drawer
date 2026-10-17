@target(javascript)
/// Target-driven drawer controller. Browser effects live in gleam_drawer/dom.
/// All fallible operations return Result; requests never change the target.
import gleam/list
import gleam/option
@target(javascript)
import gleam/result
@target(javascript)
import gleam/string
@target(javascript)
import gleam_drawer/browser/platform as b
@target(javascript)
import gleam_drawer/core
import gleam_drawer/model as m

@target(javascript)
pub opaque type Controller {
  Controller(
    state: b.Ref(core.State),
    listeners: b.Ref(List(#(Int, fn(m.Snapshot, m.Event) -> Nil))),
    queue: b.Ref(List(core.Publication)),
    dispatching: b.Ref(Bool),
    next_listener: b.Ref(Int),
  )
}

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
pub fn create(initial: option.Option(m.Target)) -> Result(Controller, String) {
  use state <- result.try(core.new(initial))
  Ok(Controller(b.ref(state), b.ref([]), b.ref([]), b.ref(False), b.ref(0)))
}

@target(javascript)
fn drain(c: Controller, errors: List(String)) -> List(String) {
  case b.get(c.queue) {
    [] -> errors
    [publication, ..rest] -> {
      b.set(c.queue, rest)
      let errors =
        list.fold(b.get(c.listeners), errors, fn(errors, listener) {
          case
            b.attempt(fn() {
              listener.1(publication.snapshot, publication.event)
            })
          {
            Ok(_) -> errors
            Error(message) -> [message, ..errors]
          }
        })
      drain(c, errors)
    }
  }
}

@target(javascript)
pub fn dispatch(
  c: Controller,
  command: core.Command,
) -> Result(option.Option(Int), String) {
  use change <- result.try(core.update(b.get(c.state), command))
  b.set(c.state, change.state)
  b.set(c.queue, list.append(b.get(c.queue), change.publications))
  case b.get(c.dispatching) {
    True -> Ok(change.token)
    False -> {
      b.set(c.dispatching, True)
      let errors = drain(c, [])
      b.set(c.dispatching, False)
      case snapshot(c).phase {
        m.DestroyedPhase -> b.set(c.listeners, [])
        _ -> Nil
      }
      case errors {
        [] -> Ok(change.token)
        _ -> Error(string.join(list.reverse(errors), "\n"))
      }
    }
  }
}

@target(javascript)
pub fn snapshot(c: Controller) -> m.Snapshot {
  core.snapshot(b.get(c.state))
}

@target(javascript)
pub fn subscribe(
  c: Controller,
  listener: fn(m.Snapshot, m.Event) -> Nil,
) -> Cleanup {
  case snapshot(c).phase {
    m.DestroyedPhase -> fn() { Nil }
    _ -> {
      let id = b.get(c.next_listener) + 1
      b.set(c.next_listener, id)
      b.set(c.listeners, list.append(b.get(c.listeners), [#(id, listener)]))
      fn() {
        b.set(
          c.listeners,
          list.filter(b.get(c.listeners), fn(pair) { pair.0 != id }),
        )
      }
    }
  }
}

@target(javascript)
fn token(c: Controller, command: core.Command) -> Result(Int, String) {
  use value <- result.try(dispatch(c, command))
  case value {
    option.Some(id) -> Ok(id)
    _ -> Error("Command returned no token")
  }
}

@target(javascript)
fn unit(c: Controller, command: core.Command) -> Result(Nil, String) {
  dispatch(c, command) |> result.map(fn(_) { Nil })
}

@target(javascript)
pub fn sync(c: Controller, target: m.Target) -> Result(Nil, String) {
  unit(c, core.Sync(target))
}

@target(javascript)
pub fn request_open(
  c: Controller,
  origin: m.RequestOrigin,
) -> Result(Int, String) {
  token(c, core.RequestOpen(origin))
}

@target(javascript)
pub fn request_close(
  c: Controller,
  reason: m.CloseReason,
  origin: m.RequestOrigin,
  release: option.Option(m.Release),
) -> Result(Int, String) {
  token(c, core.RequestClose(reason, origin, release))
}

@target(javascript)
pub fn request_snap(
  c: Controller,
  point: String,
  origin: m.RequestOrigin,
  release: option.Option(m.Release),
) -> Result(Int, String) {
  token(c, core.RequestSnap(point, origin, release))
}

@target(javascript)
pub fn begin_transition(c: Controller, id: String) -> Result(Int, String) {
  token(c, core.BeginTransition(id))
}

@target(javascript)
pub fn settle_transition(c: Controller, id: Int) -> Result(Nil, String) {
  unit(c, core.SettleTransition(id))
}

@target(javascript)
pub fn cancel_transition(
  c: Controller,
  id: Int,
  reason: m.TransitionCancelReason,
) -> Result(Nil, String) {
  unit(c, core.CancelTransition(id, reason))
}

@target(javascript)
pub fn begin_interaction(
  c: Controller,
  origin: m.InteractionOrigin,
) -> Result(Int, String) {
  token(c, core.BeginInteraction(origin))
}

@target(javascript)
pub fn end_interaction(c: Controller, id: Int) -> Result(Nil, String) {
  unit(c, core.EndInteraction(id))
}

@target(javascript)
pub fn cancel_interaction(
  c: Controller,
  id: Int,
  reason: m.InteractionCancelReason,
) -> Result(Nil, String) {
  unit(c, core.CancelInteraction(id, reason))
}

@target(javascript)
pub fn destroy(c: Controller) -> Result(Nil, String) {
  unit(c, core.Destroy)
}
