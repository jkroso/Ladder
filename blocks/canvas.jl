# A canvas is a board of cards that you put anywhere, as in the app Muse. In
# a document it's a code block in the language `canvas`, with a line for each
# card, for each line drawn by hand and for each line between two cards:
#
#     ```canvas
#     text size 28 60,20 Kitchen
#     note 60,80 Buy the tiles before Friday
#     note width 260 340,80 Ring the plumber
#       about the sink
#     picture width 240 60,240 .media/pasted-20261122-173000.png
#     page 340,240 Kitchen plan
#     link 620,240 https://www.bunnings.com.au/tiles
#     pen blue 12,30 14,32 18,40 25,44
#     join 2 3
#     ```
#
# The first word is the kind of card:
#
#   - `note`: words on a card.
#   - `text`: words straight on the canvas, with no card round them.
#   - `picture`: the picture in a file. Its path is from the page's folder.
#   - `page`: one of your pages, by the name that a wiki link gives it.
#   - `link`: a web page, by its address.
#
# A colour can come next: `red`, `blue`, `green` or `orange`. Then how the card
# is drawn, each as a word and a number: `width` is how wide it is, and `size`
# is how big the words of a text are. Then the place of its top left corner,
# as `x,y`, and last what the card holds. A line that starts with two spaces
# goes on with the words of the note or the text above it.
#
# `pen` is a line drawn by hand, written as a sketch writes one (sketch.jl).
# `join 2 3` is a line from the 2nd card to the 3rd. Cards are counted in the
# order of their lines, and the lines drawn by hand aren't counted.
#
# The canvas has no edges: a place can be anywhere, and below or left of 0.
# Lines that this file doesn't know are kept as they are.
#
# This file reads and writes those lines, and works out where things are. It
# draws nothing in a window, and it measures no words: what needs the size of
# a card takes a function that gives it. `svg` writes a canvas as a picture
# for a page of HTML.

@use "./sketch" => Sketches

"The language of a code block that is a canvas"
const CANVAS = "canvas"
const KINDS = (:note, :text, :picture, :page, :link)
const COLOURS = Sketches.COLOURS
const TEXT_SIZE = 20.0    # how big the words of a text are, when the text doesn't say
const NOTE_SIZE = 14.0    # how big the words of a note are
"How wide each kind of card is, when its line doesn't say. A text with no width is as wide as its words."
const WIDTHS = (note=220.0, text=0.0, picture=240.0, page=220.0, link=260.0)
"What a card can say about how it's drawn, with the least and the most that each can be"
const LIMITS = (width=(40.0, 4000.0), size=(8.0, 200.0))

const Place = Sketches.Place

mutable struct Card
  kind::Symbol
  colour::Symbol
  at::Place          # the place of its top left corner
  width::Float64
  size::Float64      # how big the words of a text are
  content::String    # the words of a note or a text, the path of a picture, the name of a page or a web address
end

Card(kind::Symbol, at, content=""; colour=:ink, width=getfield(WIDTHS, kind), size=TEXT_SIZE) =
  Card(kind, colour, (Float64(at[1]), Float64(at[2])), Float64(width), Float64(size), String(content))

"True for a card that holds words that you type: a note or a text"
wordy(card::Card) = card.kind in (:note, :text)

"""
Set a part of how a card is drawn: `:width` or `:size`. A number that's too
small or too big becomes the nearest that the part can be. A text can have no
width, which makes it as wide as its words.
"""
set!(card::Card, name::Symbol, value::Real) = begin
  v = Float64(value)
  v = name == :width && card.kind == :text && v <= 0 ? 0.0 : clamp(v, LIMITS[name]...)
  setfield!(card, name, v)
  card
end

mutable struct Canvas
  cards::Vector{Card}
  strokes::Vector{Sketches.Shape}   # the lines drawn by hand
  joins::Vector{Pair{Card,Card}}    # the lines between cards: from a card to a card
  other::Vector{String}             # the lines that this file doesn't know, kept as they are
