@target(javascript)
import gleam/float
@target(javascript)
import gleam/int
@target(javascript)
import gleam/list
@target(javascript)
import gleam/option.{type Option, None, Some}
@target(javascript)
import gleam/result
@target(javascript)
import gleam_drawer as d
@target(javascript)
import gleam_drawer/browser/ledger as l
@target(javascript)
import gleam_drawer/browser/modality as modal
@target(javascript)
import gleam_drawer/browser/platform as b
@target(javascript)
import gleam_drawer/browser/registry as r
@target(javascript)
import gleam_drawer/browser/view as v
@target(javascript)
import gleam_drawer/geometry
@target(javascript)
import gleam_drawer/model as m

@target(javascript)
pub type Pointer {
  Pointer(
    id: Int,
    element: b.Element,
    origin: m.InteractionOrigin,
    x: Float,
    y: Float,
    height: Float,
    current: Float,
    interaction: Option(Int),
    frame: Option(Int),
    samples: List(#(Float, Float)),
  )
}

@target(javascript)
pub type Gesture {
  Gesture(
    controller: d.Controller,
    registry: fn() -> r.Registry,
    geometry: fn() -> Option(v.Geometry),
    interrupt: fn() -> Float,
    reconcile: fn() -> Nil,
    ledger: l.Ledger,
    pointer: b.Ref(Option(Pointer)),
    cleanups: b.Ref(List(b.Cleanup)),
    suppress_click: b.Ref(Bool),
    alive: b.Ref(Bool),
  )
}

@target(javascript)
pub fn new(
  controller: d.Controller,
  registry: fn() -> r.Registry,
  geometry: fn() -> Option(v.Geometry),
  interrupt: fn() -> Float,
  reconcile: fn() -> Nil,
  ledger: l.Ledger,
) {
  Gesture(
    controller,
    registry,
    geometry,
    interrupt,
    reconcile,
    ledger,
    b.ref(None),
    b.ref([]),
    b.ref(False),
    b.ref(True),
  )
}

@target(javascript)
fn release_capture(p: Pointer) {
  case b.has_capture(p.element, p.id) {
    True -> b.release_capture(p.element, p.id)
    False -> Nil
  }
}

@target(javascript)
pub fn cancel(g: Gesture, reason: m.InteractionCancelReason, notify: Bool) {
  case b.get(g.pointer) {
    None -> Nil
    Some(p) -> {
      b.set(g.pointer, None)
      case p.frame {
        Some(id) -> b.cancel_frame(p.element, id)
        _ -> Nil
      }
      release_capture(p)
      case p.interaction, notify {
        Some(id), True -> {
          let _ = d.cancel_interaction(g.controller, id, reason)
          Nil
        }
        _, _ -> Nil
      }
      v.toggle(g.registry(), g.ledger, m.Popup, "data-swiping", False)
      g.reconcile()
    }
  }
}

@target(javascript)
fn write(g: Gesture) {
  case b.get(g.pointer), g.geometry() {
    Some(p), Some(geometry) -> {
      b.set(g.pointer, Some(Pointer(..p, frame: None)))
      let lowest =
        list.first(geometry.points)
        |> result.map(fn(p) { p.height })
        |> result.unwrap(p.height)
      let height = float.max(lowest, p.current)
      let movement = height -. p.current
      v.style(g.registry(), g.ledger, m.Popup, "height", modal.px(height))
      v.style(
        g.registry(),
        g.ledger,
        m.Popup,
        "transform",
        "translateY(" <> modal.px(movement) <> ")",
      )
      v.style(
        g.registry(),
        g.ledger,
        m.Popup,
        "--drawer-swipe-movement-y",
        modal.px(movement),
      )
      v.style(
        g.registry(),
        g.ledger,
        m.Backdrop,
        "--drawer-swipe-progress",
        float.to_string(float.clamp(
          movement /. float.max(1.0, lowest),
          0.0,
          1.0,
        )),
      )
      v.toggle(
        g.registry(),
        g.ledger,
        m.Popup,
        "data-swipe-dismiss",
        p.current <. lowest,
      )
    }
    _, _ -> Nil
  }
}

@target(javascript)
fn sample(p: Pointer, event: b.Event) {
  let time = b.number(event, "timeStamp")
  Pointer(
    ..p,
    samples: list.append(
      list.filter(p.samples, fn(s) { s.1 >=. time -. 100.0 }),
      [#(b.number(event, "clientY"), time)],
    ),
  )
}

@target(javascript)
fn down(
  g: Gesture,
  element: b.Element,
  origin: m.InteractionOrigin,
  event: b.Event,
) {
  case
    b.get(g.pointer),
    d.snapshot(g.controller).target,
    g.geometry(),
    r.part(g.registry(), m.Popup)
  {
    None, Some(m.Open(_, o, _, _)), Some(geometry), Some(popup) if o.draggable -> {
      let ignored = case b.event_target(event) {
        None -> True
        Some(target) ->
          b.closest(
            target,
            "[data-base-ui-swipe-ignore], [data-shell-sheet-drag-ignore]",
          )
          != None
          || case
            b.closest(
              target,
              "a[href],button,input,select,textarea,[contenteditable='true']",
            )
          {
            Some(interactive) -> !b.same(interactive, element)
            None -> False
          }
      }
      case
        !ignored
        && b.integer(event, "button") == 0
        && b.boolean(event, "isPrimary")
      {
        False -> Nil
        True -> {
          let height = b.rect(popup).height
          let height = case height >. 0.0 {
            True -> height
            False -> geometry.height
          }
          let x = b.number(event, "clientX")
          let y = b.number(event, "clientY")
          case b.capture(element, b.integer(event, "pointerId")) {
            Ok(_) -> {
              b.set(g.suppress_click, False)
              b.set(
                g.pointer,
                Some(
                  Pointer(
                    b.integer(event, "pointerId"),
                    element,
                    origin,
                    x,
                    y,
                    height,
                    height,
                    None,
                    None,
                    [#(y, b.number(event, "timeStamp"))],
                  ),
                ),
              )
            }
            Error(_) -> Nil
          }
        }
      }
    }
    _, _, _, _ -> Nil
  }
}

@target(javascript)
fn move(g: Gesture, event: b.Event) {
  case b.get(g.pointer), g.geometry() {
    Some(p), Some(geometry) -> {
      let dx = b.number(event, "clientX") -. p.x
      let dy = b.number(event, "clientY") -. p.y
      case
        p.id != b.integer(event, "pointerId")
        || {
          p.interaction == None
          && float.absolute_value(dx) <. 9.0
          && float.absolute_value(dy) <. 9.0
        }
      {
        True -> Nil
        False ->
          case
            p.interaction == None
            && float.absolute_value(dx) >=. float.absolute_value(dy)
          {
            True -> {
              b.set(g.pointer, None)
              release_capture(p)
            }
            False -> {
              let p = case p.interaction {
                Some(_) -> p
                None -> {
                  let height = g.interrupt()
                  let assert Ok(id) =
                    d.begin_interaction(g.controller, p.origin)
                  b.set(g.suppress_click, True)
                  v.toggle(
                    g.registry(),
                    g.ledger,
                    m.Popup,
                    "data-swiping",
                    True,
                  )
                  Pointer(..p, height: height, interaction: Some(id))
                }
              }
              b.prevent(event)
              let maximum =
                list.last(geometry.points)
                |> result.map(fn(p) { p.height })
                |> result.unwrap(p.height)
              let assert Ok(current) =
                geometry.rubber_band(
                  p.height -. dy,
                  0.0,
                  maximum,
                  geometry.viewport.height,
                  0.55,
                )
              let p = Pointer(..sample(p, event), current: current)
              let p = case p.frame {
                Some(_) -> p
                None ->
                  Pointer(
                    ..p,
                    frame: Some(b.frame(p.element, fn() { write(g) })),
                  )
              }
              b.set(g.pointer, Some(p))
            }
          }
      }
    }
    _, _ -> Nil
  }
}

@target(javascript)
fn up(g: Gesture, event: b.Event) {
  case b.get(g.pointer) {
    Some(p) ->
      case p.id == b.integer(event, "pointerId") {
        False -> Nil
        True ->
          case p.interaction {
            None -> {
              b.set(g.pointer, None)
              release_capture(p)
            }
            Some(interaction) -> {
              let p = sample(p, event)
              case p.frame {
                Some(id) -> {
                  b.cancel_frame(p.element, id)
                  write(g)
                }
                None -> Nil
              }
              b.set(g.pointer, None)
              release_capture(p)
              case g.geometry(), d.snapshot(g.controller).target {
                Some(geometry), Some(m.Open(_, o, _, _)) -> {
                  let assert Ok(first) = list.first(p.samples)
                  let assert Ok(last) = list.last(p.samples)
                  let velocity =
                    { last.0 -. first.0 } /. float.max(1.0, last.1 -. first.1)
                  let distance = b.number(event, "clientY") -. p.y
                  let lowest =
                    list.first(geometry.points)
                    |> result.map(fn(p) { p.height })
                    |> result.unwrap(p.height)
                  let assert Ok(destination) =
                    geometry.select_release(m.ReleaseOptions(
                      p.current,
                      o.snap_point,
                      velocity,
                      distance,
                      geometry.points,
                      True,
                      o.sequential,
                      180.0,
                      0.7,
                      float.min(96.0, lowest *. 0.25),
                    ))
                  let release =
                    Some(m.Release(
                      interaction,
                      distance,
                      velocity,
                      p.current -. velocity *. 180.0,
                    ))
                  let _ = d.end_interaction(g.controller, interaction)
                  v.toggle(
                    g.registry(),
                    g.ledger,
                    m.Popup,
                    "data-swiping",
                    False,
                  )
                  let _ = case destination {
                    m.CloseDestination ->
                      d.request_close(
                        g.controller,
                        m.GestureClose,
                        m.Gesture,
                        release,
                      )
                    m.SnapTo(id) ->
                      d.request_snap(g.controller, id, m.Gesture, release)
                  }
                  g.reconcile()
                }
                _, _ -> {
                  let _ =
                    d.cancel_interaction(
                      g.controller,
                      interaction,
                      m.TargetChanged,
                    )
                  g.reconcile()
                }
              }
            }
          }
      }
    None -> Nil
  }
}

@target(javascript)
fn click(g: Gesture, event: b.Event) {
  case b.get(g.suppress_click) {
    True -> b.set(g.suppress_click, False)
    False ->
      b.microtask(fn() {
        case b.get(g.alive), d.snapshot(g.controller).target, g.geometry() {
          True, Some(m.Open(_, o, _, _)), Some(geometry) if o.draggable -> {
            case b.boolean(event, "defaultPrevented") {
              True -> Nil
              False -> {
                let points =
                  list.fold(
                    geometry.points,
                    [],
                    fn(acc: List(m.ResolvedSnapPoint), p) {
                      case acc {
                        [previous, ..] if previous.height == p.height -> acc
                        _ -> [p, ..acc]
                      }
                    },
                  )
                  |> list.reverse
                let indexed = list.index_map(points, fn(p, i) { #(p, i) })
                let index =
                  list.find(indexed, fn(pair) { pair.0.id == o.snap_point })
                  |> result.map(fn(pair) { pair.1 })
                  |> result.unwrap(-1)
                let next =
                  int.modulo(index + 1, list.length(points)) |> result.unwrap(0)
                case list.find(indexed, fn(pair) { pair.1 == next }) {
                  Ok(#(point, _)) -> {
                    let _ =
                      d.request_snap(g.controller, point.id, m.Trigger, None)
                    Nil
                  }
                  _ -> Nil
                }
              }
            }
          }
          _, _, _ -> Nil
        }
      })
  }
}

@target(javascript)
pub fn refresh(g: Gesture) {
  list.each(b.get(g.cleanups), fn(cleanup) { cleanup() })
  let cleanups =
    list.flat_map(g.registry().entries, fn(entry) {
      let origin = case entry.slot {
        r.Part(m.Handle) -> Some(m.HandleOrigin)
        r.Drag(_) -> Some(m.DragAreaOrigin)
        _ -> None
      }
      case origin {
        None -> []
        Some(origin) -> {
          let draggable = case d.snapshot(g.controller).target {
            Some(m.Open(_, o, _, _)) -> o.draggable
            _ -> False
          }
          l.style(g.ledger, entry.element, "touch-action", case draggable {
            True -> "pan-x"
            False -> ""
          })
          let listeners = [
            b.listen(entry.element, "pointerdown", down(
              g,
              entry.element,
              origin,
              _,
            )),
            b.listen(entry.element, "pointermove", move(g, _)),
            b.listen(entry.element, "pointerup", up(g, _)),
            b.listen(entry.element, "pointercancel", fn(event) {
              cancel_event(g, event, m.PointerCancelled)
            }),
            b.listen(entry.element, "lostpointercapture", fn(event) {
              cancel_event(g, event, m.CaptureLost)
            }),
          ]
          case origin {
            m.HandleOrigin -> [
              b.listen(entry.element, "click", click(g, _)),
              ..listeners
            ]
            _ -> listeners
          }
        }
      }
    })
  b.set(g.cleanups, cleanups)
}

@target(javascript)
fn cancel_event(g: Gesture, event: b.Event, reason: m.InteractionCancelReason) {
  case b.get(g.pointer) {
    Some(p) ->
      case p.id == b.integer(event, "pointerId") {
        True -> cancel(g, reason, True)
        False -> Nil
      }
    None -> Nil
  }
}

@target(javascript)
pub fn destroy(g: Gesture) {
  b.set(g.alive, False)
  cancel(g, m.InteractionDestroyed, True)
  list.each(b.get(g.cleanups), fn(cleanup) { cleanup() })
  b.set(g.cleanups, [])
}
