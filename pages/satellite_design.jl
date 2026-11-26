# The satellite of the page "Data centres in space" as a design of SolidCraft,
# the CAD program: solid parts with round edges, which SolidCraft works out.
# The design is the file satellite.sc beside this one. It opens in SolidCraft,
# and in Ladder's own editor of designs.
#
# In Ladder, a `result` block like this one shows the design as a model, with
# the sizes that the page's sums give:
#
#     ```result
#     @use "./satellite_design" model page_numbers
#     model(page_numbers(@__MODULE__))
#     ```
#
# `model` gives the sizes to SolidCraft's hidden program, which makes every part again, in a second or
# two. Then it asks the program for the triangles of each part, and makes a
# model of them with the materials, the Sun and the sky that satellite.jl has.
#
# The design has a parameter for each number that it takes from the page, with
# the page's name for it: `span`, `sat_kg`, `chord`, `loop_d`, `loop_out`,
# `rad_high` and `lens`. It works out its other lengths from those, like
# `body`, `reach` and `deep`. Every part is placed with sums of the names, so
# the whole satellite follows them. A `view` block of satellite.sc itself, in
# the page, gives these parameters the page's numbers, as SolidCraft's
# editor shows the design.
#
#     julia --project=. pages/satellite_design.jl            # builds satellite.sc again from nothing
#     julia --project=. pages/satellite_design.jl out.glb    # and writes the model to out.glb
#
# Building it again replaces the file, with any change that was made to it in
# an editor.
#
# On a Mac with no SolidCraft, and when SolidCraft can't make a part at the
# sizes it's given, the model is the one that satellite.jl makes of its own
# triangles.
#
# SolidCraft has z up and works in mm: the wings go along x, the cells face -y
# and the radiator reaches along +y. A model has y up and metres.
@use "./satellite" sizes satellite glb sky VIEW_SKY Shape CELL noise tinted dot cross unit FIRST LIMITS page_numbers
@use "../cad/engine" => Engines
@use "../json" => JSON

const Vec = NTuple{3,Float64}
const UV = NTuple{2,Float64}

"The design, beside this file"
const DESIGN = joinpath(@__DIR__, "satellite.sc")

# --- SolidCraft's program --------------------------------------------------------
#
# The program reads a request as one line of JSON and writes its answer as
# one line. This file waits for each answer. Ladder's editor of designs can't
# wait, since it has a window to draw, so cad/engine.jl works another way.

"SolidCraft's hidden program, with one design open"
mutable struct Program
  process::Base.Process
  asked::Int             # how many requests it has had
end

"Start SolidCraft's program on the design at `path`. With `empty`, it starts on a new design, which can be saved at `path`."
program(path; empty=false) = begin
  cli = Engines.program()
  cli === nothing && error("SolidCraft isn't installed on this Mac.")
  design = empty ? `` : `--in $(abspath(path))`
  p = Program(open(pipeline(`$cli mcp --headless $design --allow-path $(dirname(abspath(path)))`, stderr=devnull), "r+"), 0)
  request(p, "initialize", (protocolVersion="2024-11-05", capabilities=(;), clientInfo=(name="Ladder", version="1")))
  write(p.process, JSON.json((jsonrpc="2.0", method="notifications/initialized")), '\n')
  p
end

"Send a request and wait for its answer"
request(p::Program, method, params) = begin
  id = (p.asked += 1)
  write(p.process, JSON.json((jsonrpc="2.0", id=id, method=method, params=params)), '\n')
  flush(p.process)
  while true
    eof(p.process) && error("SolidCraft's program stopped.")
    m = try JSON.parse(readline(p.process)) catch; continue end
    m isa JSON.Object && get(m, "id", nothing) == id || continue
    haskey(m, "error") && error(String(get(m["error"], "message", "SolidCraft's program refused the request.")))
    return m["result"]
  end
end

