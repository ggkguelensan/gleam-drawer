@target(javascript)
/// Browser driver implemented in Gleam. Only platform primitives use FFI.
import gleam_drawer.{type Cleanup, type Controller}
@target(javascript)
import gleam_drawer/browser/platform as b
@target(javascript)
import gleam_drawer/browser/registry as r
@target(javascript)
import gleam_drawer/browser/runtime
@target(javascript)
import gleam_drawer/model as m

@target(javascript)
pub type Element =
  b.Element

@target(javascript)
pub type Binding =
  runtime.Binding

pub type Options {
  Options(close_on_escape: Bool, close_on_backdrop: Bool)
}

pub fn defaults() -> Options {
  Options(True, True)
}

@target(javascript)
pub fn find_element(selector: String) -> Result(Element, String) {
  b.find(selector)
}

@target(javascript)
pub fn bind(
  controller: Controller,
  options: Options,
) -> Result(Binding, String) {
  runtime.new(controller, options.close_on_escape, options.close_on_backdrop)
}

@target(javascript)
pub fn register_part(
  binding: Binding,
  part: m.Part,
  element: Element,
) -> Result(Cleanup, String) {
  runtime.register(binding, r.Part(part), element)
}

@target(javascript)
pub fn register_layer(
  binding: Binding,
  region: m.Region,
  key: String,
  layer: m.Layer,
  element: Element,
) -> Result(Cleanup, String) {
  runtime.register(binding, r.Layer(region, key, layer), element)
}

@target(javascript)
pub fn register_surface(
  binding: Binding,
  region: m.Region,
  element: Element,
) -> Result(Cleanup, String) {
  runtime.register(binding, r.Surface(region), element)
}

@target(javascript)
pub fn register_drag_area(
  binding: Binding,
  element: Element,
  id: String,
) -> Result(Cleanup, String) {
  runtime.register(binding, r.Drag(id), element)
}

@target(javascript)
pub fn set_insets(
  binding: Binding,
  top: Float,
  bottom: Float,
) -> Result(Nil, String) {
  runtime.insets(binding, top, bottom)
}

@target(javascript)
pub fn refresh(binding: Binding) -> Result(Nil, String) {
  runtime.refresh(binding)
}

@target(javascript)
pub fn destroy(binding: Binding) -> Result(Nil, String) {
  runtime.destroy(binding)
}
