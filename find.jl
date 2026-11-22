# A list of the lines that match in every page of a folder. In a document it's
# a code block in the language `find`:
#
#     ```find
#     what: to-do items
#     with: plumber
#     in: jobs
#     ```
#
# `what` is the kind of thing to list. A kind of line:
#
# - `to-do items`: the to-do items that aren't ticked
# - `done items`: the ones that are
# - `headings`
# - `lines`: any line of text
# - `paragraphs`, `bullet points`, `numbered items`, `quotes`, `table rows`
# - `links` and `pictures`: the lines that have one
#
# Or a kind of block:
#
# - `code blocks`: the blocks of code that Ladder shows as code
# - `sheets`, `spreadsheets`, `live blocks`, `diagrams`, `takeoffs`,
#   `schedules`, `charts`, `boards`, `calendars`, `day sliders`, `columns`, `sketches`, `signatures`, `contacts`, `maps`, `find lists`, `filters`, `save blocks`, `load blocks`, `email lists`,
#   `time logs`, `questions`, `changes`: the blocks that Ladder shows as that component
#
# A block is listed by the heading that it's under. A block of code, and a
# block with no heading over it, is listed by its own first line.
#
# `with` holds words, and a line is listed only when it has every one of
# them. A block is listed when its heading and its own lines have them. `in` names a folder beside the page. Without it, the list is of the
# page's own folder, and the folders in that one.
#
# An empty block lists every to-do item that isn't ticked. A block with only
# words in it lists the lines that have those words.
#
# This file reads and writes those lines, and finds what matches in the lines
# of a page. It draws nothing, and reads no file.

@use "./markdown" Kind Line classify spans isdone isdivider MATTER TOML_MATTER

"The language of a code block that is a list of what was found"
const FIND = "find"

what_is(names...; one, many=names[1], langs=(), block=!isempty(langs)) = (names=names, one=one, many=many, langs=langs, block=block)

"""
The kinds of thing that a list can be of, in the order that Ladder offers
them. `names` are the words that a block can name the kind by, and the first
is the one that Ladder writes. `one` and `many` are what the top of a list
calls one of them and several. A kind of block has `block`, and `langs`, the
languages of the code blocks that are of that kind. The kind `code` is every
block in another language.
"""
const WHATS = (todo=what_is("to-do items", "to-dos", "todos", "todo", "to-do", "tasks", "open items", one="to-do item"),
               done=what_is("done items", "done", "ticked", "ticked items", "finished", one="item that's done", many="items that are done"),
               heading=what_is("headings", "heading", one="heading"),
               line=what_is("lines", "line", "text", one="line"),
               paragraph=what_is("paragraphs", "paragraph", one="paragraph"),
               bullet=what_is("bullet points", "bullets", "bullet", "list items", one="bullet point"),
               ordered=what_is("numbered items", "numbered", "numbers", one="numbered item"),
               blockquote=what_is("quotes", "quote", "blockquotes", one="quote"),
               table=what_is("table rows", "tables", "table", "rows", one="table row"),
               link=what_is("links", "link", "urls", one="line with a link", many="lines with a link"),
               picture=what_is("pictures", "picture", "images", "image", "photos", one="line with a picture", many="lines with a picture"),
               code=what_is("code blocks", "code", one="code block", block=true),
               sheet=what_is("sheets", "sheet", one="sheet", langs=("sheet",)),
               spreadsheet=what_is("spreadsheets", "spreadsheet", one="spreadsheet", langs=("spreadsheet",)),
               live=what_is("live blocks", "live block", "live", one="live block", langs=("ui",)),
               diagram=what_is("diagrams", "diagram", "mermaid", one="diagram", langs=("mermaid",)),
               takeoff=what_is("takeoffs", "takeoff", one="takeoff", langs=("takeoff",)),
               schedule=what_is("schedules", "schedule", one="schedule", langs=("schedule",)),
               chart=what_is("charts", "chart", "graphs", one="chart", langs=("chart",)),
               board=what_is("boards", "board", "kanban", one="board", langs=("board",)),
               calendar=what_is("calendars", "calendar", one="calendar", langs=("calendar",)),
               day=what_is("day sliders", "day slider", "day blocks", one="day slider", langs=("day",)),
               columns=what_is("columns", "column", one="set of columns", many="sets of columns", langs=("columns", "column")),
               sketch=what_is("sketches", "sketch", "drawings", one="sketch", langs=("sketch",)),
               canvas=what_is("canvases", "canvas", "mind maps", one="canvas", langs=("canvas",)),
               signature=what_is("signatures", "signature", one="signature", langs=("signature",)),
               contact=what_is("contacts", "contact", "people", one="block of contacts", many="blocks of contacts", langs=("contact",)),
               gallery=what_is("galleries", "gallery", one="gallery", langs=("gallery",)),
               map=what_is("maps", "map", one="map", langs=("map",)),
               find=what_is("find lists", "find list", "finds", one="find list", langs=(FIND,)),
               filter=what_is("filters", "filter", one="filter", langs=("filter",)),
               save=what_is("save blocks", "save block", "saves", one="save block", langs=("save",)),
               load=what_is("load blocks", "load block", "loads", one="load block", langs=("load",)),
               check=what_is("checks", "check", "check blocks", one="block of checks", many="blocks of checks", langs=("check",)),
               email=what_is("email lists", "email list", "emails", one="email list", langs=("email",)),
               timelog=what_is("time logs", "time log", "timelogs", "timesheets", one="time log", langs=("timelog",)),
               question=what_is("questions", "question", one="question", langs=("ask",)),
               changes=what_is("changes", one="set of changes", many="sets of changes", langs=("changes",)))

