# Turns the boxes of a page that's laid out into a list of things to draw, and
# draws them with Skia.
#
#     list = list(root, wide, tall; pictures)      # what to draw, from the top of the page down
#     list.links           # each rectangle of the page that's a link, and where it goes
#     list.words           # the page's words in the order that the HTML has them, with where each letter is
#     draw(canvas, list)                           # draw all of it, with the page's corner at the canvas's
#     draw(canvas, list; top=400, bottom=900)      # or only what's between two heights of the page
#     draw(canvas, list; at=2.5)                   # with its pictures that move, like a GIF, as they are 2.5 seconds after the page was first shown
#
# What's drawn: backgrounds in a colour, pictures and gradients, one over the
# other. Borders of every style, with round and oval corners, and the line
# round a box. Shadows, outside a box and in it, and of text. Text, with the
# lines under and through it. Pictures, as `object-fit` says. SVG drawings.
# The parts of a form. The bullets and numbers of lists. The picture that a
# video shows, and what a script drew on a <canvas>.
#
# Boxes are drawn in the order that CSS says: what has a `z-index` under 0,
# then the boxes of the text, then floats, then boxes with a place of their
# own, by their `z-index`. A box that's turned, moved or made bigger
# (`transform`), partly see-through (`opacity`), blurred or recoloured
# (`filter`), mixed with what's behind it (`mix-blend-mode`), or cut to a shape
# (`clip-path`, `mask-image`) is drawn as one piece.

@use Skia
@use "./dom" Element attr
@use "./css" resolve
@use "./style" Style Len Turn Shade Effect px isauto ispercent border colour alpha argb terms len flat PLAIN CURRENT NO_Z
@use "./text" Font font drawn normal
@use "./box" Box Piece Span Line floats placed flexes grids
@use "./svg" => Svg
@use "./canvas" Board found image!
@use "./video" Reel frame
@use "./select" Words OPEN

abstract type Item end

# How round each corner is: across and down, for the top left corner, the top right, the bottom right and the bottom left
const Radii = NTuple{8,Float64}
const SQUARE = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

"A rectangle in one colour"
struct Fill <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  color::UInt32
end

"The border of a box: how thick each side is, with its colour and its style"
struct Edge <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  widths::NTuple{4,Float64}
  colors::NTuple{4,UInt32}
  styles::NTuple{4,Symbol}
end

"Letters of one font on one line. `xs` is where each starts, from `x`."
mutable struct Glyphs <: Item
  x::Float64; y::Float64; w::Float64
  font::Font
  ids::Vector{UInt16}
  xs::Vector{Float32}
  color::UInt32
  blur::Float64       # how blurred, for a shadow
  stroke::Float64     # how thick the line round each letter is, or 0 for letters that are filled
  blob::Ptr{Cvoid}
end

"A picture in a box: all of it is drawn over `(dx, dy, dw, dh)`, and what's outside the box is cut off"
struct Picture <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  image::Ptr{Cvoid}
  dx::Float64; dy::Float64; dw::Float64; dh::Float64
  sharp::Bool          # each pixel of it stays a square when it's made bigger
end

"""
What a script drew on a <canvas>. It's drawn as the canvas is at the moment
that the page is drawn, so a page isn't laid out again each time a script
draws on its canvas.
"""
struct Sketch <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  board::Board
  dx::Float64; dy::Float64; dw::Float64; dh::Float64
  sharp::Bool
end

"""
A picture file that moves, like a GIF. It's drawn as it is at the moment that
the page is drawn: `now` holds how many seconds ago the page was first shown,
or nothing for a page that shows the file's first picture. So a page isn't
laid out again each time the picture changes.
"""
struct Moving <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  reel::Reel
  now::Base.RefValue{Any}
  dx::Float64; dy::Float64; dw::Float64; dh::Float64
  sharp::Bool
end

"Colours that run into each other: along a line, out from a point, or round one"
struct Blend
  kind::Symbol               # :linear, :radial or :conic
  again::Bool                # the colours start again after the last
  angle::Float64             # of a line: its angle in degrees, where 0 is up and 90 is to the right. Round a point: where it starts.
  cx::Float64; cy::Float64   # the point, as a share of the width and of the height
  size::String               # how far out the colours go from a point: a word, or lengths
  colors::Vector{UInt32}
  stops::Vector{Any}         # where each colour is: a length, an angle in turns, or nothing
end

"A picture or a gradient behind a box: tiles `tw` by `th`, the first at `(ox, oy)`, again and again as `repeat` says, with `gx` and `gy` px between them"
mutable struct Backing <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  source::Union{Ptr{Cvoid},Blend}
  ox::Float64; oy::Float64
  tw::Float64; th::Float64
  repeat::Tuple{Symbol,Symbol}
  gx::Float64; gy::Float64
  em::Float64                # the font size, for a gradient's lengths
  tile::Ptr{Cvoid}           # the picture of one tile of a gradient, once it's drawn
end

"A gradient in the border of a box"
struct Ring <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  widths::NTuple{4,Float64}
  blend::Blend
  em::Float64
end

"The shadow of a box: outside it, or `inset` in it"
struct Shadow <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  dx::Float64; dy::Float64; blur::Float64; spread::Float64
  color::UInt32
  inset::Bool
end

"A line under, over or through text"
struct Stroke <: Item
  x::Float64; y::Float64; w::Float64; h::Float64   # `h` is how thick it is, and `y` its top
  style::Symbol                                    # :solid, :double, :dotted, :dashed or :wavy
  color::UInt32
end

"A part of a form, the stand-in for a video, or with `:poster` the arrow over the picture of a video of another site: `value` is how full it is, or whether it's ticked"
struct Widget <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  kind::Symbol
  value::Float64
  color::UInt32      # the colour of its text
  accent::UInt32     # the colour of what's ticked or full
end

"An SVG drawing"
struct Drawing <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  element::Element
  look::Any
end

"From here to the `Unclip` that matches, nothing is drawn outside the rectangle, or outside the SVG path `path`, which is from the rectangle's corner"
struct Clip <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  path::String
end
Clip(x, y, w, h, radii) = Clip(x, y, w, h, radii, "")
struct Unclip <: Item end

"""
From here to the `Unlayer` that matches, what's drawn is one piece: partly
see-through, mixed with what's under it as `blend` says, and changed by
`effects`. `bounds` is the rectangle that the piece is in, or nothing when
that isn't known.
"""
struct Layer <: Item
  opacity::Float64
  blend::Symbol
  effects::Vector{Effect}
  bounds::Union{NTuple{4,Float64},Nothing}
end
struct Unlayer <: Item end

"From here to the `Unmove` that matches, what's drawn is moved, turned or made bigger: the six numbers are those of CSS's matrix()"
struct Move <: Item
  m::NTuple{6,Float64}
end
struct Unmove <: Item end

const Link = @NamedTuple{left::Float64, top::Float64, wide::Float64, tall::Float64, url::String}
# Where the border of an element's box is on the page. An element in lines of text has one of these for each line that it's in.
const Place = @NamedTuple{element::Element, left::Float64, top::Float64, wide::Float64, tall::Float64}

"The boxes that are drawn apart from the text of the box that orders them: each piece with its band, its z-index and when it was met"
mutable struct Order
  pieces::Vector{Tuple{Int,Int,Int,Vector{Item}}}
  clips::Int                 # how many cuts were open where the order started
end

"What to draw of a page, in order"
mutable struct List
  items::Vector{Item}
  links::Vector{Link}
  words::Vector{Words}
  wide::Float64
  tall::Float64
  background::UInt32
  pictures::Function
  # What's known while the list is made
  before::String        # what goes between the next words and the ones before them when they're copied
  line::Any             # the line that the last words were in
  behind::Any           # the box whose background is the page's, which is drawn already
  clips::Vector{Clip}   # the cuts that are open
  orders::Vector{Order}
  heading::Any          # the box that the innermost order is of
  mark::Int             # how many items there were when that box's own background was drawn
  still::IdDict{Box,Tuple{Float64,Float64}}   # where each box with a place of its own would be in the text
  corners::IdDict{Box,Tuple{Float64,Float64,Int}}   # for each box that others are placed from: where its corner is, and how many cuts were open in it
  matrix::NTuple{6,Float64}                   # how what's drawn now is moved
  met::Int
  base::String                                # the address of the page, which its links are from
  places::Vector{Place}                       # where each element's box is, in the order that the boxes are met
  floats::Vector{Vector{Vector{Item}}}        # for each box that's drawn apart and is open, the floats in it: they're drawn over its text's boxes
  now::Base.RefValue{Any}                     # how many seconds after the page was first shown it's drawn, for its pictures that move, or nothing
  seen::Vector{NTuple{4,Float64}}             # for each cut that's open, the part of the page that it and the cuts round it let be seen
end

const SAME = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
"The move `a` after the move `b`"
times(a, b) = (a[1] * b[1] + a[3] * b[2], a[2] * b[1] + a[4] * b[2], a[1] * b[3] + a[3] * b[4], a[2] * b[3] + a[4] * b[4],
               a[1] * b[5] + a[3] * b[6] + a[5], a[2] * b[5] + a[4] * b[6] + a[6])
moved(m, x, y) = (m[1] * x + m[3] * y + m[5], m[2] * x + m[4] * y + m[6])
shift(x, y) = (1.0, 0.0, 0.0, 1.0, Float64(x), Float64(y))

# --- making the list ----------------------------------------------------------------------

# The colour of the line round a picture that there isn't
const MISSING = 0x33808080

"The corners of a box `w` by `h`, in px: none rounder than the box has room for"
corners(s::Style, w, h) = begin
  rx = map(l -> max(0.0, px(l, w)), s.radius)
  ry = map(l -> max(0.0, px(l, h)), s.radiusv)
  all(==(0.0), rx) && all(==(0.0), ry) && return SQUARE
  f = min(1.0, w / max(rx[1] + rx[2], 1e-9), w / max(rx[4] + rx[3], 1e-9), h / max(ry[1] + ry[4], 1e-9), h / max(ry[2] + ry[3], 1e-9))
  (rx[1] * f, ry[1] * f, rx[2] * f, ry[2] * f, rx[3] * f, ry[3] * f, rx[4] * f, ry[4] * f)
end

"A corner that's `dx` less round across and `dy` less down: square when either comes to nothing"
less(rx, ry, dx, dy) = (x = rx - dx; y = ry - dy; x <= 0 || y <= 0 ? (0.0, 0.0) : (x, y))

"The corners of what's inside a border `widths` thick. Widths under 0 give the corners of what's that far outside."
inner(r::Radii, widths) = begin
  r == SQUARE && return SQUARE
  t, right, b, l = widths
  (less(r[1], r[2], l, t)..., less(r[3], r[4], right, t)..., less(r[5], r[6], right, b)..., less(r[7], r[8], l, b)...)
end
"The corners of the shape `d` px outside a shape with the corners `r`: a square corner stays square"
outer(r::Radii, d) = r == SQUARE || d == 0 ? r : ntuple(i -> r[i] > 0 ? max(0.0, r[i] + d) : 0.0, 8)

"The address in `url(...)`"
address(v) = (m = match(r"^url\(\s*(?:\"([^\"]*)\"|'([^']*)'|([^)]*?))\s*\)"i, strip(v)); m === nothing ? "" : String(strip(something(m[1], m[2], m[3]))))

"`s` cut at each comma that's in no brackets"
split_top(s) = begin
  out, depth, from = String[], 0, firstindex(s)
  for (i, c) in pairs(s)
    c == '(' ? (depth += 1) : c == ')' ? (depth -= 1) : nothing
    if c == ',' && depth == 0
      push!(out, s[from:prevind(s, i)])
      from = nextind(s, i)
    end
  end
  push!(out, s[from:end])
  out
end

const SIDES = Dict("top" => 0.0, "right" => 90.0, "bottom" => 180.0, "left" => 270.0)
const TURNS = Dict("deg" => 1 / 360, "rad" => 1 / 2π, "grad" => 1 / 400, "turn" => 1.0)

"The angle that `v` writes, in turns, or nothing"
turn(v) = begin
  m = match(r"^(-?[0-9.]+(?:e-?[0-9]+)?)(deg|rad|grad|turn)$", lowercase(strip(v)))
  m === nothing ? nothing : (x = tryparse(Float64, m[1]); x === nothing ? nothing : x * TURNS[m[2]])
end

"Where `v` puts a point in a box, as a share of its width and of its height: `center`, `left top`, `30% 70%`"
point(v) = begin
  ws = split(lowercase(v))
  isempty(ws) && return (0.5, 0.5)
  share(w, across) = w == "center" ? 0.5 : w in ("left", "top") ? 0.0 : w in ("right", "bottom") ? 1.0 :
                     endswith(w, '%') ? something(tryparse(Float64, chop(w)), 50.0) / 100 : nothing
  length(ws) == 1 && (ws = ws[1] in ("top", "bottom") ? ["center", ws[1]] : [ws[1], "center"])
  (ws[1] in ("top", "bottom") || ws[2] in ("left", "right")) && (ws = [ws[2], ws[1]])
  (something(share(ws[1], true), 0.5), something(share(ws[2], false), 0.5))
end

