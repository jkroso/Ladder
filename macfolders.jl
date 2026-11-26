# What macOS knows about the files of its own folders, apart from the window
# that shows them: Downloads, Pictures, the folder of the screenshots and the
# Trash. main.jl draws each folder's page. This file reads the facts.
#
#     added(path)                 # when the file came into its folder, as the Finder's "Date Added"
#     site(path)                  # "github.com", the site that a downloaded file came from, or ""
#     day_name(t)                 # "Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "October 2026"
#     screenshots()               # the folder that the Mac saves screenshots to
#     origins(trash())            # "plan.pdf" => Origin("/Users/jake/Desktop", "plan.pdf"), for each thing in the Trash
#     put_back!(path, origin)     # move it from the Trash to where it was
#
# The Finder writes where each thing in the Trash came from in the Trash's
# `.DS_Store` file. `records` reads that file's format: a tree of records, each
# with a file's name, four letters that say what the record is, and a value.
# The record `ptbL` has the folder that the file was in, from the top of its
# disk, and `ptbN` has the name that it had there.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg get_value nsstring jstring with_pool
@use Dates: Dates, Date
@use "./macfile" resource date_of added made
@use "./web/url" site_name

const Object = Ptr{Cvoid}

# --- dates ------------------------------------------------------------------------------

"""
What the Finder calls the kind of the folder or the file at `path`, as its Kind
column says it: `Folder`, `PNG image`, `Markdown`, or the app that opens it, like
`Zed.app Document`. It's `Document` where macOS doesn't say. macOS answers in
about 0.1 ms.
"""
finder_kind(path::AbstractString) = begin
  Sys.isapple() || return isdir(path) ? "Folder" : "Document"
  try
    with_pool() do
      said = resource(path, "NSURLLocalizedTypeDescriptionKey")
      said != C_NULL ? jstring(said) : "Document"
    end
  catch
    "Document"
  end
end

"The day of the time `t`, in the Mac's own time zone"
day(t::Real) = Date(Libc.strftime("%Y-%m-%d", t))

"""
The name of the group of days that the time `t` is in, as the Finder names
the groups of a folder that's sorted by date: Today, Yesterday, Previous 7
Days, Previous 30 Days, and then the month, like October 2026.
"""
day_name(t::Real, now::Real=time()) = begin
  ago = Dates.value(day(now) - day(t))
  ago <= 0 ? "Today" : ago == 1 ? "Yesterday" : ago <= 7 ? "Previous 7 Days" : ago <= 30 ? "Previous 30 Days" : month_name(t)
end

"The month of the time `t`, like October 2026"
month_name(t::Real) = Libc.strftime("%B %Y", t)

"The day of the time `t` in words, like Today, Yesterday or Friday 20 November 2026"
date_name(t::Real, now::Real=time()) = begin
  ago = Dates.value(day(now) - day(t))
  ago <= 0 ? "Today" : ago == 1 ? "Yesterday" : Libc.strftime("%A %-d %B %Y", t)
end

"The time `t` in a few characters: the time of day for today, and the date for any other day"
when(t::Real, now::Real=time()) = day(t) == day(now) ? Libc.strftime("%H:%M", t) : Libc.strftime("%-d %b %Y", t)

# --- where a file came from ---------------------------------------------------------------

"The bytes that macOS keeps with the file at `path` under `name`, or nothing when it keeps none"
extra(path::AbstractString, name::AbstractString) = begin
  Sys.isapple() || return nothing
  n = ccall(:getxattr, Cssize_t, (Cstring, Cstring, Ptr{Cvoid}, Csize_t, UInt32, Cint), path, name, C_NULL, 0, 0, 0)
  n > 0 || return nothing
  data = Vector{UInt8}(undef, n)
  got = ccall(:getxattr, Cssize_t, (Cstring, Cstring, Ptr{UInt8}, Csize_t, UInt32, Cint), path, name, data, n, 0, 0)
  got == n ? data : nothing
end

