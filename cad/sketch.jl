# The geometry of a sketch: where its curves go, what's near the mouse, which
# closed region a click is in, and how a dimension is drawn.
#
# SolidCraft describes a sketch as JSON (`sketch.inspect`): a plane, points,
# curves and constraints. A place in a sketch is two numbers, x and y in mm on
# the sketch's plane. Nothing here draws or asks SolidCraft anything.
#
#     f = Frame(sketch["plane"])
#     world(f, (10.0, 5.0))                  # that place of the sketch as a point of the design
#     on_plane(f, ray)                       # where a line of sight meets the plane, as x and y
#     outline(curve)                         # places along a curve: 2 for a line, many for an arc
#     r = Regions(sketch)                    # the closed regions that its curves make
#     region(r, (10.0, 5.0))                 # the number of the region at a place, or 0
#     nearest(sketch, (10.0, 5.0), 0.8)      # the point or the curve within 0.8 mm of a place
#
# SolidCraft finds the region of an extrude from a place inside it, so the
# editor only needs to know which region the mouse is in, to show it. A grid
# does that: each curve marks the cells that it crosses, and the cells
# between them are filled region by region.

@use "./scene" Vec3 dot cross unit len

const Spot = NTuple{2,Float64}

"A sketch's plane: where its origin is in the design, and the ways its x and y go"
struct Frame
  origin::Vec3
  x::Vec3
  y::Vec3
end

vec3(l) = (Float64(l[1]), Float64(l[2]), Float64(l[3]))
spot(l) = (Float64(l[1]), Float64(l[2]))

Frame(plane::AbstractDict) = Frame(vec3(plane["origin"]), unit(vec3(plane["x_dir"])), unit(vec3(plane["y_dir"])))

"The way the plane faces"
normal(f::Frame) = unit(cross(f.x, f.y))

world(f::Frame, p) = f.origin .+ f.x .* p[1] .+ f.y .* p[2]
flat(f::Frame, p::Vec3) = (d = p .- f.origin; (dot(d, f.x), dot(d, f.y)))

"Where the line of sight `(from, way)` meets the plane, as a place of the sketch, or nothing when it runs along the plane"
on_plane(f::Frame, (from, way)) = begin
  n = normal(f)
  d = dot(way, n)
  abs(d) < 1e-9 && return nothing
  t = dot(f.origin .- from, n) / d
  flat(f, from .+ way .* t)
end

# --- curves --------------------------------------------------------------------------

const ROUND = 72   # how many straight parts a whole circle is drawn with

"The angle of the place `p` round `c`, in radians from the x axis"
angle(c, p) = atan(p[2] - c[2], p[1] - c[1])

"Places along a part of a circle round `c`, from the angle `a` to the angle `b`, counter-clockwise"
sweep(c, r, a, b) = begin
  turn = mod(b - a, 2π)
  turn < 1e-9 && (turn = 2π)
  n = max(2, ceil(Int, ROUND * turn / 2π))
  Spot[(c[1] + r * cos(a + turn * i / n), c[2] + r * sin(a + turn * i / n)) for i in 0:n]
end