"""
The gradient that `v` writes with `linear-gradient(...)`, `radial-gradient(...)`
or `conic-gradient(...)`, or one of these that starts again
(`repeating-...`), or nothing
"""
gradient(v) = begin
  m = match(r"^(-webkit-|-moz-|-o-)?(repeating-)?(linear|radial|conic)-gradient\((.*)\)$"is, strip(v))
  m === nothing && return nothing
  old = m[1] !== nothing
  kind = Symbol(lowercase(m[3]))
  parts = [strip(p) for p in split_top(m[4])]
  isempty(parts) && return nothing
  angle, cx, cy, size = kind == :linear ? 180.0 : 0.0, 0.5, 0.5, ""
  first = lowercase(parts[1])
  if kind == :linear
    if (a = turn(first)) !== nothing
      angle = 360a
      old && (angle = 90 - angle)
      popfirst!(parts)
    elseif startswith(first, "to ") || (old && all(w -> haskey(SIDES, w), split(first)) && !isempty(split(first)))
      names = split(replace(first, "to " => ""))
      angles = [SIDES[n] for n in names if haskey(SIDES, n)]
      isempty(angles) && return nothing
      angle = length(angles) == 1 ? angles[1] : (abs(angles[1] - angles[2]) > 180 ? 315.0 : sum(angles) / 2)
      old && (angle += 180)
      popfirst!(parts)
    end
  elseif !(colour(first_word(first)) isa UInt32)
    # What's before the colours: the shape and the size, the angle that it starts from, and where its middle is
    at = match(r"(?:^|\s)at\s+(.*)$", first)
    at === nothing || ((cx, cy) = point(at[1]))
    lead = strip(at === nothing ? first : first[1:prevind(first, at.offset)])
    if kind == :conic
      from = match(r"from\s+(\S+)", lead)
      from === nothing || (angle = 360 * something(turn(from[1]), 0.0))
    else
      old && at === nothing && occursin(r"^(center|left|right|top|bottom|[0-9.]+%)", lead) && ((cx, cy) = point(lead); lead = "")
      size = String(lead)
    end
    popfirst!(parts)
  end
  colors, stops = UInt32[], Any[]
  for part in parts
    ws = terms(part)
    isempty(ws) && return nothing
    c = colour(ws[1])
    if !(c isa UInt32)
      # A place with no colour moves the middle of the change between the two colours round it: it's left out
      length(ws) == 1 && !isempty(colors) && continue
      return nothing
    end
    places = length(ws) > 1 ? ws[2:end] : [""]
    for place in places
      push!(colors, c)
      where = if isempty(place)
        nothing
      elseif kind == :conic
        t = turn(place)
        t !== nothing ? t : endswith(place, '%') ? something(tryparse(Float64, chop(place)), 0.0) / 100 : nothing
      else
        len(lowercase(place), PLAIN)
      end
      push!(stops, where)
    end
  end
  length(colors) < 2 && (isempty(colors) ? (return nothing) : (push!(colors, colors[1]); push!(stops, nothing)))
  Blend(kind, m[2] !== nothing, angle, cx, cy, size, colors, stops)
end
first_word(s) = (ws = terms(s); isempty(ws) ? "" : lowercase(ws[1]))

"The picture that a background or a mask names, as it's written: the file of an `image-set(...)` that's for a screen like a Mac's"
chosen(v) = begin
  m = match(r"^(?:-webkit-)?image-set\((.*)\)$"is, strip(v))
  m === nothing && return String(strip(v))
  best, most = "", -1.0
  for part in split_top(m[1])
    ws = terms(strip(part))
    isempty(ws) && continue
    x = length(ws) > 1 ? something(tryparse(Float64, replace(lowercase(ws[2]), r"(x|dppx)$" => "")), 1.0) : 1.0
    score = x >= 2 ? 100 - x : x
    score > most && ((best, most) = (startswith(ws[1], '"') || startswith(ws[1], '\'') ? "url($(ws[1]))" : String(ws[1]), score))
  end
  best
end

"Add the shadows `shades` of a box: the ones outside it, or with `inset` the ones in it"
shadows!(l::List, shades, x, y, w, h, radii, color; inset=false) = begin
  # The first shadow is drawn over the rest
  for sh in Iterators.reverse(shades)
    sh.inset == inset || continue
    c = sh.color == CURRENT ? color : sh.color
    alpha(c) > 0 && push!(l.items, Shadow(x, y, w, h, radii, sh.dx, sh.dy, sh.blur, sh.spread, c, inset))
  end
end

"The rectangle of a box that a background starts from or is cut to: its border, its padding or its content"
area(which, x, y, w, h, widths, padding) =
  which == :padding ? (x + widths[4], y + widths[1], w - widths[2] - widths[4], h - widths[1] - widths[3]) :
  which == :content ? (x + widths[4] + padding[4], y + widths[1] + padding[1], w - widths[2] - widths[4] - padding[2] - padding[4],
                       h - widths[1] - widths[3] - padding[1] - padding[3]) : (x, y, w, h)

nth(v, i) = v[mod1(i, length(v))]

"""
Add what's behind and round a box with the style `s`: its shadow, its
background and its border. `widths` is how thick each side of its border is,
and `padding` how much room is in it.
"""
decorate!(l::List, s::Style, x, y, w, h, widths=ntuple(i -> border(s, i), 4), padding=(0.0, 0.0, 0.0, 0.0); background=true) = begin
  (s.visible && w > 0 && h > 0) || return
  # A side with no line is no border
  widths = ntuple(i -> s.borderstyle[i] in (:none, :hidden) ? 0.0 : widths[i], 4)
  radii = corners(s, w, h)
  isempty(s.shadow) || shadows!(l, s.shadow, x, y, w, h, radii, s.color)
  background && backgrounds!(l, s, x, y, w, h, radii, widths, padding)
  isempty(s.shadow) || shadows!(l, s.shadow, x + widths[4], y + widths[1], w - widths[2] - widths[4], h - widths[1] - widths[3], inner(radii, widths), s.color; inset=true)
  if any(>(0), widths)
    g = occursin("gradient(", s.borderimage) ? gradient(first(terms(s.borderimage))) : nothing
    if g !== nothing
      push!(l.items, Ring(x, y, w, h, radii, widths, g, s.size))
    else
      colors = map(c -> c isa UInt32 ? c : s.color, s.bordercolor)
      any(i -> widths[i] > 0 && alpha(colors[i]) > 0, 1:4) && push!(l.items, Edge(x, y, w, h, radii, widths, colors, s.borderstyle))
    end
  end
  if s.outlinestyle != :none && s.outline.px > 0 && alpha(s.outlinecolor) > 0
    d = s.outline.px + s.outlineoffset.px
    ow = s.outline.px
    push!(l.items, Edge(x - d, y - d, w + 2d, h + 2d, outer(radii, d), (ow, ow, ow, ow), ntuple(_ -> s.outlinecolor, 4), ntuple(_ -> s.outlinestyle, 4)))
  end
end

"Add the background of a box: its colour, and each of its pictures and gradients, the last first"
backgrounds!(l::List, s::Style, x, y, w, h, radii, widths, padding) = begin
  n = length(s.image)
  if alpha(s.background) > 0
    # The colour is cut as the last picture is
    cx, cy, cw, ch = area(nth(s.bgclip, max(n, 1)), x, y, w, h, widths, padding)
    cut = nth(s.bgclip, max(n, 1))
    cw > 0 && ch > 0 && push!(l.items, Fill(cx, cy, cw, ch, cut == :padding ? inner(radii, widths) : cut == :content ? inner(radii, widths .+ padding) : radii, s.background))
  end
  for i in n:-1:1
    isempty(s.image[i]) && continue
    cut = nth(s.bgclip, i)
    from = nth(s.bgorigin, i)
    backdrop!(l, s, i, area(from, x, y, w, h, widths, padding), area(cut == :text ? :border : cut, x, y, w, h, widths, padding),
              cut == :padding ? inner(radii, widths) : cut == :content ? inner(radii, widths .+ padding) : radii)
  end
end

"Add picture `i` of the background of a box: it starts from the rectangle `from`, and is cut to the rectangle `cut` with the corners `radii`"
backdrop!(l::List, s::Style, i, from, cut, radii) = begin
  x, y, w, h = from
  (w > 0 && h > 0 && cut[3] > 0 && cut[4] > 0) || return
  written = chosen(s.image[i])
  source = occursin("gradient(", written) ? gradient(written) : nothing
  nw, nh = w, h
  if source === nothing
    found = l.pictures(address(written))
    found === nothing && return
    nw, nh, source = Float64(found[1]), Float64(found[2]), found[3]
    (nw > 0 && nh > 0) || return
  end
  size = nth(s.bgsize, i)
  tw, th = nw, nh
  if size == :cover || size == :contain
    k = size == :cover ? max(w / nw, h / nh) : min(w / nw, h / nh)
    tw, th = nw * k, nh * k
  elseif size isa Tuple
    a, b = size
    tw = isauto(a) ? NaN : px(a, w)
    th = isauto(b) ? NaN : px(b, h)
    isnan(tw) && isnan(th) ? ((tw, th) = (nw, nh)) : isnan(tw) ? (tw = source isa Blend ? w : th * nw / nh) : isnan(th) ? (th = source isa Blend ? h : tw * nh / nw) : nothing
  end
  (tw > 0 && th > 0) || return
  rx, ry = nth(s.repeat, i)
  # Tiles that fill the box with none cut off are made a little bigger or smaller
  rx == :round && (tw = w / max(1, round(w / tw)))
  ry == :round && (th = h / max(1, round(h / th)))
  gx = rx == :space && w >= 2tw ? (w - floor(w / tw) * tw) / (floor(w / tw) - 1) : 0.0
  gy = ry == :space && h >= 2th ? (h - floor(h / th) * th) / (floor(h / th) - 1) : 0.0
  # A percent puts that point of the picture at that point of the box
  at = nth(s.bgposition, i)
  ox = rx == :space && w >= 2tw ? 0.0 : px(at[1], w - tw)
  oy = ry == :space && h >= 2th ? 0.0 : px(at[2], h - th)
  again(r, fits) = r == :no_repeat || (r == :space && !fits) ? :no_repeat : :repeat
  item = Backing(cut[1], cut[2], cut[3], cut[4], radii, source, x + ox, y + oy, tw, th, (again(rx, w >= 2tw), again(ry, h >= 2th)), gx, gy, s.size, C_NULL)
  item.source isa Blend && finalizer(release, item)
  push!(l.items, item)
end

"Add the letters of `chars`, each as wide as `widths` says, with the first at `x` on the line at `y`"
glyphs!(l::List, f::Font, chars, widths, x, y, color; blur=0.0, stroke=0.0) = begin
  run = nothing
  at = 0.0
  for (c, w) in zip(chars, widths)
    use, id, _ = drawn(f, c)
    if id != 0
      if run === nothing || run.font !== use
        run = Glyphs(x + at, y, 0.0, use, UInt16[], Float32[], color, blur, stroke, C_NULL)
        finalizer(release, run)
        push!(l.items, run)
      end
      push!(run.ids, id)
      push!(run.xs, Float32(x + at - run.x))
      run.w = x + at + w - run.x
    end
    at += w
  end
end

release(g::Glyphs) = (g.blob == C_NULL || Skia.sk_textblob_unref(g.blob); g.blob = C_NULL; nothing)
release(b::Backing) = (b.tile == C_NULL || Skia.sk_image_unref(b.tile); b.tile = C_NULL; nothing)

"How far `b` is moved from where it was laid out, when its style has `position: relative`"
nudge(s::Style) = begin
  s.position == :relative || return (0.0, 0.0)
  top, right, bottom, left = s.inset
  (!isauto(left) ? left.px : !isauto(right) ? -right.px : 0.0, !isauto(top) ? top.px : !isauto(bottom) ? -bottom.px : 0.0)
end

"How far under the top of `b`'s border its first line of text stands, or nothing when it has no text"
first_baseline(b::Box) = begin
  isempty(b.lines) || return b.border[1] + b.padding[1] + b.lines[1].y + b.lines[1].baseline
  for k in b.children
    (k.kind in (:block, :table, :group, :row, :cell) && !floats(k) && !placed(k)) || continue
    y = first_baseline(k)
    y === nothing || return k.y + y
  end
  nothing
end

"Call `f` with each float in the text of `b`"
each_float(f, b::Box) = for k in b.children
  floats(k) ? f(k) : k.kind == :inline && each_float(f, k)
end

"""
Add each box in `b` that has a place of its own. It's met here, where the
HTML has it, so that its words are in the page's order. It's drawn from the
box that it's placed from, and cut as that box is cut. `(x, y)` is the corner
of the block that it's in, which is where it would be in the text.
"""
placed!(l::List, b::Box, x, y) = for k in b.children
  placed(k) ? placed!(l, b, k, x, y) : k.kind == :inline && placed!(l, k, x, y)
end
placed!(l::List, b::Box, k::Box, x, y) = begin
  from = k.anchor === nothing ? nothing : get(l.corners, k.anchor, nothing)
  from === nothing && return
  l.still[k] = (x + k.x, y + k.y)
  emit!(l, k, from[1], from[2]; cuts=from[3])
end

