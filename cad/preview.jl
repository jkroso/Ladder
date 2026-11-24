# What a command of a SolidCraft design would make, worked out by Ladder while
# the command's form is open, from what the form holds. pieces.jl makes the
# solids. The editor shows them over the design at once, where SolidCraft's
# program would take as long as it takes to build the design again: see
# `Designs.try!`, which the editor still uses for the commands that aren't here.
#
#     m = made("solid.extrude", params, readings, picks, bodies, sketches)
#     m.shapes          # the pieces
#     m.tints           # :add for what's added, :cut for what's taken away, :around for a wall that shows through
#     m.ghost           # the bodies that show faintly, so that a piece in them shows
#
# Every piece is the piece alone. A cut doesn't show as a hole in the body,
# but as the solid that the hole takes away, in red, in a body that shows
# through.

@use "./pieces" => Pieces
@use "./pieces" PIECE
@use "./scene" Vec3 Shape unit dot cross len
@use "./sketch" => Sketching
@use "./sketch" Spot

"What a command makes, as the editor shows it before OK"
struct Made
  shapes::Vector{Shape}               # the pieces
  tints::Dict{String,Symbol}          # each piece's tint, by its name: :add, :cut, or :around for a wall that shows what's in it
  ghost::Vector{String}               # bodies that show faintly, so that the pieces in them show
  hide::Vector{String}                # bodies that don't show: pieces show in their place
  lines::Vector{Float32}              # lines that show, like where a plane cuts a body: 6 numbers for each
  faces::Vector{Tuple{String,Int}}    # faces of bodies that show red: the command takes them away
end

Made(shapes::Vector{Shape}, tint::Symbol; ghost=String[], hide=String[], lines=Float32[], faces=Tuple{String,Int}[]) =
  Made(shapes, Dict{String,Symbol}(s.name => tint for s in shapes), ghost, hide, lines, faces)

"Each command that Ladder makes itself, and the function that makes it from what its form holds"
const MAKERS = Dict{String,Function}()

"""
What the command `command` would make with the parameters `params`, or nothing
when Ladder doesn't make it itself. `readings` has the numbers that the fields
of code came to, by their key, and `picks` what was clicked for each field:
each pick has its `kind`, what it's `of`, its number `n` and the place `at`
it was clicked. `bodies` are the bodies that show, and `sketches` the sketches
that show, by their number. `arrangement(sketch)` gives a sketch's closed
regions: the editor keeps them.
"""
made(command, params, readings, picks, bodies, sketches; arrangement=Pieces.Arrangement) = begin
  f = get(MAKERS, command, nothing)
  f === nothing && return nothing
  f((; command, params, readings, picks, bodies, sketches, arrangement))
end

# --- reading what the form holds -----------------------------------------------------

"""
The number that the field `key` came to: mm for a length, radians for an
angle. A field that isn't code, or wasn't filled in, gives `default`.
"""
number(c, key, default=nothing) = begin
  r = get(c.readings, key, nothing)
  r !== nothing && r.number !== nothing && return Float64(r.number)
  v = get(c.params, key, nothing)
  v isa Real && !(v isa Bool) && return Float64(v)
  v isa AbstractString || return default
  m = match(r"^\s*(-?[0-9]*\.?[0-9]+(?:e-?[0-9]+)?)\s*(mm|deg|°)?\s*$", v)
  m === nothing && return default
  x = parse(Float64, m[1])
  m[2] in ("deg", "°") ? deg2rad(x) : x
end

"Three numbers that the field `key` holds, or `default`"
triple(c, key, default=nothing) = begin
  v = get(c.params, key, nothing)
  (v isa AbstractVector && length(v) == 3 && all(x -> x isa Real, v)) ? (Float64(v[1]), Float64(v[2]), Float64(v[3])) : default
end

