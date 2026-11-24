# Solids that Ladder makes itself, to show what a command of a SolidCraft
# design would make while its form is open.
#
# SolidCraft's program makes every step of a design. To show what a command
# would make before OK, the editor can run the command, ask for every body,
# and undo the command (see `Designs.try!`). That takes as long as SolidCraft
# takes to build the design again: 0.15 s for a small bracket, 3.7 s for a
# satellite of 81 bodies. The calls themselves cost almost nothing (0.15 ms
# each). The time is SolidCraft's work on the solids.
#
# Most commands add a simple solid, take one away, or move a body. So this file
# makes that solid at once, and the editor shows it over the design: tinted
# with the accent colour where it adds, red where it takes away. It's the piece
# alone, not joined to the bodies or cut out of them. When OK is clicked,
# SolidCraft still makes the real step.
#
#     a = Arrangement(sketch)             # the closed regions of a sketch, exactly
#     r = region(a, (5.0, 2.0))           # the region at a place: the loop round it, and its holes
#     p = profile(a, [r])                 # its triangles, and the sides round it
#     extrude("piece", frame, p, 0.0, 10.0)                  # a Shape, as scene.jl has them
#     revolve("piece", frame, p, (0.0, 0.0, 0.0), (0.0, 1.0, 0.0), 0.0, π)
#     box("piece", (0.0, 0.0, 10.0), (20.0, 20.0, 20.0))
#     moved(body, "piece", p -> p .+ (10.0, 0.0, 0.0))
#     inside(body, (1.0, 2.0, 3.0))       # is the point in the body?
#
# sketch.jl's `Regions` finds the region under the mouse on a grid, which is
# quick, but has steps at its edges. The regions here follow the curves.

@use "./scene" Vec3 Shape Edge dot cross unit len
@use "./sketch" => Sketching
@use "./sketch" Spot Frame
@use GeometryBasics: Point2, earcut_triangulate

"What the name of each piece starts with: no body of a design is named so"
const PIECE = "(preview) "

dot2(a, b) = a[1] * b[1] + a[2] * b[2]
cross2(a, b) = a[1] * b[2] - a[2] * b[1]

# --- building a solid ----------------------------------------------------------------

"A solid as it's made: its corners, its triangles, and the face that each triangle is of"
struct Builder
  points::Vector{Vec3}
  index::Dict{Vec3,Int}
  triangles::Vector{NTuple{3,Int}}
  face::Vector{Any}
end
Builder() = Builder(Vec3[], Dict{Vec3,Int}(), NTuple{3,Int}[], Any[])

point!(b::Builder, p::Vec3) = get!(() -> (push!(b.points, p); length(b.points)), b.index, p)

"""
Add the triangle `p q r` to the face `face`, turned so that it faces the way
`out`. A triangle with no area is left out.
"""
triangle!(b::Builder, p::Vec3, q::Vec3, r::Vec3, face, out) = begin
  i, j, k = point!(b, p), point!(b, q), point!(b, r)
  (i == j || j == k || i == k) && return b
  way = cross(q .- p, r .- p)
  len(way) <= 1e-12 * (len(q .- p) + len(r .- p))^2 && return b
  dot(way, out) < 0 && ((j, k) = (k, j))
  push!(b.triangles, (i, j, k))
  push!(b.face, face)
  b
end

"""
The body that `b` has made, named `name`. The surface faces the same way at a
corner that triangles of one face share, so a curved face shades smoothly, and
two faces meet at a sharp edge.
"""
shape(b::Builder, name) = begin
  number = Dict{Any,Int}()
  face = Int[get!(number, f, length(number) + 1) for f in b.face]
  sums = Dict{NTuple{2,Int},Vec3}()
  for (i, t) in enumerate(b.triangles)
    p, q, r = b.points[t[1]], b.points[t[2]], b.points[t[3]]
    way = cross(q .- p, r .- p)
    for k in t
      sums[(face[i], k)] = get(sums, (face[i], k), (0.0, 0.0, 0.0)) .+ way
    end
  end
  normals = Vec3[]
  for (i, t) in enumerate(b.triangles), k in t
    push!(normals, unit(sums[(face[i], k)]))
  end
  Shape(String(name), b.points, b.triangles, normals, face)
end

"How much room the closed surface of `s` holds, in mm³. It's more than 0 when its triangles face out."
volume(s::Shape) = sum((dot(s.points[t[1]], cross(s.points[t[2]], s.points[t[3]])) for t in s.triangles); init=0.0) / 6

"Do the boxes round `a` and `b` overlap?"
overlaps(a::Shape, b::Shape) = all(a.low .<= b.high) && all(b.low .<= a.high)

"""
Is the point `p` inside the body `s`? A line from it goes through the body's
surface an odd number of times.
"""
inside(s::Shape, p::Vec3) = begin
  all(s.low .- 1e-9 .<= p .<= s.high .+ 1e-9) || return false
  d = unit((0.5772, 0.5774, 0.5779))   # a way that no face of a design runs along
  crossed = 0
  for t in s.triangles
    a, b, c = s.points[t[1]], s.points[t[2]], s.points[t[3]]
    e1, e2 = b .- a, c .- a
    h = cross(d, e2)
    det = dot(e1, h)
    abs(det) < 1e-14 && continue
    q = p .- a
    u = dot(q, h) / det
    0 <= u <= 1 || continue
    r = cross(q, e1)
    v = dot(d, r) / det
    (v >= 0 && u + v <= 1) || continue
    dot(e2, r) / det > 1e-9 && (crossed += 1)
  end
  isodd(crossed)
