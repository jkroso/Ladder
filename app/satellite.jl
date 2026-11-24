# Builds pages/satellite.glb: one satellite of the fleet on the page "Data
# centres in space", as a 3D model with materials.
#
#     julia --project=. app/satellite.jl
#
# The satellite is the one that pages/satellite.html draws, at the page's first
# numbers, with more of its parts worked out: seams and tape on the foil, wings
# in bays, yokes for the drums, sleeves where the loops of tube join, the
# coolant's pipes, baffles on the star trackers. A .glb file is fixed, so change
# the numbers under "the sizes" and run this again when the page's sums change.
#
# The file also has what's round the satellite: the Sun as a light, and a
# picture of the whole sky with the Earth in it, 1000 km below. Ladder's viewer
# shows the sky behind the model and lights the model with it.
#
# Lengths are in metres. The satellite is built with y up, its wings along x and
# its cells facing z. Then it's tipped back to face the Sun, which is off to one
# side of the orbit and a little above level.
@use Skia

const Vec = NTuple{3,Float64}
const UV = NTuple{2,Float64}

# --- the sizes -----------------------------------------------------------------

const span, array_area, nsat = 70.0, 3406586.0, 6667     # m across the wings, m² of cells in the fleet, satellites
const rad_use, loop_d, loop_out = 14.0, 0.03, 0.3       # % of the cells' area that the radiator has, m across a loop's tube, how far a loop passes in front of the middle for each metre of half the span
const sat_kg, lens = 2180.0, 0.02                        # kg of one satellite, m across the laser's lens

const area = array_area / nsat                           # m² of cells on one satellite
const body = clamp(cbrt(sat_kg / 450), 0.8, 4)           # m, a side of the body, at 450 kg a cubic metre
const reach = max(1, (span - body) / 2 - 0.6)            # m, how far each wing reaches past its drum
const chord = area / 2reach                              # m, how tall each wing is
const loop_r = loop_d / 2                                # m, the radius of a loop's tube
const tip = body / 2 + 0.6 + reach                       # m from the middle to the tip of each wing
const deep = max(loop_out * tip, body / 2 + 1.4)         # m from the middle to the front of each loop, and to its back
const rad_area = array_area * rad_use / 100 / nsat       # m² of the radiator
const rad_long = deep - body / 2 - 0.4                   # m: the radiator stands up behind the body, and reaches back to the loops
const rad_high = rad_area / rad_long
const CELL = 0.125                                       # m, one cell

# In a dawn-dusk orbit the Sun is off to one side, and up to about 25° above level. The orbit runs along the
# line between day and night.
const SUN = (0.0, 0.42, 1.0) ./ sqrt(1 + 0.42^2)         # the way to the Sun, where y is straight up from the Earth
const TIP = -asin(SUN[2])                                # radians that the satellite turns about x to face it
const alt, R_EARTH = 1.0e6, 6.378e6                      # m above the ground, and m from the Earth's middle to the ground

# --- shapes --------------------------------------------------------------------

"""
A surface as triangles: where each corner is, the way the surface faces there,
where the corner is in the material's pictures, and which three corners make
each triangle. `tint` has a colour for each corner, or it's empty.
"""
struct Shape
  at::Vector{Vec}
  facing::Vector{Vec}
  place::Vector{UV}
  corners::Vector{Int}
  tint::Vector{Vec}
end

Shape(at, facing, place, corners) = Shape(at, facing, place, corners, Vec[])

dot(a, b) = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
cross(a, b) = (a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])
unit(a) = a ./ sqrt(dot(a, a))

"Several shapes as one"
joined(shapes::Shape...) = begin
  out = Shape(Vec[], Vec[], UV[], Int[], Vec[])
  tinted = any(s -> !isempty(s.tint), shapes)
  for s in shapes
    append!(out.corners, s.corners .+ length(out.at))
    append!(out.at, s.at); append!(out.facing, s.facing); append!(out.place, s.place)
    tinted && append!(out.tint, isempty(s.tint) ? fill((1.0, 1.0, 1.0), length(s.at)) : s.tint)
  end
  out
end

moved(s::Shape, by) = Shape([p .+ by for p in s.at], s.facing, s.place, s.corners, s.tint)

"Turned by `degrees` round the axis :x, :y or :z, the way a right hand's fingers curl when its thumb points along the axis"
turned(s::Shape, axis, degrees) = begin
  sn, c = sincosd(degrees)
  turn(p) = axis == :x ? (p[1], c * p[2] - sn * p[3], sn * p[2] + c * p[3]) :
            axis == :y ? (c * p[1] + sn * p[3], p[2], c * p[3] - sn * p[1]) :
                         (c * p[1] - sn * p[2], sn * p[1] + c * p[2], p[3])
  Shape(turn.(s.at), turn.(s.facing), s.place, s.corners, s.tint)
end