end

Canvas() = Canvas(Card[], Sketches.Shape[], Pair{Card,Card}[], String[])

"The first word of `s` and what comes after it, without the spaces between"
next_word(s::AbstractString) = begin
  s = lstrip(s)
  m = match(r"^\S+", s)
  m === nothing ? ("", s) : (String(m.match), lstrip(s[nextind(s, 0, length(m.match) + 1):end]))
end

"The name of a page as a card holds it: without the [[ and ]] of a wiki link"
page_name(text::AbstractString) = begin
  t = strip(text)
  m = match(r"^\[\[(.+?)(?:\|.*)?\]\]$", t)
  String(m === nothing ? t : strip(m[1]))
end

"The card that a line says, or nothing when the line isn't one"
read_card(line::AbstractString) = begin
  word, rest = next_word(line)
  kind = Symbol(lowercase(word))
  kind in KINDS || return nothing
  card = Card(kind, (0.0, 0.0))
  w, after = next_word(rest)
  if Symbol(lowercase(w)) in COLOURS
    card.colour = Symbol(lowercase(w))
    rest = after
  end
  # Then how it's drawn: a word like `width`, and a number
  while true
    w, after = next_word(rest)
    name = Symbol(lowercase(w))
    name in keys(LIMITS) || break
    n, beyond = next_word(after)
    value = tryparse(Float64, n)
    (value === nothing || !isfinite(value)) && break
    set!(card, name, value)
    rest = beyond
  end
  w, after = next_word(rest)
  p = Sketches.place(w)
  p === nothing && return nothing
  card.at = p
  card.content = String(rstrip(after))
  # A picture, a page and a link must say which
  wordy(card) || !isempty(card.content) || return nothing
  card.kind == :page && (card.content = page_name(card.content))
  card
end

"Read a canvas from the lines of its block"
canvas(lines) = begin
  c = Canvas()
  numbers = Tuple{Int,Int,String,Int}[]   # each join's numbers of cards, its line, and its place among the lines that aren't known
  last = nothing                      # the note or the text that a line which starts with two spaces goes on with
  for line in lines
    if last !== nothing && startswith(line, "  ")
      last.content *= "\n" * rstrip(line[3:end])
      continue
    end
    last = nothing
    isempty(strip(line)) && continue
    words = split(strip(line))
    kind = Symbol(lowercase(words[1]))
    if kind == :pen
      s = Sketches.sketch([line])
      isempty(s.shapes) ? push!(c.other, String(rstrip(line))) : push!(c.strokes, s.shapes[1])
    elseif kind == :join
      a, b = length(words) == 3 ? (tryparse(Int, words[2]), tryparse(Int, words[3])) : (nothing, nothing)
      a === nothing || b === nothing ? push!(c.other, String(rstrip(line))) : push!(numbers, (a, b, String(rstrip(line)), length(c.other) + 1))
    else
      card = read_card(line)
      card === nothing && (push!(c.other, String(rstrip(line))); continue)
      push!(c.cards, card)
      wordy(card) && (last = card)
    end
  end
  # A join names cards by number, so it's read when all of them are. One that names no card keeps its place.
  n = length(c.cards)
  bad = filter(((a, b, _, _),) -> !(1 <= a <= n && 1 <= b <= n && a != b), numbers)
  foreach(((a, b, _, _),) -> push!(c.joins, c.cards[a] => c.cards[b]), setdiff(numbers, bad))
  foreach(((_, _, line, at),) -> insert!(c.other, at, line), reverse(bad))
  c
end

const figure = Sketches.figure

"""
A line of a note's words as the block writes it, after its first line: two
spaces and the words. A line that would start a fence, like ```, would end
the block. It gets two more spaces, which make it an indented line and not a
fence.
"""
continued(line::AbstractString) = occursin(r"^\s?(```|~~~)", line) ? "    " * line : "  " * line

