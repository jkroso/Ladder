# The Julia code that an agent runs inside Ladder.
#
# An agent that works beside a page, in agent mode, has a tool called `julia`.
# The tool runs code in Ladder itself, so the agent can ask the thing that
# the window shows what it is, and change it while you watch: see
# for_agents.jl. Each session has a module of its own. A name that the agent
# gives a value keeps it for the session, so the agent can hold a long list
# by a name and never read it.
#
#     r = Repl("Claude", dir; shown=() -> thing, look=() -> "/tmp/window.png", ask=(action, code) -> true)
#     run_code(r, "length(bodies(shown))")      # ("81", false): the words of what it comes to, and whether it failed
#     command(r)                                # the command that an agent's program starts to reach the tool
#     close!(r)
#
# How the agent's program reaches it: the Model Context Protocol (MCP), which
# is how the programs of agents take tools. Ladder listens on a socket in a
# folder that only you can read, one for each session. The agent's program
# starts `nc -U` on that socket once, as its tool server, and the two talk in
# lines of JSON through it for the whole session. So a call of the tool starts
# no program.
#
# The code runs in a thread of its own, one piece at a time for a session, so
# code that takes long doesn't stop the window. It runs in the sandbox of
# guard.jl, as the code of a web page does. The sandbox lets sums, text and
# lists go on, and each function that the thing in the window offers. Before
# anything else that could harm, like changing a file, starting a program or
# reaching into a part of Ladder, the code waits while Ladder asks you, with
# `ask`. A yes lasts for the session.
#
# What the code comes to goes back to the agent as text, cut short when it's
# long. That's why a name is worth more than a look: `cells = bodies(shown)`
# costs the agent one line.

@use "../code/guard" => Guard
@use "./for_agents" => Offer
@use "github.com/jkroso/JSON.jl" => JSON
@use Sockets

const NC = "/usr/bin/nc"                 # the program that joins an agent's program to the socket
const MOST = 4000                        # how many characters of what the code comes to go back to the agent, unless it asks for more
const MOST_EVER = 60_000                 # and the most that it can ask for

"""
The Julia code of one session of an agent: the module that it runs in, its
sandbox, and the socket that the agent's program reaches it by. `shown` gives
the thing that the window shows now, `look` saves a picture of the window and
gives its path, and `ask` asks you whether the code may do what the sandbox
stopped: it's given the action and the code, and gives true or false when
you've said. `shown` and `look` are called on the main thread. `ask` is
called on the code's thread, and waits there.
"""
mutable struct Repl
  name::String                   # the agent's name
  dir::String                    # the folder that the agent works in. The code reads its files without asking.
  m::Module
  context::Any                   # the Guard.Context of the code
  shown::Any
  look::Any
  ask::Any
  yes::Set{String}               # the keys of the actions that you allowed in this session
  socket::String
  server::Any
  talks::Vector{Any}             # each program that's connected now
  lock::ReentrantLock            # one piece of code runs at a time
  code::String                   # the code that runs now
  runs::Int                      # how many pieces have run
  guided::Set{Any}               # the kinds of thing that the agent was told of: see `guide_once!` in agent/session.jl
end

"""
What the sandbox asks for the answer of an agent's code. By an action's key it
says only what you already allowed. When the code is about to do the action,
`Guard.answer_now` asks you and waits.
"""
struct Asker
  of::Repl
end
(a::Asker)(key::AbstractString) = key in a.of.yes ? true : nothing
Guard.answer_now(a::Asker, action::Guard.Action) = begin
  r = a.of
  action.key in r.yes && return true
  r.ask(action, r.code) === true || return false
  push!(r.yes, action.key)
  true
end

Repl(name::AbstractString, dir::AbstractString; shown=() -> nothing, look=nothing, ask=(action, code) -> false) = begin
  m = Module(:Agent)
  r = Repl(String(name), String(dir), m, nothing, shown, look, ask, Set{String}(), "", nothing, Any[], ReentrantLock(), "", 0, Set{Any}())
  r.context = Guard.Context(Guard.Site("the code of $name", String(dir), Asker(r)), m, Module[Offer])
  # What every session's code has, whatever the window shows
  for (name, f) in (:guide => Offer.guide, :status => Offer.status, :look => Offer.look, :print => Offer.say, :println => Offer.sayln)
    Core.eval(m, Expr(:(=), name, f))
  end
  Core.eval(m, :(shown = nothing))
  r
