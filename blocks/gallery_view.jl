# The view of a `gallery` block: a gallery of a folder's files
#
# A code block in the language `gallery` shows the files and the folders of a
# folder as a grid of small squares. gallery.jl says how the block is written.
# The square of a picture or a video shows the middle of its picture, cut to
# fit. The square of any other file shows the picture that the Finder has for
# it, like the first page of a PDF file, with the file's name under it. A
# folder shows the Finder's icon for it. The top of the block says how many
# files there are and where they are. A button there changes the size of the
# squares, and writes the size into the block.
#
#   - A click on a picture, a PDF file, a video or a 3D model makes it fill
#     the window, as the same file in the text does. There, ← and → go to the
#     file before it and the next one of the gallery that fill the window too,
#     ↑ and ↓ turn the pages of a PDF file, and Esc puts the page back.
#   - A click on a folder or another kind of file opens it, as a link to it
#     does.
#   - While a file fills the window, the bar under it says where it is in the
#     gallery, like "2 of 6", and the name of the file. A button on each side
#     of those words goes to the file before and to the next one. While the
#     mouse is near the left or the right edge of the window, a large arrow
#     shows there that does the same.
#   - The mouse over a square shows the name of its file.
#   - A file or a folder that's dropped on the gallery from the Finder is
#     copied into the gallery's folder. A gallery that only lists its files
#     gets a line for it, and the file stays where it is.
#
# A big folder mustn't stop the window. macOS makes a small picture of each
# file, as it does for the Finder, and Ladder asks for a few of them in each
# frame. Only the rows of the grid that are in the window are built. The
# folder is read again every few seconds while the window is drawn.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe window_of handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect with_round_clip
@use "github.com/jkroso/UI.jl/Interface/image" image_source
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/STLViewer" STLViewer Mesh load!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" VideoPlayer
@use "../files/pictures" picture thumbnail finder_icon pdf_pages
@use "../html" escape
@use "../markdown" words
@use "./gallery" => Galleries
@use "../folders/folders" => Folders
@use Colors: RGBA
@use "../base" exports...
@use "../window/fill_view" exports...
@use "../files/file_view" exports...
@use "./sheet_view" exports...
@use "./live_view" exports...
@use "./schedule_view" exports...

export GALLERY, GALLERY_KINDS, GALLERY_EVERY, GALLERY_BUDGET, GALLERY_TOP, GALLERY_PAD, GALLERY_ROUND,
       GALLERY_EDGE, GALLERY_NEAR, GALLERY_NAME, GALLERY_INSET, GALLERY_LABEL, GALLERY_SIZES, GalleryThumb,
       item_at, small_mark, small, fills_square, small!, make_small!, rows_in_view, fills_window, item_fill,
       open_item!, show_item!, gallery_place, place_words, can_step, GalleryEdge, gallery_at, add_files!,
       gallery_html

const GALLERY = Galleries.GALLERY
const GALLERY_KINDS = (PICTURES..., MAC_PICTURES...)   # the ends of the names of the files that a gallery shows as pictures
const GALLERY_EVERY = 3        # seconds between two looks at the folder, while the window is drawn
const GALLERY_BUDGET = 0.012   # seconds of a frame that making small pictures can take. One is always made.
const GALLERY_TOP = 38px       # how tall the line at the top of a gallery is
const GALLERY_PAD = 12px       # between the edge of a gallery and its pictures
const GALLERY_ROUND = 6px      # how round the corners of a square are
const GALLERY_EDGE = 44px      # how big the arrow is at an edge of the window, while a picture fills the window
const GALLERY_NEAR = 140       # px: the mouse is this near an edge of the window when that edge's arrow shows
const GALLERY_NAME = 200       # px: the most room that the name of a file has in the bar under a picture
const GALLERY_INSET = 6px      # between the edge of a square and the picture and the name in it, where the picture doesn't fill the square
const GALLERY_LABEL = 14px     # how tall the name under such a picture is
"For each size of square: the icon of the button that changes the size, and what the button says"
const GALLERY_SIZES = (small=("grid-3x3-gap", "Small"), medium=("grid", "Medium"), large=("square", "Large"))
push!(BLOCK_ICONS, "images", "image", "grid-3x3-gap", "grid", "square")

