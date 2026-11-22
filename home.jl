# What the home folder's page shows, apart from the window that shows it: the
# folders that you chose as favourites, and the work that changed in the last
# week. main.jl draws the page. This file keeps the list of favourites,
# finds the work, and finds when anything in each folder last changed.
#
#     favourites()                       # ["/Users/jake/Desktop/Canon", ...], in the order that you put them
#     favourite!("/Users/jake/Notes")    # puts the folder at the end of the list
#     unfavourite!("/Users/jake/Notes")  # takes it off the list
#     move_favourite!(path, 1)           # puts it first
#     recent(homedir())                  # [Project(path="/Users/jake/Desktop/JuliaLang/Ladder", files=[...]), ...]
#     newest(homedir(), folders)         # when anything in each folder last changed, at any depth
#     sizes(homedir())                   # how many bytes each of those folders holds, at any depth
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
@use FileWatching

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

# --- when anything in a folder last changed, and how big it is ----------------------------------
#
#     newest(homedir(), ["/Users/jake/Desktop", ...])   # Dict("/Users/jake/Desktop" => 1.795e9, ...)
#     sizes(homedir())                                  # Dict("/Users/jake/Desktop" => 48_000_000_000, ...)
#
# The table on the home folder's page says when anything in each of its
# folders last changed: the newest time of the folder itself and of each
# folder and file in it, at any depth. Hidden folders and files don't count.
# Git changes the files in a repository's .git when Ladder only asks it
# something, and the Finder writes .DS_Store when it shows a folder.
#
# Ladder reads each folder once, on a second thread, the first time that the
# page asks for it. Most folders take a part of a second. A folder of half a
# million files took 10 seconds. Before it starts, Ladder asks macOS to tell it
# of each change in the home folder, at any depth (FSEvents). Each change
# moves its folder's time on. A change that's newer than the start of a
# folder's reading makes its time known: nothing that the reading could still
# find is newer. A folder's time never goes back, since taking a file out of a
# folder changes the folder's own time.
#
# The same reading adds up the sizes of the files in each folder, hidden ones
# too, as the Finder does. Its size is known when the reading ends. Ladder
# keeps the bytes of the files right in each folder that it read, at any
# depth: about 76,000 folders in a home folder. After a change, it reads again
# only the folder that the change was in, half a second later, so a lot of
# changes at once cost one reading of each folder. A folder that went takes
# its bytes away, and a folder that came is read to the end.
#
# ~/Library isn't read. It holds more than a million files, a read of it took 8
# minutes, and macOS asks you before an app reads the data that other apps
# keep there. Its time is its own until macOS tells of a change in it. Apps
# change files there all the time, so that's about a second. The same goes
# for each folder inside a Library folder, for the page of a folder in
# ~/Library, or of /Library itself.

"The folders that `newest` doesn't read, by name, and doesn't read the folders in: their time is their own, and each change that macOS tells of"
const UNREAD = Set(["Library"])

"True when `newest` doesn't read the folder at `path`: it's one of `UNREAD`, or it's inside one"
unread(path::AbstractString) = any(in(UNREAD), splitpath(path))

"The reading of one folder: the folders in it that are still to read, each with true when it's in a hidden folder, and the newest time found so far"
mutable struct Reading
  stack::Vector{Tuple{String,Bool}}
  best::Float64
end

"What's known of when the folders of one folder last changed, and of how big they are"
mutable struct Times
  root::String
  times::Dict{String,Float64}     # the newest time in each folder, as far as it's known, by its path
  known::Set{String}              # the folders whose time is known: read to the end, or changed after their reading started
  asked::Set{String}              # the folders that were asked for
  queue::Vector{String}           # the folders that wait to be read
  started::Dict{String,Float64}   # when the reading of each folder started
  reading::Bool                   # a second thread reads folders now
  monitor::Any                    # what hears of the changes from macOS, or nothing
  lock::ReentrantLock
  bytes::Dict{String,Int}         # the bytes of the files right in each folder that was read, at any depth, by its path
  sizes::Dict{String,Int}         # the bytes of each folder that was asked for, at any depth, as far as it's read
  sized::Set{String}              # the folders that were asked for whose reading ended, so their size is known
  dirty::Set{String}              # the paths that macOS told of a change at, since the last look
  looking::Bool                   # a look at those changes is to come