"With its picture `across` times across it and `down` times down it"
tiled(s::Shape, across, down) = Shape(s.at, s.facing, [(u * across, v * down) for (u, v) in s.place], s.corners, s.tint)
"With every corner at one place in its picture"
pinned(s::Shape, place) = Shape(s.at, s.facing, fill(place, length(s.at)), s.corners, s.tint)
"With the colour `tint` over its material's own"
tinted(s::Shape, tint) = Shape(s.at, s.facing, s.place, s.corners, fill(tint, length(s.at)))

"A flat piece with the corners `points` in order round it, facing `out`. `places` says where each corner is in the picture."
facet(points, out, places) = begin
  # Seen from the side that it faces, a triangle's corners go round against the clock
  order = dot(cross(points[2] .- points[1], points[3] .- points[1]), out) < 0 ? reverse(eachindex(points)) : collect(eachindex(points))
  Shape(Vec[points[i] for i in order], fill(Vec(out), length(points)), UV[places[i] for i in order], [k for i in 2:length(points)-1 for k in (1, i, i + 1)])
end

"A rectangle `w` wide and `h` tall that faces z, with a picture's top left at its top left"
plate(w, h) = facet([(-w / 2, -h / 2, 0.0), (w / 2, -h / 2, 0.0), (w / 2, h / 2, 0.0), (-w / 2, h / 2, 0.0)], (0.0, 0.0, 1.0), [(0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)])

"""
A box `w` wide, `h` tall and `d` deep. Each face has the whole picture. Its
edges are cut off `bevel` wide, as a real edge is never sharp, and so they
catch the light. The cut edges are all at the place `edge` in the picture.
"""
block(w, h, d; bevel=0.0, edge=(0.02, 0.02)) = begin
  b = bevel
  faces = [moved(plate(w - 2b, h - 2b), (0, 0, d / 2)), moved(turned(plate(w - 2b, h - 2b), :y, 180), (0, 0, -d / 2)),
           moved(turned(plate(d - 2b, h - 2b), :y, 90), (w / 2, 0, 0)), moved(turned(plate(d - 2b, h - 2b), :y, -90), (-w / 2, 0, 0)),
           moved(turned(plate(w - 2b, d - 2b), :x, -90), (0, h / 2, 0)), moved(turned(plate(w - 2b, d - 2b), :x, 90), (0, -h / 2, 0))]
  b > 0 || return joined(faces...)
  half = (w / 2, h / 2, d / 2)
  # A corner of the box, with the two axes in `flat` pulled in by the bevel
  corner(signs, flat) = ntuple(k -> signs[k] * (half[k] - (k in flat ? b : 0.0)), 3)
  cuts = Shape[]
  for i in 1:3, j in i+1:3, si in (-1, 1), sj in (-1, 1)
    k = 6 - i - j
    signs(sk) = ntuple(n -> n == i ? si : n == j ? sj : sk, 3)
    out = unit(ntuple(n -> n == i ? Float64(si) : n == j ? Float64(sj) : 0.0, 3))
    push!(cuts, facet([corner(signs(-1), (j, k)), corner(signs(1), (j, k)), corner(signs(1), (i, k)), corner(signs(-1), (i, k))], out, fill(edge, 4)))
  end
  for sx in (-1, 1), sy in (-1, 1), sz in (-1, 1)
    s = (sx, sy, sz)
    push!(cuts, facet([corner(s, (2, 3)), corner(s, (1, 3)), corner(s, (1, 2))], unit(Float64.(s)), fill(edge, 3)))
  end
  joined(faces..., cuts...)
end

"""
A round bar from `a` to `b`, `r` in radius at `a` and `top` at `b`, with `n`
flat sides that are shaded as one curve. `ends` closes it with a disc at each
end.
"""
rod(a, b, r; top=r, n=24, ends=true) = begin
  along = unit(b .- a)
  # Two directions across the bar
  u = unit(cross(along, abs(along[2]) < 0.9 ? (0.0, 1.0, 0.0) : (1.0, 0.0, 0.0)))
  v = cross(along, u)
  len = sqrt(dot(b .- a, b .- a))
  at, facing, place, corners = Vec[], Vec[], UV[], Int[]
  for i in 0:n
    s, c = sincos(2π * i / n)
    out = u .* c .+ v .* s
    push!(at, a .+ out .* r, b .+ out .* top)
    push!(facing, unit(out .* len .+ along .* (r - top)), unit(out .* len .+ along .* (r - top)))
    push!(place, (i / n, 1.0), (i / n, 0.0))
    i < n && append!(corners, (2i + 1, 2i + 2, 2i + 4, 2i + 1, 2i + 4, 2i + 3))
  end
  side = outward(Shape(at, facing, place, corners))
  ends || return side
  disc(middle, radius, out) = facet([middle .+ (u .* cos(2π * i / n) .+ v .* sin(2π * i / n)) .* radius for i in 0:n-1], out,
                                    [(0.5 + 0.5cos(2π * i / n), 0.5 + 0.5sin(2π * i / n)) for i in 0:n-1])
  joined(side, (r > 0 ? (disc(a, r, .-along),) : ())..., (top > 0 ? (disc(b, top, along),) : ())...)
end