"The way that an axis is named in a form: X, Y or Z, or three numbers. Nothing for any other."
way(axis) =
  axis == "X" ? (1.0, 0.0, 0.0) : axis == "Y" ? (0.0, 1.0, 0.0) : axis == "Z" ? (0.0, 0.0, 1.0) :
  axis isa AbstractVector && length(axis) == 3 && all(x -> x isa Real, axis) && any(!iszero, axis) ? unit((Float64(axis[1]), Float64(axis[2]), Float64(axis[3]))) : nothing

"The way that a plane of the origin faces: XY, XZ or YZ. Nothing for any other plane."
facing(plane) = plane == "XY" ? (0.0, 0.0, 1.0) : plane == "XZ" ? (0.0, 1.0, 0.0) : plane == "YZ" ? (1.0, 0.0, 0.0) : nothing

const ZERO = (0.0, 0.0, 0.0)

"The body named `name` that shows, or nothing"
body(c, name) = (i = findfirst(s -> s.name == name, c.bodies); i === nothing ? nothing : c.bodies[i])

"The bodies that the field `key` names"
named(c, key) = begin
  v = get(c.params, key, nothing)
  names = v isa AbstractVector ? v : v === nothing ? Any[] : Any[v]
  Shape[s for s in (body(c, string(n)) for n in names) if s !== nothing]
end

"What was clicked for the field `key`"
picked(c, key) = get(c.picks, key, Any[])

"Are all the parameters that the form gives ones that `known` has? A command that's been given more is left to SolidCraft."
takes(c, known) = all(k -> k in known, keys(c.params))

"A name for the `i`th piece"
piece(i) = PIECE * string(i)

"How far the bodies go in front of the plane `f`, and behind it, with a little more"
reach(bodies, f::Sketching.Frame) = begin
  n = Sketching.normal(f)
  ahead, behind = -Inf, -Inf
  for s in bodies, x in (s.low[1], s.high[1]), y in (s.low[2], s.high[2]), z in (s.low[3], s.high[3])
    h = dot((x, y, z) .- f.origin, n)
    ahead, behind = max(ahead, h), max(behind, -h)
  end
  isfinite(ahead) || return (0.0, 0.0)
  more = 0.01 * max(ahead + behind, 1.0)
  (ahead + more, behind + more)
end

"""
How a piece of an extrude, a revolve or a shape of its own joins the bodies,
as the field `operation` says: it's added, or cut where it's Cut, or Auto and
the point `probe` of it is in a body. A piece that cuts or intersects shows in
the bodies that it touches, which show faintly.
"""
joined(c, pieces, probe) = begin
  op = replace(lowercase(string(get(c.params, "operation", "new"))), r"[ _-]" => "")
  op in ("subtract", "difference") && (op = "cut")
  op == "intersection" && (op = "intersect")
  cut = op == "cut" || (op == "auto" && probe !== nothing && any(s -> Pieces.inside(s, probe), c.bodies))
  ghost = cut || op == "intersect" ? touched(c, pieces) : String[]
  Made(pieces, cut ? :cut : :add; ghost)
end

"The bodies that a cut or an intersect of `pieces` works on: the ones that the form names, or else the ones that they touch"
touched(c, pieces) = begin
  named_ = named(c, "targets")
  isempty(named_) || return String[s.name for s in named_]
  String[s.name for s in c.bodies if any(p -> Pieces.overlaps(s, p), pieces)]
end

# --- extrude and revolve ---------------------------------------------------------------

"""
What's swept for the profiles `shown`: regions of a sketch, or flat faces of a
body. Its plane and its `Profile`, or nothing.
"""
profile_of(c, shown) = begin
  isempty(shown) && return nothing
  p = shown[1]
  if p.kind == :region
    s = get(c.sketches, p.n, nothing)
    s === nothing && return nothing
    a = c.arrangement(s)
    regions = [Pieces.region(a, (q.at[1], q.at[2])) for q in shown if q.kind == :region && q.n == p.n]
    any(isnothing, regions) && return nothing
    frame, profile = Sketching.Frame(s["plane"]), Pieces.profile(a, regions)
  elseif p.kind == :face
    b = body(c, p.of)
    b === nothing && return nothing
    frame = Pieces.face_frame(b, p.n)
    frame === nothing && return nothing
    profile = Pieces.profile(b, Int[q.n for q in shown if q.kind == :face && q.of == p.of], frame)
  else
    return nothing
  end
  isempty(profile.triangles) ? nothing : (frame, profile)