"The lines of a canvas's block"
written(c::Canvas) = begin
  out = String[]
  for card in c.cards
    parts = String[string(card.kind)]
    card.colour == :ink || push!(parts, string(card.colour))
    card.width == getfield(WIDTHS, card.kind) || push!(parts, "width", figure(card.width))
    card.kind == :text && card.size != TEXT_SIZE && push!(parts, "size", figure(card.size))
    push!(parts, "$(figure(card.at[1])),$(figure(card.at[2]))")
    lines = split(card.content, '\n')
    isempty(lines[1]) || push!(parts, lines[1])
    push!(out, join(parts, " "))
    wordy(card) && append!(out, continued.(lines[2:end]))
  end
  append!(out, Sketches.written(Sketches.Sketch(c.strokes, String[])))
  for (a, b) in c.joins
    i, j = findfirst(k -> k === a, c.cards), findfirst(k -> k === b, c.cards)
    (i === nothing || j === nothing) || push!(out, "join $i $j")
  end
  [out; c.other]
end

# --- where things are -----------------------------------------------------------------------
#
# A function `size(card)` gives the width and the height of a card, in the
# canvas's own measure. Main.jl's measures words and pictures to know them.

"The left, top, right and bottom of a card that's `wh` wide and tall"
edges(card::Card, wh) = (card.at[1], card.at[2], card.at[1] + wh[1], card.at[2] + wh[2])

"The left, top, right and bottom of what the canvas holds, or nothing when it holds nothing"
extent(c::Canvas, size) = begin
  boxes = [edges(card, size(card)) for card in c.cards]
  for s in c.strokes
    xs, ys = first.(s.points), last.(s.points)
    push!(boxes, (minimum(xs), minimum(ys), maximum(xs), maximum(ys)))
  end
  isempty(boxes) && return nothing
  (minimum(b -> b[1], boxes), minimum(b -> b[2], boxes), maximum(b -> b[3], boxes), maximum(b -> b[4], boxes))
end

"True when the place `p` is in the box `b`, given as its left, top, right and bottom, or within `reach` of it"
inside(p, b, reach=0.0) = b[1] - reach <= p[1] <= b[3] + reach && b[2] - reach <= p[2] <= b[4] + reach

"The card at the place `p`, or nothing. A card that comes later is over the others, so it's the first that's looked at."
card_at(c::Canvas, p, size; reach=0.0) = begin
  for i in length(c.cards):-1:1
    inside(p, edges(c.cards[i], size(c.cards[i])), reach) && return c.cards[i]
  end
  nothing
end

"The middle of a box"
middle(b) = ((b[1] + b[3]) / 2, (b[2] + b[4]) / 2)

"""
The line between two cards, whose boxes are `a` and `b`: where it starts,
the two places that bend it, and where it ends. It leaves the side of `a`
that faces `b` from the middle of that side, and comes to the side of `b`
that faces `a`. It leaves and comes in straight, so it bends in between, as
the lines of a mind map do.
"""
join_curve(a, b) = begin
  ma, mb = middle(a), middle(b)
  across = max(b[1] - a[3], a[1] - b[3])   # the room between them from side to side
  down = max(b[2] - a[4], a[2] - b[4])     # and from top to bottom
  if across >= down
    right = mb[1] >= ma[1]
    from, to = right ? ((a[3], ma[2]), (b[1], mb[2])) : ((a[1], ma[2]), (b[3], mb[2]))
    k = max(abs(to[1] - from[1]) / 2, 24.0) * (right ? 1 : -1)
    (from, (from[1] + k, from[2]), (to[1] - k, to[2]), to)
  else
    below = mb[2] >= ma[2]
    from, to = below ? ((ma[1], a[4]), (mb[1], b[2])) : ((ma[1], a[2]), (mb[1], b[4]))
    k = max(abs(to[2] - from[2]) / 2, 24.0) * (below ? 1 : -1)
    (from, (from[1], from[2] + k), (to[1], to[2] - k), to)
  end
end