end

"A plane through `o` that faces the way `w`"
plane(o::Vec3, w::Vec3) = begin
  w = unit(w)
  k = argmin(abs.(w))
  x = unit(ntuple(j -> j == k ? 1.0 : 0.0, 3) .- w .* w[k])
  Frame(o, x, cross(w, x))
end

"""
The point `p` turned by `angle` radians round the axis through `o` along the
unit way `w`, the way the fingers of the right hand curl round its thumb.
"""
turned(p::Vec3, o::Vec3, w::Vec3, angle) = begin
  v = p .- o
  along = w .* dot(w, v)
  off = v .- along
  len(off) <= 1e-9 * (1 + len(v)) && return p
  o .+ along .+ off .* cos(angle) .+ cross(w, off) .* sin(angle)
end

"The way `x` turned by `angle` round the unit way `w`"
turned(x::Vec3, w::Vec3, angle) = turned(x, (0.0, 0.0, 0.0), w, angle)

# --- the regions of a sketch -----------------------------------------------------------

"""
A loop of an `Arrangement`: the numbers of its places in order, the curve that
the side after each one is part of, the area it goes round (more than 0 when
it goes counter-clockwise), and the group of curves that it's of.
"""
struct Loop
  corners::Vector{Int}
  curves::Vector{Int}
  area::Float64
  group::Int
end

"""
The regions that the curves of a sketch close off. Each curve is cut where
another crosses or touches it. Then the pieces are walked round with the
region on the left, which gives a loop that goes counter-clockwise round each
region, and a loop that goes clockwise round the outside of each group of
curves that touch: a hole in the region that the group is in. Construction
lines don't close anything off, and nor does a curve with a loose end.
"""
struct Arrangement
  places::Vector{Spot}
  loops::Vector{Loop}
end

Arrangement(sketch::AbstractDict) = begin
  pieces = Tuple{Spot,Spot,Int}[]
  for (k, c) in enumerate(get(sketch, "curves", Any[]))
    (c isa AbstractDict && get(c, "construction", false) !== true) || continue
    line = Sketching.outline(c)
    for i in 1:length(line)-1
      line[i] == line[i+1] || push!(pieces, (line[i], line[i+1], k))
    end
  end
  isempty(pieces) && return Arrangement(Spot[], Loop[])
  far = maximum(p -> max(abs(p[1][1]), abs(p[1][2]), abs(p[2][1]), abs(p[2][2])), pieces)
  near = 1e-7 * max(far, 1.0)    # places nearer than this are one place
  # Where each piece meets another, as how far along it that is
  ts = [Float64[0.0, 1.0] for _ in pieces]
  order = sortperm(pieces, by=p -> min(p[1][1], p[2][1]))
  for (n, i) in enumerate(order)
    a, b, _ = pieces[i]
    right_end = max(a[1], b[1]) + near
    for j in @view order[n+1:end]
      c, d, _ = pieces[j]
      min(c[1], d[1]) > right_end && break
      (min(a[2], b[2]) > max(c[2], d[2]) + near || min(c[2], d[2]) > max(a[2], b[2]) + near) && continue
      meet!(ts, i, j, a, b, c, d, near)
    end
  end
  places = Spot[]
  cells = Dict{NTuple{2,Int},Vector{Int}}()
  place!(p) = begin
    i, j = floor(Int, p[1] / near), floor(Int, p[2] / near)
    for x in i-1:i+1, y in j-1:j+1
      haskey(cells, (x, y)) || continue
      for k in cells[(x, y)]
        hypot(places[k][1] - p[1], places[k][2] - p[2]) <= near && return k
      end
    end
    push!(places, p)
    push!(get!(() -> Int[], cells, (i, j)), length(places))
    length(places)
  end
  curve_of = Dict{NTuple{2,Int},Int}()
  for (n, (a, b, k)) in enumerate(pieces)
    last = place!(a)
    for t in sort!(unique!(ts[n]))[2:end]
      here = place!(t == 1.0 ? b : (a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t))
      here == last && continue
      get!(curve_of, minmax(last, here), k)
      last = here
    end
  end
  # A piece with a loose end closes nothing off
  sides = collect(keys(curve_of))
  degree = zeros(Int, length(places))
  for (u, v) in sides
    degree[u] += 1
    degree[v] += 1
  end
  pruned = true
  while pruned
    pruned = false
    filter!(sides) do (u, v)
      (degree[u] > 1 && degree[v] > 1) && return true
      degree[u] -= 1
      degree[v] -= 1
      pruned = true
      false
    end
  end
  # Each side both ways, and the sides that leave each place in the order of their angle
  from, to, curve = Int[], Int[], Int[]
  leaving = [Int[] for _ in places]
  for (u, v) in sides
    k = curve_of[(u, v)]
    push!(from, u, v)
    push!(to, v, u)
    push!(curve, k, k)
    push!(leaving[u], length(from) - 1)
    push!(leaving[v], length(from))
  end
  heading(h) = (d = places[to[h]] .- places[from[h]]; atan(d[2], d[1]))
  foreach(l -> sort!(l, by=heading), leaving)
  rank = zeros(Int, length(from))
  for l in leaving, (i, h) in enumerate(l)
    rank[h] = i
  end
  back(h) = isodd(h) ? h + 1 : h - 1
  # After a side, the sharpest turn to the left keeps the region on the left
  next(h) = (l = leaving[to[h]]; l[mod1(rank[back(h)] - 1, length(l))])
  group = collect(1:length(places))
  root(x) = begin
    while group[x] != x
      group[x] = group[group[x]]
      x = group[x]
    end
    x
  end
  for (u, v) in sides
    group[root(u)] = root(v)
  end
  seen = falses(length(from))
  loops = Loop[]
  for h in eachindex(from)
    seen[h] && continue
    corners, curves = Int[], Int[]
    g = h
    while !seen[g]
      seen[g] = true
      push!(corners, from[g])
      push!(curves, curve[g])
      g = next(g)
    end
    area = 0.0
    for (i, c) in enumerate(corners)
      area += cross2(places[c], places[corners[mod1(i + 1, length(corners))]])
    end
    push!(loops, Loop(corners, curves, area / 2, root(corners[1])))
  end
  Arrangement(places, loops)