end

"A place inside the profile `p`, on its plane `f`"
within(f, p) = (t = p.triangles[1]; Sketching.world(f, (t[1] .+ t[2] .+ t[3]) ./ 3))

const EXTRUDE = ("sketch", "profiles", "faces", "face_body", "targets", "direction", "distance", "through_all", "operation", "taper", "exact_regions")

MAKERS["solid.extrude"] = c -> begin
  takes(c, EXTRUDE) || return nothing
  got = profile_of(c, picked(c, "profiles"))
  got === nothing && return nothing
  f, p = got
  way_ = lowercase(string(get(c.params, "direction", "positive")))
  back, both = way_ in ("negative", "reverse", "flip"), way_ == "symmetric"
  # SolidCraft can't taper a symmetric extrude: its trial says so
  both && number(c, "taper", 0.0) != 0 && return nothing
  if get(c.params, "through_all", false) === true
    ahead, behind = reach(c.bodies, f)
    low, high = both ? (-behind, ahead) : back ? (-behind, 0.0) : (0.0, ahead)
  else
    d = number(c, "distance")
    d === nothing && return nothing
    low, high = both ? (-abs(d) / 2, abs(d) / 2) : back ? (-d, 0.0) : (0.0, d)
  end
  low, high = minmax(low, high)
  high - low < 1e-9 && return nothing
  shape = Pieces.extrude(piece(1), f, p, low, high; taper=number(c, "taper", 0.0))
  joined(c, [shape], within(f, p) .+ Sketching.normal(f) .* ((low + high) / 2))
end

const REVOLVE = ("sketch", "profiles", "face", "face_body", "targets", "axis", "direction", "symmetric", "angle", "operation", "exact_regions")

MAKERS["solid.revolve"] = c -> begin
  takes(c, REVOLVE) || return nothing
  shown = picked(c, "profiles")
  got = profile_of(c, shown)
  got === nothing && return nothing
  f, p = got
  axis = get(c.params, "axis", "x")
  # A face has no x and y of its own as a sketch has
  axis in ("x", "y") && shown[1].kind != :region && return nothing
  o, w = axis == "x" ? (f.origin, f.x) : axis == "y" ? (f.origin, f.y) : (ZERO, way(axis))
  w === nothing && return nothing
  turn = number(c, "angle", 2π)
  (turn === nothing || turn <= 0) && return nothing
  both = get(c.params, "direction", nothing) == "symmetric" || get(c.params, "symmetric", false) === true
  a1, a2 = both ? (-turn / 2, turn / 2) : (0.0, min(turn, 2π))
  # SolidCraft turns the profile towards the side of its plane that the plane faces
  w = unit(w)
  dot(cross(w, within(f, p) .- o), Sketching.normal(f)) < 0 && ((a1, a2) = (-a2, -a1))
  shape = Pieces.revolve(piece(1), f, p, o, w, a1, a2)
  joined(c, [shape], Pieces.turned(within(f, p), o, unit(w), (a1 + a2) / 2))
end

# --- a hole -------------------------------------------------------------------------

"The way that the face `n` of the body `s` faces at the point `at` of it: the way of its triangle nearest the point"
face_way(s::Shape, n, at) = begin
  best, way_ = Inf, nothing
  for (i, t) in enumerate(s.triangles)
    s.face[i] == n || continue
    middle = (s.points[t[1]] .+ s.points[t[2]] .+ s.points[t[3]]) ./ 3
    d = len(middle .- at)
    d < best && ((best, way_) = (d, s.normals[3i-2]))
  end
  way_
