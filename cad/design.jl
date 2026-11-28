# A SolidCraft design that's open: what it holds now, and the changes to it.
#
# engine.jl talks to SolidCraft's hidden program. This file keeps what the
# program last said of the design, so that the editor can draw it in each
# frame without asking:
#
#     m = open_design("bracket.sc")
#     change!(m, "solid.fillet", Dict("edges" => [[30, 22.5, 6]], "radius" => 2))
#     settle!(m)                    # a test waits. A window calls `tick!(m)` in each frame.
#     m.doc["timeline"]             # the steps, with the new fillet
#     m.shapes                      # the bodies as triangles, with their faces and edges
#     save!(m)
#
# After each change it asks the program for these again: the design's lists
# (steps, bodies, sketches, parameters), the bodies as triangles with the face
# that each triangle is of, where the construction planes are, and each
# sketch that shows. While a sketch is being edited the bodies can't change,
# so they aren't asked for again until it's finished.
#
# `m.version` goes up each time any of that changes, so the editor knows when
# to draw again.
#
# `try!` runs a command to see what it would make, and takes it back at once:
# the editor shows that while a command's form is filled in. The program has
# no way to try a command, so this runs it, asks for the bodies, and undoes
# it. Until it's undone, everything else that's asked for waits.

@use "./engine" => Engines
@use "github.com/jkroso/JSON.jl" => JSON
@use "./scene" Shape read_glb Vec3
@use "./scene" => Scenes
@use "../folders/zip" => Zips

mutable struct Model
  path::String
  engine::Any                       # the hidden program, or nothing when there's none
  problem::String                   # why there's none, in words
  room::String                      # a folder of its own for the files that the program writes for Ladder
  doc::JSON.Object                  # the design's lists, as `document.inspect` gives them
  shapes::Vector{Shape}
  shapes_of::Any                    # what the shapes are of: they're asked for again when this changes
  colours::Dict{String,Vec3}        # the colour of each body that has one, by the body's name
  opacity::Dict{String,Float64}     # how solid each body shows, where that's under 1
  painted::Vector{Any}              # the faces with a colour of their own: each has the body, a point on the face, the colour and how solid
  planes::Vector{Any}               # the construction planes: each has its name, a point on it and the way it faces
  planes_of::Any                    # what the planes are of
  origin_hidden::Bool               # the origin's point, axes and planes are all hidden, as they are in a new design
  trying::Bool                      # a command is being tried, and isn't taken back yet
  later::Vector{Any}                # what was asked for meanwhile: each a function that asks for it
  ghost::Int                        # how many of the steps that the program can redo are commands that were tried
  trial::Any                        # what the command that was last tried makes: its key, the bodies, their colours, the names of those it changes, and its problem
  sketches::Dict{Int,JSON.Object}   # each sketch that shows, as `sketch.inspect` gives it, by its step's number
  glyphs::Vector{Any}               # the marks of the constraints of the sketch that's being edited
  commands::Dict{String,JSON.Object}   # every command of SolidCraft, by its id
  version::Int
  asked::Int                        # the number of the last time the lists were asked for. An older answer is dropped.
  said::String                      # what went wrong with the last change, or ""
  read::Float64                     # when the file had last changed, as it was opened or saved
  parameters::Vector{Any}           # every parameter, as `parameters.list` gives them: the user's, and the lengths of the steps, like d1
  joined::Dict{Int,Int}             # where several steps that can be taken back are one change: how many there are, by how many steps could be taken back after them
  rejoined::Dict{Int,Int}           # the same for steps that can be done again, by how many could be done again before them
end

Model(path) = Model(path, nothing, "", "", JSON.Object(), Shape[], nothing, Dict{String,Vec3}(), Dict{String,Float64}(), Any[],
                    Any[], nothing, true, false, Any[], 0, nothing,
                    Dict{Int,JSON.Object}(), Any[], Dict{String,JSON.Object}(), 0, 0, "", 0.0, Any[], Dict{Int,Int}(), Dict{Int,Int}())