end

"""
Where the piece `a b`, number `i`, and the piece `c d`, number `j`, cross or
touch. Each place goes in `ts` as how far along its piece it is.
"""
meet!(ts, i, j, a, b, c, d, near) = begin
  along(p, a, b, i) = begin
    v = b .- a
    l2 = dot2(v, v)
    l2 == 0 && return
    t = dot2(p .- a, v) / l2
    0 < t < 1 || return
    hypot(a[1] + v[1] * t - p[1], a[2] + v[2] * t - p[2]) <= near && push!(ts[i], t)
    nothing
  end
  along(c, a, b, i)
  along(d, a, b, i)
  along(a, c, d, j)
  along(b, c, d, j)
  r, s = b .- a, d .- c
  den = cross2(r, s)
  abs(den) <= 1e-12 * (dot2(r, r) + dot2(s, s)) && return
  t, u = cross2(c .- a, s) / den, cross2(c .- a, r) / den
  (0 < t < 1 && 0 < u < 1) && (push!(ts[i], t); push!(ts[j], u))
  nothing
end

"Is the place `p` inside the loop `l`?"
encloses(a::Arrangement, l::Loop, p) = begin
  in = false
  n = length(l.corners)
  for i in 1:n
    u, v = a.places[l.corners[i]], a.places[l.corners[mod1(i + 1, n)]]
    ((u[2] > p[2]) != (v[2] > p[2])) && p[1] < u[1] + (p[2] - u[2]) * (v[1] - u[1]) / (v[2] - u[2]) && (in = !in)
  end
  in
end

"The number of the smallest loop round a region that's round the place `p`, and isn't of the group `not`, or 0"
smallest(a::Arrangement, p, not=0) = begin
  best = 0
  for (i, l) in enumerate(a.loops)
    l.area > 0 && l.group != not && (best == 0 || l.area < a.loops[best].area) && encloses(a, l, p) && (best = i)
  end
  best
end

"A region of a sketch: the loop round it, and a loop round each hole in it"
struct Region
  outline::Loop
  holes::Vector{Loop}
end

"The region of the arrangement `a` at the place `p` of its sketch, or nothing when `p` is in none"
region(a::Arrangement, p) = begin
  i = smallest(a, p)
  i == 0 && return nothing
  out = a.loops[i]
  Region(out, Loop[l for l in a.loops if l.area < 0 && l.group != out.group && smallest(a, a.places[l.corners[1]], l.group) == i])
end

# --- what's swept ----------------------------------------------------------------------

"""
What's swept: triangles that fill it, as places of its plane, and the sides
round it. Each side has its two ends, the way out of the profile from it, and
what makes the face of the solid that the side sweeps: sides of one curve
sweep into one face.
"""
struct Profile
  triangles::Vector{NTuple{3,Spot}}
  rim::Vector{Tuple{Spot,Spot,Spot,Any}}
end

"The way out of a profile from its side `p q`, which has the profile on its left"
right(p, q) = (d = q .- p; l = hypot(d[1], d[2]); l == 0 ? (0.0, 0.0) : (d[2] / l, -d[1] / l))

"The number of a corner that earcut gives, from 1"
corner(c) = Int(c.i) + 1

