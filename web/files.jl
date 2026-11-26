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
# The files are kept in memory, and not between runs. A page is asked for
# again when the same `Files` has kept more than `MOST` bytes: `forget!` is
# then called before the next page.

@use "./entities" latin LATIN_NAMES

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
const AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

"""
Start to get what's at the web address `address` into `file`. `about` is a
file for three lines: the address that it ended up at, the kind of file that
the site says it is, and which sites' scripts the site says may read it. It
gives a function that's true once that has ended. A file that couldn't be
had isn't there then.
"""
curl(address, file, about) = begin
  ask = `curl --silent --fail --location --max-redirs 8 --proto =http,https --proto-redir =http,https --compressed
              --connect-timeout 10 --max-time $SECONDS --max-filesize $BIGGEST --user-agent $AGENT
              --output $file --write-out "%{url_effective}\n%{content_type}\n%header{access-control-allow-origin}\n" -- $address`
  job = run(pipeline(ask, stdout=about, stderr=devnull), wait=false)
  () -> process_exited(job)
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
end
Files(; getter=curl, online=() -> true) = Files("", Dict{String,Any}(), String[], 0, 0, 0, 0, getter, online)

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
be had. A file on this computer is read at once.
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
    f.known[address] = :queued
    push!(f.queue, address)
    start!(f)
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
    job = try (f.getter(address, name, name * ".about"), name) catch; nothing end
    f.known[address] = job
    job === nothing ? (f.landed += 1) : (f.running += 1)
  end
  f
end

"Look whether the file at `address`, which was on its way, has come. What came is read into memory, and its file is deleted."
settle!(f::Files, address) = begin
  job = get(f.known, address, nothing)
  job isa Tuple || return job
  done, name = job
  (try done() catch; true end) || return job
  f.running -= 1
  got = try
    isfile(name) ? Got(read(name), about(isfile(name * ".about") ? readlines(name * ".about") : String[], address)...) : nothing
  catch
    nothing
  end
  rm(name, force=true)
  rm(name * ".about", force=true)
  # A site that doesn't say what kind of file it sent leaves the end of the file's name to say it
  got !== nothing && isempty(got.type) && (got = Got(got.bytes, kind(got.address), got.charset, got.address, got.shared))
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

"Drop every file, so that each is asked for again. The files that are on their way are left to end."
forget!(f::Files) = (empty!(f.known); empty!(f.queue); f.running = 0; f.held = 0; f)

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