"The place `t` of the way along a curve that `join_curve` gives, from 0 at its start to 1 at its end"
along((p0, p1, p2, p3), t) = begin
  u = 1 - t
  u^3 .* p0 .+ 3u^2 * t .* p1 .+ 3u * t^2 .* p2 .+ t^3 .* p3
end

"How far the place `p` is from a curve that `join_curve` gives"
apart_curve(curve, p) = begin
  p = (Float64(p[1]), Float64(p[2]))
  ps = [along(curve, t) for t in range(0, 1, length=25)]
  minimum(Sketches.apart(p, ps[i], ps[i+1]) for i in 1:length(ps)-1)
end

"The join that's within `reach` of `p`, or nothing"
join_at(c::Canvas, p, size; reach=6.0) = begin
  for j in reverse(c.joins)
    a, b = j
    apart_curve(join_curve(edges(a, size(a)), edges(b, size(b))), p) <= reach && return j
  end
  nothing
end

"The line drawn by hand that's within `reach` of `p`, or nothing. The last one drawn is over the others."
stroke_at(c::Canvas, p; reach=6.0) = begin
  for s in reverse(c.strokes)
    Sketches.distance(s, (Float64(p[1]), Float64(p[2]))) <= reach + s.width / 2 && return s
  end
  nothing
end

"Move a card by `(dx, dy)`"
move!(card::Card, dx::Real, dy::Real) = (card.at = (card.at[1] + dx, card.at[2] + dy); card)

"Take a card away, with the lines that join it to others"
remove!(c::Canvas, card::Card) = begin
  filter!(k -> k !== card, c.cards)
  filter!(j -> j[1] !== card && j[2] !== card, c.joins)
  c
end

"Take away the line from `a` to `b`, or from `b` to `a`. True when there was one."
unjoin!(c::Canvas, a::Card, b::Card) = begin
  n = length(c.joins)
  filter!(j -> !((j[1] === a && j[2] === b) || (j[1] === b && j[2] === a)), c.joins)
  length(c.joins) < n
end

"Join `a` to `b` with a line, unless they're one card or a line joins them already. True when a line was added."
join!(c::Canvas, a::Card, b::Card) = begin
  a === b && return false
  any(j -> (j[1] === a && j[2] === b) || (j[1] === b && j[2] === a), c.joins) && return false
  push!(c.joins, a => b)
  true
end

"The card that a line joins to `card`, from it: the card above it in a mind map. Nothing when there's none."
parent_of(c::Canvas, card::Card) = (j = findfirst(j -> j[2] === card, c.joins); j === nothing ? nothing : c.joins[j][1])

"The cards that lines join from `card` to: those below it in a mind map"
children_of(c::Canvas, card::Card) = [j[2] for j in c.joins if j[1] === card]

"True when a card that's `wh` big at `at` would cover part of a card of `c`, with `gap` round it"
covers(c::Canvas, at, wh, size; gap=12.0) = begin
  b = (at[1] - gap, at[2] - gap, at[1] + wh[1] + gap, at[2] + wh[2] + gap)
  any(c.cards) do card
    e = edges(card, size(card))
    e[1] < b[3] && b[1] < e[3] && e[2] < b[4] && b[2] < e[4]
  end
end

"""
The place for a new card `wh` big: at `at`, or as near below it as no card
of `c` covers.
"""
free_place(c::Canvas, at, wh, size; gap=12.0) = begin
  x, y = at
  for _ in 1:200
    covers(c, (x, y), wh, size; gap) || return (x, y)
    # Below the lowest card that it would cover
    b = (x - gap, y - gap, x + wh[1] + gap, y + wh[2] + gap)
    hit = [edges(card, size(card)) for card in c.cards]
    low = maximum((e[4] for e in hit if e[1] < b[3] && b[1] < e[3] && e[2] < b[4] && b[2] < e[4]), init=y)
    y = max(y + 1, low + 2gap)
  end
  (x, y)
end

