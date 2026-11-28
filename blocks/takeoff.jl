# A takeoff is the list of what a job needs, measured from its plans: how many
# of each fitting, how long each run of pipe or cable is, how big each floor or
# wall is. In a document it's a code block in the language `takeoff`:
#
#     ```takeoff
#     plan: ground-floor.pdf
#     page: 1
#     scale: 1:100
#     customer: J Smith
#
#     count | Double power point | item 412
#       120,340 410,380 505,120
#     length | 20mm conduit | +10%
#       100,100 300,100 300,400
#       2: 80,80 200,80
#     area in ft² | Floor tiles
#       50,50 400,50 400,300 50,300
#     area | Wall paint
#       500,100 800,100 800,300 500,300
#       cut 600,150 680,150 680,250 600,250
#     ```
#
# The lines at the top say which file holds the plan, which of its pages
# shows, and the plan's scale. `scale 2: 1:50` gives page 2 a scale of its own.
#
# Each measure has a line with its kind, its name, which is the words that
# describe what it measures, and how much to add for waste. A measure that was
# added from Centient's catalogue has what names its item there, like
# `item 412`, after its name. A measure with none is matched to an item later,
# in Centient. `in ft²` after the kind gives the unit that its amount is in. With none, it's in pieces, metres or square
# metres. Under it, each line that starts
# with spaces is one thing drawn on the plan: the marks of a count, the corners
# of a line for a length, or the corners of an outline for an area. `2:` at its
# start puts it on page 2.
#
# A line that starts with `cut` is a cut-out: an outline that's subtracted from
# the outline of an area that's above it, like a window from a wall. Only the
# part of it that's in that outline is subtracted.
#
# A point is measured from the top left of the page, in points: there are 72
# to an inch of paper. A picture has no paper size, so one of its pixels is one
# point, and its scale comes from a length that you know.
#
# This file reads and writes those lines, and works out what each measure
# comes to. It draws nothing.

"The language of a code block that is a takeoff"
const TAKEOFF = "takeoff"

const Point = NTuple{2,Float64}

"One thing drawn on a page of the plan: marks to count, a line of several corners, or an outline"
struct Shape
  page::Int
  points::Vector{Point}
  cut::Bool   # it's a cut-out: an outline that's subtracted from the outline before it
end

Shape(page::Integer, points) = Shape(page, points, false)

"The kinds of measure, as they're written"
const KINDS = (:count, :length, :area)

"""
The units that a measure of each kind can be in, as Centient names them. The
lists are the ones that Centient's own unit picker offers, smallest first, with
metric and imperial in one list.
"""
const KIND_UNITS = (count=["Piece"],
                    length=["mm", "cm", "inch", "ft", "yard", "m", "km", "mile"],
                    area=["mm²", "inch²", "ft²", "yard²", "m²", "acre", "hectare", "km²", "mile²"])

"How many of its kind's own unit, a piece, a metre or a square metre, one of each unit is"
const UNIT_SIZES = Dict{String,Float64}(
  "Piece" => 1.0,
  "mm" => 0.001, "cm" => 0.01, "inch" => 0.0254, "ft" => 0.3048, "yard" => 0.9144, "m" => 1.0, "km" => 1000.0, "mile" => 1609.344,
  "mm²" => 1e-6, "inch²" => 0.0254^2, "ft²" => 0.3048^2, "yard²" => 0.9144^2, "m²" => 1.0, "acre" => 4046.8564224,
  "hectare" => 1e4, "km²" => 1e6, "mile²" => 1609.344^2)

"The name of each unit in words, as the list of units shows it. Centient's list uses the same names."
const UNIT_WORDS = Dict{String,String}(
  "Piece" => "Piece", "mm" => "millimetre", "cm" => "centimetre", "inch" => "inch", "ft" => "foot", "yard" => "yard",
  "m" => "metre", "km" => "kilometre", "mile" => "mile", "mm²" => "square millimetre", "inch²" => "square inch",
  "ft²" => "square foot", "yard²" => "square yard", "m²" => "square metre", "acre" => "acre", "hectare" => "hectare",
  "km²" => "square kilometre", "mile²" => "square mile")

