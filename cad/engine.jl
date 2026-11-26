# The hidden SolidCraft program. A SolidCraft design is a list of steps:
# sketches, extrudes, cuts. SolidCraft works out the solid shapes from them.
# Ladder has no code of its own that does, so it starts the program that
# SolidCraft.app has inside it for this, `solidcraft-cli`, with no window, and
# sends it each change that you make in Ladder's editor:
#
#     e = start("bracket.sc")                 # the program opens the design
#     ask(e, "document.inspect")              # one of SolidCraft's commands, and its answer
#     run!(e, "solid.box", Dict(...)) do answer, problem ... end   # the same, without waiting
#     stop!(e)
#
# The two talk in lines of JSON, as the Model Context Protocol says: a request
# with a number, and later the answer with that number. A command can take
# seconds, so a window never waits for one. `run!` gives the answer to a
# function when it has come, and `pump!` calls the functions of the answers
# that have come: the editor calls it in each frame.
#
# `available()` says whether this Mac has SolidCraft.app.

@use "../json" => JSON

const NAME = "solidcraft-cli"

"A folder that has `solidcraft-cli`, in place of the ones this looks in. A test names one of its own."
const PLACE = Ref("")

"The path of SolidCraft's program on this Mac, or nothing when SolidCraft isn't installed"
program() = begin
  places = String[]
  isempty(PLACE[]) || push!(places, joinpath(PLACE[], NAME))
  haskey(ENV, "SOLIDCRAFT_CLI") && push!(places, ENV["SOLIDCRAFT_CLI"])
  push!(places, "/Applications/SolidCraft.app/Contents/MacOS/$NAME", joinpath(homedir(), "Applications", "SolidCraft.app", "Contents", "MacOS", NAME))
  i = findfirst(isfile, places)
  i === nothing ? Sys.which(NAME) : places[i]
end

available() = program() !== nothing

"The hidden program with one design open"
mutable struct Engine
  path::String                  # the design's file
  process::Any
  next::Int                     # the number of the next request
  waiting::Dict{Int,Any}        # the function that gets each answer, by its request's number
  ready::Vector{Any}            # the answers that have come, each with its function
  stopped::String               # why the program isn't running any more, or ""
  sent::Int                     # how many commands that change the design were sent
end

"How many requests have no answer yet"
busy(e::Engine) = length(e.waiting) + length(e.ready)

"""
Start the program on the design at `path`. It reads and writes files only in
the design's folder and in `rooms`, the other folders that are named.
"""
start(path::AbstractString; rooms=String[]) = begin
  cli = program()
  cli === nothing && error("SolidCraft isn't installed on this Mac.")
  allowed = vcat(["--allow-path", dirname(abspath(path))], reduce(vcat, [["--allow-path", r] for r in rooms], init=String[]))
  # A path with no file yet starts an empty design, which `file.save` with that path then writes
  design = isfile(path) ? ["--in", abspath(path)] : String[]
  process = open(pipeline(`$cli mcp --headless $design $allowed`, stderr=devnull), "r+")
  e = Engine(abspath(path), process, 0, Dict{Int,Any}(), Any[], "", 0)
  @async listen(e)
  send(e, "initialize", JSON.Object("protocolVersion" => "2024-11-05", "capabilities" => JSON.Object(),
                                    "clientInfo" => JSON.Object("name" => "Ladder", "version" => "1"))) do _, _
    note(e, "notifications/initialized")
  end
  e
end

"Read the program's answers until it ends"
listen(e::Engine) = begin
  try
    while !eof(e.process)
      line = readline(e.process)
      isempty(line) && continue
      m = try JSON.parse(line) catch; continue end
      m isa JSON.Object && haskey(m, "id") || continue
      f = pop!(e.waiting, Int(m["id"]), nothing)
      f === nothing || push!(e.ready, (f, m))
    end
  catch
  end
  isempty(e.stopped) && (e.stopped = "SolidCraft's program stopped.")
  # What was asked gets no answer now
  for (_, f) in e.waiting
    push!(e.ready, (f, JSON.Object("error" => JSON.Object("message" => e.stopped))))
  end
  empty!(e.waiting)
