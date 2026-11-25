# Ladder's way to Centient's books, for the takeoff block: the items of the
# catalogue, the contacts, and the quote that a takeoff makes.
#
# Centient has an MCP server, sidecar/mcp_server.jl, that runs Centient's own
# commands as a program of its own. This file starts that program the first
# time it's needed and sends it requests. Centient's app needn't be open.
#
#     r = ask("search_catalogue", Dict("query" => "conduit"))   # starts to ask
#     check!()                                                  # call it now and then, as each frame does
#     finished(r)                                               # true once there's an answer
#     r.value["items"], r.problem                               # the answer, or why there's none
#
# Nothing here waits. The program can take a few seconds to start, and the
# window goes on drawing while it does. The program's answers go into a file,
# and `check!` reads what's new in it.
#
# `available()` is false on a Mac that has no Centient. The places it looks:
# the folder that CENTIENT_SIDECAR names, the Centient app in /Applications,
# and Centient's source in ~/Desktop/Centient.

# --- JSON ----------------------------------------------------------------------
#
# The server speaks JSON. This is all of it that the two need, so that Ladder
# needs no package for it.

"`value` as JSON: a Dict, a list, a string, a number, true, false or nothing"
json(value) = sprint(json, value)
json(io::IO, s::AbstractString) = begin
  print(io, '"')
  for c in s
    c == '"' ? print(io, "\\\"") : c == '\\' ? print(io, "\\\\") : c == '\n' ? print(io, "\\n") :
    c == '\r' ? print(io, "\\r") : c == '\t' ? print(io, "\\t") :
    c < ' ' ? print(io, "\\u", string(UInt16(c), base=16, pad=4)) : print(io, c)
  end
  print(io, '"')
end
json(io::IO, ::Nothing) = print(io, "null")
json(io::IO, b::Bool) = print(io, b)
json(io::IO, n::Integer) = print(io, n)
json(io::IO, n::Real) = isfinite(n) ? print(io, Float64(n)) : print(io, "null")
json(io::IO, list::Union{AbstractVector,Tuple}) = begin
  print(io, '[')
  for (i, x) in enumerate(list)
    i > 1 && print(io, ',')
    json(io, x)
  end
  print(io, ']')
end
json(io::IO, d::AbstractDict) = begin
  print(io, '{')
  for (i, (k, v)) in enumerate(d)
    i > 1 && print(io, ',')
    json(io, string(k)); print(io, ':'); json(io, v)
  end
  print(io, '}')
end

"What the JSON in `text` says, or an error if it isn't JSON. A number comes as a Float64."
parse_json(text::AbstractString) = begin
  chars = collect(text)
  value, i = read_value(chars, blank(chars, 1))
  blank(chars, i) > length(chars) || error("There's more after the JSON")
  value
end

blank(chars, i) = begin
  while i <= length(chars) && chars[i] in (' ', '\t', '\n', '\r')
    i += 1
  end
  i
end

read_value(chars, i) = begin
  i <= length(chars) || error("The JSON stops early")
  c = chars[i]
  if c == '{'
    d = Dict{String,Any}()
    i = blank(chars, i + 1)
    chars[i] == '}' && return d, i + 1
    while true
      key, i = read_string(chars, blank(chars, i))
      i = blank(chars, i)
      chars[i] == ':' || error("A key of the JSON has no value")
      d[key], i = read_value(chars, blank(chars, i + 1))
      i = blank(chars, i)
      chars[i] == '}' && return d, i + 1
      chars[i] == ',' || error("The JSON has an object that doesn't end")
      i += 1
    end
  elseif c == '['
    list = Any[]
    i = blank(chars, i + 1)
    chars[i] == ']' && return list, i + 1
    while true
      x, i = read_value(chars, blank(chars, i))
      push!(list, x)
      i = blank(chars, i)
      chars[i] == ']' && return list, i + 1
      chars[i] == ',' || error("The JSON has a list that doesn't end")
      i += 1
    end
  elseif c == '"'
    read_string(chars, i)
  else
    j = i
    while j <= length(chars) && !(chars[j] in (',', '}', ']', ' ', '\t', '\n', '\r'))
      j += 1
    end
    word = String(chars[i:j-1])
    word == "null" ? (nothing, j) : word == "true" ? (true, j) : word == "false" ? (false, j) : (parse(Float64, word), j)
  end
end

read_string(chars, i) = begin
  (i <= length(chars) && chars[i] == '"') || error("The JSON has no string where one should be")
  out = IOBuffer()
  i += 1
  while chars[i] != '"'
    c = chars[i]
    if c == '\\'
      c = chars[i+1]
      i += 2
      if c == 'u'
        n = parse(UInt32, String(chars[i:i+3]), base=16)
        i += 4
        # A character past U+FFFF is written as two halves
        if 0xd800 <= n < 0xdc00 && i + 5 <= length(chars) && chars[i] == '\\' && chars[i+1] == 'u'
          low = parse(UInt32, String(chars[i+2:i+5]), base=16)
          n = 0x10000 + ((n - 0xd800) << 10) + (low - 0xdc00)
          i += 6
        end
        print(out, Char(n))
      else
        print(out, c == 'n' ? '\n' : c == 't' ? '\t' : c == 'r' ? '\r' : c == 'b' ? '\b' : c == 'f' ? '\f' : c)
      end
    else
      print(out, c)
      i += 1
    end
  end
  String(take!(out)), i + 1