"An upright round bar `l` long, with its middle at the origin"
tube(r, l; kw...) = rod((0.0, -l / 2, 0.0), (0.0, l / 2, 0.0), r; kw...)

"A ring that lies flat round the y axis: `R` from the axis to the middle of its bar, which is `r` in radius"
ring(R, r; n=40, m=14) = begin
  at, facing, place, corners = Vec[], Vec[], UV[], Int[]
  for i in 0:n, j in 0:m
    s, c = sincos(2π * i / n)
    t, k = sincos(2π * j / m)
    out = (c * k, t, s * k)
    push!(at, (c * R, 0.0, s * R) .+ out .* r)
    push!(facing, out)
    push!(place, (i / n, j / m))
    i < n && j < m && (p = i * (m + 1) + j + 1; append!(corners, (p, p + 1, p + m + 2, p, p + m + 2, p + m + 1)))
  end
  outward(Shape(at, facing, place, corners))
end

"A tube `r` in radius along the closed line through `points`, which all lie level. It has `n` flat sides that are shaded as one curve."
hoop(points, r; n=8) = begin
  m, up = length(points), (0.0, 1.0, 0.0)
  at, facing, place, corners = Vec[], Vec[], UV[], Int[]
  for i in 0:m
    # The tube goes the way from the point before this one to the point after it
    side = unit(cross(points[mod1(i + 2, m)] .- points[mod1(i, m)], up))
    for j in 0:n
      s, c = sincos(2π * j / n)
      out = side .* c .+ up .* s
      push!(at, points[mod1(i + 1, m)] .+ out .* r)
      push!(facing, out)
      push!(place, (i / m, j / n))
      i < m && j < n && (q = i * (n + 1) + j + 1; append!(corners, (q, q + 1, q + n + 2, q, q + n + 2, q + n + 1)))
    end
  end
  outward(Shape(at, facing, place, corners))
end

"""
A loop of tube in a level plane at the height `y`, right round the satellite.
It's an oval. It passes `wide` to each side of the middle, along x, and `deep`
in front of the middle and behind it, along z.
"""
loop(wide, deep, y, r) = hoop([(wide * cos(2π * i / 192), y, deep * sin(2π * i / 192)) for i in 0:191], r)

"`s` with each triangle's corners in the order that makes it face the way its corners say"
outward(s::Shape) = begin
  corners = copy(s.corners)
  for t in 1:3:length(corners)
    a, b, c = corners[t], corners[t+1], corners[t+2]
    flat = cross(s.at[b] .- s.at[a], s.at[c] .- s.at[a])
    dot(flat, s.facing[a] .+ s.facing[b] .+ s.facing[c]) < 0 && ((corners[t+1], corners[t+2]) = (c, b))
  end
  Shape(s.at, s.facing, s.place, corners, s.tint)
end

# --- pictures ------------------------------------------------------------------
#
# The pictures are made here, a pixel at a time, so that the model needs no
# other files. Each one tiles: its right edge meets its left, and its bottom
# its top.

"""
The bytes of a picture `w` pixels wide and `h` tall, with the red, green and
blue that `colour(x, y)` gives for each pixel, from 0 to 255. It's a PNG, which
keeps every pixel as it is, or a JPEG, which is far smaller for a photograph.
"""
picture_bytes(colour, w, h; jpeg=false) = begin
  byte(x) = round(UInt32, clamp(x, 0, 255))
  pixels = Vector{UInt32}(undef, w * h)
  Threads.@threads for y in 0:h-1
    for x in 0:w-1
      c = colour(x, y)
      pixels[y*w+x+1] = 0xff000000 | byte(c[1]) << 16 | byte(c[2]) << 8 | byte(c[3])
    end
  end
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_BGRA_8888, Skia.SK_ALPHA_TYPE_OPAQUE, w, h))
  GC.@preserve info pixels begin
    data = Skia.sk_data_new_with_copy(pointer(pixels), UInt64(4w * h))
    image = Skia.sk_image_new_raster_data(info, data, Csize_t(4w))
    encoded = jpeg ? Skia.sk_encode_jpeg(C_NULL, image, Int32(88)) : Skia.sk_encode_png(C_NULL, image, Int32(9))
    out = copy(unsafe_wrap(Array, Ptr{UInt8}(Skia.sk_data_get_data(encoded)), Skia.sk_data_get_size(encoded)))
    Skia.sk_data_unref(encoded); Skia.sk_image_unref(image); Skia.sk_data_unref(data)
    out
  end
end

"The PNG bytes of a picture `n` pixels square"
png(colour, n) = picture_bytes(colour, n, n)

"A number from 0 to 1 that looks random, and is the same each time for the same `x` and `y`"
noise(x, y) = (s = sin(x * 127.1 + y * 311.7) * 43758.5453; s - floor(s))

"Soft random hills, from 0 to 1, that repeat every `n` whole steps of `x` and `y`"
hills(x, y, n) = begin
  xi, yi = floor(Int, x), floor(Int, y)
  fx, fy = x - xi, y - yi
  h(i, j) = noise(mod(i, n), mod(j, n))
  u, v = fx * fx * (3 - 2fx), fy * fy * (3 - 2fy)
  (h(xi, yi) * (1 - u) + h(xi + 1, yi) * u) * (1 - v) + (h(xi, yi + 1) * (1 - u) + h(xi + 1, yi + 1) * u) * v