"The profile of the regions `regions` of the arrangement `a`"
profile(a::Arrangement, regions) = begin
  triangles = NTuple{3,Spot}[]
  rim = Dict{NTuple{2,Spot},Int}()
  for r in unique(r -> r.outline.corners, regions)
    loops = vcat([r.outline], r.holes)
    rings = [Point2{Float64}[Point2{Float64}(a.places[c]...) for c in l.corners] for l in loops]
    all_places = reduce(vcat, rings)
    for t in earcut_triangulate(rings)
      push!(triangles, ntuple(k -> (Float64(all_places[corner(t[k])][1]), Float64(all_places[corner(t[k])][2])), 3))
    end
    for l in loops, (i, c) in enumerate(l.corners)
      p, q = a.places[c], a.places[l.corners[mod1(i + 1, length(l.corners))]]
      # A side between two regions that are both swept is inside the solid
      haskey(rim, (q, p)) ? delete!(rim, (q, p)) : (rim[(p, q)] = l.curves[i])
    end
  end
  Profile(triangles, [(p, q, right(p, q), k) for ((p, q), k) in rim])
end

"""
The profile inside `ring`, which goes counter-clockwise. The side after each
place sweeps into the face that `faces` names for it.
"""
polygon(ring::Vector{Spot}, faces=collect(1:length(ring))) = begin
  n = length(ring)
  flat = [Point2{Float64}(q...) for q in ring]
  triangles = NTuple{3,Spot}[ntuple(k -> ring[corner(t[k])], 3) for t in earcut_triangulate([flat])]
  Profile(triangles, [(ring[i], ring[mod1(i + 1, n)], right(ring[i], ring[mod1(i + 1, n)]), faces[i]) for i in 1:n])
end

"A circle of radius `r` round the place `c`, with `n` sides, all of one face"
disc(r, c=(0.0, 0.0); n=96) = begin
  ring = Spot[(c[1] + r * cos(2π * i / n), c[2] + r * sin(2π * i / n)) for i in 0:n-1]
  Profile([(c, ring[i], ring[mod1(i + 1, n)]) for i in 1:n], [(ring[i], ring[mod1(i + 1, n)], right(ring[i], ring[mod1(i + 1, n)]), 1) for i in 1:n])
end

"A plane that the flat face `n` of the body `s` is on, facing the way the face faces, out of the body. Nothing for a face that isn't there."
face_frame(s::Shape, n) = begin
  i = findfirst(==(n), s.face)
  i === nothing && return nothing
  f = plane(s.points[s.triangles[i][1]], s.normals[3i-2])
  f
end

"""
The profile of the flat faces `faces` of the body `s`, on their plane `f`.
Each side round it sweeps into the face of the edge of the body that it's on.
"""
profile(s::Shape, faces, f::Frame) = begin
  edge_of = edge_sides(s)
  triangles = NTuple{3,Spot}[]
  uses = Dict{NTuple{2,Int},Vector{NTuple{3,Int}}}()
  chosen = Set(faces)
  for (i, t) in enumerate(s.triangles)
    s.face[i] in chosen || continue
    push!(triangles, ntuple(k -> Sketching.flat(f, s.points[t[k]]), 3))
    for k in 1:3
      push!(get!(() -> NTuple{3,Int}[], uses, minmax(t[k], t[mod1(k + 1, 3)])), (i, t[k], t[mod1(k + 1, 3)]))
    end
  end
  rim = Tuple{Spot,Spot,Spot,Any}[]
  for list in values(uses)
    length(list) == 1 || continue
    i, a, b = list[1]
    p, q = Sketching.flat(f, s.points[a]), Sketching.flat(f, s.points[b])
    t = s.triangles[i]
    middle = (Sketching.flat(f, s.points[t[1]]) .+ Sketching.flat(f, s.points[t[2]]) .+ Sketching.flat(f, s.points[t[3]])) ./ 3
    out = right(p, q)
    dot2(out, (p .+ q) ./ 2 .- middle) < 0 && (out = out .* -1)
    push!(rim, (p, q, out, get(edge_of, minmax(a, b), (:side, a, b))))
  end
  Profile(triangles, rim)
end

"The edge of the body `s` that each side of its triangles is on, by the side's two points"
edge_sides(s::Shape) = begin
  at = Dict{Vec3,Int}(p => i for (i, p) in enumerate(s.points))
  out = Dict{NTuple{2,Int},Int}()
  for (k, e) in enumerate(s.edges), i in 1:length(e.points)-1
    a, b = get(at, e.points[i], 0), get(at, e.points[i+1], 0)
    (a == 0 || b == 0) || (out[minmax(a, b)] = k)
  end
  out
end

# --- sweeps ----------------------------------------------------------------------------

"""
The solid that the profile `p` on the plane `f` makes when it moves along the
plane's normal from `low` to `high` mm, as an extrude makes. With a `taper`
angle in radians its sides lean out by that much, so the end that's farther
from the plane is bigger.
"""
extrude(name, f::Frame, p::Profile, low, high; taper=0.0) = begin
  n = Sketching.normal(f)
  lean = taper == 0 ? Dict{Spot,Spot}() : leans(p)
  at(q, h) = Sketching.world(f, q .+ get(lean, q, (0.0, 0.0)) .* (abs(h) * tan(taper))) .+ n .* h
  b = Builder()
  for t in p.triangles
    triangle!(b, at(t[1], low), at(t[2], low), at(t[3], low), :low, n .* -1.0)
    triangle!(b, at(t[1], high), at(t[2], high), at(t[3], high), :high, n)
  end
  for (q, r, out, k) in p.rim
    way = f.x .* out[1] .+ f.y .* out[2]
    a, c, d, e = at(q, low), at(r, low), at(r, high), at(q, high)
    triangle!(b, a, c, d, k, way)
    triangle!(b, a, d, e, k, way)
  end
  shape(b, name)