end

# --- where Centient is -----------------------------------------------------------

const SERVER = "mcp_server.jl"
const IMAGE = "centient_sidecar.dylib"   # Centient's code, compiled. With it the server starts in a few seconds.

"The folders that can hold Centient's server, the likeliest first"
places() = begin
  named = get(ENV, "CENTIENT_SIDECAR", "")
  [(isempty(named) ? () : (named,))...,
   "/Applications/Centient.app/Contents/Resources/sidecar",
   joinpath(homedir(), "Applications", "Centient.app", "Contents", "Resources", "sidecar"),
   joinpath(homedir(), "Desktop", "Centient", "sidecar")]
end

"The folder of Centient's server on this Mac, or nothing"
sidecar() = begin
  i = findfirst(dir -> isfile(joinpath(dir, SERVER)), places())
  i === nothing ? nothing : places()[i]
end

"True when this Mac has a Centient that Ladder can work with"
available() = sidecar() !== nothing

"""
The command that runs the server in `dir`. The Centient app has a Julia of its
own beside its code. Centient's source is run with the Julia that the Mac has.
"""
command(dir) = begin
  runtime = joinpath(dirname(dir), "runtime")
  own = joinpath(runtime, "julia", "bin", "julia")
  up = joinpath(homedir(), ".juliaup", "bin", "julia")
  # Ladder's app has Julia's starter too, for its own image only: it has no image of Julia's to run a program with
  here = joinpath(Sys.BINDIR, "julia")
  whole = isfile(here) && isfile(normpath(Sys.BINDIR, "..", "lib", "julia", "sys." * Base.BinaryPlatforms.platform_dlext()))
  julia = isfile(own) ? own : isfile(up) ? up : whole ? here : "julia"
  image = joinpath(dir, IMAGE)
  cmd = isfile(image) ? `$julia -J$image --startup-file=no --compiled-modules=no $(joinpath(dir, SERVER))` :
                        `$julia --project=$dir $(joinpath(dir, SERVER))`
  cmd = Cmd(cmd, dir=dir)
  isfile(own) && isdir(joinpath(runtime, "depot")) ? addenv(cmd, "JULIA_DEPOT_PATH" => joinpath(runtime, "depot")) : cmd
end

# --- the server ------------------------------------------------------------------

"Something that Ladder asked the server for"
mutable struct Request
  tool::String
  done::Bool
  value::Any        # what the tool gave: a Dict
  problem::String   # why it gave nothing, in a sentence
end

finished(r::Request) = r.done
failed(r::Request) = r.done && !isempty(r.problem)

mutable struct Server
  process::Any                    # the program while it runs, or nothing
  input::Any                      # what Ladder writes its requests to
  out::String                     # the file that the program writes its answers into
  err::String                     # the file that it writes everything else into
  read::Int                       # how many bytes of `out` have been read
  part::String                    # the start of a line that the program hasn't finished yet
  next::Int                       # the number of the next request
  waiting::Dict{Int,Request}
  ready::Bool                     # the program has answered once, so the books are open
  company::String                 # the company whose books it opened, as Centient names it
  used::Float64                   # when a request was last sent
end

Server() = Server(nothing, nothing, "", "", 0, "", 1, Dict{Int,Request}(), false, "", 0.0)

const server = Server()
const IDLE = 15 * 60   # seconds with nothing asked, after which the program is stopped. It holds a lot of memory.
const PROTOCOL = "2026-07-28"
const META = Dict{String,Any}("io.modelcontextprotocol/protocolVersion" => PROTOCOL,
                              "io.modelcontextprotocol/clientInfo" => Dict{String,Any}("name" => "ladder", "version" => "1"))

running(s::Server=server) = s.process !== nothing && !process_exited(s.process)

"True once Julia has been told to stop Centient's program when Ladder quits"
const hooked = Ref(false)

"Start the program with `cmd`. It's false when it can't be started."
start!(s::Server, cmd::Cmd) = begin
  # Julia is told when the first program starts, and not when this file loads. An app that's
  # being built loads this file, and Julia takes no such hook then.
  hooked[] || (hooked[] = true; atexit(() -> stop!(server)))
  stop!(s)
  dir = mktempdir()
  s.out, s.err = joinpath(dir, "answers"), joinpath(dir, "log")
  s.read, s.part, s.ready, s.company = 0, "", false, ""
  try
    s.input = Pipe()
    s.process = run(pipeline(cmd, stdin=s.input, stdout=s.out, stderr=s.err), wait=false)
    close(s.input.out)   # the program has that end
  catch
    s.process = s.input = nothing
    return false
  end
  # The program's first answer says that the books are open
  send!(s, 0, "server/discover", Dict{String,Any}())
  true