"""
Open the design at `path`. With no SolidCraft on this Mac, the model says so
in `problem`. `changes` gives parameters other values before the bodies are
asked for, as `vary!` does. The file keeps its own.
"""
open_design(path::AbstractString; changes=Dict{String,String}()) = begin
  m = Model(String(path))
  m.read = mtime(path)
  m.origin_hidden = origin_hidden(path)
  if !Engines.available()
    m.problem = "SolidCraft isn't installed on this Mac. Ladder uses the program inside SolidCraft.app to open a design."
    return m
  end
  m.room = mktempdir()
  try
    m.engine = Engines.start(path, rooms=[m.room])
  catch err
    m.problem = sprint(showerror, err)
    return m
  end
  Engines.call!(m.engine, "list_commands") do answer, problem
    answer isa Vector || return
    for c in answer
      c isa JSON.Object && (m.commands[c["id"]] = c)
    end
    m.version += 1
  end
  vary!(m, changes)
  refresh!(m)
  finalizer(close!, m)
end

"The design's lists as its file at `path` has them, or nothing when the file can't be read"
file_document(path::AbstractString) = try
  z = Zips.contents(path)
  i = findfirst(en -> en.name == "document.json", z.entries)
  i === nothing ? nothing : JSON.parse_json(String(Zips.bytes(path, z.entries[i])), JSON.Object)
catch
  nothing
end

"Does the design's file say that its origin is hidden? A design that says nothing has it hidden."
origin_hidden(path::AbstractString) = origin_hidden(file_document(path))
origin_hidden(doc) = begin
  seen = doc isa JSON.Object ? get(doc, "visibility", nothing) : nothing
  !(seen isa JSON.Object && get(seen, "origin_hidden", true) === false)
end

"End the program of `m`. What wasn't saved is lost."
close!(m::Model) = begin
  m.engine === nothing || Engines.stop!(m.engine)
  m.engine = nothing
  isempty(m.room) || rm(m.room, recursive=true, force=true)
  m.room = ""
  nothing
end

"True while the program still works on something that was asked"
busy(m::Model) = m.engine !== nothing && Engines.busy(m.engine) > 0

"True when the program has stopped by itself"
stopped(m::Model) = m.engine !== nothing && !isempty(m.engine.stopped)

"Take the answers that have come. A window calls this in each frame."
tick!(m::Model) = (m.engine === nothing || Engines.pump!(m.engine); m)

"Wait until the program has answered everything. A test calls this."
settle!(m::Model; limit=120) = (m.engine === nothing || Engines.settle!(m.engine; limit); m)

"The number of the step of the sketch that's being edited, or nothing"
editing(m::Model) = (a = get(m.doc, "active_sketch", nothing); a === nothing ? nothing : Int(a))

get_list(m::Model, key) = (l = get(m.doc, key, nothing); l isa Vector ? l : Any[])
timeline(m::Model) = get_list(m, "timeline")
bodies(m::Model) = get_list(m, "bodies")
sketch_list(m::Model) = get_list(m, "sketches")
params(m::Model) = get_list(m, "params")
edited(m::Model) = get(m.doc, "dirty", false) === true
"How many steps are active: the steps after that are rolled back"
marker(m::Model) = Int(get(m.doc, "marker", length(timeline(m))))

"How many steps the program can take back"
undos(m::Model) = (n = get(m.doc, "undo", 0); n isa Number ? Int(n) : 0)

"How many steps the program can do again. A command that was tried and taken back isn't one of them."
redoable(m::Model) = (n = get(m.doc, "redo", 0); n isa Number ? max(0, Int(n) - m.ghost) : 0)

"Do `f` now, or when the command that's being tried has been taken back"
free(f, m::Model) = (m.trying ? push!(m.later, f) : f(); m)

"Does the point, the axis or the plane `name` of the origin show: O, X, Y, Z, XY, XZ or YZ?"
origin_shown(m::Model, name) = !m.origin_hidden && !(name in get_list(m, "hidden_origin"))

"Does the construction plane `name` show?"
plane_shown(m::Model, name) = !(name in get_list(m, "hidden_origin"))