"Places along the curve `c` of a sketch, close enough together to draw it with straight lines"
outline(c::AbstractDict) = begin
  kind = get(c, "type", "")
  if kind == "line"
    Spot[spot(c["start_at"]), spot(c["end_at"])]
  elseif kind == "circle"
    sweep(spot(c["center_at"]), Float64(c["radius"]), 0.0, 2π)
  elseif kind == "arc"
    o = spot(c["center_at"])
    sweep(o, Float64(c["radius"]), angle(o, spot(c["start_at"])), angle(o, spot(c["end_at"])))
  elseif kind == "ellipse"
    o, m = spot(c["center_at"]), spot(c["major_at"])
    a, b, turn = hypot(m[1] - o[1], m[2] - o[2]), Float64(c["minor_radius"]), angle(o, m)
    Spot[(o[1] + a * cos(t) * cos(turn) - b * sin(t) * sin(turn), o[2] + a * cos(t) * sin(turn) + b * sin(t) * cos(turn)) for t in range(0, 2π, length=ROUND + 1)]
  elseif kind == "conic"
    s, e, apex = spot(c["start_at"]), spot(c["end_at"]), spot(c["apex_at"])
    rho = Float64(get(c, "rho", 0.5))
    w = rho / max(1 - rho, 1e-9)
    map(range(0, 1, length=25)) do t
      a, b, d = (1 - t)^2, 2t * (1 - t) * w, t^2
      ((a * s[1] + b * apex[1] + d * e[1]) / (a + b + d), (a * s[2] + b * apex[2] + d * e[2]) / (a + b + d))
    end
  elseif haskey(c, "points_at") && c["points_at"] isa Vector && length(c["points_at"]) >= 2
    points = Spot[spot(p) for p in c["points_at"]]
    get(c, "control", false) === true ? pulled(points) : through(points, get(c, "periodic", false) === true)
  elseif haskey(c, "start_at") && haskey(c, "end_at") && c["start_at"] !== nothing && c["end_at"] !== nothing
    Spot[spot(c["start_at"]), spot(c["end_at"])]
  else
    Spot[]
  end
end

const PIECES = 16   # how many straight parts draw a spline between two of its points

"""
The spline through `points` as SolidCraft draws it, with more places between
each two. It's the smoothest curve of cubic pieces through them: its bend
changes evenly along each piece, and at an open end it has no bend. How far
along the curve a point is counts by the straight distance between the points.
A `closed` spline comes back to its first point as smoothly.
"""
through(points::Vector{Spot}, closed=false) = begin
  n = length(points)
  n < 3 && return points
  # A closed spline is worked out as an open one that goes round three times. Its middle round is almost the closed one.
  lap = closed ? n : 0
  all = closed ? vcat(points, points, points, [points[1]]) : points
  m = length(all)
  h = [max(hypot(all[k+1][1] - all[k][1], all[k+1][2] - all[k][2]), 1e-9) for k in 1:m-1]
  bends = (bend(h, first.(all)), bend(h, last.(all)))
  out = Spot[]
  for k in (closed ? (lap+1:2lap) : (1:m-1)), i in 0:PIECES-1
    b = i / PIECES
    a = 1 - b
    push!(out, ntuple(d -> a * all[k][d] + b * all[k+1][d] + ((a^3 - a) * bends[d][k] + (b^3 - b) * bends[d][k+1]) * h[k]^2 / 6, 2))
  end
  push!(out, closed ? out[1] : points[end])
  out
end

"How much the smoothest curve through the numbers `y`, which are `h` apart, bends at each of them"
bend(h, y) = begin
  n = length(y)
  # Three numbers in each row: the row of each point but the ends ties its bend to its neighbours'
  low, mid, high, right = zeros(n), ones(n), zeros(n), zeros(n)
  for k in 2:n-1
    low[k], mid[k], high[k] = h[k-1], 2(h[k-1] + h[k]), h[k]
    right[k] = 6((y[k+1] - y[k]) / h[k] - (y[k] - y[k-1]) / h[k-1])
  end
  for k in 2:n
    w = low[k] / mid[k-1]
    mid[k] -= w * high[k-1]
    right[k] -= w * right[k-1]
  end
  out = zeros(n)
  out[n] = right[n] / mid[n]
  for k in n-1:-1:1
    out[k] = (right[k] - high[k] * out[k+1]) / mid[k]
  end
  out
end

"""
The spline that the control points `points` pull towards them, as SolidCraft
draws it: a cubic B-spline that starts at the first point and ends at the last.
"""
pulled(points::Vector{Spot}) = begin
  n = length(points)
  n < 3 && return points
  degree = min(3, n - 1)
  # The knots: `degree + 1` at each end, and evenly between
  spans = n - degree
  knots = Float64[clamp(i - degree, 0, spans) for i in 0:n+degree]
  out = Spot[]
  for i in 0:PIECES*spans
    t = min(i / PIECES, spans - 1e-9)
    k = floor(Int, t) + degree + 1          # the knot span that t is in, counted from 1
    d = [points[j+k-degree] for j in 0:degree]
    for r in 1:degree, j in degree:-1:r
      a = (t - knots[j+k-degree]) / (knots[j+1+k-r] - knots[j+k-degree])
      d[j+1] = d[j] .* (1 - a) .+ d[j+1] .* a
    end
    push!(out, d[degree+1])
  end
  out[end] = points[end]
  out
