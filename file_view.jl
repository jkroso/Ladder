# What shows for each kind of file, in the page: a zip, a CSV file, a Markdown file, the pages of a PDF, and a file that isn't Markdown

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" describe reuse! focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" cursor rect
@use "github.com/jkroso/UI.jl/Interface/image" image_aspect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" AudioPlayer VideoPlayer
@use "github.com/jkroso/UI.jl/Interface/Semantic/ThreeMF" => ThreeMF
@use "./pictures" picture thumbnail pdf_pages pdf_page
@use "./markdown" classify words
@use "./sheet" shown
@use "./csv" => Csvs
@use "./base" exports...
@use "./sketch_view" exports...
@use "./csv_view" exports...
@use "./json_view" exports...
@use "./terminal_view" term_page
@use "./fill_view" video_wide
@use "./webpage_view" html_page

export MOST_ZIP, zipped, MOST_COLUMNS, FileTable, tabled, tableview, tablerow, PAGE_ZOOM,
       PAGE_HEIGHT, FilePage, room, filepage, pageview, pager, FILE_ICONS, framed, peek, MOST_LINE,
       MOST_HEX, MOST_BITS, viewed, shown_line, text_look, file_views, hexlines, hex_about,
       bitlines, bits_about, hex!, preview, scrolled, kept!, text!, bytes

const MOST_ZIP = 300_000_000   # bytes. A bigger zip isn't read.

"The files in the zip at `path`, as lines of text: the name of each and how big it is once it's unpacked"
zipped(path) = begin
  filesize(path) > MOST_ZIP && return nothing
  found = try ThreeMF.entries(read(path)) catch; return nothing end
  names = sort!([name for name in keys(found) if !endswith(name, '/')])
  isempty(names) && return nothing
  wide = min(64, maximum(length, names))
  FileText([rpad(length(name) > 64 ? "…" * last(name, 63) : name, wide) * "   " * bytes(found[name].full) for name in names], false)
end

# --- a CSV file as a table --------------------------------------------------------------------

const MOST_COLUMNS = 40

"The rows of a CSV file that a breadcrumb previews, and how wide each column is"
mutable struct FileTable
  rows::Vector{Vector{String}}
  widths::Vector{px}
  more::Bool
  scroll::Scroll
end

"The cells of one line of a CSV file, as csv.jl reads them. `mark` is the character between two cells."
const csv_cells = Csvs.cells

"The rows of the CSV file at `path`. The mark between its cells is the one its first line has most of: a comma, a tab or a semicolon."
tabled(path) = begin
  found = reading(path, tidy=false)
  found === nothing && return nothing
  lines, more = found
  lines = filter(!isempty, lines)
  isempty(lines) && return nothing
  mark = argmax(c -> count(==(c), lines[1]), (',', '\t', ';'))
  rows = [first(csv_cells(line, mark), MOST_COLUMNS) for line in lines]
  columns = maximum(length, rows)
  face(r) = Face(SANS, r == 1 ? "Semibold" : "", 12px, colours.ink, false)
  # A column is as wide as the widest of its first hundred cells, and no wider than 240px
  widths = [clamp(maximum(r -> c <= length(rows[r]) ? measure(face(r), rows[r][c]) : 0px, 1:min(100, length(rows))), 24px, 240px) + 20px
            for c in 1:columns]
  FileTable(rows, widths, more, Scroll(width(grow=grow), height(ROW_H * min(length(rows), PREVIEW_LINES) + 2TEXT_PAD)))
end

"The rows of a CSV file as a table. Its first row is its headings."
tableview(t::FileTable) = scrolled(r -> tablerow(t, r), t.scroll, length(t.rows), ROW_H)

