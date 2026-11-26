# Selecting the words of a page, as in a browser: the place nearest a point,
# the words between two places, and where the page draws them.
#
# `ws` is a page's words, as `p.words` of main.jl has them: pieces of words
# that are drawn in one line, in the order that the HTML has them. A place in
# the words is how many of their letters come before it: 0 is before the
# first one.
#
#     a = place(ws, x, y)            # the place nearest a point of the page
#     copied(ws, a, b)               # the words between two places, as they're copied
#     marks(ws, a, b)                # where the page draws them: a rectangle for each line
#     word(ws, a), paragraph(ws, a)  # the places round the word or the paragraph at a place
#     over_words(ws, x, y)           # true over a letter
#     letter_count(ws)               # the place at the end of the words
#
# browser.jl selects the words of a web page with these, and Ladder's email
# view the words of an email.
#
# A box that cuts what's in it, like one with `overflow: hidden`, hides the
# words of it that are outside it. Each piece of words knows the rectangle
# that it can be seen in (`seen`). The mouse finds no hidden words, and a
# selection is marked only where its words can be seen. Hidden words that
# are between the two ends of a selection are copied, as a browser copies
# them.

"""
A piece of the page's words that's drawn in one line: what goes before it
when it's copied (a new line `"\\n"`, a tab `"\\t"` between two cells of a row,
or `""`), its top and how tall it is in px, where each of its letters starts
and the last one ends, its letters, its place in the words, and the rectangle
that it can be seen in: its left, its top, its right and its bottom.
"""
const Words = @NamedTuple{before::String, top::Float64, tall::Float64, edges::Vector{Float64}, letters::Vector{Char}, from::Int, seen::NTuple{4,Float64}}

"The rectangle that the words that nothing cuts can be seen in"
const OPEN = (-Inf, -Inf, Inf, Inf)

"How many letters the words `ws` have"
letter_count(ws) = isempty(ws) ? 0 : ws[end].from + length(ws[end].letters)

"How far the point `(x, y)` is from the line of words `w`, up or down. It's 0 for a point that's level with it."
off_line(w, y) = y < w.top ? w.top - y : max(0.0, y - w.top - w.tall)
"How far the point `(x, y)` is from the words `w`, to the left or the right. It's 0 for a point over them."
off_words(w, x) = x < w.edges[1] ? w.edges[1] - x : max(0.0, x - w.edges[end])

"True when some of the words `w` can be seen: no box round them cuts all of them off"
shown(w) = w.seen == OPEN || (min(w.edges[end], w.seen[3]) > max(w.edges[1], w.seen[1]) && min(w.top + w.tall, w.seen[4]) > max(w.top, w.seen[2]))

"True when the point `(x, y)` is in the rectangle that the words `w` can be seen in"
sees(w, x, y) = w.seen[1] <= x <= w.seen[3] && w.seen[2] <= y <= w.seen[4]

"True when the words `w` are in the same line as words whose top is `top` and that are `tall`: when most of the shorter is level with the other"
level(w, top, tall) = min(w.top + w.tall, top + tall) - max(w.top, top) > min(w.tall, tall) / 2

"""
The place in the words `ws` that's nearest the point `(x, y)` of the page, in
px from its top left corner. The point is in the line of words that it's
level with, or in the nearest line up or down. In that line, the place is
before the letter that the point is over, or after it when the point is over
its right half. Over the first line of words, it's the start of the words.
Under the last line, it's their end.
"""
place(ws, x, y) = begin
  # Words that can't be seen are never the nearest
  seen = filter(shown, ws)
  isempty(seen) && return 0
  y < minimum(w -> w.top, seen) && return 0
  y > maximum(w -> w.top + w.tall, seen) && return letter_count(ws)
  # A line can have more than one piece of words, like a word in bold, or the cells of a row of a table
  near = argmin(w -> off_line(w, y), seen)
  w = argmin(w -> off_words(w, x), Iterators.filter(w -> level(w, near.top, near.tall), seen))
  w.from + count(i -> (w.edges[i] + w.edges[i+1]) / 2 < x, eachindex(w.letters))