end

"How far the place `p` is from the line between `a` and `b`, and the nearest place on it"
off(p, a, b) = begin
  dx, dy = b[1] - a[1], b[2] - a[2]
  l = dx^2 + dy^2
  t = l == 0 ? 0.0 : clamp(((p[1] - a[1]) * dx + (p[2] - a[2]) * dy) / l, 0.0, 1.0)
  q = (a[1] + t * dx, a[2] + t * dy)
  (hypot(p[1] - q[1], p[2] - q[2]), q)
end

"How far the place `p` is from the run of places `line`, and the nearest place on it"
off(p, line::Vector{Spot}) = begin
  best, where = Inf, p
  for i in 1:length(line)-1
    d, q = off(p, line[i], line[i+1])
    d < best && ((best, where) = (d, q))
  end
  (best, where)
end

"""
What of `sketch` is within `reach` mm of the place `p`: `(:point, id, place)`
for a point, `(:curve, id, place)` for a curve, with the nearest place on it,
or nothing. A point wins over a curve that's as near.
"""
nearest(sketch::AbstractDict, p, reach; points=true, curves=true) = begin
  if points
    best, found = reach, nothing
    for q in get(sketch, "points", Any[])
      at = spot(q["at"])
      d = hypot(at[1] - p[1], at[2] - p[2])
      d <= best && ((best, found) = (d, (:point, String(q["id"]), at)))
    end
    found === nothing || return found
  end
  curves || return nothing
  best, found = reach, nothing
  for c in get(sketch, "curves", Any[])
    line = outline(c)
    length(line) < 2 && continue
    d, q = off(p, line)
    d <= best && ((best, found) = (d, (:curve, String(c["id"]), q)))
  end
  found
end

"The corners of the box round everything in `sketch`: its low corner and its high one, or nothing for an empty sketch"
bounds(sketch::AbstractDict) = begin
  low, high = (Inf, Inf), (-Inf, -Inf)
  for c in get(sketch, "curves", Any[]), p in outline(c)
    low, high = min.(low, p), max.(high, p)
  end
  for q in get(sketch, "points", Any[])
    get(q, "id", "") == "origin" && continue
    p = spot(q["at"])
    low, high = min.(low, p), max.(high, p)
  end
  isfinite(low[1]) ? (low, high) : nothing
end

# --- the closed regions --------------------------------------------------------------

const CELLS = 640   # along the longer side of a sketch

"The regions that the curves of a sketch close off, on a grid. Cell 0 is a curve, 1 is outside every region, and 2 and up are the regions."
struct Regions
  cells::Matrix{Int32}   # [column, row]
  low::Spot              # the place of the corner of the first cell
  step::Float64          # how many mm a cell is wide
  count::Int             # how many regions there are
end

Regions(sketch::AbstractDict) = begin
  lines = [outline(c) for c in get(sketch, "curves", Any[]) if get(c, "construction", false) !== true]
  filter!(l -> length(l) >= 2, lines)
  isempty(lines) && return Regions(zeros(Int32, 1, 1), (0.0, 0.0), 1.0, 0)
  low, high = (Inf, Inf), (-Inf, -Inf)
  for l in lines, p in l
    low, high = min.(low, p), max.(high, p)
  end
  span = max(high[1] - low[1], high[2] - low[2], 1e-6)
  step = span / CELLS
  # Two cells of room round the curves, so that the outside is one piece
  low = low .- 2step
  w, h = ceil(Int, (high[1] - low[1]) / step) + 3, ceil(Int, (high[2] - low[2]) / step) + 3
  cells = fill(Int32(-1), w, h)
  for l in lines, i in 1:length(l)-1
    a, b = l[i], l[i+1]
    n = max(1, ceil(Int, 2hypot(b[1] - a[1], b[2] - a[2]) / step))
    for k in 0:n
      x, y = a[1] + (b[1] - a[1]) * k / n, a[2] + (b[2] - a[2]) * k / n
      cells[clamp(floor(Int, (x - low[1]) / step) + 1, 1, w), clamp(floor(Int, (y - low[2]) / step) + 1, 1, h)] = 0
    end
  end
  flood!(cells, 1, 1, Int32(1))
  count = 1
  for j in 1:h, i in 1:w
    cells[i, j] == -1 || continue
    count += 1
    flood!(cells, i, j, Int32(count))
  end
  Regions(cells, low, step, count - 1)
