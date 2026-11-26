# The shapes of a design as triangles, and the eye that looks at them.
#
# SolidCraft's program writes the bodies of a design as a .glb file: for each
# body its corners, the way the surface faces at each corner, and triangles.
# `read_glb` reads it. A solid body is more than triangles, though. It has
# faces, like the top of a block or the wall of a hole, and edges where two
# faces meet. SolidCraft writes each face with corners of its own, so:
#
#   - A face is the triangles that share corners in the file.
#   - The corners of two faces at one place are one point of the body.
#   - An edge is a run of sides that have the same two faces on their two sides.
#
# So a hole's wall is one face, and the ring where it meets the top is one
# edge. That's what the editor shows under the mouse, and what a click picks.
# Two curved faces that meet smoothly, like a rounded edge and the rounded
# corner at its end, are two faces too, as SolidCraft has them.
#
# SolidCraft can also write an OBJ file, and a 3MF file with the number of
# each triangle's face. Those cut a thin flat sheet into a hundred thousand
# triangles: a design with 24 such sheets took 84 seconds to write, where its
# .glb file takes a third of a second.
#
#     shapes, colours = read_glb(read("design.glb"))   # [Shape(name="Body1", ...), ...], and each body's colour by its name
#     eye = fit(Eye(), box(shapes), (800, 600))
#     at(eye, (800, 600), (30.0, 0.0, 13.0))   # where that point of the design shows, in px
#     hit(shapes, ray(eye, (800, 600), (400, 300)))   # what shows at a place of the view

@use "github.com/jkroso/JSON.jl" => JSON

const Vec3 = NTuple{3,Float64}

dot(a::Vec3, b::Vec3) = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
cross(a::Vec3, b::Vec3) = (a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])
len(a::Vec3) = sqrt(dot(a, a))
unit(a::Vec3) = (l = len(a); l == 0 ? a : a ./ l)

"An edge of a body: the corners along it, and the two faces that meet at it"
struct Edge
  points::Vector{Vec3}
  faces::NTuple{2,Int}
  closed::Bool
end

"A body as triangles, with its faces and its edges"
struct Shape
  name::String
  points::Vector{Vec3}
  normals::Vector{Vec3}              # the way the surface faces at each corner of each triangle, three for a triangle
  triangles::Vector{NTuple{3,Int}}   # each as the places of its corners in `points`
  face::Vector{Int}                  # the face that each triangle is part of
  flat::Vector{Bool}                 # for each face: is it flat?
  edges::Vector{Edge}
  low::Vec3                          # the corners of the box round it
  high::Vec3
end

"The middle of an edge, along its length: SolidCraft picks an edge by a point on it"
middle(e::Edge) = begin
  n = length(e.points)
  n == 1 && return e.points[1]
  total = sum(len(e.points[i+1] .- e.points[i]) for i in 1:n-1)
  left = total / 2
  for i in 1:n-1
    l = len(e.points[i+1] .- e.points[i])
    left <= l && return e.points[i] .+ (e.points[i+1] .- e.points[i]) .* (l == 0 ? 0.0 : left / l)
    left -= l
  end
  e.points[end]
end

"The box round `shapes`: its low corner and its high one. A design with no bodies has a box of 100 mm round the origin."
box(shapes) = begin
  any(s -> !isempty(s.points), shapes) || return ((-50.0, -50.0, -50.0), (50.0, 50.0, 50.0))
  low, high = (Inf, Inf, Inf), (-Inf, -Inf, -Inf)
  for s in shapes
    isempty(s.points) && continue
    low, high = min.(low, s.low), max.(high, s.high)
  end
  low, high
end

# --- reading the file ----------------------------------------------------------------

"The colour of a body that has none of its own, as SolidCraft writes it in a .glb file: amounts of light, not a screen's numbers"
const PLAIN = (0.43415, 0.49102, 0.56471)

"A screen's number, from 0 to 1, for an amount of light"
screen(x) = x <= 0.0031308 ? 12.92x : 1.055 * x^(1 / 2.4) - 0.055

