# The document: the lines of an open file, its carets and selections, what each
# line is, and the edits to it, with undo and redo. A Buffer knows nothing of
# the window.
#
#     b = load("/Users/sam/notes.md")
#     edit!(b, (1, 0), (1, 0), "# Notes\n")
#     undo!(b)

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" version
@use "./markdown" Kind Line classify front_matter
@use "./highlight" left_open
@use "./sheet" parts
@use "./spreadsheet" moved
@use "./merge" changes combine follow
@use "./eml" => Eml
@use "./remote" => Remote
@use "./folder_page" MARKDOWN ZIPS
@use "./look" exports...
@use "./flow" exports...
@use "./schedule" => Schedules
@use "./filter" => Filters
@use "./timelog" => Timelogs
@use "./chart" => Charts
@use "./save" => Saves

export look, table_text, in_browser, web_address, copied_from, julia_own, is_reply, web_site, site_runs,
       inspread, insheet, shared_lang, shown_only!, sandbox_only!, Pos, Buffer, readonly, protected, isremote,
       foreign, sandboxed, runs_sums, page_site, caretless, follows_links, stamp, load, text, load_email,
       READ, refresh!, file_lang, kinds, Opens, OPENS, leaves_open, string_opens, same_chars, string_open,
       dirty, name, selecting, selection, head, rest, excerpt, others, keep_others!, clash, snapshot,
       restore!, edit!, replace_text!, undo!, redo!, writes, save!, crlf, ismarkdown, CODE_FILES, iscode,
       MOST_TEXT, MOST_PAGE, reading, HEX, HEX_BYTES, HEX_CHARS, BITS, BITS_ROW, BITS_CHARS, same_text,
       unchanged, line_end, FOLDER_PAGE, page_key, unescaped, bytes_page, STEP, FILE_VIEWS, JULIA, LIVE,
       TEXT_READ, text_file, SCHEDULE, FILTER, CODE_RUNS, LOAD, FOLDER_PAGES, TIMELOG, HTMLS, TERM_CARETS,
       TERM_PASTS, VIEW_BLOCK, PAGE_MODULES, table_reads, CHART, SAVE, RUN_WAIT, LAST_RUN, fetches,
       MATTER_TITLES, MATTER_CARDS, PAGE_MEDIA

# A kind of page or of file decides these, so this file only names them. The
# file that knows the kind gives each its methods.

"The buffer that shows the file at `path`, which isn't Markdown, as its kind of file shows it"
function look end

"True when `b` shows the table or the text of a CSV file that its page changes"
function table_text end

"True when the file at `path` is a page of the browser folder"
function in_browser end

"The address on the web of the page at `path`"
function web_address end

"The address of the page on the web that the file at `path` is a copy of, or \"\" when it's no copy"
function copied_from end

"True when the file at `path` is in a folder of Julia's own code, which Ladder never changes"
function julia_own end

"True when `path` is the path of a page that holds what an agent said in a session"
function is_reply end

"The site of `address`, like https://example.com"
function web_site end

"True when you trust `site`, so the code of its pages runs with no sandbox. False or nothing when you don't."
function site_runs end

"True when line `i` of `b` is a row of a spreadsheet"
function inspread end

"True when line `i` of `b` is a row of a sheet"
function insheet end

"The language that code in `lang` shares its names with"
function shared_lang end

"Mark the lines `ks` of blocks that show only as what they make"
function shown_only! end

"Make each code block of the lines `ks`, on a page of a site that you don't trust, one that only shows its code, unless the sandbox can run it"
function sandbox_only! end

# --- the document ----------------------------------------------------------------

const Pos = Tuple{Int,Int}   # a line, from 1, and a column, from 0

