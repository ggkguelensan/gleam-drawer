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
import gleam_drawer/browser/ledger as l
@target(javascript)
import gleam_drawer/browser/platform as b

@target(javascript)
pub type Lease {
  Lease(releases: List(b.Cleanup), focus: Option(b.Element))
}

@target(javascript)
pub type Counted {
  Counted(count: Int, ledger: l.Ledger, release: b.Cleanup)
}

@target(javascript)
pub fn new() -> Lease {
  Lease([], None)
}

@target(javascript)
pub fn active(lease: Lease) {
  !list.is_empty(lease.releases)
}

@target(javascript)
pub fn number(raw: String, fallback: Float) {
  raw
  |> string.trim
  |> string.replace("px", "")
  |> float.parse
  |> result.unwrap(fallback)
}

@target(javascript)
pub fn px(value: Float) {
  float.to_string(value) <> "px"
}

@target(javascript)
fn counted(
  element: b.Element,
  key: String,
  acquire: fn(l.Ledger) -> b.Cleanup,
) -> b.Cleanup {
  let store = b.shared(element, key, fn() { None })
  case b.get(store) {
    Some(state) -> b.set(store, Some(Counted(..state, count: state.count + 1)))
    None -> {
      let ledger = l.new()
      let release = acquire(ledger)
      b.set(store, Some(Counted(1, ledger, release)))
    }
  }
  let alive = b.ref(True)
  fn() {
    case b.get(alive), b.get(store) {
      True, Some(state) -> {
        b.set(alive, False)
        case state.count > 1 {
          True -> b.set(store, Some(Counted(..state, count: state.count - 1)))
          False -> {
            b.set(store, None)
            l.restore(state.ledger)
            state.release()
          }
        }
      }
      _, _ -> Nil
    }
  }
}

@target(javascript)
fn lock(popup: b.Element) -> b.Cleanup {
  let body = b.body(popup)
  counted(body, "gleam-drawer-scroll", fn(ledger) {
    let scroll = b.scroll_position(popup)
    let width =
      float.max(0.0, b.layout_viewport(popup).width -. b.client_width(popup))
    let padding = number(b.computed(body, "padding-right"), 0.0)
    l.style(ledger, body, "overflow", "hidden")
    case width >. 0.0 {
      True -> l.style(ledger, body, "padding-right", px(padding +. width))
      False -> Nil
    }
    fn() { b.scroll_to(popup, scroll.0, scroll.1) }
  })
}

@target(javascript)
fn isolate(element: b.Element) -> b.Cleanup {
  counted(element, "gleam-drawer-isolation", fn(ledger) {
    l.attribute(ledger, element, "inert", Some(""))
    l.attribute(ledger, element, "aria-hidden", Some("true"))
    fn() { Nil }
  })
}

@target(javascript)
pub fn acquire(
  lease: Lease,
  popup: b.Element,
  portal: b.Element,
  scope: Option(b.Element),
  ledger: l.Ledger,
) -> Lease {
  case active(lease) {
    True -> lease
    False -> {
      let focus = b.active_element(popup)
      let targets = case scope {
        Some(target) ->
          case b.same(target, portal) {
            True -> backgrounds(portal)
            False -> [target]
          }
        None -> backgrounds(portal)
      }
      let releases = [lock(popup), ..list.map(targets, isolate)]
      focus_popup(popup, ledger)
      Lease(releases, focus)
    }
  }
}

@target(javascript)
fn backgrounds(portal: b.Element) {
  b.siblings(portal)
  |> list.filter(fn(e) {
    !b.same(e, portal) && b.attribute(e, "data-shell-sheet-portal") == None
  })
}

@target(javascript)
pub fn focus_popup(popup: b.Element, ledger: l.Ledger) {
  case b.attribute(popup, "tabindex") {
    None -> l.attribute(ledger, popup, "tabindex", Some("-1"))
    _ -> Nil
  }
  b.focus(popup)
}

@target(javascript)
pub fn release(lease: Lease, restore_focus: Bool) -> Lease {
  list.each(list.reverse(lease.releases), fn(release) { release() })
  case lease.focus, restore_focus {
    Some(e), True ->
      case b.connected(e) {
        True -> b.focus(e)
        False -> Nil
      }
    _, _ -> Nil
  }
  new()
}

@target(javascript)
pub fn trap(popup: b.Element, event: b.Event, ledger: l.Ledger) {
  let elements =
    b.query(
      popup,
      "a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex='-1'])",
    )
    |> list.filter(fn(e) {
      b.closest(e, "[inert], [hidden], [aria-hidden='true']") == None
      && b.rect(e).height >. 0.0
    })
  case elements {
    [] -> {
      b.prevent(event)
      focus_popup(popup, ledger)
    }
    [first, ..] -> {
      let last = list.last(elements) |> result.unwrap(first)
      let backward = b.boolean(event, "shiftKey")
      let focused = b.active_element(popup)
      let outside = case focused {
        Some(e) -> !b.contains(popup, e)
        _ -> True
      }
      let at_edge = case focused {
        Some(e) ->
          b.same(e, case backward {
            True -> first
            False -> last
          })
        _ -> False
      }
      case
        outside
        || at_edge
        || case focused {
          Some(e) -> b.same(e, popup)
          _ -> False
        }
      {
        True -> {
          b.prevent(event)
          b.focus(case backward {
            True -> last
            False -> first
          })
        }
        False -> Nil
      }
    }
  }
}
