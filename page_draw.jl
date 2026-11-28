# Drawing the page's text: its lines, the selection, the boxes of to-do items and the guides of a block

@use "github.com/jkroso/MiniFB.jl/skia" sk_color
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" WrapMode with_theme describe reuse! window_of
@use "github.com/jkroso/UI.jl/Interface/draw" cursor
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./markdown" Kind Line callout
@use "./markdown" COMMENT
@use "./highlight" tokens
@use "./sheet" shown
@use Colors: RGBA
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./takeoff_view" exports...
@use "./julia_levels" exports...
@use "./sheet_view" exports...
@use "./columns_view" exports...
@use "./long_file" exports...
@use "./timelog_view" exports...
@use "./webpage_view" exports...
@use "./terminal_view" exports...
@use "./slides_view" exports...
@use "./git_page" exports...
@use "./code_nav" exports...
@use "./page_extras" exports...
@use "./agent/pane" exports...
@use "./drag_number" exports...
@use "./givers" exports...
@use "./page_mouse" exports...
@use "./caret_glide" exports...
@use "./page_layout" exports...
@use "./tabs" exports...
@use "./transclusion" exports...

export SELECTION_RADIUS, blocktype, corners, guide_under, nofile_view, rounded

# --- drawing the text -----------------------------------------------------------------

"The box of a to-do item: empty, or filled and ticked when the item is done"
todo_box(seg::Seg) = begin
  side = px(round(num(seg.face.size) * 0.82))
  box = seg.text == TODO_DONE ?
    Box(fixed(side), height(side), radius(side * 0.22), Alignment.Center, justify=Alignment.Center, background(colours.accent),
        Icon("check", size=side * 0.9, color=colours.bg)) :
    Box(fixed(side), height(side), radius(side * 0.22), border(1.5px, :solid, colours.marker))
  Box(fixed(seg.w), Alignment.Start, box)
end

describe(seg::Seg) = begin
  # What inline code made is drawn in place of the code
  seg.node === nothing || return Box(fixed(seg.w), Alignment.Start, geometry(seg.node.node))
  isbox(seg) && return todo_box(seg)
  f = seg.face
  # A character that the font lacks, like the raised minus of yr⁻¹ in Charter, is in a font that has it
  t = hasall(f, seg.text) ? Text(seg.text, size=f.size, family=f.family, subfamily=f.style, color=f.color, wrap=WrapMode.none) :
                            Row(Alignment.Start, spared(seg.text, f)...)
  # The number of a footnote is at the top of a box as tall as the text beside it, so it sits high in the line
  seg.atomic && startswith(seg.link, '^') && !endswith(seg.text, ' ') && return Box(fixed(seg.w), height(f.size * 1.9), Alignment.Start, t)
  # ==Words== have a highlighter's colour behind them
  f.highlit && !f.chip && return Box(fixed(seg.w), Alignment.Start, radius(2px), background(highlighter()), t)
  # A Text on its own would take a share of the spare room in its row
  f.chip || return Box(fixed(seg.w), Alignment.Start, t)
  isempty(f.lang) || (t = Row(Alignment.Start, [part for tok in tokens(seg.text, f.lang) for part in coloured(tok, f)]...))
  Box(fixed(seg.w), height(f.size * 1.5), padding(CHIP_X, 0px), radius(4px), background(colours.chip), border(1px, :solid, colours.chip_line), t)
end

"""
One part of a line of code in a chip, in the colour of its kind, as the parts
of a row. Each is as wide as its text measures, so the caret lines up with it.
"""
coloured(tok, f::Face) =
  spared(tok.text, Face(f, color=tok.kind == :plain ? f.color : getfield(colours, tok.kind), style=tok.kind == :comment ? codeslant() : f.style))

"The lines of a Flow, as rows of text. `edge` is the width of a border on its left."
rows(f::Flow, edge=0px) =
  [Row(width(grow=grow), height(vl.high), padding(0px, 0px, 0px, vl.x - edge), clip=true, map(describe, vl.segs)...) for vl in f.lines]

