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

"""
One commit: the start of its hash, its first line, who made it and when, the
commits that it was made on, and the branches and the tags that are at it
"""
@def struct Commit
  hash::String = ""
  subject::String = ""
  author::String = ""
  time::Float64 = 0.0
  id::String = ""                      # its whole hash
  parents::Vector{String} = String[]   # the whole hash of each commit that it was made on, the first one first. A merge has two or more.
  refs::Vector{String} = String[]      # the whole name of each branch and tag at it, like "refs/heads/main" and "refs/remotes/origin/main"
  head::Bool = false                   # it's the commit that's checked out
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

"""
Read the branches and the tags that `git log --decorate=full` names with
`%D`, like "HEAD -> refs/heads/main, refs/remotes/origin/main,
refs/remotes/origin/HEAD, tag: refs/tags/v1.0". It gives their whole names, and
whether the commit is the one that's checked out. `origin/HEAD` only says
which branch of `origin` is its main one, so it's left out. `ref_kind` and
`ref_name` say what each one is.
"""
read_refs(text::AbstractString) = begin
  refs, head = String[], false
  for r in split(text, ", ", keepempty=false)
    startswith(r, "HEAD") && (head = true)
    r = startswith(r, "HEAD -> ") ? r[9:end] : startswith(r, "tag: ") ? r[6:end] : r
    ref_kind(r) === nothing || (ref_kind(r) == :remote && endswith(r, "/HEAD")) || push!(refs, String(r))
  end
  (refs, head)
end

"What the whole name `r` of a ref is: `:branch` for a branch here, `:remote` for a branch of another copy, like origin/main, `:tag`, or nothing"
ref_kind(r::AbstractString) =
  startswith(r, "refs/heads/") ? :branch : startswith(r, "refs/remotes/") ? :remote : startswith(r, "refs/tags/") ? :tag : nothing

"The name of the ref `r` as people say it: main, origin/main or v1.0"
ref_name(r::AbstractString) = (k = ref_kind(r); k === nothing ? String(r) : String(r[length(k == :branch ? "refs/heads/" : k == :remote ? "refs/remotes/" : "refs/tags/")+1:end]))

"Read what `git log` printed with `LOG_FORMAT`"
read_log(text::AbstractString) = begin
  found = Commit[]
  for entry in split(text, '\x1e', keepempty=false)
    f = split(strip(entry, ['\n', '\r']), '\x1f')
    length(f) == 7 || continue
    refs, head = read_refs(f[7])
    push!(found, Commit(hash=String(f[1]), subject=String(f[2]), author=String(f[3]), time=something(tryparse(Float64, f[4]), 0.0),
                        id=String(f[5]), parents=String.(split(f[6], ' ', keepempty=false)), refs=refs, head=head))
  end
  found
end

"How `commits` asks git to write each commit: seven fields with the byte 1f between them, and 1e after the last"
const LOG_FORMAT = "%h%x1f%s%x1f%an%x1f%ct%x1f%H%x1f%P%x1f%D%x1e"

# --- the tree of commits ------------------------------------------------------------------
#
# Commits branch and merge, so they make a tree, as `git log --graph` draws it.
# Each line of the tree has a lane: the commits of one branch sit one under the
# other in the same lane, and a line goes down from each commit to the commits
# that it was made on. `tree` works out where each commit's dot goes, and the
# lines that go through its row, so each row can be drawn by itself.
#
#     tree(commits(root))   # [TreeRow(lane=1, above=[...], below=[(1, 1, 1)]), ...]

"A line through one half of a row of the tree: from lane `from` at one end to lane `to` at the other, in the colour `hue`"
const Line = Tuple{Int,Int,Int}

"""
One commit's row of the tree: the lane of its dot, its colour, the lines from
the top of the row down to the dot's height (`above`), and the lines from
there down to the bottom of the row (`below`). A line in `above` goes from its
lane at the top to its lane at the dot's height, and one in `below` from its
lane at the dot's height to its lane at the bottom. The colours count up
from 1, a new one for each branch.
"""
@def struct TreeRow
  lane::Int = 1
  hue::Int = 1
  above::Vector{Line} = Line[]
  below::Vector{Line} = Line[]
  lanes::Int = 1   # how many lanes the row uses
end

