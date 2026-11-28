# A link card shows what a web page says of itself: its title, a line or two
# of its description, its picture and the name of its site. In a document a
# card is written as a picture is, on a line of its own, with the address of
# a page in place of the picture's:
#
#     ![Julia](https://julialang.org)
#
# What's at the address decides what the line shows. A web page shows as a
# card, and a picture as a picture.
#
# This file reads the HTML of a page into a card: its `og:title`,
# `og:description`, `og:image` and `og:site_name`, then its <title> and its
# <meta name="description"> where those are missing. It gets the page with
# `curl`, and keeps what it read in a folder, so that a card shows at once the
# next time, and with no network. It reads only the start of a page. It runs
# nothing from the page, and it keeps only those texts and two addresses: the
# picture's and the icon's. It draws nothing.

@use "./web/entities" entities latin LATIN_NAMES
@use "./web/fetch" => Webfetch
@use "./web/url" resolve site_name

"""
What a web page says of itself. A text that the page doesn't give is empty.
`page` is false when what's at the address turned out to be something other
than a web page, like a picture. Until Ladder knows, it's true.
"""
struct Card
  url::String           # the address of the page
  title::String
  description::String
  image::String         # the address of its picture
  site::String          # the name of its site
  icon::String          # the address of the site's icon
  page::Bool
end

Card(url::AbstractString; title="", description="", image="", site="", icon="", page=true) = Card(url, title, description, image, site, icon, page)

"True when `text` is a web address and nothing else: it starts with http:// or https://, and it names a computer"
isaddress(text::AbstractString) = occursin(r"^https?://\S+$"i, text) && !isempty(site_name(text))

"The start of the web address `url`, as far as the first / after the name of its computer: https://www.bunnings.com.au"
origin(url::AbstractString) = (m = match(r"^https?://[^/?#]+"i, url); m === nothing ? "" : String(m.match))

"The part of the web address `url` that names a file on its computer: what follows the computer's name, without what follows a ? or a #"
path(url::AbstractString) = String(first(split(chop(url, head=length(origin(url)), tail=0), r"[?#]", limit=2)))

"""
The whole web address that `href` means in a page at the address `base`.
`/logo.png` is a file of the page's computer, and `logo.png` is a file beside
the page. It's empty for an address that isn't on the web, like `data:`.
"""
absolute(href::AbstractString, base::AbstractString) = begin
  href = String(strip(href))
  (isempty(href) || any(c -> isspace(c) || iscntrl(c), href)) && return ""
  full = resolve(base, href)
  occursin(r"^https?://"i, full) && !isempty(site_name(full)) ? full : ""
end

# --- reading the HTML of a page ---------------------------------------------------------

"`text` as a card shows it: its entities as characters, each run of spaces and new lines as one space, and no more than `most` characters"
tidy(text::AbstractString, most::Int=400) = begin
  words = join(split(replace(entities(text), r"[\x00-\x1f\x7f ​  ]" => " ")), " ")
  length(words) > most ? String(rstrip(first(words, most))) * "…" : words
end

"""
The text of the bytes of a page. Most pages are in UTF-8. A page that says it's
in Latin-1 or Windows-1252 is read as that. It's nothing for a page in a set of
characters that this file can't read, so that a card never shows wrong letters.
"""
text(bytes::Vector{UInt8}) = begin
  # A page that was cut after 200 kB can end in part of a character
  for cut in 0:min(3, length(bytes))
    isvalid(String, view(bytes, 1:length(bytes)-cut)) && return String(bytes[1:end-cut])
  end
  # The page says what it's written in near its top, in letters that every set of characters has
  top = String([b < 0x80 ? b : UInt8('?') for b in view(bytes, 1:min(length(bytes), 4096))])
  m = match(r"charset\s*=\s*[\"']?\s*([\w-]+)"i, top)
  set = m === nothing ? "utf-8" : lowercase(m[1])
  (set in LATIN_NAMES || set in ("us-ascii", "ascii")) && return latin(bytes)
  # A page in UTF-8 with a wrong byte or two is read without them
  set in ("utf-8", "utf8") ? filter(isvalid, String(copy(bytes))) : nothing
