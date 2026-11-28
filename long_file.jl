# The lines of a long file
#
# A file of code can be tens of thousands of lines long. To lay out a line takes
# time: its code is cut into parts, each part is measured, and the parts are
# wrapped. So the lines of a file are laid out in a way that costs less, and the
# layout is kept from one frame to the next.
#
#   - A line is laid out as runs of text in one colour, and nothing is
#     measured. In a font whose characters are all one width, a run is as wide
#     as its characters are many, so where a long line breaks can be counted.
#     The line gets its colours when it's drawn, and only the lines on screen
#     are drawn: see `in_colour`.
#   - A line with a character that may be of another width is laid out in full,
#     and so is a line with a word that's too long for the window.
#   - After a change, only the lines that changed are laid out again.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe handled version
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor
@use "github.com/jkroso/UI.jl/Interface/image" image_source
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/STLViewer" STLViewer Mesh load!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" AudioPlayer VideoPlayer
@use "./pictures" natural thumbnail pdf_pages
@use "./markdown" Kind Line words
@use "./sheet" parts
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./changes_view" exports...
@use "./julia_levels" exports...
@use "./csv_view" exports...
@use "./json_view" exports...
@use "./fill_view" exports...
@use "./file_view" exports...
@use "./live_view" exports...
@use "./webpage_view" html_shown
@use "./terminal_view" term_shown

export Laid, pitches, pitch, typeable, quick_rows, quick_line, file_lines, in_colour, HexButton, file_item,
       model_part, model_shown, file_about, file_fill, file_zoom, video_part, file_covers, file_key!, fitted,
       viewer

"The layout of a file's lines, kept from one frame to the next, with the lines that it's of"
mutable struct Laid
  version::Int
  lines::Vector{String}
  items::Vector{Item}
end

const pitches = Dict{Tuple{String,String,Float32},Union{Nothing,px}}()

"""
How wide one character of `face` is, when each character that a keyboard types
is that wide, in the face and in the slanted one that comments are in. Code's
own fonts are like that. Nothing for a font whose characters differ.
"""
pitch(face::Face) = get!(pitches, (face.family, face.style, Float32(num(face.size)))) do
  wide = measure(face, "M")
  near(w, n=1) = abs(num(w) - n * num(wide)) < 0.01
  slant = Face(face, style=codeslant())
  # Two characters side by side can be nearer than they are apart, in a font that isn't code's
  even = all(c -> near(measure(face, string(c))) && near(measure(slant, string(c))), ' ':'~') &&
         near(measure(face, "AVAVfifiWoTo"), 12) && near(measure(face, "    ->==!="), 10)
  even && num(wide) > 0 ? wide : nothing
end

"True when each character of `text` is one that a keyboard types: a letter, a digit, a mark or a space"
typeable(text::String) = all(c -> 0x20 <= c <= 0x7e, codeunits(text))

"""
Where the line `text` breaks into lines on screen, as `wrap` breaks the line
that `file_line` gives it: the first and the last column of each. Each
character is `wide` across, the lines are `limit` across, and each after the
first starts at `hang`. Nothing when that can't be told without measuring:
a word that's too long for a line breaks between two parts of its code, and
a word that ends within half a pixel of the edge could go either way.
"""
quick_rows(text::String, wide::Float64, limit::Float64, hang::Float64) = begin
  chars = codeunits(text)
  n = length(chars)
  rows = Tuple{Int,Int}[]
  x = start = 0.0
  from = at = 0
  # The spaces that start the line go on its first line, however many they are
  while at < n && chars[at+1] == 0x20; at += 1 end
  x += at * wide
  while at < n
    word = at
    while word < n && chars[word+1] != 0x20; word += 1 end
    next = word
    while next < n && chars[next+1] == 0x20; next += 1 end
    w = (word - at) * wide
    w <= limit - hang - 0.5 || return nothing
    over = x + w - limit
    abs(over) < 0.5 && return nothing
    if over > 0 && x > start
      push!(rows, (from, at))
      from, x, start = at, hang, hang
    end
    # The spaces after a word may hang past the edge
    x += (next - at) * wide
    at = next
  end
  push!(rows, (from, n))
end

