@target(javascript)
import gleam/list
@target(javascript)
import gleam/option.{type Option, None, Some}
@target(javascript)
import gleam_drawer as d
@target(javascript)
import gleam_drawer/browser/gesture
@target(javascript)
import gleam_drawer/browser/ledger as l
@target(javascript)
import gleam_drawer/browser/modality as modal
@target(javascript)
import gleam_drawer/browser/motion
@target(javascript)
import gleam_drawer/browser/platform as b
@target(javascript)
import gleam_drawer/browser/registry as r
@target(javascript)
import gleam_drawer/browser/view as v
@target(javascript)
import gleam_drawer/internal/validate
@target(javascript)
import gleam_drawer/model as m

@target(javascript)
pub type State {
  State(
    registry: r.Registry,
    alive: Bool,
    top: Float,
    bottom: Float,
    motion: Option(motion.Motion),
    gesture: Option(gesture.Gesture),
    cleanups: List(b.Cleanup),
    unsubscribe: b.Cleanup,
    lease: modal.Lease,
    focus: Option(b.Element),
  )
}

@target(javascript)
pub opaque type Binding {
  Binding(
    controller: d.Controller,
    escape: Bool,
    backdrop: Bool,
    ledger: l.Ledger,
    state: b.Ref(State),
  )
}

@target(javascript)
pub fn new(
  controller: d.Controller,
  escape: Bool,
  backdrop: Bool,
) -> Result(Binding, String) {
  b.attempt(fn() {
    let binding =
      Binding(
        controller,
        escape,
        backdrop,
        l.new(),
        b.ref(State(
          r.new(),
          True,
          0.0,
          0.0,
          None,
          None,
          [],
          fn() { Nil },
          modal.new(),
          None,
        )),
      )
    let animation =
      motion.new(
        controller,
        fn() { b.get(binding.state).registry },
        binding.ledger,
        fn() {
          let state = b.get(binding.state)
          #(state.top, state.bottom)
        },
        before(binding, _),
        settled(binding, _),
        fn() { hidden(binding) },
      )
    let gesture =
      gesture.new(
        controller,
        fn() { b.get(binding.state).registry },
        fn() { motion.geometry(animation) },
        fn() { motion.interrupt(animation) },
        fn() { motion.schedule(animation) },
        binding.ledger,
      )
    let unsubscribe =
      d.subscribe(controller, fn(_, event) {
        case b.get(binding.state).alive, event {
          True, m.TargetSynced(..) -> {
            gesture.cancel(gesture, m.TargetChanged, False)
            gesture.refresh(gesture)
            motion.schedule(animation)
          }
          _, _ -> Nil
        }
      })
    b.set(
      binding.state,
      State(
        ..b.get(binding.state),
        motion: Some(animation),
        gesture: Some(gesture),
        unsubscribe: unsubscribe,
      ),
    )
    binding
  })
}

@target(javascript)
fn before(binding: Binding, snapshot: m.Snapshot) {
  let state = b.get(binding.state)
  case
    v.visual(snapshot),
    r.part(state.registry, m.Popup),
    r.part(state.registry, m.Portal)
  {
    Some(target), Some(popup), Some(portal) -> {
      let focus = case state.focus, snapshot.settled_target {
        None, None -> b.active_element(popup)
        _, _ -> state.focus
      }
      l.attribute(binding.ledger, popup, "role", Some("dialog"))
      let lease = case v.options(target).modality {
        m.Modal -> {
          l.attribute(binding.ledger, popup, "aria-modal", Some("true"))
          modal.acquire(
            state.lease,
            popup,
            portal,
            r.part(state.registry, m.InertTarget),
            binding.ledger,
          )
        }
        m.NonModal -> {
          l.attribute(binding.ledger, popup, "aria-modal", None)
          state.lease
        }
      }
      v.style(
        state.registry,
        binding.ledger,
        m.Backdrop,
        "pointer-events",
        case v.options(target).modality {
          m.Modal -> ""
          m.NonModal -> "none"
        },
      )
      b.set(
        binding.state,
        State(..b.get(binding.state), lease: lease, focus: focus),
      )
    }
    _, _, _ -> Nil
  }
}

@target(javascript)
fn settled(binding: Binding, snapshot: m.Snapshot) {
  case snapshot.target {
    Some(m.Open(_, options, _, _)) if options.modality == m.NonModal -> {
      let state = b.get(binding.state)
      let lease = modal.release(state.lease, True)
      b.set(binding.state, State(..b.get(binding.state), lease: lease))
    }
    _ -> Nil
  }
}

@target(javascript)
fn hidden(binding: Binding) {
  let state = b.get(binding.state)
  let lease = modal.release(state.lease, False)
  v.attr(state.registry, binding.ledger, m.Popup, "aria-modal", None)
  case state.focus {
    Some(element) ->
      case b.connected(element) {
        True -> b.focus(element)
        False -> Nil
      }
    None -> Nil
  }
  b.set(binding.state, State(..b.get(binding.state), lease: lease, focus: None))
}

@target(javascript)
fn ensure(binding: Binding) {
  case b.get(binding.state).alive {
    True -> Nil
    False -> b.raise("Drawer DOM binding has been destroyed")
  }
}