"An open file"
Base.@kwdef mutable struct Buffer
  path::String = ""
  lines::Vector{String} = [""]
  caret::Pos = (1, 0)
  anchor::Pos = (1, 0)                  # where the selection starts. The caret is its other end.
  # The other selections, when there are several at once: where each starts, and its caret. See `others`.
  others::Vector{Tuple{Pos,Pos}} = Tuple{Pos,Pos}[]
  others_for::Tuple{Pos,Pos,Int} = ((1, 0), (1, 0), -1)   # the anchor, the caret and the version that `others` goes with
  many::Bool = false                    # true while something is done at each selection in turn
  undo::Vector{Any} = Any[]
  redo::Vector{Any} = Any[]
  version::Int = 0                      # changes with every edit
  saved::Int = 0                        # the version that's in the file
  typed::Float64 = 0.0                  # when a character was last typed, to undo words not letters
  offset::px = 0px                      # how far it's scrolled
  across::px = 0px                      # how far it's scrolled to the right, in a file of code whose long lines don't wrap
  kinds::Vector{Line} = Line[]
  kinds_at::Int = -1
  # After Escape the caret is hidden, until a click puts the caret back
  reading::Bool = false
  # True while the page is written as plain text: the part with the caret shows its markup. The window sets it from its setting.
  plain::Bool = false
  # The part of the page that the caret is on as a whole, and the text, caret and so on that it was worked out for. See `picked`.
  picked::Union{Nothing,Tuple{Int,Int}} = nothing
  picked_for::Tuple{Int,Pos,Pos,Bool,Bool} = (-1, (0, 0), (0, 0), false, false)
  # Where the caret was when the page last looked at where it is, or nothing before the first look. See `stand!`.
  stood::Union{Nothing,Pos} = nothing
  # How the file shows. A Markdown file is a document that you change, and :code is a file of
  # code that you change, which is one block of code. Any other file is only shown: :text shows
  # its text, :hex shows its bytes in hexadecimal, :bits shows them as bits, and :file shows a viewer of its kind.
  view::Symbol = :markdown
  # The language of a file of code that has no file, like Julia for a field of code. "" takes it from the file's name.
  lang::String = ""
  # True for a page that's read, and never changed or written: an email, or a file that the Mac marks as
  # read-only. The lines of an email are the email as a page, which mail.jl makes from the file: the file
  # holds the email as the server sent it.
  fixed::Bool = false
  about::String = ""                    # what the top bar says of a file that's only shown, like how much of it shows
  disk::Vector{String} = [""]           # the file's text as it was last read or written
  # The text as an agent last knew it: what you last sent it, with every change that was made to the file from outside since
  told::Vector{String} = [""]
  sent::Vector{String} = [""]           # the text as it was when you last sent it to an agent, or when the file was opened
end

"True when the file is only shown. Ladder changes Markdown files, the files of code in `CODE_FILES` and CSV files, and no others."
readonly(b::Buffer) = !(b.view in (:markdown, :code) || table_text(b))

"""
True when Ladder shows the file at `path` as a page and never changes it: the
file is an email, a file of Julia's own code, or the Mac marks it as
read-only. Ladder marks each email that it keeps, and a mark that you put on a
page of your own counts the same.
"""
protected(path) = Eml.isemail(path) || julia_own(path) || (isfile(path) && !iswritable(path))

"True when `path` is the address of a page on a web server, like https://example.com/notes.md, and not a file on the Mac. See \"a page from a web server\"."
isremote(path::AbstractString) = Remote.isaddress(path)

"""
True when somebody else wrote the page at `path` and Ladder runs none of its
code: an email. A block that would run code, like a `ui` block or a sum in a
line of text, shows as its code. A page from a web server runs its code in
the sandbox instead: see `sandboxed`.
"""
foreign(path::AbstractString) = Eml.isemail(path)

"""
True when the page at `path` is from a web server, or a copy of one, and you
don't trust its site: its code runs in the sandbox, and a block that would
read the Mac's files or ask a server shows as its code. See "the sandbox".
"""
sandboxed(path::AbstractString) =
  (isremote(path) || in_browser(path) || !isempty(copied_from(path))) && site_runs(page_site(path)) !== true