end

write_line(e::Engine, m) = begin
  isempty(e.stopped) || return false
  try
    write(e.process, JSON.json(m), '\n')
    flush(e.process)
    true
  catch
    e.stopped = "SolidCraft's program stopped."
    false
  end
end

note(e::Engine, method) = write_line(e, JSON.Object("jsonrpc" => "2.0", "method" => method))

"Send a request, and give `f` its answer and its problem: one of the two is nothing"
send(f, e::Engine, method, params) = begin
  id = (e.next += 1)
  e.waiting[id] = (m) -> haskey(m, "error") ? f(nothing, String(get(m["error"], "message", "It failed."))) : f(m["result"], nothing)
  write_line(e, JSON.Object("jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params)) ||
    (pop!(e.waiting, id); push!(e.ready, (m -> f(nothing, e.stopped), JSON.Object())))
  e
end

"What a tool of the program said: its text read as JSON when it is JSON"
told(result) = begin
  texts = [String(c["text"]) for c in get(result, "content", Any[]) if c isa JSON.Object && get(c, "type", "") == "text"]
  text = join(texts, "\n")
  failed = get(result, "isError", false) === true
  value = try JSON.parse(text) catch; text end
  failed ? (nothing, value isa String ? value : text) : (value, nothing)
end

"Call the tool `tool` of the program, and give `f` its answer and its problem"
call!(f, e::Engine, tool::AbstractString, args=JSON.Object()) =
  send(e, "tools/call", JSON.Object("name" => tool, "arguments" => args)) do result, problem
    problem === nothing ? f(told(result)...) : f(nothing, problem)
  end

"Run SolidCraft's command `command`, like `solid.extrude`, and give `f` its answer and its problem"
run!(f, e::Engine, command::AbstractString, params=JSON.Object()) = begin
  e.sent += 1
  call!(f, e, "execute", JSON.Object("command" => command, "params" => params))
end
run!(e::Engine, command::AbstractString, params=JSON.Object()) = run!((_, _) -> nothing, e, command, params)

"Give each answer that has come to its function"
pump!(e::Engine) = begin
  yield()
  while !isempty(e.ready)
    f, m = popfirst!(e.ready)
    try
      f(m)
    catch err
      @error "An answer of SolidCraft's program wasn't taken" exception=(err, catch_backtrace())
    end
  end
  e
end

"Wait for every answer. A test and a script call this. A window never does."
settle!(e::Engine; limit=60) = begin
  from = time()
  while busy(e) > 0
    time() - from > limit && error("SolidCraft's program didn't answer in $limit seconds.")
    pump!(e)
    busy(e) > 0 && sleep(0.002)
  end
  e
end

"Run `command` and wait for its answer. It throws the problem, if the command has one."
ask(e::Engine, command::AbstractString, params=JSON.Object(); limit=60) = begin
  got = Ref{Any}(nothing)
  run!(e, command, params) do answer, problem
    got[] = (answer, problem)
  end
  settle!(e; limit)
  answer, problem = got[]
  problem === nothing || error(problem)
  answer
end

"Call a tool and wait for its answer"
tell(e::Engine, tool::AbstractString, args=JSON.Object(); limit=60) = begin
  got = Ref{Any}(nothing)
  call!(e, tool, args) do answer, problem
    got[] = (answer, problem)
  end
  settle!(e; limit)
  answer, problem = got[]
  problem === nothing || error(problem)
  answer
end

"End the program. What it didn't save is lost."
stop!(e::Engine) = begin
  isempty(e.stopped) && (e.stopped = "The design was closed.")
  try close(e.process.in) catch end
  try kill(e.process) catch end
  nothing
end