"Call the tool `name` of the program. Its answer is read as JSON when it is JSON."
tool(p::Program, name, args=(;)) = begin
  result = request(p, "tools/call", (name=name, arguments=args))
  text = join((String(c["text"]) for c in get(result, "content", Any[]) if get(c, "type", "") == "text"), "\n")
  get(result, "isError", false) === true && error(text)
  try JSON.parse(text) catch; text end
end

"Run one of SolidCraft's commands, like `solid.box`"
ask(p::Program, command, params=(;)) = tool(p, "execute", (command=command, params=params))

"End the program. What it didn't save is lost."
stop!(p::Program) = (try close(p.process.in) catch end; nothing)

# --- the design ------------------------------------------------------------------

"""
The body grows in steps of this many metres. Nearly every number of the page
changes the weight, and a body that changes makes SolidCraft make every part
again, which takes three seconds. A body that stays as it was makes half of
them again.
"""
const BODY_STEP = 0.05

"""
The lengths of the design, in mm, for the sizes `s` of a satellite, as `sizes`
gives them. The body is a whole number of `BODY_STEP`s, as the design makes it.
"""
lengths(s) = map(x -> round(1000x, digits=3),
                 (body=round(s.body / BODY_STEP) * BODY_STEP, reach=s.reach, chord=s.chord, loop_d=2s.loop_r, deep=s.deep, rad_high=max(s.rad_high, 0.05), lens=s.lens))

"""
The parameters of the design that a page gives it, with the page's names,
for the page's numbers `sums`: each one's expression and unit, as SolidCraft
reads them. The design works out its other lengths from these: see `WORKED`.
"""
inputs(sums=Dict{String,Any}()) = begin
  s = sizes(sums)
  page(name) = (x = get(sums, String(name), nothing); x isa Real && isfinite(x) ? clamp(Float64(x), LIMITS[name]...) : FIRST[name])
  mm(x) = ("$(round(1000x, digits=3)) mm", "mm")
  (span=mm(page(:span)), sat_kg=(string(page(:sat_kg)), ""), chord=mm(s.chord), loop_d=mm(page(:loop_d)),
   loop_out=(string(page(:loop_out)), ""), rad_high=mm(max(s.rad_high, 0.05)), lens=mm(page(:lens)))
end

"Lengths that the design works out from the ones that a page gives it. Each is the sum that `sizes` does, but that the body is a whole number of `BODY_STEP`s."
const WORKED = ["body" => "round(min(max((sat_kg/450)^(1/3) * 1 m, 800 mm), 4000 mm) / 50 mm) * 50 mm", # a side of the body, at 450 kg a cubic metre
                "root" => "body/2 + 600 mm",             # from the middle to each drum
                "reach" => "max(1000 mm, span/2 - root)", # how far each wing reaches past its drum
                "tip" => "root + reach",                 # from the middle to the tip of each wing
                "deep" => "max(loop_out*tip, body/2 + 1400 mm)", # from the middle to the front of each loop, and to its back
                "rad_long" => "deep - body/2 - 400 mm",
                "scope" => "max(50 mm, 2.5*lens)",       # the radius of the laser's tube
                "sleeve_r" => "1.1*loop_d",
                "bay" => "(reach - 11*50 mm)/12"]        # one of the 12 bays of cells, with 50 mm of bare film between two

"Each look of a part: its material in satellite.jl, its colour, how much a metal it is and how rough"
const LOOKS = ["Gold foil" => (:gold_foil, "#d9a441", 1.0, 0.4), "Silver foil" => (:silver_foil, "#c9ccd2", 1.0, 0.3),
               "Solar cells" => (:cells, "#0d1530", 0.0, 0.15), "Amber film" => (:amber_film, "#b58a3a", 0.1, 0.45),
               "White paint" => (:white_paint, "#f2f2ee", 0.0, 0.55), "Bright metal" => (:bright_metal, "#dfe3e8", 0.9, 0.22),
               "Pale paint" => (:pale_paint, "#dfe2e6", 0.0, 0.5), "Dark metal" => (:dark_metal, "#2b2e33", 0.7, 0.4),
               "Black" => (:black, "#0c0c0e", 0.2, 0.6), "Glass" => (:glass, "#0a1422", 0.0, 0.05), "Ceramic" => (:ceramic, "#e9e4da", 0.0, 0.7)]

