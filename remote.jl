# Gets a page of Markdown from a web server, for a window to show. See "a page
# from a web server" in main.jl.
#
#     c = ask("https://example.com/notes.md")   # start to get it: nothing here waits
#     a = landed(c)                              # nothing while it's on its way, then an Answer
#     a.status                                   # what the server said, like 200 or 404, or 0 when it said nothing
#     ismarkdown(a)                              # true when the server sent a page of Markdown
#     ishtml(a)                                  # true when it sent a page of HTML
#     lines(a)                                   # the lines of that page
#     problem(a)                                 # why there's no page to show, in words, or "" when there is one
#
# Ladder tells the server that it wants Markdown, with the header `Accept:
# text/markdown`. A server that keeps each page as both Markdown and HTML sends
# the Markdown to Ladder, and the HTML to a browser, from the same address.
#
# A server says what it sent with `Content-Type`. `text/markdown` is Markdown.
# Many servers send a file whose name ends in `.md` as plain text, or don't say
# what it is. That's Markdown too. Anything else isn't, so `ismarkdown` is
# false for a page of HTML. A server that has no Markdown for an address
# sends its HTML, which `ishtml` says: `text/html`, or a page that the server
# doesn't name whose name ends in `.html` or whose text starts as HTML's does.
#
# `curl` gets the page, in a process of its own. It follows the page to where
# it has moved: `a.address` is where it ended up, which the links and the
# pictures of the page are from. Nothing is sent that says who you are: no
# cookie and no password.
#
#     typed("example.com/notes.md")              # "https://example.com/notes.md": what typed words mean, or nothing
#     against("https://example.com/a/b.md", "../c.md#top")   # "https://example.com/c.md#top"
#     label("https://example.com/a/b.md")        # "example.com/a/b.md", for the top bar

@use "./web/files" => Webfiles
@use "./web/url" resolve

"What Ladder says it wants from a server: Markdown first, then plain text, then anything"
const ACCEPT = "text/markdown, text/x-markdown;q=0.9, text/plain;q=0.8, text/html;q=0.7, */*;q=0.5"
const SECONDS = 30               # how long a page can take to come
const BIGGEST = 16 * 1024 * 1024 # bytes: a page bigger than this isn't got

"The kinds of file that are Markdown, as a server names them"
const MARKDOWN_TYPES = ("text/markdown", "text/x-markdown")
"The kinds that a server gives a file when it doesn't know what the file is. The end of the file's name says then."
const VAGUE_TYPES = ("", "text/plain", "application/octet-stream", "binary/octet-stream")
"How the name of a file of Markdown ends"
const MARKDOWN_ENDS = (".md", ".markdown", ".mdown", ".mkd")
"The kinds of file that are a page of HTML, as a server names them"
const HTML_TYPES = ("text/html", "application/xhtml+xml")
"How the name of a page of HTML ends"
const HTML_ENDS = (".html", ".htm", ".xhtml")

"True when `text` is an address on the web: it starts with http:// or https://"
isaddress(text::AbstractString) = occursin(r"^https?://[^/\s]"i, text)

"The address without what follows a #, which names a place in the page and isn't sent to the server"
bare(address::AbstractString) = String(first(split(strip(address), '#', limit=2)))

"What follows the # of the address: the name of a heading of the page, or \"\""
place(address::AbstractString) = (parts = split(strip(address), '#', limit=2); length(parts) == 2 ? unescaped(parts[2]) : "")

"`text` with each %20 and the like as the character that it stands for"
unescaped(text::AbstractString) = begin
  from = codeunits(String(text))
  bytes = UInt8[]
  i = 1
  while i <= length(from)
    n = from[i] == UInt8('%') && i + 2 <= length(from) ? tryparse(UInt8, String(from[i+1:i+2]), base=16) : nothing
    n === nothing ? (push!(bytes, from[i]); i += 1) : (push!(bytes, n); i += 3)
  end
  out = String(bytes)
  isvalid(out) ? out : String(text)
