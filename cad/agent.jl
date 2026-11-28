# What the editor of a SolidCraft design says to an agent, and the functions
# that it gives the agent's code: see for_agents.jl.
#
# An agent that's shown a `.sc` file knows nothing of it: the file is a zip
# archive, and the design that you see is held by SolidCraft's hidden program,
# with the changes that you haven't saved. So the agent never touches the
# file. In its code `shown` is the editor, and these functions read the
# design and run SolidCraft's own commands in the editor's program, so the
# design in the window changes as the agent works, and ⌘Z takes a change back.
#
#     bodies(shown)                                         # the names of the bodies
#     set!(shown, "altitude", "1200 km")                    # give a parameter another value
#     commands(shown, "fillet")                             # SolidCraft's commands that have that word
#     command(shown, "solid.fillet")                        # what one command takes
#     run!(shown, "solid.fillet"; edges=[[30, 22.5, 6]], radius=2)
#
# This file holds only what an agent may call. The sandbox takes this module
# as the agent's own, so each function here runs as it is. Each one does its
# work on the main thread, which owns the editor, and waits on the code's
# thread for SolidCraft's answer. Each gives back names, numbers and lists of
# the design as it was then, and never a part of the editor.

@use "../agent/for_agents" => Offer
@use "../agent/for_agents" Tool on_main
@use "./view" => Views
@use "./view" DesignView
@use "./design" => Designs
@use "./engine" => Engines
@use "./scene" => Scenes
@use "github.com/jkroso/JSON.jl" => JSON
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!

const LIMIT = 180                        # seconds that a function waits for SolidCraft's program

"The open design of `v`, or an error that says why there's none"
model(v::DesignView) = begin
  m = Views.load!(v)
  isempty(m.problem) || error(m.problem)
  m.engine === nothing && error("The design is closed.")
  m
end

"""
Wait, on the code's thread, until SolidCraft's program has answered all that
was asked of it, and the editor has the design's new lists. The main thread
takes the answers meanwhile, and draws.
"""
settle(v::DesignView) = begin
  from = time()
  while on_main(() -> waiting!(v))
    time() - from > LIMIT && error("SolidCraft's program didn't answer in $LIMIT seconds.")
    sleep(0.02)
  end
  nothing
end

"Take the answers that have come for the design of `v`, on the main thread, and say whether more are still to come"
waiting!(v::DesignView) = begin
  m = v.model
  m === nothing && return false
  Designs.tick!(m)
  window_of(v) === nothing || redraw_in!(v, 0.001)
  Designs.busy(m) || m.trying || !isempty(m.later)
end

"Ask SolidCraft's program with `start`, which is given the function that takes the answer and the problem, and wait for the answer. A problem is an error."
asked(start, v::DesignView) = begin
  got = Ref{Any}(nothing)
  on_main(() -> start(model(v), (answer, problem) -> (got[] = (answer, problem))))
  settle(v)
  got[] === nothing && error("SolidCraft's program gave no answer.")
  answer, problem = got[]
  problem === nothing || error(problem)
  answer
end

"`x` as SolidCraft's program takes it: a table with text for its keys, a list, text or a number"
plain(x::AbstractDict) = JSON.Object(String(string(k)) => plain(v) for (k, v) in x)
plain(x::NamedTuple) = JSON.Object(String(k) => plain(v) for (k, v) in pairs(x))
plain(x::Union{AbstractVector,Tuple}) = Any[plain(v) for v in x]
plain(x::Symbol) = String(x)
plain(x) = x

"A copy of what the program said, which no later answer changes"
kept(x::AbstractDict) = JSON.Object(k => kept(v) for (k, v) in x)
kept(x::AbstractVector) = Any[kept(v) for v in x]
kept(x) = x

"The names of the things in `list`, a list of the design"
names_of(list) = String[String(get(x, "name", "")) for x in list if x isa AbstractDict]

# --- what an agent calls ---

"The names of the design's bodies"
bodies(v::DesignView) = on_main(() -> names_of(Designs.bodies(model(v))))

"What SolidCraft says of the body called `name`: whether it shows, and the rest of its line of the design's lists"
body(v::DesignView, name::AbstractString) = on_main() do
  list = Designs.bodies(model(v))
  i = findfirst(b -> b isa AbstractDict && get(b, "name", "") == name, list)
  i === nothing && error("The design has no body called $name.")
  kept(list[i])
