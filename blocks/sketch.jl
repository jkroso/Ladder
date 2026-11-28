# A sketch is a drawing made of lines, boxes, ovals, arrows and words. In a
# document it's a code block in the language `sketch`, with a line for each
# shape:
#
#     ```sketch
#     pen 12,30 14,32 18,40 25,44
#     line 10,10 80,60
#     arrow red 10,10 80,60
#     box 100,50 200,120
#     oval blue 100,50 200,120
#     text 120,80 The sink goes here
#     ```
#
# The first word is the kind of shape. A colour can come next: `red`, `blue`,
# `green` or `orange`. Without one, the shape is the colour of the page's
# text. Then come the shape's places, each as `x,y`. A sketch is 720 wide,
# whatever the width of the page, and as tall as its shapes need. `pen` is a
# line drawn by hand, through every place. `line` and `arrow` go from the
# first place to the second. `box` and `oval` have the two places as opposite
# corners. `text` starts at its place, and its words are the rest of the line.
#
# Before its places, a shape can say how it's drawn, each as a word and a
# number:
#
#     box red width 4 radius 12 100,50 200,120
#     text size 24 120,80 The sink goes here
#
# `width` is how thick the shape's line is. Without it the line is 2 thick.
# `radius` is how round the corners of a box are. Without it they're 3 round.
# `size` is how big the words of a text are. Without it they're 16.
#
# This file reads and writes those lines, and works out what a click is on.
# It draws nothing in a window. `svg` writes a sketch as a picture for a page
# of HTML.

"The language of a code block that is a sketch"
const SKETCH = "sketch"
const WIDE = 720.0       # how wide every sketch is, in its own measure
const LEAST = 220.0      # how tall a sketch with nothing low in it is
const ROOM = 48.0        # the room under a sketch's lowest shape
const TEXT_SIZE = 16.0   # how big the words of a sketch are, when the text doesn't say
const WIDTH = 2.0        # how thick the line of a shape is, when the shape doesn't say
const RADIUS = 3.0       # how round the corners of a box are, when the box doesn't say
"What a shape can say about how it's drawn, with the least and the most that each can be"
const LIMITS = (width=(0.5, 24.0), radius=(0.0, 200.0), size=(6.0, 96.0))
const KINDS = (:pen, :line, :arrow, :box, :oval, :text)
const COLOURS = (:ink, :red, :blue, :green, :orange)

const Place = NTuple{2,Float64}

mutable struct Shape
  kind::Symbol
  colour::Symbol
  points::Vector{Place}
  text::String
  width::Float64    # how thick its line is
  radius::Float64   # how round the corners of a box are
  size::Float64     # how big the words of a text are
end

Shape(kind, colour, points, text="") = Shape(kind, colour, points, text, WIDTH, RADIUS, TEXT_SIZE)

"The parts of how a shape is drawn that its kind has: the names of fields of the shape"
settings(kind::Symbol) = kind == :text ? (:size,) : kind == :box ? (:width, :radius) : (:width,)
settings(shape::Shape) = settings(shape.kind)

"Set a part of how a shape is drawn, like its `:width`. A number that's too small or too big becomes the nearest that the part can be."
set!(shape::Shape, name::Symbol, value::Real) = (setfield!(shape, name, clamp(Float64(value), LIMITS[name]...)); shape)

mutable struct Sketch
  shapes::Vector{Shape}
  other::Vector{String}   # the lines that this file doesn't know, kept as they are
end

Sketch() = Sketch(Shape[], String[])

"The place that `x,y` names, or nothing"
place(word::AbstractString) = begin
  m = match(r"^(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)$", word)
  m === nothing ? nothing : (parse(Float64, m[1]), parse(Float64, m[2]))
end

"Read a sketch from the lines of its block"
sketch(lines) = begin
  s = Sketch()
  for line in lines
    isempty(strip(line)) && continue
    words = split(strip(line))
    kind = Symbol(lowercase(words[1]))
    at = 2
    colour = :ink
    if length(words) >= 2 && Symbol(lowercase(words[2])) in COLOURS
      colour = Symbol(lowercase(words[2]))
      at = 3
    end
    # Then how it's drawn: a word like `width`, and a number
    said = Pair{Symbol,Float64}[]
    while at < length(words) && Symbol(lowercase(words[at])) in keys(LIMITS) && (n = tryparse(Float64, words[at+1])) !== nothing && isfinite(n)
      push!(said, Symbol(lowercase(words[at])) => n)
      at += 2
    end
    points = Place[]
    while at <= length(words) && (p = place(words[at])) !== nothing && !(kind == :text && !isempty(points))
      push!(points, p)
      at += 1
    end
    text = kind == :text ? join(words[at:end], " ") : ""
    good = kind == :text ? length(points) == 1 && !isempty(text) :
           kind == :pen ? length(points) >= 2 && at > length(words) :
           kind in KINDS && length(points) == 2 && at > length(words)
    good || (push!(s.other, String(strip(line))); continue)
    shape = Shape(kind, colour, points, text)
    foreach(((name, n),) -> set!(shape, name, n), said)
    push!(s.shapes, shape)
  end
  s