end

# A tag can have a > inside the quotes of an attribute
const TAG = r"<(meta|link|title|base)\b((?:[^>\"']|\"[^\"]*\"|'[^']*')*)>"i
const ATTRIBUTE = r"([a-zA-Z_:][-\w:.]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\"'>]+))"
# What a page holds that isn't its own words: comments, code and styles. One that the cut left open goes on to the end.
const NOT_WORDS = r"<!--.*?(?:-->|$)|<(script|style|noscript|template|svg)\b.*?(?:</\1\s*>|$)"is

"The attributes of a tag, by name in lower case: `content=\"Paint\"` gives \"content\" => \"Paint\""
attributes(inside::AbstractString) =
  Dict{String,String}(lowercase(m[1]) => String(something(m[2], m[3], m[4])) for m in eachmatch(ATTRIBUTE, inside))

"""
The card of the page at the address `url`, read from `html`, the text of the
page or of its start. A page says these things in its <head>: `og:title` or
<title>, `og:description` or <meta name="description">, `og:image`, and
`og:site_name`. Where a page says a thing twice, the first counts.
"""
card(html::AbstractString, url::AbstractString) = begin
  html = replace(html, NOT_WORDS => " ")
  said = Dict{String,String}()
  title, icon, base = "", "", String(url)
  for m in eachmatch(TAG, html)
    tag, a = lowercase(m[1]), attributes(m[2])
    if tag == "meta"
      key = lowercase(strip(get(a, "property", get(a, "name", ""))))
      value = strip(get(a, "content", ""))
      isempty(key) || isempty(value) || get!(said, key, String(value))
    elseif tag == "title" && isempty(title)
      # The words of the title go on to the tag that closes it
      from = m.offset + ncodeunits(m.match)
      to = findnext('<', html, from)
      title = SubString(html, from, to === nothing ? lastindex(html) : prevind(html, to))
    elseif tag == "link" && isempty(icon)
      rel = split(lowercase(get(a, "rel", "")))
      ("icon" in rel || "apple-touch-icon" in rel) && (icon = get(a, "href", ""))
    elseif tag == "base" && haskey(a, "href")
      # The page says where its own addresses start from
      (from = absolute(a["href"], String(url))) == "" || (base = from)
    end
  end
  pick(wanted...) = (k = findfirst(k -> haskey(said, k), wanted); k === nothing ? "" : said[wanted[k]])
  icon = absolute(entities(icon), base)
  Card(String(url),
       title=tidy(something(nonempty(pick("og:title", "twitter:title")), title), 200),
       description=tidy(pick("og:description", "twitter:description", "description")),
       image=absolute(entities(pick("og:image", "og:image:url", "og:image:secure_url", "twitter:image", "twitter:image:src")), base),
       site=tidy(pick("og:site_name"), 80),
       icon=isempty(icon) ? origin(url) * "/favicon.ico" : icon)
end

nonempty(s) = isempty(s) ? nothing : s

# How the files that are surely no web page start: PNG, JPEG, GIF, TIFF, ICO, PDF and RIFF, which is WebP and WAV
const NOT_PAGES = (b"\x89PNG", b"\xff\xd8\xff", b"GIF8", b"II*\0", b"MM\0*", b"\0\0\x01\0", b"%PDF", b"RIFF")

"""
True when `bytes`, the start of what's at a web address, are a web page. A
page has one of the tags that only a page has, like <html> or <title>, near
its top. An SVG picture can have a <title> too, so it's a page only when such
a tag comes before any <svg>.
"""
ispage(bytes::AbstractVector{UInt8}) = begin
  any(s -> length(bytes) >= length(s) && view(bytes, 1:length(s)) == s, NOT_PAGES) && return false
  top = String([b < 0x80 ? b : UInt8('?') for b in view(bytes, 1:min(length(bytes), 65536))])
  tag = findfirst(r"<(?:!doctype\s+html|html|head|body|meta|title)\b"i, top)
  svg = findfirst(r"<svg\b"i, top)
  tag !== nothing && (svg === nothing || first(svg) > first(tag))