"A square of a gallery: one file or folder"
@def mutable struct GalleryThumb <: SemanticUI
  of::Any = nothing
  i::Int = 0   # its place among the gallery's files
end

reread!(v::GalleryView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Galleries.gallery(lines)
  v.shown = nothing
  v
end

"True while the page is drawn for paper. `print_pdf` puts the caret on no line then."
on_paper(e) = e.buf.caret[1] == 0

"""
What the gallery shows: its files and folders, the lines that name nothing,
and why there's nothing to show. It leaves out the page that holds it. The
folder is read again after a few seconds, and after longer when reading it
takes long.
"""
found!(v::GalleryView) = begin
  e = editor(v)
  dir = docdir(e)
  key = (v.lines, dir)
  s = v.shown
  s !== nothing && s.key == key && time() < s.next && return s.found
  started = time()
  # The page itself isn't in its gallery, and nor is what you ignore
  found = Galleries.items(v.data, dir, pictures=GALLERY_KINDS, skip=(e.buf.path, Folders.ignored()...))
  v.shown = (key=key, next=time() + max(GALLERY_EVERY, 20 * (time() - started)), found=found)
  found
end

"Square `i` of the gallery: a file or a folder, or nothing when it has no such square"
item_at(v::GalleryView, i::Int) = get(found!(v).items, i, nothing)

"What the small picture of `p` is kept under: its file, when the file last changed, and how many pixels the squares need now"
small_mark(v::GalleryView, p) = (p.path, p.at, Galleries.pixels(num(v.side)))

"""
The small picture of `p`: its key, for drawing, and whether it fills the
square. It's nothing for a file that has no picture, and `missing` until it's made.
"""
small(v::GalleryView, p) = get(v.small, small_mark(v, p), missing)

"True when the picture of `p` fills its square: a picture's own, and the picture that macOS makes of a video"
fills_square(p) = p.kind == :picture || p.kind == :file && lowercase(splitext(p.path)[2]) in VIDEOS

"""
Make the small picture of `p`: the one that macOS makes for the Finder, like
the first page of a Pages document. A picture that macOS has none for shows
itself. A folder, and a file that has no picture, show the Finder's icon.
"""
small!(v::GalleryView, p) = begin
  mark = small_mark(v, p)
  key = thumbnail(p.path, mark[3])
  key === nothing && p.kind == :picture && (key = picture_key(p.path))
  fills = key !== nothing && fills_square(p)
  key === nothing && (key = finder_icon(p.path, mark[3]))
  v.small[mark] = key === nothing ? nothing : (key=key, fills=fills)
end

"""
Make the small pictures that the last frame had none for: as many as `budget`
seconds have room for, and one at the least. The next frame asks for the rest.
"""
make_small!(v::GalleryView; budget=GALLERY_BUDGET) = begin
  started = time()
  for p in v.wanted
    ismissing(small(v, p)) || continue
    small!(v, p)
    time() - started > budget && break
  end
  empty!(v.wanted)
  v
end

# In each frame, before the page is laid out, a gallery makes a few small pictures, so the window never waits long
block_tick!(v::GalleryView) = make_small!(v)

"""
The rows of the grid `g` that are in the window, and a few on each side of
them. On paper, every row shows.
"""
rows_in_view(v::GalleryView, g) = begin
  e = editor(v)
  on_paper(e) && return 1:g.rows
  _, h = window_size(e)
  k = findfirst(it -> it.content isa Live && it.content.node === v, e.layout)
  # A gallery that the page hasn't laid out yet is taken to be at the top of the window
  k === nothing && return Galleries.rows_between(0, num(h), g.rows, g.side)
  top = e.layout[k].top + LIVE_GAP + 1px + GALLERY_TOP   # of the grid, from the top of the page's text
  Galleries.rows_between(num(e.scroll.offset - PAGE_TOP - 200px - top), num(e.scroll.offset + h + 200px - top), g.rows, g.side)
end

describe(t::GalleryThumb) = begin
  v = t.of
  p = item_at(v, t.i)
  s = p === nothing ? missing : small(v, p)
  # A picture or a video fills its square, in `draw`
  (p === nothing || (s isa NamedTuple ? s.fills : ismissing(s) && fills_square(p))) &&
    return Box(fixed(v.side), height(v.side), radius(GALLERY_ROUND), name="Picture", background(colours.block))
  # Any other file has the whole of its picture in its square, with its name under it, as the Finder shows it
  wide, high = v.side - 2GALLERY_INSET, v.side - 2GALLERY_INSET - GALLERY_LABEL - 4px
  picture = if s isa NamedTuple
    image = image_source(s.key)
    _, _, w, h = Galleries.fit(image.width, image.height, num(wide), num(high))
    (Image(s.key, fixed(px(w)), height(px(h))),)
  elseif s === nothing
    # A file that has no picture at all has the icon of its kind
    (Icon(p.kind == :folder ? "folder" : file_icon(p.path), size=24px, color=colours.faint),)
  else
    ()   # its picture isn't made yet
  end
  Column(fixed(v.side), height(v.side), radius(GALLERY_ROUND), padding(GALLERY_INSET), child_gap=4px, Alignment.Center, name="Picture",
         background(colours.block),
    Box(fixed(wide), height(high), Alignment.Center, justify=Alignment.Center, picture...),
    Box(height(GALLERY_LABEL), Alignment.Center, label(elide(p.name, 11px, wide), 11px, color=colours.dim)))
end

# The square of a picture or a video shows the middle of its picture, cut to fit, with round corners
draw(ctx, size, ui::ConcreteRect, t::GalleryThumb) = begin
  v = t.of
  p = item_at(v, t.i)
  p === nothing && return
  s = small(v, p)
  left, top, wide, tall = num(ui.left), num(ui.top), num(ui.width), num(ui.height)
  if s isa NamedTuple && s.fills
    image = image_source(s.key)
    with_round_clip(ctx, ui.left, ui.top, ui.width, ui.height, GALLERY_ROUND) do
      paint_picture(ctx, image.raw, Galleries.crop(image.width, image.height), (left, top, wide, tall))
    end
    # A video has a mark that plays in its corner, so that it isn't taken for a picture
    if p.kind == :file
      r = 11.0
      x, y = left + 8 + r, top + tall - 8 - r
      disc(ctx, x, y, r, RGBA(0, 0, 0, 0.55))
      white = RGBA(1, 1, 1, 1)
      trace(ctx, [(x - 3.5, y - 5.5), (x + 5.5, y), (x - 3.5, y + 5.5)], white, 0.5; fill=white, closed=true)
    end
  end
  # The square under the mouse has a line round it
  ishovered(t) && round_box(ctx, left + 1, top + 1, wide - 2, tall - 2, num(GALLERY_ROUND) - 1; line=colours.accent, wide=2.0)
  nothing
end

cursor(::GalleryThumb) = :hand
cursor(::GalleryView) = :arrow

onmouse(t::GalleryThumb, ev::MouseMove) = begin
  p = item_at(t.of, t.i)
  p === nothing || show_tooltip!(ev.window, tip_label(p.name), t, placement=:bottom, gap=6px)
  nothing
end

onkey(t::GalleryThumb, ev::KeyPress{Keys.mouse_left}) = (hide_tooltip!(ev.window); open_item!(t.of, t.i))

"""
True when `p`, a square of the gallery, is of a kind that fills the window on
a click: a picture, a PDF file, a video or a 3D model. A picture whose square
has no picture of its own can't be read, so it doesn't. This reads no file, so
it's quick enough for each frame.
"""
fills_window(v::GalleryView, p) = begin
  ext = lowercase(splitext(p.path)[2])
  p.kind == :picture ? (s = small(v, p); ismissing(s) || s isa NamedTuple && s.fills) :
  p.kind == :file && (ext in MODELS || Sys.isapple() && (ext == ".pdf" || ext in VIDEOS))
end

"""
What fills the window for `p`, a square of the gallery: its picture, the
first page of its PDF file, the player of its video or the viewer of its 3D
model. It's nothing for a folder, a file of another kind, and a file that
can't be read as its kind. The gallery keeps one player and one viewer.
"""
item_fill(v::GalleryView, p) = begin
  if p.kind == :picture
    key = picture_key(p.path)
    return key === nothing ? nothing : (:picture, key)
  end
  fills_window(v, p) || return nothing
  ext = lowercase(splitext(p.path)[2])
  ext == ".pdf" && return pdf_pages(p.path) > 0 ? (:pdf, p.path, 1) : nothing
  if ext in VIDEOS
    old = get(v.parts, :player, nothing)
    old isa VideoPlayer && old.path == p.path && return (:node, old)
    delete!(v.parts, :player)
    return (:node, block_part!(() -> VideoPlayer(path=p.path, height=MODEL_HEIGHT), v, :player))
  end
  old = get(v.parts, :model, nothing)
  (old isa STLViewer && old.path == p.path) || delete!(v.parts, :model)
  m = block_part!(() -> STLViewer(path=p.path, height=MODEL_HEIGHT), v, :model)
  load!(m) isa Mesh ? (:node, m) : nothing
end

"""
Do what a click on square `i` of the gallery does. A picture, a PDF file, a
video or a 3D model fills the window. A folder and any other file open, as a
link to them does.
"""
open_item!(v::GalleryView, i::Int) = begin
  p = item_at(v, i)
  p === nothing && return handled
  what = item_fill(v, p)
  what === nothing || return show_item!(v, p, what)
  show_path!(editor(v), p.path)
  handled
end

"Make `what`, which shows `p` of the gallery, fill the window"
show_item!(v::GalleryView, p, what) = begin
  v.showing = p.path
  zoom_in!(editor(v), what, v)
end

"""
While a file of the gallery fills the window, go `by` files on: to the one
before it, or to the next one. A folder, and a file that doesn't fill the
window, are passed over. At the first file and the last, nothing changes.
"""
step!(v::GalleryView, by::Int) = begin
  items = found!(v).items
  i = something(findfirst(p -> p.path == v.showing, items), 0) + by
  while i in eachindex(items)
    what = item_fill(v, items[i])
    what === nothing || return show_item!(v, items[i], what)
    i += by
  end
  handled
end

"""
Where the file that fills the window is in its gallery: the gallery, the
file's place, how many files and folders the gallery has, and the name of the
file. It's nothing for what isn't from a gallery.
"""
gallery_place(z::ZoomView) = begin
  g = z.from
  (g isa GalleryView && z.what !== nothing) || return nothing
  items = found!(g).items
  i = findfirst(p -> p.path == g.showing, items)
  i === nothing ? nothing : (gallery=g, i=i, n=length(items), name=items[i].name)
end

"What the bar under a file of a gallery says of the file's place, like “2 of 6”"
place_words(at) = "$(at.i) of $(at.n)"

"""
True when the gallery has a file to show `by` files on from square `i`: one
before it, or one after it. A folder and a file that doesn't fill the window
don't count, because `step!` passes over them.
"""
can_step(v::GalleryView, i::Int, by::Int) = begin
  items = found!(v).items
  any(k -> fills_window(v, items[k]), by < 0 ? (1:i-1) : (i+1:length(items)))
end

"""
What the bar under a file of a gallery starts with: a button for the file
before, the file's place, a button for the next file, the file's name and a
line. The bar of anything else has none of them. In a window that's too
narrow for them all, the name goes first, and then the place.
"""
gallery_buttons(z::ZoomView; rest=281) = begin
  at = gallery_place(z)
  at === nothing && return ()
  g = at.gallery
  button(key, by, icon, tip) = begin
    b = part!(() -> PlanButton(of=g), z, (:button, key))
    # The view keeps its buttons, and the gallery can be another one of the page than when they were made
    b.of, b.action, b.icon, b.tip, b.off = g, (:step, by), icon, tip, !can_step(g, at.i, by)
    b
  end
  face = Face(SANS, "", 12px, colours.dim, false)
  # `rest` is how wide the rest of the bar is, with the two buttons here and the room on each side of it
  spare = num(window_size(editor(z))[1]) - rest
  place = place_words(at)
  placed = num(measure(face, place)) + 8
  room = min(spare - placed - 14, GALLERY_NAME)
  words(text) = label(text, 12px, color=colours.dim)
  (button(:before, -1, "chevron-left", "The file before  ←"),
   (spare >= placed ? (Box(Alignment.Center, padding(4px, 0px), words(place)),) : ())...,
   button(:next, 1, "chevron-right", "The next file  →"),
   (room >= 60 ? (Box(Alignment.Center, padding(6px, 0px), words(elide(at.name, 12px, px(room)))),) : ())...,
   rule())
end

"A large arrow at the left or the right edge of the window, while a file of a gallery fills it. A click goes to the file before, or to the next one."
@def mutable struct GalleryEdge <: SemanticUI
  of::Any = nothing   # the gallery
  by::Int = 1         # -1 for the file before, and 1 for the next one
end

describe(a::GalleryEdge) =
  Box(width(GALLERY_EDGE), height(GALLERY_EDGE), radius(GALLERY_EDGE / 2), Alignment.Center, justify=Alignment.Center, name="Button",
      background(ishovered(a) ? colours.hover : RGBA(colours.float, 0.85)), border(1px, :solid, colours.line),
    Icon(a.by < 0 ? "chevron-left" : "chevron-right", size=20px, color=colours.dim))

cursor(::GalleryEdge) = :hand
onkey(a::GalleryEdge, ::KeyPress{Keys.mouse_left}) = step!(a.of, a.by)

"""
The arrows at the left and the right edge of a file of a gallery that fills
the window, in the middle of the window's height. Each one shows while the
mouse is near its edge, and there's a file to go to. Anything else that fills
the window has none.
"""
gallery_edges(z::ZoomView) = begin
  at = gallery_place(z)
  w = window_of(z)
  (at === nothing || w === nothing) && return ()
  wide = num(window_size(editor(z))[1])
  x, y = num(w.mouse[1]), num(w.mouse[2])
  arrow(by) = begin
    near = y > num(bar_bottom(editor(z))) && (by < 0 ? x < GALLERY_NEAR : x > wide - GALLERY_NEAR)
    near && can_step(at.gallery, at.i, by) || return Box(width(GALLERY_EDGE))
    a = part!(() -> GalleryEdge(by=by), z, (:edge, by))
    a.of = at.gallery   # the view keeps its arrows, and the gallery can be another one of the page than when they were made
    a
  end
  (Row(width(grow=grow), height(grow=grow), Alignment.Center, padding(0px, 16px, BAR_ROOM, 16px), arrow(-1), Box(width(grow=grow)), arrow(1)),)
end

"""
Do what a button of a gallery does. The one at its top gives its squares the
next size, which goes into the block. The two under a file that fills the
window go to the file before it and to the next one.
"""
act!(v::GalleryView, action, w) = begin
  action isa Tuple && action[1] == :step && return step!(v, action[2])
  action == :size || return handled
  v.data.size = Galleries.next_size(v.data.size)
  # A page that can't be changed still shows the new size
  readonly(editor(v).buf) || write_block!(v, GALLERY, Galleries.written(v.data))
  handled
end

describe(v::GalleryView) = begin
  e = editor(v)
  found = found!(v)
  items = found.items
  paper = on_paper(e)
  with_theme(component_theme(e.zoom)) do
    lost = Galleries.lost_words(found.lost)
    isempty(items) && return Column(block_look()..., clip=true, name="Gallery", block_note(isempty(lost) ? found.problem : lost))
    icon, words = GALLERY_SIZES[v.data.size]
    bigger = lowercase(GALLERY_SIZES[Galleries.next_size(v.data.size)][2])
    top = Row(width(grow=grow), height(GALLERY_TOP), padding(0px, 6px, 0px, GALLERY_PAD), Alignment.Center, clip=true,
              Box(label(Galleries.summary(v.data, found), 12px, color=colours.dim)), Box(width(grow=grow)),
              (paper ? () : (block_button!(v, :size, :size, icon=icon, words=words, tip="Make the squares $bigger"),))...)
    g = Galleries.grid(length(items), num(e.width - 2px - 2GALLERY_PAD), v.data.size)
    v.side = px(g.side)
    rows = rows_in_view(v, g)
    places = [i for r in rows for i in Galleries.row_places(r, g.columns, length(items))]
    # On paper every square shows, so each small picture is made now. In the window, the next frames make them.
    paper && foreach(i -> ismissing(small(v, items[i])) && small!(v, items[i]), places)
    v.wanted = [items[i] for i in places if ismissing(small(v, items[i]))]
    isempty(v.wanted) || redraw_in!(v, 0)
    gap, step = px(Galleries.GAP), g.side + Galleries.GAP
    # The rows that aren't built leave their room empty, so the block is as tall as the whole grid
    above = isempty(rows) ? px(Galleries.tall(g.rows, g.side)) : px((first(rows) - 1) * step) - gap
    below = isempty(rows) ? 0px : px((g.rows - last(rows)) * step) - gap
    grid = Column(width(grow=grow), Alignment.Start, padding(0px, GALLERY_PAD, GALLERY_PAD, GALLERY_PAD), child_gap=gap,
      (above > 0px ? (Box(width(grow=grow), height(above)),) : ())...,
      [Row(height(v.side), child_gap=gap, Alignment.Start,
           [block_part!(() -> GalleryThumb(of=v, i=i), v, (:thumb, i)) for i in Galleries.row_places(r, g.columns, length(items))]...)
       for r in rows]...,
      (below > 0px ? (Box(width(grow=grow), height(below)),) : ())...)
    # A line of the block that names nothing is named under the grid
    note = isempty(lost) ? () : (Row(width(grow=grow), padding(0px, GALLERY_PAD, GALLERY_PAD, GALLERY_PAD), Alignment.Start, clip=true,
                                     Box(width(grow=grow), Text(lost, size=12px, family=SANS, color=colours.dim, wrap=WrapMode.words))),)
    Column(block_look()..., clip=true, name="Gallery", top, grid, note...)
  end
end

"The gallery under the mouse, or nothing. Only a gallery that the page shows now is where it was last drawn."
gallery_at(e, w) = begin
  x, y = w.mouse
  for it in view(e.layout, intersect(e.shown, eachindex(e.layout)))
    node = it.content isa Live ? it.content.node : nothing
    node isa GalleryView || continue
    r = rect(node)
    r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height && return node
  end
  nothing
end

"""
Add the files and the folders at `paths` to the gallery, as a drop on it
does. Each one is copied into the gallery's folder. A gallery that only lists
its files gets a line for each one, and the files stay where they are. It's
true when the gallery took a file or a folder.
"""
add_files!(v::GalleryView, paths) = begin
  e = editor(v)
  dir = docdir(e)
  new = [String(rstrip(String(p), '/')) for p in paths]
  filter!(ispath, new)
  (isempty(new) || readonly(e.buf) || !isdir(dir)) && return false
  to = Galleries.folder(v.data, dir)
  if to === nothing
    append!(v.data.listed, unique(name for name in (named(e, p) for p in new) if !(name in v.data.listed)))
    write_block!(v, GALLERY, Galleries.written(v.data))
  else
    foreach(p -> Galleries.keep(to, p), new)
    list_files!(e)   # the sidebar lists the new files too
  end
  v.shown = nothing
  true
end

"""
The gallery as HTML: a grid of squares, each named as a link in the text names
its file. A picture shows itself. Any other file or folder is a link with its
name in it.
"""
gallery_html(e, v::GalleryView) = begin
  found = found!(v)
  isempty(found.items) && return "<p>$(escape(isempty(found.lost) ? found.problem : Galleries.lost_words(found.lost)))</p>"
  shape = "aspect-ratio: 1; border-radius: $(round(Int, num(GALLERY_ROUND)))px"
  look = "width: 100%; object-fit: cover; $shape"
  box = "display: flex; align-items: flex-end; justify-content: center; box-sizing: border-box; padding: 6px; $shape; " *
        "background: rgba(128, 128, 128, 0.12); color: inherit; text-decoration: none; font-size: 12px; overflow: hidden; overflow-wrap: anywhere"
  square(p) = begin
    src = escape(escaped(named(e, p.path)))
    p.kind == :picture ? "<img src=\"$src\" alt=\"$(escape(splitext(p.name)[1]))\" loading=\"lazy\" style=\"$look\">" :
                         "<a href=\"$src\" style=\"$box\">$(escape(p.name))</a>"
  end
  squares = join((square(p) for p in found.items), "\n")
  "<div class=\"gallery\" style=\"display: grid; grid-template-columns: repeat(auto-fill, minmax($(Galleries.SIDES[v.data.size])px, 1fr)); gap: $(Galleries.GAP)px\">\n$squares\n</div>"
end

BLOCKS[GALLERY] = GalleryView
block_name(::Type{GalleryView}) = "Gallery"
block_icon(::Type{GalleryView}) = "images"
block_insert(::Type{GalleryView}) = ("Gallery", ["```$GALLERY", "```", "", ""], (4, 0))
block_html(e, v::GalleryView) = gallery_html(e, v)