end

"How far each place round the rim of `p` moves when each side moves out by 1"
leans(p::Profile) = begin
  ways = Dict{Spot,Vector{Spot}}()
  for (q, r, out, _) in p.rim
    push!(get!(() -> Spot[], ways, q), out)
    push!(get!(() -> Spot[], ways, r), out)
  end
  Dict{Spot,Spot}(q => mitre(list) for (q, list) in ways)
end

mitre(list) = begin
  length(list) == 2 || return reduce((a, b) -> a .+ b, list) ./ length(list)
  a, b = list
  d = 1 + dot2(a, b)
  d < 0.2 ? a : (a .+ b) ./ d
end

"""
The solid that the profile `p` on the plane `f` makes when it turns round the
axis through `o` along `w`, from the angle `a1` to `a2` in radians, as a
revolve makes.
"""
revolve(name, f::Frame, p::Profile, o::Vec3, w::Vec3, a1, a2) = begin
  w = unit(w)
  a1, a2 = min(a1, a2), max(a1, a2)
  whole = a2 - a1 >= 2π - 1e-9
  whole && (a2 = a1 + 2π)
  steps = max(3, ceil(Int, (a2 - a1) / (2π / 96)))
  angle(j) = whole && j == steps ? a1 : a1 + (a2 - a1) * j / steps
  at(q, j) = turned(Sketching.world(f, q), o, w, angle(j))
  b = Builder()
  for (q, r, out, k) in p.rim
    way = f.x .* out[1] .+ f.y .* out[2]
    for j in 0:steps-1
      facing = turned(way, w, a1 + (a2 - a1) * (j + 0.5) / steps)
      a, c, d, e = at(q, j), at(r, j), at(r, j + 1), at(q, j + 1)
      triangle!(b, a, c, d, k, facing)
      triangle!(b, a, d, e, k, facing)
    end
  end
  if !whole
    for t in p.triangles, (j, sign, key) in ((0, -1.0, :start), (steps, 1.0, :end))
      a, c, d = at(t[1], j), at(t[2], j), at(t[3], j)
      triangle!(b, a, c, d, key, cross(w, (a .+ c .+ d) ./ 3 .- o) .* sign)
    end
  end
  shape(b, name)
end

# --- shapes of their own ---------------------------------------------------------------

"A box `size` mm long, wide and tall, round the point `c`"
box(name, c::Vec3, size::Vec3) = begin
  hx, hy = size[1] / 2, size[2] / 2
  extrude(name, Frame(c, (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)), polygon(Spot[(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)]), -size[3] / 2, size[3] / 2)
end

"A plane through `o` whose y goes along `w`, for a profile that turns round the axis through `o` along `w`"
upright(o::Vec3, w::Vec3) = (f = plane(o, w); Frame(o, f.x, unit(w)))

"A cylinder of diameter `d` and height `h`, whose base's middle is `base`, going the way `w`"
cylinder(name, base::Vec3, w::Vec3, d, h) = extrude(name, plane(base, w), disc(d / 2), 0.0, h)

"A cone from a base of diameter `d` to a top of diameter `top`, `h` high, from `base` along `w`"
cone(name, base::Vec3, w::Vec3, d, top, h) = begin
  ring = top > 0 ? Spot[(0.0, 0.0), (d / 2, 0.0), (top / 2, h), (0.0, h)] : Spot[(0.0, 0.0), (d / 2, 0.0), (0.0, h)]
  revolve(name, upright(base, w), polygon(ring), base, unit(w), 0.0, 2π)
end

"A ball of diameter `d` round `c`"
sphere(name, c::Vec3, d) = begin
  r = d / 2
  ring = Spot[(r * cos(t), r * sin(t)) for t in range(-π / 2, π / 2, length=49)]
  revolve(name, upright(c, (0.0, 0.0, 1.0)), polygon(ring, ones(Int, length(ring))), c, (0.0, 0.0, 1.0), 0.0, 2π)
end

"A ring round the axis through `c` along `w`: its middle `major` mm from the axis, its tube `minor` mm thick from the middle"
torus(name, c::Vec3, w::Vec3, major, minor) = revolve(name, upright(c, w), disc(minor, (major, 0.0); n=48), c, unit(w), 0.0, 2π)

# --- bodies moved -------------------------------------------------------------------

"""
A copy of the body `s` named `name`, with each point at `move(p)`, and each way
that its surface faces turned by `turn`. Pass `mirrors` for a move that
mirrors: its triangles are turned over, so that they still face out.
"""
moved(s::Shape, name, move, turn=identity; mirrors=false) = begin
  points = Vec3[move(p) for p in s.points]
  triangles = mirrors ? NTuple{3,Int}[(t[1], t[3], t[2]) for t in s.triangles] : copy(s.triangles)
  normals = Vec3[turn(w) for w in s.normals]
  if mirrors
    for i in 1:3:length(normals)
      normals[i+1], normals[i+2] = normals[i+2], normals[i+1]
    end
  end
  edges = Edge[Edge(Vec3[move(p) for p in e.points], e.faces, e.closed) for e in s.edges]
  low = reduce((a, b) -> min.(a, b), points; init=(Inf, Inf, Inf))
  high = reduce((a, b) -> max.(a, b), points; init=(-Inf, -Inf, -Inf))
  Shape(String(name), points, normals, triangles, copy(s.face), copy(s.flat), edges, low, high)
