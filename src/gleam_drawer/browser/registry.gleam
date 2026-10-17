@target(javascript)
import gleam/list
@target(javascript)
import gleam/option.{type Option, None, Some}
@target(javascript)
import gleam_drawer/browser/platform as b
@target(javascript)
import gleam_drawer/model as m

@target(javascript)
pub type Slot {
  Part(m.Part)
  Layer(m.Region, String, m.Layer)
  Surface(m.Region)
  Drag(String)
}

@target(javascript)
pub type Entry {
  Entry(slot: Slot, element: b.Element, token: Int)
}

@target(javascript)
pub type Registry {
  Registry(entries: List(Entry), token: Int)
}

@target(javascript)
pub fn new() {
  Registry([], 0)
}

@target(javascript)
fn same_slot(a: Slot, z: Slot) {
  case a, z {
    Part(a), Part(z) -> a == z
    Layer(a, _, x), Layer(z, _, y) -> a == z && x == y
    Surface(a), Surface(z) -> a == z
    _, _ -> False
  }
}

@target(javascript)
pub fn add(registry: Registry, slot: Slot, element: b.Element) -> Registry {
  let id = registry.token + 1
  Registry(
    [
      Entry(slot, element, id),
      ..list.filter(registry.entries, fn(e) { !same_slot(e.slot, slot) })
    ],
    id,
  )
}

@target(javascript)
pub fn remove(registry: Registry, token: Int) -> Registry {
  Registry(
    ..registry,
    entries: list.filter(registry.entries, fn(e) { e.token != token }),
  )
}

@target(javascript)
pub fn part(registry: Registry, part: m.Part) -> Option(b.Element) {
  list.find_map(registry.entries, fn(e) {
    case e.slot {
      Part(p) if p == part -> Ok(e.element)
      _ -> Error(Nil)
    }
  })
  |> option_result
}

@target(javascript)
fn option_result(value: Result(a, e)) -> Option(a) {
  case value {
    Ok(v) -> Some(v)
    _ -> None
  }
}

@target(javascript)
pub fn layer(
  registry: Registry,
  region: m.Region,
  key: String,
) -> Option(b.Element) {
  list.find_map([m.Incoming, m.Settled, m.Outgoing], fn(priority) {
    list.find_map(registry.entries, fn(e) {
      case e.slot {
        Layer(r, k, p) if r == region && k == key && p == priority ->
          Ok(e.element)
        _ -> Error(Nil)
      }
    })
  })
  |> option_result
}

@target(javascript)
pub fn surface(registry: Registry, region: m.Region) -> Option(b.Element) {
  list.find_map(registry.entries, fn(e) {
    case e.slot {
      Surface(r) if r == region -> Ok(e.element)
      _ -> Error(Nil)
    }
  })
  |> option_result
}

@target(javascript)
pub fn region(target: m.OpenOptions, region: m.Region) -> m.RegionTarget {
  case region {
    m.HeaderRegion -> target.regions.header
    m.BodyRegion -> target.regions.body
    m.FooterRegion -> target.regions.footer
  }
}

@target(javascript)
pub fn region_name(region: m.Region) {
  case region {
    m.HeaderRegion -> "header"
    m.BodyRegion -> "body"
    m.FooterRegion -> "footer"
  }
}

@target(javascript)
pub fn host(region: m.Region) {
  case region {
    m.HeaderRegion -> m.Header
    m.BodyRegion -> m.Body
    m.FooterRegion -> m.Footer
  }
}

@target(javascript)
pub fn ready(registry: Registry, target: m.OpenOptions) {
  let parts = [
    m.Portal,
    m.Viewport,
    m.Popup,
    m.Content,
    m.Header,
    m.Body,
    m.Footer,
  ]
  list.all(parts, fn(p) { part(registry, p) != None })
  && { target.modality != m.Modal || part(registry, m.Backdrop) != None }
  && list.all([m.HeaderRegion, m.BodyRegion, m.FooterRegion], fn(r) {
    layer(registry, r, region(target, r).key) != None
  })
}