end

"The design's steps in order, as SolidCraft lists them: each has its `id`, its `name` and its `type`, like Sketch or Extrude"
steps(v::DesignView) = on_main(() -> kept(Designs.timeline(model(v))))

"The design's sketches, as SolidCraft lists them"
sketches(v::DesignView) = on_main(() -> kept(Designs.sketch_list(model(v))))

"The design's parameters: each has its `name`, its expression and what that comes to"
parameters(v::DesignView) = on_main(() -> (model(v); kept(Views.every_param(v))))

"What's selected in the editor: each thing's kind (body, face, edge, plane, step, point or curve), the name of what it's of, and a point on it"
selected(v::DesignView) = on_main(() -> Any[(kind=p.kind, of=p.of, at=p.at) for p in v.picked])

"""
SolidCraft's commands, each as its id and what it does. With `about`, only
those that have that word in their id or their words.
"""
commands(v::DesignView, about::AbstractString="") = on_main() do
  m = model(v)
  word = lowercase(about)
  lines = String[]
  for id in sort!(collect(keys(m.commands)))
    c = m.commands[id]
    does = something(get(c, "description", nothing), get(c, "title", nothing), get(c, "name", nothing), Some(""))
    line = isempty(string(does)) ? id : "$id: $does"
    (isempty(word) || occursin(word, lowercase(line))) && push!(lines, line)
  end
  lines
end

"What SolidCraft says of its command `id`, like `solid.fillet`: what it does and each thing that it takes"
command(v::DesignView, id::AbstractString) =
  kept(asked((m, then) -> Engines.call!(then, m.engine, "describe_command", JSON.Object("id" => String(id))), v))

"SolidCraft's own guide to its commands, for agents: how a face, an edge or a region of a sketch is named, and how a design is built. It's long, so give it a name and read parts of it."
reference(v::DesignView) = begin
  said = asked((m, then) -> Engines.call!(then, m.engine, "skill_reference"), v)
  said isa AbstractString ? String(said) : kept(said)
end

"""
Run SolidCraft's command `id` in the editor, and give its answer when the
design in the window has changed. What the command takes is `params`, a
table, or the names after the `;`. A command that SolidCraft can't do is an
error with SolidCraft's words. Each command that changes the design is a
step that ⌘Z takes back.
"""
run!(v::DesignView, id::AbstractString, params=(;); given...) = begin
  all = merge(plain(params isa NamedTuple ? params : Dict(params)), plain(values(given)))
  kept(asked((m, then) -> Designs.change!(m, String(id), all; quiet=true, then=then), v))
end

"Give the parameter `name` the expression `expression`, like \"1200 km\" or \"width / 2\", and give the steps that SolidCraft couldn't make with it, if any"
set!(v::DesignView, name::AbstractString, expression) =
  run!(v, "parameters.change"; name=String(name), expression=string(expression))

"Take back the last change to the design, as ⌘Z does"
undo!(v::DesignView) = (on_main(() -> (model(v); Views.undo!(v))); settle(v))

"Do again the change that was last taken back"
redo!(v::DesignView) = (on_main(() -> (model(v); Views.redo!(v))); settle(v))

"Write the design to its file. Do it only when the user asks: until then the changes are in the window alone, as the user's own are."
save!(v::DesignView) = (on_main(() -> (model(v); Views.save!(v))); settle(v))

const SIDES = Dict("front" => (-90.0, 0.0), "top" => (-90.0, 90.0), "right" => (0.0, 0.0), "home" => (-35.0, 28.0))

"Turn the design in the window to be seen from `side`: \"front\", \"top\", \"right\" or \"home\", with all of it in view. Call it before `look()` to see another side."
see!(v::DesignView, side::AbstractString) = on_main() do
  model(v)
  haskey(SIDES, lowercase(side)) || error("A side is one of front, top, right and home.")
  turn, tilt = SIDES[lowercase(side)]
  v.eye = Scenes.fit(Scenes.Eye(v.eye.target, turn, tilt, v.eye.distance, v.eye.wide), Scenes.box(Views.showing(v)), (max(v.area[3], 100.0), max(v.area[4], 100.0)))
  window_of(v) === nothing || redraw_in!(v, 0.001)
  nothing