describe(e::Editor, it::Item) = gone_under(e, it, describe(e, it, it.content))

describe(e::Editor, it::Item, f::Flow) = begin
  f = in_colour(e, it, f)   # a line of a file gets the colours of its code here
  k = f.kind
  if k == Kind.rule && !f.raw
    return Box(width(grow=grow), height(tall(f)), Box(width(grow=grow), height(1px), background(colours.line)))
  end
  edge = k == Kind.blockquote ? 3px : 0px
  col = Column(width(grow=grow), Alignment.Start, padding(f.above, 0px, f.below, 0px), rows(f, edge)...)
  if (k == Kind.code || k == Kind.fence) && !(1 <= it.first <= length(e.buf.lines) && kinds(e.buf)[it.first].lang == COMMENT)
    col.background = background(colours.block)
  elseif k == Kind.blockquote
    # A callout has its kind's colour down its left, and a little of that colour behind it
    kind = 1 <= it.first <= length(e.buf.lines) ? callout(kinds(e.buf)[it.first]) : ""
    col.border = border(edge, :solid, isempty(kind) ? colours.line : callout_colour(kind))[:left]
    isempty(kind) || (col.background = background(callout_tint(kind)))
  end
  col
end

describe(e::Editor, it::Item, g::Grid) = begin
  isspread(g) && return spreadsheet(e, it, g)
  line = border(1px, :solid, colours.line; between=true)
  # Its corners are round, as a chart's are
  table = Column(width(grow=grow), Alignment.Start, line, radius(BLOCK_ROUND), name="Table",
    [Row(width(grow=grow), height(g.heights[r]), Alignment.Start, line[:between], inner_round(r, length(g.rows)),
         background(r == 1 ? colours.head : iseven(r) ? colours.bg : colours.stripe),
       [Column(fixed(g.widths[c]), height(grow=grow), Alignment.Start, justify=Alignment.Center, rows(g.flows[r][c])...)
        for c in eachindex(g.widths)]...)
     for r in eachindex(g.rows)]...)
  Box(width(grow=grow), padding(0px, TABLE_GAP), table)
end

describe(e::Editor, it::Item, l::Live) = begin
  # In a part of this page that another page shows, a live block is only shown: a cover over it takes its clicks.
  # What an agent says is shown by the window's page too, but its blocks take the mouse as a page's do: a chart shows its
  # buttons while the mouse is on it.
  inner = hosted(e) === nothing || l.node isa Transclusion || is_reply(e.buf.path) ? geometry(l.node) :
    Stack(width(grow=grow), Alignment.Start, geometry(l.node), live_cover(e, it))
  Box(width(grow=grow), height(l.tall), Alignment.Start, padding(0px, LIVE_GAP), inner)
end

"The kind of block that an item is part of, or nothing for a blank line"
blocktype(it::Item) = begin
  c = it.content
  c isa Grid && return Table
  c isa Sheet && return SheetBlock
  c isa Live ? LiveBlock : blocktype(c.kind)
end

blocktype(k::Kind) =
  k == Kind.paragraph ? Paragraph : k == Kind.heading ? Heading : k in (Kind.bullet, Kind.ordered, Kind.todo) ? List :
  k == Kind.blockquote ? Quote : k in (Kind.code, Kind.fence) ? CodeBlock : k == Kind.table ? Table :
  k == Kind.rule ? Rule : nothing

"The kind of block that line `i` is in. The keys that edit the text do different things in different blocks."
block(b::Buffer, i::Int) = blocktype(kinds(b)[i].kind)

"The items as the nodes of the document: one for each paragraph, list, table and so on"
blocks(d::Document, items) = begin
  ks = kinds(editor(d).buf)
  out, group, T = Any[], Item[], nothing
  close() = begin
    isempty(group) && return
    T === nothing ? append!(out, group) : push!(out, own!(d, T(first=group[1].first, last=group[end].last, items=copy(group))))
    empty!(group)
  end
  for it in items
    U = blocktype(it)
    # A heading, a rule, a table and a live block each stand alone, and a ``` line that opens a block starts a new one
    alone = U in (Heading, Rule, LiveBlock, SheetBlock) || it.content isa Grid || (U === CodeBlock && ks[it.first].kind == Kind.fence && ks[it.first].level == 0)
    (U !== T || alone) && close()
    T = U
    push!(group, it)
  end
  close()
  out
