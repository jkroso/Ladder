# Gives each box of a page its size and its place, as CSS says.
#
#     root = boxes(doc, look)
#     tall = layout!(root, 700, doc.mode)   # on a page 700 px wide. It gives how tall the page is.
#     root.x, root.y, root.width, root.height
#
# A box's place is its border's top left corner, in px from the top left
# corner of the border of the box that it's in. A block whose content is text
# has `lines`, each with its pieces: words, spaces and boxes.
#
# What's here: blocks down the page, with their margins joined as CSS joins
# them. Lines of text, broken to fit, with each piece on its line as
# `vertical-align` says: text that's justified, cut off with "…", or in lines
# of about one length. Floats, with text and tables beside them. Tables, with
# their columns as wide as their content asks. Flex boxes and grids. Text in
# columns. Boxes with a place of their own (`position: absolute` and `fixed`).
# Heights in percent, and a box with a shape (`aspect-ratio`).
#
# With `high`, the page is seen through a window that high: a height in
# percent of the page is of it, and a box that's fixed is placed in it. With
# none, the page is as tall as its content.

@use "./dom" Element attr
@use "./style" Style Len Track Size Template px isauto ispercent iskey border lineheight ANY_TRACK
@use "./text" Font font normal drawn advances space
@use "./box" Box Piece Span Line Gap NO_GAP floats placed inline contained blank flexes grids columned

"What layout knows of the page"
struct Pass
  mode::Symbol                   # :standards, :limited or :quirks
  pending::Vector{Vector{Box}}   # the boxes with a place of their own that wait for the box that they're placed from
  wide::Float64                  # how wide the page is
  high::Float64                  # how high the window is, or NaN for a page that's as tall as its content
  fixed::Vector{Box}             # the boxes that are placed from the window
end

face(s::Style) = font(s.family, s.size, s.weight, s.italic, s.stretch)

"How far over and under the line that its text stands on a line of the style `s` goes"
strut(s::Style, f::Font=face(s)) = begin
  half = (lineheight(s, normal(f)) - (f.ascent + f.descent)) / 2
  (f.ascent + half, f.descent + half)
end

margin(l::Len, cw) = l.auto ? 0.0 : px(l, cw)
"`x`, no less than `lo` and no more than `hi`. The least wins when the two can't both be so."
bound(x, lo, hi) = max(lo, min(x, hi))

"Work out the margins, the padding and the borders of `b`, in a box whose content is `cw` px wide"
edges!(b::Box, cw) = begin
  s = b.style
  b.padding = map(l -> max(0.0, px(l, cw)), s.padding)
  b.border = ntuple(i -> border(s, i), 4)
  b.margin = map(l -> margin(l, cw), s.margin)
  b
end

across(t::NTuple{4,Float64}) = t[2] + t[4]
down(t::NTuple{4,Float64}) = t[1] + t[3]
"How much of the width of `b` its padding and its borders take"
chrome(b::Box) = across(b.padding) + across(b.border)

"Put the box `k`, which has a place of its own, with the boxes that wait to be placed. `(x, y)` is where it would be in the text."
wait!(p::Pass, k::Box, x, y) = begin
  k.x, k.y = x, y
  k.lone = nothing
  push!(k.style.position == :fixed ? p.fixed : p.pending[end], k)
  nothing
end

"How far under the top of its border the first line of text of `b` stands, or NaN when it has no text"
first_base(b::Box) = begin
  isnan(b.first) || return b.first
  isempty(b.lines) || return b.border[1] + b.padding[1] + b.lines[1].y + b.lines[1].baseline
  for k in b.children
    (k.kind in (:block, :table, :group, :row, :cell) && !floats(k) && !placed(k)) || continue
    y = first_base(k)
    isnan(y) || return k.y + y
  end
  NaN
end

# --- floats -------------------------------------------------------------------------------

"The floats of a flow: the margin edges of each, as its left, top, right and bottom"
mutable struct Flow
  lefts::Vector{NTuple{4,Float64}}
  rights::Vector{NTuple{4,Float64}}
  top::Float64    # the top of the last float. One that comes later is no higher.
end
Flow() = Flow(NTuple{4,Float64}[], NTuple{4,Float64}[], -Inf)

"The left and the right edge of the room between the floats, from `y1` down to `y2`, in a box from `x1` to `x2`"
band(f::Flow, y1, y2, x1, x2) = begin
  l, r = x1, x2
  for (a, b, c, d) in f.lefts
    b < y2 && d > y1 && d > b && c > a && (l = max(l, c))
  end
  for (a, b, c, d) in f.rights
    b < y2 && d > y1 && d > b && c > a && (r = min(r, a))
  end
  (l, r)
end

"The first place under `y` where a float ends, or nothing"
next_bottom(f::Flow, y) = begin
  found = Inf
  for list in (f.lefts, f.rights), r in list
    r[4] > y && (found = min(found, r[4]))
  end
  isfinite(found) ? found : nothing
end

"Where the floats of a side, or of both, end"
clear_y(f::Flow, side::Symbol) = begin
  y = -Inf
  side in (:left, :both) && foreach(r -> y = max(y, r[4]), f.lefts)
  side in (:right, :both) && foreach(r -> y = max(y, r[4]), f.rights)
  y
end

"Find the place of the float `k`, which is laid out, in a box from `x1` to `x2`, no higher than `y`. It gives the corner of its margin."
place_float!(f::Flow, k::Box, x1, x2, y) = begin
  mw = k.width + across(k.margin)
  mh = k.height + down(k.margin)
  y = max(y, f.top)
  k.style.clear != :none && (y = max(y, clear_y(f, k.style.clear)))
  l, r = x1, x2
  while true
    l, r = band(f, y, y + max(mh, 1.0), x1, x2)
    (r - l >= mw - 0.01 || (l <= x1 && r >= x2)) && break
    ny = next_bottom(f, y)
    ny === nothing && break
    y = ny
  end
  x = k.style.float == :left ? l : r - mw
  push!(k.style.float == :left ? f.lefts : f.rights, (x, y, x + mw, y + mh))
  f.top = y
  (x, y)
end

# --- how wide a box wants to be -----------------------------------------------------------

"How narrow `b` can be with its margins, and how wide it is with them when no line is broken"
outer_extent(b::Box, p::Pass) = begin
  lo, hi = extent(b, p)
  m = margin(b.style.margin[2], 0.0) + margin(b.style.margin[4], 0.0)
  (lo + m, hi + m)
end

"The gaps between the rows and between the columns of a flex box or a grid whose content is `cw` px wide"
gaps(b::Box, cw) = (g = b.style.gap; (isauto(g[1]) ? 0.0 : max(0.0, px(g[1], cw)), isauto(g[2]) ? 0.0 : max(0.0, px(g[2], cw))))

"The things that are laid out in a flex box or a grid, in the order that their styles ask for"
things(b::Box) = sort!(Box[k for k in b.children if !placed(k)]; by=k -> k.style.order, alg=MergeSort)

"True for a thing in a flex box that can be narrower than its content, since it cuts off or scrolls what doesn't fit. A picture has nothing to scroll, so it's as wide as it is."
tight(k::Box) = k.kind != :image && k.style.overflow != :visible

"""
How narrow the border of `b` can be, and how wide it is when no line of its
text is broken. Without `own`, what `b`'s own style says of its width is left
out, as it is for a cell, whose table decides.
"""
extent(b::Box, p::Pass; own=true) = begin
  own && !isnan(b.extent[1]) && return b.extent
  s = b.style
  b.kind == :table && return (b.extent = table_extent(b, p))
  pad = max(0.0, s.padding[2].px) + max(0.0, s.padding[4].px) + border(s, 2) + border(s, 4)
  lo, hi = 0.0, 0.0
  if b.kind == :image
    hi = image_size(b, Inf)[1]
    lo = ispercent(s.width) || ispercent(s.maxwidth) || b.fills ? 0.0 : hi
    return (b.extent = (lo + pad, hi + pad))
  elseif flexes(b)
    row = s.flexdir in (:row, :row_reverse)
    kids = things(b)
    gap = (row ? gaps(b, 0.0)[2] : 0.0) * max(0, length(kids) - 1)
    for k in kids
      a, z = outer_extent(k, p)
      ks = k.style
      # A thing that's let shrink past its content can be as narrow as its style says
      isauto(ks.minwidth) && !tight(k) || (a = min(a, max(0.0, ks.minwidth.px) + (z - extent(k, p)[2]) + (ks.borderbox ? 0.0 :
        max(0.0, ks.padding[2].px) + max(0.0, ks.padding[4].px) + border(ks, 2) + border(ks, 4))))
      if row
        lo = s.flexwrap == :nowrap ? lo + a : max(lo, a)
        hi += z
      else
        lo, hi = max(lo, a), max(hi, z)
      end
    end
    row && ((lo, hi) = (lo + (s.flexwrap == :nowrap ? gap : 0.0), hi + gap))
  elseif grids(b)
    lo, hi = grid_extent(b, p)
  elseif b.kind in (:block, :cell, :caption) && !isempty(b.children)
    if all(k -> inline(k) || floats(k) || placed(k), b.children)
      lo = lines!(b, p, nothing, 0.0, 0.0, 0.0; measure=:min)[2]
      hi = lines!(b, p, nothing, 0.0, 0.0, Inf; measure=:max)[2]
    else
      run = 0.0
      for k in b.children
        placed(k) && continue
        a, z = outer_extent(k, p)
        lo = max(lo, a)
        run = floats(k) ? run + z : z
        hi = max(hi, run)
        floats(k) || (run = 0.0)
      end
    end
  end
  if own
    inner(l) = max(0.0, l.px - (s.borderbox ? pad : 0.0))
    w = s.width
    w.how == :min_content ? (hi = lo) : w.how == :max_content ? (lo = hi) : isauto(w) || iskey(w) || ispercent(w) || (lo = hi = inner(w))
    iskey(s.minwidth) || ispercent(s.minwidth) || (lo = max(lo, inner(s.minwidth)); hi = max(hi, inner(s.minwidth)))
    isauto(s.maxwidth) || iskey(s.maxwidth) || ispercent(s.maxwidth) || (lo = min(lo, inner(s.maxwidth)); hi = min(hi, inner(s.maxwidth)))
  end
  out = (lo + pad, hi + pad)
  own && (b.extent = out)
  out
end

# --- pictures -----------------------------------------------------------------------------

"The width of the picture of `b` over its height, or NaN when nothing says"
shape(b::Box) = begin
  nw, nh = b.natural
  asks, first = b.style.aspect
  own = !isnan(b.shape) ? b.shape : nw > 0 && nh > 0 ? nw / nh : NaN
  # What the style says of the shape counts, unless it lets the picture's own shape come first and the picture is there
  isnan(asks) || (first && b.picture !== nothing && !isnan(own)) ? own : asks
end

"How wide and how tall the picture of `b` is, without its padding and border, in a box whose content is `cw` px wide"
image_size(b::Box, cw) = begin
  s = b.style
  nw, nh = b.natural
  ratio = shape(b)
  known(l) = !isauto(l) && !iskey(l) && !(ispercent(l) && !isfinite(cw))
  pad = max(0.0, px(s.padding[2], cw)) + max(0.0, px(s.padding[4], cw)) + border(s, 2) + border(s, 4)
  padv = max(0.0, px(s.padding[1], cw)) + max(0.0, px(s.padding[3], cw)) + border(s, 1) + border(s, 3)
  w = known(s.width) ? max(0.0, px(s.width, cw) - (s.borderbox ? pad : 0.0)) : nothing
  tall = !isauto(s.height) && !(ispercent(s.height) && isnan(b.cbh))
  h = !isnan(b.forced) ? max(0.0, b.forced - padv) : tall ? max(0.0, px(s.height, b.cbh) - (s.borderbox ? padv : 0.0)) : nothing
  if w === nothing && h === nothing
    w, h = nw, nh
    # A drawing with a shape and no size is as wide as the box that it's in
    b.fills && isfinite(cw) && ((w, h) = (max(0.0, cw - pad), max(0.0, cw - pad) / ratio))
  elseif h === nothing
    h = isnan(ratio) ? nh : w / ratio
  elseif w === nothing
    w = isnan(ratio) ? nw : h * ratio
  end
  fixed = tall || !isnan(b.forced)
  if known(s.maxwidth) && w > (m = max(0.0, px(s.maxwidth, cw) - (s.borderbox ? pad : 0.0)))
    fixed || w <= 0 || (h *= m / w)
    w = m
  end
  if !iskey(s.minwidth) && !(ispercent(s.minwidth) && !isfinite(cw)) && w < (m = px(s.minwidth, cw))
    fixed || w <= 0 || (h *= m / w)
    w = m
  end
  if !isauto(s.maxheight) && !ispercent(s.maxheight) && h > s.maxheight.px
    known(s.width) || h <= 0 || (w *= s.maxheight.px / h)
    h = s.maxheight.px
  end
  !ispercent(s.minheight) && h < s.minheight.px && (h = s.minheight.px)
  (w, h)
end

"Give the picture `b` its size"
image!(b::Box, cw) = begin
  edges!(b, cw)
  w, h = image_size(b, cw)
  b.width = w + chrome(b)
  b.height = h + down(b.padding) + down(b.border)
  b.baseline = NaN
  b
end

# --- blocks -------------------------------------------------------------------------------