end
Times(root) = Times(root, Dict{String,Float64}(), Set{String}(), Set{String}(), String[], Dict{String,Float64}(), false, nothing, ReentrantLock(),
                    Dict{String,Int}(), Dict{String,Int}(), Set{String}(), Set{String}(), false)

"What's known of the folders of each folder that `newest` was asked about, by that folder's path"
const TIMES = Dict{String,Times}()
const TIMES_LOCK = ReentrantLock()

"The time that the folder or the file at `path` last changed, or 0 when it's gone or macOS doesn't say. A link has its own time."
own_time(path::AbstractString) = try lstat(path).mtime catch; 0.0 end

"""
When anything in each of the folders `folders` of the folder `root` last
changed, at any depth, by the folder's path. A folder that's still being
read isn't in it. The first time that a folder is asked for, a second
thread starts to read it.
"""
newest(root::AbstractString, folders) = begin
  t = lock(() -> get!(() -> Times(String(root)), TIMES, root), TIMES_LOCK)
  lock(t.lock) do
    for f in folders
      f in t.asked && continue
      push!(t.asked, f)
      if unread(f)
        t.times[f] = max(get(t.times, f, 0.0), own_time(f))
        push!(t.known, f)
      else
        push!(t.queue, f)
      end
    end
    # macOS tells of the changes from before the first folder's reading starts
    t.monitor === nothing && (t.monitor = listen!(t))
    if !t.reading && !isempty(t.queue)
      t.reading = true
      errormonitor(Threads.@spawn read_all!(t))
    end
    Dict{String,Float64}(f => get(t.times, f, 0.0) for f in t.known)
  end
end

"""
Read the folders that wait in `t`'s queue. Each step reads one folder inside
each of them in turn, so a small folder's time is known soon, even while a
big one is still being read. It runs on Julia's worker thread, apart from
the window's.
"""
read_all!(t::Times) = begin
  open = Dict{String,Reading}()
  while true
    lock(t.lock) do
      while !isempty(t.queue)
        f = popfirst!(t.queue)
        t.started[f] = time()
        # A link to a folder counts with the time of the folder that it leads to. Inside, links aren't followed.
        open[f] = Reading([(f, false)], try stat(f).mtime catch; 0.0 end)
      end
      isempty(open) && (t.reading = false)
    end
    isempty(open) && return
    for (f, r) in collect(open)
      # A change that macOS told of can make its time known first. The reading goes on to the end for its size.
      isempty(r.stack) || read_one!(t, r)
      if isempty(r.stack)
        lock(t.lock) do
          t.times[f] = max(get(t.times, f, 0.0), r.best)
          push!(t.known, f)
          push!(t.sized, f)
        end
        delete!(open, f)
      end
    end
    # The thread is the one that runs a page's code too, so that waits no more than a step
    yield()
  end
end

"""
Read the last folder of `r`'s list, for `t`: the times of what's in it, apart
from what's hidden, and the bytes of its files, hidden ones too. Its folders go
on the list. A folder that was read already, after a change, isn't read again.
"""
read_one!(t::Times, r::Reading) = begin
  dir, hid = pop!(r.stack)
  claim!(t, dir) || return
  bytes, kids, newest = files_in(dir)
  for (path, st) in kids
    seen = hid || startswith(basename(path), '.')
    seen || (r.best = max(r.best, st.mtime))
    push!(r.stack, (path, seen))
  end
  hid || (r.best = max(r.best, newest))
  lock(() -> set_bytes!(t, dir, bytes), t.lock)
end

"""
What's right in the folder `dir`: the bytes of its files, its folders, each
with what `lstat` says of it, and the newest time of its files that aren't
hidden. A folder that macOS doesn't let Ladder read has nothing.
"""
files_in(dir::AbstractString) = begin
  bytes, kids, newest = 0, Tuple{String,Base.Filesystem.StatStruct}[], 0.0
  # macOS doesn't let Ladder read some folders, like the Trash before Ladder has Full Disk Access
  names = try readdir(dir) catch; return bytes, kids, newest end
  for name in names
    path = joinpath(dir, name)
    st = try lstat(path) catch; continue end
    if isdir(st)
      push!(kids, (path, st))
    else
      bytes += st.size
      startswith(name, '.') || (newest = max(newest, st.mtime))
    end
  end
  bytes, kids, newest