"The short form of a unit that goes after an amount, as Centient prints it: pc, mm, m². An inch and a foot are marks: 12\" and 6'."
unit_short(unit::AbstractString) = unit == "Piece" ? "pc" : unit == "inch" ? "\"" : unit == "ft" ? "'" : String(unit)

"The kind of measure that a unit is for, or nothing when it isn't one that a measure can be in"
unit_kind(unit::AbstractString) = findfirst(us -> unit in us, KIND_UNITS)
unit_kind(unit) = nothing

"The unit that a measure of this kind is in when it's given none: a piece, a metre or a square metre"
own_unit(kind::Symbol) = kind == :count ? "Piece" : kind == :length ? "m" : "m²"

"One line of the takeoff: what's measured, the catalogue item it's for if it has one, and where it is on the plan"
mutable struct Measure
  kind::Symbol            # :count, :length or :area
  name::String            # the words that describe what it measures
  item::String            # what names its item in Centient's catalogue, like "item 412", or "" for a measure that's matched to an item later
  extra::Float64          # the share added for waste: 0.1 adds 10%
  shapes::Vector{Shape}
  unit::String            # the unit that its amount is in, like "mm", or "" for its kind's own
end

Measure(kind::Symbol, name::AbstractString="") = Measure(kind, String(name), "", 0.0, Shape[], "")

"The unit that `m`'s amount is in, as Centient names it"
unit(m::Measure) = isempty(m.unit) ? own_unit(m.kind) : m.unit

"Give `m` the unit `u`. Its kind's own unit is written as none. A unit of another kind is left out."
unit!(m::Measure, u::AbstractString) = (m.unit = u == own_unit(m.kind) || unit_kind(u) != m.kind ? "" : String(u); m)

mutable struct Takeoff
  plan::String                       # the file of the plan, as the block names it
  page::Int                          # the page that shows
  scales::Dict{Int,Float64}          # how many times bigger the job is than each page. 0 is for the pages with no scale of their own.
  customer::String
  made::String                       # the quote that was made from it, as the catalogue's app names it
  other::Vector{Pair{String,String}} # the lines at the top that this file doesn't know, kept as they are
  measures::Vector{Measure}
end

Takeoff() = Takeoff("", 1, Dict{Int,Float64}(), "", "", Pair{String,String}[], Measure[])

# --- reading ---------------------------------------------------------------------

"The scale that `text` gives, like 100 for \"1:100\", or nothing when it gives none"
scale(text::AbstractString) = begin
  m = match(r"^\s*(?:1\s*[:/]\s*)?(\d+(?:\.\d+)?)\s*$", text)
  m === nothing && return nothing
  n = parse(Float64, m[1])
  n > 0 ? n : nothing
end

"A scale as it's written: 1:100"
scale_text(n::Real) = "1:" * number(n)

"A number with one decimal place, or none when it's a whole number"
number(x::Real) = (r = round(Float64(x), digits=1); r == round(r) ? string(round(Int, r)) : string(r))

"The points that `text` lists, like \"10,20 30.5,40\". A part that isn't a point is left out."
points(text::AbstractString) = begin
  out = Point[]
  for m in eachmatch(r"(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)", text)
    push!(out, (parse(Float64, m[1]), parse(Float64, m[2])))
  end
  out
end

"The share that `text` adds, like 0.1 for \"+10%\", or nothing when it isn't written that way"
extra(text::AbstractString) = begin
  m = match(r"^\s*\+?\s*(\d+(?:\.\d+)?)\s*%\s*$", text)
  m === nothing ? nothing : parse(Float64, m[1]) / 100
end

"""
The kind of measure for an item that's sold by `unit`, as the catalogue writes
it: a length for metres, an area for square metres, and a count for anything
else, like a piece, a box or an hour.
"""
kind_for(unit::AbstractString) = begin
  # Centient's own names for units, like ft and acre
  k = unit_kind(String(strip(unit)))
  k === nothing || return k
  u = replace(lowercase(strip(unit)), r"^(per|/)\s*" => "", r"[\s.]+" => " ")
  u = strip(replace(u, r"\b(lineal|linear|lin)\b" => "", "meter" => "metre", r"metres$" => "metre"))
  u in ("m²", "m2", "m^2", "sqm", "sq m", "sq metre", "square metre", "square m") ? :area :
  u in ("m", "lm", "l/m", "metre", "mm", "cm") ? :length : :count