end

"""
Give the code of `r` the thing `thing` as `shown`, and each function that it
offers by its name. The sandbox takes the module of such a function as the
code's own, so the function runs as it is.
"""
offer!(r::Repl, thing) = begin
  Core.eval(r.m, Expr(:(=), :shown, QuoteNode(thing)))
  for t in Offer.tools(thing)
    Core.eval(r.m, Expr(:(=), nameof(t.f), t.f))
    home = parentmodule(t.f)
    home in r.context.also || push!(r.context.also, home)
  end
  r
end

"`text`, or its first `most` characters with a line that says how much more there is"
cut_short(text::AbstractString, most::Integer) = begin
  n = length(text)
  n <= most && return String(text)
  first(text, most) * "\n… cut short: $(n - most) more characters. Give the value a name and look at the part that you need, or ask for more with `most`."
end

"What `value` shows as, for an agent to read: text as it is, and anything else as the REPL shows it, a long list with its middle left out"
words_of(value) = value === nothing ? "" : value isa AbstractString ? String(value) :
  sprint(io -> show(IOContext(io, :limit => true, :displaysize => (30, 160)), MIME"text/plain"(), value))

"What went wrong with the code, for the agent to read"
problem_words(err) = err isa ErrorException ? first(err.msg, 2000) : err isa Guard.Stopped ? sprint(showerror, err) * " The user didn't allow it in Ladder." :
  first(sprint(showerror, err), 2000)

"What's wrong with the code `code` when Julia can't read it, in words, or nothing"
syntax_problem(code::AbstractString) = begin
  for x in Meta.parseall(code; filename="julia").args
    Meta.isexpr(x, :error) || Meta.isexpr(x, :incomplete) || continue
    e = isempty(x.args) ? "" : x.args[1]
    return e isa Exception ? sprint(showerror, e) : "Julia can't read the code: $e"
  end
  nothing
end

"""
Run the code `code` for the session of `r`, and give the words that go back
to the agent, with true when the code failed. The words are what the code
printed and then what it comes to, at most `most` characters. This waits for
the code, so call it from a thread that can wait: `call` does.
"""
run_code(r::Repl, code::AbstractString; most::Integer=MOST) = lock(r.lock) do
  out = IOBuffer()
  said, failed = "", false
  r.code = String(code)
  r.runs += 1
  try
    wrong = syntax_problem(code)
    wrong === nothing || error(wrong)
    offer!(r, Offer.on_main(r.shown))
    value = Base.ScopedValues.with(Offer.OUT => out, Offer.LOOK => r.look) do
      Guard.run_code(r.context, code, "julia")
    end
    said = Base.invokelatest(words_of, value)
  catch err
    failed = true
    said = problem_words(err)
  end
  text = join(filter(!isempty, [rstrip(String(take!(out)), '\n'), said]), "\n")
  (isempty(text) ? "It ran, and came to nothing." : cut_short(text, clamp(most, 100, MOST_EVER)), failed)
end

# --- the socket ---

"What the agent is told of the tool, by its program"
const TOOL = JSON.Object(
  "name" => "julia",
  "description" => "Run Julia code inside Ladder, the app whose window the user looks at. The code runs in a module that is yours for this session, so a name that you give a value keeps it for later calls. `shown` is the thing that the window shows now. `guide(shown)` says what it is and lists the functions that read it and change it. `status(shown)` says what it shows now. `look()` saves a picture of the window and gives the PNG file's path, for you to read. The answer is what the code printed and what its last expression comes to, cut short when long: give a big value a name, and look at the part that you need. The code runs in a sandbox, and Ladder asks the user before a step that could harm.",
  "inputSchema" => JSON.Object(
    "type" => "object",
    "properties" => JSON.Object(
      "code" => JSON.Object("type" => "string", "description" => "The Julia code to run"),
      "most" => JSON.Object("type" => "integer", "description" => "The most characters of the answer to give back. $MOST when you don't say.")),
    "required" => Any["code"]))

