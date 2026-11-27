# A line of the page laid out: the runs of its text, where each one goes, and
# where a long line wraps. The text, the caret and the selection are placed
# with the same numbers, so a click can be turned back into a column.
#
#     f = wrap(pieces, 600px, lh=24px, size=17px)   # a Flow
#     spot(f, 12)                  # where column 12 is drawn in it

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "./markdown" Kind words
@use "./look" exports...

export Inline, Piece, Seg, VLine, Flow, tall, line_top, line_at, INLINE_GAP, wrap, inset, later_word,
       words_end, xcol, spot, colat

# --- a line laid out ---------------------------------------------------------------
#
# A line of the document can wrap into several lines on screen. A Flow says
# where each run of its text goes, so the same numbers place the text, the
# caret and the selection, and turn a click back into a column.

"The node that a piece of inline code made, with the room it takes in its line"
struct Inline
  node::Any      # a Shown
  w::px
  h::px
end

"A run of a line's text before it's wrapped"
struct Piece
  text::String
  col::Int       # the column of its first character
  n::Int         # how many characters of the line it stands for
  face::Face
  atomic::Bool   # true when `text` isn't the line's own text, like a • for a -
  link::String
  node::Union{Nothing,Inline}   # what's drawn in place of the text, for inline code that made a node
  words::Bool    # true for the text that inline code made, whose words can go onto different lines
end

"A run of text placed on one line of the screen"
struct Seg
  text::String
  col::Int
  n::Int
  face::Face
  atomic::Bool
  link::String
  x::px          # from the left edge of the page's text
  w::px
  node::Union{Nothing,Inline}
end

"One line on screen"
struct VLine
  segs::Vector{Seg}
  x::px          # where its text starts
  from::Int      # the columns it covers
  to::Int
  top::px        # how far it is under the first line
  high::px       # a line with a tall node in it is taller than the others
end

struct Flow
  lines::Vector{VLine}
  lh::px         # the height of a line on screen that has only text
  size::px       # the font size, which sets the caret's height
  above::px
  below::px
  kind::Kind
  raw::Bool      # true when the markup characters are showing
end

tall(f::Flow) = f.above + sum(vl -> vl.high, f.lines, init=0px) + f.below

"How far screen line `k` of `f` is under the top of `f`"
line_top(f::Flow, k::Int) = f.above + f.lines[k].top

"The screen line of `f` that's `dy` under the top of `f`"
line_at(f::Flow, dy::px) = something(findlast(vl -> f.above + vl.top <= dy, f.lines), 1)

const INLINE_GAP = 4px   # the least room above and below a node in a line of text, in all

"Wrap `pieces` to `limit`. Lines start at `left`, and all but the first at `hang`."
wrap(pieces, limit::px; lh, size, left=0px, hang=left, above=0px, below=0px, kind=Kind.paragraph, raw=false) = begin
  lines = VLine[]
  segs = Seg[]
  # `flush!` and `add!` change these. A variable that a closure assigns to is
  # boxed, and Julia looks at its type again each time it's used: that was a
  # sixth of the time a page took to describe. A `Ref` keeps its type.
  x, start, top = Ref(left), Ref(left), Ref(0px)
  flush!() = begin
    from = isempty(segs) ? (isempty(lines) ? 0 : last(lines).to) : first(segs).col
    to = isempty(segs) ? from : last(segs).col + last(segs).n
    high = max(lh, maximum(s -> s.node === nothing ? 0px : s.node.h + INLINE_GAP, segs, init=0px))
    # The line keeps a copy, and `segs` starts the next line empty
    push!(lines, VLine(copy(segs), start[], from, to, top[], high))
    top[] += high
    empty!(segs)
    x[] = start[] = hang
  end
  # Add `text`, which is `n` characters from `col`, to the line being built
  add!(p::Piece, text, col, n) = begin
    pad = p.face.chip ? 2(CHIP_X + 1px) : 0px
    if !isempty(segs) && !p.atomic && !last(segs).atomic && last(segs).col + last(segs).n == col && last(segs).face === p.face && last(segs).link == p.link
      s = pop!(segs)
      joined = s.text * text
      push!(segs, Seg(joined, s.col, s.n + n, s.face, false, s.link, s.x, measure(s.face, joined) + pad, nothing))
      x[] = s.x + last(segs).w
    else
      w = p.node === nothing ? measure(p.face, text) + pad : p.node.w
      push!(segs, Seg(text, col, n, p.face, p.atomic, p.link, x[], w, p.node))
      x[] += w
    end
  end
  # Cut the pieces into words, each with the spaces after it. A node that inline code made is one word. The text that
  # it made is cut into words too, and its first word stands for all of the code, so that a click on it finds the code.
  words = Tuple{Piece,String,Int,Int}[]
  for p in pieces
    if p.words
      for (k, m) in enumerate(eachmatch(r"\S+\s*|\s+", p.text))
        push!(words, (p, String(m.match), k == 1 ? p.col : p.col + p.n, k == 1 ? p.n : 0))
      end
      continue
    elseif p.atomic
      push!(words, (p, p.text, p.col, p.n))
      continue
    end
    col = p.col
    for m in eachmatch(r"\S+\s*|\s+", p.text)
      n = length(m.match)
      push!(words, (p, String(m.match), col, n))
      col += n
    end
  end
  # How far a word reaches past where it starts. A `code` chip has room inside it on each side.
  # Spaces at the end of a line may hang past the edge, but the spaces in a chip are inside it.
  reach((p, text, col, n), last) =
    p.node !== nothing ? p.node.w :
    p.words ? measure(p.face, last ? rstrip(text) : text) :
    p.atomic ? measure(p.face, text) :
    p.face.chip ? measure(p.face, text) + (col == p.col ? 2(CHIP_X + 1px) : 0px) :
    measure(p.face, last ? rstrip(text) : text)
  i = 1
  while i <= length(words)
    # Words with no space between them go onto a line together, like a `code` chip and the comma after it
    j = i
    while j < length(words) && !endswith(words[j][2], r"\s") && !startswith(words[j+1][2], r"\s")
      j += 1
    end
    stop = j   # the closure below sees this, which is never assigned again, so it isn't boxed as `j` would be
    w = sum(k -> reach(words[k], k == stop), i:stop)
    if w <= limit - hang
      x[] + w > limit && x[] > start[] && flush!()
      foreach(k -> add!(words[k][1], words[k][2:4]...), i:stop)
    else
      # Words that are too wide for a whole line together break where they must
      for k in i:stop
        x[] + reach(words[k], k == stop) > limit && x[] > start[] && flush!()
        add!(words[k][1], words[k][2:4]...)
      end
    end
    i = stop + 1
  end
  flush!()
  Flow(lines, lh, size, above, below, kind, raw)