"""
Row `r` of a CSV file's table. It's as wide as the box that the table is in,
so its stripe reaches both sides. Each column takes a share of that width as
big as its share of the widths that its text needs, and never less than those,
as the table of a CSV file that fills the window does. The text of a cell is
in the middle of the row's height.
"""
tablerow(t::FileTable, r) = begin
  total = num(sum(t.widths))
  Row(width(grow=grow), height(ROW_H), radius(3px), background(r == 1 ? colours.head : iseven(r) ? clear : colours.stripe),
    [Row(width(percent=num(w) / total, min=w), height(ROW_H), padding(10px, 0px), Alignment.Center, clip=true,
         label(c <= length(t.rows[r]) ? t.rows[r][c] : "", 12px, weight=r == 1 ? "Semibold" : ""))
     for (c, w) in enumerate(t.widths)]...)
end

# --- a Markdown file as it reads ---------------------------------------------------------------

const PAGE_ZOOM = 0.8        # the text of a page under a path is this much smaller than the text of the page itself
const PAGE_HEIGHT = 320px    # the most of the page that shows. The wheel scrolls through the rest.

"The lines of a Markdown file that a breadcrumb previews, laid out as the page lays out its own lines"
mutable struct FilePage
  flows::Vector{Flow}
  tops::Vector{px}   # how far each line is under the first
  tall::px
  more::Bool
  scroll::Scroll
end

"How wide what's under the breadcrumb `l` is"
room(l::Breadcrumb) = (e = editor(l); (l.inline ? min(LISTING_W, e.width) : e.width - 2PANEL_PAD) - 12px)

"The Markdown file at `path`, laid out for the breadcrumb `l`. It's laid out again when the page's text changes its size, font, weight or colours."
filepage(l::Breadcrumb, path) = begin
  e = editor(l)
  wide = room(l) - 28px   # the page has 14px of room on each side
  kept!(l, path, (:page, wide, e.zoom, look_key(e), e.font, e.weight)) do path
    found = reading(path, tidy=false)
    found === nothing && return nothing
    lines, more = found
    kinds = classify(lines)
    zoom = e.zoom
    e.zoom = zoom * PAGE_ZOOM
    # -1 says that the line isn't one of the document's, so its inline code isn't run
    flows = try
      [laid(e, lines[i], kinds[i], false, -1, wide) for i in eachindex(lines)]
    finally
      e.zoom = zoom
    end
    tops = accumulate(+, map(tall, flows)) .- map(tall, flows)
    total = sum(tall, flows, init=0px)
    FilePage(flows, tops, total, more, Scroll(width(grow=grow), height(min(total + 2TEXT_PAD, PAGE_HEIGHT))))
  end
end

"A Markdown file as it reads. Only the lines in view are made."
pageview(e, p::FilePage) = begin
  from = p.scroll.offset - TEXT_PAD
  lo = something(findlast(<=(from), p.tops), 1)
  hi = something(findfirst(>(from + PAGE_HEIGHT), p.tops), length(p.tops) + 1) - 1
  under = p.tall - (p.tops[hi] + tall(p.flows[hi]))
  Box(width(grow=grow), padding(14px, 0px), radius(5px), background(colours.bg), clip=true,
    reuse!(p.scroll, Column(width(grow=grow), Alignment.Start,
      spacer(TEXT_PAD + p.tops[lo]),
      [describe(e, Item(0, 0, 0px, tall(f), f), f) for f in p.flows[lo:hi]]...,
      spacer(TEXT_PAD + under))))
end

# --- the pages of a PDF file --------------------------------------------------------------------

describe(p::Pages) = begin
  # Twice as many pixels as px, so that the page is sharp on a screen with 2 pixels to the px
  key = pdf_page(p.path, p.page, round(Int, 2num(p.wide)))
  key === nothing && return label("This page can't be shown", 12px, color=colours.dim)
  shape = image_aspect(key)
  arrow(name, on) = Icon(name, size=11px, color=on ? colours.dim : colours.faint)
  Column(Alignment.Start, child_gap=6px,
    fillable(p, (:pdf, p.path, p.page), Image(key, fixed(p.wide), height(p.wide / shape), radius(3px), border(1px, :solid, colours.line))),
    (p.count > 1 ? (Row(fixed(p.wide), height(22px), justify=Alignment.Center, child_gap=10px,
       arrow("chevron-left", p.page > 1), label("Page $(p.page) of $(p.count)", 12px, color=colours.dim),
       arrow("chevron-right", p.page < p.count)),) : ())...)
