# What git knows about a folder, apart from the window that shows it: the
# branch, the files that have changes, and the last commits. main.jl puts a
# mark beside each changed file in the sidebar, and shows a page for the
# folder. This file asks git and reads its answers.
#
#     root = top("/Users/jake/Ladder/test")     # "/Users/jake/Ladder", the folder with the .git in it
#     s = state(root)                            # State(branch="main", ahead=2, changes=Dict("main.jl" => :changed), ...)
#     mark(s, "main.jl")                         # :changed
#     mark(s, "test")                            # :inside, since a file in the folder has changes
#     commits(root)                              # [Commit(hash="3467d8e", subject="Add new pages...", ...), ...]
#
# git can take seconds in a big repository, and a window never waits for it.
# `state` and `commits` give what git said last, at once. When that's older
# than `FRESH` seconds, they start git again, and what it says is there in a
# later frame. A repository that git is slow in is asked less often. `busy()` is true while a git still runs. `wait!()` waits for
# each, for a test.
#
# git is asked not to lock the repository (`--no-optional-locks`), so a look
# from here never stops a commit that another program makes at that moment.

@use "github.com/jkroso/Prospects.jl" @def

"How many seconds what git said stays good, before git is asked again"
const FRESH = 2.0

"""
What a file's change is, as `mark` gives it:

  - `:changed`: its lines differ from the last commit's
  - `:added`: git will add it with the next commit
  - `:new`: git doesn't keep it yet
  - `:deleted`: it's gone, and the last commit has it
  - `:renamed`: it has a new name or a new folder
  - `:clash`: a merge left two forms of it for you to choose from
  - `:inside`: it's a folder, and something in it has one of the above
"""
const MARKS = (:changed, :added, :new, :deleted, :renamed, :clash, :inside)

"What git said about a repository: its branch, how far it is from the branch that it follows, and the change of each file by its path from the top folder"
@def struct State
  known::Bool = false                  # git has answered at least once
  branch::String = ""                  # the branch's name, or the start of the commit's hash when no branch is checked out
  follows::String = ""                 # the branch that it follows, like origin/main, or ""
  ahead::Int = 0                       # commits here that the followed branch hasn't got
  behind::Int = 0                      # commits there that this branch hasn't got
  changes::Dict{String,Symbol} = Dict{String,Symbol}()
  staged::Set{String} = Set{String}()  # the paths whose change is ready for the next commit
  folders::Set{String} = Set{String}() # each folder that has a change in it
  head::String = ""                    # the whole hash of the last commit, or "(initial)" before the first
end

"One commit: the start of its hash, its first line, who made it and when"
@def struct Commit
  hash::String = ""
  subject::String = ""
  author::String = ""
  time::Float64 = 0.0
end

"""
The top folder of the repository that the folder or the file at `path` is in:
the nearest folder, from `path` up, that has a `.git` in it. It's "" when
there's none. A folder of a submodule or of a second checkout has a file
called `.git`, and that counts too.
"""
top(path::AbstractString) = begin
  d = isdir(path) ? String(rstrip(abspath(path), '/')) : dirname(abspath(path))
  while true
    ispath(joinpath(d, ".git")) && return d
    up = dirname(d)
    up == d && return ""
    d = up
  end
end

"True when the folder at `path` is the top folder of a repository"
istop(path::AbstractString) = ispath(joinpath(path, ".git"))

# --- what git prints ------------------------------------------------------------------

# The two letters that git gives each file: the first is its change in what the next commit will
# hold, and the second its change in the folder since then. A dot is no change.
change(x::Char, y::Char) =
  (x == 'U' || y == 'U' || (x == y && x in ('A', 'D'))) ? :clash :
  (x == 'D' || y == 'D') ? :deleted :
  (x == 'R' || y == 'R' || x == 'C') ? :renamed :
  x == 'A' ? :added : :changed