"The texts of a list that macOS wrote as a property list in `data`"
texts(data::Vector{UInt8}) = begin
  found = String[]
  try
    with_pool() do
      d = ccall((:objc_msgSend, libobjc), Object, (Object, Object, Ptr{UInt8}, UInt), cls("NSData"), sel("dataWithBytes:length:"), data, length(data))
      list = ccall((:objc_msgSend, libobjc), Object, (Object, Object, Object, UInt, Object, Object),
                   cls("NSPropertyListSerialization"), sel("propertyListWithData:options:format:error:"), d, 0, C_NULL, C_NULL)
      (list != C_NULL && ccall((:objc_msgSend, libobjc), Bool, (Object, Object, Object), list, sel("isKindOfClass:"), cls("NSArray"))) || return
      for i in 0:get_value(UInt, list, "count")-1
        item = ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt), list, sel("objectAtIndex:"), i)
        ccall((:objc_msgSend, libobjc), Bool, (Object, Object, Object), item, sel("isKindOfClass:"), cls("NSString")) && push!(found, jstring(item))
      end
    end
  catch
  end
  found
end

"The addresses that the file at `path` was downloaded from, as the browser wrote them: the file's own address, and the page that had the link"
sources(path::AbstractString) = (data = extra(path, "com.apple.metadata:kMDItemWhereFroms"); data === nothing ? String[] : texts(data))

"The site that the file at `path` was downloaded from: the site of the page that had the link, or else of the file's own address. It's \"\" for a file that wasn't downloaded."
site(path::AbstractString) = begin
  found = filter(!isempty, map(site_name, sources(path)))
  isempty(found) ? "" : last(found)
end

# --- the folder of the screenshots --------------------------------------------------------

"The folder that the Mac saves screenshots to: the one that its settings name, or the Desktop"
screenshots() = begin
  usual = joinpath(homedir(), "Desktop")
  Sys.isapple() || return usual
  try
    with_pool() do
      defaults = msg(msg(msg(cls("NSUserDefaults"), "alloc"), "initWithSuiteName:", nsstring("com.apple.screencapture")), "autorelease")
      at = msg(defaults, "stringForKey:", nsstring("location"))
      at == C_NULL && return usual
      path = String(rstrip(abspath(expanduser(jstring(at))), '/'))
      isdir(path) ? path : usual
    end
  catch
    usual
  end
end

# --- the Trash ------------------------------------------------------------------------------

"The folder of the Trash of the disk that the home folder is on"
trash() = joinpath(homedir(), ".Trash")

"Where something in the Trash came from: the folder that it was in, and the name that it had there"
@def struct Origin
  folder::String = ""
  name::String = ""
end

be32(b, i) = Int(b[i]) << 24 | Int(b[i+1]) << 16 | Int(b[i+2]) << 8 | Int(b[i+3])
utf16(b, i, n) = transcode(String, [UInt16(b[i+2k]) << 8 | UInt16(b[i+2k+1]) for k in 0:n-1])

"""
The records of a `.DS_Store` file whose bytes are `b`: the file that each is
about, the four letters that say what it is, and its value. A value is text, a
number, or bytes. It throws when the bytes aren't such a file.
"""
records(b::Vector{UInt8}) = begin
  (length(b) > 36 && be32(b, 1) == 1 && b[5:8] == codeunits("Bud1")) || error("Not a .DS_Store file")
  # Every place in the file is counted from its fifth byte
  info = be32(b, 9) + 4
  count = be32(b, info + 1)
  addresses = [be32(b, info + 9 + 4k) for k in 0:count-1]
  # A block's address has its size in its last five bits
  block(id) = (addresses[id+1] & ~31) + 4
  at = info + 9 + 4 * 256 * cld(max(count, 1), 256)
  tree = -1
  for _ in 1:be32(b, at)
    n = Int(b[at+4])
    name = String(b[at+5:at+4+n])
    id = be32(b, at + 5 + n)
    name == "DSDB" && (tree = id)
    at += 5 + n
  end
  tree >= 0 || error("The .DS_Store file has no tree")
  found = Tuple{String,String,Any}[]
  # A record, at `i`: it gives where the next thing starts
  record(i) = begin
    n = be32(b, i)
    file = utf16(b, i + 4, n)
    i += 4 + 2n
    id, kind = String(b[i:i+3]), String(b[i+4:i+7])
    i += 8
    value, i = kind in ("long", "shor") ? (be32(b, i), i + 4) :
               kind == "bool" ? (b[i] != 0, i + 1) :
               kind == "blob" ? (len = be32(b, i); (b[i+4:i+3+len], i + 4 + len)) :
               kind == "type" ? (String(b[i:i+3]), i + 4) :
               kind == "ustr" ? (len = be32(b, i); (utf16(b, i + 4, len), i + 4 + 2len)) :
               kind in ("comp", "dutc") ? (b[i:i+7], i + 8) : error("A record of the kind $kind")
    push!(found, (file, id, value))
    i
  end
  # A node of the tree: its records, with the nodes under it between them
  node(id, deep) = begin
    deep > 32 && error("The .DS_Store file's tree is too deep")
    i = block(id) + 1
    last, n = be32(b, i), be32(b, i + 4)
    i += 8
    for _ in 1:n
      last == 0 || (node(be32(b, i), deep + 1); i += 4)
      i = record(i)
    end
    last == 0 || node(last, deep + 1)
  end
  node(be32(b, block(tree) + 1), 0)
  found