"""
Line `i` of a file, laid out for the layout of the whole file. It's what
`file_line` gives, but for the colours of its code, and nothing is measured:
`wide` is how wide one character of `face` is, so a run of text is as wide as
its characters are many. A line with a character that a keyboard doesn't type,
or in a font whose characters differ, when `wide` is nothing, is laid out by
`file_line`. So is a line that `quick_rows` can't break.
"""
quick_line(e, text::String, line::Line, i::Int, face::Face, lh::px, wide) = begin
  n = ncodeunits(text)
  (wide !== nothing && typeable(text)) || return file_line(e, text, line, i)
  run(from, to, x) = Seg[Seg(from == 0 && to == n ? text : text[from+1:to], from, to - from, face, false, "", x, (to - from) * wide, nothing)]
  flow(lines) = Flow(lines, lh, face.size, 0px, 0px, Kind.paragraph, false)
  # A line that's sure to fit, or that goes on past the edge of the window, is one line on screen
  (!wraps(e) || n * wide <= e.width - 1px) && return flow([VLine(n == 0 ? Seg[] : run(0, n, 0px), 0px, 0, n, 0px, lh)])
  # A line that goes on under itself starts there one step of indentation further in, as `file_line` has it
  lead = something(findfirst(!=(0x20), codeunits(text)), n + 1) - 1
  hang = min((lead + e.indent) * wide, e.width / 2)
  rows = quick_rows(text, num(wide), num(e.width), num(hang))
  rows === nothing && return file_line(e, text, line, i)
  flow([VLine(run(from, to, k == 1 ? 0px : hang), k == 1 ? 0px : hang, from, to, lh * (k - 1), lh) for (k, (from, to)) in enumerate(rows)])
end

"""
The lines of the file that `b` shows, laid out. Each is a line of code. The
whole page is code, so the lines have no background of their own and start at
the edge of the page. See "the lines of a long file".
"""
file_lines(e, b::Buffer) = begin
  key = (:lines, b.path, b.view)
  kept = get(e.flows, key, nothing)
  kept isa Laid && kept.version == b.version && return kept.items
  # What was laid out before, and the lines that it was of. Julia knows the types of these two, so the loops below are quick.
  was, before = kept isa Laid ? (kept.items, kept.lines) : (Item[], String[])
  ks, lines = kinds(b), b.lines
  n = length(lines)
  items = Vector{Item}(undef, n)
  n == 0 && return items
  # Every line of a file is a line of code in the file's language, so one face and one height do for all
  f = face(e, ks[1])
  lh = code_size(e) * 1.5 / CODE_SCALE
  wide = pitch(f)
  # The lines before the first that changed, and the lines after the last, keep their layout
  m = length(before)
  head, tail = unchanged(lines, before)
  # Except a line that `file_line` laid out in its colours, when a docstring above it opened or closed. Its text is the same, so it's as tall.
  at = string_opens(b)::Vector{Char}
  laid = get(e.flows, (:opens, key), nothing)
  laid_at::Vector{Char} = kept isa Laid && laid isa Opens ? laid.at : Char[]
  recoloured(it, i) = all(vl -> length(vl.segs) == 1, it.content.lines) ? it : Item(i, i, it.top, it.tall, quick_line(e, lines[i], ks[i], i, f, lh, wide))
  top = 0px
  copyto!(items, 1, was, 1, head)
  h = min(head, length(laid_at))
  if !same_chars(at, 1, laid_at, 1, h)
    for i in 1:h
      @inbounds laid_at[i] == at[i] || (items[i] = recoloured(items[i], i))
    end
  end
  head > 0 && (top = items[head].top + items[head].tall)
  for i in head+1:n-tail
    flow = quick_line(e, lines[i], ks[i], i, f, lh, wide)
    high = tall(flow)
    items[i] = Item(i, i, top, high, flow)
    top += high
  end
  # A long file has many lines after the change, and most often a docstring opened or closed above none of them
  kept_same = m == length(laid_at) && same_chars(at, n - tail + 1, laid_at, m - tail + 1, tail)
  for i in n-tail+1:n
    j = i - n + m
    it = was[j]
    kept_same || j > length(laid_at) || laid_at[j] == at[i] || (it = recoloured(it, i))
    items[i] = Item(i, i, top, it.tall, it.content)
    top += it.tall
  end
  e.flows[key] = Laid(b.version, copy(lines), items)
  e.flows[(:opens, key)] = Opens(b.path, b.view, b.version, String[], Line[], at)
  items
end