end

"A picture that says which way each point faces, from `height(x, y)`, how far each point of a surface stands out. `steep` makes the slopes steeper."
bumps(height, n, steep) = png(n) do x, y
  dx, dy = height(x + 1, y) - height(x - 1, y), height(x, y + 1) - height(x, y - 1)
  # Red leans right and green leans up the picture
  nx, ny = -dx * steep, dy * steep
  l = sqrt(nx^2 + ny^2 + 1)
  (128 + 127nx / l, 128 + 127ny / l, 128 + 127 / l)
end

const N = 512

# The cells: a tile of 4 by 4, each 12.5 cm. A cell is dark blue glass with its corners cut off. Fine silver fingers
# cross it, and two wider bars collect from them. Pale film shows between the cells.
"0 in a cell's glass, 1 on the film between cells, 2 on a bar and 3 on a finger"
cell_part(x, y) = begin
  cx, cy = mod(x, 128), mod(y, 128)
  from_edge = min(cx, 127 - cx, cy, 127 - cy)
  cut = min(cx, 127 - cx) + min(cy, 127 - cy) < 14
  (from_edge < 2 || cut) ? 1 : (abs(cx - 43) <= 1 || abs(cx - 85) <= 1) ? 2 : cy % 6 == 3 ? 3 : 0
end
const cells_colour = png(N) do x, y
  part, n = cell_part(x, y), 10 * noise(x, y)
  part == 1 ? (196, 190, 172) : part == 2 ? (176, 180, 188) : part == 3 ? (58, 66, 96) : (9 + n, 15 + n, 40 + 1.4n)
end
# Green is how rough, and blue is how much a metal: the glass is smooth, and the bars are silver
const cells_surface = png(N) do x, y
  part = cell_part(x, y)
  part == 1 ? (0, 150, 0) : part == 2 ? (0, 95, 255) : part == 3 ? (0, 70, 120) : (0, 34 + 10 * noise(x + 7, y), 0)
end

# The foil: one blanket covers each face of the body. It's crumpled, so it catches the light in patches. Tape
# holds its edges down and crosses its middle, and the tape pulls the foil flat.
crumple(x, y) = 0.6 * hills(x / 32, y / 32, 16) + 0.3 * hills(x / 16, y / 16, 32) + 0.1 * hills(x / 4, y / 4, 128)
"How much of a point of the blanket is under tape, from 0 to 1"
tape(x, y) = begin
  from_edge = min(x, N - 1 - x, y, N - 1 - y)
  from_cross = min(abs(x - N / 2), abs(y - N / 2))
  clamp(max(1 - (from_edge - 14) / 3, 1 - (from_cross - 7) / 3), 0, 1)
end
"Is the point on one of the buttons that pin a blanket's layers together?"
button(x, y) = (mod(x - 64, 128) - 64)^2 + (mod(y - 64, 128) - 64)^2 < 20
const foil_bumps = bumps((x, y) -> crumple(x, y) * (1 - 0.85 * tape(clamp(x, 0, N - 1), clamp(y, 0, N - 1))) + 0.04 * tape(clamp(x, 0, N - 1), clamp(y, 0, N - 1)), N, 13.0)
const foil_colour = png(N) do x, y
  t, shade = tape(x, y), 235 + 20 * hills(x / 64, y / 64, 8)
  button(x, y) ? (120, 110, 95) : (shade - 70t, shade - 95t, shade - 120t)
end
const foil_surface = png(N) do x, y
  t = tape(x, y)
  button(x, y) ? (0, 140, 80) : (0, 44 + 30 * hills(x / 32, y / 32, 16) + 80t, 255 - 90t)
end

# The radiator's white paint, with a tube under it every 10 cm. The tubes run up it, from its bottom edge to its top.
const tubes = bumps((x, y) -> (d = abs(mod(x, 64) - 32); d < 6 ? 0.35 * sqrt(1 - (d / 6)^2) : 0.0), 64, 4.0)

# --- the sky -------------------------------------------------------------------
#
# The sky is one picture, twice as wide as it's tall. Its top row is straight
# up, its bottom row straight down, and its middle column is the way that -z
# points. Most of it is black. The Earth fills it from 30° under the level of
# the eye down, since the satellite is 1000 km up. The Sun is low over that
# ground: half of what you see is in daylight and half in the night.

fract(x) = x - floor(x)
mix(a, b, t) = a .+ (b .- a) .* t
smoothstep(lo, hi, x) = (t = clamp((x - lo) / (hi - lo), 0.0, 1.0); t * t * (3 - 2t))

"A number from 0 to 1 that looks random, for a point in space with whole coordinates"
speck(p) = begin
  x, y, z = fract(p[1] * 0.3183099 + 0.1) * 17, fract(p[2] * 0.3183099 + 0.1) * 17, fract(p[3] * 0.3183099 + 0.1) * 17
  fract(x * y * z * (x + y + z))