end

"Give the cell at column `i` and row `j`, and every free cell joined to it, the number `n`"
flood!(cells::Matrix{Int32}, i, j, n::Int32) = begin
  w, h = size(cells)
  cells[i, j] == -1 || return
  cells[i, j] = n
  todo = [(i, j)]
  while !isempty(todo)
    x, y = pop!(todo)
    for (a, b) in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
      (1 <= a <= w && 1 <= b <= h && cells[a, b] == -1) || continue
      cells[a, b] = n
      push!(todo, (a, b))
    end
  end
end

"The number of the region at the place `p`: 2 and up, or 0 when the place is in no closed region"
region(r::Regions, p) = begin
  w, h = size(r.cells)
  i, j = floor(Int, (p[1] - r.low[1]) / r.step) + 1, floor(Int, (p[2] - r.low[2]) / r.step) + 1
  (1 <= i <= w && 1 <= j <= h) || return 0
  n = Int(r.cells[i, j])
  if n == 0
    # On a curve: the region beside it, if only one is
    near = Set(Int(r.cells[a, b]) for a in max(1, i - 1):min(w, i + 1), b in max(1, j - 1):min(h, j + 1) if r.cells[a, b] >= 2)
    return length(near) == 1 ? first(near) : 0
  end
  n >= 2 ? n : 0
end

"The region `n` as strips: each is a row of the sketch from one x to another, `(x1, x2, y1, y2)`"
strips(r::Regions, n::Int) = begin
  w, h = size(r.cells)
  out = NTuple{4,Float64}[]
  for j in 1:h
    i = 1
    while i <= w
      if r.cells[i, j] == n
        from = i
        while i <= w && r.cells[i, j] == n
          i += 1
        end
        # Half a cell more at each end, where the curve's own cells are
        push!(out, (r.low[1] + (from - 1.5) * r.step, r.low[1] + (i - 0.5) * r.step, r.low[2] + (j - 1) * r.step, r.low[2] + j * r.step))
      else
        i += 1
      end
    end
  end
  out
end

"A place well inside the region `n`: SolidCraft finds the region again from it"
inside(r::Regions, n::Int) = begin
  w, h = size(r.cells)
  best, where = -1, (0.0, 0.0)
  # The middle of the longest strip is far from the curves at its ends
  for j in 1:h
    i = 1
    while i <= w
      if r.cells[i, j] == n
        from = i
        while i <= w && r.cells[i, j] == n
          i += 1
        end
        # A row with the region over and under it is far from the curves there too
        mid = (from + i - 1) ÷ 2
        deep = 0
        while j - deep - 1 >= 1 && j + deep + 1 <= h && r.cells[mid, j-deep-1] == n && r.cells[mid, j+deep+1] == n && deep < 40
          deep += 1
        end
        score = min(i - from, 2deep + 1)
        score > best && ((best, where) = (score, (r.low[1] + (mid - 0.5) * r.step, r.low[2] + (j - 0.5) * r.step)))
      else
        i += 1
      end
    end
  end
  where
end

# --- dimensions ----------------------------------------------------------------------

"A number with `digits` digits after its point, like 45.00"
fixed(x, digits=2) = begin
  s = lpad(string(round(Int, abs(x) * 10^digits)), digits + 1, '0')
  (x < 0 && any(!=('0'), s) ? "-" : "") * s[1:end-digits] * "." * s[end-digits+1:end]
end