"Is the body `name` shown?"
shown(m::Model, name) = begin
  i = findfirst(b -> b isa JSON.Object && get(b, "name", "") == name, bodies(m))
  i === nothing ? true : get(bodies(m)[i], "visible", true) === true
end

"""
A function that says whether a shape shows, as `shown` does for its name. It
finds the hidden bodies once, so a check of every body doesn't search the
list of bodies for each one.
"""
shows(m::Model) = begin
  hidden = Set{String}(String(get(b, "name", "")) for b in bodies(m) if b isa JSON.Object && get(b, "visible", true) !== true)
  s -> !(s.name in hidden)
end

"""
Ask the program for the design again: its lists, then its bodies and its
sketches. `then` is called when it has all come.
"""
refresh!(m::Model; then=nothing) = free(m) do
  e = m.engine
  e === nothing && return
  n = (m.asked += 1)
  Engines.call!(e, "execute", JSON.Object("command" => "document.inspect",
      "params" => JSON.Object("timeline" => true, "bodies" => true, "sketch_counts" => true))) do answer, problem
    # A newer change was asked for since: its answer will come. A design that was closed since wants none.
    (n == m.asked && m.engine === e) || return
    if answer isa JSON.Object
      m.doc = answer
      m.version += 1
      # With nothing to redo, the program has forgotten the command that was tried
      get(answer, "redo", 0) == 0 && (m.ghost = 0)
      shapes!(m)
      planes!(m)
      sketches!(m, n)
      # The parameters of the steps, like d1, and the comments of all of them, are only in this list
      Engines.call!(e, "execute", JSON.Object("command" => "parameters.list", "params" => JSON.Object())) do list, _
        (n == m.asked && m.engine === e) || return
        list isa JSON.Object && get(list, "parameters", nothing) isa Vector && (m.parameters = list["parameters"]; m.version += 1)
      end
    else
      problem === nothing || (m.said = problem)
    end
    # What `then` asks for comes after what was asked for here
    then === nothing || Engines.call!((_, _) -> then(), e, "running")
  end
end

"Ask for the bodies as triangles, when they can have changed"
shapes!(m::Model) = begin
  e = m.engine
  of = editing(m) === nothing ? (get(m.doc, "revision", 0), marker(m), length(bodies(m))) : (:sketch, editing(m), marker(m))
  of == m.shapes_of && return
  m.shapes_of = of
  if isempty(bodies(m))
    m.shapes = Shape[]
    empty!(m.colours); empty!(m.opacity); empty!(m.painted)
    m.version += 1
    return
  end
  export!(m, joinpath(m.room, "bodies")) do shapes, colours
    of == m.shapes_of || return
    m.shapes, m.colours = shapes, colours
    m.version += 1
  end
  # The file of bodies has each body's colour. How far a body shows through, and the faces with a colour of their own, are asked for.
  Engines.call!(e, "execute", JSON.Object("command" => "appearance.list", "params" => JSON.Object())) do answer, problem
    of == m.shapes_of || return
    empty!(m.opacity)
    empty!(m.painted)
    answer isa JSON.Object || return
    looks = get(answer, "bodies", nothing)
    looks isa JSON.Object && for (name, look) in looks
      a = look isa JSON.Object ? get(look, "opacity", 1.0) : 1.0
      a isa Number && a < 1 && (m.opacity[name] = Float64(a))
    end
    faces = get(answer, "faces", nothing)
    faces isa Vector && for f in faces
      f isa JSON.Object || continue
      look, point = get(f, "appearance", nothing), get(f, "point", nothing)
      colour = look isa JSON.Object ? rgb(get(look, "color", nothing)) : nothing
      (colour === nothing || !(point isa Vector) || length(point) != 3) && continue
      a = get(look, "opacity", 1.0)
      push!(m.painted, (body=String(get(f, "body", "")), point=(Float64(point[1]), Float64(point[2]), Float64(point[3])), colour=colour, opacity=a isa Number ? Float64(a) : 1.0))
    end
    m.version += 1
  end
end

