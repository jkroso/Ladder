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
# After each change it asks the program three things again: the design's
# lists (steps, bodies, sketches, parameters), the bodies as triangles, and
# each sketch that shows. While a sketch is being edited the bodies can't
# change, so they aren't asked for again until it's finished.
#
# `m.version` goes up each time any of that changes, so the editor knows when
# to draw again.

@use "./engine" => Engines
@use "./json" => JSON
@use "./scene" Shape read_obj

mutable struct Model
  path::String
  engine::Any                       # the hidden program, or nothing when there's none
  problem::String                   # why there's none, in words
  room::String                      # a folder of its own for the files that the program writes for Ladder
  doc::JSON.Object                  # the design's lists, as `document.inspect` gives them
  shapes::Vector{Shape}
  shapes_of::Any                    # what the shapes are of: they're asked for again when this changes
  sketches::Dict{Int,JSON.Object}   # each sketch that shows, as `sketch.inspect` gives it, by its step's number
  glyphs::Vector{Any}               # the marks of the constraints of the sketch that's being edited
  commands::Dict{String,JSON.Object}   # every command of SolidCraft, by its id
  version::Int
  asked::Int                        # the number of the last time the lists were asked for. An older answer is dropped.
  said::String                      # what went wrong with the last change, or ""
  read::Float64                     # when the file had last changed, as it was opened or saved
end

Model(path) = Model(path, nothing, "", "", JSON.Object(), Shape[], nothing, Dict{Int,JSON.Object}(), Any[], Dict{String,JSON.Object}(), 0, 0, "", 0.0)

"Open the design at `path`. With no SolidCraft on this Mac, the model says so in `problem`."
open_design(path::AbstractString) = begin
  m = Model(String(path))
  m.read = mtime(path)
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
  refresh!(m)
  finalizer(close!, m)
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

"Is the body `name` shown?"
shown(m::Model, name) = begin
  i = findfirst(b -> b isa JSON.Object && get(b, "name", "") == name, bodies(m))
  i === nothing ? true : get(bodies(m)[i], "visible", true) === true
end

"""
Ask the program for the design again: its lists, then its bodies and its
sketches. `then` is called when it has all come.
"""
refresh!(m::Model; then=nothing) = begin
  e = m.engine
  e === nothing && return m
  n = (m.asked += 1)
  Engines.call!(e, "execute", JSON.Object("command" => "document.inspect",
      "params" => JSON.Object("timeline" => true, "bodies" => true, "sketch_counts" => true))) do answer, problem
    # A newer change was asked for since: its answer will come
    n == m.asked || return
    if answer isa JSON.Object
      m.doc = answer
      m.version += 1
      shapes!(m)
      sketches!(m, n)
    else
      problem === nothing || (m.said = problem)
    end
    # What `then` asks for comes after what was asked for here
    then === nothing || Engines.call!((_, _) -> then(), e, "running")
  end
  m
end

"Ask for the bodies as triangles, when they can have changed"
shapes!(m::Model) = begin
  e = m.engine
  of = editing(m) === nothing ? (get(m.doc, "revision", 0), marker(m), length(bodies(m))) : (:sketch, editing(m), marker(m))
  of == m.shapes_of && return
  m.shapes_of = of
  if isempty(bodies(m))
    m.shapes = Shape[]
    m.version += 1
    return
  end
  file = joinpath(m.room, "bodies.obj")
  Engines.call!(e, "export", JSON.Object("path" => file)) do answer, problem
    of == m.shapes_of || return
    m.shapes = problem === nothing && isfile(file) ? read_obj(file) : Shape[]
    m.version += 1
  end
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
change!(m::Model, command::AbstractString, params=JSON.Object(); then=nothing, quiet=false) = begin
  e = m.engine
  e === nothing && return m
  m.said = ""
  Engines.run!(e, command, params) do answer, problem
    problem === nothing || quiet || (m.said = problem)
    m.version += 1
    then === nothing || then(answer, problem)
  end
  refresh!(m)
end

"Run a command that changes nothing, and give `then` its answer"
ask!(then, m::Model, command::AbstractString, params=JSON.Object()) = (m.engine === nothing || Engines.run!(then, m.engine, command, params); m)

"Run several commands as one step, stopping at the first that fails. Each is `command => params`."
batch!(m::Model, steps; then=nothing) = begin
  e = m.engine
  e === nothing && return m
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
step!(m::Model, tool) = begin
  m.engine === nothing && return m
  m.said = ""
  Engines.call!(m.engine, tool) do answer, problem
    problem === nothing || (m.said = problem)
  end
  refresh!(m)
end

"Write the design to its file. `then(problem)` gets nothing when it's written."
save!(m::Model; then=nothing) = begin
  m.engine === nothing && return m
  Engines.run!(m.engine, "file.save") do answer, problem
    problem === nothing ? (m.read = mtime(m.path)) : (m.said = problem)
    then === nothing || then(problem)
  end
  refresh!(m)
end
