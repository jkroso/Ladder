# Columns show blocks of a page side by side. In a document, a code block in
# the language `columns` holds a number, and that many of the blocks after it
# show as columns:
#
#     ```columns
#     3
#     ```
#
#     First block of the page.
#
#     - Second block,
#     - a list.
#
#     | Third | block |
#     |---|---|
#     | a | table |
#
# One number is how many columns there are, each as wide as the next. Several
# numbers are the share of the width that each column gets, and there are as
# many columns as numbers: `2 1` is two columns, the first twice as wide as
# the second. A comma can go between two numbers.
#
# A block is a paragraph, a heading, a list, a quote, a table, a code block,
# or a line that holds only a picture or a formula. Empty lines between blocks
# don't count. A column holds one block, unless that block is a heading. A
# heading takes the blocks under it into its column, up to the next heading of
# its level or a higher one. A lower heading, like #### under ###, stays in
# the column.
#
#     ```columns
#     2
#     ```
#
#     ### Option A
#
#     Cheapest.
#
#     - Two days
#
#     ### Option B
#
#     Lasts longer.
#
#     ---
#
#     This paragraph is under the columns.
#
# A line across the page ends the group, and so does another `columns` block:
# a column can't hold columns. The line shows under the columns, as wide as
# the page. When fewer columns follow than the number says, the group has the
# columns that there are.
#
# The blocks stay the page's own lines. Nothing is copied into the `columns`
# block. The language `column` means the same as `columns`.
#
# This file reads the number, finds the blocks of each group, and shares a
# width between the columns. It draws nothing.

@use "./markdown" Kind Line

"The language of a code block that puts the blocks after it in columns"
const COLUMNS = "columns"

"The languages that such a block can be written in"
const LANGS = (COLUMNS, "column")

"With less than this many pixels of text across, at the usual text size, the blocks show one under another"
const NARROW = 520

"The most columns that a group can have"
const MOST = 12

"""
The share of the width that each column gets, as the lines of a `columns`
block say: one for each column. It's nothing when the lines don't say, like
an empty block or one with words in it.
"""
shares(lines) = begin
  words = split(join(lines, ' '), r"[,\s]+", keepempty=false)
  (isempty(words) || length(words) > MOST) && return nothing
  ns = Float64[something(tryparse(Float64, w), NaN) for w in words]
  all(n -> isfinite(n) && n > 0, ns) || return nothing
  length(ns) > 1 && return ns
  # One number alone is how many columns there are
  isinteger(ns[1]) && ns[1] <= MOST ? fill(1.0, Int(ns[1])) : nothing
end

"True when `l` is the line that opens a `columns` block"
opens(l::Line) = l.kind == Kind.fence && l.level == 0 && l.lang in LANGS

const ITEMS = (Kind.bullet, Kind.ordered, Kind.todo)

"""
The last line of the block of the page that starts on line `i`, which isn't an
empty line. `alone(i)` is true for a line of text that's a block by itself,
like a line that holds only a picture.
"""
block_end(kinds::Vector{Line}, i::Int; alone=i -> false) = begin
  k, n = kinds[i].kind, length(kinds)
  if k == Kind.fence
    # A code block runs to the line that closes it, or to the end of the page when none does
    kinds[i].level == 0 || return i
    return something(findnext(l -> l.kind == Kind.fence && l.level == 1, kinds, i + 1), n)
  end
  (k in (Kind.heading, Kind.rule) || alone(i)) && return i
  same(j) = k in ITEMS ? kinds[j].kind in ITEMS : kinds[j].kind == k && !alone(j)
  j = i
  while j < n && same(j + 1)
    j += 1
  end
  j
end

"A `columns` block and the blocks that it puts in columns"
struct Group
  first::Int                      # the lines that open and close the `columns` block
  last::Int
  shares::Vector{Float64}         # the share of the width of each column that the block asks for. Empty when it doesn't say.
  spans::Vector{UnitRange{Int}}   # the lines of the blocks in each column, for as many columns as there are
end

"True when the block that starts on line `a` can't be in a column, so the group ends before it: a line across the page, or another `columns` block"
ends(kinds::Vector{Line}, a::Int) = opens(kinds[a]) || kinds[a].kind == Kind.rule

"""
The last line of the column that starts with the block on line `a`. A heading
takes the blocks under it into its column, up to the next heading of its level
or a higher one, or to where the group ends. Any other block is a column by itself.
"""
column_end(kinds::Vector{Line}, a::Int; alone=i -> false) = begin
  z = block_end(kinds, a; alone)
  kinds[a].kind == Kind.heading || return z
  while true
    b = findnext(l -> l.kind != Kind.blank, kinds, z + 1)
    (b === nothing || ends(kinds, b) || (kinds[b].kind == Kind.heading && kinds[b].level <= kinds[a].level)) && return z
    z = block_end(kinds, b; alone)
  end
end

"""
Each `columns` block of a page, with the blocks that it puts in columns.
`kinds` says what each of `lines` is. A block with one column, or with no
number, has no blocks in columns.
"""
groups(lines, kinds::Vector{Line}; alone=i -> false) = begin
  out = Group[]
  i, n = 1, length(kinds)
  while i <= n
    opens(kinds[i]) || (i += 1; continue)
    t = findnext(l -> l.kind == Kind.fence && l.level == 1, kinds, i + 1)
    t === nothing && break   # nothing closes it, so the rest of the page is its lines
    wide = something(shares(lines[i+1:t-1]), Float64[])
    spans = UnitRange{Int}[]
    j = t + 1
    while length(wide) > 1 && length(spans) < length(wide)
      a = findnext(l -> l.kind != Kind.blank, kinds, j)
      (a === nothing || ends(kinds, a)) && break
      z = column_end(kinds, a; alone)
      push!(spans, a:z)
      j = z + 1
    end
    push!(out, Group(i, t, wide, spans))
    i = j
  end
  out
end

"""
The lines of the page that column `k` of `g` shows: its blocks, and the empty
lines between them and the next column. The last column ends with its last block.
"""
reach(g::Group, k::Int) = first(g.spans[k]):(k < length(g.spans) ? first(g.spans[k+1]) - 1 : last(g.spans[k]))

"How wide each column is, when the columns with these shares have `wide` between them and `gap` is between one and the next"
rooms(shares::Vector{Float64}, wide::Real, gap::Real) = begin
  isempty(shares) && return Float64[]
  space = max(0.0, wide - gap * (length(shares) - 1))
  Float64[space * s / sum(shares) for s in shares]
end

"True when text that's `wide` across is too narrow for columns. `zoom` is how much bigger the text is than its usual size."
stacked(wide::Real, zoom::Real=1) = wide < NARROW * zoom
