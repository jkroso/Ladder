# Gets the files that a page names from the web, in the background.
#
#     f = Files()
#     ask!(f, "https://julialang.org/")    # start to get it, unless it's here or on its way
#     state(f, address)                    # :none, :coming, :there or :failed
#     got = file(f, address)               # what came, once it's there: got.bytes, got.type, got.address
#     text(got)                            # its bytes as text, in the characters that it says it's written in
#     load = loader(f, page)               # a `load` for `page` and `live`, for the page at the address `page`: see below
#     readable(f, address, page)           # true when a script of that page may read what came from `address`
#     f.landed                             # how many files have come, or couldn't be had, so far
#     coming(f)                            # how many are on their way
#     forget!(f)                           # drop everything, so that each file is asked for again
#     forget!(f; again=true)               # and ask each site whether the copy kept on the disk is still its file, as a reload does
#
# `loader(f, page)` gives the function that main.jl and live.jl call `load`. It
# gives the bytes of a file that's here. For one that isn't, it starts to get
# it and gives `:waiting`: the page shows without it, and the caller lays the
# page out again when `f.landed` has grown. It gives nothing for a file that
# couldn't be had.
#
# Two rules keep a page from the web away from what isn't its own, as a
# browser does:
#
# - A page from the web gets no file of this computer. Only a page that's a
#   file of this computer itself does.
# - A page shows a picture, a sheet or a script from any site. But a script
#   reads what came from another site (`fetch`, XMLHttpRequest) only when
#   that site says that any page may, or that this page's site may, with
#   `Access-Control-Allow-Origin`. `readable` says so. Nothing is sent with a
#   request that says who you are: no cookie and no password.
#
# `curl` gets each file, in a process of its own, so nothing here waits. No
# more than `AT_ONCE` of them run at a time: the rest wait their turn, in the
# order that they were asked for. It follows a page to where it has moved:
# `got.address` is where it ended up, which the addresses in the page are
# from. A file on this computer, written as `file:///Users/...` or as a
# path, is read when it's asked for.
#
# The files are kept in memory. A page is asked for again when the same
# `Files` has kept more than `MOST` bytes: `forget!` is then called before
# the next page.
#
# What a site says may be kept is also kept on the disk, in `CACHE[]`, between
# runs and for every page that names it, as a browser keeps it. So the sheets,
# the scripts, the fonts and the pictures that come from a CDN are got once. A
# kept file is used without asking its site for as long as the site said that
# it stays fresh (`Cache-Control: max-age`, or `Expires`). After that its site
# is asked whether it has changed, with what the site gave to tell the copy
# apart (`ETag`, `Last-Modified`), and a site that says it hasn't (304) sends
# nothing. A file that the site says not to keep (`no-store`) isn't kept. When
# the kept files come to more than `CACHE_MOST` bytes, those used longest ago
# are deleted. Only `curl` keeps files there: a test's own getter keeps none.

@use Dates: DateTime, datetime2unix
@use "./entities" latin LATIN_NAMES
@use "./fetch" => Webfetch

"What came from an address: the bytes, the kind of file that the site says it is, and the address that it ended up at"
struct Got
  bytes::Vector{UInt8}
  type::String      # like "text/html", in lower case, without what follows a ;
  charset::String   # the characters that the site says it's written in, in lower case, or ""
  address::String
  shared::String    # which sites' scripts may read it, as the site says: "*" for any, the start of an address for one, or ""
end

const SECONDS = 30                # how long a file can take to come
const MOST = 256 * 1024 * 1024    # bytes: a set of files that holds more than this is emptied before the next page
const BIGGEST = 32 * 1024 * 1024  # bytes: a file bigger than this isn't got
const AT_ONCE = 8                 # how many files come at a time
# Many sites give a page only to a program that says it's a browser
const AGENT = Webfetch.AGENT