"`count` rows of `N` numbers of the type `T` in `data`: the first is at the byte `from`, and each row is `step` bytes after the one before"
rows(data::Vector{UInt8}, from, step, count, ::Type{T}, ::Val{N}) where {T,N} = begin
  from + (count - 1) * step + N * sizeof(T) - 1 <= length(data) || error("The file is cut short")
  GC.@preserve data [ntuple(c -> ltoh(unsafe_load(Ptr{T}(pointer(data, from + (i - 1) * step + (c - 1) * sizeof(T))))), Val(N)) for i in 1:count]
end

"The corner that stands for the face of the corner `c`. `group` leads from each corner to another one of its face, or to itself."
leader!(group::Vector{Int}, c::Int) = begin
  while group[c] != c
    c = group[c] = group[group[c]]
  end
  c
end

"""
Add one part of a body's mesh to the body. `at` has the part's corners,
`facing` the way the surface faces at each one, or nothing, and `corners`
names three corners for each triangle. `faces` is how many faces the body
has so far, and this gives how many it has now.

SolidCraft writes each face with corners of its own. So a face is the
triangles that share corners, and the corners of two faces at one place
become one of the body's `points`.
"""
part!(points, places, triangles, normals, face, faces::Int, at::Vector{Vec3}, facing::Union{Nothing,Vector{Vec3}}, corners::Vector{Int}) = begin
  group = collect(1:length(at))
  for t in 1:3:length(corners)-2
    a = leader!(group, corners[t])
    group[leader!(group, corners[t+1])] = a
    group[leader!(group, corners[t+2])] = a
  end
  point = [get!(() -> (push!(points, q); length(points)), places, q) for q in at]
  numbers = Dict{Int,Int}()
  for t in 1:3:length(corners)-2
    a, b, c = corners[t], corners[t+1], corners[t+2]
    push!(triangles, (point[a], point[b], point[c]))
    flat = unit(cross(at[b] .- at[a], at[c] .- at[a]))
    for k in (a, b, c)
      push!(normals, facing === nothing ? flat : facing[k])
    end
    lead = leader!(group, a)
    f = get(numbers, lead, 0)
    f == 0 && (f = numbers[lead] = (faces += 1))
    push!(face, f)
  end
  faces
end

"""
The bodies in the bytes of a .glb file that SolidCraft wrote with `hierarchy:
false`, and the colour of each body that has a colour of its own, as red,
green and blue from 0 to 1. Such a file has every body where it is in the
design, in mm with z up, whatever its first node says of metres and y. A file
that can't be read has no bodies.
"""
read_glb(data::Vector{UInt8}) = begin
  none = (Shape[], Dict{String,Vec3}())
  word(at) = Int(data[at]) | Int(data[at+1]) << 8 | Int(data[at+2]) << 16 | Int(data[at+3]) << 24
  (length(data) >= 28 && data[1:4] == b"glTF") || return none
  text = word(13)
  length(data) >= 28 + text || return none
  doc = try JSON.parse_json(String(data[21:20+text]), JSON.Object) catch; return none end
  first_byte = 20 + text + 9   # of the numbers, after the text and the 8 bytes that say how long they are
  list(key) = (l = doc isa JSON.Object ? get(doc, key, nothing) : nothing; l isa Vector ? l : Any[])
  views, accessors, materials, meshes = list("bufferViews"), list("accessors"), list("materials"), list("meshes")
  # The numbers of the accessor `k`: each row has `n` of them, of the type that the file says
  column(k, n) = begin
    a = accessors[Int(k)+1]
    v = views[Int(a["bufferView"])+1]
    kind = Int(a["componentType"])
    T = kind == 5126 ? Float32 : kind == 5125 ? UInt32 : kind == 5123 ? UInt16 : UInt8
    step = Int(get(v, "byteStride", 0))
    rows(data, first_byte + Int(get(v, "byteOffset", 0)) + Int(get(a, "byteOffset", 0)), step == 0 ? n * sizeof(T) : step, Int(a["count"]), T, Val(n))
  end
  shapes, colours = Shape[], Dict{String,Vec3}()
  try
    for node in list("nodes")
      (node isa JSON.Object && haskey(node, "mesh")) || continue
      name = String(get(node, "name", ""))
      points, places = Vec3[], Dict{Vec3,Int}()   # the body's points, and the number of the point at each place
      triangles, normals, face = NTuple{3,Int}[], Vec3[], Int[]
      faces = 0
      for (n, part) in enumerate(meshes[Int(node["mesh"])+1]["primitives"])
        given = part["attributes"]
        at = map(q -> Float64.(q), column(given["POSITION"], 3))::Vector{Vec3}
        facing = haskey(given, "NORMAL") ? map(q -> unit(Float64.(q)), column(given["NORMAL"], 3))::Vector{Vec3} : nothing
        corners = haskey(part, "indices") ? map(q -> Int(q[1]) + 1, column(part["indices"], 1))::Vector{Int} : collect(1:length(at))
        all(c -> 1 <= c <= length(at), corners) || error("A triangle names a corner that isn't there")
        faces = part!(points, places, triangles, normals, face, faces, at, facing, corners)
        # The body's own look is the first that the file gives it. A face that was painted comes after, with its own.
        m = n == 1 && haskey(part, "material") ? materials[Int(part["material"])+1] : nothing
        look = m isa JSON.Object ? get(m, "pbrMetallicRoughness", nothing) : nothing
        colour = look isa JSON.Object ? get(look, "baseColorFactor", nothing) : nothing
        if colour isa Vector && length(colour) >= 3
          light = (Float64(colour[1]), Float64(colour[2]), Float64(colour[3]))
          # A body with no colour has a look that's named after the body
          plain = get(m, "name", "") == name && all(abs.(light .- PLAIN) .< 1e-3)
          plain || (colours[name] = screen.(light))
        end
      end
      push!(shapes, Shape(name, points, triangles, normals, face))
    end
  catch
    return none
  end
  shapes, colours