"The folders that the path `p` is in, from the top folder down: `a/b/c.md` gives `a` and `a/b`"
above(p::AbstractString) = begin
  parts = split(p, '/', keepempty=false)
  [join(parts[1:i], '/') for i in 1:length(parts)-1]
end

"""
Read what `git status --porcelain=v2 --branch -z` printed. Each entry ends
with a zero byte. A file that was renamed has its old path in the entry after
its own.
"""
read_status(text::AbstractString) = begin
  branch, follows, ahead, behind, hash = "", "", 0, 0, ""
  changes, staged, folders = Dict{String,Symbol}(), Set{String}(), Set{String}()
  note(path, kind, ready) = begin
    path = String(rstrip(path, '/'))   # git writes a folder that it doesn't keep with a / at its end
    changes[path] = kind
    ready && push!(staged, path)
    foreach(d -> push!(folders, d), above(path))
  end
  entries = split(text, '\0', keepempty=false)
  i = 1
  while i <= length(entries)
    s = entries[i]
    i += 1
    if startswith(s, "# branch.oid ")
      hash = String(s[14:end])
    elseif startswith(s, "# branch.head ")
      branch = String(s[15:end])
    elseif startswith(s, "# branch.upstream ")
      follows = String(s[19:end])
    elseif startswith(s, "# branch.ab ")
      m = match(r"\+(\d+) -(\d+)", s)
      m === nothing || ((ahead, behind) = (parse(Int, m[1]), parse(Int, m[2])))
    elseif startswith(s, "1 ") || startswith(s, "2 ")
      # The path comes after 8 fields, or after 9 for a file with a new name, and it can have spaces
      fields = split(s, ' ', limit=s[1] == '1' ? 9 : 10)
      length(fields) == (s[1] == '1' ? 9 : 10) || continue
      xy = fields[2]
      note(fields[end], change(xy[1], xy[2]), xy[1] != '.')
      s[1] == '2' && (i += 1)   # the old path
    elseif startswith(s, "u ")
      fields = split(s, ' ', limit=11)
      length(fields) == 11 && note(fields[end], :clash, false)
    elseif startswith(s, "? ")
      note(s[3:end], :new, false)
    end
  end
  # With no branch checked out, the start of the commit's hash stands for one
  branch == "(detached)" && (branch = first(hash, 7))
  State(known=true; branch, follows, ahead, behind, changes, staged, folders, head=hash)
end

"Read what `git log` printed with `LOG_FORMAT`"
read_log(text::AbstractString) = begin
  found = Commit[]
  for entry in split(text, '\x1e', keepempty=false)
    f = split(strip(entry, ['\n', '\r']), '\x1f')
    length(f) == 4 || continue
    push!(found, Commit(hash=String(f[1]), subject=String(f[2]), author=String(f[3]), time=something(tryparse(Float64, f[4]), 0.0)))
  end
  found
end

"How `commits` asks git to write each commit: four fields with the byte 1f between them, and 1e after the last"
const LOG_FORMAT = "%h%x1f%s%x1f%an%x1f%ct%x1e"

"""
The change of the file or the folder at `rel`, a path from the repository's
top folder: one of `MARKS`, or nothing when it has no change. A file in a
folder that git doesn't keep yet is `:new`, as the folder is.
"""
mark(s::State, rel::AbstractString) = begin
  rel = String(rstrip(rel, '/'))
  haskey(s.changes, rel) && return s.changes[rel]
  rel in s.folders && return :inside
  for d in above(rel)
    get(s.changes, d, nothing) == :new && return :new
  end
  nothing
end

"The paths that have a change, in the order of their names, each with its change"
changed(s::State) = sort!(collect(s.changes), by=p -> lowercase(first(p)))

# --- asking git -----------------------------------------------------------------------

"What one question to git has given: its answer, when it was asked, how long git took, and whether git still runs"
mutable struct Asked{T}
  value::T
  at::Float64
  took::Float64
  running::Bool