"""
Listen for the program of the agent of `r` on a socket of its own, and give
`r`. The socket's folder is one that only you can read.
"""
serve!(r::Repl) = begin
  r.server === nothing || return r
  # A socket's path can have only about 100 characters, which the Mac's own folder of temporary files can pass
  dir = mktempdir()
  length(joinpath(dir, "julia")) < 100 || (dir = mktempdir("/tmp"))
  chmod(dir, 0o700)
  r.socket = joinpath(dir, "julia")
  server = r.server = Sockets.listen(r.socket)
  @async while isopen(server)
    talk = try Sockets.accept(server) catch; break end
    push!(r.talks, talk)
    @async hear(r, talk)
  end
  r
end

"The command that an agent's program starts as the tool server of `r`: the program and what it's given"
command(r::Repl) = (serve!(r); (NC, ["-U", r.socket]))

"Read each line that the agent's program sends through `talk`, and answer it. A call of the tool is answered when its code has run, and other lines are answered meanwhile."
hear(r::Repl, talk) = begin
  writing = ReentrantLock()
  try
    for line in eachline(talk)
      m = try JSON.parse_json(line, JSON.Object) catch; continue end
      m isa AbstractDict && haskey(m, "id") && haskey(m, "method") || continue
      # A request's number comes back as it came: 3, and not 3.0
      id = m["id"]
      id isa AbstractFloat && isinteger(id) && (id = Int(id))
      @async begin
        said = try
          JSON.Object("jsonrpc" => "2.0", "id" => id, "result" => answer(r, String(m["method"]), get(m, "params", nothing)))
        catch err
          JSON.Object("jsonrpc" => "2.0", "id" => id,
                      "error" => JSON.Object("code" => err isa Unknown ? -32601 : -32603, "message" => sprint(showerror, err)))
        end
        try lock(() -> (write(talk, JSON.json(said), '\n'); flush(talk)), writing) catch end
      end
    end
  catch
  end
  filter!(t -> t !== talk, r.talks)
  try close(talk) catch end
  nothing
end

"The error of a request that this server doesn't know"
struct Unknown <: Exception
  method::String
end
Base.showerror(io::IO, e::Unknown) = print(io, "Ladder has no method ", e.method, ".")

"The answer to the request `method` of the agent's program, with `params`"
answer(r::Repl, method::String, params) = begin
  if method == "initialize"
    version = params isa AbstractDict ? get(params, "protocolVersion", "2024-11-05") : "2024-11-05"
    JSON.Object("protocolVersion" => version, "capabilities" => JSON.Object("tools" => JSON.Object()),
                "serverInfo" => JSON.Object("name" => "ladder", "version" => "1"))
  elseif method == "tools/list"
    JSON.Object("tools" => Any[TOOL])
  elseif method == "tools/call"
    call(r, params)
  elseif method == "ping"
    JSON.Object()
  else
    throw(Unknown(method))
  end
end

"Run the code of a call of the tool in a thread of its own, and give the tool's answer when it has run"
call(r::Repl, params) = begin
  given = params isa AbstractDict ? get(params, "arguments", nothing) : nothing
  code = given isa AbstractDict ? get(given, "code", nothing) : nothing
  (params isa AbstractDict && get(params, "name", "") == "julia" && code isa AbstractString) ||
    return JSON.Object("content" => Any[JSON.Object("type" => "text", "text" => "Call the tool `julia` with `code`, the Julia code to run.")], "isError" => true)
  most = get(given, "most", MOST)
  most = most isa Real && isfinite(most) ? round(Int, most) : MOST
  text, failed = fetch(Threads.@spawn run_code(r, code; most=most))
  JSON.Object("content" => Any[JSON.Object("type" => "text", "text" => text)], "isError" => failed)
end

"End the talk with each program that's connected to `r`, so that its `nc` ends. A program that starts later connects again."
hang_up!(r::Repl) = begin
  for talk in copy(r.talks)
    try close(talk) catch end
  end
  empty!(r.talks)
  r
end

"End the session of `r`: nothing reaches its code any more"
close!(r::Repl) = begin
  hang_up!(r)
  r.server === nothing || try close(r.server) catch end
  r.server = nothing
  isempty(r.socket) || try rm(dirname(r.socket), recursive=true, force=true) catch end
  r.socket = ""
  r
end