end

const LEVEL = 1 - 1e-9   # the cosine under which two corners face one way, so a face whose corners all do is flat

"""
The body `name`. `points` has its corners, and each of `triangles` names three
of them. `normals` has the way the surface faces at each corner of each
triangle, three for a triangle, and `face` the number of the face that each
triangle is part of, from 1.
"""
Shape(name, points::Vector{Vec3}, triangles::Vector{NTuple{3,Int}}, normals::Vector{Vec3}, face::Vector{Int}) = begin
  # A face is flat when the surface faces one way at every corner of it
  first_way = Dict{Int,Vec3}()
  flats = fill(true, maximum(face, init=0))
  for (i, f) in enumerate(face), k in 1:3
    n = normals[3i-3+k]
    dot(get!(first_way, f, n), n) > LEVEL || (flats[f] = false)
  end
  # The triangles on each side of every side of a triangle
  sides = Dict{NTuple{2,Int},Vector{NTuple{2,Int}}}()   # the two corners → (triangle, which corner the side starts at)
  for (i, t) in enumerate(triangles), k in 1:3
    a, b = t[k], t[mod1(k + 1, 3)]
    push!(get!(() -> NTuple{2,Int}[], sides, minmax(a, b)), (i, k))
  end
  low = isempty(points) ? (0.0, 0.0, 0.0) : reduce((a, b) -> min.(a, b), points)
  high = isempty(points) ? (0.0, 0.0, 0.0) : reduce((a, b) -> max.(a, b), points)
  Shape(name, points, normals, triangles, face, flats, edges(points, sides, face), low, high)
end