end

const HOLE = ("position", "through_all", "type", "depth", "diameter", "tip_angle", "cb_diameter", "cb_depth", "cs_diameter", "cs_angle")

MAKERS["solid.hole"] = c -> begin
  takes(c, HOLE) || return nothing
  shown = picked(c, "position")
  (isempty(shown) || shown[1].kind != :face) && return nothing
  p = shown[1]
  b = body(c, p.of)
  b === nothing && return nothing
  out = face_way(b, p.n, p.at)
  out === nothing && return nothing
  at, w = Vec3(p.at), out .* -1.0
  r = number(c, "diameter")
  (r === nothing || r <= 0) && return nothing
  r /= 2
  through = get(c.params, "through_all", false) === true
  depth = through ? reach(c.bodies, Pieces.plane(at, w))[1] : number(c, "depth")
  (depth === nothing || depth <= 0) && return nothing
  # A hole ends flat, unless it's given the angle of a drill's point: the point goes on past the depth
  tip = number(c, "tip_angle", Float64(π))
  point = through || tip <= 0 || tip >= π ? 0.0 : r / tan(tip / 2)
  kind = string(get(c.params, "type", "simple"))
  ring = if kind == "counterbore"
    d, h = number(c, "cb_diameter"), number(c, "cb_depth")
    (d === nothing || h === nothing || d / 2 <= r || h >= depth) && return nothing
    Spot[(0.0, 0.0), (d / 2, 0.0), (d / 2, h), (r, h), (r, depth), (0.0, depth + point)]
  elseif kind == "countersink"
    d, a = number(c, "cs_diameter"), number(c, "cs_angle", deg2rad(90))
    (d === nothing || d / 2 <= r || a <= 0 || a >= π) && return nothing
    sink = (d / 2 - r) / tan(a / 2)
    sink >= depth && return nothing
    Spot[(0.0, 0.0), (d / 2, 0.0), (r, sink), (r, depth), (0.0, depth + point)]
  else
    Spot[(0.0, 0.0), (r, 0.0), (r, depth), (0.0, depth + point)]
  end
  shape = Pieces.revolve(piece(1), Pieces.upright(at, w), Pieces.polygon(ring), at, w, 0.0, 2π)
  Made([shape], :cut; ghost=touched(c, [shape]))
end

# --- shapes of their own --------------------------------------------------------------

const SHAPES = ("length", "width", "height", "center", "diameter", "base", "axis", "major", "minor", "top_diameter", "operation", "name", "body_name")

MAKERS["solid.box"] = c -> begin
  takes(c, SHAPES) || return nothing
  l, w, h, at = number(c, "length"), number(c, "width"), number(c, "height"), triple(c, "center", ZERO)
  any(x -> x === nothing || x <= 0, (l, w, h)) && return nothing
  joined(c, [Pieces.box(piece(1), at, (l, w, h))], nothing)
end

MAKERS["solid.cylinder"] = c -> begin
  takes(c, SHAPES) || return nothing
  d, h, w = number(c, "diameter"), number(c, "height"), way(get(c.params, "axis", "Z"))
  (d === nothing || h === nothing || d <= 0 || h <= 0 || w === nothing) && return nothing
  joined(c, [Pieces.cylinder(piece(1), triple(c, "base", ZERO), w, d, h)], nothing)
end

MAKERS["solid.cone"] = c -> begin
  takes(c, SHAPES) || return nothing
  d, top, h, w = number(c, "diameter"), number(c, "top_diameter", 0.0), number(c, "height"), way(get(c.params, "axis", "Z"))
  (d === nothing || h === nothing || d <= 0 || h <= 0 || top < 0 || w === nothing) && return nothing
  joined(c, [Pieces.cone(piece(1), triple(c, "base", ZERO), w, d, top, h)], nothing)
end