end

"A number of a place as it's written: 12 not 12.0, and no more than one figure after the point"
figure(x::Real) = (r = round(x, digits=1); r == round(r) ? string(round(Int, r)) : string(r))

"The lines of a sketch's block"
written(s::Sketch) = begin
  out = map(s.shapes) do shape
    parts = String[string(shape.kind)]
    shape.colour == :ink || push!(parts, string(shape.colour))
    # How it's drawn is written only where it isn't what a shape has without it
    for (name, usual) in ((:width, WIDTH), (:radius, RADIUS), (:size, TEXT_SIZE))
      getfield(shape, name) == usual || push!(parts, string(name), figure(getfield(shape, name)))
    end
    append!(parts, ("$(figure(x)),$(figure(y))" for (x, y) in shape.points))
    shape.kind == :text && push!(parts, shape.text)
    join(parts, " ")
  end
  [out; s.other]
end

"How wide the words of a text shape are, when nothing measures them: about half their size for each letter"
guess(text::AbstractString, size::Real) = 0.55 * size * length(text)

"The left, top, right and bottom of a shape. `measure(text, size)` says how wide the words of a text shape are."
bounds(shape::Shape, measure=guess) = begin
  if shape.kind == :text
    x, y = shape.points[1]
    return (x, y - shape.size, x + measure(shape.text, shape.size), y + 0.3shape.size)
  end
  xs, ys = first.(shape.points), last.(shape.points)
  (minimum(xs), minimum(ys), maximum(xs), maximum(ys))
end

"How tall a sketch is: enough for its lowest shape, with room under it to draw more"
tall(s::Sketch) = max(LEAST, ceil(maximum(shape -> bounds(shape)[4], s.shapes, init=0.0) + ROOM))

"How far the place `p` is from the line between `a` and `b`"
apart(p::Place, a::Place, b::Place) = begin
  d = b .- a
  len = sum(abs2, d)
  t = len == 0 ? 0.0 : clamp(sum((p .- a) .* d) / len, 0.0, 1.0)
  hypot((p .- (a .+ t .* d))...)
end

"""
A line drawn by hand, with fewer places: a place that's less than `slack` from
the line between its neighbours that stay is left out. The line keeps its shape,
and its line of the block is short.
"""
simplify(points::Vector{Place}, slack::Real=0.8) = begin
  length(points) <= 2 && return copy(points)
  far, most = 0, 0.0
  for i in 2:length(points)-1
    d = apart(points[i], points[1], points[end])
    d > most && ((far, most) = (i, d))
  end
  most <= slack && return [points[1], points[end]]
  [simplify(points[1:far], slack)[1:end-1]; simplify(points[far:end], slack)]
end

"How far the place `p` is from what a shape draws: its line, its edge or its words"
distance(shape::Shape, p::Place, measure=guess) = begin
  k = shape.kind
  if k == :text
    l, t, r, b = bounds(shape, measure)
    return hypot(max(l - p[1], 0.0, p[1] - r), max(t - p[2], 0.0, p[2] - b))
  elseif k == :box
    l, t, r, b = bounds(shape)
    corners = [(l, t), (r, t), (r, b), (l, b), (l, t)]
    return minimum(apart(p, corners[i], corners[i+1]) for i in 1:4)
  elseif k == :oval
    l, t, r, b = bounds(shape)
    rx, ry = max((r - l) / 2, 1e-6), max((b - t) / 2, 1e-6)
    # How far out from the middle the place is, where the edge is 1
    out = hypot((p[1] - (l + r) / 2) / rx, (p[2] - (t + b) / 2) / ry)
    return abs(out - 1) * min(rx, ry)
  end
  minimum(apart(p, shape.points[i], shape.points[i+1]) for i in 1:length(shape.points)-1)
end

"""
The place of the shape that's within `reach` of `p`, or nothing. The shape that
was drawn last is over the others, so it's the first that's looked at. A thick
line is reached from further away than a thin one: `reach` is from its edge.
"""
hit(s::Sketch, p::Place, reach::Real=6.0, measure=guess) = begin
  for i in length(s.shapes):-1:1
    shape = s.shapes[i]
    distance(shape, p, measure) <= reach + (shape.kind == :text ? 0.0 : shape.width / 2) && return i
  end
  nothing
end