"""
Ask the program to write its bodies in files whose names start with `stem`,
and give `then` the bodies and their colours when it has. It writes a .glb
file: each body's triangles, with the way they face, the body's colour, and
each face's triangles apart from those of the other faces.

How fine SolidCraft cuts a curve is a share of the size of the whole body. That
is too coarse for a body that's long and thin: a 30 mm tube that goes 70 m
round a satellite comes out with three sides. So the bodies that are thin for
their size, and have a curved face, are written a second time, finer.
"""
export!(then, m::Model, stem) = begin
  e = m.engine
  e === nothing && return
  write!(e, stem * ".glb", "standard", nothing) do shapes, colours
    again = [quality => String[s.name for s in shapes if finer(s) == quality] for quality in ("fine", "finest")]
    filter!(p -> !isempty(p[2]), again)
    # One after the other. Each answer puts its bodies in the place of the coarse ones.
    next() = begin
      isempty(again) && return then(shapes, colours)
      quality, names = popfirst!(again)
      write!(e, "$stem-$quality.glb", quality, names) do better, _
        for b in better
          i = findfirst(s -> s.name == b.name, shapes)
          i === nothing || (shapes[i] = b)
        end
        next()
      end
    end
    next()
  end
end

"Ask the program `e` to write the bodies `names`, or all of them with nothing, as the .glb file `file`, and give `then` the bodies in it and their colours"
write!(then, e, file, quality, names) = begin
  rm(file, force=true)
  params = JSON.Object("path" => file, "format" => "glb", "quality" => quality, "hierarchy" => false)
  names === nothing || (params["bodies"] = names)
  Engines.call!(e, "execute", JSON.Object("command" => "file.export", "params" => params)) do answer, problem
    then((isfile(file) ? read_glb(read(file)) : (Shape[], Dict{String,Vec3}()))...)
  end
end

"""
The quality that SolidCraft should write the body `s` with, when "standard"
is too coarse for it, or nothing. The three qualities let a flat piece be
2/10,000, 5/100,000 and 1/100,000 of the body's size away from a curve. A
piece should be within a 40th of the body's thinnest side.
"""
finer(s::Shape) = begin
  all(s.flat) && return nothing
  size, thin = Scenes.len(s.high .- s.low), minimum(s.high .- s.low)
  size > 0 || return nothing
  thin / 40 >= 2e-4 * size ? nothing : thin / 40 >= 5e-5 * size ? "fine" : "finest"
end

"""
Ask where each construction plane is. The program says it of what's selected,
so this selects the planes, asks, and selects nothing again. What's selected
in the program is of no use to Ladder, which keeps what's selected itself.
"""
planes!(m::Model) = begin
  e = m.engine
  editing(m) === nothing || return
  names = String[String(f["name"]) for f in timeline(m) if f isa JSON.Object && get(f, "type", "") == "ConstructionPlane" &&
                 get(f, "suppressed", false) !== true && get(f, "rolled_back", false) !== true]
  of = (get(m.doc, "revision", 0), names)
  of == m.planes_of && return
  m.planes_of = of
  isempty(names) && return (isempty(m.planes) || (m.planes = Any[]; m.version += 1); nothing)
  run(command, params=JSON.Object()) = Engines.call!((_, _) -> nothing, e, "execute", JSON.Object("command" => command, "params" => params))
  run("select.clear")
  for name in names
    run("select.set", JSON.Object("items" => Any[JSON.Object("type" => "plane", "name" => name)], "add" => true))
  end
  Engines.call!(e, "execute", JSON.Object("command" => "selection.get", "params" => JSON.Object())) do answer, problem
    of == m.planes_of || return
    found = Any[]
    for item in (answer isa JSON.Object && get(answer, "items", nothing) isa Vector ? answer["items"] : Any[])
      (item isa JSON.Object && get(item, "kind", "") == "plane") || continue
      p, n = get(item, "point", nothing), get(item, "normal", nothing)
      (p isa Vector && n isa Vector && length(p) == 3 && length(n) == 3) || continue
      push!(found, (name=String(get(item, "name", "")), point=(Float64(p[1]), Float64(p[2]), Float64(p[3])), normal=(Float64(n[1]), Float64(n[2]), Float64(n[3]))))
    end
    m.planes = found
    m.version += 1
  end
  run("select.clear")
  nothing