end

"A copy of `s` named `name`, turned by `angle` radians round the axis through `o` along `w`"
turned(s::Shape, name, o::Vec3, w::Vec3, angle) = (w = unit(w); moved(s, name, p -> turned(p, o, w, angle), x -> turned(x, w, angle)))

"A copy of `s` named `name`, mirrored in the plane through `o` that faces `n`"
mirrored(s::Shape, name, o::Vec3, n::Vec3) = begin
  n = unit(n)
  moved(s, name, p -> p .- n .* (2dot(p .- o, n)), x -> x .- n .* (2dot(x, n)); mirrors=true)
end

"A copy of `s` named `name`, `k` times as big, round the point `c`"
scaled(s::Shape, name, c::Vec3, k) = moved(s, name, p -> c .+ (p .- c) .* k, x -> k < 0 ? x .* -1.0 : x; mirrors=k < 0)

# --- faces moved -------------------------------------------------------------------

"""
The way a point moves when the planes of the faces round it each move out by
1, as the unit ways `ways` that those faces face: so a corner of a box moves
along all three of its faces' ways at once.
"""
meet(ways) = begin
  list = Vec3[]
  for w in ways
    any(u -> dot(u, w) > 1 - 1e-6, list) || push!(list, w)
  end
  isempty(list) && return (0.0, 0.0, 0.0)
  length(list) == 1 && return list[1]
  a, b = list[1], list[2]
  if length(list) >= 3
    c = list[3]
    det = dot(a, cross(b, c))
    abs(det) > 1e-6 && return (cross(b, c) .+ cross(c, a) .+ cross(a, b)) ./ det
  end
  d = 1 + dot(a, b)
  d < 0.05 ? a : (a .+ b) ./ d
end

"""
The shortest move that takes a point onto each of a few planes. Each plane is
given as the unit way it faces, and how far the point is from it along that
way. Three planes meet at one point. With two, the point moves along neither
plane's line more than it must. A plane that faces the way of one before it
counts once.
"""
onto(planes) = begin
  list = Tuple{Vec3,Float64}[]
  for (w, b) in planes
    any(u -> abs(dot(u[1], w)) > 1 - 1e-6, list) || push!(list, (w, b))
  end
  isempty(list) && return (0.0, 0.0, 0.0)
  (a, x) = list[1]
  length(list) == 1 && return a .* x
  (b, y) = list[2]
  if length(list) >= 3
    (c, z) = list[3]
    det = dot(a, cross(b, c))
    abs(det) > 1e-6 && return (cross(b, c) .* x .+ cross(c, a) .* y .+ cross(a, b) .* z) ./ det
  end
  k = dot(a, b)
  ((x - k * y) / (1 - k^2)) .* a .+ ((y - k * x) / (1 - k^2)) .* b
end

"The ways that the faces of `s` face at each of its points: a list of (face, way) for each point"
point_ways(s::Shape) = begin
  ways = [Tuple{Int,Vec3}[] for _ in s.points]
  for (i, t) in enumerate(s.triangles), k in 1:3
    list = ways[t[k]]
    any(x -> x[1] == s.face[i], list) || push!(list, (s.face[i], s.normals[3i-3+k]))
  end
  ways
end

"""
The solid between the faces `faces` of the body `s` and the same faces with
each point `i` moved to `to(i)`: what Press Pull adds to a face, or takes away
from it. `out` is +1 when the moved faces are outside the body, and -1 when
they're in it.
"""
shifted(name, s::Shape, faces, to; out=1.0) = begin
  chosen = Set(faces)
  b = Builder()
  uses = Dict{NTuple{2,Int},Vector{Tuple{Int,Int,Int}}}()
  for (i, t) in enumerate(s.triangles)
    s.face[i] in chosen || continue
    old = (s.points[t[1]], s.points[t[2]], s.points[t[3]])
    new = (to(t[1]), to(t[2]), to(t[3]))
    # Where the face moves out of the body, the piece is in front of it. Where it moves in, behind it.
    moves = dot((new[1] .+ new[2] .+ new[3]) ./ 3 .- (old[1] .+ old[2] .+ old[3]) ./ 3, s.normals[3i-2])
    way = s.normals[3i-2] .* (abs(moves) < 1e-12 ? out : sign(moves))
    triangle!(b, old..., (:old, s.face[i]), way .* -1.0)
    triangle!(b, new..., (:new, s.face[i]), way)
    for k in 1:3
      push!(get!(() -> Tuple{Int,Int,Int}[], uses, minmax(t[k], t[mod1(k + 1, 3)])), (i, t[k], t[mod1(k + 1, 3)]))
    end
  end
  edge_of = edge_sides(s)
  for list in values(uses)
    length(list) == 1 || continue
    i, a, c = list[1]
    t = s.triangles[i]
    middle = (s.points[t[1]] .+ s.points[t[2]] .+ s.points[t[3]]) ./ 3
    away = (s.points[a] .+ s.points[c]) ./ 2 .- middle
    face = (:wall, get(edge_of, minmax(a, c), (a, c)))
    triangle!(b, s.points[a], s.points[c], to(c), face, away)
    triangle!(b, s.points[a], to(c), to(a), face, away)
  end
  shape(b, name)