"""
Start to get what's at the web address `address` into `file`. `about` is a
file for lines: the address that it ended up at, the kind of file that the
site says it is, which sites' scripts the site says may read it, then the
code of the answer and what the site says of keeping it: `Cache-Control`,
`Expires`, `Date`, `ETag`, `Last-Modified` and `Age`. It gives a function
that's true once that has ended. A file that couldn't be had isn't there
then, nor is one that the site says hasn't changed (304). `headers` are sent
with the request.
"""
curl(address, file, about; headers=String[]) = begin
  said = ["%{url_effective}", "%{content_type}", "%header{access-control-allow-origin}", "%{http_code}", "%header{cache-control}",
          "%header{expires}", "%header{date}", "%header{etag}", "%header{last-modified}", "%header{age}"]
  job = Webfetch.start(address, file; seconds=SECONDS, biggest=BIGGEST, headers, about, write_out=said)
  () -> process_exited(job)
end

# --- the files kept on the disk -----------------------------------------------------------------

"Where files are kept between runs, or \"\" to keep none"
const CACHE = Ref(joinpath(homedir(), "Library", "Caches", "Ladder", "web"))
const CACHE_MOST = 512 * 1024 * 1024    # bytes: when the kept files come to more than this, the ones used longest ago are deleted
const LONGEST_GUESS = 7 * 24 * 3600.0   # seconds: the longest that a file whose site doesn't say how long it stays fresh is used without asking
const PRUNED = Ref(0.0)                 # when the kept files were last counted

"A file that's kept on the disk: what came, until when it's fresh, what the site gave to tell it apart, and when the site last sent it or said it hadn't changed"
struct Kept
  got::Got
  fresh::Float64     # Unix time
  tag::String        # what the site said its ETag is
  changed::String    # and its Last-Modified
  checked::Float64   # Unix time
end

"The name of the file that keeps what came from `address`: a hash of the address that's the same in each run"
kept_name(address::AbstractString) = begin
  h = 0xcbf29ce484222325
  for b in codeunits(address)
    h = (h ⊻ b) * 0x00000100000001b3
  end
  string(h, base=16, pad=16)
end

"What's kept in the folder `dir` for `address`, or nothing"
kept(dir::AbstractString, address::AbstractString) = begin
  isempty(dir) && return nothing
  file = joinpath(dir, kept_name(address))
  try
    (isfile(file) && isfile(file * ".about")) || return nothing
    lines = readlines(file * ".about")
    (length(lines) >= 9 && lines[1] == address) || return nothing   # another address whose name is the same
    Kept(Got(read(file), lines[3], lines[4], lines[2], lines[5]), parse(Float64, lines[6]), lines[7], lines[8], parse(Float64, lines[9]))
  catch
    nothing
  end
end

"Keep `k`, what came from `address`, in the folder `dir`. With `bytes=false`, only what's said about the file that's kept changes."
keep!(dir::AbstractString, address::AbstractString, k::Kept; bytes=true) = begin
  isempty(dir) && return
  file = joinpath(dir, kept_name(address))
  try
    mkpath(dir)
    if bytes
      write(file * ".part", k.got.bytes)
      mv(file * ".part", file; force=true)
    end
    write(file * ".about", join([address, k.got.address, k.got.type, k.got.charset, k.got.shared, k.fresh, k.tag, k.changed, k.checked], '\n'))
  catch
  end
  bytes && prune!(dir)
  nothing
end

"Delete the kept files used longest ago, when all of them come to more than `CACHE_MOST` bytes. They're counted once an hour at most."
prune!(dir::AbstractString) = begin
  time() - PRUNED[] < 3600 && return
  PRUNED[] = time()
  try
    files = [(f, filesize(f), mtime(f)) for f in (joinpath(dir, n) for n in readdir(dir) if !occursin('.', n))]
    total = sum(f[2] for f in files; init=0)
    total <= CACHE_MOST && return
    for (f, size, _) in sort(files, by=last)
      rm(f, force=true)
      rm(f * ".about", force=true)
      (total -= size) <= 0.8 * CACHE_MOST && break
    end
  catch
  end
  nothing
end

const MONTHS = ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")

"The Unix time of a date as a site writes it, like `Wed, 21 Oct 2015 07:28:00 GMT`, or nothing"
http_time(text::AbstractString) = begin
  m = match(r"(\d{1,2})[ -]([A-Za-z]{3})[ -](\d{2,4}) (\d{1,2}):(\d{2}):(\d{2})", text)
  m === nothing && return nothing
  month = findfirst(==(lowercase(m[2])), MONTHS)
  month === nothing && return nothing
  year = parse(Int, m[3])
  year < 100 && (year += year < 70 ? 2000 : 1900)
  try datetime2unix(DateTime(year, month, parse(Int, m[1]), parse(Int, m[4]), parse(Int, m[5]), parse(Int, m[6]))) catch; nothing end