end

"The path of the address: what follows the name of its computer, without what follows a ? or a #"
path(address::AbstractString) = (m = match(r"^https?://[^/?#]*([^?#]*)"i, address); m === nothing ? "" : String(m[1]))

"True when the name of the file at `address` ends as a file of Markdown's does"
named_markdown(address::AbstractString) = lowercase(splitext(path(address))[2]) in MARKDOWN_ENDS

"""
The address that `text` means when someone types it, or nothing when it isn't
an address. An address can start with https:// or http://. Without that, it
needs the name of a computer and a /, like `example.com/notes.md`, so that
the name of a file, like `notes.md`, isn't one. A computer that's this Mac,
like `localhost:8000/`, is asked with http. What follows the computer's name
can have spaces, as in `example.com/my notes.md`.
"""
typed(text::AbstractString) = begin
  t = String(strip(text))
  isempty(t) && return nothing
  if !occursin(r"^https?://"i, t)
    occursin(r"^(localhost|\[::1\]|[\w-]+(\.[\w-]+)+)(:\d+)?/"i, t) || return nothing
    t = (occursin(r"^(localhost|127\.|\[::1\])"i, t) ? "http://" : "https://") * t
  end
  # The name of the computer has no space in it. A space in what follows is written %20, as a browser writes it.
  occursin(r"^https?://[^/?#\s]+([/?#]|$)"i, t) || return nothing
  t = replace(t, r"\s" => "%20")
  # The first page of a site is at /
  occursin(r"^https?://[^/?#]+$"i, t) ? t * "/" : t
end

"""
The whole address that the link `link` means in the page at `page`: `../c.md`
is from the page's folder, and `/c.md` from the top of its site. A link that
has its own start, like `mailto:` or `https:`, is itself. A space in the link
is written %20, as a browser writes it.
"""
against(page::AbstractString, link::AbstractString) = replace(resolve(bare(page), String(strip(link))), ' ' => "%20")

"What the top bar calls the page at `address`: the address without its https:// and without what follows a ? or a #"
label(address::AbstractString) = begin
  m = match(r"^https?://([^/?#]*)([^?#]*)"i, address)
  m === nothing && return String(address)
  String(m[1]) * (m[2] == "/" ? "" : unescaped(m[2]))
end

"The name of the computer that `address` is on, like example.com"
host(address::AbstractString) = (m = match(r"^https?://([^/?#]*)"i, address); m === nothing ? String(address) : String(m[1]))

"""
The name and the address of each step on the way to the page at `address`,
as the path in the top bar shows them: the name of the computer, each folder
of the address, and the page. A folder's address ends in /. The page's step
has `address` itself.

    trail("https://example.com/a/my%20b.md")   # [("example.com", "https://example.com/"), ("a", "https://example.com/a/"), ("my b.md", "https://example.com/a/my%20b.md")]
    trail("https://example.com/a/")            # [("example.com", "https://example.com/"), ("a", "https://example.com/a/")]
"""
trail(address::AbstractString) = begin
  m = match(r"^(https?://[^/?#]*)([^?#]*)"i, address)
  m === nothing && return [(String(address), String(address))]
  at = String(m[1])
  out = [(host(address), at * "/")]
  for name in filter(!isempty, split(m[2], '/'))
    at *= "/" * name
    push!(out, (unescaped(name), at * "/"))
  end
  out[end] = (out[end][1], String(address))
  out
end