"How tall the content of `b` is, when its style says and that's known before its content is laid out, or NaN"
said_height(b::Box) = begin
  s = b.style
  vertical = down(b.padding) + down(b.border)
  isnan(b.forced) || return max(0.0, b.forced - vertical)
  (isauto(s.height) || (ispercent(s.height) && isnan(b.cbh)) || b.kind == :cell) && return NaN
  inner(l) = max(0.0, px(l, b.cbh) - (s.borderbox ? vertical : 0.0))
  h = inner(s.height)
  isauto(s.maxheight) || (ispercent(s.maxheight) && isnan(b.cbh)) || (h = min(h, inner(s.maxheight)))
  ispercent(s.minheight) && isnan(b.cbh) || (h = max(h, inner(s.minheight)))
  h
end

"The width of a box from what its style says, without its padding and border, or nothing when the style says none"
said_width(b::Box, cw, p::Pass) = begin
  s = b.style
  w = s.width
  if iskey(w)
    w.how == :stretch && return isfinite(cw) ? max(0.0, cw - across(b.margin) - chrome(b)) : nothing
    lo, hi = extent(b, p; own=false)
    room = isfinite(cw) ? cw - across(b.margin) : hi
    return max(0.0, (w.how == :min_content ? lo : w.how == :max_content ? hi : w.how == :fit_limit ? bound(px(w, cw) + chrome(b), lo, hi) :
                     bound(room, lo, hi)) - chrome(b))
  end
  if isauto(w) || (ispercent(w) && !isfinite(cw))
    # A box with a shape is as wide as its height asks
    ratio = s.aspect[1]
    h = isnan(ratio) || b.kind == :image ? NaN : said_height(b)
    return isnan(h) ? nothing : (s.borderbox ? (h + down(b.padding) + down(b.border)) * ratio - chrome(b) : h * ratio)
  end
  max(0.0, px(w, cw) - (s.borderbox ? chrome(b) : 0.0))
end

"`w`, the width of the content of `b`, kept between its least and its greatest width"
bounded(b::Box, w, cw) = begin
  s = b.style
  inner(l) = max(0.0, px(l, cw) - (s.borderbox ? chrome(b) : 0.0))
  isauto(s.maxwidth) || iskey(s.maxwidth) || (ispercent(s.maxwidth) && !isfinite(cw)) || (w = min(w, inner(s.maxwidth)))
  iskey(s.minwidth) || ispercent(s.minwidth) && !isfinite(cw) || (w = max(w, inner(s.minwidth)))
  w
end

"""
Give the block `b` its width and its side margins, in a box whose content is
`cw` px wide. `room` is how much of that is free beside floats, for a block
that can't have a float over it.
"""
block_width!(b::Box, cw, p::Pass; room=cw) = begin
  edges!(b, cw)
  said = said_width(b, cw, p)
  w = said === nothing ? max(0.0, room - across(b.margin) - chrome(b)) : said
  w = bounded(b, w, cw)
  b.width = w + chrome(b)
  centre!(b, room)
end

"Give `b`, whose width is known, the side margins that its `auto` margins come to in `room` px"
centre!(b::Box, room) = begin
  s = b.style
  free = room - b.width - across(b.margin)
  free > 0 || return b
  al, ar = isauto(s.margin[4]), isauto(s.margin[2])
  al && ar ? (b.margin = (b.margin[1], free / 2, b.margin[3], free / 2)) :
  al ? (b.margin = (b.margin[1], b.margin[2], b.margin[3], free)) : nothing
  b
end

"Give `b` the width that fits its content, but no more than `room` px with its margins, and lay out what's in it"
shrink!(b::Box, cw, p::Pass; room=cw) = begin
  if b.kind == :table
    return table!(b, cw, p; room=room)
  elseif b.kind == :image
    return image!(b, cw)
  end
  edges!(b, cw)
  said = said_width(b, cw, p)
  if said === nothing
    lo, hi = extent(b, p)
    said = min(max(lo, room - across(b.margin)), hi) - chrome(b)
  end
  b.width = bounded(b, max(0.0, said), cw) + chrome(b)
  content!(b, p, Flow(), 0.0, 0.0)
end

"Lay out `b`, of any kind, with a border `w` px wide, in a box whose content is `cw` px wide"
sized!(b::Box, p::Pass, w, cw) = begin
  if b.kind == :table
    table!(b, cw, p; room=w + across(b.margin), exact=w)
    isnan(b.forced) || (b.height = max(b.height, b.forced))
  elseif b.kind == :image
    image!(b, cw)
    ratio = shape(b)
    s = b.style
    # A picture that's made narrower or wider keeps its shape
    if abs(b.width - w) > 0.01 && isnan(b.forced) && (isauto(s.height) || (ispercent(s.height) && isnan(b.cbh))) && !isnan(ratio)
      b.height = max(0.0, w - chrome(b)) / ratio + down(b.padding) + down(b.border)
    end
    b.width = w
  else
    b.width = w
    content!(b, p, Flow(), 0.0, 0.0)
  end
  b
end

"True for the box of the page's body or of a cell, in a page with no doctype: the margins that a browser gives a paragraph, a heading or a list are dropped at its top"
drops(b::Box, p::Pass) = p.mode == :quirks && b.element !== nothing && b.element.tag in ("body", "td", "th")

"""
The margin over `b` that can join with the margin of what's over it: its own,
joined with the margins of what starts where it starts. With `drop`, a margin
that a browser gave is nothing.
"""
top_gap(b::Box, cw, p::Pass; drop=false) = begin
  s = b.style
  g = drop && s.loose[1] ? NO_GAP : Gap(margin(s.margin[1], cw))
  (b.kind == :block && !contained(b) && border(s, 1) == 0 && px(s.padding[1], cw) <= 0) || return g
  drop = drop || drops(b, p)
  for k in b.children
    (placed(k) || floats(k)) && continue
    (inline(k) || k.style.clear != :none) && break
    g = join(g, top_gap(k, cw, p; drop))
    hollow(k, cw) || break
    drop && k.style.loose[2] || (g = join(g, Gap(margin(k.style.margin[3], cw))))
  end
  g
end

"True for a block with nothing in it and no height, whose top and bottom margins join"
hollow(b::Box, cw) = begin
  s = b.style
  b.kind == :block && !contained(b) && border(s, 1) == 0 && border(s, 3) == 0 && px(s.padding[1], cw) <= 0 && px(s.padding[3], cw) <= 0 &&
    (isauto(s.height) || ispercent(s.height) || s.height.px == 0) && s.minheight.px == 0 && !ispercent(s.minheight) && isnan(s.aspect[1]) &&
    all(k -> placed(k) || floats(k) || blank(k) || hollow(k, cw), b.children)
end

"True when `b`, which is laid out, took no room, so that the margins over it and under it join"
through(b::Box) = b.kind == :block && b.height == 0 && !contained(b) && isempty(b.lines) && down(b.padding) + down(b.border) == 0

"True for a box that the boxes in it with a place of their own are placed from"
anchors(b::Box) = begin
  s = b.style
  s.position != :static || (b.element !== nothing && b.element.parent === nothing) || !isempty(s.transform) || !isempty(s.translate) ||
    !isempty(s.rotate) || !isempty(s.scale) || !isempty(s.filter)
end

"""
Put the <legend> of the <fieldset> `b`, which is laid out, on the line of its
top border: the border starts at the middle of the legend, and is cut where
the legend is. It gives how much shorter the content of `b` is for that.
"""
legend!(b::Box) = begin
  b.notch = (0.0, 0.0, 0.0)
  (b.element !== nothing && b.element.tag == "fieldset") || return 0.0
  i = findfirst(k -> !placed(k) && !floats(k), b.children)
  i === nothing && return 0.0
  k = b.children[i]
  (k.element !== nothing && k.element.tag == "legend") || return 0.0
  line = b.border[1]
  saved = min(line, k.height)
  k.y -= line + b.padding[1]
  for other in b.children
    other === k || placed(other) || (other.y -= saved)
  end
  b.notch = (max(0.0, (k.height - line) / 2), k.x, k.x + k.width)
  saved
end

"""
Lay out what's in the block `b`, whose width is known, and give `b` its
height. `(fx, fy)` is where the corner of `b`'s border is in `flow`, the floats
that it's among. A block that keeps its own floats starts a flow of its own.
"""
content!(b::Box, p::Pass, flow::Flow, fx, fy) = begin
  s = b.style
  own = contained(b)
  own && ((flow, fx, fy) = (Flow(), 0.0, 0.0))
  cx, cy = b.border[4] + b.padding[4], b.border[1] + b.padding[1]
  cw = max(0.0, b.width - chrome(b))
  vertical = down(b.padding) + down(b.border)
  anchor = anchors(b)
  anchor && push!(p.pending, Box[])
  empty!(b.lines)
  b.baseline = b.first = NaN
  b.cols = nothing
  sure = said_height(b)
  # A box that no element made is as tall as its content, and what's in it takes its percents from the box round it
  b.sure = isnan(sure) && b.element === nothing && isauto(s.height) ? b.cbh : sure
  for k in b.children
    k.cbh = b.sure
  end
  under = NO_GAP
  if flexes(b)
    h = flex!(b, p, cw, sure)
  elseif grids(b)
    h = grid!(b, p, cw, sure)
  elseif columned(b) && !isempty(b.children)
    h = flow_columns!(b, p, cw, sure)
  elseif isempty(b.children)
    h = 0.0
  elseif all(k -> inline(k) || floats(k) || placed(k), b.children)
    h = lines!(b, p, flow, fx + cx, fy + cy, cw)[1]
    isempty(b.lines) || (b.baseline = cy + b.lines[end].y + b.lines[end].baseline)
  else
    h, under = stack!(b, p, flow, fx + cx, fy + cy, cw)
    h -= legend!(b)
    for k in Iterators.reverse(b.children)
      (placed(k) || floats(k) || isnan(k.baseline)) && continue
      b.baseline = k.y + k.baseline
      break
    end
  end
  # A block that keeps its floats is as tall as they are
  own && (h = max(h, clear_y(flow, :both) - cy))
  fixed = !isnan(sure)
  sinks = !own && !fixed && b.border[3] == 0 && b.padding[3] == 0 && s.minheight.px == 0 && !ispercent(s.minheight) && isnan(s.aspect[1])
  if sinks
    b.below = join(Gap(b.margin[3]), under)
  else
    h += Base.size(under)
    b.below = Gap(b.margin[3])
  end
  inner(l) = max(0.0, px(l, b.cbh) - (s.borderbox ? vertical : 0.0))
  if fixed
    # A cell is as tall as its content here. Its table makes it as tall as its style says, and its row.
    h = sure
  else
    # A box with a shape is as tall as its width asks, and no less tall than its content
    isnan(s.aspect[1]) || b.kind == :cell || (h = max(h, (s.borderbox ? b.width / s.aspect[1] - vertical : cw / s.aspect[1])))
    # Browsers take no greatest height for a cell
    b.kind == :cell || isauto(s.maxheight) || (ispercent(s.maxheight) && isnan(b.cbh)) || (h = min(h, inner(s.maxheight)))
    ispercent(s.minheight) && isnan(b.cbh) || (h = max(h, inner(s.minheight)))
  end
  b.height = h + vertical
  if anchor
    over!(b, pop!(p.pending), p)
  end
  b
end

"""
Lay out the boxes in `b` one under the other. `(x0, y0)` is where the corner of
`b`'s content is in `flow`, and `cw` is how wide the content is. It gives how
tall they are together, and the margin under the last that's still to join
with what comes next.
"""
stack!(b::Box, p::Pass, flow::Flow, x0, y0, cw) = begin
  cx, cy = b.border[4] + b.padding[4], b.border[1] + b.padding[1]
  y = 0.0
  pending = NO_GAP
  first = true
  lifts = !contained(b) && b.border[1] == 0 && b.padding[1] == 0
  align = b.style.align
  drop = drops(b, p)
  last = nothing   # the last box in the flow
  for k in b.children
    if placed(k)
      wait!(p, k, cx, cy + y)
      continue
    elseif k.kind == :column
      continue
    elseif floats(k)
      shrink!(k, cw, p)
      at = y0 + y + (first && lifts ? 0.0 : Base.size(pending))
      x, top = place_float!(flow, k, x0, x0 + cw, at)
      k.x, k.y = cx + (x - x0) + k.margin[4], cy + (top - y0) + k.margin[1]
      continue
    end
    g = top_gap(k, cw, p; drop=drop && first)
    ky = y + (first && lifts ? 0.0 : Base.size(join(pending, g)))
    cleared = false
    if k.style.clear != :none
      under = clear_y(flow, k.style.clear) - y0
      under > ky && ((ky, cleared) = (under, true))
    end
    kx = 0.0
    if k.kind in (:table, :image) || contained(k)
      # A table, a picture or a block with its own flow is never under a float: it's beside it, or below it
      while true
        l, r = band(flow, y0 + ky, y0 + ky + 1.0, x0, x0 + cw)
        room = r - l
        k.kind == :table ? table!(k, cw, p; room=room) : k.kind == :image ? (image!(k, cw); centre!(k, room)) : block_width!(k, cw, p; room=room)
        fits = k.width + across(k.margin) <= room + 0.01
        if !fits && room < cw - 0.01 && (ny = next_bottom(flow, y0 + ky)) !== nothing
          ky = ny - y0
          continue
        end
        kx = l - x0
        kx += aligned(k, align, room)
        break
      end
      k.x, k.y = cx + kx + k.margin[4], cy + ky
      k.kind == :block && content!(k, p, flow, 0.0, 0.0)
    else
      block_width!(k, cw, p)
      kx = aligned(k, align, cw)
      k.x, k.y = cx + kx + k.margin[4], cy + ky
      content!(k, p, flow, x0 + kx + k.margin[4], y0 + ky)
    end
    if through(k) && !cleared
      drop && first && k.style.loose[2] || (pending = join(join(pending, g), k.below))
    else
      y = ky + k.height
      pending = k.kind == :block ? k.below : Gap(k.margin[3])
      first = false
      last = k
    end
  end
  # A cell of a page with no doctype drops the margin that a browser gave the last thing in it
  drop && b.kind == :cell && last !== nothing && last.style.loose[2] && pending == Gap(last.margin[3]) && (pending = NO_GAP)
  (y, pending)