"The look that the body `name` gets when the design is built"
look(name) = begin
  n = replace(name, "Left" => "Right")
  has(words...) = any(w -> occursin(w, n), words)
  n == "Bus" ? "Gold foil" : n == "Deck" ? "Silver foil" : has("cells") ? "Solar cells" : has("film") ? "Amber film" :
  n == "Radiator panel" ? "White paint" : has("loop", "cord") ? "Pale paint" : has("glass", "lens") ? "Glass" :
  has("Laser scope", "Laser hood", "Star tracker") ? "Black" : has("Thruster ring", "Antenna") ? "Ceramic" :
  has("drum cap", "tip bar", "Radiator bar", "Coolant", "cathode", "Launch ring") ? "Bright metal" : "Dark metal"
end

"""
The commands that build the design from nothing, each with what it takes.
`l` has the design's lengths, as `lengths` gives them, and `from_page` the
parameters that a page gives it, as `inputs` gives them, for the same
numbers. A length in a command is a sum of the names, so that the part
follows them later. Only the place of an edge to round has to be a number.
"""
steps(l, from_page=inputs()) = begin
  out = Any[]
  step!(command; given...) = push!(out, (command, NamedTuple(given)))
  box!(name, long, wide, high, middle) = step!("solid.box", length=long, width=wide, height=high, center=middle, body_name=name, name=name)
  bar!(name, base, long, radius; axis="Z") = step!("solid.cylinder", base=base, height=long, radius=radius, axis=axis, operation="new", body_name=name, name=name)
  round!(name, radius, edges) = step!("solid.fillet", edges=edges, radius=radius, body=name, name="$name edges")
  half, root = l.body / 2, l.body / 2 + 600

  for (name, (expression, unit)) in pairs(from_page)
    step!("parameters.add", name=String(name), expression=expression, unit=unit)
  end
  for (name, sum) in WORKED
    step!("parameters.add", name=name, expression=sum)
  end

  # The body, wrapped in gold foil, with a silver deck on top
  box!("Bus", "body", "body", "body", (0, 0, 0))
  round!("Bus", 30, [ntuple(k -> k == i ? a * half : k == j ? b * half : 0.0, 3) for (i, j) in ((1, 2), (1, 3), (2, 3)) for a in (-1, 1) for b in (-1, 1)])
  box!("Deck", "0.98*body", "0.98*body", 30, (0, 0, "body/2 + 15 mm"))
  let d = 0.49 * l.body
    round!("Deck", 8, vcat([(a * d, 0, half + 30) for a in (-1, 1)], [(0, a * d, half + 30) for a in (-1, 1)], [(a * d, b * d, half + 15) for a in (-1, 1) for b in (-1, 1)]))
  end

  # The right wing. A yoke holds the drum that the wing unrolled from: an arm from the middle of the body's side, and a
  # strut to each end of the drum.
  wing = String[]
  part(name) = (push!(wing, name); name)
  box!(part("Right arm"), 600, 120, 120, ("body/2 + 300 mm", 0, 0))
  round!("Right arm", 10, [(half + 300, a * 60, b * 60) for a in (-1, 1) for b in (-1, 1)])
  rise = "(chord/2 - 200 mm - 0.3*body)"
  for (sign, where) in (("", "top"), ("-", "bottom"))
    bar!(part("Right strut, $where"), ("body/2", 0, "$(sign)0.3*body"), "sqrt((600 mm)^2 + $rise^2)", 35, axis=("600", "0", "$sign$rise / 1 mm"))
  end
  bar!(part("Right drum"), ("root", 0, "-(chord + 300 mm)/2"), "chord + 300 mm", 220)
  for (where, base, z) in (("top", "chord/2 + 120 mm", l.chord / 2 + 120), ("bottom", "-(chord/2 + 180 mm)", -l.chord / 2 - 180))
    bar!(part("Right drum cap, $where"), ("root", 0, base), 60, 260)
    round!("Right drum cap, $where", 10, [(root + 260, 0, z), (root + 260, 0, z + 60)])
  end
  # The fabric: a film 4 mm thick, with the cells on its sunny side in 12 bays
  box!(part("Right film"), "reach", 4, "chord", ("root + reach/2", 1, 0))
  box!(part("Right cells"), "bay", 2, "chord", ("root + bay/2", -2, 0))
  step!("solid.pattern.rectangular", bodies=["Right cells"], dir1=(1, 0, 0), count1=12, spacing1="bay + 50 mm", name="Right bays")
  append!(wing, ["Right cells ($k)" for k in 2:12])
  # The bar at the tip holds the end of the fabric. A loop of tube passes through a sleeve at each end of it.
  bar!(part("Right tip bar"), ("tip", 0, "-(chord + 100 mm)/2"), "chord + 100 mm", 60)
  bar!(part("Right sleeve, top"), ("tip", -140, "chord/2"), 280, "sleeve_r", axis="Y")
  bar!(part("Right sleeve, bottom"), ("tip", -140, "-chord/2"), 280, "sleeve_r", axis="Y")
  # The left wing is the right one in a mirror
  step!("solid.mirror", bodies=wing, plane="YZ", body_names=[replace(n, "Right" => "Left") for n in wing], name="Left wing")

  # The radiator stands up behind the body, edge-on to the Sun, and reaches back to the loops
  box!("Radiator arm", 120, 400, 120, (0, "body/2 + 200 mm", 0))
  box!("Radiator panel", 20, "rad_long", "max(rad_high, 50 mm)", (0, "(body/2 + 400 mm + deep)/2", 0))
  bar!("Radiator bar, near", (0, "body/2 + 400 mm", "-(rad_high + 60 mm)/2"), "rad_high + 60 mm", 40)
  bar!("Radiator bar, far", (0, "deep", "-(max(rad_high, chord) + 60 mm)/2"), "max(rad_high, chord) + 60 mm", 40)
  bar!("Radiator sleeve, top", (-140, "deep", "chord/2"), 280, "sleeve_r", axis="X")
  bar!("Radiator sleeve, bottom", (-140, "deep", "-chord/2"), 280, "sleeve_r", axis="X")
  bar!("Coolant pipe, out", (110, "body/2", 0), 380, 20, axis="Y")
  bar!("Coolant pipe, back", (-110, "body/2", 0), 380, 20, axis="Y")

  # Two loops of tube, one level with each edge of the cells. Each is an oval right round the satellite, through the
  # tips of both wings and the tip of the radiator. Two cords from the drums pull its front in.
  for (name, level) in (("Top", "chord/2"), ("Bottom", "-chord/2"))
    step!("sketch.create", plane="XY", offset=level, name="$name loop path")
    step!("sketch.ellipse", center=(0, 0), major=("tip", 0), minor_radius="deep", axes=false)
    step!("sketch.finish")
    step!("solid.pipe", path_sketch="$name loop path", path=["e1"], diameter="loop_d", body_name="$name loop", name="$name loop")
    bar!("Front sleeve, $(lowercase(name))", (-140, "-deep", level), 280, "sleeve_r", axis="X")
    for (sign, back, side) in (("", "-", "right"), ("-", "", "left"))
      bar!("$name cord, $side", ("$(sign)root", -200, level), "sqrt((root - 100 mm)^2 + (deep - 200 mm)^2)", 4,
           axis=("$(back)(root - 100 mm) / 1 mm", "-(deep - 200 mm) / 1 mm", "0"))
    end
  end

  # The laser to the next satellite, which looks along the orbit. It turns on a fork. A hood keeps the Sun off its lens.
  let x = "0.25*body", y = "-0.25*body", z = "body/2 + 350 mm"
    bar!("Laser pedestal", (x, y, "body/2 + 30 mm"), 200, 90)
    box!("Laser fork, front", 50, 30, 200, (x, "$y - scope - 25 mm", "body/2 + 300 mm"))
    box!("Laser fork, back", 50, 30, 200, (x, "$y + scope + 25 mm", "body/2 + 300 mm"))
    bar!("Laser scope", ("$x - 110 mm", y, z), 320, "scope", axis="X")
    step!("solid.cone", base=("$x + 210 mm", y, z), axis="X", height=90, radius="scope + 4 mm", top_radius="scope + 20 mm", body_name="Laser hood", name="Laser hood")
    step!("solid.cone", base=("$x + 210 mm", y, z), axis="X", height=90, radius="scope + 2 mm", top_radius="scope + 18 mm", operation="cut", targets=["Laser hood"], name="Laser hood bore")
    bar!("Laser lens", ("$x + 212 mm", y, z), 3, "0.8*scope", axis="X")
  end

  # Two star trackers, which look away from the Sun and the Earth. A baffle keeps stray light out of each.
  let up = (0.0, sin(0.5), cos(0.5))
    for (sign, side) in (("", "right"), ("-", "left"))
      at(far) = ("$(sign)0.3*body", "0.3*body + $(round(far * up[2], digits=4)) mm", "body/2 + 30 mm + $(round(far * up[3], digits=4)) mm")
      bar!("Star tracker, $side", at(0), 160, 60, axis=up)
      step!("solid.cone", base=at(160), axis=up, height=180, radius=60, top_radius=100, body_name="Star tracker baffle, $side", name="Star tracker baffle, $side")
      step!("solid.cone", base=at(160), axis=up, height=180, radius=57, top_radius=97, operation="cut", targets=["Star tracker baffle, $side"], name="Star tracker bore, $side")
      bar!("Star tracker glass, $side", at(163), 3, 50, axis=up)
    end
  end

  # The thruster: a ring of ceramic round a dark centre, for the last burn. The small tube beside it feeds the flame.
  let x = "-0.25*body", y = "-0.2*body"
    bar!("Thruster", (x, y, "body/2 + 30 mm"), 100, 110)
    step!("solid.torus", center=(x, y, "body/2 + 135 mm"), major=75, minor=18, body_name="Thruster ring", name="Thruster ring")
    bar!("Thruster cathode", (x, y, "body/2 + 125 mm"), 30, 30)
    bar!("Thruster feed", ("$x + 130 mm", "$y - 50 mm", "body/2 + 30 mm"), round(sqrt(20^2 + 20^2 + 120^2), digits=4), 15, axis=(-20, 20, 120))
  end

  # On the face that looks at the Earth: the radio to the ground, and the ring that held the satellite to its rocket
  box!("Antenna", 300, 300, 20, (0, "-0.2*body", "-body/2 - 10 mm"))
  let y = -0.2 * l.body
    round!("Antenna", 4, vcat([(a * 150, y, -half - 20) for a in (-1, 1)], [(0, y + a * 150, -half - 20) for a in (-1, 1)], [(a * 150, y + b * 150, -half - 10) for a in (-1, 1) for b in (-1, 1)]))
  end
  bar!("Launch ring", (0, 0, "-body/2 - 50 mm"), 50, "0.42*body")
  step!("solid.cylinder", base=(0, 0, "-body/2 - 50 mm"), height=50, radius="0.42*body - 8 mm", operation="cut", targets=["Launch ring"], name="Launch ring bore")
  step!("solid.torus", center=(0, 0, "-body/2 - 50 mm"), major="0.42*body", minor=12, body_name="Launch ring rim", name="Launch ring rim")
  out