end

# --- what the editor says of itself ---

Offer.about(v::DesignView) = "The window shows a SolidCraft design, a 3D model made of steps like sketches and extrudes, in Ladder's editor of designs. Its file, $(v.path), is a zip archive: never read it or change it. The editor holds the design, with the user's changes that aren't saved. Read the design and change it with the functions below, through the julia tool. A change shows in the user's window at once, and the user takes it back with ⌘Z. A length or an angle is an expression in text, like \"12 mm\" or \"width / 2\", which can use the design's parameters by name. A point is [x, y, z] in mm. Find a command with `commands(shown, \"word\")`, and read what it takes with `command(shown, id)` before you run it. After a change, call `look()` and read the picture to check what the user sees."

Offer.tools(v::DesignView) = Tool[
  Tool(bodies, "bodies(shown)", "The names of the design's bodies, as a list."),
  Tool(body, "body(shown, name)", "What SolidCraft says of one body."),
  Tool(steps, "steps(shown)", "The design's steps in order: each has its id, name and type."),
  Tool(sketches, "sketches(shown)", "The design's sketches."),
  Tool(parameters, "parameters(shown)", "The design's parameters: each has its name, its expression and its value."),
  Tool(selected, "selected(shown)", "What the user has selected in the editor: each thing's kind, what it's of, and a point on it."),
  Tool(set!, "set!(shown, name, expression)", "Give a parameter another expression, like set!(shown, \"altitude\", \"1200 km\"). The design is made again with it."),
  Tool(commands, "commands(shown, about=\"\")", "SolidCraft's commands, each as `id: what it does`. With a word, only the commands that have it. There are hundreds, so give a word."),
  Tool(command, "command(shown, id)", "What one command does and each thing that it takes."),
  Tool(run!, "run!(shown, id; name=value, …)", "Run a command of SolidCraft in the editor, like run!(shown, \"solid.fillet\"; edges=[[30, 22.5, 6]], radius=\"2 mm\"), and give its answer. A command that fails is an error with SolidCraft's words."),
  Tool(undo!, "undo!(shown)", "Take back the last change."),
  Tool(redo!, "redo!(shown)", "Do again the change that was taken back."),
  Tool(save!, "save!(shown)", "Write the design to its file. Only when the user asks."),
  Tool(see!, "see!(shown, side)", "Turn the design to be seen from \"front\", \"top\", \"right\" or \"home\", for the next look()."),
  Tool(reference, "reference(shown)", "SolidCraft's own long guide to its commands. Give it a name, and read parts of it.")]

"How many of something, in words: 1 body, 3 bodies"
count_words(n, one, many) = "$n $(n == 1 ? one : many)"

"What's selected in `v`, in words"
picked_words(v::DesignView) = begin
  isempty(v.picked) && return "Nothing is selected in it."
  things = String[p.kind in (:face, :edge) ? "$(p.kind == :face ? "a face" : "an edge") of the body \"$(p.of)\" at $(round.(collect(p.at), digits=2))" :
                  "the $(p.kind) \"$(p.of)\"" for p in v.picked]
  "Selected in it: " * join(things, ", ") * "."
end

Offer.status(v::DesignView) = on_main() do
  m = v.model
  m === nothing && return "The window shows a SolidCraft design, which isn't open yet."
  isempty(m.problem) || return "The window shows a SolidCraft design that Ladder couldn't open: $(m.problem)"
  lines = String["The window shows a SolidCraft design with " * join([count_words(length(Designs.bodies(m)), "body", "bodies"),
                   count_words(length(Designs.timeline(m)), "step", "steps"), count_words(length(Designs.sketch_list(m)), "sketch", "sketches"),
                   count_words(length(Views.every_param(v)), "parameter", "parameters")], ", ", " and ") * ".", picked_words(v)]
  open = Designs.editing(m)
  open === nothing || push!(lines, "The sketch of step $open is open for editing.")
  v.form === nothing || push!(lines, "The form of the command $(v.form.spec.command) is open.")
  Designs.edited(m) && push!(lines, "The design has changes that aren't in its file.")
  isempty(m.said) || push!(lines, "SolidCraft said of the last change: $(m.said)")
  join(lines, "\n")
end