end

cursor(p::Pages) = p.count > 1 ? :hand : :arrow

"Go on by `by` pages, as far as the first page or the last"
turn!(p::Pages, by) = (p.page = clamp(p.page + by, 1, max(1, p.count)); handled)

onkey(p::Pages, ev::KeyPress{Keys.mouse_left}) = begin
  focus(p)
  r = rect(p)
  r === nothing ? handled : turn!(p, ev.window.mouse[1] < r.left + p.wide / 2 ? -1 : 1)
end
# The arrow keys turn the pages too, once a click has given them the keyboard
onkey(p::Pages, ev::KeyPress{Keys.left}) = unmodified(ev) ? turn!(p, -1) : nothing
onkey(p::Pages, ev::KeyPress{Keys.right}) = unmodified(ev) ? turn!(p, 1) : nothing

"The pages of the PDF file at `path`, or nothing if it isn't a PDF file that macOS can read"
pager(l::Breadcrumb, path) = begin
  v = l.viewer
  v isa Pages && v.path == path && return v
  hush!(l)
  n = pdf_pages(path)
  n == 0 ? nothing : (l.viewer = own!(l, Pages(path=path, count=n)))
end

# --- what shows for each kind of file --------------------------------------------------------------

"Every icon that `file_icon` can give, and those of a file that's only shown: of a binary file, and of the button that opens the file in its own app. The built app reads them all when it's made."
const FILE_ICONS = ("file-earmark", "file-earmark-text", "file-earmark-image", "file-earmark-music", "file-earmark-play", "box", "terminal",
                    "file-earmark-pdf", "file-earmark-zip", "file-earmark-spreadsheet", "file-earmark-font", "file-earmark-richtext",
                    "file-earmark-code", "file-earmark-binary", "box-arrow-up-right", "chevron-left", "chevron-right")

"The picture kept under `key`, no taller than `most` and no wider than 420px. A picture of a page has a line round it."
framed(key, most=260px; page=false) = begin
  shape = image_aspect(key)
  w = min(420px, most * shape)
  page ? Image(key, fixed(w), height(w / shape), radius(3px), border(1px, :solid, colours.line)) :
         Image(key, fixed(w), height(w / shape), radius(4px))
end

"""
What shows for the file at `path`, or nothing if the file has no preview. `ext`
is the end of the file's name. `note(words)` adds words to the line under the
preview.
"""
peek(l::Breadcrumb, path, ext, note) = begin
  mac = Sys.isapple()
  # A picture, a model and a video have a button that makes them fill the window
  pic(key, more...; kw...) = fillable(l, (:picture, key), framed(key, more...; kw...))
  if ext in PICTURES
    return pic(path)
  elseif ext in MAC_PICTURES
    key = picture(path)
    key === nothing || return pic(key)
  elseif ext in MODELS
    viewer = model(l, path)
    viewer === nothing || return fillable(l, (:node, viewer), viewer, wide=:grow)
  elseif ext in DESIGNS
    viewer = design(l, path)
    return fillable(l, (:node, viewer), viewer, wide=:grow)
  elseif ext in TERMINALS
    return terminal(l, path)
  elseif mac && ext in SOUNDS
    return player(l, path, AudioPlayer)
  elseif mac && ext in VIDEOS
    p = player(l, path, VideoPlayer)
    return fillable(l, (:node, p), p, wide=video_wide(p))
  elseif mac && ext == ".pdf"
    found = pager(l, path)
    found === nothing || return found
  elseif ext in ZIPS
    list = kept!(zipped, l, path, :zip)
    list === nothing && return nothing
    note("$(length(list.lines)) file$(length(list.lines) == 1 ? "" : "s")")
    return textview(list, "")
  elseif ext in TABLES
    table = kept!(tabled, l, path, :table)
    table === nothing && return nothing
    note(table.more ? "the first $(length(table.rows) - 1) rows" : "$(length(table.rows) - 1) row$(length(table.rows) == 2 ? "" : "s")")
    return tableview(table)
  elseif ismarkdown(path)
    page = filepage(l, path)
    page === nothing && return nothing
    page.more && note("the first $(bytes(MOST_TEXT)) of $(bytes(filesize(path)))")
    return pageview(editor(l), page)
  elseif ext in DOCUMENTS || ext in FONTS
    key = thumbnail(path)
    return key === nothing ? nothing : pic(key, 400px, page=ext in DOCUMENTS)
  end
  text = text!(l, path)
  if text !== nothing
    text.more && note("the first $(bytes(MOST_TEXT)) of $(bytes(filesize(path)))")
    return textview(text, file_lang(path))
  end
  # The Finder has a picture for many kinds of file that have none here
  key = thumbnail(path)
  key === nothing ? nothing : pic(key)