end

"The names of the bodies of the design that `p` has open"
bodies(p::Program) = String[b isa AbstractDict ? b["name"] : b for b in tool(p, "measure", (names_only=true,))["bodies"]]

"""
Build the design of a satellite from nothing, with SolidCraft's program, at the
page's numbers `sums`, and save it as the file `path`. The file that was
there is replaced.
"""
build(path=DESIGN, sums=Dict{String,Any}()) = begin
  p = program(path, empty=true)
  try
    for (command, given) in steps(lengths(sizes(sums)), inputs(sums))
      try
        ask(p, command, given)
      catch e
        error("SolidCraft couldn't do the step $command $(get(given, :name, "")): $(sprint(showerror, e))")
      end
    end
    names = bodies(p)
    for (name, (_, colour, metal, rough)) in LOOKS
      mine = filter(n -> look(n) == name, names)
      isempty(mine) || ask(p, "appearance.assign", (bodies=mine, color=colour, name=name, pbr=(metallic=metal, roughness=rough, dielectric_ior=1.5)))
    end
    isfile(path) && rm(path)
    tool(p, "save", (path=abspath(path),))
    length(names)
  finally
    stop!(p)
  end
end

# --- from SolidCraft's triangles to a model ----------------------------------------

"Two faces that meet at more than this many degrees have a sharp edge between them. A curve's flat pieces meet at less, so it's shaded as one curve."
const CREASE = 50.0