end

"""
Until when a file that came at the Unix time `now` is fresh, by what its site
said: `Cache-Control`, `Expires`, `Date`, `Last-Modified` and `Age`. Nothing
when the site says not to keep it. A site that says nothing of how long, but
when the file last changed, gets a tenth of the time since then, as browsers
give it, and no more than `LONGEST_GUESS`.
"""
freshness(control, expires, date, changed, age, now) = begin
  words = lowercase(control)
  occursin(r"(^|[\s,])no-store\b", words) && return nothing
  occursin(r"(^|[\s,])no-cache\b", words) && return now
  aged = something(tryparse(Float64, strip(age)), 0.0)
  m = match(r"(^|[\s,])max-age\s*=\s*\"?(\d+)", words)
  m !== nothing && return now + max(0.0, parse(Float64, m[2]) - aged)
  sent = something(http_time(date), now)
  if !isempty(strip(expires))
    until = http_time(expires)   # an Expires that isn't a date, like 0, means that the file is stale already
    return until === nothing ? now : now + max(0.0, until - sent - aged)
  end
  last = http_time(changed)
  last === nothing ? now : now + min(LONGEST_GUESS, 0.1 * max(0.0, sent - last))
end

"The files that pages asked for"
mutable struct Files
  dir::String                 # where a file is while it comes
  # For each address: what came, nothing if it couldn't be had, the function that says if it has come with the name of
  # its file, or `:queued` while it waits its turn
  known::Dict{String,Any}
  queue::Vector{String}       # the addresses that wait their turn, in the order that they were asked for
  running::Int                # how many files are coming now
  count::Int                  # how many were asked for, which names the next file
  landed::Int                 # how many have come or couldn't be had
  held::Int                   # how many bytes are kept
  getter::Function            # what gets a file: `curl`, or a function of a test's
  online::Function            # true when the web may be asked. With false, a file that isn't here couldn't be had.
  cache::String               # the folder where files are kept between runs, or "" to keep none
  checking::Dict{String,Kept} # the kept copy of each file whose site is being asked whether it has changed
  since::Float64              # a copy kept before this Unix time is checked with its site, however fresh: see `forget!`
end
Files(; getter=curl, online=() -> true, cache=getter === curl ? CACHE[] : "") =
  Files("", Dict{String,Any}(), String[], 0, 0, 0, 0, getter, online, cache, Dict{String,Kept}(), 0.0)

"The address without what follows a #, which names a place in the file and isn't sent to the site"
bare(address::AbstractString) = String(first(split(strip(address), '#', limit=2)))

# The ends of the names of the files whose kind this file knows without a site to say it
const KINDS = Dict("html" => "text/html", "htm" => "text/html", "css" => "text/css", "js" => "text/javascript", "mjs" => "text/javascript",
                   "json" => "application/json", "svg" => "image/svg+xml", "png" => "image/png", "jpg" => "image/jpeg", "jpeg" => "image/jpeg",
                   "gif" => "image/gif", "webp" => "image/webp", "txt" => "text/plain", "md" => "text/plain", "xml" => "text/xml",
                   "woff" => "font/woff", "woff2" => "font/woff2", "ttf" => "font/ttf", "otf" => "font/otf", "mp4" => "video/mp4", "mov" => "video/quicktime")

"The kind of file that the end of the name of `path` says, or \"\""
kind(path::AbstractString) = get(KINDS, lowercase(lstrip(splitext(first(split(path, r"[?#]", limit=2)))[2], '.')), "")

"The path of the file on this computer that `address` names, or nothing for an address on the web"
path(address::AbstractString) = begin
  m = match(r"^file://(?:localhost)?(/.*)$"i, address)
  m !== nothing && return replace(String(m[1]), r"%([0-9a-fA-F]{2})" => s -> Char(parse(UInt8, s[2:3], base=16)))
  startswith(address, '/') ? String(address) : nothing
end