end

"How far right a block moves in `room` px because the text round it is centred or to the right with a tag's `align`"
aligned(k::Box, align::Symbol, room) = begin
  free = room - k.width - across(k.margin)
  free > 0 || return 0.0
  s = k.style
  (isauto(s.margin[2]) || isauto(s.margin[4])) && return 0.0
  align == :wk_center ? free / 2 : align == :wk_right ? free : 0.0
end

"""
Lay out the box `k`, which has a place of its own, and place it in a
rectangle `cbw` by `cbh` px whose corner is at `(ox, oy)`: the padding of the
box that it's placed from, or the window. Where its style gives no side, it
stays where it would be in the text: `k.still` says so, and paint.jl finds
that place.
"""
place!(k::Box, p::Pass, cbw, cbh, ox, oy) = begin
  s = k.style
  top, right, bottom, left = s.inset
  side(l, base) = isauto(l) ? nothing : px(l, base)
  l, r, t, bt = side(left, cbw), side(right, cbw), side(top, cbh), side(bottom, cbh)
  room = max(0.0, cbw - something(l, 0.0) - something(r, 0.0))
  edges!(k, cbw)
  k.cbh = cbh
  # A box with a top and a bottom and no height is as tall as the room between them
  k.forced = t !== nothing && bt !== nothing && isauto(s.height) && k.kind != :image ? max(0.0, cbh - t - bt - down(k.margin)) : NaN
  if l !== nothing && r !== nothing && isauto(s.width) && !(k.kind in (:table, :image))
    block_width!(k, cbw, p; room=room)
    content!(k, p, Flow(), 0.0, 0.0)
  else
    shrink!(k, cbw, p; room=room)
  end
  auto(i) = isauto(s.margin[i])
  x = if l !== nothing && r !== nothing
    free = room - k.width - margin(s.margin[4], cbw) - margin(s.margin[2], cbw)
    l + (auto(4) && auto(2) ? max(0.0, free / 2) : auto(4) ? max(0.0, free) : margin(s.margin[4], cbw))
  elseif l !== nothing
    l + k.margin[4]
  elseif r !== nothing
    cbw - r - k.width - k.margin[2]
  else
    nothing
  end
  y = if t !== nothing && bt !== nothing
    free = cbh - t - bt - k.height - down(k.margin)
    t + (auto(1) && auto(3) ? max(0.0, free / 2) : auto(1) ? max(0.0, free) : k.margin[1])
  elseif t !== nothing
    t + k.margin[1]
  elseif bt !== nothing
    cbh - bt - k.height - k.margin[3]
  else
    nothing
  end
  k.still = (x === nothing, y === nothing)
  # Where it stays in the text, its place is that of the text until paint.jl finds it
  x === nothing ? (k.x += k.margin[4]) : (k.x = ox + x)
  y === nothing ? (k.y += k.margin[1]) : (k.y = oy + y)
  # In a flex box or a grid, that place is where it would be as the only thing there
  if k.lone !== nothing
    home, fx, fy = k.lone
    inside = grids(home) ? (0.0, 0.0, 0.0, 0.0) : home.padding   # the room is the content of a flex box, and the padding of a grid
    x === nothing && (k.x += fx * (home.width - across(home.border) - across(inside) - k.width - across(k.margin)))
    y === nothing && (k.y += fy * (home.height - down(home.border) - down(inside) - k.height - down(k.margin)))
  end
  k
end

"""
Where a box with a place of its own that's right in the flex box or the grid
`b` would be in the text: where `b` would put it if it were the only thing in
`b`. A browser does this, so an icon with `position: absolute` and no `top`
in a flex box with `align-items: center` is in the middle. It gives how far
across, and down, the room that's left the box's margin starts, from 0 at
the start to 1 at the end. The room is the content of a flex box, and the
padding of a grid.
"""
lone_place(b::Box, k::Box) = begin
  s = b.style
  share(a) = a == :center ? 0.5 : a in (:end, :flex_end) ? 1.0 : 0.0
  if grids(b)
    sideways = k.style.justifyself == :auto ? s.justifyitems : k.style.justifyself
    upright = k.style.alignself == :auto ? s.alignitems : k.style.alignself
    return (share(sideways), share(upright))
  end
  # The only thing of a flex box that spaces its things out is in the middle, or at the start for `space-between`.
  # `normal` and `stretch` place it at the start.
  along = s.justify in (:space_around, :space_evenly) ? :center : s.justify
  backwards = s.flexdir in (:row_reverse, :column_reverse)
  main = along == :center ? 0.5 : along in (:start, :end) ? share(along) : along == :flex_end ? (backwards ? 0.0 : 1.0) : (backwards ? 1.0 : 0.0)
  a = k.style.alignself == :auto ? s.alignitems : k.style.alignself
  side = a in (:center, :start, :end) ? share(a) : a == :flex_end ? (s.flexwrap == :wrap_reverse ? 0.0 : 1.0) : (s.flexwrap == :wrap_reverse ? 1.0 : 0.0)
  s.flexdir in (:row, :row_reverse) ? (main, side) : (side, main)
end

"Lay out and place the boxes with a place of their own that are placed from `b`, which is laid out"
over!(b::Box, boxes::Vector{Box}, p::Pass) = begin
  empty!(b.over)
  top = b.element !== nothing && b.element.parent === nothing
  # A box that was laid out twice waits twice
  for k in unique(objectid, boxes)
    if top
      # From the box of the whole page, a box is placed in the window, or in the page when there's no window
      place!(k, p, p.wide, isnan(p.high) ? b.y + b.height + b.margin[3] : p.high, -b.x, -b.y)
    else
      place!(k, p, b.width - across(b.border), b.height - down(b.border), b.border[4], b.border[1])
    end
    k.anchor = b
    push!(b.over, k)
  end
end

# --- lines of text ------------------------------------------------------------------------

"What's known while the lines of a block are made"
mutable struct Liner
  b::Box
  p::Pass
  flow::Union{Flow,Nothing}
  fx::Float64                   # where the corner of the block's content is among the floats
  fy::Float64
  cw::Float64
  measure::Symbol               # :none, :min or :max to find only how wide the lines are, or :count to find only how many there are
  lines::Vector{Line{Box}}
  cur::Vector{Piece{Box}}       # what's in the line so far
  curw::Float64
  word::Vector{Piece{Box}}      # what's been read since the last place where the line can break
  wordw::Float64
  y::Float64                    # the top of the line
  left::Float64                 # where the line starts, and how wide it can be, between the floats
  avail::Float64
  open::Vector{Box}             # the inline boxes that are open where the reading has got to
  carried::Vector{Box}          # the inline boxes that were open where the line started
  spaced::Bool                  # the last thing read was a space, or the line has only just started
  content::Bool                 # the line has a word or a box in it
  first::Bool                   # it's the block's first line
  widest::Float64
  beside::Float64               # how wide the floats in the text are together, when only measuring
  squeeze::Float64              # how much sooner than its room a line ends, for lines of about one length
  count::Int                    # how many lines there are, when only counting
end

style_now(L::Liner) = isempty(L.open) ? L.b.style : L.open[end].style
wraps(s::Style) = s.whitespace in (:normal, :pre_wrap, :pre_line)
"How wide a line can be before it breaks"
fit(L::Liner) = L.avail - L.squeeze

"Work out where the line at `L.y` starts and how wide it can be"
room!(L::Liner) = begin
  if L.measure != :none || L.flow === nothing
    L.left, L.avail = 0.0, L.measure == :min ? 0.0 : L.measure == :max ? Inf : L.cw
  else
    tall = max(1.0, sum(strut(L.b.style)))
    l, r = band(L.flow, L.fy + L.y, L.fy + L.y + tall, L.fx, L.fx + L.cw)
    L.left, L.avail = l - L.fx, r - l
  end
  if L.first
    indent = px(L.b.style.indent, isfinite(L.cw) ? L.cw : 0.0)
    L.left += indent
    L.avail -= indent
  end
end

text_piece(box, chars, widths, from; space=false) = Piece{Box}(:text, box, chars, widths, sum(widths; init=0.0), 0.0, 0.0, space, from)

"""
Put what's been read since the last place where the line can break into the
line. If it doesn't fit, it starts the next line.
"""
commit!(L::Liner) = begin
  isempty(L.word) && return
  if L.measure != :max
    L.content && L.curw + L.wordw > fit(L) + 0.01 && newline!(L)
    if L.wordw > fit(L) + 0.01
      # Beside a float there may be more room further down
      while L.measure == :none && L.flow !== nothing && L.avail < L.cw - 0.01 && L.wordw > fit(L) + 0.01
        ny = next_bottom(L.flow, L.fy + L.y)
        ny === nothing && break
        L.y = ny - L.fy
        room!(L)
      end
      i = findfirst(q -> q.kind == :text, L.word)
      # A long word can break between any two letters when its style says so. With `overflow-wrap: break-word`, that
      # doesn't make the box that it's in any narrower.
      how = i === nothing ? :normal : L.word[i].box.style.wrap
      if L.wordw > fit(L) + 0.01 && how != :normal && !(how == :break_word && L.measure == :min) && wraps(L.word[i].box.style)
        return split!(L)
      end
    end
  end
  L.content |= any(q -> q.kind in (:text, :atom), L.word)
  append!(L.cur, L.word)
  L.curw += L.wordw
  empty!(L.word)
  L.wordw = 0.0
  nothing
end

"Put a word that's too long for a line into as many lines as it needs, broken between any two letters"
split!(L::Liner) = begin
  word = copy(L.word)
  empty!(L.word)
  L.wordw = 0.0
  for q in word
    if q.kind != :text
      L.content && L.curw + q.width > fit(L) + 0.01 && newline!(L)
      push!(L.cur, q)
      L.curw += q.width
      L.content |= q.kind == :atom
      continue
    end
    i, n = 1, length(q.chars)
    while i <= n
      j, w = i, 0.0
      while j <= n && (L.curw + w + q.widths[j] <= fit(L) + 0.01 || (j == i && !L.content))
        w += q.widths[j]
        j += 1
      end
      if j == i
        newline!(L)
        continue
      end
      push!(L.cur, text_piece(q.box, q.chars[i:j-1], q.widths[i:j-1], q.from + i - 1))
      L.curw += w
      L.content = true
      i = j
      i <= n && newline!(L)
    end
  end
end

"End the line. A line with nothing in it is no line, unless a <br> ends it."
newline!(L::Liner; forced=false) = begin
  ps = L.cur
  used = L.curw
  # The spaces that a line ends with take no room
  k = length(ps)
  while k >= 1 && (ps[k].space || ps[k].kind in (:open, :close))
    if ps[k].space
      used -= ps[k].width
      ps[k].width = 0.0
      fill!(ps[k].widths, 0.0)
    end
    k -= 1
  end
  if L.content || forced || any(q -> q.kind in (:open, :close) && q.width > 0, ps)
    L.widest = max(L.widest, used)
    L.count += 1
    if L.measure == :none
      line = finish(L, ps, used, forced)
      push!(L.lines, line)
      L.y += line.height
    end
  else
    # The inline boxes that opened in a line that came to nothing are still open
    for q in ps
      q.kind == :open ? push!(L.carried, q.box) : q.kind == :close && !isempty(L.carried) ? pop!(L.carried) : nothing
    end
  end
  L.cur = Piece{Box}[]
  L.curw = 0.0
  L.content = false
  L.spaced = true
  L.first = false
  room!(L)
  nothing
end

mutable struct Frame
  box::Union{Box,Nothing}
  style::Style
  font::Font
  shift::Float64      # how far under the line's own baseline its text stands
  used::Bool          # it has text in this line, so its height counts
  left::Float64
  first::Bool
end

"How far over the line that its parent's text stands on the text of an inline box, or a box in a line, stands"
raised(s::Style, parent::Frame, top, bottom) = begin
  how, by = s.valign
  how == :sub ? -parent.style.size / 5 : how == :super ? parent.style.size / 3 :
  how == :length ? px(by, lineheight(s, normal(face(s)))) :
  how == :middle ? parent.font.xheight / 2 - (top - bottom) / 2 :
  how == :text_top ? parent.font.ascent - top : how == :text_bottom ? bottom - parent.font.descent : 0.0
end

"Which side the text of a block with the style `s` is at: :left, :right, :center or :justify"
side(s::Style) = begin
  a = s.align
  rtl = s.direction == :rtl
  a == :start ? (rtl ? :right : :left) : a == :end ? (rtl ? :left : :right) : a in (:wk_center, :center) ? :center :
  a in (:wk_right, :right) ? :right : a == :justify ? :justify : :left
end