end
kind_for(unit) = :count

"The measure that a line starts, or nothing when the line doesn't start one"
measure(line::AbstractString) = begin
  cells = String.(strip.(split(line, '|')))
  # The kind, and the unit that its amount is in: "length in mm"
  first = match(r"^(\w+)(?:\s+in\s+(\S+))?$", cells[1])
  first === nothing && return nothing
  kind = Symbol(lowercase(first[1]))
  kind in KINDS || return nothing
  m = Measure(kind, length(cells) >= 2 ? cells[2] : "")
  first[2] === nothing || unit!(m, first[2])
  # After the name are its item in the catalogue, if it has one, and what it adds for waste
  for cell in cells[3:end]
    isempty(cell) && continue
    e = extra(cell)
    e === nothing ? (m.item = cell) : (m.extra = e)
  end
  m
end

"The takeoff that the lines of a block describe. The lines are those between the two ``` lines."
takeoff(lines) = begin
  t = Takeoff()
  for line in lines
    isempty(strip(line)) && continue
    if startswith(line, r"\s") && !isempty(t.measures)
      # Something drawn for the measure above
      m = match(r"^\s+(?:(\d+)\s*:)?\s*(cut\b)?(.*)$"i, line)
      found = points(m[3])
      isempty(found) && continue
      shapes = last(t.measures).shapes
      if m[2] === nothing
        push!(shapes, Shape(m[1] === nothing ? 1 : parse(Int, m[1]), found))
      elseif last(t.measures).kind == :area && !isempty(shapes)
        # A cut-out is on the page of its outline. One with no outline to be cut from is left out.
        push!(shapes, Shape(last(shapes).page, found, true))
      end
      continue
    end
    made = measure(line)
    made === nothing || (push!(t.measures, made); continue)
    m = match(r"^([^:|]+):\s*(.*)$", line)
    m === nothing && continue
    key, value = lowercase(strip(m[1])), String(strip(m[2]))
    paged = match(r"^scale\s+(\d+)$", key)
    if key == "plan"
      t.plan = value
    elseif key == "page"
      t.page = max(1, something(tryparse(Int, value), 1))
    elseif key == "scale" || paged !== nothing
      n = scale(value)
      n === nothing || (t.scales[paged === nothing ? 0 : parse(Int, paged[1])] = n)
    elseif key == "customer"
      t.customer = value
    elseif key == "quote"
      t.made = value
    else
      push!(t.other, String(strip(m[1])) => value)
    end
  end
  t
end

# --- writing ---------------------------------------------------------------------

const MOST_MARKS = 10   # the marks of a count on one line. More go on the next line.

"The lines under a measure: one for each thing drawn. The marks of a count on one page share lines."
drawn(m::Measure) = begin
  row(page, ps, cut=false) = "  " * (page == 1 ? "" : "$page: ") * (cut ? "cut " : "") * join((number(x) * "," * number(y) for (x, y) in ps), " ")
  m.kind == :count || return [row(s.page, s.points, s.cut) for s in m.shapes if !isempty(s.points)]
  out = String[]
  for page in sort!(unique(s.page for s in m.shapes))
    marks = reduce(vcat, (s.points for s in m.shapes if s.page == page), init=Point[])
    append!(out, (row(page, part) for part in Iterators.partition(marks, MOST_MARKS)))
  end
  out
end

"The lines of the block that describes `t`, without its two ``` lines"
written(t::Takeoff) = begin
  out = String[]
  isempty(t.plan) || push!(out, "plan: " * t.plan)
  isempty(t.plan) || push!(out, "page: $(t.page)")
  for page in sort!(collect(keys(t.scales)))
    push!(out, (page == 0 ? "scale: " : "scale $page: ") * scale_text(t.scales[page]))
  end
  isempty(t.customer) || push!(out, "customer: " * t.customer)
  isempty(t.made) || push!(out, "quote: " * t.made)
  append!(out, (k * ": " * v for (k, v) in t.other))
  isempty(out) || isempty(t.measures) || push!(out, "")
  for m in t.measures
    cells = [string(m.kind) * (isempty(m.unit) ? "" : " in " * m.unit), m.name]
    isempty(m.item) || push!(cells, m.item)
    m.extra > 0 && push!(cells, "+" * number(100m.extra) * "%")
    push!(out, join(cells, " | "))
    append!(out, drawn(m))
  end
  out