"True when the sums in the lines of the page of `e` run: on any page but an email. A page from the web runs them in the sandbox."
runs_sums(e) = !foreign(e.buf.path)

"The site that the page at `path` is from, like https://example.com: the site of a page from a web server or of a copy of one, or \"\""
page_site(path::AbstractString) = (at = web_address(path); isempty(at) && (at = copied_from(path)); isempty(at) ? "" : web_site(at))

"True when the page shows no caret and no key changes it: after Escape, and all the time in a page that's never changed"
caretless(b::Buffer) = b.reading || b.fixed

"True when a click with no key held on a link of the page `b` opens the link: in a page that's never changed, in a page from a web server, and in what an agent said"
follows_links(b::Buffer) = b.fixed || in_browser(b.path) || is_reply(b.path)

const stamp = Ref(0)

load(path) = begin
  READ[path] = mtime(path)
  Eml.isemail(path) && return load_email(path)
  code = !ismarkdown(path) && iscode(path)
  ismarkdown(path) || code || return look(path)
  lines = text(path)
  b = Buffer(path=path, lines=lines, disk=copy(lines), told=copy(lines), view=code ? :code : :markdown, fixed=protected(path))
  b.sent = b.told   # nothing has changed from outside yet
  code && return b
  # The caret starts at the text, after any front matter, so the front matter shows as a card
  t = front_matter(b.lines)
  if t > 0
    i = something(findnext(l -> !isempty(strip(l)), b.lines, t + 1), min(t + 1, length(b.lines)))
    b.caret = b.anchor = (i, 0)
  end
  b
end
text(path) = String.(split(replace(read(path, String), "\r\n" => "\n"), '\n'))

"""
The email file at `path`, as a page that's read and not changed: who it's from
and its subject at the top, then its text. A file that isn't an email after
all shows as any other file does.
"""
load_email(path) = begin
  lines = try Eml.render(path) catch; return look(path) end
  b = Buffer(path=path, lines=lines, disk=copy(lines), told=copy(lines), fixed=true)
  b.sent = b.told
  t = front_matter(b.lines)
  i = something(findnext(l -> !isempty(strip(l)), b.lines, t + 1), min(t + 1, length(b.lines)))
  b.caret = b.anchor = (i, 0)
  b
end

const READ = Dict{String,Float64}()   # when each open file was last read or written, as the disk tells it

"""
Read the file again if something else changed it on the disk, like an agent
that's working on the page with you. A document with changes that aren't saved
keeps them, and gets the file's changes too. Where both changed the same lines,
the document keeps its own. Returns the lines of the document that changed, as
`changes` gives them, or nothing.
"""
refresh!(b::Buffer) = begin
  (isempty(b.path) || !isfile(b.path)) && return
  # The Mac's mark can go on a file, or come off it, while the file is open
  if b.fixed != protected(b.path)
    b.fixed = !b.fixed
    b.picked_for = (-1, (0, 0), (0, 0), false, false)
  end
  at = mtime(b.path)
  at == get(READ, b.path, 0.0) && return
  READ[b.path] = at
  unsaved = false
  if readonly(b)
    # A file that's only shown is read again as it was shown: as bytes, or as its kind of file. A JSON file that
    # shows its text goes on showing its text.
    new = look(b.path, b.view)
    b.view, b.about = new.view, new.about
    lines = new.lines
  else
    theirs = Eml.isemail(b.path) ? (try Eml.render(b.path) catch; b.disk end) : text(b.path)
    theirs == b.disk && return
    # An agent knows the changes it made to the file, and none of yours until you send them
    b.told = combine(b.disk, b.told, theirs, keep=:theirs)
    lines = dirty(b) ? combine(b.disk, b.lines, theirs) : theirs
    b.disk = theirs
    unsaved = lines != theirs
  end
  moved = changes(b.lines, lines)
  if !isempty(moved)
    b.lines = lines
    empty!(b.undo); empty!(b.redo)
    b.version = (stamp[] += 1)
    # The caret stays on its line, wherever that line is now
    place(p) = (i = clamp(follow(moved, p[1]), 1, length(lines)); (i, clamp(p[2], 0, length(lines[i]))))
    b.caret, b.anchor = place(b.caret), place(b.anchor)
  end
  unsaved || (b.saved = b.version)
  isempty(moved) ? nothing : moved