"""
The folders that the page at `address` is in, from the top of its site down,
each as its address with a / at its end. A folder's own page is in the folder.

    folders("https://example.com/a/b/c.md")   # ["https://example.com/", "https://example.com/a/", "https://example.com/a/b/"]
    folders("https://example.com/a/")         # ["https://example.com/", "https://example.com/a/"]
"""
folders(address::AbstractString) = begin
  m = match(r"^(https?://[^/?#]*)([^?#]*)"i, bare(address))
  m === nothing && return String[]
  parts = split(String(m[2]), '/')   # "/a/b/c.md" is "", "a", "b" and "c.md"
  out = [String(m[1]) * "/"]
  for name in parts[2:end-1]
    isempty(name) && break   # a path like /a//b names no folder
    push!(out, out[end] * name * "/")
  end
  out
end

"""
Start to get what's at the web address `address` into `file`. `about` is a
file for three lines: the address that it ended up at, the kind of file that
the server says it is, and the number that the server answered with, like 200.
It gives a function that's true once that has ended. A server's page that
says what went wrong, like one for 404, is got too: the number says so.
"""
curl(address, file, about) = begin
  ask = `curl --silent --location --max-redirs 8 --proto =http,https --proto-redir =http,https --compressed
              --connect-timeout 10 --max-time $SECONDS --max-filesize $BIGGEST --user-agent $(Webfiles.AGENT)
              --header $("Accept: " * ACCEPT) --output $file --write-out "%{url_effective}\n%{content_type}\n%{http_code}\n" -- $address`
  job = run(pipeline(ask, stdout=about, stderr=devnull), wait=false)
  () -> process_exited(job)
end

"A page that's on its way from a server"
mutable struct Coming
  address::String        # as it was asked for, without what follows a #
  done::Any              # true once `curl` has ended, or nothing when it couldn't start
  file::String           # where the page is while it comes
  answer::Any            # the Answer, once it's here
end

"What a server sent for an address"
struct Answer
  asked::String          # the address that was asked for
  address::String        # the address that it ended up at
  type::String           # the kind of file that the server says it is, in lower case, without what follows a ;
  charset::String        # the characters that the server says it's written in, in lower case, or ""
  status::Int            # the number that the server answered with, or 0 when it didn't answer
  bytes::Vector{UInt8}
end

"""
Start to get the page at `address`. `getter` is what gets it: `curl`, or a
function of a test's that takes the same three things.
"""
ask(address::AbstractString; getter=curl) = begin
  address = bare(address)
  file = joinpath(mktempdir(), "page")
  done = try getter(address, file, file * ".about") catch; nothing end
  Coming(address, done, file, nothing)
end

"What came for `c`, or nothing while it's on its way. A page that couldn't be had is an Answer with the status 0."
landed(c::Coming) = begin
  c.answer === nothing || return c.answer
  c.done === nothing || (try c.done() catch; true end) || return nothing
  said = isfile(c.file * ".about") ? readlines(c.file * ".about") : String[]
  ended = length(said) >= 1 && isaddress(strip(said[1])) ? bare(said[1]) : c.address
  kind = length(said) >= 2 ? lowercase(strip(said[2])) : ""
  m = match(r"charset\s*=\s*\"?([\w-]+)", kind)
  status = length(said) >= 3 ? something(tryparse(Int, strip(said[3])), 0) : 0
  bytes = try isfile(c.file) ? read(c.file) : UInt8[] catch; UInt8[] end
  rm(dirname(c.file), force=true, recursive=true)
  c.answer = Answer(c.address, ended, String(strip(first(split(kind, ';')))), m === nothing ? "" : String(m[1]), status, bytes)
end

"True when the server answered with a page, and not with why it has none"
ok(a::Answer) = 200 <= a.status < 300

"True when what the server sent is a page of Markdown: the server says so, or it doesn't say and the file's name ends as Markdown's does"
ismarkdown(a::Answer) = ok(a) && ismarkdown(a.type, a.address)
ismarkdown(type::AbstractString, address::AbstractString) =
  type in MARKDOWN_TYPES || (type in VAGUE_TYPES && named_markdown(address))

