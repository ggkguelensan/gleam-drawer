/// Pure Gleam geometry. No DOM, timers, mutable state or JavaScript FFI.
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/order.{Eq}
import gleam/result
import gleam_drawer/internal/validate as v
import gleam_drawer/model as m

pub fn resolve_snap_points(
  points: List(m.SnapPoint),
  metrics: m.Metrics,
) -> Result(List(m.ResolvedSnapPoint), String) {
  use _ <- result.try(v.snap_points(points))
  let min = option.unwrap(metrics.min_height, 0.0)
  let max = option.unwrap(metrics.max_height, metrics.viewport_height)
  use _ <- result.try(v.require(
    list.all(
      [
        metrics.viewport_height,
        metrics.inset_top,
        metrics.inset_bottom,
        metrics.header_height,
        metrics.body_natural_height,
        metrics.footer_height,
        min,
        max,
      ],
      v.non_negative,
    ),
    "Metrics must be finite and non-negative",
  ))
  // An omitted maximum is the viewport bound, not an explicit min/max pair.
  use _ <- result.try(v.require(
    case metrics.min_height, metrics.max_height {
      option.Some(a), option.Some(b) -> a <=. b
      _, _ -> True
    },
    "min_height must not exceed max_height",
  ))
  let available =
    float.max(
      0.0,
      metrics.viewport_height -. metrics.inset_top -. metrics.inset_bottom,
    )
  let upper = float.min(available, max)
  let lower = float.min(upper, min)
  let natural =
    metrics.header_height
    +. metrics.body_natural_height
    +. metrics.footer_height
  points
  |> list.index_map(fn(point, index) {
    let raw = case point.size {
      m.Ratio(value) -> available *. value
      m.Pixels(value) -> value
      m.ContentSize(max_ratio) ->
        float.min(natural, available *. option.unwrap(max_ratio, 1.0))
    }
    m.ResolvedSnapPoint(point.id, float.clamp(raw, lower, upper), index)
  })
  |> list.sort(compare_points)
  |> Ok
}

fn compare_points(a: m.ResolvedSnapPoint, b: m.ResolvedSnapPoint) {
  case float.compare(a.height, b.height) {
    Eq -> int.compare(a.declaration_index, b.declaration_index)
    other -> other
  }
}

fn physical_points(points: List(m.ResolvedSnapPoint), active: String) {
  points
  |> list.sort(compare_points)
  |> list.fold([], fn(acc: List(m.ResolvedSnapPoint), point) {
    case acc {
      [previous, ..rest] if previous.height == point.height ->
        case point.id == active {
          True -> [point, ..rest]
          False -> acc
        }
      _ -> [point, ..acc]
    }
  })
  |> list.reverse
}

pub fn select_release(o: m.ReleaseOptions) -> Result(m.Destination, String) {
  use _ <- result.try(v.require(
    list.all([o.current_height, o.velocity, o.drag_distance], v.finite)
      && list.all(
      [
        o.projection_time,
        o.close_velocity_threshold,
        o.close_distance_threshold,
      ],
      v.non_negative,
    ),
    "Invalid release values or thresholds",
  ))
  use _ <- result.try(v.require(
    !list.is_empty(o.snap_points),
    "Release requires snap points",
  ))
  let ids = list.map(o.snap_points, fn(p) { p.id })
  use _ <- result.try(v.require(
    list.length(ids) == list.length(list.unique(ids)),
    "Duplicate resolved snap point id",
  ))
  use _ <- result.try(v.require(
    list.contains(ids, o.active_snap_point),
    "Unknown active snap point: " <> o.active_snap_point,
  ))
  use _ <- result.try(v.require(
    list.all(o.snap_points, fn(p) {
      v.non_negative(p.height)
      && p.declaration_index >= 0
      && p.declaration_index <= 9_007_199_254_740_991
    }),
    "Invalid resolved snap point",
  ))
  let points = physical_points(o.snap_points, o.active_snap_point)
  let assert [lowest, ..] = points
  let projected = o.current_height -. o.velocity *. o.projection_time
  case
    o.allow_close
    && projected <. lowest.height
    && { o.velocity >. 0.0 || o.drag_distance >. 0.0 }
    && {
      o.velocity >=. o.close_velocity_threshold
      || o.drag_distance >=. o.close_distance_threshold
    }
  {
    True -> Ok(m.CloseDestination)
    False -> {
      let nearest =
        list.fold(points, lowest, fn(best, point) {
          let distance = float.absolute_value(point.height -. projected)
          let best_distance = float.absolute_value(best.height -. projected)
          case distance <. best_distance, distance >. best_distance {
            True, _ -> point
            _, True -> best
            _, _ ->
              case
                point.id == o.active_snap_point,
                best.id == o.active_snap_point
              {
                True, _ -> point
                _, True -> best
                _, _ ->
                  case point.declaration_index < best.declaration_index {
                    True -> point
                    False -> best
                  }
              }
          }
        })
      case o.sequential && projected != o.current_height {
        False -> Ok(m.SnapTo(nearest.id))
        True -> {
          let indexed = list.index_map(points, fn(p, i) { #(p, i) })
          let assert Ok(#(_, index)) =
            list.find(indexed, fn(pair) { pair.0.id == o.active_snap_point })
          let direction = case projected >. o.current_height {
            True -> 1
            False -> -1
          }
          let destination =
            int.clamp(index + direction, 0, list.length(points) - 1)
          let assert Ok(#(point, _)) =
            list.find(indexed, fn(pair) { pair.1 == destination })
          Ok(m.SnapTo(point.id))
        }
      }
    }
  }
}

pub fn rubber_band(
  value: Float,
  min: Float,
  max: Float,
  dimension: Float,
  constant: Float,
) -> Result(Float, String) {
  use _ <- result.try(v.require(
    list.all([value, min, max, dimension, constant], v.finite),
    "Rubber-band values must be finite",
  ))
  use _ <- result.try(v.require(
    min <=. max && dimension >=. 0.0 && constant >. 0.0,
    "Invalid rubber-band bounds, dimension or constant",
  ))
  case value >=. min && value <=. max {
    True -> Ok(value)
    False -> {
      let boundary = case value <. min {
        True -> min
        False -> max
      }
      let overshoot = value -. boundary
      let resisted = case dimension == 0.0 {
        True -> boundary
        False ->
          boundary
          +. { overshoot *. dimension *. constant }
          /. { dimension +. constant *. float.absolute_value(overshoot) }
      }
      use _ <- result.try(v.require(
        v.finite(resisted),
        "Rubber-band result must be finite",
      ))
      Ok(resisted)
    }
  }
}
