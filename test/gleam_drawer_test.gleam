import gleam/option.{None, Some}
@target(javascript)
import gleam_drawer as drawer
import gleam_drawer/geometry
import gleam_drawer/model as m
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

@target(javascript)
fn target(id: String) {
  drawer.opened(id, drawer.options([m.SnapPoint("half", m.Ratio(0.5))], "half"))
}

@target(javascript)
pub fn lifecycle_and_stale_completion_test() {
  let first = target("first")
  let assert Ok(c) = drawer.create(Some(first))
  drawer.sync(c, first) |> should.equal(Ok(Nil))
  let assert Ok(old) = drawer.begin_transition(c, "first")
  drawer.sync(c, target("second")) |> should.equal(Ok(Nil))
  let assert Ok(current) = drawer.begin_transition(c, "second")
  drawer.settle_transition(c, old) |> should.equal(Ok(Nil))
  drawer.snapshot(c).phase |> should.equal(m.Opening)
  drawer.settle_transition(c, current) |> should.equal(Ok(Nil))
  drawer.snapshot(c).phase |> should.equal(m.OpenPhase)
  drawer.request_close(c, m.Escape, m.Keyboard, None) |> should.be_ok
  drawer.snapshot(c).phase |> should.equal(m.OpenPhase)
  drawer.sync(c, drawer.closed("closed")) |> should.equal(Ok(Nil))
  let assert Ok(id) = drawer.begin_transition(c, "closed")
  drawer.settle_transition(c, id) |> should.equal(Ok(Nil))
  drawer.snapshot(c).settled_target |> should.equal(None)
  drawer.destroy(c) |> should.equal(Ok(Nil))
  drawer.destroy(c) |> should.equal(Ok(Nil))
  drawer.request_open(c, m.Api) |> should.be_error
}

@target(javascript)
pub fn validation_test() {
  drawer.create(Some(drawer.opened("bad", drawer.options([], "none"))))
  |> should.be_error
  let assert Ok(c) = drawer.create(Some(target("same")))
  drawer.sync(c, drawer.closed("same")) |> should.be_error
  drawer.request_snap(c, "unknown", m.Api, None) |> should.be_error
  drawer.destroy(c) |> should.be_ok
}

pub fn geometry_conversion_test() {
  let points = [
    m.SnapPoint("half", m.Ratio(0.5)),
    m.SnapPoint("content", m.ContentSize(Some(0.8))),
    m.SnapPoint("pixels", m.Pixels(900.0)),
  ]
  let assert Ok(resolved) =
    geometry.resolve_snap_points(
      points,
      m.Metrics(800.0, 20.0, 20.0, 40.0, 120.0, 40.0, None, None),
    )
  resolved
  |> should.equal([
    m.ResolvedSnapPoint("content", 200.0, 1),
    m.ResolvedSnapPoint("half", 380.0, 0),
    m.ResolvedSnapPoint("pixels", 760.0, 2),
  ])
  geometry.select_release(m.ReleaseOptions(
    380.0,
    "half",
    0.0,
    0.0,
    resolved,
    False,
    False,
    200.0,
    0.5,
    100.0,
  ))
  |> should.equal(Ok(m.SnapTo("half")))
  geometry.rubber_band(50.0, 0.0, 100.0, 800.0, 0.55)
  |> should.equal(Ok(50.0))
}