end

"Soft random lumps in space, from 0 to 1"
lumps(p) = begin
  i = floor.(p)
  f = p .- i
  u = f .* f .* (3 .- 2 .* f)
  at(a, b, c) = speck(i .+ (a, b, c))
  mix(mix(mix(at(0, 0, 0), at(1, 0, 0), u[1]), mix(at(0, 1, 0), at(1, 1, 0), u[1]), u[2]),
      mix(mix(at(0, 0, 1), at(1, 0, 1), u[1]), mix(at(0, 1, 1), at(1, 1, 1), u[1]), u[2]), u[3])
end

"Lumps on lumps: big ones with smaller ones on them, six sizes in all, as coasts and clouds have"
rough_lumps(p) = begin
  total, strength = 0.0, 0.5
  for _ in 1:6
    total += strength * lumps(p)
    p = p .* 2.03
    strength /= 2
  end
  total
end

"The colour of the ground at the place `n` on the Earth (the way to it from the Earth's middle), seen from the way `to_eye`"
ground(n, to_eye) = begin
  light = dot(n, SUN)
  land = smoothstep(0.52, 0.56, rough_lumps(n .* 2.2 .+ 3.0))
  desert = smoothstep(0.5, 0.7, rough_lumps(n .* 5.0 .+ 11.0))
  soil = mix((0.02, 0.06, 0.15), mix((0.07, 0.11, 0.04), (0.32, 0.25, 0.14), desert), land)
  cloud = smoothstep(0.42, 0.68, 0.6 * rough_lumps(n .* 6.0 .+ (0.0, 4.0, 0.0)) + 0.27 * rough_lumps(n .* 40.0) + 0.13 * rough_lumps(n .* 160.0))
  day = mix(soil, (0.95, 0.95, 0.95), cloud) .* (max(light, 0.0) * 2.6) .+ (0.04, 0.09, 0.22) .* max(light, 0.0)
  # Sunlight that glints off the sea
  glint = light > 0 ? (1 - land) * (1 - cloud) * max(dot(n, unit(SUN .+ to_eye)), 0.0)^120 * 3 : 0.0
  # The lights of towns, on the night side
  towns = land * smoothstep(0.62, 0.8, rough_lumps(n .* 90.0)) * (1 - 0.8cloud)
  night = (1.0, 0.62, 0.25) .* (towns * 0.25 * smoothstep(0.05, -0.15, light))
  # The air: blue at the edge, and red where the day ends
  rim = (1 - max(dot(n, to_eye), 0.0))^4
  air = mix((0.25, 0.45, 1.0), (1.0, 0.45, 0.2), 0.3 * smoothstep(0.2, 0.0, abs(light))) .* (rim * smoothstep(-0.25, 0.25, light) * 1.6)
  day .+ glint .+ night .+ air
end

"The light that comes from the way `d`, seen from the satellite: the ground, the thin blue line of the air at the Earth's edge, or black space"
sky_light(d) = begin
  middle = (0.0, -(R_EARTH + alt), 0.0)   # of the Earth, from the satellite
  along = dot(d, middle)
  along > 0 || return (0.0, 0.0, 0.0)
  nearest = sqrt(max(0.0, dot(middle, middle) - along^2))   # how near the ray comes to the Earth's middle
  if nearest < R_EARTH
    hit = d .* (along - sqrt(R_EARTH^2 - nearest^2))
    return ground(unit(hit .- middle), d .* -1)
  end
  # The air glows for some tens of kilometres over the edge, where the Sun is on it
  over = unit(d .* along .- middle)
  (0.3, 0.55, 1.0) .* (1.2 * exp(-(nearest - R_EARTH) / 22e3) * smoothstep(-0.3, 0.4, dot(over, SUN)))
end

"A screen's number, from 0 to 255, for an amount of light. Bright light is pressed under the most that a screen shows, as film does."
screen(x) = begin
  x = clamp(x * (2.51x + 0.03) / (x * (2.43x + 0.59) + 0.14), 0.0, 1.0)
  255 * (x <= 0.0031308 ? 12.92x : 1.055x^(1 / 2.4) - 0.055)
end

const SKY_WIDE = 4096
const sky = picture_bytes(SKY_WIDE, SKY_WIDE ÷ 2, jpeg=true) do x, y
  turn, down = 2π * ((x + 0.5) / SKY_WIDE - 0.5), π * (y + 0.5) / (SKY_WIDE ÷ 2)
  screen.(sky_light((sin(turn) * sin(down), cos(down), -cos(turn) * sin(down))))
end

# --- materials -----------------------------------------------------------------

"The amounts of light that a screen's colour stands for, as a material's colour is given"
light(hex) = map(n -> (x = (hex >> n & 0xff) / 255; x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055)^2.4), (16, 8, 0))

const PICTURES = [:cells_colour => cells_colour, :cells_surface => cells_surface, :foil_colour => foil_colour,
                  :foil_surface => foil_surface, :foil_bumps => foil_bumps, :tubes => tubes]