end

# --- what each measure comes to ------------------------------------------------------

"The scale of page `page`, or nothing when it has none yet"
scale(t::Takeoff, page::Int) = get(t.scales, page, get(t.scales, 0, nothing))

"How many metres of the job one point of a page stands for, at a scale of 1 to `n`"
metres(n::Real) = n * 0.0254 / 72

"The scale of a page where the points `a` and `b` are `real` metres apart on the job"
scale(a::Point, b::Point, real::Real) = (d = hypot(b[1] - a[1], b[2] - a[2]); d > 0 && real > 0 ? real / metres(1) / d : nothing)

"How long the line through `ps` is, in points"
along(ps::Vector{Point}) = sum(hypot(ps[i+1][1] - ps[i][1], ps[i+1][2] - ps[i][2]) for i in 1:length(ps)-1; init=0.0)

"How big the outline with the corners `ps` is, in square points"
inside(ps::Vector{Point}) = begin
  n = length(ps)
  n < 3 && return 0.0
  abs(sum(ps[i][1] * ps[mod1(i + 1, n)][2] - ps[mod1(i + 1, n)][1] * ps[i][2] for i in 1:n)) / 2
end

"Where the line from `a` to `b` crosses the line from `c` to `d`, or nothing when they don't cross at one point"
crossing(a::Point, b::Point, c::Point, d::Point) = begin
  rx, ry, sx, sy = b[1] - a[1], b[2] - a[2], d[1] - c[1], d[2] - c[2]
  den = rx * sy - ry * sx
  den == 0 && return nothing
  k = ((c[1] - a[1]) * sy - (c[2] - a[2]) * sx) / den
  u = ((c[1] - a[1]) * ry - (c[2] - a[2]) * rx) / den
  (0 <= k <= 1 && 0 <= u <= 1) ? (a[1] + k * rx, a[2] + k * ry) : nothing
end

"""
How big what's left of the outline with the corners `ps` is, in square points,
when the outlines `cuts` are subtracted from it. A cut-out takes away only the
part of it that's in the outline, and where two cut-outs overlap, that part is
taken away once.

The page is cut into strips at the height of each corner and of each place
where two edges cross. In a strip no edges cross, so what's left there is a row
of trapezoids: the ones between two edges that are in the outline and in no
cut-out.
"""
left(ps::Vector{Point}, cuts) = begin
  isempty(cuts) && return inside(ps)
  # Each edge that isn't level, with the outline that it's of: 0 is the outline itself
  edges = Tuple{Point,Point,Int}[]
  for (which, corners) in enumerate((ps, cuts...))
    n = length(corners)
    n < 3 && continue
    for i in 1:n
      a, b = corners[i], corners[mod1(i + 1, n)]
      a[2] == b[2] || push!(edges, (a, b, which - 1))
    end
  end
  ys = Float64[]
  for (a, b, _) in edges
    push!(ys, a[2], b[2])
  end
  for i in eachindex(edges), j in i+1:length(edges)
    c = crossing(edges[i][1], edges[i][2], edges[j][1], edges[j][2])
    c === nothing || push!(ys, c[2])
  end
  sort!(unique!(ys))
  total = 0.0
  in_cut = falses(length(cuts))
  row = Tuple{Float64,Float64,Float64,Int}[]   # an edge in the strip: where it is in the strip's middle, at its top and at its bottom
  for k in 1:length(ys)-1
    top, bottom = ys[k], ys[k+1]
    middle = (top + bottom) / 2
    empty!(row)
    for (a, b, which) in edges
      min(a[2], b[2]) < middle < max(a[2], b[2]) || continue
      x(y) = a[1] + (y - a[2]) * (b[1] - a[1]) / (b[2] - a[2])
      push!(row, (x(middle), x(top), x(bottom), which))
    end
    sort!(row)
    inside_it = false
    fill!(in_cut, false)
    for i in 1:length(row)-1
      which = row[i][4]
      which == 0 ? (inside_it = !inside_it) : (in_cut[which] = !in_cut[which])
      inside_it && !any(in_cut) && (total += ((row[i+1][2] - row[i][2]) + (row[i+1][3] - row[i][3])) / 2 * (bottom - top))
    end
  end
  max(total, 0.0)