end

"""
Where each thing in the Trash folder `dir` came from, by its name in the
Trash, as the Finder wrote it in the folder's `.DS_Store` file. A thing that
the Finder wrote nothing about isn't there. `disk` is the top folder of the
disk that the Trash is on.
"""
origins(dir::AbstractString=trash(); disk::AbstractString="/") = begin
  found = Dict{String,Origin}()
  recs = try records(read(joinpath(dir, ".DS_Store"))) catch; return found end
  folders, names = Dict{String,String}(), Dict{String,String}()
  for (file, id, value) in recs
    value isa String || continue
    id == "ptbL" && (folders[file] = value)
    id == "ptbN" && (names[file] = value)
  end
  for (file, folder) in folders
    found[file] = Origin(folder=plain(String(rstrip(joinpath(disk, folder), '/'))), name=get(names, file, file))
  end
  found
end

# The Finder can write a folder of the Mac's own disk from the place that macOS keeps the disk's data at
const DATA = "/System/Volumes/Data"

"The path `path` without the place that macOS keeps the data of its own disk at, which the Finder can write before a folder"
plain(path::AbstractString) = startswith(path, DATA * "/") ? String(path[length(DATA)+1:end]) : String(path)

"A path in the folder `dir` for something called `name` that nothing has yet: `name`, or else `name` with 2, 3 and so on before its ending"
free(dir::AbstractString, name::AbstractString) = begin
  path = joinpath(dir, name)
  base, ending = splitext(name)
  n = 2
  while ispath(path)
    path = joinpath(dir, "$base $n$ending")
    n += 1
  end
  path
end

"""
Move the folder or the file at `path` out of the Trash, back to where
`origin` says it was, and give its new path. When something else has its
name there now, it gets a number after its name. It throws when the folder
that it was in is gone.
"""
put_back!(path::AbstractString, origin::Origin) = begin
  isdir(origin.folder) || error("The folder that it was in, $(origin.folder), isn't there any more.")
  to = free(origin.folder, origin.name)
  mv(path, to)
  to
end

# --- the words in a picture ---------------------------------------------------------------
#
# macOS reads the words that a picture shows, like the text of a screenshot.
# It takes a part of a second for each picture, and half a minute the first
# time after the Mac starts. So a second thread does the reading, one picture
# after another, and the window never waits: `words` gives what's known now,
# and asks for the rest. What was read is kept in a file beside the Mac's
# caches, so each picture is read once.
#
#     words(path)      # "ladder read only main 18 changes ...", or nothing while it isn't read yet
#     reading()        # how many pictures still wait
#     version[]        # grows each time a picture has been read

const Vision = "/System/Library/Frameworks/Vision.framework/Vision"

"The words that macOS reads in the picture at `path`, one line of the picture to a line. It waits for macOS."
read_words(path::AbstractString) = begin
  Sys.isapple() || return ""
  Base.Libc.Libdl.dlopen(Vision)
  with_pool() do
    url = msg(cls("NSURL"), "fileURLWithPath:", nsstring(path))
    handler = msg(ccall((:objc_msgSend, libobjc), Object, (Object, Object, Object, Object),
                        msg(cls("VNImageRequestHandler"), "alloc"), sel("initWithURL:options:"), url, msg(cls("NSDictionary"), "dictionary")), "autorelease")
    request = msg(msg(msg(cls("VNRecognizeTextRequest"), "alloc"), "init"), "autorelease")
    requests = msg(cls("NSArray"), "arrayWithObject:", request)
    # Julia's other threads go on while macOS reads, and can free memory
    ok = @ccall gc_safe=true libobjc.objc_msgSend(handler::Object, sel("performRequests:error:")::Object, requests::Object, C_NULL::Object)::Bool
    ok || return ""
    results = msg(request, "results")
    results == C_NULL && return ""
    lines = String[]
    for i in 0:get_value(UInt, results, "count")-1
      seen = ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt), results, sel("objectAtIndex:"), i)
      best = msg(ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt), seen, sel("topCandidates:"), 1), "firstObject")
      best == C_NULL || push!(lines, jstring(msg(best, "string")))
    end
    join(lines, '\n')
  end
