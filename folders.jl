# What Ladder knows of folders, apart from the window that shows them: the
# folders that you chose as favourites, the files and folders that you chose to
# ignore, and when anything in each folder of a folder last changed, and how
# big it is. main.jl draws the table of a folder, which shows the times and the
# sizes, and the commands that use the favourites.
#
#     favourites()                       # ["/Users/jake/Desktop/Canon", ...], in the order that you put them
#     favourite!("/Users/jake/Notes")    # puts the folder at the end of the list
#     unfavourite!("/Users/jake/Notes")  # takes it off the list
#     ignore!("/Users/jake/Movies")      # Ladder leaves the folder out of its lists, as it does a hidden one
#     unignore!("/Users/jake/Movies")    # and puts it back
#     isignored("/Users/jake/Movies")
#     newest(homedir(), folders)         # when anything in each folder last changed, at any depth
#     sizes(homedir())                   # how many bytes each of those folders holds, at any depth
#
# Ladder keeps the favourites and the ignored paths in a file of its own, in
# its folder in ~/Library/Application Support, one on each line. The Finder's
# own favourites are in a file that only the Finder writes, so Ladder's list is
# apart from them. Ladder never changes an ignored file or folder, so the
# Finder and the other apps still show it.

@use "github.com/jkroso/Prospects.jl" @def
@use FileWatching

# --- the favourites ---------------------------------------------------------------------

"The file that keeps the favourites. A test names one of its own."
const FILE = Ref("")

"""
The path of the file that keeps the favourites. It's called `home`, since the
home folder's page showed the favourites when the file was first written.
"""
file() = isempty(FILE[]) ? joinpath(homedir(), "Library", "Application Support", "Ladder", "home") : FILE[]

"What the file keeps: the favourite folders in their order, and the files and folders that you chose to ignore"
@def struct Kept
  favourites::Vector{String} = String[]
  ignored::Set{String} = Set{String}()
end

"What was read from the file, with the time that the file had changed then"
const READ = Ref((-1.0, Kept()))