"""
Where each of the commits `cs` goes in the tree, in the same order. `cs` is
newest first, and a commit comes before the commits that it was made on, as
`git log` gives them. A commit that's made on one that's not in `cs` has a
line to the bottom of its row, and on down the rows under it.
"""
tree(cs::AbstractVector{Commit}) = begin
  wants = String[]   # the commit that each lane goes down to, or "" for a lane that's free
  hues = Int[]       # each lane's colour
  hue = 0
  free(from) = (i = findnext(isempty, wants, from); i === nothing ? (push!(wants, ""); push!(hues, 0); length(wants)) : i)
  rows = TreeRow[]
  for c in cs
    mine = findall(==(c.id), wants)
    # A commit that no lane goes down to starts a branch, in the first free lane
    lane = isempty(mine) ? free(1) : mine[1]
    colour = isempty(mine) ? (hue += 1) : hues[lane]
    passing = [(i, i, hues[i]) for i in eachindex(wants) if !isempty(wants[i]) && !(i in mine)]
    above = vcat(passing, [(i, lane, hues[i]) for i in mine])
    width = length(wants)
    foreach(i -> wants[i] = "", mine)
    below = copy(passing)
    if !isempty(c.parents)
      wants[lane], hues[lane] = c.parents[1], colour
      push!(below, (lane, lane, colour))
      # The other commits that a merge was made on: a lane that goes to it already, or a free one at the right
      for p in c.parents[2:end]
        j = findfirst(==(p), wants)
        j === nothing && (j = free(lane + 1); wants[j] = p; hues[j] = (hue += 1))
        push!(below, (lane, j, hues[j]))
      end
    end
    width = max(width, length(wants), lane)
    while !isempty(wants) && isempty(wants[end])
      pop!(wants); pop!(hues)
    end
    push!(rows, TreeRow(; lane, hue=colour, above, below, lanes=width))
  end
  rows
end

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
__init__() = (empty!(STATES); empty!(LOGS); empty!(SHOWS); nothing)

"Run git in the folder `root` and give what it printed, or nothing when it failed"
ask(root, args) = begin
  try
    read(pipeline(setenv(`$(program[]) --no-optional-locks -C $root $args`, merge(ENV, Dict("LC_ALL" => "C"))), stderr=devnull), String)
  catch
    nothing
  end
end

"""
Run git in the folder `root` with the text `input` on its stdin, and with the
variables `env` too, like an index file of its own. It gives what git printed,
or nothing when git failed. It waits for git.
"""
ask_with(root, args; input="", env=Dict{String,String}()) = begin
  try
    read(pipeline(setenv(`$(program[]) -C $root $args`, merge(ENV, Dict("LC_ALL" => "C"), env)), stdin=IOBuffer(input), stderr=devnull), String)
  catch
    nothing
  end
end

"""
Commit the text `text` as the file at `rel` in the repository at `root`, with
the message `message`. The commit is the last commit with that one file
changed. The file on the disk and every other file stay as they are. The
index gets the file's new text too, so the changes of the file that the
commit didn't take show as changes that aren't staged. It gives true and "",
or false and why.
"""
commit_text(root, rel, text, message) = begin
  head = strip(something(ask_with(root, `rev-parse --verify --quiet HEAD`), ""))
  blob = strip(something(ask_with(root, `hash-object -w --stdin`; input=text), ""))
  isempty(blob) && return (false, "git couldn't keep the text of $rel")
  # A file keeps its mode, like one that runs as a program. A new file is a plain file.
  listed = split(something(ask_with(root, `ls-files -s -- $rel`), ""))
  mode = isempty(listed) ? "100644" : listed[1]
  index = tempname()
  env = Dict("GIT_INDEX_FILE" => index)
  try
    ask_with(root, isempty(head) ? `read-tree --empty` : `read-tree $head`; env) === nothing && return (false, "git couldn't read the last commit")
    ask_with(root, `update-index --add --cacheinfo $mode,$blob,$rel`; env) === nothing && return (false, "git couldn't take $rel")
    tree = strip(something(ask_with(root, `write-tree`; env), ""))
    isempty(tree) && return (false, "git couldn't make the commit")
    parent = isempty(head) ? String[] : ["-p", head]
    commit = strip(something(ask_with(root, `commit-tree $tree $parent -F -`; input=message), ""))
    isempty(commit) && return (false, "git couldn't make the commit")
    # The branch moves only if no other commit came in the meantime
    moved = ask_with(root, isempty(head) ? `update-ref HEAD $commit` : `update-ref HEAD $commit $head`)
    moved === nothing && return (false, "another commit came first")
    ask_with(root, `update-index --add --cacheinfo $mode,$blob,$rel`)
    (true, "")
  finally
    rm(index, force=true)
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

"""
The last `n` commits of the repository whose top folder is `root`, the newest
first, as git last gave them. They're the commits of every branch, the ones
that git has from other copies too, like `origin/main`. A commit always comes
before the commits that it was made on.
"""
commits(root::AbstractString, n::Integer=30) =
  kept(read_log, LOGS, (String(root), Int(n)), root, `log -n $n --date-order --decorate=full --branches --remotes HEAD --pretty=format:$LOG_FORMAT`, Commit[])

"How many gits that were started here still run"
running() = count(a -> a.running, values(STATES)) + count(a -> a.running, values(LOGS)) + count(a -> a.running, values(SHOWS))

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

# --- what one commit holds ------------------------------------------------------------
#
# A click on a commit in git's panel shows what the commit holds: its message,
# who made it and when, and the lines of each file that it changed. `shown`
# asks git once for each commit, since a commit never changes.