"What the lines about a file say: its kind, its characters, the address that it ended up at, and which sites' scripts may read it"
about(lines, address) = begin
  ended = length(lines) >= 1 && !isempty(strip(lines[1])) ? String(strip(lines[1])) : address
  said = length(lines) >= 2 ? lowercase(strip(lines[2])) : ""
  m = match(r"charset\s*=\s*\"?([\w-]+)", said)
  (String(strip(first(split(said, ';')))), m === nothing ? "" : String(m[1]), ended, length(lines) >= 3 ? String(strip(lines[3])) : "")
end

"The start of a web address, as far as the name of its computer and its port, in lower case: https://julialang.org. It's \"\" for any other address."
origin(address::AbstractString) = (m = match(r"^https?://[^/?#]+"i, address); m === nothing ? "" : lowercase(m.match))

"Note that the file at `address` has come, or with nothing that it couldn't be had"
land!(f::Files, address, got) = begin
  f.known[address] = got
  f.landed += 1
  got === nothing || (f.held += length(got.bytes))
  got
end

"""
Start to get the file at `address`, unless it's here, on its way, or couldn't
be had. A file on this computer is read at once, and so is a fresh copy that
was kept on the disk.
"""
ask!(f::Files, address::AbstractString) = begin
  address = bare(address)
  (isempty(address) || haskey(f.known, address)) && return f
  local_path = path(address)
  if local_path !== nothing
    land!(f, address, try Got(read(local_path), kind(local_path), "", address, "") catch; nothing end)
  elseif !occursin(r"^https?://[^/\s]"i, address) || !f.online()
    land!(f, address, nothing)
  else
    k = kept(f.cache, address)
    if k !== nothing && k.fresh > time() && k.checked >= f.since
      try touch(joinpath(f.cache, kept_name(address))) catch end   # it was used now, so it's deleted after the files used longer ago
      land!(f, address, k.got)
    else
      k === nothing || (f.checking[address] = k)
      f.known[address] = :queued
      push!(f.queue, address)
      start!(f)
    end
  end
  f
end

"Start to get the files that wait their turn, for as long as fewer than `AT_ONCE` are coming"
start!(f::Files) = begin
  while f.running < AT_ONCE && !isempty(f.queue)
    address = popfirst!(f.queue)
    get(f.known, address, nothing) === :queued || continue   # it was forgotten since
    isempty(f.dir) && (f.dir = mktempdir())
    name = joinpath(f.dir, string(f.count += 1))
    # A kept copy that isn't fresh is sent back only if it has changed
    k = get(f.checking, address, nothing)
    asks = k === nothing ? String[] : [(isempty(k.tag) ? String[] : ["If-None-Match: $(k.tag)"]); (isempty(k.changed) ? String[] : ["If-Modified-Since: $(k.changed)"])]
    job = try (isempty(asks) ? f.getter(address, name, name * ".about") : f.getter(address, name, name * ".about"; headers=asks), name) catch; nothing end
    f.known[address] = job
    job === nothing ? (f.landed += 1) : (f.running += 1)
  end
  f
end

"""
What came from `address` is `got`, or nothing, and `lines` are what the site
said of it (see `curl`). A file that the site says may be kept is kept on the
disk. A site that says that the kept copy hasn't changed gives that copy,
and so does a site that doesn't answer.
"""
kept!(f::Files, address, got, lines) = begin
  isempty(f.cache) && return got
  said(i) = length(lines) >= i ? String(strip(lines[i])) : ""
  old = pop!(f.checking, address, nothing)
  now = time()
  if said(4) == "304" && old !== nothing
    fresh = freshness(said(5), said(6), said(7), old.changed, said(10), now)
    keep!(f.cache, address, Kept(old.got, something(fresh, now), isempty(said(8)) ? old.tag : said(8), old.changed, now); bytes=false)
    return old.got
  end
  got === nothing && return old === nothing ? nothing : old.got
  said(4) == "200" || return got
  fresh = freshness(said(5), said(6), said(7), said(9), said(10), now)
  # A file that's stale at once, and that the site gave nothing to tell apart, would be got again in full: it isn't kept
  (fresh === nothing || (fresh <= now && isempty(said(8)) && isempty(said(9)))) && return got
  keep!(f.cache, address, Kept(got, fresh, said(8), said(9), now))
  got
