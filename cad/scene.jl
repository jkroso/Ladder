# The shapes of a design as triangles, and the eye that looks at them.
#
# SolidCraft's program writes the bodies of a design as an OBJ file: corners,
# the way the surface faces at each corner, and triangles. `read_obj` reads
# it. A solid body is more than triangles, though. It has faces, like the top
# of a block or the wall of a hole, and edges where two faces meet. `Shape`
# finds them again in the triangles:
#
#   - A triangle is flat when the surface faces the same way at its three
#     corners as the triangle does. If not, it's part of a curved face.
#   - Two triangles that share a side are of one face when the surface faces
#     the same way on both sides of it, and both are flat or both are curved.
#   - An edge is a run of sides that have the same two faces on their two sides.
#
# So a hole's wall is one face, and the ring where it meets the top is one
# edge. That's what the editor shows under the mouse, and what a click picks.
#
# Two curved faces that meet smoothly, like a rounded edge and the rounded
# corner at its end, can't be told apart that way. SolidCraft also writes a
# file that says which face each triangle is of: `tagged` reads it, and
# `read_obj` takes the faces from it when its triangles are the same ones.
#
#     shapes = read_obj("design.obj")          # [Shape(name="Body1", ...), ...]
#     eye = fit(Eye(), box(shapes), (800, 600))
#     at(eye, (800, 600), (30.0, 0.0, 13.0))   # where that point of the design shows, in px
#     hit(shapes, ray(eye, (800, 600), (400, 300)))   # what shows at a place of the view

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

"The bodies in the OBJ file at `path`, as SolidCraft writes it"
read_obj(path::AbstractString; faces=nothing) = read_obj(read(path); faces)

"`faces` is what `tagged` read, or nothing: the face of each triangle of each body, as SolidCraft has them"
read_obj(data::Vector{UInt8}; faces=nothing) = begin
  points, normals = Vec3[], Vec3[]
  shapes = Shape[]
  name = ""
  tris, norms = NTuple{3,Int}[], NTuple{3,Int}[]
  done() = begin
    if !(isempty(tris) && isempty(name))
      known = faces === nothing || length(faces) <= length(shapes) ? nothing : faces[length(shapes)+1]
      push!(shapes, Shape(name, points, normals, tris, norms; tags=same_mesh(known, points, tris) ? known.faces : nothing))
    end
    tris, norms = NTuple{3,Int}[], NTuple{3,Int}[]
  end
  for line in eachline(IOBuffer(data))
    length(line) < 2 && continue
    if startswith(line, "v ")
      p = split(line)
      push!(points, (parse(Float64, p[2]), parse(Float64, p[3]), parse(Float64, p[4])))
    elseif startswith(line, "vn ")
      p = split(line)
      push!(normals, (parse(Float64, p[2]), parse(Float64, p[3]), parse(Float64, p[4])))
    elseif startswith(line, "f ")
      p = split(line)
      corner(s) = (q = split(s, '/'); (parse(Int, q[1]), length(q) >= 3 && !isempty(q[3]) ? parse(Int, q[3]) : 0))
      c = corner.(@view p[2:end])
      # A face with more than three corners is a fan of triangles
      for k in 2:length(c)-1
        push!(tris, (c[1][1], c[k][1], c[k+1][1]))
        push!(norms, (c[1][2], c[k][2], c[k+1][2]))
      end
    elseif startswith(line, "o ")
      done()
      name = String(strip(line[3:end]))
    end
  end
  done()
  shapes
end