"One file that a commit changed, and its part of the commit's diff"
@def struct Touched
  path::String = ""              # its path from the top folder, after the commit
  from::String = ""              # its path before the commit, when the commit moved it, or ""
  kind::Symbol = :changed        # :changed, :new, :deleted or :renamed
  binary::Bool = false           # git shows no lines of it, as for a picture
  lines::UnitRange{Int} = 1:0    # the lines of the diff that are about it
end

"What a commit holds: who made it and when, its whole message, and its diff as `git show` writes it, file by file"
@def struct Shown
  known::Bool = false                    # git has answered
  hash::String = ""                      # the whole hash
  author::String = ""
  time::Float64 = 0.0
  message::String = ""                   # its first line, an empty line and the rest, as it was written
  diff::Vector{String} = String[]        # the lines of its diff
  files::Vector{Touched} = Touched[]     # each file that it changed, in the order of the diff
end

"How `shown` asks git to write a commit's hash, author, time and message, with the byte 1f between them and 1e after the last"
const SHOW_FORMAT = "%H%x1f%an%x1f%at%x1f%B%x1e"

"A path as the diff writes it: without git's quotes, and without the `a/` or `b/` before it. /dev/null is \"\"."
diff_path(s::AbstractString) = begin
  s = strip(replace(s, r"\t.*$" => ""))
  # git puts a name with odd characters in quotes, with a \ before each quote and \ in it
  length(s) >= 2 && startswith(s, '"') && endswith(s, '"') && (s = replace(s[2:end-1], "\\\"" => "\"", "\\\\" => "\\"))
  s == "/dev/null" ? "" : String(replace(s, r"^[ab]/" => ""))
end

"The path in a `diff --git a/x b/x` line. A file that keeps its name has it twice, so the half after `b/` is its path."
git_line_path(line::AbstractString) = begin
  s = chop(line, head=length("diff --git "), tail=0)
  n = length(s)
  # "a/" * p * " b/" * p is 2 * length(p) + 5 characters long
  isodd(n) && (k = (n - 5) ÷ 2; k > 0 && s[3:2+k] == s[end-k+1:end]) && return String(s[end-k+1:end])
  m = match(r" b/(.*)$", s)
  m === nothing ? "" : diff_path(m[1])
end

"Read what `git show` printed with `SHOW_FORMAT`"
read_shown(text::AbstractString) = begin
  head, _, rest = partition(text, '\x1e')
  f = split(head, '\x1f', limit=4)
  length(f) == 4 || return Shown(known=true)
  diff = String.(split(rest, '\n'))
  # git puts an empty line between the message and the diff, and ends with a newline
  while !isempty(diff) && isempty(diff[1]); popfirst!(diff) end
  while !isempty(diff) && isempty(diff[end]); pop!(diff) end
  starts = [i for (i, l) in enumerate(diff) if startswith(l, "diff --git ")]
  files = map(enumerate(starts)) do (n, s)
    stop = n < length(starts) ? starts[n+1] - 1 : length(diff)
    path, from, kind, binary = git_line_path(diff[s]), "", :changed, false
    old = nothing
    for i in s+1:stop
      l = diff[i]
      startswith(l, "@@") && break
      startswith(l, "new file mode") ? (kind = :new) :
      startswith(l, "deleted file mode") ? (kind = :deleted) :
      startswith(l, "rename from ") ? (kind = :renamed; from = diff_path(l[13:end])) :
      startswith(l, "rename to ") ? (path = diff_path(l[11:end])) :
      startswith(l, "Binary files ") || startswith(l, "GIT binary patch") ? (binary = true) :
      startswith(l, "--- ") ? (old = diff_path(l[5:end])) :
      startswith(l, "+++ ") ? (new = diff_path(l[5:end]); path = isempty(new) ? something(old, path) : new) : nothing
    end
    Touched(; path, from, kind, binary, lines=s:stop)
  end
  Shown(known=true, hash=String(f[1]), author=String(f[2]), time=something(tryparse(Float64, f[3]), 0.0),
        message=String(rstrip(f[4])), diff=diff, files=files)
end

"`text` cut at the first `c`: what comes before it, `c`, and what comes after it"
partition(text::AbstractString, c::Char) = begin
  i = findfirst(c, text)
  i === nothing ? (text, "", "") : (text[1:prevind(text, i)], string(c), text[nextind(text, i):end])
end

const SHOWS = Dict{Tuple{String,String},Asked{Shown}}()

"""
What the commit `hash` of the repository whose top folder is `root` holds, as
git gave it: `known` is false until git has answered. A merge shows what it
brought to the branch that it was made on. It's nothing when git couldn't
find the commit.
"""
shown(root::AbstractString, hash::AbstractString) = begin
  key = (String(root), String(hash))
  # A commit never changes, so it's asked once. Before that, git is asked at once.
  s = kept(read_shown, SHOWS, key, root,
           `-c core.quotePath=false show --no-color --no-ext-diff -M --diff-merges=first-parent --format=$SHOW_FORMAT $hash --`,
           Shown(); fresh=1e9)
  a = SHOWS[key]
  !s.known && a.at > 0 && !a.running ? nothing : s
end
