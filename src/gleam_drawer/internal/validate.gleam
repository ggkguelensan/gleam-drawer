import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam_drawer/model as m

pub fn require(condition: Bool, message: String) -> Result(Nil, String) {
  case condition {
    True -> Ok(Nil)
    False -> Error(message)
  }
}

/// Comparisons reject NaN and infinities on JavaScript without a runtime FFI.
pub fn finite(value: Float) -> Bool {
  value <=. 1.7976931348623157e308 && value >=. -1.7976931348623157e308
}

pub fn non_negative(value: Float) -> Bool {
  finite(value) && value >=. 0.0
}

pub fn positive_id(value: Int) -> Bool {
  value > 0 && value <= 9_007_199_254_740_991
}

pub fn non_empty(value: String) -> Bool {
  string.trim(value) != ""
}

pub fn snap_points(points: List(m.SnapPoint)) -> Result(Nil, String) {
  use _ <- result.try(require(
    !list.is_empty(points),
    "At least one snap point is required",
  ))
  let ids = list.map(points, fn(p) { p.id })
  use _ <- result.try(require(
    list.length(ids) == list.length(list.unique(ids)),
    "Duplicate snap point id",
  ))
  list.try_each(points, fn(p) {
    use _ <- result.try(require(
      non_empty(p.id),
      "Snap point id must not be empty",
    ))
    let valid = case p.size {
      m.Ratio(v) -> finite(v) && v >. 0.0 && v <=. 1.0
      m.Pixels(v) -> non_negative(v)
      m.ContentSize(None) -> True
      m.ContentSize(Some(v)) -> finite(v) && v >. 0.0 && v <=. 1.0
    }
    require(valid, "Invalid size for snap point: " <> p.id)
  })
}

pub fn target(target: m.Target) -> Result(Nil, String) {
  use _ <- result.try(require(
    non_empty(target.id),
    "Target id must not be empty",
  ))
  let cause_request_id = case target {
    m.Closed(_, _, id) -> id
    m.Open(_, _, _, id) -> id
  }
  use _ <- result.try(case cause_request_id {
    None -> Ok(Nil)
    Some(id) ->
      require(positive_id(id), "Request id must be a positive safe integer")
  })
  case target {
    m.Closed(..) -> Ok(Nil)
    m.Open(_, o, _, _) -> {
      use _ <- result.try(snap_points(o.snap_points))
      use _ <- result.try(require(
        list.any(o.snap_points, fn(p) { p.id == o.snap_point }),
        "Unknown selected snap point: " <> o.snap_point,
      ))
      require(
        list.all([o.regions.header, o.regions.body, o.regions.footer], fn(r) {
          non_empty(r.key)
        }),
        "Region keys must not be empty",
      )
    }
  }
}

pub fn preserved(previous: m.Target, next: m.Target) -> Result(Nil, String) {
  case previous, next {
    m.Open(_, a, _, _), m.Open(_, b, _, _) -> {
      list.try_each(
        [
          #(a.regions.header, b.regions.header),
          #(a.regions.body, b.regions.body),
          #(a.regions.footer, b.regions.footer),
        ],
        fn(pair) {
          require(
            pair.1.transition != m.Preserve || pair.0.key == pair.1.key,
            "A preserved region cannot change key",
          )
        },
      )
    }
    _, _ -> Ok(Nil)
  }
}

pub fn release(r: m.Release) -> Result(Nil, String) {
  require(
    positive_id(r.interaction_id)
      && list.all([r.distance, r.velocity, r.projected_height], finite),
    "Invalid gesture release evidence",
  )
}