end

"""
What Press Pull or Offset Face adds when the faces `faces` of the body `s`
move out by `d` mm, or takes away when `d` is under 0.
"""
offset(name, s::Shape, faces, d) = begin
  chosen = Set(faces)
  ways = point_ways(s)
  to(i) = s.points[i] .+ meet(Vec3[w for (f, w) in ways[i] if f in chosen]) .* d
  shifted(name, s, faces, to; out=d >= 0 ? 1.0 : -1.0)
end

"""
The body `s` with each point moved in by `t` mm from every face but the faces
`open`: what Shell takes out of it. Where a face is open, the hollow goes
out through it.
"""
hollow(name, s::Shape, open, t) = begin
  ways = point_ways(s)
  open = Set(open)
  to = Dict{Vec3,Vec3}(p => p .- meet(Vec3[w for (f, w) in ways[i] if !(f in open)]) .* t for (i, p) in enumerate(s.points))
  moved(s, name, p -> get(to, p, p))
end

"""
What Draft does to the flat faces `faces` of the body `s`: each face's plane
turns by `angle` radians round the line where it meets the plane through `o`
that faces `pull`, so that the face leans in as it goes along `pull`. The
faces round it stay on their own planes, so each corner of the face slides
along them to the face's new plane. The piece is the solid between the faces
as they are and as they will be, and the sign of how much room it takes:
under 0 when the draft takes more away than it adds.
"""
drafted(name, s::Shape, faces, o::Vec3, pull::Vec3, angle) = begin
  pull = unit(pull)
  planes = Dict{Int,Tuple{Vec3,Vec3}}()   # each face's new plane: a point on it, and the way it faces
  for n in faces
    i = findfirst(==(n), s.face)
    i === nothing && continue
    way = s.normals[3i-2]
    hinge = cross(way, pull)
    len(hinge) < 1e-9 && continue
    hinge = unit(hinge)
    # A point of the line where the face's plane meets the neutral plane
    p = s.points[s.triangles[i][1]]
    side = cross(hinge, way)   # in the face, across the hinge
    k = dot(side, pull)
    abs(k) < 1e-12 && continue
    on = p .+ side .* (dot(o .- p, pull) / k)
    planes[n] = (on, turned(way, hinge, angle))
  end
  ways = point_ways(s)
  to(i) = begin
    p = s.points[i]
    any(x -> haskey(planes, x[1]), ways[i]) || return p
    # A corner goes on to the new planes of its faces that turn, and keeps to the planes of the other faces round it
    p .+ onto(Tuple{Vec3,Float64}[haskey(planes, f) ? (planes[f][2], dot(planes[f][1] .- p, planes[f][2])) : (w, 0.0) for (f, w) in ways[i]])
  end
  moved = collect(keys(planes))
  # How much the faces move out, all told: under 0 where they move in
  out = 0.0
  for (i, t) in enumerate(s.triangles), c in t
    s.face[i] in moved && (out += dot(to(c) .- s.points[c], s.normals[3i-2]))
  end
  (shifted(name, s, moved, to), out)
end

# --- rounds and chamfers on edges ----------------------------------------------------

"For each point of `s`, the triangles that have it as a corner, each with which corner it is"
corners_of(s::Shape) = begin
  out = [NTuple{2,Int}[] for _ in s.points]
  for (i, t) in enumerate(s.triangles), k in 1:3
    push!(out[t[k]], (i, k))
  end
  out
end

"""
How the faces `f1` and `f2` of `s` meet at its point `k`, where the edge goes
the way `along`: the way each faces there, and the way into each from the edge.
"""
faces_at(s::Shape, around, k, f1, f2, along) = begin
  get_face(f) = begin
    way, into = (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)
    for (i, c) in around[k]
      s.face[i] == f || continue
      way = way .+ s.normals[3i-3+c]
      t = s.triangles[i]
      into = into .+ ((s.points[t[1]] .+ s.points[t[2]] .+ s.points[t[3]]) ./ 3 .- s.points[k])
    end
    way = unit(way)
    into = into .- along .* dot(into, along)
    into = unit(into .- way .* dot(into, way))
    (way, into)
  end
  get_face(f1)..., get_face(f2)...
end

