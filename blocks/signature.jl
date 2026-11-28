# A signature is a place where a person signs the page by hand. In a document
# it's a code block in the language `signature`:
#
#     ```signature
#     name: Sam Lee
#     signed: 2026-11-18 09:14
#     pen 52,80 60,71.5 74,90
#     pen 90,62 96,88
#     ```
#
# `name:` is who signs. `signed:` is the day and the time of the first stroke,
# as year-month-day hour:minute. Each `pen` line is one stroke of the pen,
# through each of its places, as a sketch writes a line drawn by hand (see
# sketch.jl). A place is `x,y` in a box that's 420 wide and 130 tall, whatever
# size the box has in the page. So the signature keeps its shape in a page
# that's zoomed and in a narrow window.
#
# A block with no `pen` line isn't signed yet. A line that this file doesn't
# know is kept as it is.
#
# This file reads and writes those lines. It draws nothing in a window. `svg`
# writes a signature as a picture for a page of HTML.

@use "./sketch" Place place figure simplify xml
@use Dates: Dates, DateTime

"The language of a code block that is a signature"
const SIGNATURE = "signature"
const WIDE = 420.0   # how wide the box to sign in is, in its own measure
const TALL = 130.0   # and how tall
const LINE = 100.0   # how far down the box the line to sign on is
const EDGE = 24.0    # how far the ends of that line are from the sides of the box
const INK = 2.0      # how thick the ink is
const SLACK = 0.4    # how far a stroke as it's written can be from the stroke as it was drawn
"The two lines of the ✕ at the left end of the line to sign on, as paper forms have"
const CROSS = (((EDGE, LINE - 16), (EDGE + 9, LINE - 7)), ((EDGE + 9, LINE - 16), (EDGE, LINE - 7)))
"How the block writes a day and a time: 2026-11-18 09:14"
const STAMP = Dates.DateFormat("yyyy-mm-dd HH:MM")

mutable struct Signature
  name::String                             # who signs, or "" when the block doesn't say
  when::Union{DateTime,Nothing}            # when the first stroke was drawn
  strokes::Vector{Vector{Place}}           # each stroke of the pen, in the order that they were drawn
  other::Vector{String}                    # the lines that this file doesn't know, kept as they are
end

Signature() = Signature("", nothing, Vector{Place}[], String[])

"What comes after `key:` on a line, or nothing for a line that doesn't start with that key"
said(key, line) = (m = match(Regex("^" * key * "\\s*:(.*)\$", "i"), line); m === nothing ? nothing : String(strip(m[1])))

"The places of the stroke that a `pen` line names, or nothing for a line that isn't one"
stroke(line) = begin
  words = split(line)
  (length(words) >= 3 && lowercase(words[1]) == "pen") || return nothing
  points = Place[]
  for word in words[2:end]
    # A number with more figures than any place has can't be read
    p = length(word) > 40 ? nothing : place(word)
    p === nothing && return nothing
    push!(points, p)
  end
  points
end

"Read a signature from the lines of its block. A line that's wrong is kept, and changes nothing."
signature(lines) = begin
  s = Signature()
  for line in lines
    text = String(strip(line))
    isempty(text) && continue
    if (name = said("name", text)) !== nothing
      s.name = name
    elseif (stamp = said("signed", text)) !== nothing && (at = tryparse(DateTime, stamp, STAMP)) !== nothing
      s.when = at
    elseif (points = stroke(text)) !== nothing
      push!(s.strokes, points)
    else
      push!(s.other, text)
    end
  end
  s
end

"The lines of a signature's block"
written(s::Signature) = begin
  out = String[]
  isempty(strip(s.name)) || push!(out, "name: " * strip(s.name))
  s.when === nothing || push!(out, "signed: " * Dates.format(s.when, STAMP))
  for points in s.strokes
    push!(out, "pen " * join(("$(figure(x)),$(figure(y))" for (x, y) in points), " "))
  end
  [out; s.other]
end

"True when the block has a stroke: somebody signed it"
issigned(s::Signature) = !isempty(s.strokes)

"Take away the lines that say `signed:` and that this file couldn't read"
forget_day!(s::Signature) = filter!(line -> said("signed", line) === nothing, s.other)

"""
Add a stroke through `points`, drawn at the time `at`. The first stroke says
when the block was signed. It's true when the stroke was added. One place
alone is a dot, like the one over an i. Before the first stroke a dot is left
out, so a click by mistake doesn't sign the page.
"""
sign!(s::Signature, points::Vector{Place}, at::DateTime) = begin
  isempty(points) && return false
  length(points) == 1 && !issigned(s) && return false
  points = length(points) == 1 ? [points[1], points[1]] : simplify(points, SLACK)
  if !issigned(s) || s.when === nothing
    s.when = floor(at, Dates.Minute)
    forget_day!(s)
  end
  push!(s.strokes, points)
  true
end

"Take the strokes away, and the day that they were drawn. The name stays."
clear!(s::Signature) = (empty!(s.strokes); s.when = nothing; forget_day!(s); s)

"A day as a person writes it: 18 November 2026"
day(at) = Dates.format(at, "d U yyyy")

"What a signed block says under the signature: Signed by Sam Lee on 18 November 2026"
caption(s::Signature) = "Signed" * (isempty(s.name) ? "" : " by " * s.name) * (s.when === nothing ? "" : " on " * day(s.when))

# --- a signature as a picture for a page of HTML ----------------------------------------

"""
A stroke as the `d` of an SVG path. The line goes from the middle of each part
to the middle of the next, and bends at the place between, so it's as smooth
as the stroke that the window draws.
"""
curve(points::Vector{Place}) = begin
  f = figure
  out = "M$(f(points[1][1])) $(f(points[1][2]))"
  for i in 2:length(points)-1
    mid = (points[i] .+ points[i+1]) ./ 2
    out *= " Q$(f(points[i][1])) $(f(points[i][2])) $(f(mid[1])) $(f(mid[2]))"
  end
  out * " L$(f(points[end][1])) $(f(points[end][2]))"
end

"""
A signature as an SVG picture: the box, the line to sign on with its ✕, and
the strokes. `ink` is the colour of the strokes, `line` the colour of the box
and `mark` the colour of the line and the ✕, each as CSS writes a colour.
"""
svg(s::Signature; ink, line, mark) = begin
  out = IOBuffer()
  f = figure
  println(out, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 $(f(WIDE)) $(f(TALL))\" width=\"$(f(WIDE))\" role=\"img\" ",
          "aria-label=\"$(xml(issigned(s) ? caption(s) : "A place to sign"))\">")
  println(out, "<rect x=\"0.5\" y=\"0.5\" width=\"$(f(WIDE - 1))\" height=\"$(f(TALL - 1))\" rx=\"8\" fill=\"none\" stroke=\"$line\"/>")
  rule = "M$(f(EDGE)) $(f(LINE)) H$(f(WIDE - EDGE))"
  cross = join(("M$(f(a[1])) $(f(a[2])) L$(f(b[1])) $(f(b[2]))" for (a, b) in CROSS), " ")
  println(out, "<path d=\"$rule\" fill=\"none\" stroke=\"$mark\" stroke-width=\"1\"/>")
  println(out, "<path d=\"$cross\" fill=\"none\" stroke=\"$mark\" stroke-width=\"1.5\" stroke-linecap=\"round\"/>")
  for points in s.strokes
    println(out, "<path d=\"$(curve(points))\" fill=\"none\" stroke=\"$ink\" stroke-width=\"$(f(INK))\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>")
  end
  print(out, "</svg>")
  String(take!(out))
end
