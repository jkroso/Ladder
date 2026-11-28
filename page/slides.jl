# A page can show as slides: one part of the page fills the window at a time,
# for when you show a plan to someone. This file says which lines of a page
# each slide shows:
#
#   - A slide starts at each heading of level 1 or 2.
#   - A slide starts at each line across the page, like `---`. That line
#     doesn't show.
#   - What's before the first heading is the first slide, if it has anything
#     in it.
#   - Front matter is never part of a slide.
#   - A heading of level 3 or lower stays inside its slide.
#   - A heading in a group of columns starts no slide, so the columns stay on
#     one slide. The page says which lines those are.
#
# It also works out how much bigger than the page's text a slide's text is,
# so that the slide suits the window. It draws nothing.

@use "./markdown" Kind Line classify front_matter

"One slide of a page"
struct Slide
  start::Int   # the line that starts it: its heading, or the line across the page
  first::Int   # the first line that it shows
  last::Int    # the last line that it shows
end

"True when a line of the kind `line` starts a slide: a heading of level 1 or 2, or a line across the page"
starts(line::Line) = line.kind == Kind.rule || (line.kind == Kind.heading && line.level <= 2)

"""
The slides of the page with these `lines`, in order. A slide shows no empty
line at its top or its bottom. A part of the page with nothing in it, like the
lines between a line across the page and the heading after it, is no slide:
its lines belong to the slide that comes next. `held(i)` is true for a line
that starts no slide whatever it is, like a heading in a group of columns.
"""
slides(lines, kinds=classify(lines); held=i -> false) = begin
  out = Slide[]
  n = length(lines)
  start = from = front_matter(lines) + 1
  for i in from:n+1
    (i > n || (starts(kinds[i]) && !held(i))) || continue
    a = findnext(k -> k.kind != Kind.blank, kinds, from)
    if a !== nothing && a < i
      push!(out, Slide(start, a, findprev(k -> k.kind != Kind.blank, kinds, i - 1)))
      start = i
    end
    # A line across the page doesn't show. A heading is the first line of its slide.
    from = i <= n && kinds[i].kind == Kind.rule ? i + 1 : i
  end
  out
end

"The number of the slide that line `i` is in: the last one that starts at or before the line, or the first slide"
number(list::Vector{Slide}, i::Integer) = something(findlast(s -> s.start <= i, list), 1)

const MOST = 2.0   # how many times bigger than the page's text a slide's text gets, at the most
const FULL = 0.95  # a slide that takes this much of the room it has is big enough

"""
A scale to try next. The slide is `tall` at the page's own size and `high` at
`scale`, and its height is taken to grow evenly between the two. The scale that
would make it as tall as `room` is the guess, a little less when the slide was
too tall.
"""
guess(tall, scale, high, room; most=MOST) = begin
  grows = (high - tall) / (scale - 1)
  grows > 0 || return high <= room ? most : 1.0
  to = 1 + (room - tall) / grows
  clamp(high > room ? min(to, scale) * 0.97 : to, 1.0, most)
end

"""
How many times bigger than the page's text a slide's text is, so that the
slide fits the window's height: from 1 to `most`. `tall` is how tall the slide
is at the page's own size, and `room` is how tall it can be. `measure` gives
how tall the slide is at a scale. Text that's twice as big isn't always twice
as tall, since a picture stays the size it was and a narrow window wraps the
words again. So the first scale is a guess, and `measure` checks it, three
times at the most. A slide that's too tall at the page's own size gets 1.
"""
fit(measure, tall, room; most=MOST) = begin
  (tall > 0 && room > tall) || return 1.0
  tried = [(1.0, Float64(tall))]
  scale = round(clamp(room / tall, 1.0, most), digits=2)
  for _ in 1:3
    any(t -> abs(first(t) - scale) < 0.01, tried) && break
    high = Float64(measure(scale))
    push!(tried, (scale, high))
    high <= room && (scale >= most - 0.01 || high >= FULL * room) && break
    scale = round(guess(tall, scale, high, room; most), digits=2)
  end
  maximum(first(t) for t in tried if last(t) <= room)
end