end

"A colour that SolidCraft writes as `#rrggbb`, as red, green and blue from 0 to 1, or nothing"
rgb(text) = begin
  text isa AbstractString && length(text) == 7 && text[1] == '#' || return nothing
  n = tryparse(UInt32, text[2:end], base=16)
  n === nothing ? nothing : (((n >> 16) & 0xff) / 255, ((n >> 8) & 0xff) / 255, (n & 0xff) / 255)
end

"Ask for each sketch that shows, and for the marks of the one that's edited"
sketches!(m::Model, n) = begin
  e = m.engine
  active = editing(m)
  wanted = Int[Int(s["id"]) for s in sketch_list(m) if s isa JSON.Object && (get(s, "visible", false) === true || Int(s["id"]) == active)]
  for id in collect(keys(m.sketches))
    id in wanted || (delete!(m.sketches, id); m.version += 1)
  end
  for id in wanted
    Engines.call!(e, "execute", JSON.Object("command" => "sketch.inspect", "params" => JSON.Object("sketch" => id))) do answer, problem
      n == m.asked || return
      answer isa JSON.Object && (m.sketches[id] = answer; m.version += 1)
    end
  end
  if active === nothing
    isempty(m.glyphs) || (m.glyphs = Any[]; m.version += 1)
  else
    Engines.call!(e, "execute", JSON.Object("command" => "sketch.glyphs", "params" => JSON.Object())) do answer, problem
      n == m.asked || return
      m.glyphs = answer isa JSON.Object && get(answer, "glyphs", nothing) isa Vector ? answer["glyphs"] : Any[]
      m.version += 1
    end
  end
end

"""
Run the command `command` of SolidCraft on the design, then ask for the design
again. `then(answer, problem)` gets what the command said. A problem also
stays in `m.said`, for the editor to show.
"""
change!(m::Model, command::AbstractString, params=JSON.Object(); then=nothing, quiet=false) = free(m) do
  e = m.engine
  e === nothing && return
  m.said = ""
  # A change takes away what could be done again, and the steps after this one that could be taken back are other ones now
  empty!(m.rejoined)
  filter!(p -> p.first <= undos(m), m.joined)
  Engines.run!(e, command, params) do answer, problem
    problem === nothing || quiet || (m.said = problem)
    m.version += 1
    then === nothing || then(answer, problem)
  end
  refresh!(m)
end

"""
Make the steps that the program can take back since there were `before` of
them one change, after the editor made them for one thing that was asked of
it: ⌘Z takes them all back, and ⇧⌘Z does them all again. Call it when the
design's lists have come since the last of them.
"""
together!(m::Model, before) = begin
  now = undos(m)
  now - before > 1 && (m.joined[now] = now - before)
  m
end

"Run a command that changes nothing, and give `then` its answer"
ask!(then, m::Model, command::AbstractString, params=JSON.Object()) = free(() -> m.engine === nothing || Engines.run!(then, m.engine, command, params), m)

"""
Show or hide things of the design: those that `items` names, or everything of
the folder `folder`, which is `bodies`, `sketches`, `construction` or `origin`.
"""
show!(m::Model, visible::Bool; items=nothing, folder=nothing) = begin
  params = JSON.Object("visible" => visible)
  items === nothing || (params["items"] = items)
  folder === nothing || (params["folder"] = folder)
  change!(m, "browser.visibility", params; then=(answer, problem) -> begin
    # The program says that the origin shows only in the answer to this command
    answer isa JSON.Object && get(answer, "visibility", nothing) isa JSON.Object && (m.origin_hidden = origin_hidden(answer))
  end)
end