"""
The face of each triangle of each body, from the text of the model inside a
3MF file that SolidCraft wrote with face tags. Each body is `(name, points,
triangles, faces)`: its corners, its triangles as the places of their corners
in `points`, and for each triangle the number of its face, counted from 0 as
SolidCraft counts the faces of a body.
"""
tagged(text::AbstractString) = begin
  bodies = Any[]
  number(s) = parse(Float64, s)
  for line in eachline(IOBuffer(text))
    l = lstrip(line)
    if startswith(l, "<vertex ")
      isempty(bodies) && continue
      q = split(l, '"')
      length(q) >= 6 && push!(bodies[end].points, (number(q[2]), number(q[4]), number(q[6])))
    elseif startswith(l, "<triangle ")
      isempty(bodies) && continue
      q = split(l, '"')
      length(q) >= 6 || continue
      push!(bodies[end].triangles, (parse(Int, q[2]) + 1, parse(Int, q[4]) + 1, parse(Int, q[6]) + 1))
      i = findfirst(k -> endswith(q[k], "ft:face="), 1:length(q)-1)
      push!(bodies[end].faces, i === nothing ? -1 : parse(Int, q[i+1]))
    elseif startswith(l, "<object ")
      m = match(r" name=\"([^\"]*)\"", l)
      push!(bodies, (name=m === nothing ? "" : String(m[1]), points=Vec3[], triangles=NTuple{3,Int}[], faces=Int[]))
    end
  end
  bodies
end

"Are the triangles `tris` of an OBJ file, with their corners in `points`, the triangles of the body `known` that `tagged` read, in the same order?"
same_mesh(known, points, tris) = begin
  known === nothing && return false
  (length(known.triangles) == length(tris) && length(known.faces) == length(tris) && all(>=(0), known.faces)) || return false
  for (a, b) in zip(known.triangles, tris), k in 1:3
    (1 <= a[k] <= length(known.points) && 1 <= b[k] <= length(points)) || return false
    p, q = known.points[a[k]], points[b[k]]
    len(p .- q) <= 1e-6 * (1 + len(q)) || return false
  end
  true
end

"""
The colour of each body of the OBJ file at `path` that has a colour of its
own, as red, green and blue from 0 to 1. SolidCraft writes them in a second
file beside it, which the OBJ file names. A body with no colour isn't listed.
"""
colours(path::AbstractString) = begin
  found = Dict{String,Vec3}()
  library, body = "", ""
  uses = Dict{String,String}()
  for line in eachline(path)
    startswith(line, "o ") ? (body = String(strip(line[3:end]))) :
    startswith(line, "usemtl ") ? (uses[body] = String(strip(line[8:end]))) :
    startswith(line, "mtllib ") && (library = String(strip(line[8:end])))
  end
  file = joinpath(dirname(path), library)
  (isempty(library) || !isfile(file)) && return found
  named, name = Dict{String,Vec3}(), ""
  for line in eachline(file)
    if startswith(line, "newmtl ")
      name = String(strip(line[8:end]))
    elseif startswith(line, "Kd ")
      p = split(line)
      length(p) >= 4 && (named[name] = (parse(Float64, p[2]), parse(Float64, p[3]), parse(Float64, p[4])))
    end
  end
  for (body, material) in uses
    haskey(named, material) && (found[body] = named[material])
  end
  found
end

const SAME = 0.99999     # the cosine of the angle under which two ways of facing count as one
const LEVEL = 1 - 1e-9   # and the cosine under which the corners of a triangle face one way, so it's flat