"""
The places of a shape that a drag moves to change the shape: the two ends of a
line or an arrow, each place of a line drawn by hand, the four corners of a
box, and the middle of each side of an oval. A text has none.
"""
handles(shape::Shape) = begin
  k = shape.kind
  k == :text && return Place[]
  k in (:box, :oval) || return copy(shape.points)
  (x1, y1), (x2, y2) = shape.points
  k == :box ? Place[(x1, y1), (x2, y1), (x2, y2), (x1, y2)] :
              Place[(x1, (y1 + y2) / 2), ((x1 + x2) / 2, y1), (x2, (y1 + y2) / 2), ((x1 + x2) / 2, y2)]
end

"The number of the handle of a shape that's within `reach` of `p`, or nothing. The nearest one wins."
handle(shape::Shape, p::Place, reach::Real=6.0) = begin
  hs = handles(shape)
  isempty(hs) && return nothing
  far, k = findmin(h -> hypot((h .- p)...), hs)
  far <= reach ? k : nothing
end

"""
Move the `k`th handle of a shape to `p`. A corner of a box takes its two sides
with it, and the corner across from it stays. The middle of a side of an oval
takes that side with it.
"""
pull!(shape::Shape, k::Integer, p::Place) = begin
  kind = shape.kind
  if kind == :box
    (x1, y1), (x2, y2) = shape.points
    k in (1, 4) ? (x1 = p[1]) : (x2 = p[1])
    k in (1, 2) ? (y1 = p[2]) : (y2 = p[2])
    shape.points = [(x1, y1), (x2, y2)]
  elseif kind == :oval
    (x1, y1), (x2, y2) = shape.points
    k == 1 ? (x1 = p[1]) : k == 2 ? (y1 = p[2]) : k == 3 ? (x2 = p[1]) : (y2 = p[2])
    shape.points = [(x1, y1), (x2, y2)]
  elseif kind != :text
    shape.points[k] = p
  end
  shape
end

"Move a shape by `(dx, dy)`"
move!(shape::Shape, dx::Real, dy::Real) = (shape.points = [(x + dx, y + dy) for (x, y) in shape.points]; shape)

"True for a shape that's too small to see: a line, a box or an oval whose two places are almost one"
slight(shape::Shape) = shape.kind in (:line, :arrow, :box, :oval) && hypot((shape.points[2] .- shape.points[1])...) < 3

"The two ends of the head of an arrow that points from `from` to `tip`. The head is `long` from its tip to its ends."
barbs(from::Place, tip::Place, long::Real=11.0) = begin
  d = tip .- from
  len = max(hypot(d...), 1e-6)
  along, across = d ./ len, (-d[2], d[1]) ./ len
  back = tip .- along .* long
  (back .+ across .* 0.45long, back .- across .* 0.45long)
end

"The two ends of the head of an arrow. A thick arrow has a long head."
barbs(shape::Shape) = barbs(shape.points[1], shape.points[2], 7 + 2shape.width)

# --- a sketch as a picture for a page of HTML -------------------------------------------

xml(s::AbstractString) = replace(s, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

"""
A sketch as an SVG picture. `colours` gives the colour of each name in
`COLOURS`, as CSS writes a colour.
"""
svg(s::Sketch; colours, family="sans-serif") = begin
  out = IOBuffer()
  f = figure
  through(points) = join(("$(f(x)),$(f(y))" for (x, y) in points), " ")
  println(out, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 $(f(WIDE)) $(f(tall(s)))\" width=\"$(f(WIDE))\" font-family=\"$(xml(family))\" role=\"img\">")
  for shape in s.shapes
    c = colours[shape.colour]
    stroke = "fill=\"none\" stroke=\"$c\" stroke-width=\"$(f(shape.width))\" stroke-linecap=\"round\" stroke-linejoin=\"round\""
    if shape.kind == :text
      x, y = shape.points[1]
      println(out, "<text x=\"$(f(x))\" y=\"$(f(y))\" font-size=\"$(f(shape.size))\" fill=\"$c\">$(xml(shape.text))</text>")
    elseif shape.kind == :box
      l, t, r, b = bounds(shape)
      println(out, "<rect x=\"$(f(l))\" y=\"$(f(t))\" width=\"$(f(r - l))\" height=\"$(f(b - t))\" rx=\"$(f(min(shape.radius, (r - l) / 2, (b - t) / 2)))\" $stroke/>")
    elseif shape.kind == :oval
      l, t, r, b = bounds(shape)
      println(out, "<ellipse cx=\"$(f((l + r) / 2))\" cy=\"$(f((t + b) / 2))\" rx=\"$(f((r - l) / 2))\" ry=\"$(f((b - t) / 2))\" $stroke/>")
    else
      println(out, "<polyline points=\"$(through(shape.points))\" $stroke/>")
      if shape.kind == :arrow
        a, b = barbs(shape)
        println(out, "<polyline points=\"$(through([a, shape.points[2], b]))\" $stroke/>")
      end
    end
  end
  print(out, "</svg>")
  String(take!(out))
end