end

"The place in `m` of the outline that shape `j` is cut from. A shape that isn't a cut-out gives its own place."
outline(m::Measure, j::Int) = something(findprev(s -> !s.cut, m.shapes, j), j)

"The places in `m` of the cut-outs of the outline at place `j`: the shapes after it, as far as the next outline"
cuts(m::Measure, j::Int) = begin
  last = j
  while last < length(m.shapes) && m.shapes[last+1].cut
    last += 1
  end
  j+1:last
end

"What one shape of a measure of this kind comes to, before anything is added for waste: a count, metres or square metres. It's nothing when its page has no scale."
amount(t::Takeoff, kind::Symbol, s::Shape) = begin
  kind == :count && return Float64(length(s.points))
  n = scale(t, s.page)
  n === nothing && return nothing
  kind == :length ? along(s.points) * metres(n) : inside(s.points) * metres(n)^2
end

"""
What shape `j` of `m` comes to, before anything is added for waste. An outline
comes to what's left of it without its cut-outs. A cut-out comes to what it
takes from its outline by itself. It's nothing when its page has no scale.
"""
amount(t::Takeoff, m::Measure, j::Int) = begin
  s = m.shapes[j]
  m.kind == :area || return amount(t, m.kind, s)
  n = scale(t, s.page)
  n === nothing && return nothing
  if s.cut
    from = m.shapes[outline(m, j)].points
    return max(inside(from) - left(from, [s.points]), 0.0) * metres(n)^2
  end
  left(s.points, [m.shapes[k].points for k in cuts(m, j)]) * metres(n)^2
end

"""
What `m` comes to, with what it adds for waste: a count, metres or square
metres. It's nothing when a page that it's drawn on has no scale.
"""
amount(t::Takeoff, m::Measure) = begin
  total = 0.0
  for (j, s) in enumerate(m.shapes)
    s.cut && continue   # its outline's amount is already without it
    a = amount(t, m, j)
    a === nothing && return nothing
    total += a
  end
  total * (1 + m.extra)
end

"An amount of its kind's own unit, a piece, a metre or a square metre, in the unit `u`"
in_unit(amount::Real, u::AbstractString) = amount / get(UNIT_SIZES, u, 1.0)

"""
A number of a unit as it's shown: to two decimal places, or to three figures
when it's less than one, so that 0.0125 km doesn't show as 0.01.
"""
amount_number(x::Real) = begin
  r = abs(x) < 1 && x != 0 ? round(x, sigdigits=3) : round(x, digits=2)
  r == round(r) && abs(r) < 1e15 ? string(round(Int, r)) : string(r)
end

"""
An amount of its kind's own unit as the list shows it in the unit `u`: 12,
12.4 m, 38.25 m² or 41' for feet. A count of pieces has no unit after it.
"""
shown(kind::Symbol, amount::Real, u::AbstractString=own_unit(kind)) = begin
  kind == :count && u == "Piece" && return string(round(Int, amount))
  n = amount_number(in_unit(amount, u))
  u in ("inch", "ft") ? n * unit_short(u) : n * " " * unit_short(u)
end
shown(m::Measure, amount::Real) = shown(m.kind, amount, unit(m))

# --- finding what's under the mouse ---------------------------------------------------

"How far `p` is from the line between `a` and `b`"
apart(p::Point, a::Point, b::Point) = begin
  dx, dy = b[1] - a[1], b[2] - a[2]
  len = dx^2 + dy^2
  k = len == 0 ? 0.0 : clamp(((p[1] - a[1]) * dx + (p[2] - a[2]) * dy) / len, 0.0, 1.0)
  hypot(p[1] - a[1] - k * dx, p[2] - a[2] - k * dy)
end

"""
The corner or the mark on page `page` that's nearest to `p`, if one is within
`reach`: the place of its measure, of its shape and of the point. It's nothing
when none is that near.
"""
corner(t::Takeoff, page::Int, p::Point, reach::Real) = begin
  best, found = Float64(reach), nothing
  for (i, m) in enumerate(t.measures), (j, s) in enumerate(m.shapes)
    s.page == page || continue
    for (k, q) in enumerate(s.points)
      d = hypot(q[1] - p[1], q[2] - p[2])
      d <= best && ((best, found) = (d, (i, j, k)))
    end
  end
  found