"The name of the kind `k` as a button or a menu shows it: To-do items"
title(k::Symbol) = uppercasefirst(WHATS[k].names[1])

"True when the kind `k` is a kind of block, and not a kind of line"
isblock(k::Symbol) = haskey(WHATS, k) && WHATS[k].block

"The kind of block that a code block in the language `lang` is, or nothing for a page's front matter"
block_kind(lang::AbstractString) = begin
  lang in (MATTER, TOML_MATTER) && return nothing
  for k in keys(WHATS)
    lang in WHATS[k].langs && return k
  end
  :code
end

mutable struct Query
  what::Union{Nothing,Symbol}   # a key of WHATS, like :todo, or nothing when the block doesn't say
  with::Vector{String}          # the words that a line must have
  folder::String                # the folder to look in, or "" for the page's own
  other::Vector{String}         # the lines that this file doesn't know, kept as they are
end

Query() = Query(nothing, String[], "", String[])

"The kind of thing that `words` name, or nothing"
what(words::AbstractString) = begin
  w = lowercase(strip(words))
  for k in keys(WHATS)
    w in WHATS[k].names && return k
  end
  nothing
end

"The kind of thing that the list is of. A block that doesn't say lists lines when it has words to find, and to-do items when it has none."
kind(q::Query) = q.what !== nothing ? q.what : isempty(q.with) ? :todo : :line

"Read what to find from the lines of its block"
query(lines) = begin
  q = Query()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    m = match(r"^(\w+)\s*:\s*(.*)$", text)
    key, value = m === nothing ? ("", "") : (lowercase(m[1]), String(strip(m[2])))
    if key == "what" && what(value) !== nothing
      q.what = what(value)
    elseif key == "with"
      append!(q.with, split(value))
    elseif key == "in"
      q.folder = value
    elseif m !== nothing
      push!(q.other, String(text))
    elseif what(text) !== nothing
      q.what = what(text)       # the kind by itself, like `headings`
    else
      append!(q.with, split(text))   # words by themselves are the words to find
    end
  end
  q
end

"The lines of the block"
written(q::Query) = begin
  out = String[]
  q.what === nothing || push!(out, "what: " * WHATS[q.what].names[1])
  isempty(q.with) || push!(out, "with: " * join(q.with, " "))
  isempty(q.folder) || push!(out, "in: " * q.folder)
  append!(out, q.other)
  out
end

"A line or a block that was found"
struct Match
  path::String    # the file that it's in
  line::Int       # the line of that file. A block's is the line that opens it.
  text::String    # its text as it reads, without the marks of bold and the like
  kind::Symbol    # what it is: :todo, :done, :heading, :line for any other line of text, or the kind of a block, like :takeoff
end

const PICTURE = r"!\[([^\]]*)\]\(\s*<?([^)\s>]*)>?[^)]*\)"
const ADDRESS = r"https?://\S"

"`text` with each picture in it as its words, or as the name of its file when it has none"
without_pictures(text::AbstractString) =
  occursin("![", text) ? replace(text, PICTURE => s -> (m = match(PICTURE, s); isempty(strip(m[1])) ? basename(m[2]) : m[1])) : text

"The text of a line as it reads: without what starts it, like the # of a heading, and without the marks of bold and the like"
reads(text::AbstractString, l::Line) =
  String(strip(join(s.text for s in spans(without_pictures(String(chop(text, head=min(l.prefix, length(text)), tail=0)))) if !s.markup)))

"True when the line `text` has a link: words that go somewhere, or an address by itself. A picture and a footnote aren't links."
haslink(text::AbstractString) =
  occursin(ADDRESS, replace(text, PICTURE => "")) || any(s -> !isempty(s.link) && !startswith(s.link, '^'), spans(replace(text, PICTURE => "")))

"What the line `text` is to a list: a to-do item, one that's done, a heading or a line"
line_kind(text::AbstractString, l::Line) = l.kind == Kind.todo ? (isdone(text) ? :done : :todo) : l.kind == Kind.heading ? :heading : :line

"True when the line `text` is of the kind `want`, a kind of line"
fits(want::Symbol, text::AbstractString, l::Line) =
  want == :line ? true :
  want in (:todo, :done, :heading) ? line_kind(text, l) == want :
  want == :paragraph ? l.kind == Kind.paragraph && !isempty(strip(replace(text, PICTURE => ""))) :   # a picture by itself is no paragraph
  want == :bullet ? l.kind == Kind.bullet :
  want == :ordered ? l.kind == Kind.ordered :
  want == :blockquote ? l.kind == Kind.blockquote :
  want == :table ? l.kind == Kind.table && !isdivider(text) :
  want == :link ? haslink(text) :
  want == :picture ? occursin(PICTURE, text) : false

