# What the home folder's page shows, apart from the window that shows it: the
# folders that you chose as favourites, and the work that changed in the last
# week. main.jl draws the page. This file keeps the list of favourites and
# finds the work.
#
#     favourites()                       # ["/Users/jake/Desktop/Canon", ...], in the order that you put them
#     favourite!("/Users/jake/Notes")    # puts the folder at the end of the list
#     unfavourite!("/Users/jake/Notes")  # takes it off the list
#     move_favourite!(path, 1)           # puts it first
#     recent(homedir())                  # [Project(path="/Users/jake/Desktop/JuliaLang/Ladder", files=[...]), ...]
#
# Ladder keeps the favourites in a file of its own, in its folder in
# ~/Library/Application Support, one folder on each line. The same file keeps
# the projects that you hid from the page. The Finder's own favourites are in
# a file that only the Finder writes, so Ladder's list is apart from them.
#
# Spotlight, the Mac's index of its files, finds the work: each file in the
# home folder whose text changed in the last 7 days, and each file that an app
# opened in that time. Spotlight answers in about a second, for tens of
# thousands of files, so `recent` asks it on a second thread and gives what it
# found the last time. A project is a git repository, and the files go in
# groups, one for each repository:
#
#   - A file in a git repository is in the project of the repository's top
#     folder. A file that git ignores, like one that a build made, isn't work.
#   - A file in no repository isn't work. Most of those are what a program
#     wrote, like the files of an email app.
#   - A file in a hidden folder, in ~/Library, in an app, or in a folder of
#     what a program made, like node_modules, isn't work.

@use "github.com/jkroso/Prospects.jl" @def
@use Dates: Dates, DateTime

# --- the favourites ---------------------------------------------------------------------

"The file that keeps the favourites and the hidden projects. A test names one of its own."
const FILE = Ref("")

"The path of the file that keeps the favourites and the hidden projects"
file() = isempty(FILE[]) ? joinpath(homedir(), "Library", "Application Support", "Ladder", "home") : FILE[]

"What the file keeps: the favourite folders in their order, and the projects that the page doesn't show"
@def struct Kept
  favourites::Vector{String} = String[]
  hidden::Vector{String} = String[]
end

"What was read from the file, with the time that the file had changed then"
const READ = Ref((-1.0, Kept()))

"""
What the file keeps now. The file is read again when it has changed, as it
does when another window of Ladder writes it.
"""
kept() = begin
  path = file()
  at = try isfile(path) ? mtime(path) : 0.0 catch; 0.0 end
  READ[][1] == at && return READ[][2]
  k = Kept()
  try
    at > 0 && for line in eachline(path)
      what, where = (split(line, '\t', limit=2)..., "")[1:2]
      isempty(where) && continue
      what == "favourite" && push!(k.favourites, String(where))
      what == "hidden" && push!(k.hidden, String(where))
    end
  catch
  end
  READ[] = (at, k)
  k
end

"Write `k` to the file"
keep!(k::Kept) = begin
  path = file()
  mkpath(dirname(path))
  write(path, join(("favourite\t$p\n" for p in k.favourites)) * join(("hidden\t$p\n" for p in k.hidden)))
  READ[] = (mtime(path), k)
  k
end

"`path` as the list keeps it: from the top of the disk, with no / at its end"
clean(path::AbstractString) = (p = abspath(expanduser(path)); length(p) > 1 ? String(rstrip(p, '/')) : p)

"The folders that you chose as favourites, in the order that you put them"
favourites() = kept().favourites

"True when the folder at `path` is a favourite"
isfavourite(path::AbstractString) = clean(path) in favourites()

"Put the folder at `path` at the end of the favourites. A folder that's a favourite already stays where it is."
favourite!(path::AbstractString) = begin
  p, k = clean(path), kept()
  p in k.favourites || keep!(Kept([k.favourites; p], k.hidden))
  nothing
end

"Take the folder at `path` off the favourites"
unfavourite!(path::AbstractString) = begin
  p, k = clean(path), kept()
  p in k.favourites && keep!(Kept(filter(!=(p), k.favourites), k.hidden))
  nothing
end

"Put the favourite at `path` at place `to` of the list, counted from 1"
move_favourite!(path::AbstractString, to::Integer) = begin
  p, k = clean(path), kept()
  p in k.favourites || return nothing
  rest = filter(!=(p), k.favourites)
  insert!(rest, clamp(to, 1, length(rest) + 1), p)
  rest == k.favourites || keep!(Kept(rest, k.hidden))
  nothing
end

"The projects that you hid from the page"
hidden() = kept().hidden

"Leave the project of the folder at `path` off the page"
hide!(path::AbstractString) = begin
  p, k = clean(path), kept()
  p in k.hidden || keep!(Kept(k.favourites, [k.hidden; p]))
  nothing
end