end

describe(b::Block) = Column(width(grow=grow), Alignment.Start, [describe(editor(b), it) for it in b.items]...)

describe(d::Document) = begin
  e = editor(d)
  items = e.layout
  total = isempty(items) ? 0px : lowest(e, items)
  _, h = window_size(e)
  # Only the lines on screen, and a few either side, are built
  from, to = e.scroll.offset - PAGE_TOP - 200px, e.scroll.offset + h + 200px
  lo = something(findfirst(it -> it.top + it.tall >= from, items), length(items))
  hi = something(findlast(it -> it.top <= to, items), lo)
  # A part of this page that another page shows is built whole. That page's own scroll says what's on screen.
  hosted(e) === nothing || ((lo, hi) = (1, length(items)))
  lo, hi = whole_groups(e, items, lo, hi)   # a group of columns is built whole
  e.shown = lo:hi
  # Each row of text cuts off what's past its end, so long lines that don't wrap need a page as wide as the longest
  Column(fixed(wraps(e) ? e.width : max(e.width, e.reach + SIDE_ROOM)), Alignment.Start, name="Document",
    gone_over(e, items, lo)...,
    page_parts(d, e, items[lo:hi])...,
    spacer(total - lowest(e, view(items, lo:hi))))
end

# With ⌘ and no other key held, a click on a link opens it, so the mouse shows a hand there. In a page
# that's never changed, a click on a link opens it with no key held.
cursor(d::Document) = begin
  e = editor(d)
  e.buf.view == :file && return :arrow   # a viewer has no text to select
  slideshow(e) === nothing || return slide_cursor(e)   # nor has a slide
  w = window_of(e)
  w === nothing && return :ibeam
  # A click on a to-do item's box ticks it
  todo_at(e, w.mouse) === nothing || return :hand
  # A drag on what a number comes to changes the number
  (haskey(e.nodes, :scrub) || scrub_at(e, w.mouse) !== nothing) && return :resize_x
  # A click on the value of a name goes to where the page gives the name its value
  unmodified(w) && giver_at(e, w.mouse) !== nothing && return :hand
  # With ⌘ held, a click on a name of Julia code goes to where the name is defined. Julia compiles definition only when ⌘ is first held.
  # ⌘ with another key held, like ⇧ or ⌃, does neither, so the mouse isn't a hand.
  cmd = only_held(w, Keys.cmd)
  cmd && link_at(e, w.mouse) === nothing && Base.invokelatest(definition, e, locate(e, w.mouse)) !== nothing && return :hand
  (cmd && link_at(e, w.mouse) !== nothing) || (follows_links(e.buf) && unmodified(w) && link_on(e, w.mouse) !== nothing) ? :hand : :ibeam
end

"""
The room under the last line of the page. A code file scrolls on until its last
lines are at the top of the window, so a box that opens under them has room to
show. A kind of folder whose own page has no text to type at its end can have
less: see `page_bottom(e, o)`.
"""
page_bottom(e) = numbered(e.buf) ? max(PAGE_BOTTOM, e.scroll.viewport - CODE_END) : something(page_bottom(e, page_object(e)), PAGE_BOTTOM)

"The room under the page that `page_view` gives for `o`, or nothing for a page's own room"
page_bottom(e, o) = nothing