"""
Run `command` to see what it makes, then take it back. `m.trial` has what it
made when that's done: the bodies as the command leaves them, and the names
of those that it changes or adds. `key` says what was tried, so that the
editor knows what the trial is of.
"""
try!(m::Model, key, command::AbstractString, params) = begin
  e = m.engine
  (e === nothing || m.trying) && return m
  m.trying = true
  before = get(m.doc, "undo", 0)
  finish(shapes, colours, changed, problem) = begin
    m.trial = (key=key, shapes=shapes, colours=colours, changed=changed, problem=problem, made=nothing)
    m.trying = false
    m.version += 1
    waiting = copy(m.later)
    empty!(m.later)
    foreach(f -> f(), waiting)
  end
  none() = (Shape[], Dict{String,Vec3}())
  Engines.call!(e, "execute", JSON.Object("command" => command, "params" => params)) do answer, problem
    problem === nothing || return finish(none()..., String[], problem)
    changed = String[]
    for list in ("changed_bodies", "created_bodies"), name in (answer isa JSON.Object && get(answer, list, nothing) isa Vector ? answer[list] : Any[])
      name isa AbstractString && push!(changed, name)
    end
    # Only a command that made a step for Undo is taken back: an Undo after any other would take back the step before it
    Engines.call!(e, "execute", JSON.Object("command" => "document.inspect", "params" => JSON.Object("timeline" => false, "bodies" => false))) do doc, _
      made = doc isa JSON.Object && before isa Number && get(doc, "undo", 0) isa Number && doc["undo"] > before
      made || return finish(none()..., String[], "")
      export!(m, joinpath(m.room, "trial")) do shapes, colours
        Engines.call!(e, "undo") do _, _
          m.ghost = 1
          # A command that doesn't say which bodies it changes may have changed them all
          finish(shapes, colours, isempty(changed) ? String[s.name for s in shapes] : changed, "")
        end
      end
    end
  end
  m
end

"""
Show what Ladder worked out itself that the command `key` would make, in place
of a trial of SolidCraft's: see preview.jl. `made` has the pieces and how they
show. SolidCraft's program isn't asked anything.
"""
made!(m::Model, key, made) = begin
  m.trial = (key=key, shapes=made.shapes, colours=Dict{String,Vec3}(), changed=String[s.name for s in made.shapes], problem="", made=made)
  m.version += 1
  m
end

"Forget what the command that was last tried makes"
forget!(m::Model) = (m.trial === nothing || (m.trial = nothing; m.version += 1); m)

"Run several commands as one step, stopping at the first that fails. Each is `command => params`."
batch!(m::Model, steps; then=nothing) = free(m) do
  e = m.engine
  e === nothing && return
  m.said = ""
  list = Any[JSON.Object("command" => c, "params" => p) for (c, p) in steps]
  Engines.call!(e, "batch", JSON.Object("commands" => list)) do answer, problem
    problem === nothing || (m.said = problem)
    m.version += 1
    then === nothing || then(answer, problem)
  end
  refresh!(m)
end

undo!(m::Model) = step!(m, "undo")
redo!(m::Model) = step!(m, "redo")
step!(m::Model, tool) = free(m) do
  m.engine === nothing && return
  # A command that was tried and taken back is nothing to redo
  tool == "redo" && redoable(m) == 0 && return
  m.said = ""
  # Steps that the editor made as one change go back together, and come again together: see `together!`
  undo, redo = undos(m), redoable(m)
  n = tool == "undo" ? pop!(m.joined, undo, 1) : pop!(m.rejoined, redo, 1)
  n > 1 && (tool == "undo" ? (m.rejoined[redo + n] = n) : (m.joined[undo + n] = n))
  for _ in 1:n
    Engines.call!(m.engine, tool) do answer, problem
      problem === nothing || (m.said = problem)
    end
  end
  hidden!(m)
  refresh!(m)
end

"""
Ask whether the origin is hidden. An Undo can change that, and the program
says it only in a copy of the whole design, so this asks for one.
"""
hidden!(m::Model) = begin
  file = joinpath(m.room, "design.json")
  rm(file, force=true)
  Engines.call!(m.engine, "execute", JSON.Object("command" => "file.export", "params" => JSON.Object("path" => file, "format" => "json"))) do answer, problem
    isfile(file) || return
    hidden = try origin_hidden(JSON.parse_json(read(file, String), JSON.Object)) catch; return end
    hidden == m.origin_hidden || (m.origin_hidden = hidden; m.version += 1)
  end