"The rectangle round the rectangle `(x, y, w, h)` as it's moved now"
around(l::List, x, y, w, h) = begin
  l.matrix == SAME && return (Float64(x), Float64(y), Float64(w), Float64(h))
  ps = (moved(l.matrix, x, y), moved(l.matrix, x + w, y), moved(l.matrix, x, y + h), moved(l.matrix, x + w, y + h))
  x0, x1 = extrema(p[1] for p in ps)
  y0, y1 = extrema(p[2] for p in ps)
  (x0, y0, x1 - x0, y1 - y0)
end

"Note where the text of the piece `q` is, so that it can be selected"
words!(l::List, line, q::Piece, x, top, tall) = begin
  edges = Float64[x]
  for w in q.widths
    push!(edges, edges[end] + w)
  end
  if l.matrix != SAME
    # Text that's moved or made bigger is where it's drawn. Text that's turned is in the rectangle round it.
    x0, y0, w0, h0 = around(l, edges[1], top, edges[end] - edges[1], tall)
    wide = max(edges[end] - edges[1], 1e-9)
    edges = [x0 + (e - edges[1]) / wide * w0 for e in edges]
    top, tall = y0, h0
  end
  seen = isempty(l.seen) ? OPEN : l.seen[end]
  last = isempty(l.words) ? nothing : l.words[end]
  if last !== nothing && l.line === line && isempty(l.before) && abs(last.edges[end] - edges[1]) < 0.5 && last.seen == seen
    # It goes on from the words before it
    append!(last.edges, @view edges[2:end])
    append!(last.letters, q.chars)
    l.words[end] = (before=last.before, top=min(last.top, top), tall=max(last.top + last.tall, top + tall) - min(last.top, top),
                    edges=last.edges, letters=last.letters, from=last.from, seen=seen)
  else
    from = last === nothing ? 0 : last.from + length(last.letters)
    before = last === nothing ? "" : l.before
    push!(l.words, (before=before, top=top, tall=tall, edges=edges, letters=copy(q.chars), from=from, seen=seen))
  end
  l.line = line
  l.before = ""
end

"Note where the border of the box `b` is, for the element that it's the box of"
place!(l::List, b::Box, x, y, w, h) = begin
  b.element === nothing && return
  x, y, w, h = around(l, x, y, w, h)
  push!(l.places, (element=b.element, left=x, top=y, wide=w, tall=h))
end

"Add a rectangle of the page that's a link. Only a page that's a file of this computer links to a file of it."
link!(l::List, url, x, y, w, h) = begin
  (isempty(url) || w <= 0 || h <= 0) && return
  url = resolve(l.base, url)
  occursin(r"^(https?|mailto|tel):"i, url) || (occursin(r"^file:"i, url) && occursin(r"^file:"i, l.base)) || return
  x, y, w, h = around(l, x, y, w, h)
  last = isempty(l.links) ? nothing : l.links[end]
  # A link's words on one line are one rectangle
  if last !== nothing && last.url == url && abs(last.top - y) < 0.5 && abs(last.tall - h) < 0.5 && abs(last.left + last.wide - x) < 0.5
    l.links[end] = (left=last.left, top=last.top, wide=x + w - last.left, tall=last.tall, url=url)
  else
    push!(l.links, (left=Float64(x), top=Float64(y), wide=Float64(w), tall=Float64(h), url=String(url)))
  end
end

"The shape that `clip-path: v` cuts a box `w` by `h` px to: its rectangle and corners, from the box's corner, or an SVG path. Nothing when `v` can't be read."
cut_shape(v, w, h, em) = begin
  m = match(r"^([a-z]+)\((.*)\)"is, strip(v))
  m === nothing && return nothing
  name, inside = lowercase(m[1]), m[2]
  size(t, of) = (x = len(lowercase(t), PLAIN); x === nothing || x.auto ? nothing : px(flat(x, em), of))
  if name == "inset"
    halves = split(inside, r"\bround\b")
    ws = [size(t, i in (1, 3) ? h : w) for (i, t) in enumerate(side4(terms(halves[1])))]
    any(isnothing, ws) && return nothing
    t, r, b, left = ws
    cw, ch = max(0.0, w - left - r), max(0.0, h - t - b)
    radii = SQUARE
    if length(halves) > 1
      rs = [size(x, cw) for x in side4(terms(first(split(halves[2], '/'))))]
      any(isnothing, rs) || (radii = (rs[1], rs[1], rs[2], rs[2], rs[3], rs[3], rs[4], rs[4]))
    end
    return (left, t, cw, ch, radii, "")
  elseif name in ("circle", "ellipse")
    at = match(r"(?:^|\s)at\s+(.*)$", inside)
    cx, cy = at === nothing ? (0.5, 0.5) : point(at[1])
    lead = [lowercase(t) for t in terms(strip(at === nothing ? inside : inside[1:prevind(inside, at.offset)]))]
    ax, ay = cx * w, cy * h
    # How far the shape goes from its middle, along a side that's `of` px long: to the nearest edge, to the farthest, or as far as it says
    far(t, c, of, other) = t == "closest-side" ? min(c, of - c) : t == "farthest-side" ? max(c, of - c) : size(t, other)
    if name == "circle"
      t = isempty(lead) ? "closest-side" : lead[1]
      rx = t == "closest-side" ? min(ax, w - ax, ay, h - ay) : t == "farthest-side" ? max(ax, w - ax, ay, h - ay) : size(t, hypot(w, h) / sqrt(2))
      ry = rx
    else
      rx = far(isempty(lead) ? "closest-side" : lead[1], ax, w, w)
      ry = far(length(lead) > 1 ? lead[2] : "closest-side", ay, h, h)
    end
    (rx === nothing || ry === nothing) && return nothing
    return (ax - rx, ay - ry, 2rx, 2ry, (rx, ry, rx, ry, rx, ry, rx, ry), "")
  elseif name == "polygon"
    pts = String[]
    for part in split_top(inside)
      ws = terms(strip(part))
      length(ws) == 2 || continue   # the first part can be how the shape is filled
      px_, py_ = size(ws[1], w), size(ws[2], h)
      (px_ === nothing || py_ === nothing) && return nothing
      push!(pts, "$(px_) $(py_)")
    end
    length(pts) < 3 && return nothing
    return (0.0, 0.0, w, h, SQUARE, "M " * join(pts, " L ") * " Z")
  elseif name == "path"
    d = match(r"[\"']([^\"']*)[\"']", inside)
    return d === nothing ? nothing : (0.0, 0.0, w, h, SQUARE, String(d[1]))
  end
  nothing
end
side4(ws) = length(ws) == 1 ? [ws[1], ws[1], ws[1], ws[1]] : length(ws) == 2 ? [ws[1], ws[2], ws[1], ws[2]] : length(ws) == 3 ? [ws[1], ws[2], ws[3], ws[2]] : ws[1:min(4, end)]

"How the box `b`, `w` by `h` px with its corner at `(x, y)`, is moved, turned or made bigger by its style: the six numbers of a matrix"
matrix(s::Style, x, y, w, h) = begin
  m = SAME
  for list in (s.translate, s.rotate, s.scale, s.transform), t in list
    m = times(m, t.kind == :move ? shift(px(t.x, w), px(t.y, h)) : t.kind == :spin ? (cos(t.n[1]), sin(t.n[1]), -sin(t.n[1]), cos(t.n[1]), 0.0, 0.0) : t.n)
  end
  m == SAME && return m
  # It turns round a point of the box
  ox, oy = x + px(s.origin[1], w), y + px(s.origin[2], h)
  times(times(shift(ox, oy), m), shift(-ox, -oy))
end

"True for a box that's drawn as one piece, with what's in it in an order of its own"
apart(b::Box) = begin
  s = b.style
  b.kind in (:text, :break) && return false
  (s.position != :static && s.zindex != NO_Z) || s.position in (:fixed, :sticky) || (b.item && s.zindex != NO_Z) || s.opacity < 1 ||
    !isempty(s.transform) || !isempty(s.translate) || !isempty(s.rotate) || !isempty(s.scale) || !isempty(s.filter) || s.blend != :normal || s.isolate ||
    !isempty(s.clippath) || !isempty(s.mask) || (b.element !== nothing && b.element.parent === nothing)
end

"The rectangle that the items are in, or nothing when one of them is moved"
bounds(items) = begin
  x0 = y0 = Inf
  x1 = y1 = -Inf
  grow(x, y, w, h) = (x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x + w); y1 = max(y1, y + h))
  for i in items
    i isa Move && return nothing
    i isa Glyphs ? grow(i.x - i.font.size, i.y - 2i.font.size, i.w + 2i.font.size, 3i.font.size) :
    i isa Shadow ? (i.inset || (far = abs(i.dx) + abs(i.dy) + i.spread + 3i.blur; grow(i.x - far, i.y - far, i.w + 2far, i.h + 2far))) :
    i isa Union{Fill,Edge,Picture,Backing,Ring,Stroke,Widget,Drawing} ? grow(i.x, i.y, i.w, i.h) : nothing
  end
  isfinite(x0) ? (x0, y0, x1 - x0, y1 - y0) : (0.0, 0.0, 0.0, 0.0)
end

"""
Add what `b` draws, and what's in it. `(ox, oy)` is the corner of the border of
the box that `b` is in. A box that isn't part of the text of the box that
it's in is kept apart, and drawn when its turn comes.
"""
emit!(l::List, b::Box, ox, oy; cuts=nothing) = begin
  s = b.style
  whole = apart(b)
  (whole || (b.kind != :text && (s.position != :static || s.float != :none))) || return draw!(l, b, ox, oy)
  order = l.orders[end]
  # It's drawn before the boxes in it that are kept apart too
  met = (l.met += 1)
  saved = l.items
  l.items = Item[]
  # What cuts the text here cuts this too. A box with a place of its own is cut only by what cuts the box that it's placed from.
  limit = cuts === nothing ? length(l.clips) : max(order.clips, min(cuts, length(l.clips)))
  open = l.clips[order.clips+1:limit]
  append!(l.items, open)
  kept = l.seen
  l.seen = l.seen[1:limit]
  if whole
    piece!(l, b, ox, oy)
  else
    # The floats in it are drawn over the boxes of its text
    push!(l.floats, Vector{Item}[])
    draw!(l, b, ox, oy)
    foreach(f -> append!(l.items, f), pop!(l.floats))
  end
  foreach(_ -> push!(l.items, Unclip()), open)
  l.seen = kept
  made = l.items
  l.items = saved
  z = s.zindex == NO_Z || (s.position == :static && !b.item) ? 0 : s.zindex
  if s.position == :static && s.float != :none && !whole
    # A float is drawn with the box that it's in, after the boxes of that box's text
    push!(l.floats[end], made)
  else
    push!(order.pieces, (z < 0 ? 1 : 4, z, met, made))
  end
  nothing
end

"Add the box `b` as one piece, with what's in it in its own order: see `apart`"
piece!(l::List, b::Box, ox, oy) = begin
  s = b.style
  s.opacity <= 0 && return
  dx, dy = nudge(s)
  x, y = ox + b.x + dx, oy + b.y + dy
  at = get(l.still, b, nothing)
  if at !== nothing
    b.still[1] && (x = at[1])
    b.still[2] && (y = at[2])
  end
  w, h = b.width, b.height
  m = matrix(s, x, y, w, h)
  saved, was = l.items, l.matrix
  l.items = Item[]
  l.matrix = times(was, m)
  push!(l.orders, Order(Tuple{Int,Int,Int,Vector{Item}}[], length(l.clips)))
  heading, mark = l.heading, l.mark
  l.heading = b
  l.mark = 0
  push!(l.floats, Vector{Item}[])
  draw!(l, b, ox, oy)
  floats = pop!(l.floats)
  order = pop!(l.orders)
  # What has a z-index under 0 is drawn over the box's own background and under its text
  sort!(order.pieces; by=x -> (x[1], x[2], x[3]), alg=MergeSort)
  own = l.items
  cut = min(l.mark, length(own))
  made = own[1:cut]
  foreach(p -> p[1] == 1 && append!(made, p[4]), order.pieces)
  append!(made, @view own[cut+1:end])
  foreach(f -> append!(made, f), floats)
  foreach(p -> p[1] != 1 && append!(made, p[4]), order.pieces)
  l.heading, l.mark = heading, mark
  l.items, l.matrix = saved, was
  # The piece, in what changes how it's drawn
  m == SAME || push!(l.items, Move(m))
  shape = isempty(s.clippath) ? nothing : cut_shape(s.clippath, w, h, s.size)
  shape === nothing || push!(l.items, Clip(x + shape[1], y + shape[2], shape[3], shape[4], shape[5], shape[6]))
  layered = s.opacity < 1 || s.blend != :normal || !isempty(s.filter) || !isempty(s.mask)
  layered && push!(l.items, Layer(s.opacity, s.blend, s.filter, isempty(s.filter) ? bounds(made) : nothing))
  append!(l.items, made)
  if !isempty(s.mask)
    # Only what's under the mask's picture stays
    push!(l.items, Layer(1.0, :dst_in, Effect[], nothing))
    mask = Style(image=[s.mask], repeat=[(:no_repeat, :no_repeat)], bgsize=Any[(Len(0, 1, 0, false), Len(0, 1, 0, false))], size=s.size)
    backdrop!(l, mask, 1, (x, y, w, h), (x, y, w, h), SQUARE)
    push!(l.items, Unlayer())
  end
  layered && push!(l.items, Unlayer())
  shape === nothing || push!(l.items, Unclip())
  m == SAME || push!(l.items, Unmove())
  nothing