"Make the line of the pieces `ps`, which are `used` px wide together: how tall it is, and where each piece is in it"
finish(L::Liner, ps, used, forced) = begin
  s0 = L.b.style
  quirky = L.p.mode != :standards
  above, below = -Inf, -Inf
  grow(top, bottom) = (above = max(above, top); below = max(below, bottom))
  # In a page that isn't of today's kind, the block's own text height counts only for a line that has text right in
  # the block, or that a <br> ended with nothing else in it
  frames = Frame[Frame(nothing, s0, face(s0), 0.0, !quirky || (forced && !any(q -> q.kind in (:text, :atom), ps)), 0.0, false)]
  for box in L.carried
    s = box.style
    f = face(s)
    top, bottom = strut(s, f)
    push!(frames, Frame(box, s, f, frames[end].shift - raised(s, frames[end], top, bottom), !quirky, 0.0, false))
  end
  spans = Tuple{Box,Float64,Float64,Float64,Float64,Bool,Bool}[]
  close(fr::Frame, right, last) = begin
    over, under = strut(fr.style, fr.font)
    fr.used && grow(over - fr.shift, under + fr.shift)
    k = fr.box
    push!(spans, (k, fr.left, right, fr.shift - fr.font.ascent - k.padding[1] - k.border[1], fr.shift + fr.font.descent + k.padding[3] + k.border[3], fr.first, last))
  end
  later = Tuple{Piece{Box},Float64,Symbol}[]
  x = 0.0
  for q in ps
    q.x = x
    if q.kind == :open
      s = q.box.style
      f = face(s)
      top, bottom = strut(s, f)
      push!(frames, Frame(q.box, s, f, frames[end].shift - raised(s, frames[end], top, bottom), !quirky || q.width > 0, x + q.box.margin[4], true))
    elseif q.kind == :close
      length(frames) > 1 && close(pop!(frames), x + q.width - q.box.margin[2], true)
    elseif q.kind == :text
      fr = frames[end]
      fr.used = true
      q.y = fr.shift
      # A letter that's drawn in another font, like an emoji, makes the line as tall as that font needs
      if fr.style.lineheight[1] == :normal
        for ch in q.chars
          use = drawn(fr.font, ch)[1]
          use === fr.font || grow(use.ascent + use.gap / 2 - fr.shift, use.descent + use.gap / 2 + fr.shift)
        end
      end
    else
      k = q.box
      h = k.height + down(k.margin)
      # A box that cuts off what's in it stands on the line with its bottom. A text field stands on it with its text.
      field = k.element !== nothing && k.element.tag in ("input", "select", "button")
      base = isnan(k.baseline) || (k.style.overflow != :visible && !field) ? h : k.margin[1] + k.baseline
      fr = frames[end]
      how = k.style.valign[1]
      if how in (:top, :bottom)
        push!(later, (q, h, how))
      else
        top = how == :middle ? fr.font.xheight / 2 + h / 2 - fr.shift :
              how == :text_top ? fr.font.ascent - fr.shift : how == :text_bottom ? h - fr.font.descent - fr.shift :
              base - fr.shift + raised(k.style, fr, base, h - base)
        grow(top, h - top)
        q.y = -top
      end
    end
    x += q.width
  end
  open_now = Box[fr.box for fr in frames[2:end]]
  while length(frames) > 1
    close(pop!(frames), x, false)
  end
  frames[1].used && grow(strut(s0, frames[1].font)...)
  isfinite(above) || ((above, below) = (0.0, 0.0))
  tall = above + below
  for (q, h, how) in later
    h > tall && (how == :bottom ? (above += h - tall) : (below += h - tall); tall = h)
  end
  for (q, h, how) in later
    q.y = how == :top ? -above : below - h
  end
  free = L.avail - used
  at = side(s0)
  dx = L.left + (free > 0 && isfinite(free) ? (at == :center ? free / 2 : at == :right ? free : 0.0) : 0.0)
  base = L.y + above
  for q in ps
    q.x += dx
    q.y += base
  end
  L.carried = open_now
  Line{Box}(L.y, tall, above, ps, [Span{Box}(b, l + dx, r + dx, t + base, bt + base, first, last) for (b, l, r, t, bt, first, last) in spans], forced,
            isfinite(free) ? free : 0.0)
end

isideograph(c::Char) = '\u2e80' <= c <= '\u9fff' || '\uac00' <= c <= '\ud7af' || '\uf900' <= c <= '\ufaff' || '\uff00' <= c <= '\uffef' || '\U20000' <= c <= '\U3ffff'

"Read the text of the box `t` into the line: its words, and its spaces as CSS keeps them"
text!(L::Liner, t::Box) = begin
  s = t.style
  f = face(s)
  ls, ws = s.letterspacing.px, s.wordspacing.px
  collapse = s.whitespace in (:normal, :nowrap, :pre_line)
  newlines = s.whitespace in (:pre, :pre_wrap, :pre_line)
  wrap = wraps(s)
  cs = collect(t.text)
  n = length(cs)
  # The width of each letter is found once, in the run of text that it's in
  length(t.advances) == n || (t.advances = advances(f, cs))
  gap = space(f) + ls + ws
  chars, widths, from = Char[], Float64[], 0
  flush() = begin
    isempty(chars) && return
    q = text_piece(t, chars, widths, from)
    push!(L.word, q)
    L.wordw += q.width
    chars, widths = Char[], Float64[]
  end
  for (i, ch) in enumerate(cs)
    if ch == '\n' && newlines
      flush()
      commit!(L)
      newline!(L; forced=true)
      continue
    elseif ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\f'
      if collapse
        L.spaced && continue
        flush()
        q = text_piece(t, [' '], [gap], i - 1; space=true)
        if wrap
          commit!(L)
          push!(L.cur, q)
          L.curw += q.width
        else
          push!(L.word, q)
          L.wordw += q.width
        end
        L.spaced = true
      else
        w = gap
        if ch == '\t'
          # A tab goes on to the next stop: the stops are so many spaces apart, from the start of the line
          stop = s.tabsize * gap
          at = wrap ? L.curw + L.wordw : L.curw + L.wordw + sum(widths; init=0.0)
          w = stop > 0 ? stop - mod(at + (wrap ? sum(widths; init=0.0) : 0.0), stop) : 0.0
          w < 0.01 && (w = stop)
        end
        if wrap
          flush()
          commit!(L)
          push!(L.cur, text_piece(t, [' '], [w], i - 1; space=true))
          L.curw += w
          L.content = true
        else
          isempty(chars) && (from = i - 1)
          push!(chars, ' ')
          push!(widths, w)
        end
        L.spaced = false
      end
      continue
    end
    w = t.advances[i]
    wide = wrap && isideograph(ch)
    wide && (flush(); commit!(L))
    isempty(chars) && (from = i - 1)
    push!(chars, ch)
    push!(widths, w + (w > 0 ? ls : 0.0))
    L.spaced = false
    # A line can break after a hyphen in a word, and at a space of no width or a hyphen that only shows at a break
    if wrap && (wide || s.wrap == :all || ch == '\u200b' || ch == '\u00ad' ||
                (ch == '-' && i > 1 && i < n && (isletter(cs[i-1]) || isdigit(cs[i-1])) && isletter(cs[i+1])))
      flush()
      commit!(L)
    end
  end
  flush()
end

"Read the inline box, the text or the box `k` into the line"
read!(L::Liner, k::Box) = begin
  b = L.b
  if placed(k)
    L.measure == :none && wait!(L.p, k, b.border[4] + b.padding[4] + L.left + L.curw, b.border[1] + b.padding[1] + L.y)
  elseif floats(k)
    if L.measure != :none
      lo, hi = outer_extent(k, L.p)
      L.measure == :min ? (L.widest = max(L.widest, lo)) : L.measure == :max ? (L.beside += hi) : nothing
      return
    end
    commit!(L)
    k.cbh = b.sure
    shrink!(k, L.cw, L.p)
    mw = k.width + across(k.margin)
    # A float that doesn't fit beside what the line has goes under the line
    under = L.content && L.curw + mw > L.avail + 0.01 ? sum(strut(b.style)) : 0.0
    x, top = place_float!(L.flow, k, L.fx, L.fx + L.cw, L.fy + L.y + under)
    k.x, k.y = b.border[4] + b.padding[4] + (x - L.fx) + k.margin[4], b.border[1] + b.padding[1] + (top - L.fy) + k.margin[1]
    room!(L)
  elseif k.kind == :text
    text!(L, k)
  elseif k.kind == :break
    commit!(L)
    newline!(L; forced=true)
    if k.style.clear != :none && L.measure == :none && L.flow !== nothing
      L.y = max(L.y, clear_y(L.flow, k.style.clear) - L.fy)
      room!(L)
    end
  elseif k.kind == :inline
    edges!(k, isfinite(L.cw) ? L.cw : 0.0)
    push!(L.word, Piece{Box}(:open, k, Char[], Float64[], k.margin[4] + k.border[4] + k.padding[4], 0.0, 0.0, false, 0))
    L.wordw += L.word[end].width
    push!(L.open, k)
    for c in k.children
      read!(L, c)
    end
    pop!(L.open)
    q = Piece{Box}(:close, k, Char[], Float64[], k.margin[2] + k.border[2] + k.padding[2], 0.0, 0.0, false, 0)
    # The end of an inline box stays with what's before it
    if isempty(L.word)
      push!(L.cur, q)
      L.curw += q.width
    else
      push!(L.word, q)
      L.wordw += q.width
    end
  else
    wrap = wraps(style_now(L))
    w = if L.measure == :none
      k.cbh = b.sure
      shrink!(k, L.cw, L.p)
      k.width + across(k.margin)
    else
      lo, hi = outer_extent(k, L.p)
      L.measure == :min ? lo : L.measure == :max ? hi : min(hi, max(lo, L.cw))
    end
    wrap && commit!(L)
    push!(L.word, Piece{Box}(:atom, k, Char[], Float64[], w, 0.0, 0.0, false, 0))
    L.wordw += w
    wrap && commit!(L)
    L.spaced = false
  end
  nothing
end

liner(b, p, flow, fx, fy, cw, measure) =
  Liner(b, p, flow, fx, fy, cw, measure, Line{Box}[], Piece{Box}[], 0.0, Piece{Box}[], 0.0, 0.0, 0.0, 0.0, Box[], Box[], true, false, true, 0.0, 0.0, 0.0, 0)

"How many lines the text of `b` makes in `cw` px, when each line ends `squeeze` px sooner than it has to"
count_lines(b::Box, p::Pass, cw, squeeze) = begin
  L = liner(b, p, nothing, 0.0, 0.0, cw, :count)
  L.squeeze = squeeze
  room!(L)
  foreach(k -> read!(L, k), b.children)
  commit!(L)
  newline!(L)
  L.count
end

"""
How much sooner than it has to each line of `b` can end, with no more lines:
what makes the lines of a heading about one length (`text-wrap: balance`)
"""
balance(b::Box, p::Pass, cw) = begin
  n = count_lines(b, p, cw, 0.0)
  (2 <= n <= 10) || return 0.0
  lo, hi = 0.0, cw * (1 - 1 / n)
  for _ in 1:12
    mid = (lo + hi) / 2
    count_lines(b, p, cw, mid) == n ? (lo = mid) : (hi = mid)
  end
  lo
end

"Cut the line off at `limit` px from the left of the block's content, with … where it's cut. With `always`, a line that fits has the dots after it."
ellipsis!(line::Line{Box}, limit; always=false) = begin
  i = findlast(q -> q.kind == :text, line.pieces)
  i === nothing && return
  s = line.pieces[i].box.style
  wide = drawn(face(s), '…')[3]
  stop = limit - wide
  keep = Piece{Box}[]
  at = nothing
  for q in line.pieces
    if q.x + q.width <= stop + 0.01 || q.kind in (:open, :close)
      at === nothing && push!(keep, q)
      continue
    end
    at === nothing || continue
    at = q.x
    if q.kind == :text
      n, w = 0, 0.0
      while n < length(q.chars) && q.x + w + q.widths[n+1] <= stop + 0.01
        w += q.widths[n+1]
        n += 1
      end
      # A space before the dots is left out
      while n > 0 && q.chars[n] == ' '
        w -= q.widths[n]
        n -= 1
      end
      if n > 0
        cut = text_piece(q.box, q.chars[1:n], q.widths[1:n], q.from)
        cut.x, cut.y = q.x, q.y
        push!(keep, cut)
      end
      at = q.x + w
    end
  end
  if at === nothing
    always || return
    j = findlast(q -> q.kind == :text && !(q.space && q.width == 0), keep)
    j === nothing && return
    at = keep[j].x + keep[j].width
  end
  # The dots stand where the text stands
  last = line.pieces[i]
  dots = text_piece(last.box, ['…'], [wide], last.from + length(last.chars))
  dots.x, dots.y = max(0.0, at), last.y
  push!(keep, dots)
  line.pieces = keep
  line.spans = [Span{Box}(sp.box, sp.left, min(sp.right, at + wide), sp.top, sp.bottom, sp.first, sp.last) for sp in line.spans if sp.left < at + wide]
  nothing
end

"Make the line as wide as its block, with what room it left shared among its spaces"
justify!(line::Line{Box}) = begin
  ps = line.pieces
  stop = findlast(q -> q.kind in (:text, :atom) && !(q.space && q.width == 0), ps)
  stop === nothing && return
  gaps = [i for i in 1:stop if ps[i].space && ps[i].width > 0]
  (isempty(gaps) || line.free <= 0.01) && return
  extra = line.free / length(gaps)
  starts = [ps[i].x for i in gaps]
  moved(x) = extra * count(<(x - 0.001), starts)
  line.spans = [Span{Box}(sp.box, sp.left + moved(sp.left), sp.right + moved(sp.right), sp.top, sp.bottom, sp.first, sp.last) for sp in line.spans]
  shift = 0.0
  for (i, q) in enumerate(ps)
    q.x += shift
    if i in gaps
      q.width += extra
      q.widths[end] += extra
      shift += extra
    end
  end
  line.free = 0.0
  nothing