end

"What shows under the path of a file: its picture, its model, its player, its pages or its text, and when it last changed"
preview(l::Breadcrumb, path) = begin
  isfile(path) || return Box(height(0px))
  ext = lowercase(splitext(path)[2])
  # A player that was made for another file stops when the path leaves that file
  l.viewer !== nothing && l.viewer.path != path && (hush!(l); l.viewer = nothing)
  about = "Changed " * Libc.strftime("%-d %b %Y, %H:%M", mtime(path))
  content = try
    peek(l, path, ext, words -> (about *= "  ·  " * words))
  catch
    nothing
  end
  content === nothing && (content = label("This file has no preview", 12px, color=colours.dim))
  Column(width(grow=grow), Alignment.Start, padding(6px), child_gap=8px,
    content, label(about, 12px, color=colours.dim))
end

cursor(::FileEntry) = :hand

onkey(r::FileEntry, ev::KeyPress{Keys.mouse_left}) = begin
  l = r.parent::Breadcrumb
  # A click with ⌘ held shows the file in the window, as a click on a link with ⌘ held does. In a `view` block any
  # click does, since the block shows the folder that its line names.
  (only_held(r, Keys.cmd) || l.parent isa ViewBlock) && !l.folders && return show_crumb!(l, r.path, ev.window)
  l.at = r.path
end

# --- a file that isn't Markdown, in the page -------------------------------------------------
#
# A click on a file in the sidebar shows the file in the page, whatever kind of
# file it is. Ladder changes Markdown files and Julia files, so any other file
# is only shown, and the top bar has a lock (see `ReadOnly`). The button beside
# the lock opens the file in the app that the Mac uses for it.
#
# A Julia file is one block of code, with no lines that open and close it. You
# type in it as in a `julia` code block of a page: ⌘Return runs the expression
# that the caret is in, a list offers names, a bracket comes with the bracket
# that closes it, and ⌘S writes the file. What its code comes to has three
# levels under the value, as it has in a `julia` code block: with the slider in
# the top bar, the box after a piece of code shows the code as Julia infers it,
# its LLVM code or its assembly.
# "what Julia code ran, down a level" says more.
#
#   - A file of text shows its text. A file of code has the colours that a code
#     block has. You can select the text, copy it and find words in it.
#   - A picture, a model, a sound, a video, a PDF file, a CSV file, a Word file
#     and a font show as they do under a file path, as big as the page has room for.
#   - A CSV file shows as a table as wide as the window, which you can sort and
#     filter by its headings. "a CSV file in the page" says more.
#   - A JSON file shows as a tree of its values. "a JSON file as a tree"
#     says more.
#   - A file of text, a CSV file and a JSON file have levels under what they
#     show: the file's text, its bytes in hexadecimal, and its bits. The
#     slider in the top bar goes to each. "the slider of the levels" says more.
#   - A zip shows the list of the files in it.
#   - Any other file is a binary file. The page says so, and a button there
#     shows the file's bytes in hexadecimal.

const MOST_LINE = 2000     # characters. A longer line of a file's text stops there.
const MOST_HEX = 160_000   # bytes. The lines of a longer file stop there.
const MOST_BITS = 80_000   # bytes. The lines of bits of a longer file stop there.