end

"Add the letters of the text in `b`, in one colour: the shape that a background is cut to with `background-clip: text`"
ink!(l::List, b::Box, ox, oy) = begin
  x, y = ox + b.x, oy + b.y
  cx, cy = x + b.border[4] + b.padding[4], y + b.border[1] + b.padding[1]
  for line in b.lines, q in line.pieces
    if q.kind == :atom
      ink!(l, q.box, x, y)
    elseif q.kind == :text && !isempty(q.chars) && !q.space
      t = q.box.style
      glyphs!(l, font(t.family, t.size, t.weight, t.italic, t.stretch), q.chars, q.widths, cx + q.x, cy + q.y, 0xff000000)
    end
  end
  isempty(b.lines) && foreach(k -> k.kind in (:text, :inline, :break, :column) || placed(k) || ink!(l, k, x, y), b.children)
end

"Add the lines under, through and over the text of a piece that's `wide` px wide, with its first letter at `x` on the line at `base`"
underline!(l::List, t::Style, f::Font, x, base, wide) = begin
  thick = t.linethick > 0 ? t.linethick : max(1.0, round(f.thick))
  below = max(1.0, f.under) + (isauto(t.underoffset) ? 0.0 : px(t.underoffset, t.size))
  t.lines & 0x01 != 0 && push!(l.items, Stroke(x, round(base + below - thick / 2), wide, thick, t.linestyle, t.linecolor))
  t.lines & 0x04 != 0 && push!(l.items, Stroke(x, round(base - f.ascent), wide, thick, t.linestyle, t.linecolor))
  t.lines & 0x02 != 0 && push!(l.items, Stroke(x, round(base - f.xheight / 2 - thick / 2), wide, thick, t.linestyle, t.linecolor))
end

"Add the picture of the box `b`, whose content is the rectangle `(cx, cy, iw, ih)`, as its style's `object-fit` says"
picture!(l::List, b::Box, image, cx, cy, iw, ih, radii) = begin
  s = b.style
  nw, nh = b.natural
  dw, dh = iw, ih
  if s.objectfit != :fill && nw > 0 && nh > 0
    k = s.objectfit == :contain ? min(iw / nw, ih / nh) : s.objectfit == :cover ? max(iw / nw, ih / nh) : s.objectfit == :none ? 1.0 : min(1.0, iw / nw, ih / nh)
    dw, dh = nw * k, nh * k
  end
  at = (cx + px(s.objectat[1], iw - dw), cy + px(s.objectat[2], ih - dh), dw, dh)
  # A drawing from an SVG file isn't stretched: it's as big as fits in the rectangle, or as covers it, with its own shape
  if b.keeps !== nothing && nw > 0 && nh > 0
    ax, ay, covers = b.keeps
    k = covers ? max(dw / nw, dh / nh) : min(dw / nw, dh / nh)
    at = (at[1] + ax * (dw - nw * k), at[2] + ay * (dh - nh * k), nw * k, nh * k)
  end
  sharp = s.rendering == :pixelated
  push!(l.items, image isa Board ? Sketch(cx, cy, iw, ih, radii, image, at..., sharp) : image isa Reel ? Moving(cx, cy, iw, ih, radii, image, l.now, at..., sharp) :
                 Picture(cx, cy, iw, ih, radii, image, at..., sharp))
end

"""
Add what stands for a video that plays on another site, in the frame `b`
whose content is the rectangle `(cx, cy, iw, ih)`: the video's picture, as
big as covers the frame, the video's name on a dark band at the top, and the
arrow that a player shows before it plays.
"""
poster!(l::List, b::Box, cx, cy, iw, ih, radii) = begin
  push!(l.items, Fill(cx, cy, iw, ih, radii, 0xff000000))
  found = b.picture
  if found !== nothing && found[1] > 0 && found[2] > 0
    k = max(iw / found[1], ih / found[2])
    dw, dh = found[1] * k, found[2] * k
    push!(l.items, Picture(cx, cy, iw, ih, radii, found[3], cx + (iw - dw) / 2, cy + (ih - dh) / 2, dw, dh, false))
  end
  f = font(b.style.family, 14.0, 500, false)
  edge = 12.0
  band = f.ascent + f.descent + 2edge
  if !isempty(b.text) && band < ih / 2 && iw > 6edge
    # A name that's too long for the frame ends with three dots
    chars = collect(b.text)
    widths = [drawn(f, c)[3] for c in chars]
    room = iw - 2edge
    if sum(widths) > room
      dots = drawn(f, '\u2026')[3]
      n = something(findlast(<=(room - dots), cumsum(widths)), 0)
      chars, widths = [chars[1:n]; '\u2026'], [widths[1:n]; dots]
    end
    push!(l.items, Fill(cx, cy, iw, band, SQUARE, 0x99000000))
    glyphs!(l, f, chars, widths, cx + edge, cy + edge + f.ascent, 0xffffffff)
  end
  push!(l.items, Widget(cx, cy, iw, ih, :poster, 1.0, 0xffffffff, 0x00000000))
end

"Add what the box `b` draws, and what's in it, in the order of the text. `(ox, oy)` is the corner of the border of the box that `b` is in."
draw!(l::List, b::Box, ox, oy) = begin
  s = b.style
  background = b !== l.behind
  dx, dy = nudge(s)
  x, y = ox + b.x + dx, oy + b.y + dy
  at = get(l.still, b, nothing)
  if at !== nothing
    b.still[1] && (x = at[1])
    b.still[2] && (y = at[2])
  end
  w, h = b.width, b.height
  place!(l, b, x, y, w, h)
  b.kind in (:block, :cell, :caption) && isempty(l.before) && (l.before = "\n")
  b.kind == :cell && b.col > 1 && l.before != "\t" && !isempty(l.words) && (l.before = "\t")
  # A cell with nothing in it has no border and no background when its style says
  bare = b.kind == :cell && !s.emptycells && !s.collapse && isempty(b.lines) && isempty(b.children)
  if !bare
    text = any(==(:text), s.bgclip) && !isempty(s.image)
    text && push!(l.items, Layer(1.0, :normal, Effect[], (x, y, w, h)))
    if b.notch == (0.0, 0.0, 0.0)
      decorate!(l, s, x, y, w, h, b.border, b.padding; background)
    else
      # The border of a <fieldset> starts at the middle of its <legend>, and is cut where the legend is
      down, from, to = b.notch
      hole = "M0 0 H$(w) V$(h) H0 Z M$(from) 0 V$(down + b.border[1] + 1) H$(to) V0 Z"
      push!(l.items, Clip(x, y, w, h, SQUARE, hole))
      decorate!(l, s, x, y + down, w, h - down, b.border, b.padding; background)
      push!(l.items, Unclip())
    end
    if text
      # The background shows only where the letters are
      push!(l.items, Layer(1.0, :dst_in, Effect[], (x, y, w, h)))
      ink!(l, b, ox + dx, oy + dy)
      push!(l.items, Unlayer(), Unlayer())
    end
  end
  l.heading === b && (l.mark = length(l.items))
  b.element !== nothing && b.element.tag == "a" && link!(l, b.link, x, y, w, h)
  cx, cy = x + b.border[4] + b.padding[4], y + b.border[1] + b.padding[1]
  iw, ih = w - b.border[2] - b.border[4] - b.padding[2] - b.padding[4], h - b.border[1] - b.border[3] - b.padding[1] - b.padding[3]
  if b.kind == :image
    radii = inner(corners(s, w, h), b.border)
    if b.widget == :svg
      s.visible && iw > 0 && ih > 0 && push!(l.items, Clip(cx, cy, iw, ih, radii), Drawing(cx, cy, iw, ih, b.element, b.picture), Unclip())
    elseif b.widget == :canvas
      # What a script has drawn on it. With no script, a canvas shows nothing.
      sketch = s.visible && iw > 0 && ih > 0 ? found(b.element) : nothing
      sketch === nothing || picture!(l, b, sketch, cx, cy, iw, ih, radii)
    elseif b.widget == :poster
      s.visible && iw > 0 && ih > 0 && poster!(l, b, cx, cy, iw, ih, radii)
    elseif b.widget != :none
      # A video's picture is a `Frame` of video.jl, which the box keeps for as long as the page is drawn
      b.picture !== nothing && s.visible && iw > 0 && ih > 0 && picture!(l, b, b.picture isa Ptr ? b.picture : b.picture.image, cx, cy, iw, ih, radii)
      # Over a video's picture, the arrow that starts it shows when the video has its buttons and doesn't play
      if s.visible && iw > 0 && ih > 0 && !(b.widget == :video && b.picture !== nothing && !(haskey(b.element.attrs, "controls") && b.value != 1.0))
        color = b.widget == :color ? something(colour(b.text), 0xff000000) : s.color
        # Over a video's picture, only the arrow that starts it is drawn
        push!(l.items, Widget(cx, cy, iw, ih, b.widget, b.widget == :video && b.picture !== nothing ? 1.0 : b.value, color isa UInt32 ? color : s.color, s.accent))
      end
    elseif b.picture !== nothing && s.visible && iw > 0 && ih > 0
      picture!(l, b, b.picture, cx, cy, iw, ih, radii)
    elseif s.visible && iw > 2 && ih > 2 && b.element !== nothing
      # A picture that there isn't shows where it would be, as a browser shows it
      push!(l.items, Edge(cx, cy, iw, ih, SQUARE, (1.0, 1.0, 1.0, 1.0), ntuple(_ -> MISSING, 4), ntuple(_ -> :solid, 4)))
      # The words that stand for the picture show in its box when they fit
      f = font(s.family, s.size, s.weight, s.italic, s.stretch)
      widths = [drawn(f, c)[3] for c in b.text]
      if !isempty(b.text) && sum(widths) + 4 <= iw + 0.5 && f.ascent + f.descent + 4 <= ih + 0.5
        glyphs!(l, f, collect(b.text), widths, cx + 2, cy + 2 + f.ascent, s.color)
      end
    end
    link!(l, b.link, x, y, w, h)
  end
  clipped = s.overflow != :visible && b.kind != :image
  if clipped
    clip = Clip(x + b.border[4], y + b.border[1], w - b.border[2] - b.border[4], h - b.border[1] - b.border[3], inner(corners(s, w, h), b.border))
    push!(l.items, clip)
    push!(l.clips, clip)
    # The words in it can be seen where it and each box round it that cuts let them be
    cx0, cy0, cw, ch = around(l, clip.x, clip.y, clip.w, clip.h)
    o = isempty(l.seen) ? OPEN : l.seen[end]
    push!(l.seen, (max(o[1], cx0), max(o[2], cy0), min(o[3], cx0 + cw), min(o[4], cy0 + ch)))
  end
  isempty(b.over) || (l.corners[b] = (x, y, length(l.clips)))
  # In lines of text, the boxes with a place of their own come first. Among blocks, each comes where the HTML has it.
  isempty(b.lines) || placed!(l, b, x, y)
  # The bullet or the number of a list item, to the left of its first line
  if (!isempty(b.marker) || b.markerimage !== nothing) && s.visible
    ms = something(b.markerstyle, s)
    f = font(ms.family, ms.size, ms.weight, ms.italic, ms.stretch)
    base = y + something(first_baseline(b), b.border[1] + b.padding[1] + f.ascent)
    # The sizes and the places are the ones that Safari draws a bullet and a number with
    rise = round(Int, f.ascent)
    off = rise * 2 ÷ 3
    if b.markerimage !== nothing
      mw, mh, image = Float64(b.markerimage[1]), Float64(b.markerimage[2]), b.markerimage[3]
      push!(l.items, Picture(cx - mw - 7, base - mh, mw, mh, SQUARE, image, cx - mw - 7, base - mh, mw, mh, false))
    elseif s.listtype in (:disc, :circle, :square) && b.markerstyle === nothing
      d = Float64((off + 1) ÷ 2)
      bx, by = cx - off - 7, base - rise + 3 * (rise - off) ÷ 2
      r = d / 2
      s.listtype == :disc ? push!(l.items, Fill(bx, by, d, d, (r, r, r, r, r, r, r, r), ms.color)) :
      s.listtype == :square ? push!(l.items, Fill(bx, by, d, d, SQUARE, ms.color)) :
      push!(l.items, Edge(bx, by, d, d, (r, r, r, r, r, r, r, r), (1.0, 1.0, 1.0, 1.0), ntuple(_ -> ms.color, 4), ntuple(_ -> :solid, 4)))
    else
      widths = [drawn(f, c)[3] for c in b.marker]
      glyphs!(l, f, collect(b.marker), widths, cx - sum(widths) - drawn(f, ' ')[3], base, ms.color)
    end
  end
  if b.cols === nothing
    inside!(l, b, x, y, cx, cy)
  else
    # Text in columns is laid out as one column: each column of the page is a piece of it, moved to its place
    cols = b.cols
    saved, links, words = l.items, length(l.links), length(l.words)
    l.items = Item[]
    inside!(l, b, x, y, cx, cy)
    made = l.items
    l.items = saved
    column(top) = something(findlast(from -> from <= top - cy + 0.01, cols.starts), 1)
    by(i) = ((i - 1) * (cols.wide + cols.gap), -cols.starts[i])
    for i in eachindex(cols.starts)
      mx, my = by(i)
      push!(l.items, Clip(cx + mx - cols.gap / 2, cy, cols.wide + cols.gap, cols.ends[i] - cols.starts[i] + 0.01, SQUARE), Move(shift(mx, my)))
      append!(l.items, made)
      push!(l.items, Unmove(), Unclip())
      if i > 1 && s.colrulestyle != :none && s.colrule.px > 0 && alpha(s.colrulecolor) > 0
        push!(l.items, Stroke(cx + mx - cols.gap / 2 - s.colrule.px / 2, cy, s.colrule.px, cols.high, s.colrulestyle == :solid ? :upright : s.colrulestyle, s.colrulecolor))
      end
    end
    for j in links+1:length(l.links)
      k = l.links[j]
      mx, my = by(column(k.top))
      l.links[j] = (left=k.left + mx, top=k.top + my, wide=k.wide, tall=k.tall, url=k.url)
    end
    for j in words+1:length(l.words)
      k = l.words[j]
      col = column(k.top)
      mx, my = by(col)
      # A column is cut to its own part of the page, inside what cuts the box of the columns
      o = isempty(l.seen) ? OPEN : l.seen[end]
      x0, y0, cw, ch = around(l, cx + mx - cols.gap / 2, cy, cols.wide + cols.gap, cols.ends[col] - cols.starts[col] + 0.01)
      l.words[j] = (before=k.before, top=k.top + my, tall=k.tall, edges=k.edges .+ mx, letters=k.letters, from=k.from,
                    seen=(max(o[1], x0), max(o[2], y0), min(o[3], x0 + cw), min(o[4], y0 + ch)))
    end
  end
  # The arrows of a list of choices
  b.widget == :select && s.visible && push!(l.items, Widget(x + w - b.border[2] - 18, y + b.border[1], 16.0, h - b.border[1] - b.border[3], :select, 0.0, s.color, s.accent))
  if clipped
    pop!(l.clips)
    pop!(l.seen)
    push!(l.items, Unclip())
  end
  nothing
