# Holds pages of a web site in WebKit with nothing on the screen, signed in as
# you, and takes what the site sends them. WebKit is the part of macOS that
# draws web pages, and Safari uses it.
#
# A site like x.com gives its posts only to its own pages, in a browser that's
# signed in. A viewer of Ladder's for such a site can't ask the site's server
# as Ladder asks for a page of Markdown. So it opens the site's real page
# here, where nobody sees it, and reads what the site sends that page:
#
#     site = Hidden.site("x.com")
#     Hidden.open!(site, "home", "https://x.com/home", capture="/i/api/")
#     for event in Hidden.events!(site)
#       event["event"] == "data" && read_posts(Hidden.body!(event))
#     end
#
# A site has a store, which keeps what the site keeps in a browser, like the
# cookie that says who you are. The store is on the Mac, in WebKit's own
# folder, and it's the site's own: a site sees nothing that another keeps.
# `sign_in!` opens a window on the screen at the site's sign-in page, and the
# store keeps who you are from then on. The window closes by itself when you
# have signed in. `sign_out!` empties the store.
#
# A page has a name, like "home", and `open!` shows an address in it. Each
# answer that the site sends the page's own code, from an address that matches
# `capture`, comes as an event, and so does what `run!` gets from JavaScript
# that it runs in the page. `events!` gives the events since it was last
# asked, so a view asks in each frame while it waits.
#
# hiddenpage.swift holds the pages, as a program of its own, because macOS
# only offers WebKit to Swift and Objective-C. A site's program starts when
# the site is first told something, and it ends when Ladder does. When Ladder
# runs as an app, the program is in the app. When Ladder runs from its source,
# it compiles hiddenpage.swift the first time it's needed, which takes a few
# seconds and needs Swift on the Mac. The app and a run from the source each
# have stores of their own, so you sign in once in each.

@use "../swift" => Swift
@use "github.com/jkroso/JSON.jl" parse_json write_json

const SOURCE = joinpath(@__DIR__, "hiddenpage.swift")

"""
The name of the program's file in a run from the source. WebKit keeps a
program's stores in a folder of the program's name, so the name is the same
whatever the source says, and a change to the source signs you out of nothing.
"""
const PROGRAM = "ladder-hiddenpage"

"Compile hiddenpage.swift into the program at `out`. The app's build runs it."
compile(out) = Swift.compile(SOURCE, out)

"The folder that keeps the files that the program of the store `name` writes, until Ladder has read them"
folder(name::AbstractString) = joinpath(Swift.programs(), "hidden", replace(name, r"[^\w.\-]" => "_"))

"""
The command that runs the program with `args`: the program in the app, or the
one compiled from the source, which is kept in a folder of `dir` that's named
for the source. If that isn't compiled yet, the command compiles it first.
"""
command(args; dir=Swift.programs()) = begin
  kept = Swift.bundled("hiddenpage")
  kept === nothing || return `$kept $args`
  mine = "hiddenpage-" * string(hash(read(SOURCE)), base=16)
  program = joinpath(dir, mine, PROGRAM)
  isfile(program) && return `$program $args`
  mkpath(dirname(program))
  # A program compiled from older source isn't needed
  foreach(f -> startswith(f, "hiddenpage-") && f != mine && rm(joinpath(dir, f), force=true, recursive=true), readdir(dir))
  # It's compiled to a name of this run's own and renamed once it's whole, so a program that's there is always whole
  script = """swiftc -O -parse-as-library -target $(Swift.target()) "\$1" -o "\$2.\$\$" && mv "\$2.\$\$" "\$2" && p="\$2" && shift 2 && exec "\$p" "\$@" """
  `sh -c $script sh $SOURCE $program $args`
end

"""
A web site as a browser that nobody sees has it: its store, and the program
that holds its pages while it runs. `signed` is whether the store says who you
are: nothing until the program has said. `asking` is true while the sign-in
window is open. `problem` is why the program ended, when it shouldn't have.
"""
mutable struct Site
  name::String
  process::Any            # the program as it runs, or nothing
  to::Any                 # what Ladder writes its commands to
  events::Vector{Dict{String,Any}}   # what the program has said that `events!` hasn't given yet
  signed::Union{Bool,Nothing}
  asking::Bool
  problem::String
  count::Int              # how many times `run!` has asked
end

Site(name::AbstractString) = Site(String(name), nothing, nothing, Dict{String,Any}[], nothing, false, "", 0)

"Each site that Ladder has made, by the name of its store"
const SITES = Dict{String,Site}()

"The site whose store is called `name`, like \"x.com\". One name is one site, in every window."
site(name::AbstractString) = get!(() -> Site(name), SITES, String(name))

"True while the program of `s` runs"
running(s::Site) = s.process !== nothing && process_running(s.process)

"""
Start the program of the site `s`: `(process, to, out)`, the program as it
runs, what its commands are written to, and what its lines are read from. A
test puts a function of its own here, so that it uses neither the program nor
the web.
"""
start_program(s::Site) = begin
  to, out = Pipe(), Pipe()
  dir = folder(s.name)
  mkpath(dir)
  process = run(pipeline(command([s.name, dir]), stdin=to, stdout=out, stderr=joinpath(dir, "problem.txt")), wait=false)
  close(out.in)   # only the program writes to it now, so reading ends when the program does
  close(to.out)
  (process, to, out)
end
const STARTER = Ref{Any}(start_program)