end

"The language of the file at `path`: the end of its name, like jl, or its whole name when it has no end, like makefile"
file_lang(path) = (ext = lowercase(splitext(path)[2]); isempty(ext) ? lowercase(basename(path)) : String(lstrip(ext, '.')))

kinds(b::Buffer) = begin
  if b.kinds_at != b.version && b.view != :markdown
    # Each line of a file that isn't Markdown is a line of code, in the language that the file's name gives
    lang = b.view == :hex ? HEX : b.view == :bits ? BITS : isempty(b.lang) ? file_lang(b.path) : b.lang
    b.kinds = fill(Line(Kind.code, 0, 0, lang), length(b.lines))
    b.kinds_at = b.version
  elseif b.kinds_at != b.version
    b.kinds = classify(b.lines)
    # A page that somebody else wrote, like an email, shows the code of a block that would run code or read the Mac's files
    # A page of a site that you don't trust runs only the code that the sandbox can check
    foreign(b.path) ? shown_only!(b.kinds) : sandboxed(b.path) && sandbox_only!(b.kinds)
    b.kinds_at = b.version
  end
  b.kinds
end

# --- strings in three quotes ---------------------------------------------------------------
#
# A string in three quotes, like a docstring, can run over several lines. The
# lines inside it are all the colour of a string, though they have words like
# for and end. Each line is coloured by itself, so the page keeps the quote of
# the string that's open at the start of each line: see `string_opens`.

"For the lines `lines` and their kinds `kinds`, of the version `version` of the file at `path` as `view` shows it: `at[i]` is the quote of a string in three quotes that's open at the start of line i, or '\\0'"
struct Opens
  path::String
  view::Symbol
  version::Int
  lines::Vector{String}
  kinds::Vector{Line}
  at::Vector{Char}
end

const OPENS = WeakKeyDict{Buffer,Opens}()

"What a string in three quotes is at the end of `text`, a line of the kind `line` that starts with `open` open: see `left_open`"
leaves_open(text::String, line::Line, open::Char) = line.kind == Kind.code ? left_open(text, shared_lang(line.lang), open) : '\0'

"""
For each line of `b`, the quote of a string in three quotes that's open at the
start of the line, like the middle of a docstring, or '\\0'. A code block of a
page starts with none open. After a change, it's worked out again from the
first line that changed, until a line after the change starts as it did before.
"""
string_opens(b::Buffer) = begin
  kept = get(OPENS, b, nothing)
  kept !== nothing && kept.version == b.version && kept.path == b.path && kept.view == b.view && return kept.at
  # What was worked out for another file, or for another view of this one, is no help
  kept !== nothing && (kept.path != b.path || kept.view != b.view) && (kept = nothing)
  lines, ks = b.lines, kinds(b)
  n = length(lines)
  at = fill('\0', n)
  was, before, wks = kept === nothing ? (Char[], String[], Line[]) : (kept.at, kept.lines, kept.kinds)
  m = length(before)
  head, tail = unchanged(lines, before)
  # A line can change its kind though its text didn't, as when a ``` above it opens a code block
  if b.view == :markdown
    k = findfirst(k -> ks[k] != wks[k], 1:head)
    k === nothing || (head = k - 1)
    tail = min(tail, something(findfirst(k -> ks[n-k+1] != wks[m-k+1], 1:tail), tail + 1) - 1)
  elseif n > 0 && m > 0 && ks[1] != wks[1]
    head = tail = 0
  end
  copyto!(at, 1, was, 1, head)
  q = head == 0 ? '\0' : leaves_open(lines[head], ks[head], at[head])
  for i in head+1:n
    j = i - n + m
    # The rest of the lines are as they were, and so are the strings in them
    if i > n - tail && q == was[j]
      copyto!(at, i, was, j, n - i + 1)
      break
    end
    at[i] = q
    q = leaves_open(lines[i], ks[i], q)
  end
  OPENS[b] = Opens(b.path, b.view, b.version, copy(lines), ks, at)
  at