picture(name) = (index=findfirst(p -> p[1] == name, PICTURES) - 1,)

"A material: its name, colour, how much a metal and how rough, and the pictures that it has"
material(name, hex, metal, rough; colour=nothing, surface=nothing, bump=nothing, depth=1.0, both=false) =
  name => merge((name=String(name), doubleSided=both,
                 pbrMetallicRoughness=merge((baseColorFactor=(light(hex)..., 1.0), metallicFactor=metal, roughnessFactor=rough),
                                            colour === nothing ? (;) : (baseColorTexture=picture(colour),),
                                            surface === nothing ? (;) : (metallicRoughnessTexture=picture(surface),))),
                bump === nothing ? (;) : (normalTexture=merge(picture(bump), (scale=depth,)),))

const MATERIALS = [
  material(:gold_foil, 0xd9a441, 1.0, 1.0, colour=:foil_colour, surface=:foil_surface, bump=:foil_bumps, depth=0.9),
  material(:silver_foil, 0xc9ccd2, 1.0, 0.3, bump=:foil_bumps, depth=0.6),
  material(:cells, 0xffffff, 1.0, 1.0, colour=:cells_colour, surface=:cells_surface),
  material(:amber_film, 0xb58a3a, 0.1, 0.45),
  material(:white_paint, 0xf2f2ee, 0.0, 0.55, bump=:tubes, depth=0.5),
  material(:bright_metal, 0xdfe3e8, 0.9, 0.22),
  # The loops shed heat, so they're painted pale. Bare metal would show only the black sky that it reflects.
  material(:pale_paint, 0xdfe2e6, 0.0, 0.5),
  material(:dark_metal, 0x2b2e33, 0.7, 0.4),
  material(:black, 0x0c0c0e, 0.2, 0.6),
  material(:glass, 0x0a1422, 0.0, 0.03),
  material(:ceramic, 0xe9e4da, 0.0, 0.7)]

# --- the satellite -------------------------------------------------------------

"The parts of the satellite: each has a name, and its shapes by material"
const parts = Pair{String,Vector{Pair{Symbol,Shape}}}[]
part!(name, shapes...) = push!(parts, name => collect(Pair{Symbol,Shape}, shapes))

# The body, wrapped in gold foil, with a silver deck on top
const top, back = body / 2, -body / 2
part!("Body",
  :gold_foil => block(body, body, body, bevel=0.03, edge=(0.01, 0.01)),
  :silver_foil => moved(block(0.98body, 0.03, 0.98body, bevel=0.008), (0, top + 0.015, 0)))

for (side, name) in ((-1, "Left wing"), (1, "Right wing"))
  root = side * (body / 2 + 0.6)   # where the drum stands, which the wing unrolled from
  x(far) = root + side * far       # a place `far` along the wing from the drum
  shapes = Pair{Symbol,Shape}[]
  # A yoke holds the drum: an arm from the middle of the body's side, and a strut to each end of the drum
  push!(shapes, :dark_metal => moved(block(0.6, 0.12, 0.12, bevel=0.01), (side * (body / 2 + 0.3), 0, 0)))
  for end_ in (-1, 1)
    push!(shapes, :dark_metal => rod((side * body / 2, end_ * 0.6body / 2, 0.0), (root, end_ * (chord / 2 - 0.2), 0.0), 0.035, n=12))
    push!(shapes, :bright_metal => moved(tube(0.26, 0.06), (root, end_ * (chord / 2 + 0.15), 0)))
  end
  push!(shapes, :dark_metal => moved(tube(0.22, chord + 0.3), (root, 0, 0)))
  # The fabric of cells, held taut between the drum and the bar at its tip. It was rolled up in bays. A strip
  # of bare film is between each two, and no two bays are quite the same blue.
  bays, strip = 12, 0.05
  wide = (reach - (bays - 1) * strip) / bays
  for bay in 0:bays-1
    middle = x(bay * (wide + strip) + wide / 2)
    shade = 0.88 + 0.12 * noise(bay, side)
    push!(shapes, :cells => tinted(moved(tiled(plate(wide, chord), wide / 4CELL, chord / 4CELL), (middle, 0, 0.003)), (shade, shade, shade)))
    bay < bays - 1 && push!(shapes, :amber_film => moved(plate(strip, chord), (middle + side * (wide + strip) / 2, 0, 0.003)))
  end
  # Amber film is behind the cells
  push!(shapes, :amber_film => moved(turned(plate(reach, chord), :y, 180), (x(reach / 2), 0, -0.003)))
  # The bar at the tip holds the end of the fabric. A loop of tube passes through a sleeve at each end of it.
  push!(shapes, :bright_metal => moved(tube(0.06, chord + 0.1), (x(reach), 0, 0)))
  for y in (-chord / 2, chord / 2)
    push!(shapes, :dark_metal => rod((x(reach), y, -0.14), (x(reach), y, 0.14), 2.2loop_r, n=12))
  end
  part!(name, shapes...)
end