"Show the project of the folder at `path` on the page again"
unhide!(path::AbstractString) = begin
  p, k = clean(path), kept()
  p in k.hidden && keep!(Kept(k.favourites, filter(!=(p), k.hidden)))
  nothing
end

# --- what Spotlight knows -----------------------------------------------------------------

"A file that changed or that an app opened, and when that was, in seconds"
@def struct Touched
  path::String = ""
  when::Float64 = 0.0
end

"How far back the work goes, in seconds"
const WEEK = 7 * 86400.0

"The time that Spotlight writes, like 2026-11-22 03:04:49 +0000, in seconds, or nothing"
spotlight_time(s::AbstractString) = begin
  m = match(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d) ([+-])(\d\d)(\d\d)", s)
  m === nothing && return nothing
  t = Dates.datetime2unix(DateTime(m[1], Dates.dateformat"yyyy-mm-dd HH:MM:SS"))
  zone = (parse(Int, m[3]) * 3600 + parse(Int, m[4]) * 60) * (m[2] == "+" ? 1 : -1)
  t - zone
end

"""
Read what `mdfind -0 -attr key` printed: a path, three spaces, `key = ` and
the time, for each file, with a zero byte after each. It gives each path with
its time, for the times since `since`.
"""
read_found(text::AbstractString, key::AbstractString, since::Real) = begin
  found = Touched[]
  for record in split(text, '\0', keepempty=false)
    at = findlast("   $key = ", record)
    at === nothing && continue
    t = spotlight_time(record[last(at)+1:end])
    (t === nothing || t < since) && continue
    push!(found, Touched(String(record[1:first(at)-1]), t))
  end
  found
end

"""
The files in the folder `home` whose text changed since the time `since`, or
that an app opened since then, as Spotlight knows them. Each has the later of
the two times. It's empty when Spotlight can't be asked.
"""
spotlight(home::AbstractString, since::Real) = begin
  Sys.isapple() || return Touched[]
  days = max(1, ceil(Int, (time() - since) / 86400))
  newest = Dict{String,Float64}()
  for key in ("kMDItemFSContentChangeDate", "kMDItemLastUsedDate")
    query = "$key >= \$time.today(-$days) && kMDItemContentTypeTree != \"public.folder\""
    text = try read(pipeline(`/usr/bin/mdfind -0 -onlyin $home -attr $key $query`, stderr=devnull), String) catch; "" end
    for t in read_found(text, key, since)
      newest[t.path] = max(get(newest, t.path, 0.0), t.when)
    end
  end
  [Touched(path, t) for (path, t) in newest]
end

# --- the projects -------------------------------------------------------------------------

"The names of folders that hold what a program made, not work"
const MADE = Set(["node_modules", "__pycache__", "DerivedData", "Pods"])

"The endings of the names of folders that the Finder shows as one file, like an app"
const PACKAGES = (".app", ".photoslibrary", ".musiclibrary", ".bundle", ".framework", ".plugin")

"""
True when the file at `path` can be work in the home folder `home`: it's in
`home`, and not in ~/Library or ~/Applications, not hidden or in a hidden
folder, and not in an app or in a folder of what a program made.
"""
iswork(path::AbstractString, home::AbstractString) = begin
  startswith(path, home * "/") || return false
  parts = split(path[length(home)+2:end], '/')
  parts[1] in ("Library", "Applications") && return false
  all(p -> !isempty(p) && !startswith(p, '.') && !(p in MADE) && !any(x -> endswith(p, x), PACKAGES), parts)
end

"""
The top folder of the git repository that the folder `dir` is in, or "" when
it's in none. `tops` keeps what's found for each folder. The home folder
itself doesn't count as a repository's top, since its repository would hold
all the others.
"""
repo_top!(tops::Dict{String,String}, dir::AbstractString, home::AbstractString) = begin
  haskey(tops, dir) && return tops[dir]
  top = (dir == home || !startswith(dir, home * "/")) ? "" :
        (try ispath(joinpath(dir, ".git")) catch; false end) ? String(dir) : repo_top!(tops, dirname(dir), home)
  tops[String(dir)] = top
end

"The git program. A test can name another."
const git = Ref("git")

"The paths of `rels`, from the top folder `top` of a git repository, that git ignores. A folder's path ends with a /."
ask_ignored(top::AbstractString, rels) = begin
  isempty(rels) && return Set{String}()
  input = join(rels, '\0') * '\0'
  # git ends with 1 when it ignores none of them, and then there's nothing to read
  out = try
    read(pipeline(`$(git[]) --no-optional-locks -C $top check-ignore -z --stdin`, stdin=IOBuffer(input), stderr=devnull), String)
  catch
    ""
  end
  Set{String}(split(out, '\0', keepempty=false))
end

"What git said about each folder and file, by its path from the top of the disk: true when git ignores it"
const IGNORED = Dict{String,Bool}()

