@target(javascript)
/// Browser registrations, scoped to one controller. Importing is SSR-safe;
/// binding real elements requires ResizeObserver, Pointer Events and WAAPI.
import gleam_drawer.{type Cleanup, type Controller}
@target(javascript)
import gleam_drawer/model as m

pub type Element

pub type Binding

pub type Options {
  Options(close_on_escape: Bool, close_on_backdrop: Bool)
}

pub fn defaults() -> Options {
  Options(True, True)
}

@target(javascript)
/// Lookup is deferred until called. Missing elements return Error.
@external(javascript, "../gleam_drawer_ffi.mjs", "find_element")
pub fn find_element(selector: String) -> Result(Element, String)

@target(javascript)
@external(javascript, "../gleam_drawer_ffi.mjs", "bind")
pub fn bind(controller: Controller, options: Options) -> Result(Binding, String)

@target(javascript)
/// Register Portal first. Popup requires an accessible name supplied by the app.
@external(javascript, "../gleam_drawer_ffi.mjs", "register_part")
pub fn register_part(
  binding: Binding,
  part: m.Part,
  element: Element,
) -> Result(Cleanup, String)

@target(javascript)
@external(javascript, "../gleam_drawer_ffi.mjs", "register_layer")
pub fn register_layer(
  binding: Binding,
  region: m.Region,
  key: String,
  layer: m.Layer,
  element: Element,
) -> Result(Cleanup, String)

@target(javascript)
@external(javascript, "../gleam_drawer_ffi.mjs", "register_surface")
pub fn register_surface(
  binding: Binding,
  region: m.Region,
  element: Element,
) -> Result(Cleanup, String)

@target(javascript)
@external(javascript, "../gleam_drawer_ffi.mjs", "register_drag_area")
pub fn register_drag_area(
  binding: Binding,
  element: Element,
  id: String,
) -> Result(Cleanup, String)

@target(javascript)
@external(javascript, "../gleam_drawer_ffi.mjs", "set_insets")
pub fn set_insets(
  binding: Binding,
  top: Float,
  bottom: Float,
) -> Result(Nil, String)

@target(javascript)
@external(javascript, "../gleam_drawer_ffi.mjs", "refresh")
pub fn refresh(binding: Binding) -> Result(Nil, String)

@target(javascript)
/// Destroy the binding before destroying its controller.
@external(javascript, "../gleam_drawer_ffi.mjs", "destroy_binding")
pub fn destroy(binding: Binding) -> Result(Nil, String)
