import gleam/option.{None, Some}
import gleam_drawer as drawer
import gleam_drawer/core
import gleam_drawer/model as m
import gleeunit/should

fn target(id: String) {
  drawer.opened(id, drawer.options([m.SnapPoint("half", m.Ratio(0.5))], "half"))
}

pub fn value_identity_and_preserved_regions_test() {
  let assert Ok(state) = core.new(Some(target("initial")))
  let assert Ok(change) = core.update(state, core.Sync(target("initial")))
  change.publications |> should.equal([])
  core.update(state, core.Sync(drawer.closed("initial"))) |> should.be_error
  let options = drawer.options([m.SnapPoint("half", m.Ratio(0.5))], "half")
  let regions =
    m.Regions(..options.regions, body: m.RegionTarget("other", m.Preserve))
  core.update(
    state,
    core.Sync(drawer.opened("new", m.OpenOptions(..options, regions: regions))),
  )
  |> should.be_error
  let regions = m.Regions(..regions, body: m.RegionTarget("other", m.Crossfade))
  core.update(
    state,
    core.Sync(drawer.opened("new", m.OpenOptions(..options, regions: regions))),
  )
  |> should.be_ok
}

pub fn release_is_consumed_once_and_cancel_clears_it_test() {
  let assert Ok(state) = core.new(Some(target("a")))
  let assert Ok(start) =
    core.update(state, core.BeginInteraction(m.HandleOrigin))
  let assert Some(id) = start.token
  core.update(start.state, core.BeginInteraction(m.HandleOrigin))
  |> should.be_error
  let assert Ok(ended) = core.update(start.state, core.EndInteraction(id))
  let release = Some(m.Release(id, 50.0, 0.5, 250.0))
  let assert Ok(requested) =
    core.update(ended.state, core.RequestSnap("half", m.Gesture, release))
  core.update(
    requested.state,
    core.RequestClose(m.GestureClose, m.Gesture, release),
  )
  |> should.be_error
  let assert Ok(start) =
    core.update(requested.state, core.BeginInteraction(m.DragAreaOrigin))
  let assert Some(id) = start.token
  let assert Ok(cancelled) =
    core.update(start.state, core.CancelInteraction(id, m.CaptureLost))
  core.snapshot(cancelled.state).interaction |> should.equal(None)
  core.update(
    cancelled.state,
    core.RequestClose(
      m.GestureClose,
      m.Gesture,
      Some(m.Release(id, 0.0, 0.0, 0.0)),
    ),
  )
  |> should.be_error
}

pub fn destroy_cancels_both_tokens_and_is_terminal_test() {
  let assert Ok(state) = core.new(Some(target("a")))
  let assert Ok(transition) = core.update(state, core.BeginTransition("a"))
  let assert Ok(interaction) =
    core.update(transition.state, core.BeginInteraction(m.HandleOrigin))
  let assert Ok(destroyed) = core.update(interaction.state, core.Destroy)
  let assert [
    core.Publication(_, m.InteractionCancelled(_, _, _, m.InteractionDestroyed)),
    core.Publication(_, m.TransitionCancelled(_, _, _, m.TransitionDestroyed)),
    core.Publication(final, m.Destroyed(_)),
  ] = destroyed.publications
  final.phase |> should.equal(m.DestroyedPhase)
  final.target |> should.equal(None)
  let assert Ok(again) = core.update(destroyed.state, core.Destroy)
  again.publications |> should.equal([])
  core.update(destroyed.state, core.Sync(target("b"))) |> should.be_error
}

pub fn stale_completion_never_settles_new_target_test() {
  let assert Ok(state) = core.new(Some(target("a")))
  let assert Ok(first) = core.update(state, core.BeginTransition("a"))
  let assert Some(old) = first.token
  let assert Ok(next) = core.update(first.state, core.Sync(target("b")))
  let assert Ok(stale) = core.update(next.state, core.SettleTransition(old))
  stale.publications |> should.equal([])
  core.snapshot(stale.state).settled_target |> should.equal(None)
  let assert Ok(started) = core.update(stale.state, core.BeginTransition("b"))
  let assert Some(id) = started.token
  let assert Ok(done) = core.update(started.state, core.SettleTransition(id))
  core.snapshot(done.state).phase |> should.equal(m.OpenPhase)
}