"""
The corners and the triangles of the body `name`, as SolidCraft has them. A
flat piece is at most `off` mm from a curve that it stands for. SolidCraft
gives at most 16,384 triangles in one answer, so a body that needs more gets
fewer, larger ones.
"""
triangles(p::Program, name, off) = begin
  while true
    try
      m = ask(p, "model.mesh", (body=name, tolerance=off))
      # SolidCraft has z up and mm. A model has y up and metres.
      at = Vec[(q[1] / 1000, q[3] / 1000, -q[2] / 1000) for q in m["positions"]]
      return at, NTuple{3,Int}[(Int(t[1]) + 1, Int(t[2]) + 1, Int(t[3]) + 1) for t in m["triangles"]], off
    catch e
      occursin("transfer budget", sprint(showerror, e)) && off < 50 || rethrow()
      off *= 1.4
    end
  end
end

"The size of flat piece that each body's triangles were last read with, in mm, and how thin the body was then, in mm, by the body's name"
const READ_WITH = Dict{String,NTuple{2,Float64}}()

"""
The body `name` as triangles, and two opposite corners of the box round it. A
round bar 8 mm across needs smaller flat pieces than a drum, so the first
answer says how thin the body is, and a thin body is asked for again.

The size of piece that a body got is kept for the next time. SolidCraft works
all of a body's triangles out before it refuses to give too many, so a
refusal costs as much as an answer. The two loops were refused twice each,
and that was more than half of the time that the triangles took.
"""
triangles(p::Program, name) = begin
  box(at) = (reduce((a, b) -> min.(a, b), at), reduce((a, b) -> max.(a, b), at))
  thin(lo, hi) = 1000 * minimum(hi .- lo)
  before = get(READ_WITH, name, nothing)
  if before !== nothing
    at, corners, off = triangles(p, name, before[1])
    lo, hi = box(at)
    # A body that's about as thin as it was has pieces of the right size
    off == before[1] && isapprox(thin(lo, hi), before[2], rtol=0.2) && return at, corners, lo, hi
  end
  at, corners, off = triangles(p, name, 0.4)
  lo, hi = box(at)
  fine = clamp(thin(lo, hi) / 80, 0.05, 0.4)
  off == 0.4 && fine < 0.39 && ((at, corners, off) = triangles(p, name, fine))
  READ_WITH[name] = (off, thin(lo, hi))
  at, corners, lo, hi