end

const STATES = Dict{String,Asked{State}}()
const LOGS = Dict{Tuple{String,Int},Asked{Vector{Commit}}}()
"The git program. A test can name another."
const program = Ref("git")

# The app that's built keeps what these hold when it's made. A git that ran then never ends in the app,
# so the app starts with nothing asked.
__init__() = (empty!(STATES); empty!(LOGS); nothing)

"Run git in the folder `root` and give what it printed, or nothing when it failed"
ask(root, args) = begin
  try
    read(pipeline(setenv(`$(program[]) --no-optional-locks -C $root $args`, merge(ENV, Dict("LC_ALL" => "C"))), stderr=devnull), String)
  catch
    nothing
  end
end

"How many gits run at once, at the most. A folder can list many repositories, and the rest wait for a later frame."
const MOST = 4

"""
What `read` makes of git's answer to `args`, kept in `table` under `key`. It's
asked again, in the background, when it's older than `fresh` seconds. A
repository that git is slow in is asked less often: no sooner than ten times
as long as git took the last time. So git works for a tenth of the time at
the most, however big the repository is.
"""
kept(read, table, key, root, args, empty; fresh=FRESH) = begin
  a = get!(() -> Asked(empty, 0.0, 0.0, false), table, key)
  if !a.running && time() - a.at > max(fresh, 10 * a.took) && running() < MOST
    a.running = true
    @async begin
      started = time()
      text = ask(root, args)
      text === nothing || (a.value = read(text))
      a.at = time()
      a.took = a.at - started
      a.running = false
    end
  end
  a.value
end

"What git says about the repository whose top folder is `root`, as it last said it. `known` is false until git has answered."
state(root::AbstractString; fresh=FRESH) =
  kept(read_status, STATES, String(root), root, `status --porcelain=v2 --branch -z`, State(); fresh)

"The last `n` commits of the repository whose top folder is `root`, the newest first, as git last gave them"
commits(root::AbstractString, n::Integer=30) =
  kept(read_log, LOGS, (String(root), Int(n)), root, `log -n $n --pretty=format:$LOG_FORMAT`, Commit[])

"How many gits that were started here still run"
running() = count(a -> a.running, values(STATES)) + count(a -> a.running, values(LOGS))

"True while a git that was started here still runs"
busy() = running() > 0

"Wait until each git that was started here has answered, for no longer than `seconds`"
wait!(seconds=10) = begin
  started = time()
  while busy() && time() - started < seconds
    sleep(0.01)
  end
  !busy()
end

"Forget what git said, so the next question starts git at once: after a commit that Ladder made, or in a test"
forget!() = (foreach(a -> (a.at = a.took = 0.0), values(STATES)); foreach(a -> (a.at = a.took = 0.0), values(LOGS)); nothing)

"""
The commit that last changed a line of a file: its hash, who made it, when, its
first line, and the number that the line has in that commit's own text of the
file `file`. `hash` is "" for a line that's in no commit yet.
"""
struct Blamed
  hash::String
  who::String
  at::Float64
  words::String
  line::Int
  file::String
end

"""
Start git to say which commit last changed line `line` of the file at `rel`.
`text` is the file's text as the window has it, which can be newer than the
file. It gives the process and what it prints: `read_blame` reads that.
"""
blame(root::AbstractString, rel::AbstractString, line::Int, text::AbstractString) = begin
  out = IOBuffer()
  cmd = setenv(`$(program[]) --no-optional-locks -C $root blame -L $line,$line --porcelain --contents - -- $rel`, merge(ENV, Dict("LC_ALL" => "C")))
  (run(pipeline(cmd, stdin=IOBuffer(text), stdout=out, stderr=devnull), wait=false), out)
end