end

"True when `p` is in the outline with the corners `ps`"
within(p::Point, ps::Vector{Point}) = begin
  n, hit = length(ps), false
  for i in 1:n
    a, b = ps[i], ps[mod1(i + 1, n)]
    (a[2] > p[2]) != (b[2] > p[2]) && p[1] < a[1] + (p[2] - a[2]) * (b[1] - a[1]) / (b[2] - a[2]) && (hit = !hit)
  end
  hit
end

"""
The shape on page `page` that's under `p`: the place of its measure and of the
shape. A mark and a line are under `p` when they're within `reach` of it, and
so is the edge of an outline. The inside of an outline counts when nothing
else is under `p`, and the inside of a cut-out comes before the inside of the
outline that it's cut from. It's nothing when no shape is there.
"""
shape(t::Takeoff, page::Int, p::Point, reach::Real) = begin
  best, found, filled, hole = Float64(reach), nothing, nothing, nothing
  for (i, m) in enumerate(t.measures), (j, s) in enumerate(m.shapes)
    s.page == page || continue
    ps = s.points
    d = m.kind == :count || length(ps) == 1 ? minimum(q -> hypot(q[1] - p[1], q[2] - p[2]), ps, init=Inf) :
        minimum(apart(p, ps[k], ps[k+1]) for k in 1:length(ps)-1; init=Inf)
    m.kind == :area && length(ps) > 2 && (d = min(d, apart(p, ps[end], ps[1])))
    d <= best && ((best, found) = (d, (i, j)))
    m.kind == :area && (s.cut ? hole : filled) === nothing && within(p, ps) && (s.cut ? (hole = (i, j)) : (filled = (i, j)))
  end
  something(found, hole, Some(filled))
end

# --- changing it -------------------------------------------------------------------

"Add a mark to the count `m` on page `page`"
mark!(m::Measure, page::Int, p::Point) = begin
  i = findlast(s -> s.page == page, m.shapes)
  i === nothing ? push!(m.shapes, Shape(page, [p])) : push!(m.shapes[i].points, p)
  m
end

"Take shape `j` away from `m`. The cut-outs of an outline go with it."
remove!(m::Measure, j::Int) = (deleteat!(m.shapes, m.shapes[j].cut ? (j:j) : (j:last(cuts(m, j)))); m)

"Take point `k` of shape `j` away from `m`. A shape that's left with too few points to be one goes too."
remove!(m::Measure, j::Int, k::Int) = begin
  ps = m.shapes[j].points
  deleteat!(ps, k)
  least = m.kind == :count ? 1 : m.kind == :length ? 2 : 3
  length(ps) < least && remove!(m, j)
  m
end

"""
How many square points a cut-out with the corners `ps` would take from the
outline at place `j` of `m`: its part of what the outline's other cut-outs
have left.
"""
takes(m::Measure, j::Int, ps::Vector{Point}) = begin
  others = [m.shapes[k].points for k in cuts(m, j)]
  max(left(m.shapes[j].points, others) - left(m.shapes[j].points, [others; [ps]]), 0.0)
end

"""
The outline on page `page` that a cut-out with the corners `ps` would be cut
from: the place of its measure and of the outline. It's the outline that the
cut-out takes the most from. An outline of the measure at place `first` comes
before the others, so the measure that's chosen in the list takes the cut-out
when two measures cover the same part of the plan. It's nothing when the
cut-out is over no outline.
"""
cut_from(t::Takeoff, page::Int, ps::Vector{Point}, first::Int=0) = begin
  length(ps) < 3 && return nothing
  best, found = 0.0, nothing
  for (i, m) in enumerate(t.measures), (j, s) in enumerate(m.shapes)
    (m.kind == :area && s.page == page && !s.cut) || continue
    took = takes(m, j, ps)
    took > 1e-9 || continue
    mine = i == first
    (found === nothing || (mine && found[1] != first) || (mine == (found[1] == first) && took > best)) || continue
    best, found = took, (i, j)
  end
  found
end