"""
The Flow `f` of the item `it`, with the colours of its code, to draw. A line of
a file whose lines on screen are each one run of text is in one colour: see
`quick_line`. The line as `file_line` lays it out has its colours, and is kept
by its text. It's drawn only if it breaks where `f` does, so the page's lines
stay where the layout put them.
"""
in_colour(e, it::Item, f::Flow) = begin
  b = e.buf
  (b.view != :markdown && it.first == it.last && 1 <= it.first <= length(b.lines)) || return f
  all(vl -> length(vl.segs) == 1, f.lines) || return f
  text = b.lines[it.first]
  (last(f.lines).to == length(text) && startswith(text, f.lines[1].segs[1].text)) || return f
  line = kinds(b)[it.first]
  spare_flows!(e)
  full = get!(() -> file_line(e, text, line, it.first), e.flows, (:file, text, line, string_opens(b)[it.first]))::Flow
  length(full.lines) == length(f.lines) && all(k -> full.lines[k].from == f.lines[k].from, eachindex(f.lines)) ? full : f
end

"""
Forget the lines that are laid out, when many are kept: more than a page of
4,000 lines has, or more than three for each line of a longer page, so that a
long page's lines stay laid out from one frame to the next. The layout of a
whole file's lines stays: it's made again only after a change.
"""
spare_flows!(e) = begin
  length(e.flows) > max(4000, 3length(e.buf.lines)) || return e
  kept = [p for p in e.flows if p.second isa Laid || p.second isa Opens || p.second isa Vector{Union{Nothing,PlainLine}}]
  empty!(e.flows)
  foreach(p -> e.flows[p.first] = p.second, kept)
  e
end

"The button under the words that say a file is binary. A click shows the file's bytes."
@def mutable struct HexButton <: SemanticUI end

describe(b::HexButton) = Box(height(30px), padding(14px, 0px), radius(6px), background(ishovered(b) ? colours.active : colours.hover),
                             label("View as hexadecimal", 13px))
cursor(::HexButton) = :hand
onkey(b::HexButton, ::KeyPress{Keys.mouse_left}) = (hex!(editor(b)); handled)

cursor(::FileView) = :arrow

"The one item of the page of a file that shows in a viewer"
file_item(e, b::Buffer) = begin
  v = node!(() -> FileView(path=b.path), e, (:fileview, b.path))
  # What covers the page's whole space isn't one of the page's items, so it has no height to learn
  b === e.buf && (page_covered(e) || html_shown(e) || term_shown(e) || chat_shown(e) || file_covers(e)) && return Item(1, 1, 0px, 1px, Live(v, 1px))
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(v)), (e.width, 9999px))
  high = concrete.height + 2LIVE_GAP
  Item(1, 1, 0px, high, Live(v, high))
end

# A file that you open is all that its page shows. So a model, a picture, a PDF file and a video cover the
# page's whole space in the window, under the top bar, as the page of an HTML file does. One in another
# page, like a model in a gallery, has the room that the page gives it, and so does a part of another page.

"The viewer that covers the page's space with the model in the file that shows, or nothing if the page shows no file that can be read as a model"
model_part(e) = begin
  b = e.buf
  (b.view == :file && hosted(e) === nothing && lowercase(splitext(b.path)[2]) in MODELS && isfile(b.path)) || return nothing
  m = node!(() -> STLViewer(path=b.path, fill=true), e, (:model_page, b.path))
  load!(m) isa Mesh || return nothing
  # The top bar says how big the file is and when it changed, as it does for a table
  b.about = file_about(b.path)
  m
end

"True when the page shows a model's file as the model, which covers the page's whole space"
model_shown(e) = model_part(e) !== nothing

"What the top bar says of a file that's only shown: how big it is and when it changed"
file_about(path) = bytes(filesize(path)) * "  ·  Changed " * Libc.strftime("%-d %b %Y, %H:%M", mtime(path))

"What of the file at `path` fills its own page as a picture does: a picture, or the first page of a PDF file. Nothing for any other file."
file_fill(path) = begin
  ext = lowercase(splitext(path)[2])
  if ext in PICTURES || ext in MAC_PICTURES
    key = picture_key(path)
    key === nothing ? nothing : (:picture, key)
  elseif Sys.isapple() && ext == ".pdf"
    pdf_pages(path) > 0 ? (:pdf, path, 1) : nothing
  end
end