"""
The files of `paths`, which are all in the git repository whose top folder is
`top`, that git ignores. git takes about a millisecond for each path in a big
repository, and a build can make thousands of files in a week. So git is
asked first about the folders that the files are in, and then only about the
files in folders that it doesn't ignore. What git said is kept, so the next
time it's asked only about new paths.
"""
ignored(top::AbstractString, paths) = begin
  length(IGNORED) > 200_000 && empty!(IGNORED)
  rels = [p[length(top)+2:end] for p in paths]
  # Each folder on the way to each file, from the top down, with a / at its end
  folders = Set{String}()
  for r in rels
    for i in findall('/', r)
      push!(folders, r[1:i])
    end
  end
  ask!(rels) = begin
    unknown = String[r for r in rels if !haskey(IGNORED, joinpath(top, r))]
    yes = ask_ignored(top, sort!(unknown))
    foreach(r -> IGNORED[joinpath(top, r)] = r in yes, unknown)
  end
  ask!(collect(folders))
  inside(r) = any(i -> IGNORED[joinpath(top, r[1:i])], findall('/', r))
  ask!(filter(!inside, rels))
  Set{String}(p for (p, r) in zip(paths, rels) if inside(r) || IGNORED[p])
end

"The work of one project: the top folder of its git repository, its newest files, how many of its files changed, and when the newest did"
@def struct Project
  path::String = ""
  files::Vector{Touched} = Touched[]   # the newest few, the newest first
  count::Int = 0                       # how many of its files changed or were opened
  when::Float64 = 0.0                  # when the newest of them did
end

"""
The work in `touched`, the files of the home folder `home` that changed or
were opened, in a project for each git repository, the newest project first.
A project keeps its `most` newest files. `ignores` gives the files of a
repository that git ignores, which aren't work.
"""
projects(touched, home::AbstractString; most::Integer=3, ignores=ignored) = begin
  tops = Dict{String,String}()
  groups = Dict{String,Vector{Touched}}()
  for t in touched
    iswork(t.path, home) || continue
    top = repo_top!(tops, dirname(t.path), home)
    isempty(top) || push!(get!(Vector{Touched}, groups, top), t)
  end
  gone = Set{String}()
  for (top, ts) in groups
    union!(gone, ignores(top, [t.path for t in ts]))
  end
  out = Project[]
  for (p, ts) in groups
    filter!(t -> !(t.path in gone), ts)
    isempty(ts) && continue
    sort!(ts, by=t -> -t.when)
    push!(out, Project(path=p, files=ts[1:min(most, end)], count=length(ts), when=ts[1].when))
  end
  sort!(out, by=p -> -p.when)
end

# --- the work, found on a second thread -----------------------------------------------------

"What finds the files that changed or were opened: Spotlight, or a test's own function of the home folder and the time to look back to"
const finder = Ref{Function}(spotlight)

"What `recent` found the last time, and when it asked"
mutable struct Recent
  home::String
  projects::Vector{Project}
  at::Float64       # when it last asked, or 0 when it must ask at once
  done::Bool        # it found the work of `home` at least once
  running::Bool     # it's asking now
end

const RECENT = Recent("", Project[], 0.0, false, false)

"""
The work of the last week in the home folder `home`, as it was found the last
time, the newest project first. It's found again on a second thread when it's
older than `fresh` seconds. `found()` is false until it was found once.
"""
recent(home::AbstractString; fresh::Real=120.0) = begin
  r = RECENT
  if r.home != home
    r.home, r.projects, r.at, r.done = String(home), Project[], 0.0, false
  end
  if !r.running && time() - r.at > fresh
    r.running = true
    r.at = time()
    task = Threads.@spawn begin
      found = try
        projects(Base.invokelatest(finder[], home, time() - WEEK), home)
      catch err
        @warn "Ladder couldn't find the work of the last week" exception=err
        Project[]
      end
      if r.home == home
        r.projects = found
        r.done = true
      end
      r.running = false
    end
    errormonitor(task)
  end
  r.projects
end

"True once the work of the home folder that was asked for last was found"
found() = RECENT.done

"True while the work is being found"
busy() = RECENT.running

"Wait until the work is found, for no longer than `seconds`, for a test"
wait!(seconds=10) = begin
  started = time()
  while busy() && time() - started < seconds
    sleep(0.01)
  end
  !busy()
end

"Find the work again the next time that it's asked for"
forget!() = (RECENT.at = 0.0; nothing)

# The app that's built keeps what these hold when it's made. A search that ran then never ends in the
# app, so the app starts with nothing found, and reads its file again.
__init__() = begin
  RECENT.home, RECENT.projects, RECENT.at, RECENT.done, RECENT.running = "", Project[], 0.0, false, false
  READ[] = (-1.0, Kept())
  empty!(IGNORED)
  nothing
end