"""
The place for a new card joined from `card`, to its right, as the next of
the cards that it joins to. It's under the lowest of those, and where no
card is.
"""
child_place(c::Canvas, card::Card, wh, size; gap=56.0) = begin
  e = edges(card, size(card))
  kids = children_of(c, card)
  y = isempty(kids) ? e[2] : maximum(k -> edges(k, size(k))[4], kids) + 20
  free_place(c, (e[3] + gap, y), wh, size)
end

"The place for a new card under `card`, as the next card joined from the card that `card` is joined from"
sibling_place(c::Canvas, card::Card, wh, size) = begin
  e = edges(card, size(card))
  free_place(c, (e[1], e[4] + 20), wh, size)
end

# --- a canvas as a picture for a page of HTML -------------------------------------------

xml(s::AbstractString) = Sketches.xml(s)

"""
A canvas as an SVG picture. `size(card)` is a card's width and height,
`lines(card)` the lines that the words of a note or a text take, and
`source(card)` the address of a picture's file, or nothing when it has none.
`colours` gives the colour of each name in `COLOURS`, and the colours
`card`, `edge`, `join` and `dim`, as CSS writes a colour.
"""
svg(c::Canvas; size, lines, source, colours, family="sans-serif", room=24.0) = begin
  out = IOBuffer()
  f = figure
  box = something(extent(c, size), (0.0, 0.0, 400.0, 200.0))
  l, t = box[1] - room, box[2] - room
  w, h = box[3] - box[1] + 2room, box[4] - box[2] + 2room
  println(out, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"$(f(l)) $(f(t)) $(f(w)) $(f(h))\" width=\"$(f(w))\" font-family=\"$(xml(family))\" role=\"img\">")
  for (a, b) in c.joins
    p0, p1, p2, p3 = join_curve(edges(a, size(a)), edges(b, size(b)))
    println(out, "<path d=\"M$(f(p0[1])),$(f(p0[2])) C$(f(p1[1])),$(f(p1[2])) $(f(p2[1])),$(f(p2[2])) $(f(p3[1])),$(f(p3[2]))\" fill=\"none\" stroke=\"$(colours[:join])\" stroke-width=\"1.5\"/>")
  end
  for card in c.cards
    x, y = card.at
    cw, ch = size(card)
    if card.kind == :text
      fill = colours[card.colour]
      for (i, line) in enumerate(lines(card))
        println(out, "<text x=\"$(f(x))\" y=\"$(f(y + card.size * (i - 0.25)))\" font-size=\"$(f(card.size))\" fill=\"$fill\">$(xml(line))</text>")
      end
      continue
    end
    if card.kind == :picture
      src = source(card)
      src === nothing || (println(out, "<image href=\"$(xml(src))\" x=\"$(f(x))\" y=\"$(f(y))\" width=\"$(f(cw))\" height=\"$(f(ch))\" preserveAspectRatio=\"xMidYMid slice\"/>"); continue)
    end
    println(out, "<rect x=\"$(f(x))\" y=\"$(f(y))\" width=\"$(f(cw))\" height=\"$(f(ch))\" rx=\"6\" fill=\"$(colours[:card])\" stroke=\"$(colours[:edge])\"/>")
    words = card.kind == :note ? lines(card) : [card.content]
    tint = card.kind == :note ? colours[:ink] : colours[:dim]
    for (i, line) in enumerate(words)
      println(out, "<text x=\"$(f(x + 12))\" y=\"$(f(y + 12 + NOTE_SIZE * 1.4 * (i - 0.2)))\" font-size=\"$(f(NOTE_SIZE))\" fill=\"$tint\">$(xml(line))</text>")
    end
  end
  for s in c.strokes
    pts = join(("$(f(x)),$(f(y))" for (x, y) in s.points), " ")
    println(out, "<polyline points=\"$pts\" fill=\"none\" stroke=\"$(colours[s.colour])\" stroke-width=\"$(f(s.width))\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>")
  end
  print(out, "</svg>")
  String(take!(out))
end