"""
Cut the outline with the corners `ps` out of an area on page `page`. `first` is
as it is for `cut_from`. It gives the place of the measure and of the new
cut-out, or nothing when the cut-out is over no outline, and then nothing changes.
"""
cut!(t::Takeoff, page::Int, ps::Vector{Point}, first::Int=0) = begin
  found = cut_from(t, page, ps, first)
  found === nothing && return nothing
  i, j = found
  m = t.measures[i]
  at = last(cuts(m, j)) + 1
  insert!(m.shapes, at, Shape(page, ps, true))
  (i, at)
end

# --- the lines of the plan ----------------------------------------------------------
#
# A PDF plan is made of lines, and the tools that draw snap to them: a corner
# that's put near the end of a line of the plan goes on it. `Lines` holds the
# lines of one page in a grid of squares, with the lines that pass through each
# square, so that the lines near the mouse are found without a look at them all.

"A line of the plan, from one point of the page to another"
const Line = NTuple{4,Float64}

"The lines of a page of a plan, with a grid that finds the ones near a point"
struct Lines
  lines::Vector{Line}
  ends::Vector{UInt8}    # the ends of each line that are corners of the plan: 1 is its start, 2 its end, 3 both. A piece in the middle of a curve has none.
  cell::Float64          # how wide and how tall a square of the grid is, in points
  wide::Int              # how many squares the grid has across, and down
  tall::Int
  first::Vector{Int}     # for each square, where its lines start in `found`. The last one is where they all end.
  found::Vector{Int32}   # the places in `lines` of each square's lines
end

"No lines at all, as a picture has"
Lines() = Lines(Line[], UInt8[], 1.0, 0, 0, [1], Int32[])

Base.isempty(l::Lines) = isempty(l.lines)

"The square of the grid that the point `(x, y)` is in, or 0 when it's off the page"
square(l::Lines, x, y) = begin
  (0 <= x < l.wide * l.cell && 0 <= y < l.tall * l.cell) || return 0
  floor(Int, y / l.cell) * l.wide + floor(Int, x / l.cell) + 1
end

"Call `f` with each square that a line passes through, or passes within a quarter of a square of"
squares(f, l::Lines, (x1, y1, x2, y2)::Line) = begin
  # A point for each half square along the line. Every part of the line is within a quarter of a square of one.
  n = max(1, ceil(Int, hypot(x2 - x1, y2 - y1) / (l.cell / 2)))
  was = 0
  for k in 0:n
    c = square(l, x1 + (x2 - x1) * k / n, y1 + (y2 - y1) * k / n)
    (c == 0 || c == was) && continue
    f(c)
    was = c
  end
end

"""
The lines of a page that's `w` points wide and `h` tall, ready to be searched.
`ends` says which ends of each line are corners. With none, both ends of every
line are.
"""
Lines(lines::Vector{Line}, w::Real, h::Real, ends::Vector{UInt8}=fill(0x03, length(lines))) = begin
  (isempty(lines) || w <= 0 || h <= 0) && return Lines()
  # About 250 squares along the page's long side, and none smaller than 6 points
  cell = max(6.0, max(w, h) / 250)
  wide, tall = ceil(Int, w / cell), ceil(Int, h / cell)
  l = Lines(lines, ends, cell, wide, tall, zeros(Int, wide * tall + 1), Int32[])
  # Count the lines of each square, then put each line in its squares
  foreach(line -> squares(c -> l.first[c+1] += 1, l, line), lines)
  l.first[1] = 1
  for c in 1:wide*tall
    l.first[c+1] += l.first[c]
  end
  resize!(l.found, l.first[end] - 1)
  next = l.first[1:end-1]
  for (i, line) in enumerate(lines)
    squares(l, line) do c
      l.found[next[c]] = i
      next[c] += 1
    end
  end
  l
end