end

"""
Hear of each change from macOS in the folder of `t`, at any depth. It's
nothing when macOS can't be asked.
"""
listen!(t::Times) = begin
  m = try watch_deep(t.root) catch err
    @warn "Ladder can't hear of changes in $(t.root)" exception=err
    return nothing
  end
  errormonitor(Threads.@spawn while true
    name = try first(wait(m)) catch; break end
    try changed!(t, name) catch err; @warn "Ladder couldn't take in a change" exception=err end
  end)
  m
end

"""
A watcher of the folder at `root` that hears of changes at any depth. Julia's
`FolderMonitor` only hears of the things in the folder itself, so its watch
starts again with libuv's flag for every depth. On a Mac, libuv asks
FSEvents, and a change's name is its path from `root`.
"""
watch_deep(root::AbstractString) = begin
  m = FileWatching.FolderMonitor(root)
  cb = @cfunction(FileWatching.uv_fseventscb_folder, Cvoid, (Ptr{Cvoid}, Ptr{Int8}, Int32, Int32))
  Base.iolock_begin()
  err = try
    ccall(:uv_fs_event_stop, Cint, (Ptr{Cvoid},), m.handle)
    ccall(:uv_fs_event_start, Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Cstring, Cint), m.handle, cb, root, UV_FS_EVENT_RECURSIVE)
  finally
    Base.iolock_end()
  end
  err == 0 || (close(m); error("libuv couldn't watch $root at every depth: error $err"))
  m
end

"libuv's flag that asks to hear of changes at every depth of a folder"
const UV_FS_EVENT_RECURSIVE = Cint(4)

"Take in the change that macOS told of at `name`, the path of a folder or a file from the folder of `t`"
changed!(t::Times, name::AbstractString) = begin
  parts = split(name, '/', keepempty=false)
  isempty(parts) && return
  path = joinpath(t.root, name)
  # Each change counts for the sizes, hidden ones too
  note!(t, path)
  # A change inside a hidden folder, or to a hidden file, doesn't count for the time
  any(p -> startswith(p, '.'), parts[2:end]) && return
  folder = joinpath(t.root, parts[1])
  # The thing's own time. A thing that went has none, but the folder that held it changed when it went.
  when = length(parts) == 1 ? own_time(path) : max(own_time(path), own_time(dirname(path)))
  lock(t.lock) do
    t.times[folder] = max(get(t.times, folder, 0.0), when)
    started = get(t.started, folder, Inf)
    when >= started && push!(t.known, folder)
  end
  nothing
end

# --- the sizes ---

"How long after a change Ladder looks at the sizes, so that a lot of changes at once cost one look"
const LOOK_WAIT = 0.5

"""
How many bytes each folder that `newest` was asked about in the folder `root`
holds, at any depth, hidden files too, by its path. A folder that's still
being read, or that isn't read, like ~/Library, isn't in it.
"""
sizes(root::AbstractString) = begin
  t = lock(() -> get(TIMES, root, nothing), TIMES_LOCK)
  t === nothing && return Dict{String,Int}()
  lock(() -> Dict{String,Int}(f => get(t.sizes, f, 0) for f in t.sized), t.lock)
end

"The folder that was asked for that `path`, a folder in the folder of `t` at any depth, is in"
top_of(t::Times, path::AbstractString) = joinpath(t.root, first(splitpath(relpath(path, t.root))))

"Keep the bytes of the files right in the folder `dir`, and add the difference to the size of the folder that it's in. The caller holds `t`'s lock."
set_bytes!(t::Times, dir::AbstractString, bytes::Integer) = begin
  old = get(t.bytes, dir, 0)
  t.bytes[dir] = bytes
  top = top_of(t, dir)
  t.sizes[top] = get(t.sizes, top, 0) + bytes - old
  nothing
end

"True when no reading of `t` has had the folder `dir` yet, which this one now has. So two readings never count a folder twice."
claim!(t::Times, dir::AbstractString) = lock(t.lock) do
  haskey(t.bytes, dir) && return false
  t.bytes[dir] = 0
  true