"Start the program of `s`, if it doesn't run. A task reads each line that it prints."
start!(s::Site) = begin
  running(s) && return s
  s.problem = ""
  process, to, out = try
    STARTER[](s)
  catch err
    s.problem = "Ladder couldn't start the program that holds a site's pages: " * sprint(showerror, err)
    return s
  end
  s.process, s.to = process, to
  @async begin
    try
      for line in eachline(out)
        event = try parse_json(line) catch; nothing end
        event isa AbstractDict && said!(s, event)
      end
    catch
    end
    try wait(process) catch end
    s.process === process && ended!(s, process)
  end
  s
end

"The program of `s` ended. Keep why, when it didn't end because Ladder told it to."
ended!(s::Site, process) = begin
  s.process, s.to, s.asking = nothing, nothing, false
  code = try process.exitcode catch; 0 end
  code == 0 && return s
  wrote = try strip(read(joinpath(folder(s.name), "problem.txt"), String)) catch; "" end
  s.problem = code == 127 ? "Ladder needs Swift to show this site. It comes with Xcode's command line tools." :
              isempty(wrote) ? "The program that holds the site's pages stopped." : String(replace(last(split(wrote, '\n')), r"^error: " => ""))
  said!(s, Dict{String,Any}("event" => "stopped", "why" => s.problem))
  s
end

"""
The program of `s` said `event`. It's kept for `events!`, and what it says of
signing in is kept in `s`. A test calls this to stand in for the program.
"""
said!(s::Site, event::AbstractDict) = begin
  kind = get(event, "event", "")
  kind == "signed" && (s.signed = get(event, "in", false) === true)
  kind == "signin" && (s.asking = get(event, "open", false) === true)
  push!(s.events, Dict{String,Any}(String(k) => v for (k, v) in event))
  s
end

"Tell the program of `s` to do `command`, which starts it if it doesn't run. False when it can't be told."
tell!(s::Site, command::AbstractDict) = begin
  start!(s)
  s.to === nothing && return false
  try
    write(s.to, write_json(command) * "\n")
    flush(s.to)
    true
  catch
    false
  end
end

"""
Show the address `url` in the page of `s` called `page`. A name that's new
makes a page. Each answer that the site sends the page's own code, from an
address that matches the regular expression `capture`, comes as an event:

    Dict("event" => "data", "page" => "home", "url" => "https://…", "status" => 200, "file" => "…")

`body!` gives the answer's text. A page keeps the `capture` that it was made
with. When the page has loaded, the event is "loaded" with its `url`, which is
another address when the site moved the page, as it does to its sign-in page.
"failed" has `why`.
"""
open!(s::Site, page::AbstractString, url::AbstractString; capture::AbstractString="") =
  tell!(s, Dict("do" => "open", "page" => page, "url" => url, "capture" => capture))

"""
Run the JavaScript `js` in the page of `s` called `page`, as the body of a
function that can `await`. It gives a number, and what the code returns comes
as an event with that number as its `id`:

    Dict("event" => "value", "page" => "home", "id" => 7, "value" => "Home / X")

The value is text, a number, true or false, and anything else as the text
that JSON.stringify makes of it. Code that threw has `error` in place of
`value`.
"""
run!(s::Site, page::AbstractString, js::AbstractString) = begin
  s.count += 1
  tell!(s, Dict("do" => "run", "page" => page, "id" => s.count, "js" => js))
  s.count
end

"End the page of `s` called `page`"
close!(s::Site, page::AbstractString) = running(s) && tell!(s, Dict("do" => "close", "page" => page))

"""
Open a window on the screen at `url`, the site's sign-in page, for you to
sign in. `cookie` is the name of the cookie that the site keeps while it knows
who you are: the window closes by itself when the store has it. `title` is the
window's. The event "signed" says whether you signed in, once the window has
closed, and `s.signed` has it from then on.

A site that's signed in can still put a page in the way that only a person
passes, like a check that you aren't a robot. With `until`, a regular
expression, the window shows `url` and closes when its page's address
matches `until`, which is where the site goes once you have passed.
"""
sign_in!(s::Site, url::AbstractString; cookie::AbstractString, title::AbstractString="Sign in", until::AbstractString="") =
  tell!(s, isempty(until) ? Dict("do" => "signin", "url" => url, "cookie" => cookie, "title" => title) :
                            Dict("do" => "signin", "url" => url, "cookie" => cookie, "title" => title, "until" => until))

"Empty the store of `s`, so the site no longer knows who you are"
sign_out!(s::Site) = tell!(s, Dict("do" => "signout"))

"Ask whether the store of `s` has the cookie called `cookie`, which says who you are. The answer is the event \"signed\", and `s.signed`."
ask_signed!(s::Site, cookie::AbstractString) = tell!(s, Dict("do" => "signed", "cookie" => cookie))

"What the program of `s` has said since this was last asked: each event as a Dict. It's empty when there's nothing new."
events!(s::Site) = begin
  isempty(s.events) && return Dict{String,Any}[]
  got = copy(s.events)
  empty!(s.events)
  got
end

"The text of the answer of a \"data\" event, or nothing when it has gone. The file that kept it is deleted."
body!(event::AbstractDict) = begin
  file = get(event, "file", nothing)
  file isa AbstractString || return nothing
  text = try read(file, String) catch; nothing end
  rm(file, force=true)
  text
end

"End the program of `s`. Its pages end with it. The store keeps who you are."
stop!(s::Site) = begin
  to = s.to
  s.process, s.to, s.asking = nothing, nothing, false
  to === nothing || try close(to) catch end   # the program ends when its input does
  s
end

"End the program of every site. Ladder calls this when it quits."
stop_all!() = foreach(stop!, values(SITES))