end

# What reads a picture's words. A test puts a function of its own here.
const reader = Ref{Function}(read_words)
"The file that keeps the words of each picture, in the home folder of whoever runs Ladder. A test names one of its own."
const words_file = Ref("")
"The file that keeps the words of each picture when nothing else is named"
usual_words_file() = joinpath(homedir(), "Library", "Caches", "Ladder", "picture-words.tsv")

const words_lock = ReentrantLock()
"The words of each picture that was read, in small letters, by its path, with when its file had changed"
const WORDS = Dict{String,Tuple{Float64,String}}()
"The paths of the pictures that wait to be read, the first to read first"
const waiting = String[]
"Grows each time a picture has been read, so that a view knows to look again"
const version = Ref(0)
const working = Ref(false)   # the thread that reads is running
const loaded = Ref("")       # the file that `WORDS` was last read from
const unsaved = Ref(0)       # how many pictures were read since the file was written

# The app that's built keeps what these hold when it's made, on the Mac that made it. So the app starts
# with nothing read, no thread at work, and the file in the home folder of whoever runs it.
__init__() = begin
  empty!(WORDS); empty!(waiting)
  working[], loaded[], unsaved[] = false, "", 0
  words_file[] = usual_words_file()
  nothing
end

"Read the file of the words, once for each file that `words_file` names"
load_words!() = begin
  loaded[] == words_file[] && return
  loaded[] = words_file[]
  empty!(WORDS)
  isfile(words_file[]) || return
  for line in eachline(words_file[])
    f = split(line, '\t', limit=3)
    length(f) == 3 || continue
    at = tryparse(Float64, f[1])
    at === nothing || (WORDS[String(f[2])] = (at, String(f[3])))
  end
  nothing
end

"Write the words of each picture that's still there to the file"
save_words!() = begin
  unsaved[] = 0
  try
    mkpath(dirname(words_file[]))
    open(words_file[] * ".part", "w") do io
      for (path, (at, text)) in WORDS
        isfile(path) && println(io, at, '\t', path, '\t', text)
      end
    end
    mv(words_file[] * ".part", words_file[], force=true)
  catch
  end
  nothing
end

"Read the pictures that wait, one after another, until none waits"
work!() = begin
  while true
    path = lock(words_lock) do
      isempty(waiting) ? nothing : first(waiting)
    end
    path === nothing && break
    at = mtime(path)
    text = try lowercase(replace(reader[](path), r"\s+" => " ")) catch; "" end
    lock(words_lock) do
      WORDS[path] = (at, text)
      filter!(!=(path), waiting)
      version[] += 1
      unsaved[] += 1
      (isempty(waiting) || unsaved[] >= 25) && save_words!()
    end
  end
  lock(() -> (working[] = false), words_lock)
  nothing
end

"""
The words in the picture at `path`, in small letters with one space between
them, or nothing while the picture isn't read yet. A picture that isn't read
is put with the ones that wait, and a second thread reads them. `at` is when
the picture's file last changed, for a caller that knows it already.
"""
words(path::AbstractString, at::Real=mtime(path)) = lock(words_lock) do
  load_words!()
  kept = get(WORDS, path, nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  path in waiting || push!(waiting, path)
  if !working[]
    working[] = true
    Threads.@spawn work!()
  end
  nothing
end

"How many pictures wait to be read"
reading() = lock(() -> length(waiting), words_lock)

"Leave the pictures that wait unread, when nobody asks for their words any more. The one that's being read is finished."
stop_reading!() = lock(words_lock) do
  length(waiting) > 1 && resize!(waiting, 1)
  nothing
end