"The edges of `s` that go on smoothly from the edges `chosen`, end to end, as a tangent chain does"
chained(s::Shape, chosen) = begin
  out = collect(chosen)
  ends(e) = (e.points[1], e.points[end])
  way(e, at_start) = at_start ? unit(e.points[2] .- e.points[1]) : unit(e.points[end] .- e.points[end-1])
  grew = true
  while grew
    grew = false
    for (k, e) in enumerate(s.edges)
      (k in out || length(e.points) < 2 || e.faces[2] == 0) && continue
      for j in out
        f = s.edges[j]
        for (p, ps) in ((e.points[1], true), (e.points[end], false)), (q, qs) in ((f.points[1], true), (f.points[end], false))
          len(p .- q) < 1e-6 || continue
          # Smooth where one goes on the way the other came
          abs(dot(way(e, ps), way(f, qs))) > cos(deg2rad(8)) || continue
          push!(out, k)
          grew = true
          break
        end
        grew && break
      end
      grew && break
    end
  end
  out
end

"""
What a fillet of radius `r`, or a chamfer, does to the edge `n` of the body
`s`: the piece between the edge and the round, or the flat, that meets both
faces. A chamfer has the two distances along the faces in `chamfer`. It's
taken away from an edge that sticks out, and added to an edge in a corner.
The piece, and whether the edge sticks out.
"""
edge_piece(name, s::Shape, n; r=0.0, chamfer=nothing, around=corners_of(s)) = begin
  e = s.edges[n]
  f1, f2 = e.faces
  (f2 == 0 || length(e.points) < 2) && return nothing
  at = Dict{Vec3,Int}(p => i for (i, p) in enumerate(s.points))
  points = e.closed && e.points[1] == e.points[end] ? e.points[1:end-1] : e.points
  m = length(points)
  m < 2 && return nothing
  # Each section across the edge, and the way out of the piece from each of its sides
  sections, aways = Vector{Vec3}[], Vector{Vec3}[]
  sticks = true
  for (j, p) in enumerate(points)
    k = get(at, p, 0)
    k == 0 && return nothing
    before = e.closed ? points[mod1(j - 1, m)] : points[max(j - 1, 1)]
    after = e.closed ? points[mod1(j + 1, m)] : points[min(j + 1, m)]
    along = unit(after .- before)
    n1, t1, n2, t2 = faces_at(s, around, k, f1, f2, along)
    out = dot(t1, n2) < 0
    j == 1 && (sticks = out)
    # The piece is on the faces where the edge sticks out, and in front of them in a corner
    side = out ? 1.0 : -1.0
    if chamfer !== nothing
      a, b = p .+ t1 .* chamfer[1], p .+ t2 .* chamfer[2]
      push!(sections, Vec3[p, a, b])
      push!(aways, Vec3[n1 .* side, (a .+ b) ./ 2 .- p, n2 .* side])
    else
      σ = -side * r
      det = dot(n1, cross(n2, along))
      abs(det) < 1e-9 && return nothing
      c = p .+ (cross(n2, along) .* σ .+ cross(along, n1) .* σ) ./ det
      a, b = c .- n1 .* dot(c .- p, n1), c .- n2 .* dot(c .- p, n2)
      u, v = unit(a .- c), unit(b .- c)
      φ = acos(clamp(dot(u, v), -1.0, 1.0))
      w = unit(v .- u .* dot(u, v))
      arc = Vec3[c .+ (u .* cos(φ * i / 12) .+ w .* sin(φ * i / 12)) .* r for i in 0:12]
      push!(sections, vcat(Vec3[p], arc))
      # Out of the piece through the round is towards the round's middle
      push!(aways, vcat(Vec3[n1 .* side], Vec3[c .- (arc[i] .+ arc[i+1]) ./ 2 for i in 1:12], Vec3[n2 .* side]))
    end
  end
  b = Builder()
  sides = length(sections[1])
  middle(sec) = reduce((x, y) -> x .+ y, sec) ./ length(sec)
  face(i) = i == 1 ? :one : i == sides ? :two : :round
  for j in 1:(e.closed ? m : m - 1)
    s1, s2 = sections[j], sections[mod1(j + 1, m)]
    for i in 1:sides
      a, c = s1[i], s1[mod1(i + 1, sides)]
      d, h = s2[mod1(i + 1, sides)], s2[i]
      away = aways[j][i]
      triangle!(b, a, c, d, face(i), away)
      triangle!(b, a, d, h, face(i), away)
    end
  end
  if !e.closed
    for (sec, other, key) in ((sections[1], sections[2], :start), (sections[end], sections[end-1], :end))
      away = middle(sec) .- middle(other)
      for i in 2:sides-1
        triangle!(b, sec[1], sec[i], sec[i+1], key, away)
      end
    end
  end
  (shape(b, name), sticks)
end

# --- where a plane cuts a body -------------------------------------------------------

"The lines where the plane through `o` that faces `n` cuts the body `s`, as the graphics card takes lines: 6 numbers for each"
section(s::Shape, o::Vec3, n::Vec3) = begin
  data = Float32[]
  height = [dot(p .- o, n) for p in s.points]
  for t in s.triangles
    cuts = Vec3[]
    for k in 1:3
      i, j = t[k], t[mod1(k + 1, 3)]
      (height[i] > 0) == (height[j] > 0) && continue
      x = height[i] / (height[i] - height[j])
      push!(cuts, s.points[i] .+ (s.points[j] .- s.points[i]) .* x)
    end
    length(cuts) == 2 && (append!(data, cuts[1]); append!(data, cuts[2]))
  end
  data
end