end

"Add what's in the box `b`: its lines of text, or the boxes in it. `(x, y)` is the corner of its border, and `(cx, cy)` of its content."
inside!(l::List, b::Box, x, y, cx, cy) = begin
  for line in b.lines
    for sp in line.spans
      k = sp.box
      widths = (k.border[1], sp.last ? k.border[2] : 0.0, k.border[3], sp.first ? k.border[4] : 0.0)
      decorate!(l, k.style, cx + sp.left, cy + sp.top, sp.right - sp.left, sp.bottom - sp.top, widths)
      place!(l, k, cx + sp.left, cy + sp.top, sp.right - sp.left, sp.bottom - sp.top)
      k.element !== nothing && k.element.tag == "a" && link!(l, k.link, cx + sp.left, cy + sp.top, sp.right - sp.left, sp.bottom - sp.top)
    end
    for q in line.pieces
      if q.kind == :atom
        emit!(l, q.box, x, y)
      elseif q.kind == :text && !isempty(q.chars)
        t = q.box.style
        f = font(t.family, t.size, t.weight, t.italic, t.stretch)
        px0, base = cx + q.x, cy + q.y
        top, tall = base - f.ascent, f.ascent + f.descent
        words!(l, line, q, px0, top, tall)
        (t.visible && t.size > 0) || continue
        ink = t.textfill == CURRENT ? t.color : t.textfill
        if !q.space
          for sh in Iterators.reverse(t.textshadow)
            c = sh.color == CURRENT ? t.color : sh.color
            alpha(c) > 0 && glyphs!(l, f, q.chars, q.widths, px0 + sh.dx, base + sh.dy, c; blur=sh.blur)
          end
          alpha(ink) > 0 && glyphs!(l, f, q.chars, q.widths, px0, base, ink)
          line_ = t.strokecolor == CURRENT ? t.color : t.strokecolor
          t.stroke.px > 0 && alpha(line_) > 0 && glyphs!(l, f, q.chars, q.widths, px0, base, line_; stroke=t.stroke.px)
        end
        t.lines != 0 && q.width > 0 && alpha(t.linecolor) > 0 && underline!(l, t, f, px0, base, q.width)
      end
    end
    # A line that a <br> ended is a line of its own when the words are copied
    line.hard && (l.before = "\n")
  end
  if isempty(b.lines)
    for k in b.children
      placed(k) ? placed!(l, b, k, x, y) : k.kind == :inline ? placed!(l, k, x, y) : k.kind in (:text, :break, :column) || emit!(l, k, x, y)
    end
  else
    each_float(k -> emit!(l, k, x, y), b)
    l.before = "\n"
  end
end

"""
What to draw of the page whose <html> element has the box `root`, which is
laid out `wide` px wide and `tall` px tall. `pictures` gives the picture of an
address, as `boxes` takes it.
"""
list(root::Box, wide, tall; pictures=src -> nothing, base="", at=nothing) = begin
  l = List(Item[], Link[], Words[], Float64(wide), Float64(tall), 0x00000000, pictures, "", nothing, nothing, Clip[], Order[], nothing, 0,
           IdDict{Box,Tuple{Float64,Float64}}(), IdDict{Box,Tuple{Float64,Float64,Int}}(), SAME, 0, String(base), Place[], Vector{Vector{Item}}[], Ref{Any}(at), NTuple{4,Float64}[])
  # The background of the page is the <html> element's, or the <body>'s when that has none
  body = findfirst(k -> k.element !== nothing && k.element.tag == "body", root.children)
  from = alpha(root.style.background) > 0 || !isempty(root.style.image) || body === nothing ? root : root.children[body]
  s = from.style
  l.background = s.background
  none = (0.0, 0.0, 0.0, 0.0)
  backgrounds!(l, s, 0.0, 0.0, l.wide, l.tall, SQUARE, none, none)
  l.behind = from
  piece!(l, root, 0.0, 0.0)
  l
end

"The colour `c` over the colour `under`, which has no see-through part, as `share` of `c` and the rest of `under`"
over(under::UInt32, c::UInt32, share=alpha(c)) = begin
  share >= 1 && return c | 0xff000000
  share <= 0 && return under
  mix(k) = round(UInt32, ((under >> k) & 0xff) * (1 - share) + ((c >> k) & 0xff) * share) << k
  0xff000000 | mix(16) | mix(8) | mix(0)
end

"""
The one colour that the page shows along the line `y` px down it, or nothing.
It's looked at in five points across the page, and it's the colour of three
or more of them. A point under a picture, a gradient or a drawing has no one
colour. `under` is what shows where the page draws nothing. What's turned
or skewed is left out, and so is text, which is too thin to colour the line.
"""
edge_colour(l::List, y; under=0xffffffff) = begin
  at = Float64(y) + 0.5
  xs = [l.wide * k / 4 for k in 0:4]
  xs[1], xs[end] = 0.5, l.wide - 0.5
  base = over(under, l.background)
  seen = Union{UInt32,Nothing}[base for _ in xs]
  m = SAME
  moves = NTuple{6,Float64}[]
  shares = Float64[1.0]          # how much of each piece that's drawn as one shows
  cuts = NTuple{4,Float64}[]     # the rectangles that what's drawn is cut to
  for i in l.items
    if i isa Move
      push!(moves, m)
      m = times(m, i.m)
    elseif i isa Unmove
      isempty(moves) || (m = pop!(moves))
    elseif i isa Layer
      push!(shares, shares[end] * i.opacity)
    elseif i isa Unlayer
      length(shares) > 1 && pop!(shares)
    elseif i isa Clip
      # A cut that's turned is taken as no cut
      push!(cuts, something(placed_area(m, i.x, i.y, i.w, i.h), (-1e9, -1e9, 2e9, 2e9)))
    elseif i isa Unclip
      isempty(cuts) || pop!(cuts)
    elseif i isa Fill || i isa Backing || i isa Picture || i isa Sketch || i isa Moving || i isa Drawing || i isa Widget
      r = placed_area(m, i.x, i.y, i.w, i.h)
      (r === nothing || !(r[2] <= at < r[2] + r[4])) && continue
      share = i isa Fill ? alpha(i.color) * shares[end] : 0.0
      for (k, x) in enumerate(xs)
        (r[1] <= x < r[1] + r[3] && all(c -> c[1] <= x < c[1] + c[3] && c[2] <= at < c[2] + c[4], cuts)) || continue
        seen[k] = !(i isa Fill) ? nothing : share >= 1 ? i.color | 0xff000000 : seen[k] === nothing ? nothing : over(seen[k], i.color, share)
      end
    end
  end
  for c in unique(seen)
    c !== nothing && count(==(c), seen) >= 3 && return c
  end
  nothing
end

"The rectangle `(x, y, w, h)` where the move `m` puts it, or nothing when `m` turns or skews it"
placed_area(m, x, y, w, h) = begin
  (m[2] == 0 && m[3] == 0) || return nothing
  (a, b), (c, d) = moved(m, x, y), moved(m, x + w, y + h)
  (min(a, c), min(b, d), abs(c - a), abs(d - b))
end

# --- drawing ------------------------------------------------------------------------------

rect(x, y, w, h) = Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h)))
skia(m) = Ref(Skia.sk_matrix_t(Float32(m[1]), Float32(m[3]), Float32(m[5]), Float32(m[2]), Float32(m[4]), Float32(m[6]), 0f0, 0f0, 1f0))

"A Skia path round a box with the corners `r`"
outline(x, y, w, h, r::Radii) = begin
  p = Skia.sk_path_new()
  if r == SQUARE
    Skia.sk_path_add_rect(p, rect(x, y, w, h), Skia.SK_PATH_DIRECTION_CW)
    return p
  end
  right, bottom = x + w, y + h
  corner(cx, cy, rx, ry, from) = begin
    oval = rect(cx - rx, cy - ry, 2rx, 2ry)
    rx > 0 && ry > 0 ? Skia.sk_path_arc_to_with_oval(p, oval, Float32(from), 90f0, false) : Skia.sk_path_line_to(p, Float32(cx), Float32(cy))
  end
  Skia.sk_path_move_to(p, Float32(x + r[1]), Float32(y))
  corner(right - r[3], y + r[4], r[3], r[4], -90)
  corner(right - r[5], bottom - r[6], r[5], r[6], 0)
  corner(x + r[7], bottom - r[8], r[7], r[8], 90)
  corner(x + r[1], y + r[2], r[1], r[2], 180)
  Skia.sk_path_close(p)
  p
end

"A Skia path of the border `widths` thick of a box: the shape of its outside, with the shape of its inside cut out"
ring(x, y, w, h, radii, widths) = begin
  t, r, b, l = widths
  out = outline(x, y, w, h, radii)
  hole = outline(x + l, y + t, max(0.0, w - l - r), max(0.0, h - t - b), inner(radii, widths))
  made = Skia.sk_path_new()
  Skia.sk_path_op(out, hole, Skia.sk_path_op_t(0), made)
  foreach(Skia.sk_path_delete, (out, hole))
  made
end

with_paint(f, color::UInt32) = begin
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  Skia.sk_paint_set_color(paint, color)
  Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(0))
  try f(paint) finally Skia.sk_paint_delete(paint) end
end

fill_shape(canvas, x, y, w, h, radii, paint) = begin
  if radii == SQUARE
    Skia.sk_canvas_draw_rect(canvas, rect(x, y, w, h), paint)
  else
    p = outline(x, y, w, h, radii)
    Skia.sk_canvas_draw_path(canvas, p, paint)
    Skia.sk_path_delete(p)
  end
end

clip_shape(canvas, x, y, w, h, radii) = begin
  if radii == SQUARE
    Skia.sk_canvas_clip_rect_with_operation(canvas, rect(x, y, w, h), Skia.SK_CLIP_OP_INTERSECT, true)
  else
    p = outline(x, y, w, h, radii)
    Skia.sk_canvas_clip_path_with_operation(canvas, p, Skia.SK_CLIP_OP_INTERSECT, true)
    Skia.sk_path_delete(p)
  end
end

"A Skia path through the points"
polygon(pts) = begin
  p = Skia.sk_path_new()
  Skia.sk_path_move_to(p, Float32(pts[1][1]), Float32(pts[1][2]))
  foreach(q -> Skia.sk_path_line_to(p, Float32(q[1]), Float32(q[2])), pts[2:end])
  Skia.sk_path_close(p)
  p
end

paint!(canvas, i::Fill) = with_paint(paint -> fill_shape(canvas, i.x, i.y, i.w, i.h, i.radii, paint), i.color)

"The dark side of a border that looks pressed in or raised, in the colour `c`: as dark as WebKit makes it"
darker(c::UInt32) = begin
  v = max((c >> 16) & 0xff, (c >> 8) & 0xff, c & 0xff) / 255
  k = v <= 0 ? 0.0 : max(0.0, (v - 0.33) / v)
  part(shift) = UInt32(round(((c >> shift) & 0xff) * k)) << shift
  (c & 0xff000000) | part(16) | part(8) | part(0)
end