"The edges of a body: each run of sides of triangles that has the same two faces on its two sides"
edges(points, sides, face) = begin
  # Each side that's on an edge, by the two faces that it parts. A side with one triangle is the rim of an open sheet.
  runs = Dict{NTuple{2,Int},Vector{NTuple{2,Int}}}()
  for (key, users) in sides
    pair = length(users) == 2 ? minmax(face[users[1][1]], face[users[2][1]]) : (face[users[1][1]], 0)
    pair[1] == pair[2] && continue
    push!(get!(() -> NTuple{2,Int}[], runs, pair), key)
  end
  found = Edge[]
  for (pair, segments) in runs
    # Join the sides end to end. A corner where the run stops or forks ends an edge.
    at = Dict{Int,Vector{Int}}()
    for (i, s) in enumerate(segments), c in s
      push!(get!(() -> Int[], at, c), i)
    end
    used = falses(length(segments))
    walk(start, first) = begin
      line = [start]
      c, i = start, first
      while true
        used[i] = true
        c = segments[i][1] == c ? segments[i][2] : segments[i][1]
        push!(line, c)
        next = length(at[c]) == 2 ? findfirst(j -> !used[j], at[c]) : nothing
        next === nothing && break
        i = at[c][next]
      end
      line
    end
    for (c, list) in at
      length(list) == 2 && continue
      for i in list
        used[i] || push!(found, Edge([points[k] for k in walk(c, i)], pair, false))
      end
    end
    # What's left goes round in rings
    for i in eachindex(segments)
      used[i] && continue
      line = walk(segments[i][1], i)
      push!(found, Edge([points[k] for k in line], pair, true))
    end
  end
  found
end

# --- the eye --------------------------------------------------------------------------
#
# The eye looks at a point of the design, its `target`, from `distance` away.
# `turn` is the way it looks from, round the upright axis z, and `tilt` is how
# far over the design it is: both in degrees. Things farther away look smaller
# when `wide`, the angle of what it sees from top to bottom, is over 0. With 0
# they don't, as in a drawing.

struct Eye
  target::Vec3
  turn::Float64
  tilt::Float64
  distance::Float64
  wide::Float64
end

Eye() = Eye((0.0, 0.0, 0.0), -35.0, 28.0, 200.0, 32.0)

"The eye's three axes: to its right, up, and from the target back to the eye"
axes(e::Eye) = begin
  st, ct = sincosd(e.turn)
  sp, cp = sincosd(e.tilt)
  back = (cp * ct, cp * st, sp)
  right = (-st, ct, 0.0)
  (right, cross(back, right), back)
end

"The point that the eye is at"
place(e::Eye) = e.target .+ axes(e)[3] .* e.distance

"How many px one mm at the target shows as, in a view `size` px wide and tall"
scale(e::Eye, size) = e.wide > 0 ? size[2] / (2e.distance * tand(e.wide / 2)) : size[2] / e.distance

"""
Where the point `p` of the design shows in a view of `size` px: px from its
left and from its top, and how far in front of the eye the point is. A point
behind the eye has a distance under 0, and shows nowhere.
"""
at(e::Eye, size, p::Vec3) = seer(e, size)(p)

"""
`at` for many points: a function that gives where a point shows, with the
eye's axes worked out once. A check of the edges under the mouse looks at
thousands of points, and the axes took most of its time.
"""
seer(e::Eye, size) = begin
  right, up, back = axes(e)
  wide = e.wide > 0
  k = wide ? (size[2] / 2) / tand(e.wide / 2) : scale(e, size)
  p -> begin
    d = p .- e.target
    x, y, depth = dot(d, right), dot(d, up), e.distance - dot(d, back)
    f = wide ? k / max(depth, 1e-9) : k
    (size[1] / 2 + x * f, size[2] / 2 - y * f, depth)
  end
end

"The line of sight through the place `px` of the view: a point that it starts at, and the way it goes"
ray(e::Eye, size, px) = begin
  right, up, back = axes(e)
  x, y = px[1] - size[1] / 2, size[2] / 2 - px[2]
  if e.wide > 0
    k = tand(e.wide / 2) / (size[2] / 2)
    (place(e), unit(right .* (x * k) .+ up .* (y * k) .- back))
  else
    k = 1 / scale(e, size)
    (place(e) .+ right .* (x * k) .+ up .* (y * k), back .* -1.0)
  end
end

"The eye that sees all of the box from `low` to `high` in a view of `size` px, looking the way `e` looks"
fit(e::Eye, (low, high), size; room=1.25) = begin
  middle = (low .+ high) ./ 2
  radius = max(len(high .- low) / 2, 1e-3) * room
  narrow = min(size[1], size[2]) / max(size[2], 1)   # a view that's taller than wide shows less from side to side
  distance = e.wide > 0 ? radius / (sind(e.wide / 2) * min(1.0, narrow)) : 2radius / min(1.0, narrow)
  Eye(middle, e.turn, e.tilt, distance, e.wide)