"The text of a line as a list shows it. A line of a table shows as it's written."
line_words(text::AbstractString, l::Line) = l.kind == Kind.table ? String(strip(text)) : reads(text, l)

"The lines of the block that opens on line `i`: from the line under it to the one over the line that closes it"
block_span(kinds, i::Int) = begin
  t = i
  while t < length(kinds) && kinds[t+1].kind == Kind.code
    t += 1
  end
  i+1:t
end

"""
The words that a list shows for the block of the kind `is` that opens on line
`i`: the heading that it's under. A block of code, and a block with no
heading over it, shows its own first line. An empty one shows what it is.
"""
block_words(lines, kinds, i::Int, is::Symbol) = begin
  if is != :code
    h = findprev(l -> l.kind == Kind.heading, kinds, i)
    text = h === nothing ? "" : reads(lines[h], kinds[h])
    isempty(text) || return text
  end
  for j in block_span(kinds, i)
    text = strip(lines[j])
    isempty(text) || return String(text)
  end
  uppercasefirst(WHATS[is].one)
end

"The kind of the block that opens on line `i`, or nothing when no block opens there"
block_at(kinds, i::Int) = (l = kinds[i]; l.kind == Kind.fence && l.level == 0 ? block_kind(l.lang) : nothing)

"""
The lines of the page at `path` that `q` asks for, or its blocks when `q`
asks for a kind of block. `lines` holds the page's text. A line of code isn't
a line of the page's text, and neither is its front matter.
"""
matches(q::Query, path::AbstractString, lines, kinds=classify(lines)) = begin
  want = kind(q)
  words = lowercase.(q.with)
  out = Match[]
  for (i, l) in enumerate(kinds)
    if isblock(want)
      block_at(kinds, i) == want || continue
      text = block_words(lines, kinds, i, want)
      if !isempty(words)
        hay = lowercase(text * "\n" * join(view(lines, block_span(kinds, i)), "\n"))
        all(w -> occursin(w, hay), words) || continue
      end
      push!(out, Match(String(path), i, text, want))
      continue
    end
    l.kind in (Kind.blank, Kind.fence, Kind.code, Kind.rule) && continue
    fits(want, lines[i], l) || continue
    # A line that hasn't the words as it's written hasn't them as it reads, and is quick to rule out
    isempty(words) || (raw = lowercase(lines[i]); all(w -> occursin(w, raw), words)) || continue
    text = line_words(lines[i], l)
    isempty(text) && continue
    low = lowercase(text)
    all(w -> occursin(w, low), words) || continue
    push!(out, Match(String(path), i, text, line_kind(lines[i], l)))
  end
  out
end

"True when the list of `q` counts `m` as one of its own. A list of to-do items doesn't count an item that was ticked in it, though it still shows it."
counted(q::Query, m::Match) = !(kind(q) in (:todo, :done)) || m.kind == kind(q)

"""
The line of a page that the match `m` is on now, or nothing when the page no
longer has it. The page can have changed since `m` was found, so this is the
line nearest to where it was that still reads the same and is of the same kind.
"""
locate(m::Match, lines, kinds=classify(lines)) = begin
  same(i) = begin
    1 <= i <= length(lines) || return false
    l = kinds[i]
    isblock(m.kind) && return block_at(kinds, i) == m.kind && block_words(lines, kinds, i, m.kind) == m.text
    l.kind in (Kind.blank, Kind.fence, Kind.code, Kind.rule) && return false
    line_kind(lines[i], l) == m.kind && line_words(lines[i], l) == m.text
  end
  for far in 0:length(lines)
    same(m.line - far) && return m.line - far
    same(m.line + far) && return m.line + far
  end
  nothing
end

"`line` with the box of its to-do item ticked, or with its tick taken away"
ticked(line::AbstractString, done::Bool) = begin
  i = findfirst('[', line)
  i === nothing && return String(line)
  chars = collect(line)
  k = length(line[1:i])   # the place of the [ among the characters
  k < length(chars) && (chars[k+1] = done ? 'x' : ' ')
  String(chars)
end

"""
What the list is of and where it looks, in words, for `n` lines or blocks in
`pages` pages: `3 to-do items in 2 pages of this folder`
"""
summary(q::Query, n::Int, pages::Int) = begin
  one, many = WHATS[kind(q)].one, WHATS[kind(q)].many
  with = isempty(q.with) ? "" : " with “" * join(q.with, " ") * "”"
  place = isempty(q.folder) ? "this folder" : "the folder " * q.folder
  n == 0 && return "No $many$with in $place"
  "$n $(n == 1 ? one : many)$with in $(pages == 1 ? "1 page" : "$pages pages") of $place"
end