# The radiator stands up behind the body, edge-on to the Sun. It reaches back to the loops, which pass through
# sleeves on the bar at its tip.
let root = back - 0.4, far = -deep
  panel = tiled(block(0.02, rad_high, rad_long, bevel=0.003), rad_long / 0.1, 1)
  shapes = Pair{Symbol,Shape}[
    :dark_metal => moved(block(0.12, 0.12, 0.4, bevel=0.01), (0, 0, back - 0.2)),
    :white_paint => moved(panel, (0, 0, (root + far) / 2))]
  for y in (-chord / 2, chord / 2)
    push!(shapes, :dark_metal => rod((-0.14, y, far), (0.14, y, far), 2.2loop_r, n=12))
  end
  # A bar at each end of the panel. The one at the tip is tall enough to reach both loops.
  for (z, high) in ((root, rad_high), (far, max(rad_high, chord)))
    push!(shapes, :bright_metal => moved(tube(0.04, high + 0.06), (0, 0, z)))
  end
  # The coolant comes from the body to the near bar in one pipe, and goes back in another
  for side in (-1, 1)
    push!(shapes, :bright_metal => rod((side * 0.11, 0.0, back), (side * 0.11, 0.0, root + 0.02), 0.02, n=10))
  end
  part!("Radiator", shapes...)
end

# Two loops of tube hold the wings and the radiator out, one level with each edge of the cells. Each goes right
# round the satellite: through the tip of one wing, behind the body through the tip of the radiator, through
# the tip of the other wing, and back in front of the body. The three tips can't move apart, so no wing can
# swing about its drum. The pressure in a loop pushes it towards a circle. The radiator pulls its back in, and
# two cords from the drums pull its front in. So it pushes the wings' tips apart, as a wheel's rim does on its
# spokes.
let shapes = Pair{Symbol,Shape}[]
  for y in (-chord / 2, chord / 2)
    push!(shapes, :pale_paint => loop(tip, deep, y, loop_r))
    # A sleeve at the front, where the two cords meet the loop. The cords are pale too, so they show against the sky.
    push!(shapes, :dark_metal => rod((-0.14, y, deep), (0.14, y, deep), 2.2loop_r, n=12))
    for side in (-1, 1)
      push!(shapes, :pale_paint => rod((side * (body / 2 + 0.6), y, 0.2), (side * 0.1, y, deep), 0.004, n=6))
    end
  end
  part!("Loops", shapes...)
end

# The laser to the next satellite, which looks along the orbit. It turns on a fork.
let scope = max(0.05, 2.5lens), at = (0.25body, top + 0.35, 0.25body)
  part!("Laser",
    :dark_metal => moved(tube(0.09, 0.2), (at[1], top + 0.13, at[3])),
    :dark_metal => moved(block(0.05, 0.2, 0.03, bevel=0.005), (at[1], top + 0.3, at[3] + scope + 0.025)),
    :dark_metal => moved(block(0.05, 0.2, 0.03, bevel=0.005), (at[1], top + 0.3, at[3] - scope - 0.025)),
    :black => rod((at[1] - 0.11, at[2], at[3]), (at[1] + 0.21, at[2], at[3]), scope),
    # A hood keeps the Sun off the lens
    :black => rod((at[1] + 0.21, at[2], at[3]), (at[1] + 0.3, at[2], at[3]), scope + 0.004, top=scope + 0.02, ends=false),
    :glass => rod((at[1] + 0.212, at[2], at[3]), (at[1] + 0.215, at[2], at[3]), 0.8scope))
end

# Two star trackers, looking away from the Sun and the Earth. A baffle keeps stray light out of each.
let shapes = Pair{Symbol,Shape}[]
  for side in (-1, 1)
    foot, up = (side * 0.3body, top + 0.03, -0.3body), unit((0.0, cos(0.5), -sin(0.5)))
    push!(shapes, :black => rod(foot, foot .+ up .* 0.16, 0.06))
    push!(shapes, :black => rod(foot .+ up .* 0.16, foot .+ up .* 0.34, 0.06, top=0.1, ends=false))
    push!(shapes, :glass => rod(foot .+ up .* 0.163, foot .+ up .* 0.166, 0.05))
  end
  part!("Star trackers", shapes...)
end

# The thruster: a ring of ceramic round a dark centre, for the last burn. The small tube beside it feeds the flame.
let at = (-0.25body, top + 0.03, 0.2body)
  part!("Thruster",
    :dark_metal => moved(tube(0.11, 0.1), at .+ (0, 0.05, 0)),
    :ceramic => moved(ring(0.075, 0.018), at .+ (0, 0.105, 0)),
    :bright_metal => moved(tube(0.03, 0.03), at .+ (0, 0.11, 0)),
    :dark_metal => rod(at .+ (0.13, 0, 0.05), at .+ (0.11, 0.12, 0.03), 0.015, n=10))
end