"""
True when what the server sent is a page of HTML: the server says so, or it
doesn't say and the file's name ends as HTML's does, or its text starts as
HTML's does. A page that says why the server has nothing at the address
counts too.
"""
ishtml(a::Answer) = a.type in HTML_TYPES || a.type in VAGUE_TYPES &&
  (lowercase(splitext(path(a.address))[2]) in HTML_ENDS || occursin(r"^\s*<(!doctype\s+html|html)\b"i, ascii_start(a.bytes)))

"The first bytes of `bytes` as text, with a space for each byte that isn't a character of ASCII, so that part of a character can't stop a search"
ascii_start(bytes) = String(map(c -> c < 0x80 ? c : UInt8(' '), bytes[1:min(end, 512)]))

"The lines of the page that the server sent"
lines(a::Answer) = begin
  text = Webfiles.text(a.bytes, a.charset)
  text = replace(lstrip(text, '﻿'), "\r\n" => "\n", '\r' => '\n')
  String.(split(text, '\n'))
end

"Why there's no page to show for `a`, in words, or \"\" when the server sent one"
problem(a::Answer) = begin
  name = host(a.asked)
  a.status == 0 && return "$name didn't answer."
  a.status in (404, 410) && return "$name has no page at that address."
  a.status in (401, 403) && return "$name doesn't let Ladder read that page."
  ok(a) ? "" : "$name answered with the error $(a.status)."
end

# --- a copy on the Mac --------------------------------------------------------------------
#
# A page that Ladder shows can be saved on the Mac with the pages and files
# that it links to: see "a copy of a page from a web server" in main.jl. They
# go in one folder, at the places that they have on the site, so a page's
# links to them name the same places:
#
#     copy_path("https://example.com/a/b.html", page=true)   # "a/b.md": a page of Markdown is a .md file
#     copy_path("https://example.com/a/", page=true)         # "a/index.md": the page of a folder
#     copy_path("https://example.com/i/air%20cost.png")      # "i/air cost.png"
#     inside("https://example.com/a/c.md", "https://example.com/a/b.md")   # true: c.md is in b.md's folder

"The start of `address`: how it's asked for and the computer that it's on, like https://example.com, in lower case"
site(address::AbstractString) = (m = match(r"^(https?://[^/?#]*)"i, address); m === nothing ? "" : lowercase(m[1]))

"The folder of the path `p`, with the / at its end: /a/ of /a/b.md"
folder(p::AbstractString) = p[1:something(findlast('/', p), 0)]

"True when `address` is on the site of `page`, in the folder of `page` there or in a folder in that"
inside(address::AbstractString, page::AbstractString) = begin
  a, p = path(address), path(page)
  site(address) == site(page) && startswith(isempty(a) ? "/" : a, folder(isempty(p) ? "/" : p))
end

"How the name of a page of the copy can end. Any other page of Markdown, like plans.html, ends in .md there."
const KEPT_ENDS = (".md", ".markdown")

"""
Where the copy of what's at `address` goes, from the folder of the site's
copy, or nothing when no file of the copy can be it. A `page` of Markdown
ends in .md, or keeps .markdown: the page of an address that ends in / is
index.md in that folder. Any other file keeps its name, and one at an
address that ends in / is called index. No part of the path can start with
a dot, so a copy has no hidden file, like the `.ladder` page of a folder,
which runs its code.
"""
copy_path(address::AbstractString; page=false) = begin
  p = path(address)
  isempty(p) && (p = "/")
  names = unescaped.(split(p, '/')[2:end])
  any(n -> startswith(n, '.') || occursin('/', n) || occursin('\0', n), names) && return nothing
  any(isempty, names[1:end-1]) && return nothing   # a path like /a//b names no folder
  name = names[end]
  name = isempty(name) ? (page ? "index.md" : "index") :
         page && !(lowercase(splitext(name)[2]) in KEPT_ENDS) ? splitext(name)[1] * ".md" : name
  ncodeunits(name) > 250 && return nothing   # longer than a file's name can be
  join([names[1:end-1]; name], '/')
end