end

"True when the `n` characters of `a` from `i` are the ones of `b` from `j`. It compares them as memory, which is quick for the lines of a long file."
same_chars(a::Vector{Char}, i::Int, b::Vector{Char}, j::Int, n::Int) =
  n <= 0 || GC.@preserve a b ccall(:memcmp, Cint, (Ptr{Char}, Ptr{Char}, Csize_t), pointer(a, i), pointer(b, j), n * sizeof(Char)) == 0

"The quote of a string in three quotes that's open at the start of line `i` of the page `b`, when `text` is that line, or '\\0'"
string_open(b::Buffer, i::Int, text::AbstractString) =
  1 <= i <= length(b.lines) && same_text(b.lines[i], String(text)) ? string_opens(b)[i] : '\0'

dirty(b::Buffer) = b.version != b.saved
name(b::Buffer) = isempty(b.path) ? "Untitled" : (at = web_address(b.path); isempty(at) ? basename(b.path) : Remote.label(at))
selecting(b::Buffer) = b.caret != b.anchor
"""
The two ends of the selection, first end first. A selection that covers several
lines takes the whole of each row of a table or a sheet that it touches.
"""
selection(b::Buffer) = begin
  lo, hi = minmax(b.caret, b.anchor)
  (lo[1] == hi[1] || readonly(b)) && return (lo, hi)
  ks = kinds(b)
  (ks[lo[1]].kind == Kind.table || insheet(b, lo[1]) || inspread(b, lo[1])) && (lo = (lo[1], 0))
  (ks[hi[1]].kind == Kind.table || insheet(b, hi[1]) || inspread(b, hi[1])) && (hi = (hi[1], length(b.lines[hi[1]])))
  (lo, hi)
end

head(s, n) = String(first(s, n))
rest(s, n) = String(chop(s, head=n, tail=0))

"The text from `lo` to `hi`"
excerpt(b::Buffer, lo::Pos, hi::Pos) = begin
  lo[1] == hi[1] && return rest(head(b.lines[lo[1]], hi[2]), lo[2])
  join([rest(b.lines[lo[1]], lo[2]); b.lines[lo[1]+1:hi[1]-1]; head(b.lines[hi[1]], hi[2])], "\n")
end

"""
The other selections, when there are several at once. ⌘D on a word that's
selected adds the next place that has the word. What's typed then goes in at
each of them. They last until the caret moves, or the text changes, in a way
that isn't done at each of them: a click, ↑, undo, a change from outside.
"""
others(b::Buffer) = begin
  isempty(b.others) && return b.others
  (b.many || b.others_for == (b.anchor, b.caret, b.version)) || empty!(b.others)
  b.others
end

"Keep the other selections with the caret where it is now"
keep_others!(b::Buffer) = (b.others_for = (b.anchor, b.caret, b.version); b)

"True when two selections share some text, or start at the same place"
clash(s, t) = begin
  (a, b), (c, d) = minmax(s...), minmax(t...)
  a == c || (a < d && c < b)
end

"Where `p` is after the text from `lo` to `hi` was replaced by text that ends at `stop`"
moved(p::Pos, lo::Pos, hi::Pos, stop::Pos) =
  p <= lo ? p : p < hi ? stop : p[1] == hi[1] ? (stop[1], stop[2] + p[2] - hi[2]) : (p[1] + stop[1] - hi[1], p[2])