"A number of mm as a dimension shows it: 45.00 mm"
length_words(x, unit="mm") = fixed(x) * " " * unit

"""
How the dimension `k` of `sketch` is drawn, as places of the sketch:
`(lines=..., arrows=..., words=..., at=...)`. `lines` are the thin lines out
from what's measured, `arrows` the lines with an arrow at each end, `words`
what it says and `at` the middle of the words. It's nothing for a constraint
that's no dimension.

SolidCraft keeps where the words of a dimension are only after they were
dragged. Until then `at` is on what's measured, and `placed` is false: the
words then go `gap` mm to the side of it that's away from `middle`, the middle
of the sketch, so that they're clear of the lines.
"""
dimension(sketch::AbstractDict, k::AbstractDict, at; placed=true, gap=0.0, middle=(0.0, 0.0)) = begin
  haskey(k, "value") && k["value"] !== nothing || return nothing
  value = Float64(k["value"])
  kind = get(k, "type", "")
  points, curves = get(sketch, "points", Any[]), get(sketch, "curves", Any[])
  point(i) = spot(points[Int(i)+1]["at"])
  curve(i) = curves[Int(i)+1]
  text = kind == "angle" ? string(round(value, digits=1), "°") : kind == "diameter" ? "Ø" * length_words(value) : kind == "radius" ? "R" * length_words(value) : length_words(value)
  plain = (lines=NTuple{2,Spot}[], arrows=NTuple{2,Spot}[], words=text, at=at)
  try
    if kind in ("length", "distance", "point_line_distance", "horizontal_distance", "vertical_distance", "distance_x", "distance_y")
      a, b = if kind == "length"
        c = curve(k["l"])
        spot(c["start_at"]), spot(c["end_at"])
      elseif kind == "point_line_distance"
        p, c = point(k["p"]), curve(k["l"])
        s, e = spot(c["start_at"]), spot(c["end_at"])
        dx, dy = e[1] - s[1], e[2] - s[2]
        t = ((p[1] - s[1]) * dx + (p[2] - s[2]) * dy) / max(dx^2 + dy^2, 1e-12)
        p, (s[1] + t * dx, s[2] + t * dy)
      else
        point(k["p"]), point(k["q"])
      end
      # The line with the arrows goes through the words, along what's measured
      way = kind in ("horizontal_distance", "distance_x") ? (1.0, 0.0) : kind in ("vertical_distance", "distance_y") ? (0.0, 1.0) :
            (l = hypot(b[1] - a[1], b[2] - a[2]); l < 1e-9 ? (1.0, 0.0) : ((b[1] - a[1]) / l, (b[2] - a[2]) / l))
      if !placed
        mid = ((a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
        side = (-way[2], way[1])
        (mid[1] - middle[1]) * side[1] + (mid[2] - middle[2]) * side[2] < 0 && (side = (-side[1], -side[2]))
        at = (mid[1] + side[1] * gap, mid[2] + side[2] * gap)
      end
      foot(p) = (t = (p[1] - at[1]) * way[1] + (p[2] - at[2]) * way[2]; (at[1] + t * way[1], at[2] + t * way[2]))
      fa, fb = foot(a), foot(b)
      return (lines=[(a, fa), (b, fb)], arrows=[(fa, fb)], words=text, at=at)
    elseif kind in ("diameter", "radius")
      c = curve(k["c"])
      o, r = spot(c["center_at"]), Float64(c["radius"])
      placed || (at = (o[1] + (r + gap) * 0.7071, o[2] + (r + gap) * 0.7071))
      l = hypot(at[1] - o[1], at[2] - o[2])
      way = l < 1e-9 ? (1.0, 0.0) : ((at[1] - o[1]) / l, (at[2] - o[2]) / l)
      rim = (o[1] + way[1] * r, o[2] + way[2] * r)
      from = kind == "diameter" ? (o[1] - way[1] * r, o[2] - way[2] * r) : o
      return (lines=l > r ? [(rim, at)] : NTuple{2,Spot}[], arrows=[(from, rim)], words=text, at=at)
    end
  catch
  end
  plain
end