"The colour that side `i` of a border is drawn in: a border that looks pressed in or raised has two sides darker"
shade(e::Edge, i) = begin
  st = e.styles[i]
  dark = st in (:inset, :groove) ? i in (1, 4) : st in (:outset, :ridge) ? i in (2, 3) : false
  dark ? darker(e.colors[i]) : e.colors[i]
end

"Draw a line `wide` thick from `a` to `z`, in dashes or dots"
dashes(canvas, a, z, wide, style, color) = with_paint(color) do paint
  Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(1))
  Skia.sk_paint_set_stroke_width(paint, Float32(wide))
  # A dot is as wide as the line, and a dash three times that
  gaps = style == :dotted ? Float32[0, 2wide] : Float32[3wide, 3wide]
  style == :dotted && Skia.sk_paint_set_stroke_cap(paint, Skia.sk_stroke_cap_t(1))
  effect = Skia.sk_path_effect_create_dash(gaps, Cint(2), 0f0)
  Skia.sk_paint_set_path_effect(paint, effect)
  p = Skia.sk_path_new()
  Skia.sk_path_move_to(p, Float32(a[1]), Float32(a[2]))
  Skia.sk_path_line_to(p, Float32(z[1]), Float32(z[2]))
  Skia.sk_canvas_draw_path(canvas, p, paint)
  Skia.sk_path_delete(p)
  Skia.sk_path_effect_unref(effect)
end

paint!(canvas, e::Edge) = begin
  x, y, w, h = e.x, e.y, e.w, e.h
  t, r, b, l = e.widths
  colors = ntuple(i -> shade(e, i), 4)
  shown = [i for i in 1:4 if e.widths[i] > 0 && alpha(colors[i]) > 0]
  isempty(shown) && return
  plain = all(i -> e.styles[i] in (:solid, :inset, :outset), shown)
  one = plain && all(i -> colors[i] == colors[shown[1]], shown)
  if e.radii == SQUARE && plain
    # Each side is a shape with slanted ends, so that two colours meet at a corner on a slant
    for i in shown
      pts = i == 1 ? ((x, y), (x + w, y), (x + w - r, y + t), (x + l, y + t)) :
            i == 2 ? ((x + w, y), (x + w, y + h), (x + w - r, y + h - b), (x + w - r, y + t)) :
            i == 3 ? ((x + w, y + h), (x, y + h), (x + l, y + h - b), (x + w - r, y + h - b)) :
                     ((x, y + h), (x, y), (x + l, y + t), (x + l, y + h - b))
      p = polygon(pts)
      with_paint(colors[i]) do paint
        # Sides of one colour that meet at a square corner show no seam without smoothing
        Skia.sk_paint_set_antialias(paint, false)
        Skia.sk_canvas_draw_path(canvas, p, paint)
      end
      Skia.sk_path_delete(p)
    end
    return
  end
  if one && length(shown) == 4
    made = ring(x, y, w, h, e.radii, e.widths)
    with_paint(paint -> Skia.sk_canvas_draw_path(canvas, made, paint), colors[1])
    Skia.sk_path_delete(made)
    return
  end
  # Each side is drawn alone, cut to its part of the box: the line from each corner of the outside to the corner of the inside is where two sides meet
  mx, my = x + w / 2, y + h / 2
  for i in shown
    # How far along the slanted lines the cut goes: to the middle of the box, or to where the two lines meet
    pts = if i == 1
      k = min((h / 2) / max(t, 1e-9), w / max(l + r, 1e-9))
      ((x, y), (x + w, y), (x + w - r * k, y + t * k), (x + l * k, y + t * k))
    elseif i == 2
      k = min((w / 2) / max(r, 1e-9), h / max(t + b, 1e-9))
      ((x + w, y), (x + w, y + h), (x + w - r * k, y + h - b * k), (x + w - r * k, y + t * k))
    elseif i == 3
      k = min((h / 2) / max(b, 1e-9), w / max(l + r, 1e-9))
      ((x + w, y + h), (x, y + h), (x + l * k, y + h - b * k), (x + w - r * k, y + h - b * k))
    else
      k = min((w / 2) / max(l, 1e-9), h / max(t + b, 1e-9))
      ((x, y + h), (x, y), (x + l * k, y + t * k), (x + l * k, y + h - b * k))
    end
    Skia.sk_canvas_save(canvas)
    p = polygon(pts)
    Skia.sk_canvas_clip_path_with_operation(canvas, p, Skia.SK_CLIP_OP_INTERSECT, true)
    Skia.sk_path_delete(p)
    st = e.styles[i]
    wide = e.widths[i]
    part(from, to, color) = begin
      # The part of the border from `from` to `to` of the way in from its outside
      a = map(v -> v * from, e.widths)
      z = map(v -> v * (to - from), e.widths)
      made = ring(x + a[4], y + a[1], w - a[2] - a[4], h - a[1] - a[3], inner(e.radii, a), z)
      with_paint(paint -> Skia.sk_canvas_draw_path(canvas, made, paint), color)
      Skia.sk_path_delete(made)
    end
    if st in (:dashed, :dotted)
      if e.radii == SQUARE
        a, z = i == 1 ? ((x, y + t / 2), (x + w, y + t / 2)) : i == 2 ? ((x + w - r / 2, y), (x + w - r / 2, y + h)) :
               i == 3 ? ((x, y + h - b / 2), (x + w, y + h - b / 2)) : ((x + l / 2, y), (x + l / 2, y + h))
        dashes(canvas, a, z, wide, st, colors[i])
      else
        # Along the middle of the border, round its corners
        half = map(v -> v / 2, e.widths)
        p = outline(x + half[4], y + half[1], w - half[2] - half[4], h - half[1] - half[3], inner(e.radii, half))
        with_paint(colors[i]) do paint
          Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(1))
          Skia.sk_paint_set_stroke_width(paint, Float32(wide))
          st == :dotted && Skia.sk_paint_set_stroke_cap(paint, Skia.sk_stroke_cap_t(1))
          effect = Skia.sk_path_effect_create_dash(st == :dotted ? Float32[0, 2wide] : Float32[3wide, 3wide], Cint(2), 0f0)
          Skia.sk_paint_set_path_effect(paint, effect)
          Skia.sk_canvas_draw_path(canvas, p, paint)
          Skia.sk_path_effect_unref(effect)
        end
        Skia.sk_path_delete(p)
      end
    elseif st == :double && wide >= 3
      part(0.0, 1 / 3, colors[i])
      part(2 / 3, 1.0, colors[i])
    elseif st in (:groove, :ridge)
      # Two lines, one dark and one light, that look cut into the page or raised from it
      light, dark = e.colors[i], darker(e.colors[i])
      first = (st == :groove) == (i in (1, 4)) ? dark : light
      part(0.0, 0.5, first)
      part(0.5, 1.0, first == dark ? light : dark)
    else
      part(0.0, 1.0, colors[i])
    end
    Skia.sk_canvas_restore(canvas)
  end
end

paint!(canvas, g::Glyphs) = begin
  if g.blob == C_NULL
    builder = Skia.sk_textblob_builder_new()
    n = length(g.ids)
    run = unsafe_load(Skia.sk_textblob_builder_alloc_run_pos_h(builder, g.font.raw, Cint(n), 0f0, C_NULL))
    GC.@preserve g begin
      unsafe_copyto!(run.glyphs, pointer(g.ids), n)
      unsafe_copyto!(run.pos, pointer(g.xs), n)
    end
    g.blob = Skia.sk_textblob_builder_make(builder)
    Skia.sk_textblob_builder_delete(builder)
  end
  with_paint(g.color) do paint
    blur = C_NULL
    if g.blur > 0
      blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, Float32(g.blur / 2), true)
      Skia.sk_paint_set_maskfilter(paint, blur)
    end
    if g.stroke > 0
      Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(1))
      Skia.sk_paint_set_stroke_width(paint, Float32(g.stroke))
    end
    Skia.sk_canvas_draw_text_blob(canvas, g.blob, Float32(g.x), Float32(g.y), paint)
    blur == C_NULL || Skia.sk_maskfilter_unref(blur)
  end
end

const SAMPLING = Skia.sk_sampling_options_t(0, false, Skia.sk_cubic_resampler_t(0f0, 0f0), Skia.SK_FILTER_MODE_LINEAR, Skia.SK_MIPMAP_MODE_LINEAR)
const NEAREST = Skia.sk_sampling_options_t(0, false, Skia.sk_cubic_resampler_t(0f0, 0f0), Skia.SK_FILTER_MODE_NEAREST, Skia.sk_mipmap_mode_t(0))

draw_image(canvas, image, x, y, w, h; sharp=false) = begin
  src = rect(0, 0, Skia.sk_image_get_width(image), Skia.sk_image_get_height(image))
  with_paint(0xffffffff) do paint
    Skia.sk_canvas_draw_image_rect(canvas, image, src, rect(x, y, w, h), Ref(sharp ? NEAREST : SAMPLING), paint, Skia.SRC_RECT_CONSTRAINT_FAST)
  end
end

paint!(canvas, i::Moving) = begin
  at = i.now[]
  shown = at === nothing ? i.reel.first : frame(i.reel, at)
  cut = i.radii != SQUARE || i.dx < i.x - 0.01 || i.dy < i.y - 0.01 || i.dx + i.dw > i.x + i.w + 0.01 || i.dy + i.dh > i.y + i.h + 0.01
  cut && (Skia.sk_canvas_save(canvas); clip_shape(canvas, i.x, i.y, i.w, i.h, i.radii))
  draw_image(canvas, shown.image, i.dx, i.dy, i.dw, i.dh; sharp=i.sharp)
  cut && Skia.sk_canvas_restore(canvas)
end

paint!(canvas, i::Sketch) = begin
  image = image!(i.board)
  image == C_NULL && return
  cut = i.radii != SQUARE || i.dx < i.x - 0.01 || i.dy < i.y - 0.01 || i.dx + i.dw > i.x + i.w + 0.01 || i.dy + i.dh > i.y + i.h + 0.01
  cut && (Skia.sk_canvas_save(canvas); clip_shape(canvas, i.x, i.y, i.w, i.h, i.radii))
  draw_image(canvas, image, i.dx, i.dy, i.dw, i.dh; sharp=i.sharp)
  cut && Skia.sk_canvas_restore(canvas)
end

paint!(canvas, i::Picture) = begin
  i.image == C_NULL && return
  cut = i.radii != SQUARE || i.dx < i.x - 0.01 || i.dy < i.y - 0.01 || i.dx + i.dw > i.x + i.w + 0.01 || i.dy + i.dh > i.y + i.h + 0.01
  cut && (Skia.sk_canvas_save(canvas); clip_shape(canvas, i.x, i.y, i.w, i.h, i.radii))
  draw_image(canvas, i.image, i.dx, i.dy, i.dw, i.dh; sharp=i.sharp)
  cut && Skia.sk_canvas_restore(canvas)
end

# --- gradients ----------------------------------------------------------------------------