snapshot(b::Buffer) = (copy(b.lines), b.caret, b.anchor, b.version, copy(others(b)))

restore!(b::Buffer, (lines, caret, anchor, version, rest)) = begin
  b.lines, b.caret, b.anchor, b.version, b.others = lines, caret, anchor, version, copy(rest)
  keep_others!(b)
  b.typed = 0.0
end

"Replace the text from `lo` to `hi` with `new`, and put the caret after it"
edit!(b::Buffer, lo::Pos, hi::Pos, new::AbstractString; typing=false) = begin
  (readonly(b) || b.fixed) && return b   # nothing changes a file that's only shown, an email, or a file that's read-only
  # No key types in the lines of a CSV file while its table shows. The table changes them with `table_edit!`.
  b.view == :file && return b
  replace_text!(b, lo, hi, new; typing)
end

"Replace the text from `lo` to `hi` with `new`, and put the caret after it, so that ⌘Z puts it back. `edit!` says what may be changed."
replace_text!(b::Buffer, lo::Pos, hi::Pos, new::AbstractString; typing=false) = begin
  # Letters typed one after another undo together
  if !(typing && time() - b.typed < 1 && !isempty(b.undo))
    push!(b.undo, snapshot(b))
    # Each step back keeps a list of the file's lines, so a long file keeps fewer steps: 500 for a
    # file of 16,000 lines or less, 228 for one of 35,000 lines, and never less than 20
    while length(b.undo) > clamp(8_000_000 ÷ max(length(b.lines), 1), 20, 500)
      popfirst!(b.undo)
    end
  end
  empty!(b.redo)
  b.typed = typing ? time() : 0.0
  joined = head(b.lines[lo[1]], lo[2]) * new * rest(b.lines[hi[1]], hi[2])
  splice!(b.lines, lo[1]:hi[1], String.(split(joined, '\n')))
  parts = split(new, '\n')
  stop = (lo[1] + length(parts) - 1, length(parts) == 1 ? lo[2] + length(new) : length(last(parts)))
  b.caret = b.anchor = stop
  # Each of the other selections stays with its own text
  isempty(b.others) || map!(((a, c),) -> (moved(a, lo, hi, stop), moved(c, lo, hi, stop)), b.others, b.others)
  b.version = (stamp[] += 1)
  b
end

undo!(b::Buffer) = isempty(b.undo) || (push!(b.redo, snapshot(b)); restore!(b, pop!(b.undo)))
redo!(b::Buffer) = isempty(b.redo) || (push!(b.undo, snapshot(b)); restore!(b, pop!(b.redo)))

"""
True when the lines of `b` are what its file holds, so they can be written to
it. The lines of a file that's only shown can be a part of the file, or its
bytes. The lines of an email are the email as a page, which isn't what its file holds.
A page from a web server is a file of the browser folder: ⌘S writes your changes
there, and never to the server. See "the browser folder". What an agent said
is in no file of its own: a session's file keeps it.
"""
writes(b::Buffer) = !(isempty(b.path) || readonly(b) || b.fixed || Eml.isemail(b.path) || isremote(b.path) || is_reply(b.path))

save!(b::Buffer) = begin
  writes(b) || return
  refresh!(b)   # a change that something else made to the file a moment ago is kept
  # A file whose lines end as Windows ends them keeps them that way, so a change to one line changes no others
  write(b.path, join(b.lines, crlf(b.path) ? "\r\n" : "\n"))
  READ[b.path] = mtime(b.path)
  b.disk = copy(b.lines)
  b.saved = b.version
end

"True when the lines of the file at `path` end with a carriage return and a line feed, as Windows ends them. Its first line says."
crlf(path) = begin
  isfile(path) || return false
  start = open(io -> read(io, 65_536), path)
  i = findfirst(==(0x0a), start)
  i !== nothing && i > 1 && start[i-1] == 0x0d