end

"""
The card of the page at `url`, read from the bytes of the page. Bytes that
aren't a page give a card that says so. A page whose bytes can't be read as
text gives a card with only the address.
"""
card(bytes::Vector{UInt8}, url::AbstractString) = begin
  ispage(bytes) || return Card(url, page=false)
  html = text(bytes)
  html === nothing ? Card(url) : card(html, url)
end

"The line under a card's words: the name of the site, when the page gives one, and the name of the computer that it's on"
source(c::Card) = begin
  name = site_name(c.url)
  isempty(c.site) || lowercase(c.site) == name ? name : c.site * " · " * name
end

"""
The words at the top of a card: the page's title. While Ladder has no title,
they're `words`, the words that the line of the document has for the card,
or the address when the line has none.
"""
heading(c::Card, words::AbstractString="") = !isempty(c.title) ? c.title : !isempty(words) ? String(words) : c.url

"The words under a card's title: the page's description, or its address when that isn't the title"
blurb(c::Card, words::AbstractString="") = !isempty(c.description) ? c.description : heading(c, words) == c.url ? "" : c.url

# --- the card in a page of HTML -----------------------------------------------------------

escape(s::AbstractString) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")

"The card as HTML: a link in a box, with the title, the description, the name of the site and the picture. `words` are the line's words for the card."
markup(c::Card, words::AbstractString="") =
  "<a class=\"card\" href=\"" * escape(c.url) * "\"><span class=\"card-words\"><strong>" * escape(heading(c, words)) * "</strong>" *
  (isempty(blurb(c, words)) ? "" : "<span class=\"card-description\">" * escape(blurb(c, words)) * "</span>") *
  "<span class=\"card-site\">" * escape(source(c)) * "</span></span>" *
  (isempty(c.image) ? "" : "<img class=\"card-picture\" src=\"" * escape(c.image) * "\" alt=\"\">") * "</a>"

"The rules of a page of HTML that give a card its look"
const STYLE = """
a.card { display: flex; gap: 1em; margin: 1em 0; padding: 0.8em 1em; border: 1px solid #d8d0bd; border-radius: 8px; color: inherit; text-decoration: none; font: 0.9em/1.4 -apple-system, system-ui, sans-serif; }
.card-words { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 0.25em; overflow-wrap: anywhere; }
.card-description { color: #6b6259; font-size: 0.9em; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.card-site { color: #9a917f; font-size: 0.82em; margin-top: auto; }
.card-picture { width: 9em; height: 6em; object-fit: cover; border-radius: 6px; flex: none; }
"""

# --- what a card keeps on the Mac ---------------------------------------------------------
#
# The folder has one small file of text for each page: a line for each thing
# that the page said. It has a file for each picture and each icon too. The
# name of a file is made from its web address.

"The name of the file that keeps what's at the web address `url`"
name(url::AbstractString) = string(hash(String(url)), base=16)

const FIELDS = (:title, :description, :image, :site, :icon)

"The lines of the file that keeps a card. One for an address that isn't a page says so."
written(c::Card) = String[(string(f, ": ", getfield(c, f)) for f in FIELDS if !isempty(getfield(c, f)))..., (c.page ? () : ("page: no",))...]

"The card of the page at `url`, from the lines of the file that keeps it"
card(lines::AbstractVector{<:AbstractString}, url::AbstractString) = begin
  said = Dict{Symbol,String}()
  for line in lines
    m = match(r"^(\w+): (.*)$", line)
    m === nothing || (said[Symbol(m[1])] = String(m[2]))
  end
  Card(String(url), (get(said, f, "") for f in FIELDS)..., get(said, :page, "") != "no")
end

# --- getting a page from the web ----------------------------------------------------------

const PAGE_BYTES = 200_000        # how much of a page is read: its <head> is at its start
const PICTURE_BYTES = 8_000_000   # a picture that's bigger than this isn't kept
const SECONDS = 20                # how long a page or a picture can take to come
const RETRY = 300.0               # seconds after a page couldn't be had before Ladder asks for it again
const SOON = 10.0                 # and after the first time, because a site that's busy says no for a moment