end

send!(s::Server, id::Int, method::String, params::Dict{String,Any}) = begin
  params["_meta"] = META
  try
    println(s.input, json(Dict{String,Any}("jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params)))
    flush(s.input)
    true
  catch
    false   # the program has gone. `check!` says so to whoever waits.
  end
end

# The programs that were told to stop, and when. One that's still there a while later is killed.
const leaving = Tuple{Any,Float64}[]
const PATIENCE = 5   # seconds that a program has to stop by itself

"Kill the programs that were told to stop and haven't"
reap!() = filter!(leaving) do (process, since)
  process_exited(process) && return false
  time() - since < PATIENCE && return true
  try kill(process, Base.SIGKILL) catch end
  false
end

"Stop the program. What's waiting for an answer gets `why`."
stop!(s::Server=server, why="Centient's program stopped") = begin
  if s.process !== nothing
    # It stops by itself when it has nothing more to read. A signal to stop that came while
    # it was stopping could leave it half stopped for good, so it gets none unless it stays.
    try close(s.input) catch end
    process_exited(s.process) || push!(leaving, (s.process, time()))
    isempty(s.out) || rm(dirname(s.out), recursive=true, force=true)
  end
  s.process = s.input = nothing
  s.ready = false
  for r in values(s.waiting)
    r.done, r.problem = true, why
  end
  empty!(s.waiting)
  s
end

"""
Ask the server to run `tool` with `args`. The answer comes later: call `check!`
until the request is `finished`. `cmd` is the command that starts the server,
for a test that has a server of its own.
"""
ask(tool::AbstractString, args::AbstractDict=Dict{String,Any}(); s::Server=server, cmd=nothing) = begin
  r = Request(String(tool), false, nothing, "")
  if !running(s)
    dir = cmd === nothing ? sidecar() : ""
    dir === nothing && return (r.done = true; r.problem = "Centient isn't on this Mac"; r)
    start!(s, cmd === nothing ? command(dir) : cmd) || return (r.done = true; r.problem = "Ladder couldn't start Centient's program"; r)
  end
  id = s.next
  s.next += 1
  s.waiting[id] = r
  s.used = time()
  send!(s, id, "tools/call", Dict{String,Any}("name" => String(tool), "arguments" => Dict{String,Any}(string(k) => v for (k, v) in args)))
  r
end

"The last thing the program said that wasn't an answer, for when it stops with no reason given"
last_words(s::Server) = begin
  isfile(s.err) || return ""
  lines = filter(l -> !isempty(strip(l)) && !startswith(l, "CENTIENT:"), readlines(s.err))
  isempty(lines) ? "" : String(strip(first(last(lines), 200)))
end

"Take one line of the program's answers"
answer!(s::Server, line::AbstractString) = begin
  msg = try parse_json(line) catch; return end
  msg isa Dict || return
  id = get(msg, "id", nothing)
  id isa Real || return
  result, problem = get(msg, "result", nothing), get(msg, "error", nothing)
  if id == 0
    # The answer to the first request. An error there means that the books didn't open.
    if result isa Dict
      s.ready = true
      meta = get(result, "_meta", nothing)
      meta isa Dict && (s.company = string(something(get(meta, "au.com.centient/company", nothing), "")))
    elseif problem isa Dict
      stop!(s, string(get(problem, "message", "Centient's books didn't open")))
    end
    return
  end
  r = pop!(s.waiting, Int(id), nothing)
  r === nothing && return
  r.done = true
  if problem isa Dict
    r.problem = string(get(problem, "message", "Centient couldn't do that"))
  elseif result isa Dict && get(result, "isError", false) === true
    content = get(result, "content", Any[])
    r.problem = isempty(content) ? "Centient couldn't do that" : string(get(content[1], "text", "Centient couldn't do that"))
  elseif result isa Dict
    r.value = get(result, "structuredContent", nothing)
  else
    r.problem = "Centient gave an answer that Ladder can't read"
  end
  nothing
end

"""
Read the answers that have come since the last time. Call it in each frame
while a request waits. It's true while any request still waits, so the caller
knows to look again soon.
"""
check!(s::Server=server) = begin
  isempty(leaving) || reap!()
  s.process === nothing && return false
  if isfile(s.out) && filesize(s.out) > s.read
    new = open(s.out) do io
      seek(io, s.read)
      read(io)
    end
    s.read += length(new)
    lines = split(s.part * String(new), '\n')
    s.part = String(pop!(lines))   # a line that's whole ends with a line end, so the last piece is the start of the next
    foreach(line -> answer!(s, line), lines)
  end
  if s.process !== nothing && process_exited(s.process)
    words = last_words(s)
    stop!(s, isempty(words) ? "Centient's program stopped" : "Centient's program stopped: " * words)
  elseif isempty(s.waiting) && time() - s.used > IDLE
    stop!(s)
  end
  !isempty(s.waiting)
end

export available, ask, check!, finished, failed, stop!, running, Request, server, json, parse_json