end

# A folder's own page, `.ladder`, is Markdown too: see "a folder's own page" below
ismarkdown(path) = lowercase(splitext(path)[2]) in MARKDOWN || basename(path) == FOLDER_PAGE

# The files of code that the page changes, as it changes a Markdown file. The whole file is one block of code.
const CODE_FILES = (".jl",)

"""
True when the file at `path` is code that the page can change: a kind of file
in `CODE_FILES`, whose text shows whole. A file of any usual length does: see
"the lines of a long file". A file that's longer than `MOST_PAGE`, or that
isn't text, is only shown.
"""
iscode(path) = begin
  (lowercase(splitext(path)[2]) in CODE_FILES && isfile(path)) || return false
  filesize(path) == 0 && return true
  found = try reading(path, tidy=false, most=MOST_PAGE) catch; nothing end
  found !== nothing && !found[2]
end

const MOST_TEXT = 400_000    # bytes. The preview of a longer file stops there.

const MOST_PAGE = 20_000_000 # bytes. A file that shows as a page shows this much of its text: see "the lines of a long file".

"""
The lines of the file at `path` and whether it has more, or nothing if it isn't
text. With `tidy`, a tab is two spaces and a long line stops at 200 characters,
which is how the lines of a file of code are shown. No more than `most` bytes
of the file are read.
"""
reading(path; tidy=true, most=MOST_TEXT) = begin
  # Julia makes room for as many bytes as it's asked to read, so it's asked for no more than the file has
  bytes = open(io -> read(io, min(most, filesize(path)) + 1), path)
  more = length(bytes) > most
  more && resize!(bytes, most)
  (isempty(bytes) || 0x00 in view(bytes, 1:min(length(bytes), 4000))) && return nothing
  s = String(bytes)
  # A file that was cut short can stop part way through a character
  for _ in 1:3
    (isvalid(s) || !more) && break
    s = String(codeunits(s)[1:end-1])
  end
  isvalid(s) || return nothing
  lines = [tidy ? String(first(replace(rstrip(line, '\r'), '\t' => "  "), 200)) : String(rstrip(line, '\r')) for line in split(s, '\n')]
  # The last line of a file that was cut short isn't all there, and a file that ends with a new line has no line after it
  (more || isempty(lines[end])) && length(lines) > 1 && pop!(lines)
  lines, more
end

const HEX = "hex"          # the language of the lines that show a file's bytes

const HEX_BYTES = 10       # the column of such a line where the bytes start, after their place in the file

const HEX_CHARS = 60       # the column where the same bytes start as characters

const BITS = "bits"        # the language of the lines that show a file's bytes as bits

const BITS_ROW = 6         # how many bytes such a line has, so that it's no longer than a line of hexadecimal

const BITS_CHARS = HEX_BYTES + 9BITS_ROW + 1   # the column of such a line where its bytes start as characters

"True when `a` and `b` are the same text. Two lines of a file that didn't change are one string, which is quick to see."
same_text(a::String, b::String) = pointer(a) == pointer(b) || a == b

"How many lines at the start of `new` are as they are in `old`, and how many at the end of the lines that are left"
unchanged(new::Vector{String}, old::Vector{String}) = begin
  n, m = length(new), length(old)
  head = 0
  while head < min(n, m) && same_text(new[head+1], old[head+1])
    head += 1
  end
  tail = 0
  while tail < min(n, m) - head && same_text(new[n-tail], old[m-tail])
    tail += 1
  end
  (head, tail)
end

line_end(b, i) = (i, length(b.lines[i]))

"The name of the page of a folder that says the folder's kind"
const FOLDER_PAGE = ".ladder"

# --- paths -----------------------------------------------------------------------------

"The path that the module of the page at `path` is kept by: the file's real path, as Kip keeps a module by, or the address of a page on the web"
page_key(path::AbstractString) = isremote(path) ? String(path) : isfile(path) ? realpath(path) : abspath(path)

