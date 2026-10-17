/// Pure state machine. Applications may own State directly (including on Erlang)
/// and interpret the returned publications. Browser consumers can use the
/// imperative controller in gleam_drawer, which delegates every command here.
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam_drawer/internal/validate as v
import gleam_drawer/model as m

pub opaque type State {
  State(
    snapshot: m.Snapshot,
    sequence: Int,
    request_id: Int,
    transition_counter: Int,
    interaction_counter: Int,
    active_transition: Option(#(Int, String)),
    pending_release: Option(Int),
    seen: Dict(String, m.Target),
  )
}

pub type Command {
  Sync(target: m.Target)
  RequestOpen(origin: m.RequestOrigin)
  RequestClose(
    reason: m.CloseReason,
    origin: m.RequestOrigin,
    release: Option(m.Release),
  )
  RequestSnap(
    point: String,
    origin: m.RequestOrigin,
    release: Option(m.Release),
  )
  BeginTransition(target_id: String)
  SettleTransition(id: Int)
  CancelTransition(id: Int, reason: m.TransitionCancelReason)
  BeginInteraction(origin: m.InteractionOrigin)
  EndInteraction(id: Int)
  CancelInteraction(id: Int, reason: m.InteractionCancelReason)
  Destroy
}

pub type Publication {
  Publication(snapshot: m.Snapshot, event: m.Event)
}

pub type Change {
  Change(state: State, publications: List(Publication), token: Option(Int))
}

pub fn new(initial: Option(m.Target)) -> Result(State, String) {
  use _ <- result.try(case initial {
    Some(t) -> v.target(t)
    None -> Ok(Nil)
  })
  let phase = case initial {
    Some(m.Open(..)) -> m.Preparing
    _ -> m.ClosedPhase
  }
  let seen = case initial {
    Some(t) -> dict.from_list([#(t.id, t)])
    None -> dict.new()
  }
  Ok(State(
    m.Snapshot(initial, None, phase, None, None),
    0,
    0,
    0,
    0,
    None,
    None,
    seen,
  ))
}

pub fn snapshot(state: State) -> m.Snapshot {
  state.snapshot
}

fn unchanged(state: State) {
  Change(state, [], None)
}

fn emit(state: State, event: fn(Int) -> m.Event) -> Change {
  let sequence = state.sequence + 1
  let next = State(..state, sequence: sequence)
  Change(next, [Publication(next.snapshot, event(sequence))], None)
}

fn combine(first: Change, second: Change) -> Change {
  Change(
    second.state,
    list.append(first.publications, second.publications),
    second.token,
  )
}

fn stable_phase(state: State) -> m.Phase {
  case state.snapshot.interaction {
    Some(_) -> m.Dragging
    None ->
      case state.active_transition, state.snapshot.target {
        Some(_), Some(m.Closed(..)) -> m.Closing
        Some(_), Some(m.Open(..)) ->
          case state.snapshot.settled_target {
            None -> m.Opening
            Some(_) -> m.Transitioning
          }
        _, Some(m.Open(id, _, _, _)) ->
          case state.snapshot.settled_target {
            Some(t) if t.id == id -> m.OpenPhase
            None -> m.Preparing
            _ -> m.OpenPhase
          }
        _, _ ->
          case state.snapshot.settled_target {
            Some(_) -> m.OpenPhase
            None -> m.ClosedPhase
          }
      }
  }
}

fn restabilize(state: State) -> State {
  State(
    ..state,
    snapshot: m.Snapshot(..state.snapshot, phase: stable_phase(state)),
  )
}

fn cancel_interaction(
  state: State,
  id: Int,
  reason: m.InteractionCancelReason,
) -> Change {
  case state.snapshot.interaction {
    Some(i) if i.id == id -> {
      let next =
        State(
          ..state,
          pending_release: None,
          snapshot: m.Snapshot(..state.snapshot, interaction: None),
        )
        |> restabilize
      emit(next, fn(sequence) {
        m.InteractionCancelled(sequence, id, i.origin, reason)
      })
    }
    _ -> unchanged(state)
  }
}

fn cancel_transition(
  state: State,
  id: Int,
  reason: m.TransitionCancelReason,
) -> Change {
  case state.active_transition {
    Some(#(active, target_id)) if active == id -> {
      let next =
        State(
          ..state,
          active_transition: None,
          snapshot: m.Snapshot(..state.snapshot, transition_id: None),
        )
        |> restabilize
      emit(next, fn(sequence) {
        m.TransitionCancelled(sequence, target_id, id, reason)
      })
    }
    _ -> unchanged(state)
  }
}

fn consume_release(
  state: State,
  release: Option(m.Release),
) -> Result(State, String) {
  case release {
    None -> Ok(state)
    Some(r) -> {
      use _ <- result.try(v.release(r))
      use _ <- result.try(v.require(
        state.pending_release == Some(r.interaction_id),
        "Release must match one just-ended interaction and can be consumed only once",
      ))
      Ok(State(..state, pending_release: None))
    }
  }
}

fn request(state: State, event: fn(Int, Int) -> m.Event) -> Change {
  let id = state.request_id + 1
  let change =
    emit(State(..state, request_id: id), fn(sequence) { event(sequence, id) })
  Change(..change, token: Some(id))
}

fn sync_target(state: State, target: m.Target) -> Result(Change, String) {
  use _ <- result.try(v.target(target))
  case state.snapshot.target {
    // Gleam values have structural identity: equal current targets are no-ops.
    Some(current) if current == target -> Ok(unchanged(state))
    current -> {
      use _ <- result.try(v.require(
        !dict.has_key(state.seen, target.id),
        "Target id was reused: " <> target.id,
      ))
      use _ <- result.try(case current {
        Some(old) -> v.preserved(old, target)
        None -> Ok(Nil)
      })
      let phase = case target, state.snapshot.settled_target {
        m.Closed(..), None -> m.ClosedPhase
        _, _ -> m.Preparing
      }
      let next =
        State(
          ..state,
          seen: dict.insert(state.seen, target.id, target),
          pending_release: None,
          snapshot: m.Snapshot(
            ..state.snapshot,
            target: Some(target),
            phase: phase,
          ),
        )
      let cancelled = case next.snapshot.interaction {
        Some(i) -> cancel_interaction(next, i.id, m.TargetChanged)
        None -> unchanged(next)
      }
      Ok(combine(
        cancelled,
        emit(cancelled.state, fn(sequence) { m.TargetSynced(sequence, target) }),
      ))
    }
  }
}

fn begin_transition(state: State, target_id: String) -> Result(Change, String) {
  use _ <- result.try(v.require(
    case state.snapshot.target {
      Some(t) -> t.id == target_id
      None -> False
    },
    "Cannot begin a transition for a non-authoritative target",
  ))
  let id = state.transition_counter + 1
  let next =
    State(
      ..state,
      transition_counter: id,
      active_transition: Some(#(id, target_id)),
      snapshot: m.Snapshot(..state.snapshot, transition_id: Some(id)),
    )
    |> restabilize
  let replaced = case state.active_transition {
    Some(#(old, old_target)) ->
      emit(next, fn(sequence) {
        m.TransitionReplaced(sequence, old_target, old, id)
      })
    None -> unchanged(next)
  }
  let change =
    combine(
      replaced,
      emit(replaced.state, fn(sequence) {
        m.TransitionStarted(sequence, target_id, id)
      }),
    )
  Ok(Change(..change, token: Some(id)))
}

fn settle_transition(state: State, id: Int) -> Change {
  case state.active_transition, state.snapshot.target {
    Some(#(active, target_id)), Some(target)
      if active == id && target_id == target.id
    -> {
      let settled = case target {
        m.Open(..) -> Some(target)
        m.Closed(..) -> None
      }
      let next =
        State(
          ..state,
          active_transition: None,
          snapshot: m.Snapshot(
            ..state.snapshot,
            settled_target: settled,
            transition_id: None,
          ),
        )
        |> restabilize
      emit(next, fn(sequence) { m.TransitionSettled(sequence, target_id, id) })
    }
    _, _ -> unchanged(state)
  }
}

fn begin_interaction(
  state: State,
  origin: m.InteractionOrigin,
) -> Result(Change, String) {
  use _ <- result.try(v.require(
    case state.snapshot.target {
      Some(m.Open(..)) -> True
      _ -> False
    },
    "Cannot interact with a closed drawer",
  ))
  use _ <- result.try(v.require(
    state.snapshot.interaction == None,
    "An interaction is already active",
  ))
  let id = state.interaction_counter + 1
  let next =
    State(
      ..state,
      interaction_counter: id,
      pending_release: None,
      snapshot: m.Snapshot(
        ..state.snapshot,
        interaction: Some(m.Interaction(id, origin)),
        phase: m.Dragging,
      ),
    )
  let change =
    emit(next, fn(sequence) { m.InteractionStarted(sequence, id, origin) })
  Ok(Change(..change, token: Some(id)))
}

fn end_interaction(state: State, id: Int) -> Change {
  case state.snapshot.interaction {
    Some(i) if i.id == id -> {
      let next =
        State(
          ..state,
          pending_release: Some(id),
          snapshot: m.Snapshot(..state.snapshot, interaction: None),
        )
        |> restabilize
      emit(next, fn(sequence) { m.InteractionEnded(sequence, id, i.origin) })
    }
    _ -> unchanged(state)
  }
}

fn destroy(state: State) -> Change {
  case state.snapshot.phase == m.DestroyedPhase {
    True -> unchanged(state)
    False -> {
      let interaction = case state.snapshot.interaction {
        Some(i) -> cancel_interaction(state, i.id, m.InteractionDestroyed)
        None -> unchanged(state)
      }
      let transition = case interaction.state.active_transition {
        Some(#(id, _)) ->
          cancel_transition(interaction.state, id, m.TransitionDestroyed)
        None -> unchanged(interaction.state)
      }
      let next =
        State(
          ..transition.state,
          seen: dict.new(),
          pending_release: None,
          snapshot: m.Snapshot(None, None, m.DestroyedPhase, None, None),
        )
      combine(combine(interaction, transition), emit(next, m.Destroyed))
    }
  }
}

/// Apply a command atomically. Each publication retains the snapshot at that
/// fact, including cancellation facts emitted while destroying the machine.
pub fn update(state: State, command: Command) -> Result(Change, String) {
  case command {
    Destroy -> Ok(destroy(state))
    _ -> {
      use _ <- result.try(v.require(
        state.snapshot.phase != m.DestroyedPhase,
        "Drawer controller has been destroyed",
      ))
      case command {
        Sync(target) -> sync_target(state, target)
        RequestOpen(origin) ->
          Ok(
            request(state, fn(sequence, id) {
              m.OpenRequested(sequence, id, origin)
            }),
          )
        RequestClose(reason, origin, release) -> {
          use next <- result.try(consume_release(state, release))
          Ok(
            request(next, fn(sequence, id) {
              m.CloseRequested(sequence, id, origin, reason, release)
            }),
          )
        }
        RequestSnap(point, origin, release) -> {
          use _ <- result.try(v.require(
            case state.snapshot.target {
              Some(m.Open(_, o, _, _)) ->
                list.any(o.snap_points, fn(p) { p.id == point })
              _ -> False
            },
            "Unknown snap point: " <> point,
          ))
          use next <- result.try(consume_release(state, release))
          Ok(
            request(next, fn(sequence, id) {
              m.SnapRequested(sequence, id, origin, point, release)
            }),
          )
        }
        BeginTransition(id) -> begin_transition(state, id)
        SettleTransition(id) -> Ok(settle_transition(state, id))
        CancelTransition(id, reason) -> Ok(cancel_transition(state, id, reason))
        BeginInteraction(origin) -> begin_interaction(state, origin)
        EndInteraction(id) -> Ok(end_interaction(state, id))
        CancelInteraction(id, reason) ->
          Ok(cancel_interaction(state, id, reason))
        Destroy -> Ok(unchanged(state))
      }
    }
  }
}