end

"""
Make the lines of the block `b` from the text and the boxes in it. `(fx, fy)`
is where the corner of `b`'s content is in `flow`, and `cw` is how wide the
content is. It gives how tall the lines are together, and how wide the widest
is. With `measure`, it only finds how wide: `:min` with each line as short as
it can be, `:max` with no line broken.
"""
lines!(b::Box, p::Pass, flow, fx, fy, cw; measure=:none) = begin
  s = b.style
  L = liner(b, p, flow, fx, fy, cw, measure)
  if measure == :none && s.textwrap == :balance && isfinite(cw) && (flow === nothing || (isempty(flow.lefts) && isempty(flow.rights)))
    L.squeeze = balance(b, p, cw)
  end
  room!(L)
  for k in b.children
    read!(L, k)
  end
  commit!(L)
  newline!(L)
  measure == :none || return (0.0, L.widest + L.beside)
  # Text that's cut off after so many lines
  if s.lineclamp > 0 && length(L.lines) > s.lineclamp
    resize!(L.lines, s.lineclamp)
    last = L.lines[end]
    ellipsis!(last, cw; always=true)
    L.y = last.y + last.height
  end
  if s.textoverflow == :ellipsis && s.overflow != :visible
    for line in L.lines
      line.free < -0.5 && ellipsis!(line, cw)
    end
  end
  if side(s) == :justify
    for (i, line) in enumerate(L.lines)
      i == length(L.lines) || line.hard || justify!(line)
    end
  end
  b.lines = L.lines
  # Each box in a line gets its place, from the corner of `b`'s border
  cx, cy = b.border[4] + b.padding[4], b.border[1] + b.padding[1]
  for line in L.lines, q in line.pieces
    q.kind == :atom || continue
    q.box.x, q.box.y = cx + q.x + q.box.margin[4], cy + q.y + q.box.margin[1]
  end
  (L.y, L.widest)
end

# --- flex boxes ---------------------------------------------------------------------------

"A thing in a flex box, while the box is laid out"
mutable struct Flexed
  box::Box
  base::Float64       # how long its content is along the box before it grows or shrinks
  lo::Float64         # the least and the most that its content can be along the box
  hi::Float64
  size::Float64       # how long its content is along the box
  frozen::Bool
  edge::Float64       # its padding and its border along the box
  margin::Float64     # its margins along the box
  pos::Float64        # where its margin starts along the box
end

"How the thing `k` is placed across the flex box or the grid `b`: its own `align-self`, or what the box says for all"
across_place(b::Box, k::Box) = begin
  a = k.style.alignself
  a == :auto && (a = b.style.alignitems)
  a == :normal ? (k.kind == :image && grids(b) ? :start : :stretch) : a
end

"True when what's in `k` needs to be laid out again when `k` is made taller: something in it takes its height from `k`'s"
deep(k::Box) = flexes(k) || grids(k) || columned(k) || k.kind == :table ||
               any(c -> ispercent(c.style.height) || ispercent(c.style.minheight) || (c.element === nothing && deep(c)), k.children)

"Make `k` as tall as `tall` px, with its border: lay it out again only when what's in it needs that"
stretch!(k::Box, p::Pass, tall, cw) = begin
  abs(tall - k.height) > 0.01 || return
  k.forced = tall
  if k.kind == :image || !deep(k)
    k.height = tall
    k.sure = max(0.0, tall - down(k.padding) - down(k.border))
  else
    sized!(k, p, k.width, cw)
  end
  nothing
end

"Give each thing of one line of a flex box its length along the box: they grow into what room is free, or shrink to fit"
resolve!(line::Vector{Flexed}, room, gap) = begin
  hyp(it) = bound(it.base, it.lo, it.hi)
  between = gap * (length(line) - 1)
  growing = room - between - sum(hyp(it) + it.edge + it.margin for it in line) > 0
  factor(it) = growing ? it.box.style.grow : it.box.style.shrink
  for it in line
    it.frozen = factor(it) == 0 || (growing ? it.base > hyp(it) : it.base < hyp(it))
    it.size = it.frozen ? hyp(it) : it.base
  end
  left() = room - between - sum((it.frozen ? it.size : it.base) + it.edge + it.margin for it in line)
  start = left()
  for _ in 1:length(line)+1
    loose = [it for it in line if !it.frozen]
    isempty(loose) && break
    free = left()
    total = sum(factor, loose)
    # Things that ask for less than all of the room together get that share of it
    total < 1 && abs(start * total) < abs(free) && (free = start * total)
    if growing
      foreach(it -> it.size = it.base + free * it.box.style.grow / total, loose)
    else
      scaled = sum(it.box.style.shrink * it.base for it in loose)
      foreach(it -> it.size = scaled > 0 ? it.base - abs(free) * it.box.style.shrink * it.base / scaled : it.base, loose)
    end
    over = sum(bound(it.size, it.lo, it.hi) - it.size for it in loose)
    for it in loose
      fits = bound(it.size, it.lo, it.hi)
      (abs(over) < 1e-9 || (over > 0 && fits > it.size) || (over < 0 && fits < it.size)) && (it.frozen = true)
      it.size = fits
    end
  end
end

"""
Lay out what's in the flex box `b`, whose content is `cw` px wide and `sure`
px tall (NaN when its height isn't known yet). It gives how tall the content
is.
"""
flex!(b::Box, p::Pass, cw, sure) = begin
  s = b.style
  cx, cy = b.border[4] + b.padding[4], b.border[1] + b.padding[1]
  row = s.flexdir in (:row, :row_reverse)
  rowgap, colgap = gaps(b, cw)
  gap, linegap = row ? (colgap, rowgap) : (rowgap, colgap)
  foreach(k -> placed(k) && (wait!(p, k, cx, cy); k.lone = (b, lone_place(b, k)...)), b.children)
  kids = things(b)
  vertical = down(b.padding) + down(b.border)
  inner(l) = max(0.0, px(l, b.cbh) - (s.borderbox ? vertical : 0.0))
  least = ispercent(s.minheight) && isnan(b.cbh) ? 0.0 : inner(s.minheight)
  most = isauto(s.maxheight) || (ispercent(s.maxheight) && isnan(b.cbh)) ? Inf : inner(s.maxheight)
  avail = row ? cw : sure
  items = Flexed[]
  for k in kids
    ks = k.style
    edges!(k, cw)
    k.cbh, k.forced = sure, NaN
    edge = row ? chrome(k) : down(k.padding) + down(k.border)
    m = row ? across(k.margin) : down(k.margin)
    of = row ? cw : sure   # what a percent along the box is of
    inside(l) = max(0.0, px(l, of) - (ks.borderbox ? edge : 0.0))
    known(l) = !isauto(l) && !iskey(l) && !(ispercent(l) && isnan(of))
    use = isauto(ks.basis) ? (row ? ks.width : ks.height) : ks.basis
    if row
      a, z = extent(k, p)
      base = known(use) ? inside(use) : z - edge
      # With no least width said, a thing shrinks to its content, though its style gives it a width
      content = k.kind == :image ? a : extent(k, p; own=false)[1]
      lo = isauto(ks.minwidth) ? (tight(k) ? 0.0 : min(content - edge, known(ks.width) ? inside(ks.width) : Inf, known(ks.maxwidth) ? inside(ks.maxwidth) : Inf)) :
           iskey(ks.minwidth) ? (ks.minwidth.how == :max_content ? z - edge : a - edge) : inside(ks.minwidth)
      hi = isauto(ks.maxwidth) || iskey(ks.maxwidth) ? Inf : inside(ks.maxwidth)
    else
      # Down the box, a thing's length is its height, which its width decides: so its width comes first
      if k.kind == :table
        table!(k, cw, p)
      elseif k.kind == :image
        image!(k, cw)
        across_place(b, k) == :stretch && isauto(ks.width) && !isauto(ks.margin[2]) && !isauto(ks.margin[4]) && sized!(k, p, max(0.0, cw - across(k.margin)), cw)
      else
        said = said_width(k, cw, p)
        if said === nothing
          if across_place(b, k) == :stretch && !isauto(ks.margin[2]) && !isauto(ks.margin[4])
            said = max(0.0, cw - across(k.margin) - chrome(k))
          else
            a, z = extent(k, p)
            said = min(max(a, cw - across(k.margin)), z) - chrome(k)
          end
        end
        k.width = bounded(k, max(0.0, said), cw) + chrome(k)
        content!(k, p, Flow(), 0.0, 0.0)
      end
      natural = k.height - edge
      base = known(use) ? inside(use) : natural
      lo = isauto(ks.minheight) ? (tight(k) ? 0.0 : min(natural, known(ks.height) ? inside(ks.height) : Inf)) : known(ks.minheight) ? inside(ks.minheight) : 0.0
      hi = known(ks.maxheight) ? inside(ks.maxheight) : Inf
    end
    push!(items, Flexed(k, max(0.0, base), max(0.0, lo), hi, 0.0, false, edge, m, 0.0))
  end
  # The lines of the box: one, or as many as its things need
  lines = Vector{Flexed}[]
  wraps = s.flexwrap != :nowrap && !isnan(avail)
  cur, used = Flexed[], 0.0
  for it in items
    outer = bound(it.base, it.lo, it.hi) + it.edge + it.margin
    if wraps && !isempty(cur) && used + gap + outer > avail + 0.01
      push!(lines, cur)
      cur, used = Flexed[], 0.0
    end
    used += (isempty(cur) ? 0.0 : gap) + outer
    push!(cur, it)
  end
  isempty(cur) || push!(lines, cur)
  # How long the box is: down the page, a box with no height is as long as its things, or as its least height
  room = !isnan(avail) ? avail : bound(maximum((sum(bound(it.base, it.lo, it.hi) + it.edge + it.margin for it in line) + gap * (length(line) - 1) for line in lines); init=0.0), least, most)
  foreach(line -> resolve!(line, room, gap), lines)
  # How far across the box each line goes
  crosses = Float64[]
  ups = Float64[]   # for each line, how far under its start the line that its text stands on is
  for line in lines
    tall, up, under = 0.0, 0.0, 0.0
    for it in line
      k = it.box
      if row
        # A box with one line and a height says how tall its things are before they're laid out
        length(lines) == 1 && !isnan(sure) && across_place(b, k) == :stretch && isauto(k.style.height) && !isauto(k.style.margin[1]) && !isauto(k.style.margin[3]) &&
          (k.forced = max(0.0, sure - down(k.margin)))
        sized!(k, p, it.size + it.edge, cw)
      elseif abs(it.size + it.edge - k.height) > 0.01
        stretch!(k, p, it.size + it.edge, cw)
      end
      outer = row ? k.height + down(k.margin) : k.width + across(k.margin)
      base = row && across_place(b, k) == :baseline ? first_base(k) : NaN
      if isnan(base)
        tall = max(tall, outer)
      else
        up, under = max(up, k.margin[1] + base), max(under, outer - k.margin[1] - base)
      end
    end
    push!(crosses, max(tall, up + under))
    push!(ups, up)
  end
  n = length(lines)
  total = sum(crosses; init=0.0) + linegap * max(0, n - 1)
  # How far across the box goes: its height, for a box whose things are side by side
  far = row ? (isnan(sure) ? bound(total, least, most) : sure) : cw
  if n == 1
    crosses[1] = row || s.flexwrap == :nowrap ? far : crosses[1]
  elseif s.aligncontent in (:normal, :stretch) && far > total
    crosses .+= (far - total) / n
  end
  total = sum(crosses; init=0.0) + linegap * max(0, n - 1)
  # Where the lines start, when they don't fill the box
  spare = far - total
  lead, apart = 0.0, linegap
  if n > 1 && spare > 0
    ac = s.aligncontent
    ac in (:flex_end, :end) ? (lead = spare) : ac == :center ? (lead = spare / 2) : ac == :space_between ? (apart += spare / (n - 1)) :
    ac == :space_around ? (apart += spare / n; lead = spare / n / 2) : ac == :space_evenly ? (apart += spare / (n + 1); lead = spare / (n + 1)) : nothing
  end
  backwards = s.flexdir in (:row_reverse, :column_reverse)
  at = lead
  for (i, line) in enumerate(lines)
    count_ = length(line)
    used = sum(it.size + it.edge + it.margin for it in line) + gap * (count_ - 1)
    free = room - used
    # Margins that are `auto` take the room that's free. With none, the box's own style says where its things go.
    autos = sum(row ? isauto(it.box.style.margin[4]) + isauto(it.box.style.margin[2]) : isauto(it.box.style.margin[1]) + isauto(it.box.style.margin[3]) for it in line)
    each = autos > 0 && free > 0 ? free / autos : 0.0
    start, between = 0.0, gap
    if each == 0
      j = s.justify
      j in (:flex_end, :end) ? (start = free) : j == :center ? (start = free / 2) :
      j == :space_between ? (count_ > 1 && free > 0 && (between += free / (count_ - 1))) :
      j == :space_around ? (free > 0 ? (between += free / count_; start = free / count_ / 2) : (start = free / 2)) :
      j == :space_evenly ? (free > 0 ? (between += free / (count_ + 1); start = free / (count_ + 1)) : (start = free / 2)) : nothing
    end
    pos = start
    for it in line
      ks = it.box.style
      pos += each * (row ? isauto(ks.margin[4]) : isauto(ks.margin[1]))
      it.pos = pos
      pos += it.size + it.edge + it.margin + each * (row ? isauto(ks.margin[2]) : isauto(ks.margin[3])) + between
    end
    for it in line
      k = it.box
      ks = k.style
      how = across_place(b, k)
      # A thing that's stretched is as tall as its line
      if row && how == :stretch && isauto(ks.height) && !isauto(ks.margin[1]) && !isauto(ks.margin[3])
        stretch!(k, p, max(0.0, crosses[i] - down(k.margin)), cw)
      end
      outer = row ? k.height + down(k.margin) : k.width + across(k.margin)
      spare = crosses[i] - outer
      a1, a2 = row ? (isauto(ks.margin[1]), isauto(ks.margin[3])) : (isauto(ks.margin[4]), isauto(ks.margin[2]))
      base = row && how == :baseline ? first_base(k) : NaN
      off = a1 && a2 ? max(0.0, spare / 2) : a1 ? max(0.0, spare) : a2 ? 0.0 : how in (:flex_end, :end) ? spare : how == :center ? spare / 2 :
            !isnan(base) ? ups[i] - k.margin[1] - base : 0.0
      along = backwards ? room - it.pos - (it.size + it.edge + it.margin) : it.pos
      over = s.flexwrap == :wrap_reverse ? far - (at + off) - outer : at + off
      k.x, k.y = row ? (cx + along + k.margin[4], cy + over + k.margin[1]) : (cx + over + k.margin[4], cy + along + k.margin[1])
    end
    at += crosses[i] + apart
  end
  # The box's text stands where the text of its first thing stands
  if !isempty(items)
    k = lines[1][1].box
    base = first_base(k)
    b.first = k.y + (isnan(base) ? k.height : base)
    b.baseline = b.first
  end
  row ? far : room