end

"""
Where a corner at `q` is in the pictures of the material `m`, on a face that
looks the way `n`. `lo` and `hi` are two opposite corners of the box round the
corner's body. A foil has its whole picture on each face of its body. The
cells' picture is 4 cells by 4, and the radiator's has one tube every 10 cm.
"""
place(m, q, n, lo, hi) = begin
  axis = argmax(abs.(n))   # the axis that the face looks along most
  across(k) = (q[k] - lo[k]) / max(hi[k] - lo[k], 1e-9)
  m == :cells ? (axis == 3 && n[3] > 0 ? ((q[1] - lo[1]) / 4CELL, (hi[2] - q[2]) / 4CELL) : (0.0, 0.0)) :
  m in (:gold_foil, :silver_foil) ? (axis == 1 ? (across(3), 1 - across(2)) : axis == 2 ? (across(1), across(3)) : (across(1), 1 - across(2))) :
  m == :white_paint ? (axis == 1 ? ((q[3] - lo[3]) / 0.1, 1 - across(2)) : (0.0, 0.0)) : (0.0, 0.0)
end

"""
A body as a shape with the material `m`. `at` has its corners and `corners`
its triangles. A corner gets the way that the surface faces there from the
triangles round it, but only from those that are part of the same curve.
"""
shape(m, at, corners, lo, hi) = begin
  flat = [cross(at[b] .- at[a], at[c] .- at[a]) for (a, b, c) in corners]   # the way each triangle faces, as long as twice its area
  long = [sqrt(dot(f, f)) for f in flat]
  faces = [l > 0 ? f ./ l : f for (f, l) in zip(flat, long)]
  round_about = [Int[] for _ in at]
  for (t, triangle) in enumerate(corners), v in triangle
    push!(round_about[v], t)
  end
  out = Shape(Vec[], Vec[], UV[], Int[])
  known = Dict{Tuple{Int,NTuple{3,Int},NTuple{2,Int}},Int}()
  least = cosd(CREASE)
  for (t, triangle) in enumerate(corners)
    long[t] > 0 || continue
    for v in triangle
      facing = (0.0, 0.0, 0.0)
      for other in round_about[v]
        dot(faces[other], faces[t]) > least && (facing = facing .+ flat[other])
      end
      facing = unit(facing)
      where = place(m, at[v], faces[t], lo, hi)
      i = get!(known, (v, round.(Int, facing .* 2000), round.(Int, where .* 8192))) do
        push!(out.at, at[v]); push!(out.facing, facing); push!(out.place, where)
        length(out.at)
      end
      push!(out.corners, i)
    end
  end
  out
