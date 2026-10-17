import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam_drawer as drawer
import gleam_drawer/dom
import gleam_drawer/model as m

@external(javascript, "./demo_ffi.mjs", "on_click")
fn on_click(selector: String, callback: fn() -> Nil) -> drawer.Cleanup

@external(javascript, "./demo_ffi.mjs", "on_dispose")
fn on_dispose(callback: fn() -> Nil) -> Nil

@external(javascript, "./demo_ffi.mjs", "set_status")
fn set_status(status: String) -> Nil

fn initial_options() {
  drawer.options(
    [
      m.SnapPoint("compact", m.Ratio(0.45)),
      m.SnapPoint("expanded", m.Ratio(0.85)),
      m.SnapPoint("content", m.ContentSize(Some(0.9))),
    ],
    "compact",
  )
}

fn active_options(c: drawer.Controller) {
  case drawer.snapshot(c).target {
    Some(m.Open(_, options, _, _)) -> options
    _ -> initial_options()
  }
}

fn register(binding: dom.Binding, part: m.Part, selector: String) {
  let assert Ok(element) = dom.find_element(selector)
  let assert Ok(cleanup) = dom.register_part(binding, part, element)
  cleanup
}

fn handle_event(c: drawer.Controller, event: m.Event) {
  case event {
    m.OpenRequested(_, id, _) -> {
      let assert Ok(_) =
        drawer.sync(
          c,
          m.Open(
            "open-" <> int.to_string(id),
            initial_options(),
            drawer.transition(m.OpenCause),
            Some(id),
          ),
        )
      Nil
    }
    m.CloseRequested(_, id, _, _, _) -> {
      let assert Ok(_) =
        drawer.sync(
          c,
          m.Closed(
            "close-" <> int.to_string(id),
            drawer.transition(m.CloseCause),
            Some(id),
          ),
        )
      Nil
    }
    m.SnapRequested(_, id, _, point, _) -> {
      let options = m.OpenOptions(..active_options(c), snap_point: point)
      let assert Ok(_) =
        drawer.sync(
          c,
          m.Open(
            "snap-" <> int.to_string(id),
            options,
            drawer.transition(m.SnapCause),
            Some(id),
          ),
        )
      Nil
    }
    m.TransitionSettled(sequence, _, _) ->
      set_status("Settled · " <> int.to_string(sequence))
    _ -> Nil
  }
}

pub fn main() {
  let assert Ok(c) = drawer.create(Some(drawer.closed("initial")))
  let assert Ok(binding) = dom.bind(c, dom.defaults())
  let registrations =
    list.map(
      [
        #(m.Portal, "#portal"),
        #(m.Backdrop, "#backdrop"),
        #(m.Viewport, "#viewport"),
        #(m.Popup, "#popup"),
        #(m.Content, "#content"),
        #(m.Header, "#header"),
        #(m.Body, "#body"),
        #(m.Footer, "#footer"),
        #(m.Handle, "#handle"),
        #(m.InertTarget, "#app"),
      ],
      fn(pair) { register(binding, pair.0, pair.1) },
    )
  let layers =
    list.map(
      [
        #(m.HeaderRegion, "header", "#header-layer"),
        #(m.BodyRegion, "body", "#body-layer"),
        #(m.FooterRegion, "footer", "#footer-layer"),
      ],
      fn(item) {
        let assert Ok(element) = dom.find_element(item.2)
        let assert Ok(cleanup) =
          dom.register_layer(binding, item.0, item.1, m.Settled, element)
        cleanup
      },
    )
  let assert Ok(_) = dom.set_insets(binding, 16.0, 0.0)
  let unsubscribe = drawer.subscribe(c, fn(_, event) { handle_event(c, event) })
  let listeners = [
    on_click("#open", fn() {
      let assert Ok(_) = drawer.request_open(c, m.Trigger)
      Nil
    }),
    on_click("#close", fn() {
      let assert Ok(_) =
        drawer.request_close(c, m.CloseButton, m.CloseButtonOrigin, None)
      Nil
    }),
    on_click("#expand", fn() {
      let point = case active_options(c).snap_point {
        "expanded" -> "compact"
        _ -> "expanded"
      }
      let assert Ok(_) = drawer.request_snap(c, point, m.Api, None)
      Nil
    }),
    on_click("#fit", fn() {
      let assert Ok(_) = drawer.request_snap(c, "content", m.Api, None)
      Nil
    }),
    on_click("#morph", fn() {
      case drawer.snapshot(c).target {
        Some(m.Open(id, options, _, _)) -> {
          let presentation = case options.presentation {
            m.Sheet -> m.Dialog
            m.Dialog -> m.Sheet
          }
          let assert Ok(_) =
            drawer.sync(
              c,
              m.Open(
                id <> "-morph",
                m.OpenOptions(..options, presentation: presentation),
                drawer.transition(m.PresentationCause),
                None,
              ),
            )
          Nil
        }
        _ -> Nil
      }
    }),
  ]
  on_dispose(fn() {
    list.each(list.append(listeners, [unsubscribe]), fn(cleanup) { cleanup() })
    list.each(list.append(layers, registrations), fn(cleanup) { cleanup() })
    let assert Ok(_) = dom.destroy(binding)
    let assert Ok(_) = drawer.destroy(c)
    Nil
  })
}