"Read what `git blame --porcelain` printed for one line, or nothing when it printed no commit"
read_blame(text::AbstractString) = begin
  lines = split(text, '\n')
  m = match(r"^([0-9a-f]{40}) (\d+) \d+", first(lines))
  m === nothing && return nothing
  field(name) = (k = findfirst(startswith(name * " "), lines); k === nothing ? "" : String(chop(lines[k], head=length(name) + 1, tail=0)))
  # git gives a line that's in no commit a hash of zeros
  all(==('0'), m[1]) && return Blamed("", "", 0.0, "", parse(Int, m[2]), "")
  Blamed(String(m[1]), field("author"), something(tryparse(Float64, field("author-time")), 0.0), field("summary"), parse(Int, m[2]), field("filename"))
end

"""
The lines that the commit `b` took away where it wrote its line: what the file
had there before. It's empty when the commit only added lines. It asks git and
waits.
"""
before(root::AbstractString, b::Blamed) = begin
  out = String[]
  text = ask(root, `show --format= -U0 $(b.hash) -- $(b.file)`)
  text === nothing && return out
  within = false
  for line in split(text, '\n')
    m = match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
    if m !== nothing
      from, count = parse(Int, m[1]), m[2] === nothing ? 1 : parse(Int, m[2])
      within = from <= b.line < from + max(count, 1)
    elseif within && startswith(line, '-') && !startswith(line, "---")
      push!(out, String(chop(line, head=1, tail=0)))
    end
  end
  out
end

"What the file at `rel` had in the last commit, or nothing when the commit hasn't got it. It asks git and waits."
committed(root::AbstractString, rel::AbstractString) = ask(root, `show HEAD:$rel`)

"""
Start git in the folder `root` to change the repository or to send it, and
give the process and what it prints as it runs. git never asks for a password
here: with none to hand, it fails. The caller waits for the process, or looks
at it in a later frame.
"""
start(root::AbstractString, args) = begin
  out = IOBuffer()
  cmd = setenv(`$(program[]) -C $root $args`, merge(ENV, Dict("LC_ALL" => "C", "GIT_TERMINAL_PROMPT" => "0")))
  (run(pipeline(cmd, stdout=out, stderr=out), wait=false), out)
end

"Run git in the folder `root` to change the repository. It gives true when git did it, and what git printed. It waits for git."
act(root::AbstractString, args) = begin
  p, out = try start(root, args) catch; return (false, "git didn't start") end
  wait(p)
  (success(p), String(take!(out)))
end

"The commits that changed the file at `rel`, the newest first: the hash of each, and when it was made, in seconds. It asks git and waits."
history(root::AbstractString, rel::AbstractString) = begin
  out = Tuple{String,Float64}[]
  for line in eachline(IOBuffer(something(ask(root, `log --format=%H%x1f%ct -- $rel`), "")))
    parts = split(line, '\x1f')
    at = length(parts) == 2 ? tryparse(Float64, parts[2]) : nothing
    at === nothing || push!(out, (String(parts[1]), at))
  end
  out
end

"What the file at `rel` had in the commit `hash`, or nothing when that commit hasn't got it. It asks git and waits."
at_commit(root::AbstractString, hash::AbstractString, rel::AbstractString) = ask(root, `show $hash:$rel`)

"The changes of the file at `rel` since the last commit, as `git diff` writes them, or \"\". It asks git and waits."
changes(root::AbstractString, rel::AbstractString) = something(ask(root, `diff HEAD -- $rel`), "")

"How long ago `t` was, in a few words: `just now`, `5 min ago`, `3 h ago`, `4 days ago`, or the date"
ago(t::Real, now::Real=time()) = begin
  s = now - t
  s < 90 ? "just now" :
  s < 3600 ? "$(round(Int, s / 60)) min ago" :
  s < 86400 ? "$(round(Int, s / 3600)) h ago" :
  s < 14 * 86400 ? (d = round(Int, s / 86400); d == 1 ? "yesterday" : "$d days ago") :
  Libc.strftime("%-d %b %Y", t)
end