end

"Write the design to its file. `then(problem)` gets nothing when it's written."
save!(m::Model; then=nothing) = free(m) do
  m.engine === nothing && return
  Engines.run!(m.engine, "file.save") do answer, problem
    problem === nothing ? (m.read = mtime(m.path)) : (m.said = problem)
    then === nothing || then(problem)
  end
  refresh!(m)
end

# --- numbers from a page ----------------------------------------------------------
#
# A design that a page shows takes the page's numbers: each parameter of the
# design that has the name of a sum on the page gets the sum's value. With
#
#     !`span = 70m`
#
# on the page, a parameter `span` of the design is 70000 mm. The values are
# only in the program. The file keeps its own.

"The parameters that the design's file at `path` names: each one's name, unit and expression. The lengths of the steps, like d1, aren't in it."
file_params(path::AbstractString) = begin
  doc = file_document(path)
  list = doc isa JSON.Object ? get(doc, "params", nothing) : nothing
  list isa Vector || return NamedTuple{(:name, :unit, :expr),NTuple{3,String}}[]
  [(name=String(p["name"]), unit=String(something(get(p, "unit", nothing), "mm")), expr=string(get(p, "expr", "")))
   for p in list if p isa JSON.Object && get(p, "name", nothing) isa AbstractString && get(p, "model", false) !== true]
end

"""
What the numbers `sums` of a page change in a design whose parameters are
`params`, as `parameters.change` takes it: the expression of each parameter
that has the name of a number. A page gives each number in SI units, so a
length is in metres and an angle in radians: 0.03 for a parameter in mm is
30 mm. A parameter that can't take its number keeps its own value.
"""
changes(params, sums) = begin
  out = Dict{String,String}()
  for p in params
    x = get(sums, p.name, nothing)
    text = x === nothing ? nothing : amount(x, p.unit)
    text === nothing || (out[p.name] = text)
  end
  out
end

"The units of a parameter that's a length"
const LENGTHS = ("mm", "cm", "m", "in", "ft")

"What SolidCraft reads for `x`, a number in SI units, in a parameter whose unit is `unit`, or nothing when the parameter can't take it"
amount(x::Bool, unit) = nothing
amount(x::Real, unit) = !isfinite(x) ? nothing :
  unit in LENGTHS ? written(1000x) * " mm" : unit in ("deg", "rad") ? written(x) * " rad" : unit == "" ? written(x) : nothing
amount(x::AbstractString, unit) = unit == "text" ? String(x) : nothing
amount(x, unit) = nothing

"A number as SolidCraft reads it, to a millionth"
written(x) = (r = round(Float64(x), digits=6); isinteger(r) && abs(r) < 1e15 ? string(Int(r)) : string(r))

"""
Give the design's parameters other values in the program: `changes` has each
name with its expression, as `changes` makes them. The file keeps its own,
unless the design is saved. What SolidCraft couldn't make with them is in
`m.said`.
"""
vary!(m::Model, changes) = begin
  (m.engine === nothing || isempty(changes)) && return m
  Engines.run!(m.engine, "parameters.change", JSON.Object("changes" => JSON.Object(changes))) do answer, problem
    m.said = problem === nothing ? unmade(answer) : problem
    m.version += 1
  end
  m
end

"What a change of parameters says of the steps that SolidCraft couldn't make after it, in words, or \"\" when it made them all"
unmade(answer) = begin
  errors = answer isa JSON.Object ? get(answer, "errors", nothing) : nothing
  errors isa Vector || return ""
  steps = unique(String(e["feature"]) for e in errors if e isa JSON.Object && get(e, "feature", nothing) isa AbstractString)
  isempty(steps) && return ""
  named = length(steps) <= 3 ? join(steps, ", ", " and ") : join(steps[1:2], ", ") * " and $(length(steps) - 2) more steps"
  "SolidCraft can't make $named with these numbers."
end