end

"True when the point `(x, y)` of the page is over some of the words `ws`"
over_words(ws, x, y) = any(w -> off_line(w, y) == 0 && off_words(w, x) == 0 && sees(w, x, y), ws)

"The letters of `w` between the places `a` and `b` of the page's words, as how many of its letters come before each"
letters_between(w, a, b) = (max(a - w.from, 0), min(b - w.from, length(w.letters)))

"""
The words of `ws` between the places `a` and `b`, as they're copied: with a
new line between two lines of the page that aren't one paragraph, and a tab
between two cells of a row of a table. A space that can't break a line is a
space, and no line ends with a space.
"""
copied(ws, a, b) = begin
  a, b = minmax(a, b)
  io = IOBuffer()
  for w in ws
    lo, hi = letters_between(w, a, b)
    lo < hi || continue
    position(io) > 0 && print(io, w.before)
    print(io, String(w.letters[lo+1:hi]))
  end
  replace(replace(String(take!(io)), '\u00a0' => ' '), r" +(?=\n|$)" => "")
end

"""
Where the page draws the words of `ws` between the places `a` and `b`: a
rectangle for each line, as the left, the top, how wide and how tall it is,
in px. The words of a line that are in more than one piece, like a word in
bold, are one rectangle. Two cells of a row of a table are two. Each is cut
to where its words can be seen, and words that can't be seen have none.
"""
marks(ws, a, b) = begin
  a, b = minmax(a, b)
  out = NTuple{4,Float64}[]
  for w in ws
    lo, hi = letters_between(w, a, b)
    lo < hi || continue
    left, right, top, bottom = max(w.edges[lo+1], w.seen[1]), min(w.edges[hi+1], w.seen[3]), max(w.top, w.seen[2]), min(w.top + w.tall, w.seen[4])
    (right > left && bottom > top) || continue
    if !isempty(out) && isempty(w.before)
      l, t, wide, tall = out[end]
      # Words that go on in the same line, to the right, are part of the same rectangle
      if left >= l + wide - 1 && level(w, t, tall)
        top, bottom = min(top, t), max(bottom, t + tall)
        out[end] = (l, top, max(right, l + wide) - l, bottom - top)
        continue
      end
    end
    push!(out, (left, top, right - left, bottom - top))
  end
  out
end

"Which piece of the words `ws` holds the letter after place `a`, or the last letter when `a` is the end of the words, or nothing"
words_at(ws, a) = findlast(w -> w.from <= a, ws)

isword(c::Char) = isletter(c) || isdigit(c) || c in ('_', '\'', '\u2019')

"""
The places round the word at place `a` of the words `ws`, as two clicks select
it. Where there's no word, it's the letter after `a`.
"""
word(ws, a) = begin
  i = words_at(ws, a)
  i === nothing && return (a, a)
  w = ws[i]
  k = a - w.from
  n = length(w.letters)
  # A place at the end of a piece of words, after its last letter, is in its last word
  k >= n && return n > 0 && isword(w.letters[n]) ? word(ws, a - 1) : (a, a)
  isword(w.letters[k+1]) || return (a, a + 1)
  lo = hi = k
  while lo > 0 && isword(w.letters[lo]); lo -= 1 end
  while hi < n && isword(w.letters[hi+1]); hi += 1 end
  (w.from + lo, w.from + hi)
end

"""
The places round the paragraph at place `a` of the words `ws`, as three clicks
select it: the lines of words from the last one that starts a line of its
own, to the next one that does.
"""
paragraph(ws, a) = begin
  i = words_at(ws, a)
  i === nothing && return (a, a)
  lo = hi = i
  while lo > 1 && isempty(ws[lo].before); lo -= 1 end
  while hi < length(ws) && isempty(ws[hi+1].before); hi += 1 end
  (ws[lo].from, ws[hi].from + length(ws[hi].letters))
end