end

"Look whether the file at `address`, which was on its way, has come. What came is read into memory, and its file is deleted."
settle!(f::Files, address) = begin
  job = get(f.known, address, nothing)
  job isa Tuple || return job
  done, name = job
  (try done() catch; true end) || return job
  f.running -= 1
  lines = try isfile(name * ".about") ? readlines(name * ".about") : String[] catch; String[] end
  got = try
    isfile(name) ? Got(read(name), about(lines, address)...) : nothing
  catch
    nothing
  end
  rm(name, force=true)
  rm(name * ".about", force=true)
  # A site that doesn't say what kind of file it sent leaves the end of the file's name to say it
  got !== nothing && isempty(got.type) && (got = Got(got.bytes, kind(got.address), got.charset, got.address, got.shared))
  got = kept!(f, address, got, lines)
  land!(f, address, got)
  start!(f)
  got
end

"What's known of the file at `address`: `:none` when nothing asked for it, `:coming`, `:there`, or `:failed` when it couldn't be had"
state(f::Files, address::AbstractString) = begin
  address = bare(address)
  haskey(f.known, address) || return :none
  got = settle!(f, address)
  got isa Got ? :there : got === nothing ? :failed : :coming
end

"What came from `address`, or nothing while it isn't here"
file(f::Files, address::AbstractString) = (got = settle!(f, bare(address)); got isa Got ? got : nothing)

"How many files are on their way, or wait their turn. This looks whether each has come."
coming(f::Files) = count(address -> (job = settle!(f, address); job isa Tuple || job === :queued), collect(keys(f.known)))

"""
Drop every file, so that each is asked for again. The files that are on their
way are left to end. With `again`, as for a reload, each copy kept on the disk
until now is checked with its site, however fresh the site said it is.
"""
forget!(f::Files; again=false) = begin
  empty!(f.known); empty!(f.queue); empty!(f.checking)
  f.running, f.held = 0, 0
  again && (f.since = time())
  f
end

"""
The `load` of the files `f`, for `page` and `live`, for the page at the
address `page`: the bytes of the file at an address, `:waiting` for one
that's on its way, which it starts to get, and nothing for one that couldn't
be had. A page from the web gets no file of this computer.
"""
loader(f::Files, page::AbstractString="") = address -> begin
  (path(address) === nothing || path(page) !== nothing) || return nothing
  ask!(f, address)
  s = state(f, address)
  s == :there ? file(f, address).bytes : s == :coming ? :waiting : nothing
end

"""
True when a script of the page at the address `page` may read what came from
`address`: the file is from the page's own site, or its site says that any
page's scripts may read it, or this page's. A page that's a file of this
computer reads the files of this computer.
"""
readable(f::Files, address::AbstractString, page::AbstractString) = begin
  path(address) !== nothing && return path(page) !== nothing
  from = origin(page)
  # A file that the site moved is from where it ended up
  got = file(f, address)
  ended = got === nothing ? address : got.address
  (!isempty(from) && origin(address) == from && origin(ended) == from) && return true
  got !== nothing && (got.shared == "*" || (!isempty(from) && lowercase(got.shared) == from))
end

"""
The bytes of a file as text. Most files are in UTF-8. One that says it's in
Latin-1 or Windows-1252, where the site says the kind of file or near the top
of a page, is read as that. Any other is read as UTF-8, without the bytes
that aren't.
"""
text(bytes::Vector{UInt8}, charset::AbstractString="") = begin
  isvalid(String, bytes) && return String(copy(bytes))
  set = charset
  if isempty(set)
    # A page says what it's written in near its top, in letters that every set of characters has
    top = String([b < 0x80 ? b : UInt8('?') for b in view(bytes, 1:min(length(bytes), 4096))])
    m = match(r"charset\s*=\s*[\"']?\s*([\w-]+)"i, top)
    set = m === nothing ? "" : lowercase(m[1])
  end
  set in LATIN_NAMES && return latin(bytes)
  filter(isvalid, String(copy(bytes)))
end
text(got::Got) = text(got.bytes, got.charset)

export Files, Got, ask!, state, file, coming, forget!, loader, readable, text