MAKERS["solid.sphere"] = c -> begin
  takes(c, SHAPES) || return nothing
  d = number(c, "diameter")
  (d === nothing || d <= 0) && return nothing
  joined(c, [Pieces.sphere(piece(1), triple(c, "center", ZERO), d)], nothing)
end

MAKERS["solid.torus"] = c -> begin
  takes(c, SHAPES) || return nothing
  big, small = number(c, "major"), number(c, "minor")
  (big === nothing || small === nothing || small <= 0 || big <= small) && return nothing
  joined(c, [Pieces.torus(piece(1), triple(c, "center", ZERO), (0.0, 0.0, 1.0), big, small)], nothing)
end

# --- bodies moved and copied ----------------------------------------------------------

"Copies of the bodies that the field `bodies` names, each moved by `move(body, name)`: what Mirror and the patterns add"
copies(c, move; key="bodies") = begin
  out = Shape[]
  for s in named(c, key)
    for m in move(s)
      push!(out, m(piece(length(out) + 1)))
    end
  end
  out
end

MAKERS["solid.mirror"] = c -> begin
  takes(c, ("bodies", "plane", "combine")) || return nothing
  n = facing(get(c.params, "plane", "YZ"))
  n === nothing && return nothing
  made = copies(c, s -> [name -> Pieces.mirrored(s, name, ZERO, n)])
  isempty(made) ? nothing : Made(made, :add)
end

MAKERS["solid.pattern.rectangular"] = c -> begin
  takes(c, ("bodies", "dir1", "count1", "spacing1", "dir2", "count2", "spacing2")) || return nothing
  w1, n1, s1 = way(get(c.params, "dir1", [1, 0, 0])), number(c, "count1"), number(c, "spacing1")
  (w1 === nothing || n1 === nothing || s1 === nothing || n1 < 1) && return nothing
  w2 = way(get(c.params, "dir2", nothing))
  n2, s2 = w2 === nothing ? (1.0, 0.0) : (number(c, "count2", 1.0), number(c, "spacing2", 0.0))
  (n2 === nothing || s2 === nothing) && return nothing
  steps = [w1 .* (s1 * i) .+ (w2 === nothing ? ZERO : w2 .* (s2 * j)) for i in 0:round(Int, n1)-1, j in 0:round(Int, n2)-1 if i + j > 0]
  length(steps) > 400 && return nothing
  made = copies(c, s -> [name -> Pieces.moved(s, name, p -> p .+ step) for step in steps])
  isempty(made) ? nothing : Made(made, :add)
end

MAKERS["solid.pattern.circular"] = c -> begin
  takes(c, ("bodies", "axis", "count", "angle")) || return nothing
  w, n, turn = way(get(c.params, "axis", "Z")), number(c, "count"), number(c, "angle", 2π)
  (w === nothing || n === nothing || turn === nothing || n < 2 || n > 400) && return nothing
  n = round(Int, n)
  # A whole turn has its copies all the way round. A part of one has the last copy at its end.
  step = turn >= 2π - 1e-9 ? 2π / n : turn / (n - 1)
  made = copies(c, s -> [name -> Pieces.turned(s, name, ZERO, w, step * k) for k in 1:n-1])
  isempty(made) ? nothing : Made(made, :add)
end

MAKERS["solid.move"] = c -> begin
  takes(c, ("bodies", "translate", "angle", "axis", "copy")) || return nothing
  by = triple(c, "translate", ZERO)
  turn = number(c, "angle", 0.0)
  w = way(get(c.params, "axis", [0, 0, 1]))
  (turn === nothing || w === nothing) && return nothing
  (all(iszero, by) && turn == 0) && return nothing
  # SolidCraft turns a body round the axis through the design's origin, then moves it
  made = copies(c, s -> [name -> Pieces.moved(Pieces.turned(s, name, ZERO, w, turn), name, p -> p .+ by)])
  isempty(made) && return nothing
  # A move shows where the bodies were faintly. A copy leaves them as they are.
  Made(made, :add; ghost=get(c.params, "copy", false) === true ? String[] : String[s.name for s in named(c, "bodies")])