end

"Turn the eye round the point `pivot` of the design, which stays where it shows"
turned(e::Eye, size, turn, tilt, pivot::Vec3) = begin
  was = at(e, size, pivot)
  new = Eye(e.target, e.turn + turn, clamp(e.tilt + tilt, -90.0, 90.0), e.distance, e.wide)
  now = at(new, size, pivot)
  moved(new, size, (was[1] - now[1], was[2] - now[2]), pivot)
end

"Move the eye so that what it sees moves by `by` px. `about` is a point at the distance that moves by just that much."
moved(e::Eye, size, by, about::Vec3=e.target) = begin
  right, up, _ = axes(e)
  depth = at(e, size, about)[3]
  k = e.wide > 0 ? max(depth, 1e-6) * tand(e.wide / 2) / (size[2] / 2) : 1 / scale(e, size)
  Eye(e.target .- right .* (by[1] * k) .+ up .* (by[2] * k), e.turn, e.tilt, e.distance, e.wide)
end

"Bring the eye `by` times nearer to the point `about` of the design, which stays where it shows"
nearer(e::Eye, size, by, about::Vec3) = begin
  distance = clamp(e.distance / by, 1e-3, 1e7)
  if e.wide > 0
    # The eye and its target both go towards `about`, so `about` shows where it did, `by` times nearer. When only the
    # target moved, and only sideways, the eye came up to the plane through the target and no further: a part behind
    # that plane stopped growing, however much the wheel turned.
    return Eye(about .+ (e.target .- about) .* (distance / e.distance), e.turn, e.tilt, distance, e.wide)
  end
  was = at(e, size, about)
  new = Eye(e.target, e.turn, e.tilt, distance, e.wide)
  now = at(new, size, about)
  moved(new, size, (was[1] - now[1], was[2] - now[2]), about)
end

# --- what shows at a place ------------------------------------------------------------

"What a line of sight meets: the body, the triangle, the face, the point, and how far along the line it is"
struct Hit
  shape::Int
  triangle::Int
  face::Int
  point::Vec3
  far::Float64
end

"How far along the line from `o` the way `d` the triangle a, b, c is, or Inf if the line misses it"
meets(o::Vec3, d::Vec3, a::Vec3, b::Vec3, c::Vec3) = begin
  e1, e2 = b .- a, c .- a
  p = cross(d, e2)
  det = dot(e1, p)
  abs(det) < 1e-14 && return Inf
  s = o .- a
  u = dot(s, p) / det
  (u < -1e-9 || u > 1 + 1e-9) && return Inf
  q = cross(s, e1)
  v = dot(d, q) / det
  (v < -1e-9 || u + v > 1 + 1e-9) && return Inf
  t = dot(e2, q) / det
  t > 1e-9 ? t : Inf
end

"Does the line from `o` the way `d` go through the box from `low` to `high`?"
through(o::Vec3, d::Vec3, low::Vec3, high::Vec3) = begin
  near, far = -Inf, Inf
  for k in 1:3
    if abs(d[k]) < 1e-12
      (o[k] < low[k] - 1e-9 || o[k] > high[k] + 1e-9) && return false
    else
      a, b = (low[k] - o[k]) / d[k], (high[k] - o[k]) / d[k]
      near, far = max(near, min(a, b)), min(far, max(a, b))
    end
  end
  far >= max(near, 0.0) - 1e-9
end

"The nearest thing of `shapes` that the line of sight `(o, d)` meets, or nothing. `shown` says which of them show."
hit(shapes, (o, d); shown=s -> true) = begin
  best = nothing
  for (n, s) in enumerate(shapes)
    (shown(s) && through(o, d, s.low, s.high)) || continue
    for (i, t) in enumerate(s.triangles)
      far = meets(o, d, s.points[t[1]], s.points[t[2]], s.points[t[3]])
      far < (best === nothing ? Inf : best.far) && (best = Hit(n, i, s.face[i], o .+ d .* far, far))
    end
  end
  best
end