"""
The body `name` from the triangles `tris` of an OBJ file, which name their
corners in `points` and their ways of facing in `normals`. `tags` has the
number of each triangle's face when SolidCraft said them. With none, the
faces are found in the triangles.
"""
Shape(name, all_points, all_normals, tris, norms; tags=nothing) = begin
  # The corners of this body only, numbered from 1
  place = Dict{Int,Int}()
  points = Vec3[]
  own = NTuple{3,Int}[]
  for t in tris
    push!(own, ntuple(k -> get!(() -> (push!(points, all_points[t[k]]); length(points)), place, t[k]), 3))
  end
  across = [unit(cross(points[t[2]] .- points[t[1]], points[t[3]] .- points[t[1]])) for t in own]
  normals = Vec3[]
  for (i, n) in enumerate(norms), k in 1:3
    push!(normals, n[k] == 0 ? across[i] : unit(all_normals[n[k]]))
  end
  # A triangle of a curved face can be so thin that it faces almost as its corners do. But only on a flat face do the three corners face one way.
  flat = [dot(normals[3i-2], normals[3i-1]) > LEVEL && dot(normals[3i-2], normals[3i]) > LEVEL && dot(normals[3i-2], across[i]) > 0.999 for i in eachindex(own)]
  # The triangles on each side of every side of a triangle
  sides = Dict{NTuple{2,Int},Vector{NTuple{2,Int}}}()   # the two corners → (triangle, which corner the side starts at)
  for (i, t) in enumerate(own), k in 1:3
    a, b = t[k], t[mod1(k + 1, 3)]
    push!(get!(() -> NTuple{2,Int}[], sides, minmax(a, b)), (i, k))
  end
  facing(i, corner) = normals[3i-3+findfirst(==(corner), own[i])]
  joined(key, x, y) = flat[x[1]] == flat[y[1]] &&
    dot(facing(x[1], key[1]), facing(y[1], key[1])) > SAME && dot(facing(x[1], key[2]), facing(y[1], key[2])) > SAME
  face = zeros(Int, length(own))
  flats = Bool[]
  if tags !== nothing
    # SolidCraft's own faces, numbered from 1 in the order they're first met. A face is flat when each of its triangles is.
    numbers = Dict{Int,Int}()
    for (i, t) in enumerate(tags)
      face[i] = get!(() -> (push!(flats, true); length(flats)), numbers, t)
      flat[i] || (flats[face[i]] = false)
    end
  else
    # Faces: the triangles that are joined across their sides
    near = [Int[] for _ in own]
    for (key, users) in sides
      length(users) == 2 && joined(key, users[1], users[2]) && (push!(near[users[1][1]], users[2][1]); push!(near[users[2][1]], users[1][1]))
    end
    faces = 0
    for i in eachindex(own)
      face[i] == 0 || continue
      faces += 1
      push!(flats, flat[i])
      face[i] = faces
      todo = [i]
      while !isempty(todo)
        for j in near[pop!(todo)]
          face[j] == 0 && (face[j] = faces; push!(todo, j))
        end
      end
    end
  end
  low = isempty(points) ? (0.0, 0.0, 0.0) : reduce((a, b) -> min.(a, b), points)
  high = isempty(points) ? (0.0, 0.0, 0.0) : reduce((a, b) -> max.(a, b), points)
  Shape(name, points, normals, own, face, flats, edges(points, sides, face), low, high)
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
at(e::Eye, size, p::Vec3) = begin
  right, up, back = axes(e)
  d = p .- e.target
  x, y, depth = dot(d, right), dot(d, up), e.distance - dot(d, back)
  k = e.wide > 0 ? (size[2] / 2) / (tand(e.wide / 2) * max(depth, 1e-9)) : scale(e, size)
  (size[1] / 2 + x * k, size[2] / 2 - y * k, depth)
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
  was = at(e, size, about)
  new = Eye(e.target, e.turn, e.tilt, clamp(e.distance / by, 1e-3, 1e7), e.wide)
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
  limit = front === nothing ? Inf : at(e, size, front.point)[3] * 1.002 + 1e-6
  for (n, s) in enumerate(shapes)
    shown(s) || continue
    for (k, edge) in enumerate(s.edges)
      for i in 1:length(edge.points)-1
        a, b = at(e, size, edge.points[i]), at(e, size, edge.points[i+1])
        (a[3] <= 0 || b[3] <= 0) && continue
        d, t = off(px, a, b)
        d < best || continue
        # Far things look smaller, so halfway along the line as it shows isn't halfway along the edge.
        # The point of the edge is the one nearest the line of sight.
        p = closest(edge.points[i], edge.points[i+1], sight)
        # An edge at the back of a body is hidden by the face in front of it
        at(e, size, p)[3] <= limit || continue
        best, found = d, (n, k, p)
      end
    end
  end
  found
end