"""
The view that covers the page's space with the picture or the PDF file that
shows, or nothing if the page shows no such file. It's what fills the window
for a picture in a document, without the room round it and the button that
closes it: the picture fits the page's space, a pinch or a scroll with ⌘ makes
it bigger, a drag moves it, and a PDF file turns its pages. Its bar of buttons
shows while the mouse is over the foot of the page.
"""
file_zoom(e) = begin
  b = e.buf
  (b.view == :file && hosted(e) === nothing && isfile(b.path)) || return nothing
  v = get(e.nodes, (:file_zoom, b.path), nothing)
  # The file is looked at again only when it changes, since this is asked several times in each frame
  read = mtime(b.path)
  if v === nothing || v.read != read
    what = file_fill(b.path)
    what === nothing && return nothing
    v = node!(() -> ZoomView(bare=true), e, (:file_zoom, b.path))
    v.read = read
    if !same_what(v.what, what)
      v.what, v.path, v.zoom, v.fits, v.grab = what, b.path, 0.0, true, nothing
      what[1] == :pdf && ((v.page, v.pages) = (1, max(1, pdf_pages(b.path))))
    end
  end
  about = v.what[1] == :pdf ? "$(v.pages) page$(v.pages == 1 ? "" : "s")" : (s = subject_size(v); s === nothing ? "" : "$(round(Int, s[1])) × $(round(Int, s[2]))")
  b.about = (isempty(about) ? "" : about * "  ·  ") * file_about(b.path)
  v
end

"The player that covers the page's space with the video in the file that shows, or nothing if the page shows no video"
video_part(e) = begin
  b = e.buf
  (b.view == :file && hosted(e) === nothing && Sys.isapple() && lowercase(splitext(b.path)[2]) in VIDEOS && isfile(b.path)) || return nothing
  p = node!(() -> VideoPlayer(path=b.path), e, (:video_page, b.path))
  b.about = file_about(b.path)
  p
end

"True when the file that shows covers the page's whole space: a model, a picture, a PDF file or a video"
file_covers(e) = model_shown(e) || file_zoom(e) !== nothing || video_part(e) !== nothing

"""
Do what the key `K` does to the picture, the PDF file or the video that covers
a file's own page. It's `handled`, or nothing for a key that the page takes as
it always does. The keys that change the size of a page's text change the size
of a picture, and the arrows turn the pages of a PDF file.
"""
file_key!(e, K, w, command) = begin
  v = file_zoom(e)
  if v !== nothing
    command == :bigger && return zoom_by!(v, ZOOM_STEP, view_middle(v)...)
    command == :smaller && return zoom_by!(v, 1 / ZOOM_STEP, view_middle(v)...)
    command == :usual_size && return fit_now!(v)
    unmodified(w) && v.what[1] == :pdf && K in (Keys.left, Keys.right, Keys.up, Keys.down) && return turn!(v, K in (Keys.left, Keys.up) ? -1 : 1)
    return nothing
  end
  p = video_part(e)
  (p === nothing || !unmodified(w)) && return nothing
  # F makes the video fill the screen. Space plays and stops it, and ← and → go back and on in it.
  K == Keys.f && return screen_video!(e, p)
  K in (Keys.space, Keys.left, Keys.right) ? onkey(p, KeyPress{K}(0, w)) : nothing
end

"The picture kept under `key`, `wide` across, and no wider than the page's text"
fitted(e, key, wide; line=false) = begin
  source = image_source(key)
  w = min(e.width, px(wide))
  h = w * source.height / source.width
  line ? Image(key, fixed(w), height(h), radius(3px), border(1px, :solid, colours.line)) : Image(key, fixed(w), height(h), radius(4px))
end

