@target(javascript)
import gleam/float
@target(javascript)
import gleam/list
@target(javascript)
import gleam/option.{type Option, None, Some}
@target(javascript)
import gleam/result
@target(javascript)
import gleam_drawer/browser/ledger as l
@target(javascript)
import gleam_drawer/browser/modality as modal
@target(javascript)
import gleam_drawer/browser/platform as b
@target(javascript)
import gleam_drawer/browser/registry as r
@target(javascript)
import gleam_drawer/geometry
@target(javascript)
import gleam_drawer/model as m

@target(javascript)
pub type Geometry {
  Geometry(
    height: Float,
    points: List(m.ResolvedSnapPoint),
    rect: b.Rect,
    viewport: b.Viewport,
    keyboard: Float,
    header: Float,
    body: Float,
    footer: Float,
  )
}

@target(javascript)
pub fn visual(snapshot: m.Snapshot) -> Option(m.Target) {
  case snapshot.target {
    Some(m.Open(..)) -> snapshot.target
    _ -> snapshot.settled_target
  }
}

@target(javascript)
pub fn options(target: m.Target) -> m.OpenOptions {
  let assert m.Open(_, options, _, _) = target
  options
}

@target(javascript)
pub fn intent(target: m.Target) -> m.Transition {
  case target {
    m.Open(_, _, transition, _) | m.Closed(_, transition, _) -> transition
  }
}

@target(javascript)
pub fn is_open(target: Option(m.Target)) {
  case target {
    Some(m.Open(..)) -> True
    _ -> False
  }
}

@target(javascript)
pub fn each_part(registry: r.Registry, part: m.Part, f: fn(b.Element) -> Nil) {
  case r.part(registry, part) {
    Some(e) -> f(e)
    None -> Nil
  }
}

@target(javascript)
pub fn style(
  registry: r.Registry,
  ledger: l.Ledger,
  part: m.Part,
  key: String,
  value: String,
) {
  each_part(registry, part, fn(e) { l.style(ledger, e, key, value) })
}

@target(javascript)
pub fn attr(
  registry: r.Registry,
  ledger: l.Ledger,
  part: m.Part,
  key: String,
  value: Option(String),
) {
  each_part(registry, part, fn(e) { l.attribute(ledger, e, key, value) })
}

@target(javascript)
pub fn toggle(
  registry: r.Registry,
  ledger: l.Ledger,
  part: m.Part,
  key: String,
  value: Bool,
) {
  each_part(registry, part, fn(e) { l.toggle(ledger, e, key, value) })
}

@target(javascript)
pub fn presentation(value: m.Presentation) {
  case value {
    m.Sheet -> "sheet"
    m.Dialog -> "dialog"
  }
}

@target(javascript)
pub fn measure(
  registry: r.Registry,
  options: m.OpenOptions,
  top: Float,
  bottom: Float,
) -> Result(Geometry, String) {
  case r.ready(registry, options) {
    False -> Error("Target registry is not ready")
    True -> {
      let assert Some(portal) = r.part(registry, m.Portal)
      let assert Some(popup) = r.part(registry, m.Popup)
      let assert Some(viewport_element) = r.part(registry, m.Viewport)
      let assert Some(header) = r.part(registry, m.Header)
      let assert Some(footer) = r.part(registry, m.Footer)
      let assert Some(body) =
        r.layer(registry, m.BodyRegion, options.regions.body.key)
      let viewport = case b.visual_viewport(portal) {
        Some(v) -> v
        None -> b.layout_viewport(portal)
      }
      let header_height = b.rect(header).height
      let footer_height = b.rect(footer).height
      let body_height = float.max(b.scroll_height(body), b.rect(body).height)
      use points <- result.try(geometry.resolve_snap_points(
        options.snap_points,
        m.Metrics(
          viewport.height,
          top,
          bottom,
          header_height,
          body_height,
          footer_height,
          None,
          None,
        ),
      ))
      let assert Ok(selected) =
        list.find(points, fn(p) { p.id == options.snap_point })
      Ok(Geometry(
        selected.height,
        points,
        b.rect(popup),
        viewport,
        float.max(
          0.0,
          b.rect(viewport_element).height -. viewport.y -. viewport.height,
        ),
        header_height,
        body_height,
        footer_height,
      ))
    }
  }
}