"The places in `l.lines` of the lines that pass within `reach` of `p`. A line shows once."
near(l::Lines, p::Point, reach::Real) = begin
  out = Int32[]
  isempty(l) && return out
  # A line is in a square that's within a quarter of a square of each of its points
  far = reach + l.cell / 4
  cols = clamp(floor(Int, (p[1] - far) / l.cell), 0, l.wide - 1):clamp(floor(Int, (p[1] + far) / l.cell), 0, l.wide - 1)
  rows = clamp(floor(Int, (p[2] - far) / l.cell), 0, l.tall - 1):clamp(floor(Int, (p[2] + far) / l.cell), 0, l.tall - 1)
  for row in rows, col in cols
    c = row * l.wide + col + 1
    for k in l.first[c]:l.first[c+1]-1
      i = l.found[k]
      x1, y1, x2, y2 = l.lines[i]
      apart(p, (x1, y1), (x2, y2)) <= reach && push!(out, i)
    end
  end
  length(cols) * length(rows) > 1 ? unique!(out) : out
end

const MOST_CROSSED = 24   # the lines near the mouse that are looked at for where they cross

"""
Where a corner that's put at `p` snaps to on the lines `l`, and what's there:
`:corner` for the end of a line, `:crossing` for where two lines cross, and
`:line` for the nearest point of a line. A corner or a crossing within `reach`
comes before a line, even a nearer one, because a corner of the plan is what's
most often measured from. It's nothing when no line is within `reach`.
"""
snap(l::Lines, p::Point, reach::Real) = begin
  found = near(l, p, reach)
  isempty(found) && return nothing
  far(q) = hypot(q[1] - p[1], q[2] - p[2])
  best, at, what = Float64(reach), p, :none
  take(q, kind) = (d = far(q); d <= best && ((best, at, what) = (d, q, kind)))
  for i in found
    x1, y1, x2, y2 = l.lines[i]
    l.ends[i] & 0x01 == 0 || take((x1, y1), :corner)
    l.ends[i] & 0x02 == 0 || take((x2, y2), :corner)
  end
  # Where the nearest of the lines cross each other
  length(found) > MOST_CROSSED && partialsort!(found, 1:MOST_CROSSED, by=i -> (s = l.lines[i]; apart(p, (s[1], s[2]), (s[3], s[4]))))
  some = @view found[1:min(end, MOST_CROSSED)]
  for a in eachindex(some), b in a+1:length(some)
    s, r = l.lines[some[a]], l.lines[some[b]]
    c = crossing((s[1], s[2]), (s[3], s[4]), (r[1], r[2]), (r[3], r[4]))
    c === nothing && continue
    # Two lines that meet end to end don't cross. If the place is a corner of the plan, it was taken as one.
    ends_at(q) = (abs(q[1] - c[1]) < 1e-6 && abs(q[2] - c[2]) < 1e-6) || (abs(q[3] - c[1]) < 1e-6 && abs(q[4] - c[2]) < 1e-6)
    (ends_at(s) && ends_at(r)) || take(c, :crossing)
  end
  what == :none || return (at, what)
  for i in found
    x1, y1, x2, y2 = l.lines[i]
    dx, dy = x2 - x1, y2 - y1
    len = dx^2 + dy^2
    k = len == 0 ? 0.0 : clamp(((p[1] - x1) * dx + (p[2] - y1) * dy) / len, 0.0, 1.0)
    take((x1 + k * dx, y1 + k * dy), :line)
  end
  what == :none ? nothing : (at, what)
end

"""
Where a corner that's put at `p` on page `page` snaps to: on the lines `l` of
the plan, or on a corner of something that's already measured there, whichever
corner is nearer. `skip` is a corner of the takeoff that it doesn't snap to:
the one that's being moved. It gives the point and what's there, as `snap`
does for the plan's lines, or nothing.
"""
snap(t::Takeoff, l::Lines, page::Int, p::Point, reach::Real; skip=nothing) = begin
  found = snap(l, p, reach)
  best = found === nothing || found[2] == :line ? Float64(reach) : hypot(found[1][1] - p[1], found[1][2] - p[2])
  for (i, m) in enumerate(t.measures), (j, s) in enumerate(m.shapes)
    (s.page == page && m.kind != :count) || continue
    for (k, q) in enumerate(s.points)
      (i, j, k) == skip && continue
      d = hypot(q[1] - p[1], q[2] - p[2])
      d <= best && ((best, found) = (d, (q, :corner)))
    end
  end
  found
end

export TAKEOFF, Takeoff, Measure, Shape, Point, takeoff, written, amount, shown, scale, scale_text, metres,
       corner, shape, mark!, remove!, number, Lines, snap, cut!, cut_from, cuts, outline