"""
What shows the file of `v`, or nothing if Ladder has nothing that shows it.
`note(words)` adds words to the line that says how big the file is.
"""
viewer(v::FileView, e, note) = begin
  path = v.path
  ext = lowercase(splitext(path)[2])
  mac = Sys.isapple()
  _, h = window_size(e)
  room = clamp(h - above_page(e) - PAGE_TOP - 150px, 240px, 800px)   # how tall a model or a video shows
  # What's made for the file is kept, so the model stays as it was turned and the file plays on
  made(make, T) = v.viewer isa T ? v.viewer : (v.viewer = own!(v, make()))
  if ext in PICTURES || ext in MAC_PICTURES
    key = picture_key(path)
    key === nothing && return nothing
    source = image_source(key)
    # A picture of pixels is a pixel to the px. One that macOS read, like an SVG, is the size that macOS says it is.
    size = something(natural(key), (source.width, source.height))
    note("$(round(Int, size[1])) × $(round(Int, size[2]))")
    return fillable(v, (:picture, key), fitted(e, key, size[1]))
  elseif ext in MODELS
    m = made(() -> STLViewer(path=path), STLViewer)
    zoomed_node(e, m) || (m.height = room)   # one that fills the window is as tall as the window
    return load!(m) isa Mesh ? fillable(v, (:node, m), m, wide=:grow) : nothing
  elseif mac && ext in SOUNDS
    return made(() -> AudioPlayer(path=path), AudioPlayer)
  elseif mac && ext in VIDEOS
    p = made(() -> VideoPlayer(path=path), VideoPlayer)
    zoomed_node(e, p) || (p.height = room)
    return fillable(v, (:node, p), p, wide=video_wide(p))
  elseif mac && ext == ".pdf"
    p = made(() -> Pages(path=path, count=pdf_pages(path)), Pages)
    p.count == 0 && return nothing
    p.wide = e.width
    return p
  elseif ext in JSONS
    root = json_of(path)
    root === nothing && return nothing
    t = made(() -> JSONTree(path=path), JSONTree)
    t.root === root || plant!(t, root)   # a file that changed shows afresh
    json_holder(root) && note(json_count(root))
    return t
  elseif ext in TABLES
    return sheet_view(v, e, note)
  end
  # The picture that the Finder shows: the first page of a Word file, the letters of a font,
  # and what it has for many kinds of file that have no viewer here
  key = thumbnail(path)
  key === nothing && return nothing
  fillable(v, (:picture, key), fitted(e, key, image_source(key).width / 2, line=ext in DOCUMENTS))   # the picture has two pixels to the px
end

describe(v::FileView) = begin
  e = editor(v)
  # A Text on its own would take the whole width and start at the left, so each is in a box that the column centres
  words(parts) = Column(width(grow=grow), padding(90px, 0px, 30px, 0px), child_gap=10px, [p isa Text ? Box(p) : p for p in parts]...)
  # A kind of folder can show a file that it holds, or itself, its own way
  o = e.buf.path == v.path ? page_object(e) : object(e, v.path)
  own = o === nothing ? nothing : with_theme(() -> page_view(e, o), component_theme(e.zoom))
  own === nothing || return Box(width(grow=grow), Alignment.Start, own)
  # A folder with no page of its own shows its folders and files as the sidebar does
  isdir(v.path) && return Box(width(grow=grow), Alignment.Start, node!(() -> FolderPage(path=v.path), e, (:folder_page, v.path)))
  isfile(v.path) || return words((label("$(basename(v.path)) isn't there any more", 15px),))
  about = bytes(filesize(v.path)) * "  ·  Changed " * Libc.strftime("%-d %b %Y, %H:%M", mtime(v.path))
  # An empty CSV file that the page changes shows a table to write in
  filesize(v.path) == 0 && !(e.buf.path == v.path && table_text(e.buf)) &&
    return words((label("$(basename(v.path)) is empty", 15px), label(about, 12px, color=colours.dim)))
  # A model and a player are components, so they get the colours and the text size that a live block gives them
  with_theme(component_theme(e.zoom)) do
    content = try
      viewer(v, e, more -> (about *= "  ·  " * more))
    catch
      nothing
    end
    line = label(about, 12px, color=colours.dim)
    if content === nothing
      # Nothing shows this file, so the page says what it is, and its bytes are a click away
      v.button === nothing && (v.button = own!(v, HexButton()))
      return words((Icon("file-earmark-binary", size=34px, color=colours.faint), label("$(basename(v.path)) is a binary file", 15px),
                    line, Box(height(4px)), v.button))
    end
    # A table and the tree of a JSON file can be long, so what's said about them is in the top bar, where it
    # stays in sight while they scroll. Anything else has the line about it under it.
    if lowercase(splitext(v.path)[2]) in (TABLES..., JSONS...)
      e.buf.path == v.path && (e.buf.about = about)
      return Box(width(grow=grow), Alignment.Start, content)
    end
    Column(width(grow=grow), child_gap=10px, content, Box(line))
  end
end