"""
What the file keeps now. The file is read again when it has changed, as it
does when another window of Ladder writes it. A line of another kind, like
the projects that the home folder's page used to hide, is left out.
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
      what == "ignored" && push!(k.ignored, String(where))
    end
  catch
  end
  READ[][2].ignored == k.ignored || (CHANGED[] = time())
  READ[] = (at, k)
  k
end

"Write `k` to the file"
keep!(k::Kept) = begin
  path = file()
  mkpath(dirname(path))
  write(path, join(("favourite\t$p\n" for p in k.favourites)) * join(("ignored\t$p\n" for p in sort!(collect(k.ignored)))))
  READ[][2].ignored == k.ignored || (CHANGED[] = time())
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
  p in k.favourites || keep!(Kept([k.favourites; p], k.ignored))
  nothing
end

"Take the folder at `path` off the favourites"
unfavourite!(path::AbstractString) = begin
  p, k = clean(path), kept()
  p in k.favourites && keep!(Kept(filter(!=(p), k.favourites), k.ignored))
  nothing
end

# --- what you ignore ------------------------------------------------------------------------
#
# A file or a folder that you ignore is one that Ladder leaves out, as it
# leaves out one whose name starts with a dot: its lists of a folder don't
# show it, unless they show the hidden files, and its searches don't look in
# it. It's kept by its path, so a file or a folder of the same name in another
# folder still shows.

"When the list of what you ignore last changed, in this window or in another. A list of a folder that was read before then is read again."
const CHANGED = Ref(0.0)

"The paths of the files and folders that you chose to ignore"
ignored() = kept().ignored

"True when you chose to ignore the file or the folder at `path`. `among` is what's ignored, for a caller that asks of many paths."
isignored(path::AbstractString, among=ignored()) = !isempty(among) && clean(path) in among

"Leave the file or the folder at `path` out of Ladder's lists from now on"
ignore!(path::AbstractString) = begin
  p, k = clean(path), kept()
  p in k.ignored || keep!(Kept(k.favourites, union(k.ignored, [p])))
  nothing
end

"Show the file or the folder at `path` in Ladder's lists again"
unignore!(path::AbstractString) = begin
  p, k = clean(path), kept()
  p in k.ignored && keep!(Kept(k.favourites, setdiff(k.ignored, [p])))
  nothing
end

"When the list of what you ignore last changed"
changed() = (kept(); CHANGED[])

# --- the projects -------------------------------------------------------------------------
#
#     repositories(homedir())   # ["/Users/jake/Desktop/Canon", ...]
#     projects(homedir())       # the same, newest first, as the last search found them
#
# A project is a git repository: a folder with a .git in it. The project
# picker that ⌘P opens lists them. The search looks six folders down from the
# home folder, and not in hidden folders, in folders that you ignore, in
# Library, in node_modules or in an app. It doesn't look inside a repository,
# so one inside another isn't a project of its own. In a home folder with 76
# repositories it took 0.4 seconds the first time and 0.05 seconds after that,
# so it runs on a second thread each time the picker opens, and the picker
# shows what the last search found until it ends.
#
# The newest project is the one that git last wrote in: its index, which a
# commit, `git add` and `git status` after a change write, or its HEAD, which a
# commit or a checkout writes. Reading the time of every file in 76
# repositories would take too long.

"The folders that the search for projects doesn't go into, by name. Hidden folders and apps are left out too."
const NOT_SEARCHED = Set(["Library", "node_modules"])

"The git repositories in the folder `root`, as far down as `depth` folders, apart from those in the folders that `skip` has. `root` itself isn't one."
repositories(root::AbstractString; depth::Integer=6, skip=ignored()) = begin
  found = String[]
  look(dir, d) = begin
    names = try readdir(dir) catch; return end
    d > 0 && ".git" in names && return push!(found, dir)
    d < depth || return
    for name in names
      (startswith(name, ".") || name in NOT_SEARCHED || endswith(name, ".app")) && continue
      path = joinpath(dir, name)
      path in skip && continue
      # A link to a folder isn't followed, so the search can't go round in a circle
      s = try lstat(path) catch; continue end
      isdir(s) && look(path, d + 1)
    end
  end
  look(clean(root), 0)
  found
end

"When git last wrote in the repository at `path`: its index or its HEAD. 0 when it never did."
worked_on(path::AbstractString) =
  maximum(p -> mtime(p), (joinpath(path, ".git"), joinpath(path, ".git", "index"), joinpath(path, ".git", "HEAD"), joinpath(path, ".git", "logs", "HEAD")))

"`paths` with the one that git last wrote in first"
newest_first(paths) = (times = Dict(p => worked_on(p) for p in paths); sort(paths, by=p -> times[p], rev=true))

"What the last search for projects found in the folder `root`, and the search while it runs"
mutable struct Search
  root::String
  found::Vector{String}
  task::Union{Task,Nothing}
  at::Float64
end
const SEARCH = Search("", String[], nothing, 0.0)
const SEARCH_LOCK = ReentrantLock()
"Seconds after a search starts that `projects` starts another"
const SEARCH_AGAIN = 5.0

"""
The projects in the folder `root`, newest first, as the last search found
them. A new search starts on a second thread, unless one is running or the
last one started less than `SEARCH_AGAIN` seconds ago. `searching()` gives it
while it runs.
"""
projects(root::AbstractString) = lock(SEARCH_LOCK) do
  r = clean(root)
  SEARCH.root == r || forget_projects!(r)
  if SEARCH.task === nothing && time() - SEARCH.at > SEARCH_AGAIN
    SEARCH.at = time()
    skip = ignored()   # read here, as the file can't be read on two threads at once
    SEARCH.task = Threads.@spawn begin
      found = try newest_first(repositories(r; skip)) catch; String[] end
      lock(SEARCH_LOCK) do
        SEARCH.root == r && (SEARCH.found = found)
        SEARCH.task = nothing
      end
    end
  end
  SEARCH.found
end

"The search for projects while it runs, or nothing"
searching() = lock(() -> SEARCH.task, SEARCH_LOCK)

"Forget what the searches for projects found, as a test does before it makes projects of its own. The next search is in `root`."
forget_projects!(root="") = lock(SEARCH_LOCK) do
  SEARCH.root = root
  SEARCH.found = String[]
  SEARCH.at = 0.0
end

# --- when anything in a folder last changed, and how big it is ----------------------------------
#
#     newest(homedir(), ["/Users/jake/Desktop", ...])   # Dict("/Users/jake/Desktop" => 1.795e9, ...)
#     sizes(homedir())                                  # Dict("/Users/jake/Desktop" => 48_000_000_000, ...)
#
# The table of a folder says when anything in each of its folders last
# changed: the newest time of the folder itself and of each
# folder and file in it, at any depth. Hidden folders and files don't count.
# Git changes the files in a repository's .git when Ladder only asks it
# something, and the Finder writes .DS_Store when it shows a folder.
#
# Ladder reads each folder once, on a second thread, the first time that a
# table asks for it. Most folders take a part of a second. A folder of half a
# million files took 10 seconds. Before it starts, Ladder asks macOS to tell it
# of each change in the folder of the table, at any depth (FSEvents). Each change
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

# The app that's built keeps what these hold when it's made. A reading that ran then never ends in
# the app, so the app starts with nothing read, and reads its file again.
__init__() = begin
  READ[] = (-1.0, Kept())
  # What was read, and what heard of changes, when the app was made, are gone
  empty!(TIMES)
  nothing
end
