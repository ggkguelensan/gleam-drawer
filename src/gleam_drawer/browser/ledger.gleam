//// Track only properties owned by this binding, preserving outside mutations.

@target(javascript)
import gleam/list
@target(javascript)
import gleam/option.{type Option, None, Some}
@target(javascript)
import gleam_drawer/browser/platform as b

@target(javascript)
pub type Value {
  Style(String, String)
  Attribute(Option(String))
}

@target(javascript)
pub type Entry {
  Entry(element: b.Element, property: String, original: Value, owned: Value)
}

@target(javascript)
pub type Ledger =
  b.Ref(List(Entry))

@target(javascript)
pub fn new() -> Ledger {
  b.ref([])
}

@target(javascript)
fn matches(entry: Entry, element: b.Element, property: String, value: Value) {
  b.same(entry.element, element)
  && entry.property == property
  && case entry.owned, value {
    Style(..), Style(..) | Attribute(..), Attribute(..) -> True
    _, _ -> False
  }
}

@target(javascript)
fn remember(
  ledger: Ledger,
  element: b.Element,
  property: String,
  original: Value,
  value: Value,
) {
  let entries = b.get(ledger)
  case list.any(entries, matches(_, element, property, value)) {
    True ->
      b.set(
        ledger,
        list.map(entries, fn(e) {
          case matches(e, element, property, value) {
            True -> Entry(..e, owned: value)
            False -> e
          }
        }),
      )
    False ->
      b.set(ledger, [Entry(element, property, original, value), ..entries])
  }
}

@target(javascript)
pub fn style(
  ledger: Ledger,
  element: b.Element,
  property: String,
  value: String,
) {
  let old = b.style(element, property)
  b.set_style(element, property, value, "")
  // CSSOM normalizes numbers, colours and shorthand values. Track the actual
  // serialized value so teardown can distinguish our writes from external ones.
  let written = b.style(element, property)
  remember(
    ledger,
    element,
    property,
    Style(old.0, old.1),
    Style(written.0, written.1),
  )
}

@target(javascript)
pub fn attribute(
  ledger: Ledger,
  element: b.Element,
  property: String,
  value: Option(String),
) {
  remember(
    ledger,
    element,
    property,
    Attribute(b.attribute(element, property)),
    Attribute(value),
  )
  b.set_attribute(element, property, value)
}

@target(javascript)
pub fn toggle(
  ledger: Ledger,
  element: b.Element,
  property: String,
  present: Bool,
) {
  attribute(ledger, element, property, case present {
    True -> Some("")
    False -> None
  })
}

@target(javascript)
pub fn restore(ledger: Ledger) {
  list.each(b.get(ledger), fn(entry) {
    case entry.original, entry.owned {
      Style(value, priority), Style(owned, owned_priority) ->
        case
          b.style(entry.element, entry.property) == #(owned, owned_priority)
        {
          True -> b.set_style(entry.element, entry.property, value, priority)
          False -> Nil
        }
      Attribute(value), Attribute(owned) ->
        case b.attribute(entry.element, entry.property) == owned {
          True -> b.set_attribute(entry.element, entry.property, value)
          False -> Nil
        }
      _, _ -> Nil
    }
  })
  b.set(ledger, [])
}