"True when a file whose name ends with `ext` has a viewer of its own, so it doesn't show as text"
viewed(ext) = ext in PICTURES || ext in MAC_PICTURES || ext in MODELS || ext in SOUNDS || ext in VIDEOS || ext == ".pdf" ||
              ext in TABLES || ext in DOCUMENTS || ext in FONTS

"A line of a file's text as the page shows it: a tab is two spaces, and a very long line stops with an …"
shown_line(line) = begin
  s = replace(line, '\t' => "  ")
  length(s) > MOST_LINE ? first(s, MOST_LINE) * "…" : String(s)
end

"The buffer that shows the file at `path`, which isn't Markdown. A JSON file shows as a tree and an HTML file as its page, or with `tree` false as their text."
look(path; tree=true) = begin
  ext = lowercase(splitext(path)[2])
  if table_edits(path)
    return table_look(path)   # a CSV file that its table changes: see "changing a CSV file"
  elseif ext in ZIPS
    return Buffer(path=path, view=:file)   # the list of what it holds: see "a zip file"
  elseif tree && ext in JSONS && json_of(path) !== nothing
    return Buffer(path=path, view=:file)
  elseif tree && ext in HTMLS && text_file(path)
    return Buffer(path=path, view=:file)   # the page that its HTML makes: see "an HTML file as its page"
  elseif tree && ext in TERMINALS
    return Buffer(path=path, view=:file)   # the terminal that it keeps: see "a terminal's file"
  elseif tree && ext in CHATS
    return Buffer(path=path, view=:file)   # the session that it keeps: see "a session's file"
  elseif !viewed(ext)
    shown = text_look(path)
    shown === nothing || return shown
  end
  Buffer(path=path, view=:file)
end

"The buffer that shows the text of the file at `path`, or nothing if the file isn't text"
text_look(path) = begin
  found = try reading(path, tidy=false, most=MOST_PAGE) catch; nothing end
  found === nothing && return nothing
  lines, more = found
  Buffer(path=path, view=:text, lines=map(shown_line, lines),
         about=more ? "First $(bytes(MOST_PAGE)) of $(bytes(filesize(path)))" : "")
end

"""
The ways that the file of `b` can show, from its lowest level to its highest,
or () for a page and for a file with one way to show. A file of text shows as
its bits, its bytes in hexadecimal and its text. A JSON file and a CSV file
have a level over their text: :file, which is the tree of the one and the
table of the other. So has an HTML file: the page that its HTML makes.
"""
file_views(b::Buffer) = begin
  (b.view in FILE_VIEWS && !isdir(b.path)) || return ()   # a folder that shows in the page has one way to show
  (json_page(b) || html_page(b) || term_page(b) || chat_page(b)) && return FILE_VIEWS
  ext = lowercase(splitext(b.path)[2])
  ext in TABLES ? (text_file(b.path) ? FILE_VIEWS : ()) :
  viewed(ext) || !text_file(b.path) ? () : FILE_VIEWS[1:3]
end

"""
The bytes of the file at `path` as lines of text. Each line has the place of
its first byte in the file, then 16 bytes in hexadecimal, then the same bytes
as characters. A byte that isn't a character of plain text shows as a dot.
"""
hexlines(path) = begin
  data = open(io -> read(io, MOST_HEX), path)
  hex(row) = join((string(x, base=16, pad=2) for x in row), ' ')
  map(0:16:max(0, length(data) - 1)) do at
    row = data[at+1:min(at + 16, end)]
    rpad(string(at, base=16, pad=8), HEX_BYTES) * rpad(hex(row[1:min(8, end)]) * "  " * hex(row[9:end]), HEX_CHARS - HEX_BYTES) *
      String([0x20 <= x < 0x7f ? Char(x) : '.' for x in row])
  end
end

"What the top bar says of the bytes of the file at `path`: how many of them show, when not all do"
hex_about(path) = filesize(path) > MOST_HEX ? "First $(bytes(MOST_HEX)) of $(bytes(filesize(path)))" : ""