end

"""
How far into `seg` the gap after its first `k` characters is. In a `code` chip the text
is inside the chip's padding, so even the gaps at its two ends are inside the chip.
"""
inset(seg::Seg, k::Int) = begin
  seg.atomic && return k <= 0 ? 0px : seg.w
  pad = seg.face.chip ? CHIP_X + 1px : 0px
  k <= 0 && return pad
  k >= seg.n && return seg.w - pad
  pad + measure(seg.face, first(seg.text, k))
end

"""
True when `seg` is one of the words after the first of the text that inline
code made. Those take none of the line's columns: the first word stands for
all of the code. See `wrap`.
"""
later_word(seg::Seg) = seg.atomic && seg.n == 0

"Where segment `i` of `vl` ends, with the words of the same inline code that come after it"
words_end(vl::VLine, i::Int) = begin
  at = vl.segs[i].col + vl.segs[i].n
  while i < length(vl.segs) && later_word(vl.segs[i+1]) && vl.segs[i+1].col == at
    i += 1
  end
  vl.segs[i].x + vl.segs[i].w
end

"Where column `col` is on the screen line `vl`"
xcol(vl::VLine, col::Int) = begin
  for (i, seg) in enumerate(vl.segs)
    col < seg.col && return seg.x
    # The end of inline code is after the last word of its text. A line can start with the last of them.
    later_word(seg) && col == seg.col && return words_end(vl, i)
    col == seg.col && return seg.x + inset(seg, 0)
    if col <= seg.col + seg.n
      # The gap before a `code` chip is the start of its code, so the caret shows inside the chip
      i < length(vl.segs) && col == seg.col + seg.n && (next = vl.segs[i+1]).face.chip && next.col == col &&
        return next.x + inset(next, 0)
      seg.atomic && col == seg.col + seg.n && return words_end(vl, i)
      return seg.x + inset(seg, col - seg.col)
    end
  end
  isempty(vl.segs) ? vl.x : last(vl.segs).x + last(vl.segs).w
end

"The screen line that column `col` is on, and where it is on that line"
spot(f::Flow, col::Int) = begin
  for (k, vl) in enumerate(f.lines), seg in vl.segs
    col < seg.col + seg.n && return (k, xcol(vl, col))
  end
  (length(f.lines), xcol(last(f.lines), col))
end

"The column nearest to `x` on screen line `k`"
colat(f::Flow, k::Int, x::px) = begin
  vl = f.lines[k]
  isempty(vl.segs) && return vl.from
  col = vl.to
  for (i, seg) in enumerate(vl.segs)
    (x < seg.x + seg.w || i == length(vl.segs)) || continue
    if seg.atomic
      col = x < seg.x + seg.w/2 ? seg.col : seg.col + seg.n
    else
      col = seg.col + seg.n
      for c in 1:seg.n
        if x < seg.x + (inset(seg, c - 1) + inset(seg, c))/2
          col = seg.col + c - 1
          break
        end
      end
    end
    break
  end
  # The end of a wrapped line is the start of the next one, so stop a character short
  k < length(f.lines) && col >= vl.to ? max(vl.from, vl.to - 1) : col
end
