/// Value types shared by the controller and browser binding.
import gleam/option.{type Option}

pub type TransitionCause {
  OpenCause
  CloseCause
  NavigateCause
  SnapCause
  ContentCause
  PresentationCause
  HydrateCause
  ApiCause
}

pub type Direction {
  Forward
  Backward
  ReplaceDirection
  SnapDirection
  NoDirection
}

pub type Motion {
  Auto
  Instant
}

pub type RegionTransition {
  Preserve
  Crossfade
  ReplaceRegion
}

pub type Presentation {
  Sheet
  Dialog
}

pub type Modality {
  Modal
  NonModal
}

pub type ResizeBehavior {
  Animate
  Immediate
  KeepSnapAndScroll
}

pub type Phase {
  ClosedPhase
  Preparing
  Opening
  OpenPhase
  Dragging
  Transitioning
  Closing
  DestroyedPhase
}

pub type InteractionOrigin {
  HandleOrigin
  DragAreaOrigin
}

pub type RequestOrigin {
  Trigger
  Api
  Gesture
  Keyboard
  BackdropOrigin
  CloseButtonOrigin
}

pub type CloseReason {
  Escape
  BackdropClose
  GestureClose
  CloseButton
  ApiClose
  RouteChange
}

pub type TransitionCancelReason {
  TransitionDestroyed
  DriverCancelled
  RegistryLost
}

pub type InteractionCancelReason {
  PointerCancelled
  CaptureLost
  VisibilityLost
  TargetChanged
  InteractionDestroyed
}

pub type Part {
  Portal
  Backdrop
  Viewport
  Popup
  Content
  Header
  Body
  Footer
  Handle
  InertTarget
}

pub type Region {
  HeaderRegion
  BodyRegion
  FooterRegion
}

pub type Layer {
  Settled
  Outgoing
  Incoming
}

pub type Transition {
  Transition(cause: TransitionCause, direction: Direction, motion: Motion)
}

pub type Size {
  Ratio(value: Float)
  Pixels(value: Float)
  ContentSize(max_ratio: Option(Float))
}

pub type SnapPoint {
  SnapPoint(id: String, size: Size)
}

pub type RegionTarget {
  RegionTarget(key: String, transition: RegionTransition)
}

pub type Regions {
  Regions(header: RegionTarget, body: RegionTarget, footer: RegionTarget)
}

pub type OpenOptions {
  OpenOptions(
    snap_points: List(SnapPoint),
    snap_point: String,
    presentation: Presentation,
    modality: Modality,
    draggable: Bool,
    sequential: Bool,
    resize_behavior: ResizeBehavior,
    regions: Regions,
  )
}

pub type Target {
  Closed(id: String, transition: Transition, cause_request_id: Option(Int))
  Open(
    id: String,
    options: OpenOptions,
    transition: Transition,
    cause_request_id: Option(Int),
  )
}

pub type Interaction {
  Interaction(id: Int, origin: InteractionOrigin)
}

pub type Snapshot {
  Snapshot(
    target: Option(Target),
    settled_target: Option(Target),
    phase: Phase,
    transition_id: Option(Int),
    interaction: Option(Interaction),
  )
}

pub type Release {
  Release(
    interaction_id: Int,
    distance: Float,
    velocity: Float,
    projected_height: Float,
  )
}

pub type Event {
  OpenRequested(sequence: Int, request_id: Int, origin: RequestOrigin)
  CloseRequested(
    sequence: Int,
    request_id: Int,
    origin: RequestOrigin,
    reason: CloseReason,
    release: Option(Release),
  )
  SnapRequested(
    sequence: Int,
    request_id: Int,
    origin: RequestOrigin,
    snap_point: String,
    release: Option(Release),
  )
  TargetSynced(sequence: Int, target: Target)
  TransitionStarted(sequence: Int, target_id: String, transition_id: Int)
  TransitionSettled(sequence: Int, target_id: String, transition_id: Int)
  TransitionReplaced(
    sequence: Int,
    target_id: String,
    transition_id: Int,
    replaced_by: Int,
  )
  TransitionCancelled(
    sequence: Int,
    target_id: String,
    transition_id: Int,
    reason: TransitionCancelReason,
  )
  InteractionStarted(
    sequence: Int,
    interaction_id: Int,
    origin: InteractionOrigin,
  )
  InteractionEnded(
    sequence: Int,
    interaction_id: Int,
    origin: InteractionOrigin,
  )
  InteractionCancelled(
    sequence: Int,
    interaction_id: Int,
    origin: InteractionOrigin,
    reason: InteractionCancelReason,
  )
  Destroyed(sequence: Int)
}

pub type Metrics {
  Metrics(
    viewport_height: Float,
    inset_top: Float,
    inset_bottom: Float,
    header_height: Float,
    body_natural_height: Float,
    footer_height: Float,
    min_height: Option(Float),
    max_height: Option(Float),
  )
}

pub type ResolvedSnapPoint {
  ResolvedSnapPoint(id: String, height: Float, declaration_index: Int)
}

pub type ReleaseOptions {
  ReleaseOptions(
    current_height: Float,
    active_snap_point: String,
    velocity: Float,
    drag_distance: Float,
    snap_points: List(ResolvedSnapPoint),
    allow_close: Bool,
    sequential: Bool,
    projection_time: Float,
    close_velocity_threshold: Float,
    close_distance_threshold: Float,
  )
}

pub type Destination {
  SnapTo(id: String)
  CloseDestination
}