@target(javascript)
pub fn register(
  binding: Binding,
  slot: r.Slot,
  element: b.Element,
) -> Result(b.Cleanup, String) {
  b.attempt(fn() {
    ensure(binding)
    case slot {
      r.Part(m.Portal) ->
        case b.supported(element) {
          True -> Nil
          False ->
            b.raise(
              "Drawer requires ResizeObserver, Pointer Events, RAF and Web Animations",
            )
        }
      _ -> Nil
    }
    let state = b.get(binding.state)
    let registry = r.add(state.registry, slot, element)
    let token = registry.token
    let assert [entry, ..] = registry.entries
    v.initialize(entry, binding.ledger)
    case slot {
      r.Part(m.Portal) ->
        case d.snapshot(binding.controller).phase {
          m.OpenPhase | m.Closing -> Nil
          _ -> l.attribute(binding.ledger, element, "hidden", Some(""))
        }
      _ -> Nil
    }
    b.set(binding.state, State(..state, registry: registry))
    changed(binding)
    fn() {
      let state = b.get(binding.state)
      case
        state.alive
        && list.any(state.registry.entries, fn(entry) { entry.token == token })
      {
        False -> Nil
        True -> {
          case state.gesture {
            Some(g) -> gesture.cancel(g, m.CaptureLost, True)
            _ -> Nil
          }
          b.set(
            binding.state,
            State(
              ..b.get(binding.state),
              registry: r.remove(state.registry, token),
            ),
          )
          changed(binding)
        }
      }
    }
  })
}

@target(javascript)
fn changed(binding: Binding) {
  let state = b.get(binding.state)
  list.each(state.cleanups, fn(cleanup) { cleanup() })
  let assert Some(animation) = state.motion
  let assert Some(gesture) = state.gesture
  gesture.refresh(gesture)
  let cleanups = case r.part(state.registry, m.Portal) {
    None -> []
    Some(portal) -> {
      let listeners = [
        b.observe_size(
          portal,
          list.map(state.registry.entries, fn(e) { e.element }),
          fn() { motion.schedule(animation) },
        ),
        b.listen_viewport(portal, fn() { motion.schedule(animation) }),
        b.listen_document(portal, "visibilitychange", fn(_) {
          case b.visible(portal) {
            True -> Nil
            False -> gesture.cancel(gesture, m.VisibilityLost, True)
          }
        }),
        b.listen_document(portal, "keydown", keydown(binding, _)),
      ]
      case r.part(state.registry, m.Backdrop) {
        Some(backdrop) -> [
          b.listen(backdrop, "click", fn(event) {
            case b.event_target(event), d.snapshot(binding.controller).target {
              Some(target), Some(m.Open(_, o, _, _)) if o.modality == m.Modal -> {
                case binding.backdrop && b.same(target, backdrop) {
                  True -> {
                    let _ =
                      d.request_close(
                        binding.controller,
                        m.BackdropClose,
                        m.BackdropOrigin,
                        None,
                      )
                    Nil
                  }
                  False -> Nil
                }
              }
              _, _ -> Nil
            }
          }),
          ..listeners
        ]
        None -> listeners
      }
    }
  }
  b.set(binding.state, State(..b.get(binding.state), cleanups: cleanups))
  motion.schedule(animation)
}

@target(javascript)
fn keydown(binding: Binding, event: b.Event) {
  let state = b.get(binding.state)
  case d.snapshot(binding.controller).target, r.part(state.registry, m.Popup) {
    Some(m.Open(_, options, _, _)), Some(popup) -> {
      case b.text(event, "key") {
        "Escape" if binding.escape -> {
          b.prevent(event)
          let _ =
            d.request_close(binding.controller, m.Escape, m.Keyboard, None)
          Nil
        }
        "Tab" if options.modality == m.Modal ->
          modal.trap(popup, event, binding.ledger)
        _ -> Nil
      }
    }
    _, _ -> Nil
  }
}

@target(javascript)
pub fn insets(
  binding: Binding,
  top: Float,
  bottom: Float,
) -> Result(Nil, String) {
  b.attempt(fn() {
    ensure(binding)
    case validate.non_negative(top) && validate.non_negative(bottom) {
      False -> b.raise("Insets must be finite and non-negative")
      True -> Nil
    }
    let state = b.get(binding.state)
    case top == state.top && bottom == state.bottom {
      True -> Nil
      False -> {
        b.set(binding.state, State(..state, top: top, bottom: bottom))
        let assert Some(animation) = state.motion
        motion.schedule(animation)
      }
    }
  })
}

@target(javascript)
pub fn refresh(binding: Binding) -> Result(Nil, String) {
  b.attempt(fn() {
    ensure(binding)
    let assert Some(animation) = b.get(binding.state).motion
    motion.schedule(animation)
  })
}

@target(javascript)
pub fn destroy(binding: Binding) -> Result(Nil, String) {
  b.attempt(fn() {
    let state = b.get(binding.state)
    case state.alive {
      False -> Nil
      True -> {
        b.set(binding.state, State(..state, alive: False))
        let assert Some(animation) = state.motion
        let assert Some(gesture) = state.gesture
        // Disable scheduling before gesture cancellation requests reconciliation.
        motion.destroy(animation)
        gesture.destroy(gesture)
        state.unsubscribe()
        list.each(state.cleanups, fn(cleanup) { cleanup() })
        let _ = modal.release(state.lease, True)
        l.restore(binding.ledger)
        b.set(
          binding.state,
          State(
            ..b.get(binding.state),
            registry: r.new(),
            cleanups: [],
            focus: None,
            lease: modal.new(),
          ),
        )
      }
    }
  })
}