end

"The part of the satellite that the body `name` belongs to"
part_of(name) = begin
  has(words...) = any(w -> occursin(w, name), words)
  startswith(name, "Left") ? "Left wing" : startswith(name, "Right") ? "Right wing" : has("Radiator", "Coolant") ? "Radiator" :
  has("loop", "cord", "Front sleeve") ? "Loops" : has("Laser") ? "Laser" : has("Star tracker") ? "Star trackers" : has("Thruster") ? "Thruster" :
  has("Antenna", "Launch ring") ? "Earth face" : "Body"
end

"""
The parts of the design that `p` has open, as `satellite` of satellite.jl
gives them: each part has a name, and its shapes by material. A body's
material is the one that its look in the design names. `panel` is false when
the radiator has no panel, since the loops shed all of the heat.
"""
parts(p::Program; panel=true) = begin
  looks = ask(p, "appearance.list")["bodies"]
  materials = Dict(name => m for (name, (m, _)) in LOOKS)
  out = Pair{String,Vector{Pair{Symbol,Shape}}}[]
  for name in bodies(p)
    name == "Radiator panel" && !panel && continue
    given = get(looks, name, nothing)
    m = get(materials, given isa AbstractDict ? get(given, "name", "") : "", :dark_metal)
    s = shape(m, triangles(p, name)...)
    if m == :cells
      # No two bays are quite the same blue
      bay = match(r"\((\d+)\)$", name)
      shade = 0.88 + 0.12 * noise(bay === nothing ? 0 : parse(Int, bay[1]) - 1, startswith(name, "Left") ? -1 : 1)
      s = tinted(s, (shade, shade, shade))
    end
    i = findfirst(p -> p[1] == part_of(name), out)
    i === nothing && (push!(out, part_of(name) => Pair{Symbol,Shape}[]); i = length(out))
    push!(out[i][2], m => s)
  end
  out