"""
Skia's shader for the gradient `g` over a rectangle `w` by `h` px whose corner
is at `(x, y)`, where an em is `em` px. The caller unrefs it. It's C_NULL for
a gradient that can't be drawn.
"""
shader(g::Blend, x, y, w, h, em) = begin
  n = length(g.colors)
  # How long the line that the colours run along is, and where it starts
  cx, cy = x + g.cx * w, y + g.cy * h
  rx = ry = 0.0
  long = 1.0
  dx, dy = 0.0, 0.0
  if g.kind == :linear
    a = deg2rad(g.angle)
    dx, dy = sin(a), -cos(a)
    long = abs(w * dx) + abs(h * dy)
  elseif g.kind == :radial
    near = (min(g.cx * w, w - g.cx * w), min(g.cy * h, h - g.cy * h))
    far = (max(g.cx * w, w - g.cx * w), max(g.cy * h, h - g.cy * h))
    ws = split(lowercase(g.size))
    circle = "circle" in ws
    lens = [l for l in (len(t, PLAIN) for t in ws) if l !== nothing && !l.auto]
    how = something(findfirst(t -> t in ("closest-side", "farthest-side", "closest-corner", "farthest-corner", "contain", "cover"), ws), 0)
    how = how == 0 ? "farthest-corner" : ws[how] == "contain" ? "closest-side" : ws[how] == "cover" ? "farthest-corner" : ws[how]
    if !isempty(lens)
      rx = px(flat(lens[1], em), w)
      ry = length(lens) > 1 ? px(flat(lens[2], em), h) : rx
    elseif circle
      rx = ry = how == "closest-side" ? min(near...) : how == "farthest-side" ? max(far...) : how == "closest-corner" ? hypot(near...) : hypot(far...)
    else
      rx, ry = how == "closest-side" ? near : how == "farthest-side" ? far : how == "closest-corner" ? near .* sqrt(2) : far .* sqrt(2)
    end
    (rx > 0 && ry > 0) || return C_NULL
    long = rx
  end
  # Where each colour is, as a share of the line. One with no place is evenly between the ones that have one.
  at = Float64[st === nothing ? NaN : st isa Len ? px(flat(st, em), long) / long : Float64(st) for st in g.stops]
  isnan(at[1]) && (at[1] = 0.0)
  isnan(at[end]) && (at[end] = max(1.0, maximum(filter(!isnan, at); init=0.0)))
  i = 1
  while i < n
    j = i + 1
    while isnan(at[j]) j += 1 end
    for k in i+1:j-1
      at[k] = at[i] + (at[j] - at[i]) * (k - i) / (j - i)
    end
    i = j
  end
  for k in 2:n
    at[k] = max(at[k], at[k-1])
  end
  # A colour that's fully see-through takes the colour of each neighbour, so that no grey shows between them
  colors, places = UInt32[], Float64[]
  for k in 1:n
    c = g.colors[k]
    if alpha(c) == 0 && n > 1
      k > 1 && (push!(colors, g.colors[k-1] & 0x00ffffff); push!(places, at[k]))
      k < n && (push!(colors, g.colors[k+1] & 0x00ffffff); push!(places, at[k]))
    else
      push!(colors, c)
      push!(places, at[k])
    end
  end
  # The colours of a gradient that starts again go from the first place to the last. Any other goes over the whole line, and past it when a place is.
  lo, hi = g.again ? (places[1], places[end]) : (min(places[1], 0.0), max(places[end], 1.0))
  hi - lo < 1e-6 && return C_NULL
  pos = Float32[(p - lo) / (hi - lo) for p in places]
  mode = Skia.sk_tile_mode_t(g.again ? 1 : 0)
  count = Cint(length(colors))
  if g.kind == :linear
    mx, my = x + w / 2, y + h / 2
    sx, sy = mx - dx * long / 2, my - dy * long / 2
    points = [Skia.sk_point_t(Float32(sx + dx * long * lo), Float32(sy + dy * long * lo)), Skia.sk_point_t(Float32(sx + dx * long * hi), Float32(sy + dy * long * hi))]
    Skia.sk_shader_new_linear_gradient(points, colors, pos, count, mode, C_NULL)
  elseif g.kind == :radial
    # A circle from `lo` to `hi` of the way out, made as wide and as tall as the gradient's shape
    m = times(times(shift(cx, cy), (1.0, 0.0, 0.0, ry / rx, 0.0, 0.0)), shift(-cx, -cy))
    center = Ref(Skia.sk_point_t(Float32(cx), Float32(cy)))
    lo <= 0 ? Skia.sk_shader_new_radial_gradient(center, Float32(rx * hi), colors, pos, count, mode, skia(m)) :
              Skia.sk_shader_new_two_point_conical_gradient(center, Float32(rx * lo), center, Float32(rx * hi), colors, pos, count, mode, skia(m))
  else
    # Skia starts at the right, and CSS at the top
    r = deg2rad(g.angle - 90)
    m = times(times(shift(cx, cy), (cos(r), sin(r), -sin(r), cos(r), 0.0, 0.0)), shift(-cx, -cy))
    Skia.sk_shader_new_sweep_gradient(Ref(Skia.sk_point_t(Float32(cx), Float32(cy))), colors, pos, count, mode, Float32(360lo), Float32(360hi), skia(m))
  end
end

"A picture of one tile of a gradient, `w` by `h` px, with two pixels to the px"
tile(g::Blend, w, h, em) = begin
  k = min(2.0, 2048 / max(w, h))
  pw, ph = max(1, ceil(Int, w * k)), max(1, ceil(Int, h * k))
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, pw, ph))
  GC.@preserve info begin
    surface = Skia.sk_surface_make_raster_n32_premul(pointer_from_objref(info), C_NULL)
    surface == C_NULL && return C_NULL
    canvas = Skia.sk_surface_get_canvas(surface)
    Skia.sk_canvas_clear(canvas, 0x00000000)
    Skia.sk_canvas_scale(canvas, Float32(pw / w), Float32(ph / h))
    made = shader(g, 0.0, 0.0, w, h, em)
    if made != C_NULL
      with_paint(0xffffffff) do paint
        Skia.sk_paint_set_shader(paint, made)
        Skia.sk_canvas_draw_rect(canvas, rect(0, 0, w, h), paint)
      end
      Skia.sk_shader_unref(made)
    end
    image = Skia.sk_surface_make_image_snapshot(surface)
    Skia.sk_surface_unref(surface)
    Ptr{Cvoid}(image)
  end
end

paint!(canvas, i::Backing) = begin
  Skia.sk_canvas_save(canvas)
  clip_shape(canvas, i.x, i.y, i.w, i.h, i.radii)
  tw, th = i.tw, i.th
  across, down = i.repeat[1] == :repeat, i.repeat[2] == :repeat
  # One tile that covers the box, or that isn't drawn again, is drawn as it is
  once = (!across || (i.ox <= i.x + 0.01 && i.ox + tw >= i.x + i.w - 0.01)) && (!down || (i.oy <= i.y + 0.01 && i.oy + th >= i.y + i.h - 0.01))
  if i.source isa Blend && once
    made = shader(i.source, i.ox, i.oy, tw, th, i.em)
    if made != C_NULL
      with_paint(0xffffffff) do paint
        Skia.sk_paint_set_shader(paint, made)
        Skia.sk_canvas_draw_rect(canvas, rect(i.ox, i.oy, tw, th), paint)
      end
      Skia.sk_shader_unref(made)
    end
  else
    image = i.source isa Blend ? (i.tile == C_NULL && (i.tile = tile(i.source, tw, th, i.em)); i.tile) : i.source
    if image != C_NULL
      if once
        draw_image(canvas, image, i.ox, i.oy, tw, th)
      elseif i.gx > 0 || i.gy > 0
        # Tiles with room between them
        sx, sy = tw + i.gx, th + i.gy
        x0 = across ? i.ox - ceil((i.ox - i.x) / sx) * sx : i.ox
        y0 = down ? i.oy - ceil((i.oy - i.y) / sy) * sy : i.oy
        for r in 0:(down ? min(400, ceil(Int, (i.y + i.h - y0) / sy)) : 1)-1, c in 0:(across ? min(400, ceil(Int, (i.x + i.w - x0) / sx)) : 1)-1
          draw_image(canvas, image, x0 + c * sx, y0 + r * sy, tw, th)
        end
      else
        iw, ih = Skia.sk_image_get_width(image), Skia.sk_image_get_height(image)
        m = (tw / iw, 0.0, 0.0, th / ih, i.ox, i.oy)
        # 3 is Skia's way to draw nothing outside the one tile
        made = Skia.sk_image_make_shader(image, Skia.sk_tile_mode_t(across ? 1 : 3), Skia.sk_tile_mode_t(down ? 1 : 3), Ref(SAMPLING), skia(m))
        with_paint(0xffffffff) do paint
          Skia.sk_paint_set_shader(paint, made)
          Skia.sk_canvas_draw_rect(canvas, rect(i.x, i.y, i.w, i.h), paint)
        end
        Skia.sk_shader_unref(made)
      end
    end
  end
  Skia.sk_canvas_restore(canvas)
end

paint!(canvas, i::Ring) = begin
  made = shader(i.blend, i.x, i.y, i.w, i.h, i.em)
  made == C_NULL && return
  p = ring(i.x, i.y, i.w, i.h, i.radii, i.widths)
  with_paint(0xffffffff) do paint
    Skia.sk_paint_set_shader(paint, made)
    Skia.sk_canvas_draw_path(canvas, p, paint)
  end
  Skia.sk_path_delete(p)
  Skia.sk_shader_unref(made)
end

paint!(canvas, s::Shadow) = begin
  Skia.sk_canvas_save(canvas)
  shape = outline(s.x, s.y, s.w, s.h, s.radii)
  with_paint(s.color) do paint
    blur = C_NULL
    if s.blur > 0
      blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, Float32(s.blur / 2), true)
      Skia.sk_paint_set_maskfilter(paint, blur)
    end
    if s.inset
      # In the box: all that's outside a hole of the box's shape, which is smaller and moved
      Skia.sk_canvas_clip_path_with_operation(canvas, shape, Skia.SK_CLIP_OP_INTERSECT, true)
      far = abs(s.dx) + abs(s.dy) + abs(s.spread) + 3s.blur + 10
      all = Skia.sk_path_new()
      Skia.sk_path_add_rect(all, rect(s.x - far, s.y - far, s.w + 2far, s.h + 2far), Skia.SK_PATH_DIRECTION_CW)
      hole = outline(s.x + s.dx + s.spread, s.y + s.dy + s.spread, max(0.0, s.w - 2s.spread), max(0.0, s.h - 2s.spread), outer(s.radii, -s.spread))
      frame = Skia.sk_path_new()
      Skia.sk_path_op(all, hole, Skia.sk_path_op_t(0), frame)
      Skia.sk_canvas_draw_path(canvas, frame, paint)
      foreach(Skia.sk_path_delete, (all, hole, frame))
    else
      # The box's own shape is cut out, so that a see-through background doesn't show the shadow behind it
      Skia.sk_canvas_clip_path_with_operation(canvas, shape, Skia.SK_CLIP_OP_DIFFERENCE, true)
      fill_shape(canvas, s.x + s.dx - s.spread, s.y + s.dy - s.spread, s.w + 2s.spread, s.h + 2s.spread, outer(s.radii, s.spread), paint)
    end
    blur == C_NULL || Skia.sk_maskfilter_unref(blur)
  end
  Skia.sk_path_delete(shape)
  Skia.sk_canvas_restore(canvas)
end

paint!(canvas, s::Stroke) = begin
  if s.style == :upright
    return with_paint(paint -> Skia.sk_canvas_draw_rect(canvas, rect(s.x, s.y, s.w, s.h), paint), s.color)
  elseif s.w > s.h && s.style in (:dotted, :dashed)
    return dashes(canvas, (s.x, s.y + s.h / 2), (s.x + s.w, s.y + s.h / 2), s.h, s.style, s.color)
  elseif s.w <= s.h && s.style in (:dotted, :dashed)
    return dashes(canvas, (s.x + s.w / 2, s.y), (s.x + s.w / 2, s.y + s.h), s.w, s.style, s.color)
  end
  with_paint(s.color) do paint
    if s.style == :double
      Skia.sk_canvas_draw_rect(canvas, rect(s.x, s.y - s.h, s.w, s.h), paint)
      Skia.sk_canvas_draw_rect(canvas, rect(s.x, s.y + s.h, s.w, s.h), paint)
    elseif s.style == :wavy
      # Up and down, twice as far as the line is thick
      Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(1))
      Skia.sk_paint_set_stroke_width(paint, Float32(s.h))
      p = Skia.sk_path_new()
      step, rise = 2s.h + 2, s.h + 0.5
      mid = s.y + s.h / 2
      Skia.sk_path_move_to(p, Float32(s.x), Float32(mid))
      at, up = s.x, true
      while at < s.x + s.w
        Skia.sk_path_quad_to(p, Float32(at + step / 2), Float32(mid + (up ? -2rise : 2rise)), Float32(at + step), Float32(mid))
        at += step
        up = !up
      end
      Skia.sk_canvas_save(canvas)
      Skia.sk_canvas_clip_rect_with_operation(canvas, rect(s.x, s.y - 3rise, s.w, 6rise + s.h), Skia.SK_CLIP_OP_INTERSECT, true)
      Skia.sk_canvas_draw_path(canvas, p, paint)
      Skia.sk_canvas_restore(canvas)
      Skia.sk_path_delete(p)
    else
      Skia.sk_canvas_draw_rect(canvas, rect(s.x, s.y, s.w, s.h), paint)
    end
  end
end

# --- the parts of a form ------------------------------------------------------------------

const ACCENT = 0xff0a7aff
const TRACK = 0xffe2e2e4
const RIM = 0xff8e8e93

"Draw a line `wide` thick through the points, in one colour, with round ends"
line(canvas, pts, wide, color) = with_paint(color) do paint
  Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(1))
  Skia.sk_paint_set_stroke_width(paint, Float32(wide))
  Skia.sk_paint_set_stroke_cap(paint, Skia.sk_stroke_cap_t(1))
  Skia.sk_paint_set_stroke_join(paint, Skia.sk_stroke_join_t(1))
  p = Skia.sk_path_new()
  Skia.sk_path_move_to(p, Float32(pts[1][1]), Float32(pts[1][2]))
  foreach(q -> Skia.sk_path_line_to(p, Float32(q[1]), Float32(q[2])), pts[2:end])
  Skia.sk_canvas_draw_path(canvas, p, paint)
  Skia.sk_path_delete(p)
end

round_fill(canvas, x, y, w, h, r, color) = with_paint(paint -> fill_shape(canvas, x, y, w, h, (r, r, r, r, r, r, r, r), paint), color)