@target(javascript)
pub fn initialize(entry: r.Entry, ledger: l.Ledger) {
  let e = entry.element
  let styles = case entry.slot {
    r.Part(m.Portal) -> {
      l.attribute(ledger, e, "data-shell-sheet-portal", Some(""))
      []
    }
    r.Part(m.Popup) -> [
      #("min-height", "0"),
      #("overflow", "hidden"),
      #("contain", "layout paint"),
      #("--drawer-swipe-movement-x", "0px"),
      #("--drawer-swipe-movement-y", "0px"),
      #("--drawer-swipe-strength", "1"),
      #("--nested-drawers", "0"),
    ]
    r.Part(m.Content) -> [
      #("display", "grid"),
      #("grid-template-rows", "auto minmax(0, 1fr) auto"),
      #("block-size", "100%"),
      #("min-block-size", "0"),
    ]
    r.Part(m.Header) -> [
      #("display", "grid"),
      #("grid-template-rows", "auto auto"),
      #("min-block-size", "0"),
    ]
    r.Part(m.Body) -> [
      #("display", "grid"),
      #("grid-template-rows", "auto"),
      #("min-block-size", "0"),
      #("overflow-y", "auto"),
      #("overscroll-behavior", "contain"),
    ]
    r.Part(m.Footer) -> [
      #("display", "grid"),
      #("grid-template-rows", "auto"),
      #("min-block-size", "0"),
    ]
    r.Layer(..) -> [#("align-self", "start")]
    r.Surface(region) -> {
      l.attribute(ledger, e, "data-region-blur", Some(r.region_name(region)))
      l.attribute(ledger, e, "aria-hidden", Some("true"))
      [
        #("align-self", "stretch"),
        #("justify-self", "stretch"),
        #("grid-area", area(region)),
        #("z-index", "1"),
        #("pointer-events", "none"),
      ]
    }
    _ -> []
  }
  list.each(styles, fn(pair) { l.style(ledger, e, pair.0, pair.1) })
}

@target(javascript)
pub fn area(region: m.Region) {
  case region {
    m.HeaderRegion -> "2 / 1"
    _ -> "1 / 1"
  }
}

@target(javascript)
pub fn project(
  registry: r.Registry,
  ledger: l.Ledger,
  snapshot: m.Snapshot,
  geometry: Option(Geometry),
) {
  let open = is_open(snapshot.target)
  let visual = visual(snapshot)
  let morph = case snapshot.target, snapshot.settled_target {
    Some(m.Open(_, a, _, _)), Some(m.Open(_, z, _, _)) ->
      snapshot.phase == m.Transitioning && a.presentation != z.presentation
    _, _ -> False
  }
  list.each([m.Backdrop, m.Viewport, m.Popup], fn(part) {
    toggle(registry, ledger, part, "data-open", open)
    toggle(registry, ledger, part, "data-closed", !open)
    toggle(
      registry,
      ledger,
      part,
      "data-starting-style",
      snapshot.phase == m.Opening,
    )
    toggle(
      registry,
      ledger,
      part,
      "data-ending-style",
      snapshot.phase == m.Closing,
    )
  })
  toggle(registry, ledger, m.Popup, "data-transitioning", morph)
  toggle(
    registry,
    ledger,
    m.Popup,
    "data-swiping",
    snapshot.phase == m.Dragging,
  )
  attr(registry, ledger, m.Popup, "data-swipe-direction", Some("down"))
  list.each(["data-nested-drawer-open", "data-nested-drawer-swiping"], fn(key) {
    toggle(registry, ledger, m.Popup, key, False)
  })
  case morph, snapshot.settled_target, snapshot.target {
    True, Some(m.Open(_, old, _, _)), Some(m.Open(_, new, _, _)) -> {
      attr(
        registry,
        ledger,
        m.Popup,
        "data-from-presentation",
        Some(presentation(old.presentation)),
      )
      attr(
        registry,
        ledger,
        m.Popup,
        "data-to-presentation",
        Some(presentation(new.presentation)),
      )
    }
    _, _, _ -> {
      attr(registry, ledger, m.Popup, "data-from-presentation", None)
      attr(registry, ledger, m.Popup, "data-to-presentation", None)
    }
  }
  case snapshot.phase != m.Dragging {
    True -> {
      style(registry, ledger, m.Popup, "--drawer-swipe-movement-y", "0px")
      style(registry, ledger, m.Backdrop, "--drawer-swipe-progress", "0")
      toggle(registry, ledger, m.Popup, "data-swipe-dismiss", False)
    }
    False -> Nil
  }
  case visual {
    None -> Nil
    Some(target) -> {
      let o = options(target)
      list.each([m.Viewport, m.Popup], fn(part) {
        attr(
          registry,
          ledger,
          part,
          "data-presentation",
          Some(presentation(o.presentation)),
        )
        attr(
          registry,
          ledger,
          part,
          "data-modality",
          Some(case o.modality {
            m.Modal -> "modal"
            m.NonModal -> "non-modal"
          }),
        )
      })
      style(registry, ledger, m.Handle, "touch-action", case o.draggable {
        True -> "pan-x"
        False -> ""
      })
      case geometry {
        Some(g) -> {
          let highest =
            list.last(g.points)
            |> result.map(fn(p) { p.id == o.snap_point })
            |> result.unwrap(False)
          toggle(registry, ledger, m.Popup, "data-expanded", highest)
          list.each(
            [
              #("--drawer-height", g.height),
              #("--drawer-frontmost-height", g.height),
              #("--drawer-snap-point-offset", 0.0),
              #("--shell-sheet-header-height", g.header),
              #("--shell-sheet-body-natural-height", g.body),
              #("--shell-sheet-footer-height", g.footer),
              #("--shell-sheet-target-inline-size", g.rect.width),
            ],
            fn(pair) {
              style(registry, ledger, m.Popup, pair.0, modal.px(pair.1))
            },
          )
          style(
            registry,
            ledger,
            m.Viewport,
            "--drawer-keyboard-inset",
            modal.px(g.keyboard),
          )
        }
        None -> Nil
      }
      list.each([m.HeaderRegion, m.BodyRegion, m.FooterRegion], fn(region) {
        let key = r.region(o, region).key
        let entries =
          list.filter(registry.entries, fn(e) {
            case e.slot {
              r.Layer(r, _, _) -> r == region
              _ -> False
            }
          })
        toggle(
          registry,
          ledger,
          r.host(region),
          "data-transitioning",
          list.any(entries, fn(e) {
            case e.slot {
              r.Layer(_, k, _) -> k != key
              _ -> False
            }
          }),
        )
        list.each(entries, fn(e) {
          let assert r.Layer(_, k, layer) = e.slot
          let active = k == key && layer != m.Outgoing
          l.attribute(
            ledger,
            e.element,
            "data-region",
            Some(r.region_name(region)),
          )
          l.attribute(
            ledger,
            e.element,
            "data-layer",
            Some(case layer {
              m.Settled -> "settled"
              m.Incoming -> "incoming"
              m.Outgoing -> "outgoing"
            }),
          )
          l.style(ledger, e.element, "grid-area", area(region))
          l.toggle(ledger, e.element, "data-active", active)
          l.toggle(
            ledger,
            e.element,
            "data-starting-style",
            layer == m.Incoming,
          )
          l.toggle(ledger, e.element, "data-ending-style", layer == m.Outgoing)
          case active {
            True -> {
              l.attribute(ledger, e.element, "aria-hidden", None)
              l.attribute(ledger, e.element, "inert", None)
            }
            False -> {
              case b.active_element(e.element), r.part(registry, m.Popup) {
                Some(focused), Some(popup) ->
                  case b.contains(e.element, focused) {
                    True -> modal.focus_popup(popup, ledger)
                    False -> Nil
                  }
                _, _ -> Nil
              }
              l.attribute(ledger, e.element, "aria-hidden", Some("true"))
              l.attribute(ledger, e.element, "inert", Some(""))
            }
          }
        })
      })
    }
  }
}