# On the face that looks at the Earth: the radio to the ground, and the ring that held the satellite to its rocket
part!("Earth face",
  :ceramic => moved(block(0.3, 0.02, 0.3, bevel=0.004), (0, back - 0.01, 0.2body)),
  :bright_metal => moved(tube(0.42body, 0.05, n=48, ends=false), (0, back - 0.025, 0)),
  :bright_metal => moved(ring(0.42body, 0.012, n=48, m=8), (0, back - 0.05, 0)))

# --- the file ------------------------------------------------------------------

json(x::NamedTuple) = "{" * join(("\"$k\":" * json(v) for (k, v) in pairs(x)), ",") * "}"
json(x::Union{AbstractVector,Tuple}) = "[" * join(json.(x), ",") * "]"
json(x::AbstractString) = "\"" * escape_string(x) * "\""
json(x::Bool) = string(x)
json(x::Integer) = string(x)
json(x::Real) = string(round(Float64(x), sigdigits=7))

"Write the satellite to the .glb file at `path`"
write_glb(path) = begin
  bin, views, accessors = IOBuffer(), [], []
  # Put `bytes` in the file and note where. `target` says what the graphics card uses them for.
  view!(bytes, target=nothing) = begin
    at = position(bin)
    write(bin, bytes, zeros(UInt8, (4 - length(bytes) % 4) % 4))
    push!(views, merge((buffer=0, byteOffset=at, byteLength=length(bytes)), target === nothing ? (;) : (target=target,)))
    length(views) - 1
  end
  numbers!(rows, kind; limits=false) = begin
    bytes = reinterpret(UInt8, Float32[x for row in rows for x in row])
    push!(accessors, merge((bufferView=view!(bytes, 34962), componentType=5126, count=length(rows), type=kind),
                           limits ? (min=Float32.(reduce((a, b) -> min.(a, b), rows)), max=Float32.(reduce((a, b) -> max.(a, b), rows))) : (;)))
    length(accessors) - 1
  end
  known = first.(MATERIALS)
  meshes, nodes = [], []
  for (name, shapes) in parts
    primitives = []
    for m in unique(first.(shapes))
      s = joined((shape for (which, shape) in shapes if which == m)...)
      order = length(s.at) <= 65535 ? UInt16.(s.corners .- 1) : UInt32.(s.corners .- 1)
      push!(accessors, (bufferView=view!(reinterpret(UInt8, order), 34963), componentType=eltype(order) == UInt16 ? 5123 : 5125, count=length(order), type="SCALAR"))
      given = merge((POSITION=numbers!(s.at, "VEC3", limits=true), NORMAL=numbers!(s.facing, "VEC3"), TEXCOORD_0=numbers!(s.place, "VEC2")),
                    isempty(s.tint) ? (;) : (COLOR_0=numbers!(s.tint, "VEC3"),))
      push!(primitives, (attributes=given, indices=length(accessors) - (isempty(s.tint) ? 4 : 5), material=findfirst(==(m), known) - 1))
    end
    push!(meshes, (name=name, primitives=primitives))
    push!(nodes, (name=name, mesh=length(meshes) - 1))
  end
  images = Any[(name=String(name), mimeType="image/png", bufferView=view!(bytes)) for (name, bytes) in PICTURES]
  push!(images, (name="sky", mimeType="image/jpeg", bufferView=view!(sky)))
  # The satellite is tipped back to face the Sun, and the Sun's light shines along its own -z, turned the same way
  tipped = (sin(TIP / 2), 0.0, 0.0, cos(TIP / 2))
  sun = (name="Sun", type="directional", color=(1.0, 0.965, 0.925), intensity=5.0)
  text = json((asset=(version="2.0", generator="Ladder app/satellite.jl"),
               extensionsUsed=["KHR_lights_punctual"], extensions=(KHR_lights_punctual=(lights=[sun],),),
               scene=0, scenes=[(name="One satellite of the fleet", nodes=[length(nodes), length(nodes) + 1], extras=(sky=(image=length(PICTURES),),))],
               nodes=[nodes..., (name="Satellite", children=collect(0:length(nodes)-1), rotation=tipped),
                      (name="Sun", rotation=tipped, extensions=(KHR_lights_punctual=(light=0,),))],
               meshes=meshes, materials=last.(MATERIALS),
               textures=[(source=i - 1, sampler=0) for i in eachindex(PICTURES)], samplers=[(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)],
               images=images, accessors=accessors, bufferViews=views, buffers=[(byteLength=position(bin),)]))
  text *= " "^((4 - sizeof(text) % 4) % 4)
  bytes = take!(bin)
  open(path, "w") do io
    write(io, 0x46546c67, UInt32(2), UInt32(12 + 8 + sizeof(text) + 8 + length(bytes)))
    write(io, UInt32(sizeof(text)), 0x4e4f534a, text)
    write(io, UInt32(length(bytes)), 0x004e4942, bytes)
  end
  path
end

if abspath(PROGRAM_FILE) == @__FILE__
  path = write_glb(joinpath(@__DIR__, "..", "pages", "satellite.glb"))
  println("Wrote $(relpath(path)): $(sum(length(s.corners) ÷ 3 for (_, shapes) in parts for (_, s) in shapes)) triangles, $(filesize(path) ÷ 1000) KB")
end