"""
The face of the body `s` that the point `p` is on. SolidCraft names a face by
a point on it, so this finds the triangle that the point is in, or with none
the triangle whose middle is nearest.
"""
face_at(s::Shape, p::Vec3) = begin
  best, found = Inf, 0
  near, nearest = Inf, 0
  for (i, t) in enumerate(s.triangles)
    a, b, c = s.points[t[1]], s.points[t[2]], s.points[t[3]]
    d = len((a .+ b .+ c) ./ 3 .- p)
    d < near && ((near, nearest) = (d, i))
    n = cross(b .- a, c .- a)
    area = dot(n, n)
    area < 1e-18 && continue
    # Where the point is in the triangle, as three shares that add up to 1
    u = dot(cross(b .- p, c .- p), n) / area
    v = dot(cross(c .- p, a .- p), n) / area
    (u < -1e-6 || v < -1e-6 || u + v > 1 + 1e-6) && continue
    off = abs(dot(p .- a, n)) / sqrt(area)
    off < best && ((best, found) = (off, i))
  end
  i = found == 0 || best > 1e-3 * max(len(s.high .- s.low), 1e-9) ? nearest : found
  i == 0 ? 0 : s.face[i]
end

"How far the place `px` is from the line between the places `a` and `b`, and how far along the line the nearest point is, from 0 to 1"
off(px, a, b) = begin
  dx, dy = b[1] - a[1], b[2] - a[2]
  l = dx^2 + dy^2
  t = l == 0 ? 0.0 : clamp(((px[1] - a[1]) * dx + (px[2] - a[2]) * dy) / l, 0.0, 1.0)
  (hypot(px[1] - a[1] - t * dx, px[2] - a[2] - t * dy), t)
end

"The point between `a` and `b` that's nearest the line of sight `(o, d)`"
closest(a::Vec3, b::Vec3, (o, d)) = begin
  u, w = b .- a, a .- o
  uu, ud, dd = dot(u, u), dot(u, d), dot(d, d)
  under = uu * dd - ud^2
  s = under < 1e-12 ? 0.0 : clamp((ud * dot(d, w) - dd * dot(u, w)) / under, 0.0, 1.0)
  a .+ u .* s
end

"""
The edge of `shapes` that shows nearest the place `px` of the view, within
`reach` px, and that nothing hides: `(shape, edge, point)`, or nothing.
`front` is what the line of sight through `px` meets first, if anything.
"""
edge_at(shapes, e::Eye, size, px, front; reach=6.0, shown=s -> true) = begin
  best, found = reach, nothing
  sight = ray(e, size, px)
  see = seer(e, size)
  limit = front === nothing ? Inf : see(front.point)[3] * 1.002 + 1e-6
  for (n, s) in enumerate(shapes)
    (!isempty(s.edges) && shown(s) && near(see, s.low, s.high, px, best)) || continue
    for (k, edge) in enumerate(s.edges)
      a = see(edge.points[1])
      for i in 1:length(edge.points)-1
        b = see(edge.points[i+1])
        if a[3] > 0 && b[3] > 0
          d, _ = off(px, a, b)
          if d < best
            # Far things look smaller, so halfway along the line as it shows isn't halfway along the edge.
            # The point of the edge is the one nearest the line of sight.
            p = closest(edge.points[i], edge.points[i+1], sight)
            # An edge at the back of a body is hidden by the face in front of it
            see(p)[3] <= limit && ((best, found) = (d, (n, k, p)))
          end
        end
        a = b
      end
    end
  end
  found
end

"""
Can a point of the box from `low` to `high` show within `reach` px of the
place `px`? `see` is the eye's `seer`. With every corner in front of the eye,
all of the box shows inside the rectangle round its corners.
"""
near(see, low::Vec3, high::Vec3, px, reach) = begin
  left, top, right, bottom = Inf, Inf, -Inf, -Inf
  for x in (low[1], high[1]), y in (low[2], high[2]), z in (low[3], high[3])
    q = see((x, y, z))
    q[3] > 0 || return true
    left, top, right, bottom = min(left, q[1]), min(top, q[2]), max(right, q[1]), max(bottom, q[2])
  end
  left - reach <= px[1] <= right + reach && top - reach <= px[2] <= bottom + reach
end