end

# --- grids --------------------------------------------------------------------------------

"A thing in a grid: its first row and column, and how many of each it's over"
mutable struct Spot
  box::Box
  r::Int
  c::Int
  rs::Int
  cs::Int
end

"The tracks that a grid's style gives, when there's `avail` px for them: the tracks that repeat are there as often as fits"
laid_tracks(t::Template, avail, gap) = begin
  isempty(t.again) && return (copy(t.tracks), 0, 0)
  one(tr::Track) = tr.max.kind == :length ? px(tr.max.len, avail) : tr.min.kind == :length ? px(tr.min.len, avail) : 0.0
  others = sum(one, t.tracks; init=0.0) + sum(one, t.after; init=0.0)
  count = length(t.tracks) + length(t.after)
  each = sum(one, t.again; init=0.0)
  n = isfinite(avail) && each > 0 ? max(1, floor(Int, (avail - others - gap * count + gap) / (each + gap * length(t.again)) + 1e-6)) : 1
  n = min(n, max(1, 1000 ÷ length(t.again)))
  ([t.tracks; repeat(t.again, n); t.after], length(t.tracks) + 1, length(t.tracks) + n * length(t.again))
end

"The line that `v` of a grid's thing names, or nothing: `areas` gives the lines round each named area, and `names` the lines with a name"
grid_line(v, names, areas, rows::Bool, count, last::Bool) = begin
  v isa Int && return v > 0 ? v : max(1, count + 2 + v)
  v isa String || return nothing
  if haskey(areas, v)
    r1, c1, r2, c2 = areas[v]
    return rows ? (last ? r2 : r1) : (last ? c2 : c1)
  end
  for name in (v, v * (last ? "-end" : "-start"))
    haskey(names, name) && return names[name][1]
  end
  nothing
end

"Where a thing of a grid starts on one axis, or nothing when the grid finds it a place, and how many tracks it's over"
grid_span(a, b, names, areas, rows, count) = begin
  la = a isa Tuple ? nothing : grid_line(a, names, areas, rows, count, false)
  lb = b isa Tuple ? nothing : grid_line(b, names, areas, rows, count, true)
  sa, sb = a isa Tuple ? a[2] : 0, b isa Tuple ? b[2] : 0
  la !== nothing && lb !== nothing ? (min(la, lb), max(1, abs(lb - la))) :
  la !== nothing ? (la, max(1, sb)) : lb !== nothing ? (max(1, lb - max(1, sa)), max(1, sa)) : (nothing, max(1, sa, sb))
end

"""
Where each thing of the grid `b` is, and the tracks of its columns and its
rows. `cw` and `sure` are how wide and how tall its content is, for the tracks
that repeat as often as fits.
"""
arrange(b::Box, cw, sure) = begin
  s = b.style
  rowgap, colgap = gaps(b, isfinite(cw) ? cw : 0.0)
  cols, cfrom, cto = laid_tracks(s.gridcols, cw, colgap)
  rows, rfrom, rto = laid_tracks(s.gridrows, isnan(sure) ? Inf : sure, rowgap)
  # The areas that the style names: the lines round each
  areas = Dict{String,NTuple{4,Int}}()
  for (r, row) in enumerate(s.gridareas), (c, name) in enumerate(row)
    occursin(r"^\.+$", name) && continue
    r1, c1, r2, c2 = get(areas, name, (r, c, r + 1, c + 1))
    areas[name] = (min(r1, r), min(c1, c), max(r2, r + 1), max(c2, c + 1))
  end
  isempty(s.gridareas) || (length(rows) < length(s.gridareas) && append!(rows, fill(first_or(s.autorows), length(s.gridareas) - length(rows))))
  isempty(s.gridareas) || (length(cols) < length(s.gridareas[1]) && append!(cols, fill(first_or(s.autocols), length(s.gridareas[1]) - length(cols))))
  ncols, nrows = length(cols), length(rows)
  down_ = s.autoflow in (:column, :column_dense)
  dense = s.autoflow in (:row_dense, :column_dense)
  spots = Spot[]
  fixed = Tuple{Union{Int,Nothing},Union{Int,Nothing}}[]
  for k in things(b)
    rs, cs_, re, ce = k.style.gridplace
    r, rn = grid_span(rs, re, s.gridrows.names, areas, true, nrows)
    c, cn = grid_span(cs_, ce, s.gridcols.names, areas, false, ncols)
    push!(spots, Spot(k, something(r, 0), something(c, 0), rn, cn))
    push!(fixed, (r, c))
  end
  # The grid fills along its rows, or down its columns: the same work, with the two swapped
  swap!(sp) = ((sp.r, sp.c, sp.rs, sp.cs) = (sp.c, sp.r, sp.cs, sp.rs))
  down_ && (foreach(swap!, spots); fixed = [(c, r) for (r, c) in fixed])
  wide = max(1, down_ ? nrows : ncols)
  for (sp, (r, c)) in zip(spots, fixed)
    wide = max(wide, sp.cs, c === nothing ? 0 : c + sp.cs - 1)
  end
  taken = Set{Tuple{Int,Int}}()
  free(r, c, rs, cs) = all(!((i, j) in taken) for i in r:r+rs-1, j in c:c+cs-1)
  take!(sp) = for i in sp.r:sp.r+sp.rs-1, j in sp.c:sp.c+sp.cs-1
    push!(taken, (i, j))
  end
  for (sp, (r, c)) in zip(spots, fixed)
    r !== nothing && c !== nothing && take!(sp)
  end
  # Then the things that say their row
  for (sp, (r, c)) in zip(spots, fixed)
    (r !== nothing && c === nothing) || continue
    sp.c = something(findfirst(j -> free(sp.r, j, sp.rs, sp.cs), 1:max(1, wide - sp.cs + 1)), wide + 1)
    wide = max(wide, sp.c + sp.cs - 1)
    take!(sp)
  end
  # Then the rest, each after the one before it
  row, col = 1, 1
  for (sp, (r, c)) in zip(spots, fixed)
    r === nothing || continue
    dense && ((row, col) = (1, 1))
    if c !== nothing
      c < col && (row += 1)
      col = c
      while !free(row, col, sp.rs, sp.cs)
        row += 1
      end
    else
      while true
        col + sp.cs - 1 > wide && ((row, col) = (row + 1, 1))
        free(row, col, sp.rs, sp.cs) && break
        col += 1
      end
    end
    sp.r, sp.c = row, col
    take!(sp)
  end
  down_ && foreach(swap!, spots)
  # The rows and the columns that the style doesn't give are as its `grid-auto-rows` and `grid-auto-columns` say
  more(tracks, n, auto) = begin
    have = length(tracks)
    for i in have+1:n
      push!(tracks, isempty(auto) ? ANY_TRACK : auto[mod1(i - have, length(auto))])
    end
    tracks
  end
  more(cols, maximum(sp -> sp.c + sp.cs - 1, spots; init=ncols), s.autocols)
  more(rows, maximum(sp -> sp.r + sp.rs - 1, spots; init=nrows), s.autorows)
  # With `auto-fit`, the tracks that repeat and have nothing in them take no room, when they're the last
  if s.gridcols.fit && isempty(s.gridcols.after) && cto > 0
    used = maximum(sp -> sp.c + sp.cs - 1, spots; init=cfrom - 1)
    used < length(cols) && resize!(cols, max(used, cfrom - 1, 1))
  end
  (spots, cols, rows)
end

first_or(tracks) = isempty(tracks) ? ANY_TRACK : tracks[1]

"""
How big each track of a grid is, when its tracks have `avail` px together
(Inf to find how big they'd like to be). `wants` gives, for each thing, its
first track, how many tracks it's over, and the least and the most room that
it wants. With `fill`, tracks that are `auto` take what room is left.
"""
size_tracks(tracks::Vector{Track}, wants, avail, gap; fill=true) = begin
  n = length(tracks)
  n == 0 && return Float64[]
  definite = isfinite(avail)
  of = definite ? avail : 0.0
  set(sz::Size) = sz.kind == :length && (definite || !ispercent(sz.len))
  kind(sz::Size) = set(sz) ? :length : sz.kind == :length ? :auto : sz.kind
  base = [set(t.min) ? px(t.min.len, of) : 0.0 for t in tracks]
  limit = [set(t.max) ? max(px(t.max.len, of), base[i]) : Inf for (i, t) in enumerate(tracks)]
  flex(i) = tracks[i].max.kind == :fr
  for (i, span, lo, hi) in wants
    span == 1 || continue
    t = tracks[i]
    lowest, highest = kind(t.min), kind(t.max)
    lowest in (:auto, :min_content) && (base[i] = max(base[i], lo))
    lowest == :max_content && (base[i] = max(base[i], hi))
    had = isfinite(limit[i]) ? limit[i] : 0.0
    highest in (:auto, :max_content) ? (limit[i] = max(had, hi)) : highest == :min_content ? (limit[i] = max(had, lo)) :
    highest == :fit ? (limit[i] = max(had, min(hi, max(lo, px(t.max.len, of))))) : nothing
  end
  for i in 1:n
    flex(i) || (limit[i] = isfinite(limit[i]) ? max(limit[i], base[i]) : base[i])
  end
  # A thing over several tracks makes them bigger when they're too small for it together
  for (i, span, lo, hi) in sort([w for w in wants if w[2] > 1]; by=w -> w[2])
    over = i:min(n, i + span - 1)
    any(flex, over) && continue
    between = gap * (length(over) - 1)
    can = [j for j in over if kind(tracks[j].min) != :length]
    need = lo - between - sum(base[j] for j in over)
    need > 0 && !isempty(can) && foreach(j -> base[j] += need / length(can), can)
    can = [j for j in over if kind(tracks[j].max) != :length]
    foreach(j -> limit[j] = max(limit[j], base[j]), over)
    need = hi - between - sum(limit[j] for j in over)
    need > 0 && !isempty(can) && foreach(j -> limit[j] += need / length(can), can)
  end
  between = gap * (n - 1)
  if definite
    # The tracks grow to what they'd like, as far as there's room
    free = avail - between - sum(base)
    while free > 0.01
      open = [i for i in 1:n if !flex(i) && limit[i] - base[i] > 0.01]
      isempty(open) && break
      share = free / length(open)
      for i in open
        add = min(share, limit[i] - base[i])
        base[i] += add
        free -= add
      end
    end
  else
    for i in 1:n
      flex(i) || (base[i] = limit[i])
    end
  end
  flexible = [i for i in 1:n if flex(i)]
  if !isempty(flexible)
    if definite
      # The tracks that take a share of what's left. One that would get less than it needs keeps what it needs.
      active = copy(flexible)
      unit = 0.0
      while !isempty(active)
        left = avail - between - sum(base[i] for i in 1:n if !(i in active); init=0.0)
        unit = max(0.0, left) / max(1.0, sum(tracks[i].max.fr for i in active))
        small = [i for i in active if base[i] > tracks[i].max.fr * unit + 0.001]
        isempty(small) && break
        filter!(i -> !(i in small), active)
      end
      foreach(i -> base[i] = tracks[i].max.fr * unit, active)
    else
      unit = 0.0
      for (i, span, lo, hi) in wants
        over = i:min(n, i + span - 1)
        shares = sum(tracks[j].max.fr for j in over if flex(j); init=0.0)
        shares > 0 && (unit = max(unit, (hi - gap * (length(over) - 1) - sum(base[j] for j in over if !flex(j); init=0.0)) / max(shares, 1.0)))
      end
      foreach(i -> base[i] = max(base[i], tracks[i].max.fr * unit), flexible)
    end
  elseif definite && fill
    free = avail - between - sum(base)
    autos = [i for i in 1:n if kind(tracks[i].max) == :auto]
    free > 0.01 && !isempty(autos) && foreach(i -> base[i] += free / length(autos), autos)
  end
  base
end