paint!(canvas, i::Widget) = begin
  x, y, w, h = i.x, i.y, i.w, i.h
  accent = alpha(i.accent) > 0 ? i.accent : ACCENT
  d = min(w, h)
  bx, by = x + (w - d) / 2, y + (h - d) / 2
  if i.kind == :checkbox
    r = d * 0.22
    if i.value > 0
      round_fill(canvas, bx, by, d, d, r, accent)
      line(canvas, ((bx + 0.24d, by + 0.52d), (bx + 0.43d, by + 0.71d), (bx + 0.77d, by + 0.29d)), max(1.2, d * 0.13), 0xffffffff)
    else
      round_fill(canvas, bx, by, d, d, r, RIM)
      round_fill(canvas, bx + 1, by + 1, d - 2, d - 2, max(0.0, r - 1), 0xffffffff)
    end
  elseif i.kind == :radio
    round_fill(canvas, bx, by, d, d, d / 2, i.value > 0 ? accent : RIM)
    i.value > 0 ? round_fill(canvas, bx + 0.3d, by + 0.3d, 0.4d, 0.4d, 0.2d, 0xffffffff) : round_fill(canvas, bx + 1, by + 1, d - 2, d - 2, d / 2 - 1, 0xffffffff)
  elseif i.kind == :range
    t = min(4.0, h)
    knob = min(h, 16.0)
    at = x + knob / 2 + (w - knob) * clamp(i.value, 0, 1)
    round_fill(canvas, x, y + (h - t) / 2, w, t, t / 2, TRACK)
    round_fill(canvas, x, y + (h - t) / 2, at - x, t, t / 2, accent)
    round_fill(canvas, at - knob / 2, y + (h - knob) / 2, knob, knob, knob / 2, RIM)
    round_fill(canvas, at - knob / 2 + 0.5, y + (h - knob) / 2 + 0.5, knob - 1, knob - 1, knob / 2 - 0.5, 0xffffffff)
  elseif i.kind in (:progress, :meter)
    t = min(h, max(6.0, h * 0.5))
    top = y + (h - t) / 2
    round_fill(canvas, x, top, w, t, t / 2, TRACK)
    # A bar with no value shows a part that's on its way
    full = isnan(i.value) ? 0.3 : clamp(i.value, 0, 1)
    full > 0 && round_fill(canvas, x, top, max(t, w * full), t, t / 2, i.kind == :meter ? 0xff34c759 : accent)
  elseif i.kind == :color
    round_fill(canvas, x + 2, y + 2, max(0.0, w - 4), max(0.0, h - 4), 2.0, i.color)
  elseif i.kind == :select
    # Two small arrows, up and down
    mx, my = x + w / 2, y + h / 2
    c = (i.color & 0x00ffffff) | 0xb0000000
    line(canvas, ((mx - 3, my - 2), (mx, my - 5), (mx + 3, my - 2)), 1.4, c)
    line(canvas, ((mx - 3, my + 2), (mx, my + 5), (mx + 3, my + 2)), 1.4, c)
  elseif i.kind in (:video, :audio, :poster)
    i.kind == :audio ? round_fill(canvas, x, y, w, h, min(h / 2, 27.0), 0xfff1f3f4) : (isnan(i.value) && with_paint(paint -> Skia.sk_canvas_draw_rect(canvas, rect(x, y, w, h), paint), 0xff000000))
    # The arrow that starts it
    size = i.kind == :audio ? min(h * 0.3, 12.0) : i.kind == :poster ? clamp(d * 0.04, 7.0, 14.0) : clamp(d * 0.18, 10.0, 36.0)
    mx, my = i.kind == :audio ? x + min(h / 2, 27.0) + 4 : x + w / 2, y + h / 2
    if i.kind == :poster
      # A dark plate, as the player of a video site shows, so that the arrow reads over any picture
      round_fill(canvas, mx - 2.8size, my - 2size, 5.6size, 4size, size, 0xe6212121)
    elseif i.kind == :video
      round_fill(canvas, mx - 1.6size, my - 1.6size, 3.2size, 3.2size, 1.6size, 0x80000000)
    else
      round_fill(canvas, mx + 2size, my - 2, max(0.0, w - (mx - x) - 2size - 16), 4.0, 2.0, 0xffc4c7c5)
    end
    p = polygon(((mx - 0.6size, my - size), (mx + size, my), (mx - 0.6size, my + size)))
    with_paint(paint -> Skia.sk_canvas_draw_path(canvas, p, paint), i.kind == :audio ? 0xff000000 : 0xffffffff)
    Skia.sk_path_delete(p)
  elseif i.kind == :frame
    with_paint(paint -> Skia.sk_canvas_draw_rect(canvas, rect(x, y, w, h), paint), 0xffffffff)
  end
  nothing
end

paint!(canvas, i::Drawing) = Svg.draw(canvas, i.element, i.look, i.x, i.y, i.w, i.h)

# --- pieces -------------------------------------------------------------------------------

paint!(canvas, c::Clip) = begin
  Skia.sk_canvas_save(canvas)
  if isempty(c.path)
    clip_shape(canvas, c.x, c.y, c.w, c.h, c.radii)
  else
    p = Skia.sk_path_new()
    if Skia.sk_path_parse_svg_string(p, c.path)
      Skia.sk_path_transform(p, skia(shift(c.x, c.y)))
      Skia.sk_canvas_clip_path_with_operation(canvas, p, Skia.SK_CLIP_OP_INTERSECT, true)
    end
    Skia.sk_path_delete(p)
  end
end
paint!(canvas, ::Unclip) = Skia.sk_canvas_restore(canvas)
paint!(canvas, m::Move) = (Skia.sk_canvas_save(canvas); Skia.sk_canvas_concat(canvas, skia(m.m)); nothing)
paint!(canvas, ::Unmove) = Skia.sk_canvas_restore(canvas)

const BLENDS = Dict(:normal => 3, :dst_in => 6, :plus => 12, :screen => 14, :overlay => 15, :darken => 16, :lighten => 17, :color_dodge => 18, :color_burn => 19,
                    :hard_light => 20, :soft_light => 21, :difference => 22, :exclusion => 23, :multiply => 24, :hue => 25, :saturation => 26, :color => 27,
                    :luminosity => 28)

"The 20 numbers of the matrix that changes each colour as the step `e` of a filter says, or nothing for a step that isn't a change of colour"
colour_matrix(e::Effect) = begin
  a = e.x
  if e.kind == :brightness
    Float32[a, 0, 0, 0, 0, 0, a, 0, 0, 0, 0, 0, a, 0, 0, 0, 0, 0, 1, 0]
  elseif e.kind == :contrast
    o = 0.5 - 0.5a
    Float32[a, 0, 0, 0, o, 0, a, 0, 0, o, 0, 0, a, 0, o, 0, 0, 0, 1, 0]
  elseif e.kind == :opacity
    Float32[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, min(a, 1), 0]
  elseif e.kind == :invert
    a = min(a, 1)
    Float32[1 - 2a, 0, 0, 0, a, 0, 1 - 2a, 0, 0, a, 0, 0, 1 - 2a, 0, a, 0, 0, 0, 1, 0]
  elseif e.kind == :grayscale
    k = 1 - min(a, 1)
    Float32[0.2126 + 0.7874k, 0.7152 - 0.7152k, 0.0722 - 0.0722k, 0, 0, 0.2126 - 0.2126k, 0.7152 + 0.2848k, 0.0722 - 0.0722k, 0, 0,
            0.2126 - 0.2126k, 0.7152 - 0.7152k, 0.0722 + 0.9278k, 0, 0, 0, 0, 0, 1, 0]
  elseif e.kind == :sepia
    k = 1 - min(a, 1)
    Float32[0.393 + 0.607k, 0.769 - 0.769k, 0.189 - 0.189k, 0, 0, 0.349 - 0.349k, 0.686 + 0.314k, 0.168 - 0.168k, 0, 0,
            0.272 - 0.272k, 0.534 - 0.534k, 0.131 + 0.869k, 0, 0, 0, 0, 0, 1, 0]
  elseif e.kind == :saturate
    Float32[0.213 + 0.787a, 0.715 - 0.715a, 0.072 - 0.072a, 0, 0, 0.213 - 0.213a, 0.715 + 0.285a, 0.072 - 0.072a, 0, 0,
            0.213 - 0.213a, 0.715 - 0.715a, 0.072 + 0.928a, 0, 0, 0, 0, 0, 1, 0]
  elseif e.kind == :hue
    c, s = cos(a), sin(a)
    Float32[0.213 + 0.787c - 0.213s, 0.715 - 0.715c - 0.715s, 0.072 - 0.072c + 0.928s, 0, 0,
            0.213 - 0.213c + 0.143s, 0.715 + 0.285c + 0.140s, 0.072 - 0.072c - 0.283s, 0, 0,
            0.213 - 0.213c - 0.787s, 0.715 - 0.715c + 0.715s, 0.072 + 0.928c + 0.072s, 0, 0, 0, 0, 0, 1, 0]
  else
    nothing
  end
end

"Skia's filter for the steps of a `filter`, each after the one before it. The caller unrefs it. It's C_NULL for no steps."
filters(effects) = begin
  made = Ptr{Skia.sk_image_filter_t}(C_NULL)
  for e in effects
    next = if e.kind == :blur
      e.x > 0 ? Skia.sk_imagefilter_new_blur(Float32(e.x), Float32(e.x), Skia.sk_tile_mode_t(3), made, C_NULL) : made
    elseif e.kind == :shadow
      Skia.sk_imagefilter_new_drop_shadow(Float32(e.x), Float32(e.y), Float32(e.z / 2), Float32(e.z / 2), e.color == CURRENT ? 0xff000000 : e.color, made, C_NULL)
    else
      m = colour_matrix(e)
      m === nothing && continue
      cf = Skia.sk_colorfilter_new_color_matrix(m)
      f = Skia.sk_imagefilter_new_color_filter(cf, made, C_NULL)
      Skia.sk_colorfilter_unref(cf)
      f
    end
    next == made || made == C_NULL || Skia.sk_imagefilter_unref(made)
    made = next
  end
  made
end

paint!(canvas, f::Layer) = begin
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_color(paint, UInt32(round(UInt8, clamp(f.opacity, 0, 1) * 255)) << 24 | 0x00ffffff)
  f.blend == :normal || Skia.sk_paint_set_blend_mode(paint, Skia.sk_blend_mode_t(get(BLENDS, f.blend, 3)))
  made = filters(f.effects)
  made == C_NULL || Skia.sk_paint_set_imagefilter(paint, made)
  b = f.bounds
  b === nothing ? Skia.sk_canvas_save_layer(canvas, C_NULL, paint) : Skia.sk_canvas_save_layer(canvas, rect(b[1] - 2, b[2] - 2, b[3] + 4, b[4] + 4), paint)
  made == C_NULL || Skia.sk_imagefilter_unref(made)
  Skia.sk_paint_delete(paint)
  nothing
end
paint!(canvas, ::Unlayer) = Skia.sk_canvas_restore(canvas)

const Bracket = Union{Clip,Unclip,Layer,Unlayer,Move,Unmove}

"The top and the bottom of what an item draws"
reach(i::Item) = (i.y, i.y + i.h)
reach(g::Glyphs) = (g.y - 2g.font.size - 2g.blur, g.y + g.font.size + 2g.blur)
reach(s::Shadow) = (s.y + s.dy - s.spread - 2s.blur, s.y + s.h + s.dy + s.spread + 2s.blur)
reach(s::Stroke) = (s.y - 4s.h, s.y + 5s.h)
reach(::Bracket) = (-Inf, Inf)

"How far right what the page draws goes, in px from its left edge"
right(l::List) = begin
  x = 0.0
  depth = 0
  for i in l.items
    i isa Move ? (depth += 1) : i isa Unmove ? (depth -= 1) : nothing
    depth == 0 && i isa Union{Fill,Edge,Picture,Sketch,Moving,Backing,Glyphs,Widget,Drawing} && (x = max(x, i.x + i.w))
  end
  x
end

"True when nothing of what `i` draws is in the part of the canvas that can be drawn on now"
hidden(canvas, i::Item) = Skia.sk_canvas_quick_reject_rect(canvas, rect(i.x, i.y, i.w, i.h))
hidden(canvas, g::Glyphs) = Skia.sk_canvas_quick_reject_rect(canvas, rect(g.x - g.font.size - 2g.blur, g.y - 2g.font.size - 2g.blur, g.w + 2g.font.size + 4g.blur, 3g.font.size + 4g.blur))
hidden(canvas, s::Shadow) = begin
  s.inset && return Skia.sk_canvas_quick_reject_rect(canvas, rect(s.x, s.y, s.w, s.h))
  far = abs(s.spread) + 2s.blur
  Skia.sk_canvas_quick_reject_rect(canvas, rect(s.x + s.dx - far, s.y + s.dy - far, s.w + 2far, s.h + 2far))
end
hidden(canvas, s::Stroke) = Skia.sk_canvas_quick_reject_rect(canvas, rect(s.x, s.y - 4s.h, s.w, 9s.h))
hidden(canvas, ::Bracket) = false

"""
Draw the page, with its top left corner at the canvas's. With `top` and
`bottom`, only what's between those two heights of the page is drawn. What
the canvas cuts off, as a window does with what's scrolled out of it, isn't
drawn either.
"""
draw(canvas, l::List; top=-Inf, bottom=Inf, at=l.now[]) = begin
  moved = 0   # how many moves are open: what's moved isn't where its numbers say
  # A picture that moves shows its picture of the moment `at`, and the list is as it was after
  was, l.now[] = l.now[], at
  for i in l.items
    i isa Move ? (moved += 1) : i isa Unmove ? (moved -= 1) : nothing
    if !(i isa Bracket)
      a, z = reach(i)
      ((moved == 0 && (z < top || a > bottom)) || hidden(canvas, i)) && continue
    end
    paint!(canvas, i)
  end
  l.now[] = was
  nothing
end