"The path that a link wrote with `escaped`"
unescaped(path) = replace(path, "%20" => ' ', "%28" => '(', "%29" => ')')

"True when the page shows a file's bytes, in hexadecimal or as bits. Each line keeps its columns, so the lines never wrap."
bytes_page(b::Buffer) = b.view in (:hex, :bits)

const STEP = "  "   # one step of indentation

const FILE_VIEWS = (:bits, :hex, :text, :file)   # the ways that a file with levels shows, from the lowest level

const JULIA = ("julia", "jl")   # the names of the language whose code blocks run

const LIVE = "ui"

"Whether each file that was asked about is text, with when the file was last read then. Only the last few are kept."
const TEXT_READ = Dict{String,Tuple{Float64,Bool}}()

"""
True when the file at `path` is text, so it can show as its text. A file is
read once to find out, and again after the page reads it again. A zip isn't
text: what shows for it is the list of its files.
"""
text_file(path) = begin
  lowercase(splitext(path)[2]) in ZIPS && return false
  at = get(READ, path, 0.0)
  kept = get(TEXT_READ, path, nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  found = isfile(path) && (try reading(path, tidy=false) !== nothing catch; false end)
  length(TEXT_READ) >= 16 && empty!(TEXT_READ)
  TEXT_READ[path] = (at, found)
  found
end

const SCHEDULE = Schedules.SCHEDULE

const FILTER = Filters.FILTER

"How many times the code of a page has run in this Ladder. A `check` block runs its lines again when it's more than it was."
const CODE_RUNS = Ref(0)

const LOAD = "load"

# What each folder that a list looks in held when it was last read: its pages, with when each file last changed
const FOLDER_PAGES = Dict{String,Any}()

const TIMELOG = Timelogs.TIMELOG

const HTMLS = (".html", ".htm")

const TERM_CARETS = (:block, :bar, :underline)

const TERM_PASTS = (1_000, 10_000, 50_000)

const VIEW_BLOCK = "view"

"""
The module of each Markdown page's `julia` code, by the real path of the
page's file. There's one for each file, as Kip has one for each Julia file.
The page's live blocks, the code that you run on it in any window, and the
kinds of block that it defines are all in the same module. See `page_module`.
"""
const PAGE_MODULES = Dict{String,Module}()

# How many times a CSV file has been read. What's worked out from a file's table is worked out again when this changes.
const table_reads = Ref(0)

const CHART = Charts.CHART

const SAVE = Saves.SAVE

"""
How many seconds a window waits for what its code comes to, before it goes on
drawing. A box whose code takes longer shows a spinner until the code comes
back. Tests make it longer, so that every result is there when a key's handler
ends.
"""
const RUN_WAIT = Ref(0.1)

"The task of the code that started to run last, in any window. Each run waits for the one before it to end, so two pieces of code never run at once."
const LAST_RUN = Ref{Any}(nothing)

# What's known of each web address that a picture has: the `curl` that's fetching
# it, the file it's kept in, or nothing if it couldn't be fetched
const fetches = Dict{String,Any}()

"What the card of the page's front matter is called: `f(e)` gives the word, or nothing for FRONTMATTER"
const MATTER_TITLES = Dict{Symbol,Any}()

"""
What shows in place of the card of the page's front matter, while the caret
isn't in it: `f(e, rows)` gives a node, or nothing to leave the card. `rows`
are the front matter's keys, each as its line, the key and what it's set to.
"""
const MATTER_CARDS = Dict{Symbol,Any}()

# A file that a page makes goes in a folder called .media beside the page: a
# picture that's pasted, a recording, a copy of a temporary file. Only the page
# that made it has a use for it, so it stays out of the list of the page's
# folder. The Finder and the sidebar leave out a name that starts with a dot
# until you ask for the hidden files.
const PAGE_MEDIA = ".media"