"How narrow a grid can be, and how wide it would like to be, without its padding and border"
grid_extent(b::Box, p::Pass) = begin
  spots, cols, _ = arrange(b, Inf, NaN)
  gap = gaps(b, 0.0)[2]
  wants = [(sp.c, sp.cs, outer_extent(sp.box, p)...) for sp in spots]
  between = gap * max(0, length(cols) - 1)
  (sum(size_tracks(cols, wants, 0.0, gap; fill=false); init=0.0) + between, sum(size_tracks(cols, wants, Inf, gap); init=0.0) + between)
end

"Where each track starts, when the tracks have `room` px and `how` says where they go in it: it gives the starts and the gap"
track_starts(sizes, gap, room, how) = begin
  n = length(sizes)
  spare = room - sum(sizes; init=0.0) - gap * max(0, n - 1)
  lead = 0.0
  if spare > 0.01 && n > 0
    how in (:end, :flex_end) ? (lead = spare) : how == :center ? (lead = spare / 2) : how == :space_between ? (n > 1 && (gap += spare / (n - 1))) :
    how == :space_around ? (gap += spare / n; lead = spare / n / 2) : how == :space_evenly ? (gap += spare / (n + 1); lead = spare / (n + 1)) : nothing
  end
  starts = Float64[]
  at = lead
  for size in sizes
    push!(starts, at)
    at += size + gap
  end
  (starts, gap)
end

"""
Lay out what's in the grid `b`, whose content is `cw` px wide and `sure` px
tall (NaN when its height isn't known yet). It gives how tall the content is.
"""
grid!(b::Box, p::Pass, cw, sure) = begin
  s = b.style
  cx, cy = b.border[4] + b.padding[4], b.border[1] + b.padding[1]
  # A box with a place of its own stays in the grid's padding, as if it were the grid's only thing
  foreach(k -> placed(k) && (wait!(p, k, b.border[4], b.border[1]); k.lone = (b, lone_place(b, k)...)), b.children)
  rowgap, colgap = gaps(b, cw)
  spots, cols, rows = arrange(b, cw, sure)
  wide = size_tracks(cols, [(sp.c, sp.cs, outer_extent(sp.box, p)...) for sp in spots], cw, colgap; fill=s.justify in (:normal, :stretch))
  colx, colgap = track_starts(wide, colgap, cw, s.justify)
  span(starts, sizes, gap, i, n) = starts[min(end, i + n - 1)] + sizes[min(end, i + n - 1)] - starts[i]
  # A row whose height the style gives is known before what's in it is laid out
  said(sp) = all(t -> t.min.kind == :length && t.max.kind == :length && t.min.len == t.max.len && !ispercent(t.max.len), rows[sp.r:sp.r+sp.rs-1]) ?
             sum(px(t.max.len) for t in rows[sp.r:sp.r+sp.rs-1]) + rowgap * (sp.rs - 1) : NaN
  # Across its area, a thing is as wide as the area, or as its content when its style places it at a side
  across_of(k) = (j = k.style.justifyself; j == :auto && (j = s.justifyitems); j == :normal ? (k.kind == :image ? :start : :stretch) : j)
  for sp in spots
    k = sp.box
    ks = k.style
    room = span(colx, wide, colgap, sp.c, sp.cs)
    edges!(k, room)
    given = said(sp)
    k.cbh = given
    how = across_place(b, k)
    k.forced = !isnan(given) && how == :stretch && isauto(ks.height) && !isauto(ks.margin[1]) && !isauto(ks.margin[3]) ? max(0.0, given - down(k.margin)) : NaN
    autos = isauto(ks.margin[4]) || isauto(ks.margin[2])
    if k.kind == :table
      table!(k, room, p; room=room)
    elseif k.kind == :image
      image!(k, room)
      across_of(k) == :stretch && isauto(ks.width) && !autos && sized!(k, p, max(0.0, room - across(k.margin)), room)
    else
      w = said_width(k, room, p)
      if w === nothing
        if across_of(k) == :stretch && !autos
          w = max(0.0, room - across(k.margin) - chrome(k))
        else
          a, z = extent(k, p)
          w = min(max(a, room - across(k.margin)), z) - chrome(k)
        end
      end
      k.width = bounded(k, max(0.0, w), room) + chrome(k)
      content!(k, p, Flow(), 0.0, 0.0)
    end
  end
  tall = size_tracks(rows, [(sp.r, sp.rs, sp.box.height + down(sp.box.margin), sp.box.height + down(sp.box.margin)) for sp in spots], isnan(sure) ? Inf : sure, rowgap;
                     fill=s.aligncontent in (:normal, :stretch))
  total = sum(tall; init=0.0) + rowgap * max(0, length(tall) - 1)
  rowy, rowgap = track_starts(tall, rowgap, isnan(sure) ? total : sure, s.aligncontent)
  for sp in spots
    k = sp.box
    ks = k.style
    room = span(colx, wide, colgap, sp.c, sp.cs)
    high = span(rowy, tall, rowgap, sp.r, sp.rs)
    how = across_place(b, k)
    how == :stretch && isauto(ks.height) && !isauto(ks.margin[1]) && !isauto(ks.margin[3]) && stretch!(k, p, max(0.0, high - down(k.margin)), room)
    # Where it is in its area
    spare = room - k.width - across(k.margin)
    j = across_of(k)
    l, r = isauto(ks.margin[4]), isauto(ks.margin[2])
    dx = l && r ? max(0.0, spare / 2) : l ? max(0.0, spare) : r ? 0.0 : j in (:end, :flex_end) ? spare : j == :center ? spare / 2 : 0.0
    spare = high - k.height - down(k.margin)
    t, bt = isauto(ks.margin[1]), isauto(ks.margin[3])
    dy = t && bt ? max(0.0, spare / 2) : t ? max(0.0, spare) : bt ? 0.0 : how in (:end, :flex_end) ? spare : how == :center ? spare / 2 : 0.0
    k.x, k.y = cx + colx[sp.c] + dx + k.margin[4], cy + rowy[sp.r] + dy + k.margin[1]
  end
  if !isempty(spots)
    k = spots[argmin([(sp.r, sp.c) for sp in spots])].box
    base = first_base(k)
    b.first = k.y + (isnan(base) ? k.height : base)
    b.baseline = b.first
  end
  isnan(sure) ? total : sure
end

# --- text in columns ----------------------------------------------------------------------

"Add to `out` the top and the bottom of each piece of `b` that can't be cut in two: a line of text, or a box that's one piece. `oy` is how far down the top of `b`'s border is."
uncut!(out, b::Box, oy) = begin
  cy = oy + b.border[1] + b.padding[1]
  if !isempty(b.lines)
    for line in b.lines
      push!(out, (cy + line.y, cy + line.y + line.height))
    end
  elseif b.kind == :block && !flexes(b) && !grids(b) && !isempty(b.children) && b.style.overflow == :visible
    for k in b.children
      (placed(k) || floats(k)) || uncut!(out, k, oy + k.y)
    end
  else
    push!(out, (oy, oy + b.height))
  end
  out
end

"""
Lay out what's in `b` in columns. Its content is `cw` px wide, and `sure` px
tall when its style says. What's in it is laid out as one column, and
`b.cols` says where each column of the page is cut from: paint.jl draws each
piece in its place.
"""
flow_columns!(b::Box, p::Pass, cw, sure) = begin
  s = b.style
  gap = isauto(s.gap[2]) ? s.size : max(0.0, px(s.gap[2], cw))
  n = isauto(s.colwidth) ? s.colcount : max(1, floor(Int, (cw + gap) / (max(1.0, s.colwidth.px) + gap)))
  s.colcount > 0 && (n = min(n, s.colcount))
  n = max(1, n)
  w = max(0.0, (cw - gap * (n - 1)) / n)
  cx, cy = b.border[4] + b.padding[4], b.border[1] + b.padding[1]
  tall = if all(k -> inline(k) || floats(k) || placed(k), b.children)
    lines!(b, p, Flow(), cx, cy, w)[1]
  else
    h, under = stack!(b, p, Flow(), cx, cy, w)
    h + Base.size(under)
  end
  pieces = Tuple{Float64,Float64}[]
  if isempty(b.lines)
    foreach(k -> (placed(k) || floats(k)) || uncut!(pieces, k, k.y - cy), b.children)
  else
    foreach(line -> push!(pieces, (line.y, line.y + line.height)), b.lines)
  end
  sort!(pieces)
  # Where each column starts, when no column is taller than `most`
  cuts(most) = begin
    out = [0.0]
    for (top, bottom) in pieces
      bottom - out[end] > most + 0.01 && top > out[end] + 0.01 && push!(out, top)
    end
    out
  end
  starts = if !isnan(sure)
    cuts(sure)
  else
    # The shortest columns that hold it all
    lo, hi = max(tall / n, maximum(x -> x[2] - x[1], pieces; init=0.0)), tall
    for _ in 1:20
      mid = (lo + hi) / 2
      length(cuts(mid)) <= n ? (hi = mid) : (lo = mid)
    end
    cuts(hi)
  end
  ends = [starts[2:end]; tall]
  high = maximum(ends .- starts; init=0.0)
  b.cols = (wide=w, gap=gap, starts=starts, ends=ends, high=isnan(sure) ? high : sure)
  isnan(sure) ? high : sure
end

# --- tables -------------------------------------------------------------------------------

"The rows and the columns of a table"
mutable struct Grid
  rows::Vector{Box}
  groups::Vector{Box}
  cells::Vector{Box}
  captions::Vector{Box}
  ncols::Int
  said::Vector{Len}            # the width that a <col> says for each column
  low::Vector{Float64}         # how narrow each column can be
  high::Vector{Float64}        # how wide each is with no line broken
  share::Vector{Float64}       # the share of the table that each asks for, as a percent does, or 0
  fixed::Vector{Float64}       # the width in px that a cell or a <col> says for each, or NaN
  joined::Tuple{Float64,Float64}   # how far the borders of two cells run into each other, across and down, when the table's borders are one line
end

"Find the rows of the table `t`, and the row and the column of each of its cells"
grid(t::Box) = begin
  t.grid === nothing || return t.grid::Grid
  heads, bodies, feet = Box[], Box[], Box[]
  groups, captions, said = Box[], Box[], Len[]
  col!(c::Box) = begin
    n = c.element === nothing ? 1 : clamp(something(tryparse(Int, strip(attr(c.element, "span"))), 1), 1, 1000)
    foreach(_ -> push!(said, c.style.width), 1:n)
  end
  for k in t.children
    if k.kind == :group
      push!(groups, k)
      rows = filter(r -> r.kind == :row, k.children)
      append!(k.style.display == :table_header_group ? heads : k.style.display == :table_footer_group ? feet : bodies, rows)
    elseif k.kind == :row
      push!(bodies, k)
    elseif k.kind == :caption
      push!(captions, k)
    elseif k.kind == :column
      cols = filter(c -> c.kind == :column, k.children)
      isempty(cols) ? col!(k) : foreach(col!, cols)
    end
  end
  rows = [heads; bodies; feet]
  cells = Box[]
  busy = Int[]   # the last row that a cell from a row above takes of each column
  for (r, row) in enumerate(rows)
    col = 1
    for cell in row.children
      cell.kind == :cell || continue
      while col <= length(busy) && busy[col] >= r
        col += 1
      end
      cell.row, cell.col = r, col
      span = cell.rowspan == 0 ? length(rows) - r + 1 : min(cell.rowspan, length(rows) - r + 1)
      cell.rowspan = span
      for c in col:col+cell.colspan-1
        c > length(busy) && resize_zero!(busy, c)
        busy[c] = r + span - 1
      end
      col += cell.colspan
      push!(cells, cell)
    end
  end
  n = length(busy)
  joined = (0.0, 0.0)
  if t.style.collapse
    # The borders of two cells side by side are one line: each cell is over the one before it by the thinner of the two
    # borders that meet. Cells with a line only under them aren't over each other at all.
    top = right = bottom = left = 0.0
    for cell in cells
      cs = cell.style
      top, right, bottom, left = max(top, border(cs, 1)), max(right, border(cs, 2)), max(bottom, border(cs, 3)), max(left, border(cs, 4))
    end
    joined = (min(left, right), min(top, bottom))
  end
  t.grid = Grid(rows, groups, cells, captions, n, said, zeros(n), zeros(n), zeros(n), fill(NaN, n), joined)
end

resize_zero!(v::Vector{Int}, n) = (old = length(v); resize!(v, n); v[old+1:n] .= 0; v)

"Share `extra` px among the columns `cols` of `w`, by how wide each is in `by`, or evenly when they're nothing"
spread!(w, cols, extra, by) = begin
  total = sum(by[c] for c in cols)
  for c in cols
    w[c] += total > 0 ? extra * by[c] / total : extra / length(cols)
  end
end

"The room between the columns of the table `t`, and round them, and the room between its rows"
spacing(t::Box) = t.style.collapse ? (-grid(t).joined[1], -grid(t).joined[2]) : t.style.cellspacing

"How thick each side of the border of the table `t` is: with borders that are one line, it's no thinner than its cells' borders, which lie over it"
table_border(t::Box) = begin
  s = t.style
  s.collapse || return ntuple(i -> border(s, i), 4)
  jx, jy = grid(t).joined
  (max(border(s, 1), jy), max(border(s, 2), jx), max(border(s, 3), jy), max(border(s, 4), jx))
end

"How much of the width of the table `t` isn't its columns: its border, its padding and the room between its columns"
table_chrome(t::Box, g::Grid) = begin
  s = t.style
  pad = s.collapse ? 0.0 : max(0.0, s.padding[2].px) + max(0.0, s.padding[4].px)
  across(table_border(t)) + pad + spacing(t)[1] * (g.ncols + 1)