"""
Start to get what's at the web address `url` into `file`, and no more than its
first `most` bytes. It gives a function that's true once that has ended.
`curl` does it, in a process of its own. It follows the page to where it has
moved, gives up after `SECONDS`, and writes nothing when the site says no.
"""
curl(url, file, most) = begin
  job = Webfetch.start(url, file; redirs=5, seconds=SECONDS, most)
  () -> process_exited(job)
end

"What gets a page or a picture from the web. A test puts its own function here, so that it uses no network."
const getter = Ref{Function}(curl)

# What's known of each file that keeps something from the web: the function that says if it has come yet, when
# it couldn't be had and how many times that has happened, or true once the file is there
const jobs = Dict{String,Any}()
const tries = Dict{String,Int}()

"Note that `file` couldn't be had just now"
failed!(file) = (tries[file] = get(tries, file, 0) + 1; jobs[file] = time(); :failed)

"How many seconds Ladder waits before it asks again for a file that couldn't be had"
patience(file) = get(tries, file, 1) <= 1 ? SOON : RETRY

"""
Get what's at the web address `url` into `file`, unless it's there or on its
way. It's `:there` once the file is whole, and `:coming` while it's on its
way. The first time it can't be had, it's still `:coming`, and Ladder asks
again `SOON` seconds later. After that it's `:failed`, and Ladder asks again
each `RETRY` seconds. It never waits.
Without `ask` it starts nothing, and a file that isn't there or on its way
counts as one that couldn't be had.
"""
fetch!(url::AbstractString, file::AbstractString, most::Int, ask::Bool=true) = try
  state = get(jobs, file, nothing)
  state === true && return :there
  # A file that an earlier run of the app got is still there
  state === nothing && isfile(file) && filesize(file) > 0 && return (jobs[file] = true; :there)
  part = file * ".part"
  if state isa Function
    state() || return :coming
    isfile(part) && filesize(part) > 0 && return (mv(part, file, force=true); jobs[file] = true; :there)
    rm(part, force=true)
    failed!(file)
    state = jobs[file]
  end
  state isa Float64 && time() - state < patience(file) && return ask && patience(file) == SOON ? :coming : :failed
  ask || return :failed
  mkpath(dirname(file))
  jobs[file] = getter[](String(url), part, most)
  :coming
catch
  failed!(file)
end

# The cards that this run of the app has read, by the folder that keeps them and the address of the page
const cards = Dict{Tuple{String,String},Card}()

keep!(dir, c::Card) = cards[(String(dir), c.url)] = c

"""
The card of the page at the address `url`, and true while Ladder is still
getting the page. `dir` is the folder that keeps the cards. Until the page has
come, and when it can't be had, the card has only the address. Without `ask`,
Ladder asks the web for nothing, and the card is what the folder keeps. It
never waits and never throws.
"""
lookup!(url::AbstractString, dir::AbstractString; ask::Bool=true) = begin
  known = get(cards, (dir, url), nothing)
  known === nothing || return (known, false)
  try
    record = joinpath(dir, name(url) * ".card")
    isfile(record) && return (keep!(dir, card(readlines(record), url)), false)
    page = joinpath(dir, name(url) * ".html")
    state = fetch!(url, page, PAGE_BYTES, ask)
    state == :there || return (Card(url), state == :coming)
    made = try card(read(page), url) catch; Card(url) end
    write(record, join(written(made), "\n"))
    # Only what the card shows is kept. The page itself goes.
    rm(page, force=true)
    delete!(jobs, page)
    (keep!(dir, made), false)
  catch
    (Card(url), false)
  end
end

"""
The file in the folder `dir` that keeps the picture at the web address `url`,
and true while Ladder is still getting it. The file is nothing until the
picture has come, and when it can't be had. Without `ask`, Ladder asks the
web for nothing.
"""
picture!(url::AbstractString, dir::AbstractString; ask::Bool=true) = begin
  isempty(url) && return (nothing, false)
  file = joinpath(dir, name(url))
  state = fetch!(url, file, PICTURE_BYTES, ask)
  (state == :there ? file : nothing, state == :coming)
end
