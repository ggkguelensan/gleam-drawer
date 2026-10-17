//// Browser primitives only. No drawer policy, state machine or animation plans.

@target(javascript)
import gleam/option.{type Option}

@target(javascript)
pub type Element

@target(javascript)
pub type Event

@target(javascript)
pub type Animation

@target(javascript)
pub type Ref(a)

@target(javascript)
pub type Cleanup =
  fn() -> Nil

@target(javascript)
pub type Rect {
  Rect(x: Float, y: Float, width: Float, height: Float)
}

@target(javascript)
pub type Viewport {
  Viewport(x: Float, y: Float, width: Float, height: Float)
}

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "ref")
pub fn ref(value: a) -> Ref(a)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "get")
pub fn get(ref: Ref(a)) -> a

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "set")
pub fn set(ref: Ref(a), value: a) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "attempt")
pub fn attempt(run: fn() -> a) -> Result(a, String)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "raise")
pub fn raise(message: String) -> a

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "shared")
pub fn shared(element: Element, key: String, initial: fn() -> a) -> Ref(a)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "same")
pub fn same(a: Element, b: Element) -> Bool

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "find")
pub fn find(selector: String) -> Result(Element, String)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "query")
pub fn query(element: Element, selector: String) -> List(Element)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "closest")
pub fn closest(element: Element, selector: String) -> Option(Element)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "siblings")
pub fn siblings(element: Element) -> List(Element)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "contains")
pub fn contains(parent: Element, child: Element) -> Bool

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "connected")
pub fn connected(element: Element) -> Bool

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "body")
pub fn body(element: Element) -> Element

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "active_element")
pub fn active_element(element: Element) -> Option(Element)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "focus")
pub fn focus(element: Element) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "attribute")
pub fn attribute(element: Element, name: String) -> Option(String)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "set_attribute")
pub fn set_attribute(
  element: Element,
  name: String,
  value: Option(String),
) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "style")
pub fn style(element: Element, name: String) -> #(String, String)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "set_style")
pub fn set_style(
  element: Element,
  name: String,
  value: String,
  priority: String,
) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "computed")
pub fn computed(element: Element, name: String) -> String

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "rect")
pub fn rect(element: Element) -> Rect

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "scroll_height")
pub fn scroll_height(element: Element) -> Float

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "layout_viewport")
pub fn layout_viewport(element: Element) -> Viewport

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "visual_viewport")
pub fn visual_viewport(element: Element) -> Option(Viewport)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "client_width")
pub fn client_width(element: Element) -> Float

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "scroll_position")
pub fn scroll_position(element: Element) -> #(Float, Float)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "scroll_to")
pub fn scroll_to(element: Element, x: Float, y: Float) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "reduced_motion")
pub fn reduced_motion(element: Element) -> Bool

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "visible")
pub fn visible(element: Element) -> Bool

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "supported")
pub fn supported(element: Element) -> Bool

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "frame")
pub fn frame(element: Element, callback: fn() -> Nil) -> Int

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "cancel_frame")
pub fn cancel_frame(element: Element, token: Int) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "microtask")
pub fn microtask(callback: fn() -> Nil) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "listen")
pub fn listen(
  element: Element,
  name: String,
  callback: fn(Event) -> Nil,
) -> Cleanup

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "listen_document")
pub fn listen_document(
  element: Element,
  name: String,
  callback: fn(Event) -> Nil,
) -> Cleanup

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "listen_viewport")
pub fn listen_viewport(element: Element, callback: fn() -> Nil) -> Cleanup

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "observe_size")
pub fn observe_size(
  element: Element,
  nodes: List(Element),
  callback: fn() -> Nil,
) -> Cleanup

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "number")
pub fn number(event: Event, field: String) -> Float

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "integer")
pub fn integer(event: Event, field: String) -> Int

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "boolean")
pub fn boolean(event: Event, field: String) -> Bool

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "text")
pub fn text(event: Event, field: String) -> String

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "event_target")
pub fn event_target(event: Event) -> Option(Element)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "prevent")
pub fn prevent(event: Event) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "capture")
pub fn capture(element: Element, id: Int) -> Result(Nil, String)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "release_capture")
pub fn release_capture(element: Element, id: Int) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "has_capture")
pub fn has_capture(element: Element, id: Int) -> Bool

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "animate")
pub fn animate(
  element: Element,
  frames: List(List(#(String, String))),
  duration: Float,
  easing: String,
  finished: fn(Bool) -> Nil,
) -> Animation

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "stop")
pub fn stop(animation: Animation) -> Nil

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "translation")
pub fn translation(element: Element) -> #(Float, Float)

@target(javascript)
@external(javascript, "./platform_ffi.mjs", "css_supports")
pub fn css_supports(element: Element, property: String, value: String) -> Bool