end

"Work out what each column of the table `t` asks for: how narrow it can be, how wide it wants to be, and what its cells say of its width"
columns!(t::Box, g::Grid, p::Pass) = begin
  fill!(g.low, 0.0); fill!(g.high, 0.0); fill!(g.share, 0.0); fill!(g.fixed, NaN)
  hs = spacing(t)[1]
  for (c, l) in enumerate(g.said)
    c > g.ncols && break
    (isauto(l) || iskey(l)) && continue
    ispercent(l) ? (g.share[c] = l.pct) : (g.fixed[c] = l.px)
  end
  wants(cell) = begin
    lo, hi = extent(cell, p; own=false)
    s = cell.style
    pad = max(0.0, s.padding[2].px) + max(0.0, s.padding[4].px) + border(s, 2) + border(s, 4)
    said = isauto(s.width) || iskey(s.width) || ispercent(s.width) ? NaN : s.width.px + (s.borderbox ? 0.0 : pad)
    # A cell is no narrower than its least width, and that's all of its own style that counts for how narrow it can be
    least = ispercent(s.minwidth) || iskey(s.minwidth) ? 0.0 : s.minwidth.px + (s.borderbox ? 0.0 : pad)
    (max(lo, least), max(hi, least), said, ispercent(s.width) ? s.width.pct : 0.0)
  end
  for cell in g.cells
    cell.colspan == 1 || continue
    c = cell.col
    lo, hi, said, share = wants(cell)
    g.low[c] = max(g.low[c], lo)
    if !isnan(said)
      g.fixed[c] = isnan(g.fixed[c]) ? said : max(g.fixed[c], said)
    else
      g.high[c] = max(g.high[c], hi)
    end
    g.share[c] = max(g.share[c], share)
  end
  for c in 1:g.ncols
    # A column whose cell says a width wants that width, and never less than its content needs
    isnan(g.fixed[c]) || (g.fixed[c] = max(g.fixed[c], g.low[c]); g.high[c] = g.fixed[c])
    g.high[c] = max(g.high[c], g.low[c])
  end
  # A cell over several columns makes them wider when they're too narrow for it together
  for cell in sort(filter(c -> c.colspan > 1, g.cells); by=c -> c.colspan)
    cols = cell.col:min(cell.col + cell.colspan - 1, g.ncols)
    lo, hi, said, share = wants(cell)
    between = hs * (length(cols) - 1)
    isnan(said) || (hi = max(lo, said))
    need = lo - between - sum(g.low[c] for c in cols)
    loose = [c for c in cols if isnan(g.fixed[c])]
    need > 0 && spread!(g.low, isempty(loose) ? cols : loose, need, g.high)
    for c in cols
      g.high[c] = max(g.high[c], g.low[c])
    end
    need = hi - between - sum(g.high[c] for c in cols)
    need > 0 && spread!(g.high, isempty(loose) ? cols : loose, need, g.high)
    if share > 0
      had = sum(g.share[c] for c in cols)
      rest = [c for c in cols if g.share[c] == 0]
      share > had && !isempty(rest) && foreach(c -> g.share[c] = (share - had) / length(rest), rest)
    end
  end
  g
end

"How narrow the table `t` can be, and how wide it wants to be"
table_extent(t::Box, p::Pass) = begin
  g = columns!(t, grid(t), p)
  s = t.style
  extra = table_chrome(t, g)
  lo, hi = sum(g.low) + extra, sum(g.high) + extra
  # A column that asks for a share of the table makes the table wide enough to give it
  total = sum(g.share)
  if 0 < total < 1
    plain = sum(g.high[c] for c in 1:g.ncols if g.share[c] == 0; init=0.0)
    hi = max(hi, plain / (1 - total) + extra)
    for c in 1:g.ncols
      g.share[c] > 0 && (hi = max(hi, g.high[c] / g.share[c] + extra))
    end
  end
  for k in g.captions
    lo = max(lo, outer_extent(k, p)[1])
  end
  isauto(s.width) || iskey(s.width) || ispercent(s.width) || (lo = max(lo, s.width.px); hi = lo)
  ispercent(s.minwidth) || iskey(s.minwidth) || (lo = max(lo, s.minwidth.px); hi = max(hi, lo))
  isauto(s.maxwidth) || iskey(s.maxwidth) || ispercent(s.maxwidth) || (hi = max(lo, min(hi, s.maxwidth.px)))
  (lo, max(lo, hi))
end

"How wide each column of a table is, when the columns have `target` px together"
column_widths(g::Grid, target) = begin
  w = copy(g.low)
  left = target - sum(w)
  left <= 0 && return w
  # First the columns that ask for a share of the table, then the ones that say a width, then the rest
  give!(cols, want) = begin
    need = [max(0.0, want(c) - w[c]) for c in cols]
    total = sum(need; init=0.0)
    total > 0 || return
    part = min(1.0, left / total)
    for (c, x) in zip(cols, need)
      w[c] += x * part
    end
    left -= total * part
  end
  shared = [c for c in 1:g.ncols if g.share[c] > 0]
  fixed = [c for c in 1:g.ncols if g.share[c] == 0 && !isnan(g.fixed[c])]
  loose = [c for c in 1:g.ncols if g.share[c] == 0 && isnan(g.fixed[c])]
  give!(shared, c -> g.share[c] * target)
  give!(fixed, c -> g.fixed[c])
  give!(loose, c -> g.high[c])
  # What's still free goes to the columns that said no width
  if left > 0.01
    cols = !isempty(loose) ? loose : !isempty(fixed) ? fixed : shared
    isempty(cols) || spread!(w, cols, left, cols === shared ? g.share : g.high)
  end
  w
end

"Move what's in `b` down by `dy`"
lower!(b::Box, dy) = begin
  dy == 0 && return
  foreach(k -> k.y += dy, b.children)
  foreach(k -> k.still[2] || (k.y += dy), b.over)
  for line in b.lines
    line.y += dy
    foreach(q -> q.y += dy, line.pieces)
    line.spans = [Span{Box}(s.box, s.left, s.right, s.top + dy, s.bottom + dy, s.first, s.last) for s in line.spans]
  end
  isnan(b.baseline) || (b.baseline += dy)
  isnan(b.first) || (b.first += dy)
end

"""
Lay out the table `t`, in a box whose content is `cw` px wide. `room` is how
much of that is free for it, beside floats. With `exact`, its border is that
many px wide, when its content can be.
"""
table!(t::Box, cw, p::Pass; room=cw, exact=NaN) = begin
  g = grid(t)
  s = t.style
  edges!(t, cw)
  t.border = table_border(t)
  s.collapse && (t.padding = (0.0, 0.0, 0.0, 0.0))
  lo, hi = extent(t, p)
  hs, vs = spacing(t)
  extra = across(t.border) + across(t.padding) + hs * (g.ncols + 1)
  # A table's width is of its border
  wide = if !isnan(exact)
    max(lo, exact)
  elseif isauto(s.width) || iskey(s.width) || (ispercent(s.width) && !isfinite(cw))
    max(lo, min(hi, room - across(t.margin)))
  else
    max(lo, px(s.width, cw) + (s.borderbox || t.element !== nothing && t.element.tag == "table" ? 0.0 : across(t.border) + across(t.padding)))
  end
  if isnan(exact)
    isauto(s.maxwidth) || iskey(s.maxwidth) || (ispercent(s.maxwidth) && !isfinite(cw)) || (wide = max(lo, min(wide, px(s.maxwidth, cw))))
    iskey(s.minwidth) || ispercent(s.minwidth) && !isfinite(cw) || (wide = max(wide, px(s.minwidth, cw)))
  end
  t.width = wide
  centre!(t, room)
  widths = column_widths(g, wide - extra)
  left = t.border[4] + t.padding[4]
  colx = Float64[]
  x = left + hs
  for w in widths
    push!(colx, x)
    x += w + hs
  end
  # The captions that go over the table
  y = 0.0
  for k in g.captions
    k.style.captionbottom && continue
    block_width!(k, wide, p)
    content!(k, p, Flow(), 0.0, 0.0)
    k.x, k.y = k.margin[4], y + k.margin[1]
    y += k.height + down(k.margin)
  end
  top = y
  # Each cell is laid out as wide as its columns, which says how tall its row has to be
  nrows = length(g.rows)
  tall = zeros(nrows)
  natural = Dict{Box,Float64}()
  for cell in g.cells
    cols = cell.col:min(cell.col + cell.colspan - 1, g.ncols)
    cell.width = sum(widths[c] for c in cols; init=0.0) + hs * (length(cols) - 1)
    edges!(cell, wide)
    cell.margin = (0.0, 0.0, 0.0, 0.0)
    cell.cbh = NaN
    content!(cell, p, Flow(), 0.0, 0.0)
    natural[cell] = cell.height
    # A cell is at least as tall as its style says
    h = cell.style.height
    isauto(h) || ispercent(h) || (cell.height = max(cell.height, h.px + (cell.style.borderbox ? 0.0 : down(cell.padding) + down(cell.border))))
    cell.rowspan == 1 && (tall[cell.row] = max(tall[cell.row], cell.height))
  end
  for (r, row) in enumerate(g.rows)
    h = row.style.height
    isauto(h) || ispercent(h) || (tall[r] = max(tall[r], h.px))
  end
  for cell in g.cells
    cell.rowspan > 1 || continue
    rows = cell.row:cell.row+cell.rowspan-1
    need = cell.height - vs * (length(rows) - 1) - sum(tall[r] for r in rows)
    need > 0 && spread!(tall, rows, need, tall)
  end
  # A table that says a height shares what's over among its rows
  said = !isnan(t.forced) ? t.forced : !isauto(s.height) && !(ispercent(s.height) && isnan(t.cbh)) ? px(s.height, t.cbh) : NaN
  if !isnan(said) && nrows > 0
    need = said - down(t.border) - down(t.padding) - vs * (nrows + 1) - sum(tall)
    need > 0 && spread!(tall, 1:nrows, need, tall)
  end
  rowy = Float64[]
  y = top + t.border[1] + t.padding[1] + vs
  for h in tall
    push!(rowy, y)
    y += h + vs
  end
  bottom = y + t.padding[3] + t.border[3]
  inner = (left + hs, wide - extra + hs * (g.ncols - 1))   # where the rows start, and how wide they are
  for (r, row) in enumerate(g.rows)
    row.x, row.y, row.width, row.height = inner[1], rowy[r], inner[2], tall[r]
  end
  for cell in g.cells
    rows = cell.row:cell.row+cell.rowspan-1
    h = sum(tall[r] for r in rows) + vs * (length(rows) - 1)
    how = cell.style.valign[1]
    lower!(cell, how == :top ? 0.0 : how == :bottom ? h - natural[cell] : how == :baseline ? 0.0 : (h - natural[cell]) / 2)
    cell.height = h
    # A cell's place is from the corner of its row
    cell.x, cell.y = colx[cell.col] - inner[1], 0.0
  end
  # A group of rows is the box round its rows, and its rows' places are from its corner
  for group in g.groups
    rows = filter(r -> r.kind == :row, group.children)
    if isempty(rows)
      group.x, group.y, group.width, group.height = inner[1], top, inner[2], 0.0
      continue
    end
    group.x, group.y = inner[1], minimum(r -> r.y, rows)
    group.width, group.height = inner[2], maximum(r -> r.y + r.height, rows) - group.y
    for r in rows
      r.x -= group.x
      r.y -= group.y
    end
  end
  y = bottom
  for k in g.captions
    k.style.captionbottom || continue
    block_width!(k, wide, p)
    content!(k, p, Flow(), 0.0, 0.0)
    k.x, k.y = k.margin[4], y + k.margin[1]
    y += k.height + down(k.margin)
  end
  t.height = y
  t.baseline = NaN
  t
end

# --- the page -----------------------------------------------------------------------------

"How far down what's in `b` goes, from the top of the box that `b` is in: what a box cuts off doesn't count"
reach(b::Box) = begin
  far = b.y + b.height
  b.style.overflow == :visible || return far
  for k in b.children
    k.kind in (:text, :break) || (far = max(far, b.y + (k.kind == :inline ? reach_in(k) : reach(k))))
  end
  for k in b.over
    k.still[2] || k.style.position == :fixed || (far = max(far, b.y + reach(k)))
  end
  far
end
reach_in(b::Box) = maximum(k -> k.kind in (:text, :break) ? 0.0 : k.kind == :inline ? reach_in(k) : reach(k), b.children; init=0.0)

"""
Lay out the page whose <html> element has the box `root`, `wide` px wide.
`mode` is what the page's doctype says of how it's laid out. `high` is how
high the window that the page is seen through is, or NaN for a page that's
as tall as its content. It gives how tall the page is.
"""
layout!(root::Box, wide, mode::Symbol=:standards; high=NaN) = begin
  p = Pass(mode, Vector{Box}[], Float64(wide), Float64(high), Box[])
  root.cbh = p.high
  block_width!(root, Float64(wide), p)
  root.x, root.y = root.margin[4], root.margin[1]
  content!(root, p, Flow(), 0.0, 0.0)
  # The boxes that are fixed in the window, and the ones that those hold
  tall = root.y + root.height + root.margin[3]
  while !isempty(p.fixed)
    waiting = unique(objectid, p.fixed)
    empty!(p.fixed)
    for k in waiting
      place!(k, p, p.wide, isnan(p.high) ? tall : p.high, -root.x, -root.y)
      k.anchor = root
      push!(root.over, k)
    end
  end
  max(tall, reach(root))
end