"""
The bytes of the file at `path` as lines of bits. Each line has the place of
its first byte in the file, then `BITS_ROW` bytes as the 8 bits of each, then
the same bytes as characters. A byte that isn't a character of plain text
shows as a dot.
"""
bitlines(path) = begin
  data = open(io -> read(io, MOST_BITS), path)
  map(0:BITS_ROW:max(0, length(data) - 1)) do at
    row = data[at+1:min(at + BITS_ROW, end)]
    rpad(string(at, base=16, pad=8), HEX_BYTES) * rpad(join((string(x, base=2, pad=8) for x in row), ' '), BITS_CHARS - HEX_BYTES) *
      String([0x20 <= x < 0x7f ? Char(x) : '.' for x in row])
  end
end

"What the top bar says of the bits of the file at `path`: how many of its bytes show, when not all do"
bits_about(path) = filesize(path) > MOST_BITS ? "First $(bytes(MOST_BITS)) of $(bytes(filesize(path)))" : ""

"""
The buffer that shows the file at `path` at the level `view`: :bits for its
bytes as bits, :hex for its bytes in hexadecimal, :text for its text, and
:file for what `look` shows, like the tree of a JSON file or the table of a
CSV file. A file that has no text shows as `look` shows it.
"""
look(path, view::Symbol) = begin
  view in (:file, :text) && table_edits(path) && return table_look(path, view)
  view == :bits && return Buffer(path=path, view=:bits, lines=bitlines(path), about=bits_about(path))
  view == :hex && return Buffer(path=path, view=:hex, lines=hexlines(path), about=hex_about(path))
  # A terminal's file is read each time, since its shell writes it while it shows
  (view == :text && (text_file(path) || lowercase(splitext(path)[2]) in (TERMINALS..., CHATS...))) || return look(path)
  something(text_look(path), look(path))
end

"Show the bytes of the file that the page shows, in hexadecimal"
hex!(e) = begin
  b = e.buf
  (readonly(b) && isfile(b.path)) || return e
  b.lines, b.about, b.view = hexlines(b.path), hex_about(b.path), :hex
  b.caret = b.anchor = (1, 0)
  b.saved = b.version += 1
  e.scroll.offset = 0px
  focus(e)
  e
end

"""
`n` rows that are each `high` tall, `PREVIEW_LINES` of them at a time. The
wheel scrolls through the rest. `row(i)` makes row `i`. Only the rows in view
are made, so a long file costs no more than a short one.
"""
scrolled(row, scroll::Scroll, n, high=LINE_H) = begin
  lo = clamp(floor(Int, (scroll.offset - TEXT_PAD) / high), 0, max(0, n - PREVIEW_LINES))
  hi = min(n, lo + PREVIEW_LINES + 2)
  Box(width(grow=grow), padding(10px, 0px), radius(5px), background(colours.bg), clip=true,
    reuse!(scroll, Column(width(grow=grow), Alignment.Start,
      spacer(TEXT_PAD + high * lo),
      [row(i) for i in lo+1:hi]...,
      spacer(TEXT_PAD + high * (n - hi)))))
end

"""
What the breadcrumb `l` keeps of the file at `path`: what `make(path)` gave, or
nothing if `make` found nothing to show. It's made again when the file changes.
`kind` names what's kept, so that two kinds of preview don't take each other's.
"""
kept!(make, l::Breadcrumb, path, kind) = begin
  key = (kind, path, mtime(path))
  l.read == key || (l.read = key; l.text = something(make(path), false))
  l.text === false ? nothing : l.text
end

"The text of the file at `path` for the breadcrumb `l`, or nothing if the file isn't text"
text!(l::Breadcrumb, path) = kept!(l, path, :text) do path
  found = reading(path)
  found === nothing ? nothing : FileText(found...)
end

"A file's size in words, like 6.5 KB"
bytes(n) = begin
  n < 1000 && return "$n bytes"
  for unit in ("KB", "MB", "GB")
    n /= 1000
    (n < 1000 || unit == "GB") && return "$(n < 10 ? round(n, digits=1) : round(Int, n)) $unit"
  end
end
