@target(javascript)
import gleam/float
@target(javascript)
import gleam/list
@target(javascript)
import gleam/option.{type Option, None, Some}
@target(javascript)
import gleam/result
@target(javascript)
import gleam/string
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
import gleam_drawer/model as m

@target(javascript)
pub type Active {
  Active(
    id: Int,
    target: m.Target,
    source: Option(m.Target),
    height: Float,
    animations: List(b.Animation),
    remaining: Int,
    cleanups: List(#(b.Element, String)),
  )
}

@target(javascript)
pub type State {
  State(
    frame: Option(Int),
    active: Option(Active),
    geometry: Option(v.Geometry),
    height: Option(Float),
    prepared: Bool,
    gesture: Bool,
    alive: Bool,
  )
}

@target(javascript)
pub type Motion {
  Motion(
    controller: d.Controller,
    registry: fn() -> r.Registry,
    ledger: l.Ledger,
    insets: fn() -> #(Float, Float),
    before: fn(m.Snapshot) -> Nil,
    settled: fn(m.Snapshot) -> Nil,
    hidden: fn() -> Nil,
    state: b.Ref(State),
  )
}

@target(javascript)
pub type Timing {
  Timing(
    open: Float,
    close: Float,
    geometry: Float,
    region: Float,
    enter: String,
    change: String,
  )
}

@target(javascript)
pub type Visual {
  Visual(element: b.Element, opacity: String, filter: String, continuing: Bool)
}

@target(javascript)
pub fn new(
  controller: d.Controller,
  registry: fn() -> r.Registry,
  ledger: l.Ledger,
  insets: fn() -> #(Float, Float),
  before: fn(m.Snapshot) -> Nil,
  settled: fn(m.Snapshot) -> Nil,
  hidden: fn() -> Nil,
) {
  Motion(
    controller,
    registry,
    ledger,
    insets,
    before,
    settled,
    hidden,
    b.ref(State(None, None, None, None, False, False, True)),
  )
}

@target(javascript)
pub fn geometry(motion: Motion) {
  b.get(motion.state).geometry
}

@target(javascript)
fn duration(raw: String, fallback: Float) {
  let raw = string.trim(raw)
  let parsed = case string.ends_with(raw, "ms"), string.ends_with(raw, "s") {
    True, _ -> raw |> string.drop_end(2) |> float.parse
    _, True ->
      raw
      |> string.drop_end(1)
      |> float.parse
      |> result.map(fn(v) { v *. 1000.0 })
    _, _ -> Error(Nil)
  }
  case parsed {
    Ok(value) if value >=. 0.0 -> value
    _ -> fallback
  }
}

@target(javascript)
fn easing(popup: b.Element, property: String, fallback: String) {
  let value = b.computed(popup, property) |> string.trim
  case
    value != "" && b.css_supports(popup, "animation-timing-function", value)
  {
    True -> value
    False -> fallback
  }
}

@target(javascript)
fn timing(popup: b.Element) {
  Timing(
    duration(b.computed(popup, "--shell-sheet-open-duration"), 280.0),
    duration(b.computed(popup, "--shell-sheet-close-duration"), 220.0),
    duration(b.computed(popup, "--shell-sheet-geometry-duration"), 270.0),
    duration(b.computed(popup, "--shell-sheet-region-duration"), 220.0),
    easing(
      popup,
      "--shell-sheet-easing-enter",
      "cubic-bezier(0.32, 0.72, 0, 1)",
    ),
    easing(
      popup,
      "--shell-sheet-easing-change",
      "cubic-bezier(0.65, 0, 0.35, 1)",
    ),
  )
}

@target(javascript)
fn clean(motion: Motion, active: Active) {
  list.each(active.animations, b.stop)
  list.each(active.cleanups, fn(pair) {
    l.style(motion.ledger, pair.0, pair.1, "")
  })
}

@target(javascript)
fn stop(motion: Motion) {
  let state = b.get(motion.state)
  b.set(motion.state, State(..state, active: None))
  case state.active {
    Some(active) -> clean(motion, active)
    None -> Nil
  }
}

@target(javascript)
fn remember_cleanup(motion: Motion, element: b.Element, property: String) {
  let state = b.get(motion.state)
  case state.active {
    Some(active) ->
      b.set(
        motion.state,
        State(
          ..state,
          active: Some(
            Active(..active, cleanups: [#(element, property), ..active.cleanups]),
          ),
        ),
      )
    None -> Nil
  }
}

@target(javascript)
fn finished(motion: Motion, id: Int, success: Bool) {
  let state = b.get(motion.state)
  case state.alive, state.active {
    True, Some(active) if active.id == id -> {
      case success {
        False -> {
          stop(motion)
          let _ = d.cancel_transition(motion.controller, id, m.DriverCancelled)
          Nil
        }
        True ->
          case active.remaining > 1 {
            True ->
              b.set(
                motion.state,
                State(
                  ..state,
                  active: Some(
                    Active(..active, remaining: active.remaining - 1),
                  ),
                ),
              )
            False -> {
              // Clear active before cancelling filled WAAPI clocks: stale promise
              // callbacks cannot affect a later attempt.
              stop(motion)
              let _ = d.settle_transition(motion.controller, id)
              let snapshot = d.snapshot(motion.controller)
              let state = b.get(motion.state)
              b.set(motion.state, State(..state, height: Some(active.height)))
              let registry = motion.registry()
              v.project(registry, motion.ledger, snapshot, state.geometry)
              v.style(
                registry,
                motion.ledger,
                m.Popup,
                "height",
                modal.px(active.height),
              )
              v.style(registry, motion.ledger, m.Popup, "transform", "")
              v.style(registry, motion.ledger, m.Popup, "opacity", "")
              motion.settled(snapshot)
              case v.is_open(snapshot.target) {
                False -> {
                  v.attr(registry, motion.ledger, m.Portal, "hidden", Some(""))
                  b.set(
                    motion.state,
                    State(..b.get(motion.state), prepared: False, height: None),
                  )
                  motion.hidden()
                }
                True -> Nil
              }
            }
          }
      }
    }
    _, _ -> Nil
  }
}

@target(javascript)
fn animate(
  motion: Motion,
  element: b.Element,
  frames: List(List(#(String, String))),
  duration: Float,
  easing: String,
) {
  let state = b.get(motion.state)
  case state.active {
    None -> Nil
    Some(active) -> {
      let animation =
        b.animate(element, frames, duration, easing, finished(
          motion,
          active.id,
          _,
        ))
      b.set(
        motion.state,
        State(
          ..state,
          active: Some(
            Active(..active, remaining: active.remaining + 1, animations: [
              animation,
              ..active.animations
            ]),
          ),
        ),
      )
    }
  }
}

@target(javascript)
fn transform(element: b.Element) {
  let value = b.computed(element, "transform")
  case value == "none" {
    True -> "translateY(0px)"
    False -> value
  }
}

@target(javascript)
fn capture_visuals(motion: Motion) {
  let cleanups = case b.get(motion.state).active {
    Some(active) -> active.cleanups
    None -> []
  }
  list.map(motion.registry().entries, fn(entry) {
    Visual(
      entry.element,
      b.computed(entry.element, "opacity"),
      b.computed(entry.element, "backdrop-filter"),
      list.any(cleanups, fn(pair) { b.same(pair.0, entry.element) }),
    )
  })
}

@target(javascript)
fn opacity(visuals: List(Visual), element: b.Element, fallback: String) {
  case list.find(visuals, fn(v) { b.same(v.element, element) }) {
    Ok(visual) if visual.continuing -> visual.opacity
    _ -> fallback
  }
}

@target(javascript)
fn regions(
  motion: Motion,
  target: m.Target,
  previous: Option(m.Target),
  visuals: List(Visual),
  time: Timing,
  reduced: Bool,
) {
  case target, previous {
    m.Open(_, next, intent, _), Some(m.Open(_, old, _, _)) -> {
      list.each([m.HeaderRegion, m.BodyRegion, m.FooterRegion], fn(region) {
        let incoming_target = r.region(next, region)
        let outgoing_target = r.region(old, region)
        case
          incoming_target.key != outgoing_target.key
          && incoming_target.transition == m.Crossfade
        {
          False -> Nil
          True ->
            case
              r.layer(motion.registry(), region, incoming_target.key),
              r.layer(motion.registry(), region, outgoing_target.key)
            {
              Some(incoming), Some(outgoing) -> {
                let duration = case intent.motion {
                  m.Instant -> 0.0
                  _ -> time.region
                }
                let incoming_opacity = opacity(visuals, incoming, "0")
                let outgoing_opacity = opacity(visuals, outgoing, "1")
                l.style(motion.ledger, incoming, "opacity", incoming_opacity)
                l.style(motion.ledger, outgoing, "opacity", outgoing_opacity)
                remember_cleanup(motion, incoming, "opacity")
                remember_cleanup(motion, outgoing, "opacity")
                animate(
                  motion,
                  incoming,
                  [[#("opacity", incoming_opacity)], [#("opacity", "1")]],
                  duration,
                  time.change,
                )
                animate(
                  motion,
                  outgoing,
                  [[#("opacity", outgoing_opacity)], [#("opacity", "0")]],
                  duration,
                  time.change,
                )
                case r.surface(motion.registry(), region), reduced {
                  Some(surface), False -> {
                    let old =
                      list.find(visuals, fn(v) { b.same(v.element, surface) })
                    let filter = case old {
                      Ok(v) if v.continuing -> v.filter
                      _ -> "blur(0px)"
                    }
                    let alpha = opacity(visuals, surface, "0")
                    list.each(
                      ["opacity", "backdrop-filter", "-webkit-backdrop-filter"],
                      remember_cleanup(motion, surface, _),
                    )
                    animate(
                      motion,
                      surface,
                      [
                        [
                          #("offset", "0"),
                          #("opacity", alpha),
                          #("backdropFilter", filter),
                          #("webkitBackdropFilter", filter),
                        ],
                        [
                          #("offset", "0.5"),
                          #("opacity", "1"),
                          #("backdropFilter", "blur(2px)"),
                          #("webkitBackdropFilter", "blur(2px)"),
                        ],
                        [
                          #("offset", "1"),
                          #("opacity", "0"),
                          #("backdropFilter", "blur(0px)"),
                          #("webkitBackdropFilter", "blur(0px)"),
                        ],
                      ],
                      duration,
                      time.change,
                    )
                  }
                  _, _ -> Nil
                }
              }
              _, _ -> Nil
            }
        }
      })
    }
    _, _ -> Nil
  }
}

@target(javascript)
pub fn schedule(motion: Motion) {
  let state = b.get(motion.state)
  case state.alive, state.frame, r.part(motion.registry(), m.Portal) {
    True, None, Some(portal) -> {
      let frame = b.frame(portal, fn() { run(motion) })
      b.set(motion.state, State(..state, frame: Some(frame)))
    }
    _, _, _ -> Nil
  }
}

@target(javascript)
fn run(motion: Motion) {
  let state = b.get(motion.state)
  b.set(motion.state, State(..state, frame: None))
  let snapshot = d.snapshot(motion.controller)
  let registry = motion.registry()
  case
    state.alive,
    snapshot.interaction,
    r.part(registry, m.Portal),
    r.part(registry, m.Popup),
    snapshot.target
  {
    True, None, Some(portal), Some(popup), Some(target) -> {
      case v.visual(snapshot) {
        None -> {
          v.project(registry, motion.ledger, snapshot, None)
          l.attribute(motion.ledger, portal, "hidden", Some(""))
          motion.hidden()
        }
        Some(visual) -> {
          let options = v.options(visual)
          case r.ready(registry, options) {
            False -> {
              case state.active {
                Some(active) -> {
                  stop(motion)
                  let _ =
                    d.cancel_transition(
                      motion.controller,
                      active.id,
                      m.RegistryLost,
                    )
                  Nil
                }
                None -> Nil
              }
            }
            True ->
              case !state.prepared && v.is_open(snapshot.target) {
                True -> {
                  l.attribute(motion.ledger, portal, "hidden", None)
                  l.style(motion.ledger, portal, "visibility", "hidden")
                  l.style(motion.ledger, portal, "pointer-events", "none")
                  b.set(
                    motion.state,
                    State(..b.get(motion.state), prepared: True),
                  )
                  schedule(motion)
                }
                False ->
                  reconcile(motion, snapshot, target, visual, popup, portal)
              }
          }
        }
      }
    }
    _, _, _, _, _ -> Nil
  }
}

@target(javascript)
fn reconcile(
  motion: Motion,
  snapshot: m.Snapshot,
  target: m.Target,
  visual: m.Target,
  popup: b.Element,
  portal: b.Element,
) {
  let state = b.get(motion.state)
  let registry = motion.registry()
  let insets = motion.insets()
  let assert Ok(measured) =
    v.measure(registry, v.options(visual), insets.0, insets.1)
  let previous = case state.active {
    Some(active) ->
      case active.target.id == target.id {
        True -> active.source
        False -> Some(active.target)
      }
    None -> snapshot.settled_target
  }
  let keep = case target, previous {
    m.Open(_, next, _, _), Some(m.Open(_, old, _, _)) ->
      next.resize_behavior == m.KeepSnapAndScroll
      && next.snap_point == old.snap_point
    _, _ -> False
  }
  let geometry = case keep {
    True -> {
      let height = case measured.rect.height >. 0.0 {
        True -> measured.rect.height
        False -> measured.height
      }
      let points =
        list.map(measured.points, fn(p) {
          case p.id == v.options(visual).snap_point {
            True -> m.ResolvedSnapPoint(..p, height: height)
            False -> p
          }
        })
        |> list.sort(fn(a, z) { float.compare(a.height, z.height) })
      v.Geometry(..measured, height: height, points: points)
    }
    False -> measured
  }
  let active_matches = case state.active {
    Some(active) ->
      active.target.id == target.id
      && float.absolute_value(active.height -. geometry.height) <. 0.5
    None -> False
  }
  let stable =
    !state.gesture
    && snapshot.phase == m.OpenPhase
    && case snapshot.settled_target, state.height {
      Some(t), Some(h) ->
        t.id == target.id && float.absolute_value(h -. geometry.height) <. 0.5
      _, _ -> False
    }
  case active_matches {
    True -> Nil
    False ->
      case stable {
        True -> {
          b.set(
            motion.state,
            State(..b.get(motion.state), geometry: Some(geometry)),
          )
          v.project(registry, motion.ledger, snapshot, Some(geometry))
          l.style(motion.ledger, popup, "height", modal.px(geometry.height))
          l.style(motion.ledger, popup, "transform", "")
        }
        False ->
          start(motion, snapshot, target, previous, geometry, popup, portal)
      }
  }
}

@target(javascript)
fn start(
  motion: Motion,
  snapshot: m.Snapshot,
  target: m.Target,
  previous: Option(m.Target),
  geometry: v.Geometry,
  popup: b.Element,
  portal: b.Element,
) {
  let state = b.get(motion.state)
  let registry = motion.registry()
  let time = timing(popup)
  let reduced = b.reduced_motion(popup)
  let instant = v.intent(target).motion == m.Instant
  let old_transform = transform(popup)
  let old_opacity = b.computed(popup, "opacity")
  let old_radius = b.computed(popup, "border-radius")
  let backdrop = r.part(registry, m.Backdrop)
  let old_backdrop = case backdrop {
    Some(e) -> b.computed(e, "opacity")
    None -> "1"
  }
  let visuals = capture_visuals(motion)
  let opening =
    v.is_open(snapshot.target)
    && snapshot.settled_target == None
    && state.active == None
    && state.height == None
  let morph = case target, previous {
    m.Open(_, next, _, _), Some(m.Open(_, old, _, _)) ->
      next.presentation != old.presentation
    _, _ -> False
  }
  let immediate = case target {
    m.Open(_, o, _, _) -> o.resize_behavior == m.Immediate
    _ -> False
  }
  let geometry_time = case instant || reduced || immediate {
    True -> 0.0
    False -> time.geometry
  }
  let change_easing = case state.gesture {
    True -> time.enter
    False -> time.change
  }
  stop(motion)
  let assert Ok(id) = d.begin_transition(motion.controller, target.id)
  b.set(
    motion.state,
    State(
      ..b.get(motion.state),
      geometry: Some(geometry),
      gesture: False,
      active: Some(Active(id, target, previous, geometry.height, [], 0, [])),
    ),
  )
  motion.before(d.snapshot(motion.controller))
  v.project(
    registry,
    motion.ledger,
    d.snapshot(motion.controller),
    Some(geometry),
  )
  l.style(motion.ledger, portal, "visibility", "")
  l.style(motion.ledger, portal, "pointer-events", "")
  let from_height = case opening {
    True -> geometry.height
    False -> geometry.rect.height
  }
  l.style(motion.ledger, popup, "height", modal.px(from_height))
  l.style(motion.ledger, popup, "transform", old_transform)
  case target {
    m.Closed(..) -> {
      let duration = case instant {
        True -> 0.0
        False ->
          case reduced {
            True -> 120.0
            False -> time.close
          }
      }
      let end_transform = case v.visual(snapshot) {
        Some(m.Open(_, o, _, _)) if o.presentation == m.Sheet ->
          "translateY(100%)"
        _ -> "translateY(12px)"
      }
      let frames = case reduced {
        True -> [[#("opacity", old_opacity)], [#("opacity", "0")]]
        False -> [
          [#("transform", old_transform), #("opacity", old_opacity)],
          [
            #("transform", end_transform),
            #("opacity", case end_transform == "translateY(100%)" {
              True -> "1"
              False -> "0"
            }),
          ],
        ]
      }
      animate(motion, popup, frames, duration, time.enter)
      case backdrop {
        Some(e) ->
          animate(
            motion,
            e,
            [[#("opacity", old_backdrop)], [#("opacity", "0")]],
            duration,
            time.enter,
          )
        None -> Nil
      }
    }
    m.Open(_, o, _, _) -> {
      case opening {
        True -> {
          let duration = case instant {
            True -> 0.0
            False ->
              case reduced {
                True -> 120.0
                False -> time.open
              }
          }
          let frames = case reduced {
            True -> [[#("opacity", "0")], [#("opacity", "1")]]
            False -> [
              [
                #("transform", case o.presentation {
                  m.Sheet -> "translateY(100%)"
                  m.Dialog -> "translateY(12px)"
                }),
                #("opacity", case o.presentation {
                  m.Sheet -> "1"
                  m.Dialog -> "0"
                }),
              ],
              [#("transform", "translateY(0px)"), #("opacity", "1")],
            ]
          }
          animate(motion, popup, frames, duration, time.enter)
          case backdrop {
            Some(e) ->
              animate(
                motion,
                e,
                [[#("opacity", "0")], [#("opacity", old_backdrop)]],
                duration,
                time.enter,
              )
            None -> Nil
          }
        }
        False -> {
          case morph {
            True -> {
              // Measure the new CSS layout with the old box dimensions, then
              // invert its displacement. Animate size, never scale the text.
              l.style(motion.ledger, popup, "transform", "none")
              l.style(motion.ledger, popup, "width", "")
              let target_width = b.rect(popup).width
              let target_radius = b.computed(popup, "border-radius")
              l.style(
                motion.ledger,
                popup,
                "width",
                modal.px(geometry.rect.width),
              )
              let base = b.rect(popup)
              let inverse =
                "translate("
                <> modal.px(geometry.rect.x -. base.x)
                <> ", "
                <> modal.px(geometry.rect.y -. base.y)
                <> ")"
              l.style(motion.ledger, popup, "transform", inverse)
              list.each(["width", "border-radius"], remember_cleanup(
                motion,
                popup,
                _,
              ))
              animate(
                motion,
                popup,
                [
                  [
                    #("width", modal.px(geometry.rect.width)),
                    #("height", modal.px(from_height)),
                    #("transform", inverse),
                    #("borderRadius", old_radius),
                  ],
                  [
                    #("width", modal.px(target_width)),
                    #("height", modal.px(geometry.height)),
                    #("transform", "translate(0px, 0px)"),
                    #("borderRadius", target_radius),
                  ],
                ],
                geometry_time,
                change_easing,
              )
            }
            False ->
              animate(
                motion,
                popup,
                [
                  [
                    #("height", modal.px(from_height)),
                    #("transform", old_transform),
                    #("opacity", old_opacity),
                  ],
                  [
                    #("height", modal.px(geometry.height)),
                    #("transform", "translateY(0px)"),
                    #("opacity", "1"),
                  ],
                ],
                geometry_time,
                change_easing,
              )
          }
          regions(motion, target, previous, visuals, time, reduced)
        }
      }
    }
  }
}

@target(javascript)
pub fn interrupt(motion: Motion) -> Float {
  case r.part(motion.registry(), m.Popup) {
    None -> 0.0
    Some(popup) -> {
      let state = b.get(motion.state)
      let rect = b.rect(popup)
      let offset = case d.snapshot(motion.controller).target {
        Some(m.Open(_, o, _, _)) if o.presentation == m.Sheet ->
          b.translation(popup).1
        _ -> 0.0
      }
      let height = float.max(0.0, rect.height -. offset)
      stop(motion)
      case state.frame {
        Some(id) -> b.cancel_frame(popup, id)
        None -> Nil
      }
      case state.active {
        Some(active) -> {
          let _ =
            d.cancel_transition(motion.controller, active.id, m.DriverCancelled)
          Nil
        }
        None -> Nil
      }
      b.set(
        motion.state,
        State(
          ..b.get(motion.state),
          frame: None,
          height: Some(height),
          gesture: True,
        ),
      )
      l.style(motion.ledger, popup, "height", modal.px(height))
      l.style(motion.ledger, popup, "transform", "translateY(0px)")
      l.style(motion.ledger, popup, "opacity", "1")
      height
    }
  }
}

@target(javascript)
pub fn destroy(motion: Motion) {
  let state = b.get(motion.state)
  b.set(motion.state, State(..state, alive: False))
  case state.frame, r.part(motion.registry(), m.Portal) {
    Some(id), Some(portal) -> b.cancel_frame(portal, id)
    _, _ -> Nil
  }
  stop(motion)
  case state.active {
    Some(active) -> {
      let _ =
        d.cancel_transition(motion.controller, active.id, m.TransitionDestroyed)
      Nil
    }
    None -> Nil
  }
}