end

MAKERS["solid.scale"] = c -> begin
  takes(c, ("bodies", "factor")) || return nothing
  k = number(c, "factor")
  (k === nothing || k <= 0 || k == 1) && return nothing
  # SolidCraft scales round the design's origin
  made = copies(c, s -> [name -> Pieces.scaled(s, name, ZERO, k)])
  isempty(made) ? nothing : Made(made, :add; ghost=String[s.name for s in named(c, "bodies")])
end

MAKERS["solid.combine"] = c -> begin
  takes(c, ("target", "tools", "operation", "keep_tools")) || return nothing
  tools = named(c, "tools")
  isempty(tools) && return nothing
  op = string(get(c.params, "operation", "join"))
  made = Shape[Pieces.moved(s, piece(i), identity) for (i, s) in enumerate(tools)]
  # The tools show tinted in their own place, over the target
  Made(made, op == "cut" ? :cut : :add; hide=String[s.name for s in tools], ghost=op == "join" ? String[] : String[s.name for s in named(c, "target")])
end

MAKERS["solid.remove"] = c -> begin
  takes(c, ("bodies",)) || return nothing
  gone = named(c, "bodies")
  isempty(gone) && return nothing
  Made(Shape[Pieces.moved(s, piece(i), identity) for (i, s) in enumerate(gone)], :cut; hide=String[s.name for s in gone])
end

MAKERS["solid.split_body"] = c -> begin
  takes(c, ("body", "plane")) || return nothing
  n = facing(get(c.params, "plane", "XY"))
  cut = named(c, "body")
  (n === nothing || isempty(cut)) && return nothing
  lines = reduce(vcat, [Pieces.section(s, ZERO, n) for s in cut])
  isempty(lines) ? nothing : Made(Shape[], :add; lines)
end

# --- faces moved ----------------------------------------------------------------------

"The faces clicked for the field `key`, by body: each body's name, the body, and the numbers of its faces"
faces_by_body(c, key) = begin
  out = Tuple{String,Shape,Vector{Int}}[]
  for p in picked(c, key)
    p.kind == :face || continue
    i = findfirst(x -> x[1] == p.of, out)
    if i === nothing
      b = body(c, p.of)
      b === nothing && continue
      push!(out, (p.of, b, Int[]))
      i = length(out)
    end
    push!(out[i][3], p.n)
  end
  out
end

"What moving the faces of the field `key` by `d` mm adds, or takes away when `d` is under 0"
faces_moved(c, key, d) = begin
  (d === nothing || d == 0) && return nothing
  made = Shape[Pieces.offset(piece(i), b, faces, d) for (i, (_, b, faces)) in enumerate(faces_by_body(c, key))]
  isempty(made) && return nothing
  Made(made, d > 0 ? :add : :cut; ghost=d > 0 ? String[] : String[s.name for s in made_from(c, key)])
end

made_from(c, key) = Shape[b for (_, b, _) in faces_by_body(c, key)]

MAKERS["solid.press_pull"] = c -> takes(c, ("face", "distance")) ? faces_moved(c, "face", number(c, "distance")) : nothing
MAKERS["solid.offset_face"] = c -> takes(c, ("faces", "distance")) ? faces_moved(c, "faces", number(c, "distance")) : nothing

MAKERS["face.delete"] = c -> begin
  takes(c, ("faces",)) || return nothing
  gone = Tuple{String,Int}[(p.of, p.n) for p in picked(c, "faces") if p.kind == :face]
  isempty(gone) ? nothing : Made(Shape[], :cut; faces=gone)
end