describe(p::Page) = begin
  e = editor(p)
  nofile(e) && return nofile_view(e)
  # A kind of folder or of file can cover the page's whole space, as a desktop does with its wallpaper
  cover = page_cover(e)
  cover === nothing || return cover
  # An HTML file at its highest level covers it with the page that its HTML makes, as a browser's window would show it
  html_shown(e) && return Box(width(grow=grow), height(grow=grow), Alignment.Start, html_part(e))
  # A terminal's file covers it with the terminal
  term_shown(e) && return Box(width(grow=grow), height(grow=grow), Alignment.Start, term_part(e))
  # A session's file covers it with what you and the agent said
  chat_shown(e) && return Box(width(grow=grow), height(grow=grow), Alignment.Start, chat_part(e))
  # A model's file covers it with the model, which is a component, so it gets a live block's colours and text size
  model = model_part(e)
  model === nothing || return with_theme(() -> Box(width(grow=grow), height(grow=grow), Alignment.Start, model), component_theme(e.zoom))
  # A picture and a PDF file fit it, and can be made bigger and moved
  shown = file_zoom(e)
  shown === nothing || return Box(width(grow=grow), height(grow=grow), Alignment.Start, shown)
  # A video has all of it, with black round its picture and its controls over the foot of the picture, as when it fills a
  # screen. While it does fill the screen, it's there and not here.
  video = video_part(e)
  if video !== nothing
    zoomed_node(e, video) && return Box(width(grow=grow), height(grow=grow), background(RGBA(0, 0, 0, 1)))
    video.screen, video.height = true, page_room(e)[2]
    return with_theme(() -> Box(width(grow=grow), height(grow=grow), Alignment.Start, background(RGBA(0, 0, 0, 1)), video), component_theme(e.zoom))
  end
  # Long lines that don't wrap go on to the right edge of the window. The text moves left as the page
  # scrolls sideways. None of it shows past the edges of the page, and the numbers of the lines go over it.
  # A kind of folder can show something under the text of each page that it holds
  foot = page_foot(e)
  page = wraps(e) ?
    Row(width(grow=grow), Alignment.Start, justify=numbered(e.buf) ? Alignment.Start : Alignment.Center,
        padding(page_top(e), page_x(e), page_bottom(e), page_x(e) + gutter(e)),
      with_comments(e, foot === nothing ? node!(Document, e, :document) : Column(Alignment.Start, node!(Document, e, :document), foot))) :
    Row(width(grow=grow), Alignment.Start, padding(page_top(e), 0px, page_bottom(e), PAGE_X + gutter(e)), clip_x=true,
      Box(Alignment.Start, offset_x=-sideways(e), node!(Document, e, :document)))
  reuse!(e.scroll, guide_under(e, page))
end

"What the page shows in a window with no file: the keys that open a file and that close the window, or the tab while a tab is open"
nofile_view(e) = begin
  open_keys, close_keys = strip(hint(e, :open)), strip(hint(e, :close))
  Box(width(grow=grow), height(grow=grow),
    Column(child_gap=8px,
      Box(label("No file is open", 15px, color=colours.dim)),
      (isempty(open_keys) ? () : (Box(label("$open_keys finds a file", 13px, color=colours.faint)),))...,
      (isempty(close_keys) ? () : (Box(label("$close_keys closes the $(new_tab(e) || !isempty(tabs(e)) ? "tab" : "window")", 13px, color=colours.faint)),))...))
end

"""
Put a faint line down a file of code, under the text of `page`, after the
number of characters that the settings page chooses. It moves with the text
when the page scrolls sideways.
"""
guide_under(e, page) = begin
  (e.guide > 0 && numbered(e.buf)) || return page
  x = PAGE_X + gutter(e) + measure(face(e, Line(Kind.code, 0, 0, "")), "0") * e.guide - sideways(e)
  Stack(width(grow=grow), Alignment.Start,
    Box(fixed(1px), height(grow=grow), background(colours.line), offset_x=x),
    page)
end

"The part of line `i` that's selected, as columns, and whether the selection goes on past it"
selected(b::Buffer, i::Int) = begin
  lo, hi = selection(b)
  (lo[1] <= i <= hi[1] && lo != hi) || return nothing
  (i == lo[1] ? lo[2] : 0, i == hi[1] ? hi[2] : length(b.lines[i]), i < hi[1])
end