end

# --- the model that a page shows ---------------------------------------------------

"SolidCraft's program with the design open, when the design's file was last changed, and the lengths that the program has now"
const OPEN = Ref{Any}(nothing)
"The lengths of the model that was made last, and its parts"
const MADE = Ref{Any}(nothing)
"Only one model is made at a time"
const BUSY = ReentrantLock()
"The program is ended after this many seconds with no model to make"
const IDLE = 120.0
const USED = Ref(0.0)

shut!() = (OPEN[] === nothing || stop!(OPEN[][1]); OPEN[] = nothing)

"The parts of the design with the lengths `l`, as SolidCraft makes them"
solid(l; panel=true) = begin
  changed = mtime(DESIGN)
  # A design that was saved again since it was opened here may have new parts
  OPEN[] !== nothing && (OPEN[][2] != changed || !process_running(OPEN[][1].process)) && shut!()
  OPEN[] === nothing && (OPEN[] = (program(DESIGN), changed, nothing))
  p, _, has = OPEN[]
  try
    if has != l
      ask(p, "parameters.change", (changes=Dict(String(name) => "$value mm" for (name, value) in pairs(l)),))
      OPEN[] = (p, changed, l)
    end
    parts(p; panel)
  catch
    shut!()
    rethrow()
  end
end

"End the program when no model was asked for in a while"
rest!() = begin
  USED[] = time()
  @async begin
    sleep(IDLE + 1)
    lock(() -> time() - USED[] > IDLE && shut!(), BUSY)
  end
end

"""
The parts of a satellite with the sizes `s`. SolidCraft makes them from the
design. When it can't, they're the triangles that satellite.jl makes.
"""
made(s) = lock(BUSY) do
  l, panel = lengths(s), s.rad_high >= 0.05
  MADE[] !== nothing && MADE[][1] == (l, panel, mtime(DESIGN)) && return MADE[][2]
  out = if Engines.available() && isfile(DESIGN)
    try
      solid(l; panel)
    catch e
      @warn "SolidCraft couldn't make the satellite, so this is the model of satellite.jl" problem=sprint(showerror, e)
      nothing
    end
  end
  rest!()
  out === nothing && return satellite(s)
  MADE[] = ((l, panel, mtime(DESIGN)), out)
  out
end

"""
The model of the satellite that the numbers `given` make, as the bytes of a
.glb file. `given` has a number in SI units for each name of the page's first
numbers that it has, as `page_numbers` gives them. With none, the satellite
has the page's first numbers.
"""
model(given=Dict{String,Any}()) = (s = sizes(given); glb(made(s), sky(s.alt, VIEW_SKY)))

if abspath(PROGRAM_FILE) == @__FILE__
  n = build()
  println("Built $(relpath(DESIGN)): $n bodies")
  if !isempty(ARGS)
    parts = made(sizes())
    write(ARGS[1], model())
    println("Wrote $(ARGS[1]): $(sum(length(s.corners) ÷ 3 for (_, shapes) in parts for (_, s) in shapes)) triangles, $(filesize(ARGS[1]) ÷ 1000) KB")
    shut!()
  end
end