MAKERS["solid.shell"] = c -> begin
  takes(c, ("faces", "thickness", "direction", "tangent_chain")) || return nothing
  t = number(c, "thickness")
  (t === nothing || t <= 0) && return nothing
  way_ = string(get(c.params, "direction", "inside"))
  made, tints, hide, ghost = Shape[], Dict{String,Symbol}(), String[], String[]
  add!(s, tint) = (push!(made, s); tints[s.name] = tint)
  # A face that's clicked is left open. A body that's clicked has none open.
  shown = picked(c, "faces")
  for name in unique(String[string(p.of) for p in shown])
    b = body(c, name)
    b === nothing && continue
    open = Int[p.n for p in shown if p.kind == :face && p.of == name]
    if way_ == "inside"
      add!(Pieces.hollow(piece(length(made) + 1), b, open, t), :cut)
      push!(ghost, name)
    else
      out, in = way_ == "outside" ? (t, 0.0) : (t / 2, t / 2)
      add!(Pieces.hollow(piece(length(made) + 1), b, open, -out), :around)
      add!(in == 0 ? Pieces.moved(b, piece(length(made) + 1), identity) : Pieces.hollow(piece(length(made) + 1), b, open, in), :cut)
      push!(hide, name)
    end
  end
  isempty(made) ? nothing : Made(made, tints, ghost, hide, Float32[], Tuple{String,Int}[])
end

MAKERS["solid.draft"] = c -> begin
  takes(c, ("faces", "angle", "neutral")) || return nothing
  a, n = number(c, "angle"), facing(get(c.params, "neutral", "XY"))
  (a === nothing || a == 0 || n === nothing) && return nothing
  made, tints = Shape[], Dict{String,Symbol}()
  for (i, (_, b, faces)) in enumerate(faces_by_body(c, "faces"))
    shape, out = Pieces.drafted(piece(i), b, faces, ZERO, n, a)
    isempty(shape.triangles) && continue
    push!(made, shape)
    tints[shape.name] = out < 0 ? :cut : :add
  end
  isempty(made) ? nothing : Made(made, tints, String[s.name for s in made_from(c, "faces")], String[], Float32[], Tuple{String,Int}[])
end

# --- edges rounded and cut off --------------------------------------------------------

"""
The pieces of a fillet or a chamfer on the edges that were clicked, and the
edges that go on smoothly from them where Tangent Chain is ticked. `how`
gives the keywords of `Pieces.edge_piece`.
"""
on_edges(c, how) = begin
  made, tints, ghost = Shape[], Dict{String,Symbol}(), String[]
  shown = Any[p for p in picked(c, "edges") if p.kind == :edge]
  for name in unique(String[string(p.of) for p in shown])
    b = body(c, name)
    b === nothing && continue
    edges = Int[p.n for p in shown if p.of == name && 1 <= p.n <= length(b.edges)]
    get(c.params, "tangent_chain", true) === true && (edges = Pieces.chained(b, edges))
    around = Pieces.corners_of(b)
    for n in edges
      got = Pieces.edge_piece(piece(length(made) + 1), b, n; around, how...)
      got === nothing && continue
      shape, sticks_out = got
      push!(made, shape)
      tints[shape.name] = sticks_out ? :cut : :add
      sticks_out && !(name in ghost) && push!(ghost, name)
    end
  end
  isempty(made) ? nothing : Made(made, tints, ghost, String[], Float32[], Tuple{String,Int}[])
end

MAKERS["solid.fillet"] = c -> begin
  takes(c, ("edges", "radius", "type", "tangent_chain")) || return nothing
  string(get(c.params, "type", "constant")) == "constant" || return nothing
  r = number(c, "radius")
  (r === nothing || r <= 0) ? nothing : on_edges(c, (; r))
end

MAKERS["solid.chamfer"] = c -> begin
  takes(c, ("edges", "distance", "distance2", "tangent_chain")) || return nothing
  d = number(c, "distance")
  (d === nothing || d <= 0) && return nothing
  d2 = number(c, "distance2", d)
  (d2 === nothing || d2 <= 0) ? nothing : on_edges(c, (; chamfer=(d, d2)))
end