"""
The boxes that cover the selected part of each line of `f`, whose top left
corner is at (x, y). The first and last boxes take in the space above and below
the lines, so the boxes of one line of the document meet those of the next.
With `margin`, a box that starts at the start of its line also takes in the
space to the left of the text, like the inset of a code block. That's for a
line that the selection came into from the line above: it keeps the left edge
of the selection straight from one kind of line to the next. The line that the
selection starts in has no `margin`, so its box starts where its text does. A
selection that's all in one code block has no `margin` on any line. See `within_code`.
"""
marks(f::Flow, x, y, (from, to, more); margin=true, edge=0px) = begin
  out = Rect[]
  n = length(f.lines)
  for (k, vl) in enumerate(f.lines)
    (from <= vl.to && to >= vl.from) || continue
    # `edge` is the left edge of the line's column of the page, where the space to the left of its text starts
    # A selection from the end of inline code starts after its last words, which can start the line
    starts = from > vl.from || (from == vl.from && !isempty(vl.segs) && later_word(first(vl.segs)))
    x1 = starts ? xcol(vl, from) : margin ? edge : vl.x
    x2 = xcol(vl, min(to, vl.to))
    # A little extra shows that the end of the line is selected too
    (to > vl.to || (more && k == n)) && (x2 += 7px)
    # A line with none of its text selected has no box, not even over its margin
    x2 > max(x1, vl.x) || continue
    top = k == 1 ? 0px : line_top(f, k)
    bottom = line_top(f, k) + vl.high + (k == n ? f.below : 0px)
    push!(out, (num(x + x1), num(y + top), num(x + x2), num(y + bottom)))
  end
  out
end

const SELECTION_RADIUS = 4.0

"""
Fill the selection. Boxes that sit on top of each other are joined into one
shape, and every corner of that shape is rounded, the ones that point in as
well as the ones that point out.
"""
fill_selection(ctx, rects::Vector{Rect}) = begin
  isempty(rects) && return
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  Skia.sk_paint_set_color(paint, sk_color(colours.select))
  from = 1
  for i in 2:length(rects)+1
    # A box joins the one above it when they touch and share some width
    joined = i <= length(rects) && abs(rects[i][2] - rects[i-1][4]) < 1 &&
             rects[i][1] < rects[i-1][3] && rects[i][3] > rects[i-1][1]
    joined && continue
    outline = rounded(corners(rects[from:i-1]), SELECTION_RADIUS)
    Skia.sk_canvas_draw_path(ctx, outline, paint)
    Skia.sk_path_delete(outline)
    from = i
  end
  Skia.sk_paint_delete(paint)
end

"The corners of the shape made by a stack of boxes: down its right side, then back up its left"
corners(rects) = begin
  points = NTuple{2,Float64}[]
  add(p) = (isempty(points) || points[end] != p) && push!(points, p)
  top = rects[1][2]
  for (l, t, r, b) in rects
    add((r, top)); add((r, b))
    top = b
  end
  for (i, (l, t, r, b)) in Iterators.reverse(enumerate(rects))
    add((l, b)); add((l, i == 1 ? t : rects[i-1][4]))
  end
  points
end

"A Skia path around `points`, with each corner rounded by up to `radius`"
rounded(points, radius) = begin
  path = Skia.sk_path_new()
  n = length(points)
  for i in 1:n
    before, corner, after = points[mod1(i - 1, n)], points[i], points[mod1(i + 1, n)]
    d1, d2 = hypot((before .- corner)...), hypot((after .- corner)...)
    # A short edge has room for less of a curve at each end
    r = min(radius, d1 / 2, d2 / 2)
    a = corner .+ (before .- corner) .* (r / max(d1, 1e-6))
    b = corner .+ (after .- corner) .* (r / max(d2, 1e-6))
    i == 1 ? Skia.sk_path_move_to(path, Float32(a[1]), Float32(a[2])) : Skia.sk_path_line_to(path, Float32(a[1]), Float32(a[2]))
    # A conic with this weight is a quarter of a circle
    Skia.sk_path_conic_to(path, Float32(corner[1]), Float32(corner[2]), Float32(b[1]), Float32(b[2]), Float32(sqrt(0.5)))
  end
  Skia.sk_path_close(path)
  path
end