end

"Take away from `t` each folder in `gone`, and each folder in those, at any depth. The caller holds `t`'s lock."
forget_under!(t::Times, gone) = begin
  for dir in collect(keys(t.bytes))
    d = dir
    while length(d) >= length(t.root)
      if d in gone
        set_bytes!(t, dir, 0)
        delete!(t.bytes, dir)
        break
      end
      up = dirname(d)
      up == d && break
      d = up
    end
  end
end

"Keep the change at `path` for a look at the sizes of `t`, `LOOK_WAIT` after the first change that's kept"
note!(t::Times, path::AbstractString) = lock(t.lock) do
  push!(t.dirty, path)
  t.looking && return
  t.looking = true
  errormonitor(Threads.@spawn (sleep(LOOK_WAIT); look!(t)))
  nothing
end

"""
Take in the changes that `t` kept: read again each folder that a change was
in, take away the folders that went, and read the folders that came to the
end. Only folders that a reading had are read again. The others are still to
be read.
"""
look!(t::Times) = begin
  paths = lock(t.lock) do
    t.looking = false
    p = collect(t.dirty)
    empty!(t.dirty)
    p
  end
  gone, again, came = Set{String}(), Set{String}(), String[]
  for path in paths
    st = try lstat(path) catch; nothing end
    folder = st !== nothing && isdir(st)
    had = lock(() -> haskey(t.bytes, path), t.lock)
    had && !folder && push!(gone, path)   # a folder that went, or that a file took the place of
    folder && (had ? push!(again, path) : push!(came, path))
    # The nearest folder over it that a reading had. macOS can tell only of a file in a folder that came, at any depth.
    up = lock(() -> read_over(t, path), t.lock)
    up === nothing || push!(again, up)
  end
  isempty(gone) || lock(() -> forget_under!(t, gone), t.lock)
  for dir in again
    lock(() -> haskey(t.bytes, dir), t.lock) || continue
    bytes, kids, _ = files_in(dir)
    lock(() -> set_bytes!(t, dir, bytes), t.lock)
    # macOS can tell of a folder that came only as a change in the folder that holds it
    foreach(k -> push!(came, k[1]), kids)
  end
  foreach(path -> walk!(t, path), came)
end

"The nearest folder over `path` that a reading of `t` had, or nothing. The caller holds `t`'s lock."
read_over(t::Times, path::AbstractString) = begin
  d = dirname(path)
  while length(d) > length(t.root)
    haskey(t.bytes, d) && return d
    up = dirname(d)
    up == d && break
    d = up
  end
  nothing
end

"Read the folder at `path` to the end for its size, when it came after the folder that holds it was read. A folder that a reading will still get to is left to it."
walk!(t::Times, path::AbstractString) = begin
  lock(() -> haskey(t.bytes, dirname(path)) && !haskey(t.bytes, path), t.lock) || return
  stack = [path]
  while !isempty(stack)
    dir = pop!(stack)
    claim!(t, dir) || continue
    bytes, kids, _ = files_in(dir)
    foreach(k -> push!(stack, k[1]), kids)
    lock(() -> set_bytes!(t, dir, bytes), t.lock)
    yield()
  end
end

"Forget what's known of when folders changed, and stop hearing of changes, for a test"
forget_times!() = lock(TIMES_LOCK) do
  for t in values(TIMES)
    t.monitor === nothing || close(t.monitor)
  end
  empty!(TIMES)
  nothing
end

"True when no folder of `root` is being read or waits to be, for a test"
times_read(root::AbstractString) = (t = get(TIMES, root, nothing); t === nothing || lock(() -> !t.reading && isempty(t.queue), t.lock))

# The app that's built keeps what these hold when it's made. A search that ran then never ends in the
# app, so the app starts with nothing found, and reads its file again.
__init__() = begin
  RECENT.home, RECENT.projects, RECENT.at, RECENT.done, RECENT.running = "", Project[], 0.0, false, false
  READ[] = (-1.0, Kept())
  empty!(IGNORED)
  # What was read, and what heard of changes, when the app was made, are gone
  empty!(TIMES)
  nothing
end
