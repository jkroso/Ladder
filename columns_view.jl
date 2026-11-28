# Blocks of the page side by side, in columns
#
# A code block in the language `columns` holds a number, and that many of the
# blocks after it show side by side. columns.jl says how the block is written
# and which blocks each column holds. The blocks stay the page's own lines:
# the caret goes into them, and every key does there what it does anywhere else.
#
# The page's layout does the work. `page_columns!` finds the columns before
# the page is laid out. `column_turn!` is called at each line of the layout.
# In a column it makes the page's text as wide as the column, so each line
# wraps there, and each table, picture and component is made for that width.
# A column's lines of text and its tables are placed at the column's left
# edge. So the caret, the selection and a click find them as they find any
# other line. Each column starts level with the first, and the page goes on
# under the tallest. `page_parts` puts the columns side by side in the window.
#
# In a narrow window the blocks show one under another.
#
# The `columns` block itself takes no room in the page, and shows nothing.
# `column_fold` says which lines that is: the block's own, and as many of the
# empty lines after it as there are before it. So the room over the columns is
# the room between two blocks. As rich text the caret steps over those lines,
# as it steps over the ``` lines of a code block. As plain text (⌘E) the caret
# goes through them, and the block shows its lines while the caret is on them.
# A block that doesn't say how many columns keeps a little room, and says how
# to write it.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" rectangle
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw cursor
@use "./markdown" Kind
@use "./sheet" parts folded
@use "./columns" => Columns
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

export COLUMN_BLOCK, COLUMN_GAP, COLUMN_MARK, PageColumn, ColumnGroup, PageColumns, column_gap, column_groups,
       page_columns!, flat, column_cache, in_column, shifted, column_turn!, whole_groups, page_parts, land,
       ColumnsView, COLUMN_WORDS, html_columns, columns_html, LaidColumns, laid_columns

const COLUMN_BLOCK = Columns.COLUMNS   # the language of the block. `COLUMNS` is the columns of a takeoff's table.
const COLUMN_GAP = 1.6     # the room between two columns, as a part of the size of the page's text
const COLUMN_MARK = 1px    # how tall a `columns` block that says nothing is in the page, without the room above and below it
push!(BLOCK_ICONS, "columns-gap")

"One column of the page, as the layout places it"
struct PageColumn
  first::Int   # the lines of the page that show in it
  last::Int
  left::px     # how far its left edge is from the left edge of the page's text
  wide::px
  group::Int   # the place of its group among the page's groups of columns
end

"The columns that one `columns` block makes"
mutable struct ColumnGroup
  block::Int   # the line that opens the `columns` block
  top::px      # how far down the page the layout put the columns
  tall::px     # they're as tall as the tallest of them
end

"The columns of a page that are side by side, and what the layout does with them"
mutable struct PageColumns
  path::String                      # the page that they're the columns of
  columns::Vector{PageColumn}       # in the order of their lines
  groups::Vector{ColumnGroup}
  folds::Vector{Tuple{Int,Int,Bool}}   # the lines of each `columns` block that takes no room, and whether the caret is in them
  now::Union{Nothing,PageColumn}    # the column that the layout is in. The page's text is as wide as that column then.
  busy::Bool                        # a line of a column is being laid out, so `column_at` doesn't send it round again
  next::Int                         # the place in `columns` of the next column that the layout comes to
  from::Int                         # the first item of the column that the layout is in
  flows::Dict{Any,Any}              # the page's own layouts and its width, to put back after a column
  width::px
end

"The columns of the page, as its last layout found them, which the window keeps until the next layout: see `page_columns!`"
@def mutable struct LaidColumns
  found::Union{Nothing,PageColumns} = nothing
end

"The columns that the last layout of the page of `e` found, or nothing for a page that has none"
laid_columns(e) = state_of(e, LaidColumns).found

"The room between two columns of the page"
column_gap(e) = body(e).size * COLUMN_GAP

"Each `columns` block of the page, with the blocks that it puts in columns. They're found again when the page has changed."
column_groups(e) = begin
  b = e.buf
  get!(e.flows, (:column_groups, b.path, b.version)) do
    # A line that holds only a picture or a formula is a block by itself
    Columns.groups(b.lines, kinds(b), alone=i -> pictured(b, i) || maths_line(b, i))
  end
end

"""
The lines of a `columns` block that takes no room in the page, when line `i`
is one of them: the first and the last. Nothing for any other line. A block
that says how many columns takes no room. Nor do the empty lines after it, as
many of them as there are empty lines before it: the room that's left over the
columns is the room between two blocks of the page.
"""
column_fold(b::Buffer, i::Int) = begin
  b.view == :markdown || return nothing
  ks = kinds(b)
  j = i
  if ks[i].kind == Kind.blank
    # An empty line is one of them when the block is the first thing over it
    while j > 1 && ks[j].kind == Kind.blank
      j -= 1
    end
    (ks[j].kind == Kind.fence && ks[j].level == 1) || return nothing
  elseif !(ks[i].kind in (Kind.fence, Kind.code))
    return nothing
  end
  s, t = codeblock(b, j)
  (t > s && Columns.opens(ks[s]) && ks[t].kind == Kind.fence && ks[t].level == 1) || return nothing
  Columns.shares(@view b.lines[s+1:t-1]) === nothing && return nothing
  bare(k) = 1 <= k <= length(ks) && ks[k].kind == Kind.blank
  n = 0
  while bare(s - n - 1) && bare(t + n + 1)
    n += 1
  end
  i <= t + n ? (s, t + n) : nothing
end

"""
Find the columns of the page, before the layout: where each is across the
page, and how wide. A window that's too narrow has none. It also finds the
`columns` blocks that take no room. It's nothing when the page has neither. A
layout that failed in a column left the column's width behind, so the page's
own is put back first.
"""
page_columns!(e) = begin
  kept = state_of(e, LaidColumns)
  old, kept.found = kept.found, nothing
  old !== nothing && old.now !== nothing && (e.flows = old.flows; empty!(e.flows))
  b = e.buf
  (b.view == :markdown && lowered(e) === nothing) || return nothing
  found = column_groups(e)
  isempty(found) && return nothing
  gap = column_gap(e)
  s = PageColumns(b.path, PageColumn[], ColumnGroup[], Tuple{Int,Int,Bool}[], nothing, false, 1, 0, e.flows, e.width)
  for g in found
    fold = column_fold(b, g.first)
    # With the caret in them, the lines of the block show
    fold === nothing || push!(s.folds, (fold..., !caretless(b) && all(p -> fold[1] <= p[1] <= fold[2], (b.caret, b.anchor))))
  end
  for g in (Columns.stacked(num(e.width), e.zoom) ? () : found)
    isempty(g.spans) && continue
    push!(s.groups, ColumnGroup(g.first, 0px, 0px))
    left = 0px
    # A group with fewer blocks than its number has room for the columns that it hasn't got
    for (k, wide) in enumerate(Columns.rooms(g.shares, num(e.width), num(gap))[1:length(g.spans)])
      lines = Columns.reach(g, k)
      push!(s.columns, PageColumn(first(lines), last(lines), left, px(wide), length(s.groups)))
      left += px(wide) + gap
    end
  end
  isempty(s.columns) && isempty(s.folds) && return nothing
  kept.found = s
end

"True when `it`, an item that the layout just made, is of a `columns` block that takes no room: the block, or an empty line after it"
folded(s::PageColumns, e, it::Item) = begin
  k = findfirst(f -> f[1] <= it.first <= f[2], s.folds)
  k === nothing && return false
  # With the caret in the block, the block is lines of code, which show
  it.content isa Live && return it.content.node isa ColumnsView
  it.content isa Flow && kinds(e.buf)[it.first].kind == Kind.blank && !s.folds[k][3]
end

"An item that takes no room, in the place of `it`"
flat(e, it::Item) = Item(it.first, it.last, it.top, 0px, Flow([VLine(Seg[], 0px, 0, 0, 0px, 0px)], 0px, body(e).size, 0px, 0px, Kind.blank, false))

"The column that line `i` of the page shows in, or nothing"
column_at(e, i::Int) = begin
  s = laid_columns(e)
  # Another page can show before the next layout finds its columns
  (s === nothing || s.busy || s.path != e.buf.path) && return nothing
  for c in s.columns
    c.first > i && break
    i <= c.last && return c
  end
  nothing
end

"How far the left edge of `it` is from the left edge of the page's text, and how wide it is: its column's, or the page's"
item_room(e, it::Item) = (c = column_at(e, it.first); c === nothing ? (0px, e.width) : (c.left, c.wide))

"The layouts of the lines of a column that's as wide as `c`, kept apart from those of the page's own width"
column_cache(s::PageColumns, c::PageColumn) = get!(() -> Dict{Any,Any}(), s.flows, (:column, c.wide))

"Do `f` while the page's text is as wide as the column `c`, so that what `f` lays out and describes fits the column"
in_column(f, e, s::PageColumns, c::PageColumn) = begin
  width, flows = e.width, e.flows
  e.width, e.flows = c.wide, column_cache(s, c)
  try
    f()
  finally
    e.width, e.flows = width, flows
  end
end

"`f` moved `dx` to the right. A line of a column is placed at the column's left edge."
shifted(f::Flow, dx::px) = dx == 0px ? f :
  Flow([VLine([Seg(s.text, s.col, s.n, s.face, s.atomic, s.link, s.x + dx, s.w, s.node) for s in vl.segs], vl.x + dx, vl.from, vl.to, vl.top, vl.high)
        for vl in f.lines], f.lh, f.size, f.above, f.below, f.kind, f.raw)
shifted(g::Grid, dx::px) = dx == 0px ? g : Grid(g.rows, g.widths, g.heights, g.cells, g.flows, g.head, g.left + dx, g.values)
shifted(content, dx::px) = content   # a sheet and a component have no place across the page of their own

"Line `i` of the page, which is in the column `c`, laid out for the column's width and placed at its left edge"
column_flow(e, c::PageColumn, i::Int, raw::Bool) = begin
  s = laid_columns(e)::PageColumns
  s.busy = true
  f = try
    # The layout of the page is in the column already. Anything else that asks is at the page's own width.
    s.now === c ? flow(e, i, raw) : in_column(() -> flow(e, i, raw), e, s, c)
  finally
    s.busy = false
  end
  shifted(f, c.left)
end

"""
The layout has come to line `i` of the page, and `top` is how far down the page
it has got. This says how far down the page line `i` goes. After a `columns`
block, line `i` goes where the block was, because the block takes no room. At
the first line of a column, the page's text becomes as wide as the column, and
the line goes level with the top of the group's first column. After the last line of a
column, the page's text gets its own width back. After the last column of a
group, the page goes on under the tallest column.
"""
column_turn!(s::PageColumns, e, items::Vector{Item}, i::Int, top::px) = begin
  # A `columns` block takes no room, so the item that was just made for it goes flat, and line `i` takes its place
  if !isempty(items) && last(items).tall > 0px && folded(s, e, last(items))
    items[end] = flat(e, last(items))
    top = last(items).top
  end
  c = s.now
  if c !== nothing && i > c.last
    g = s.groups[c.group]
    g.tall = max(g.tall, top - g.top)
    e.width, e.flows = s.width, s.flows
    s.now = nothing
    # A table is placed at the column's left edge, as each line of text was when it was laid out
    for k in s.from:length(items)
      it = items[k]
      it.content isa Grid && (items[k] = Item(it.first, it.last, it.top, it.tall, shifted(it.content, c.left)))
    end
    ends = s.next > length(s.columns) || s.columns[s.next].group != c.group
    ends && (top = g.top + g.tall)
  end
  if s.now === nothing && s.next <= length(s.columns) && i >= s.columns[s.next].first
    c = s.columns[s.next]
    g = s.groups[c.group]
    (s.next == 1 || s.columns[s.next-1].group != c.group) && (g.top = top; g.tall = 0px)
    s.next += 1
    s.now, s.from = c, length(items) + 1
    e.width, e.flows = c.wide, column_cache(s, c)
    top = g.top
  end
  top
end

"How far down the page the lowest of `items` ends. In a group of columns, that's the end of the tallest column."
lowest(e, items) = laid_columns(e) !== nothing ? maximum(it -> it.top + it.tall, items) : last(items).top + last(items).tall

"The first and the last of the items `lo` to `hi` of the page, with the whole of each group of columns that they're part of"
whole_groups(e, items, lo::Int, hi::Int) = begin
  first_of(k) = (c = column_at(e, items[k].first); c === nothing ? nothing : c.group)
  while lo > 1 && first_of(lo) !== nothing && first_of(lo - 1) == first_of(lo)
    lo -= 1
  end
  while hi < length(items) && first_of(hi) !== nothing && first_of(hi + 1) == first_of(hi)
    hi += 1
  end
  (lo, hi)
end

"""
The place in the page's layout of the item under a point that's `dx` across
and `dy` down from the top left corner of the page's text. Beside a group of
columns and between two of them, it's an item of the column that the point is
in or after. Under a column that's shorter than its group, it's the column's
last item.
"""
item_under(e, dx::px, dy::px) = begin
  items = e.layout
  k = something(findlast(it -> it.top <= dy, items), 1)
  s = laid_columns(e)
  s === nothing && return k
  g = findfirst(g -> g.top <= dy < g.top + g.tall, s.groups)
  g === nothing && return k
  mine = [c for c in s.columns if c.group == g]
  c = mine[something(findlast(c -> c.left <= dx, mine), 1)]
  lo = findfirst(it -> it.first >= c.first, items)
  hi = findlast(it -> it.first <= c.last, items)
  (lo === nothing || hi === nothing || hi < lo) && return k
  lo - 1 + something(findlast(it -> it.top <= dy, view(items, lo:hi)), 1)
end

"""
The parts of the page that `items` show, as the document holds them: one under
another, with the columns of a group side by side. Each column describes its
blocks while the page's text is as wide as the column.
"""
page_parts(d::Document, e, items) = begin
  parts(run) = Any[x isa Item ? describe(e, x) : x for x in blocks(d, run)]
  s = laid_columns(e)
  s === nothing && return parts(items)
  out, run = Any[], Item[]
  k, n = 1, length(items)
  while k <= n
    c = column_at(e, items[k].first)
    if c === nothing
      push!(run, items[k])
      k += 1
      continue
    end
    append!(out, parts(run))
    empty!(run)
    group, columns = c.group, Any[]
    while k <= n && c !== nothing && c.group == group
      mine = Item[]
      while k <= n && items[k].first <= c.last
        it = items[k]
        # Its text is drawn from the column's own left edge
        push!(mine, Item(it.first, it.last, it.top, it.tall, shifted(it.content, -c.left)))
        k += 1
      end
      push!(columns, in_column(() -> Column(fixed(c.wide), Alignment.Start, name="Column", parts(mine)...), e, s, c))
      c = k <= n ? column_at(e, items[k].first) : nothing
    end
    push!(out, Row(width(grow=grow), Alignment.Start, child_gap=column_gap(e), name="Columns", columns...))
  end
  append!(out, parts(run))
  out
end

"""
The place on line `j` that ↑ or ↓ takes the caret to from line `from`, with `x`
as far across the page as the caret tries to stay. It's nothing when `j` isn't
a line of the page. It follows the rules of `line_step`: the caret steps over
a line that doesn't show, and goes onto a part like a picture as a whole.
"""
land(e, j::Int, by::Int, x::px, from::Int) = begin
  b = e.buf
  if rich(b)
    j = step_over(b, j, by, from)
    1 <= j <= length(b.lines) || return nothing
    free(b, j, from) || return (j, 0)
  end
  1 <= j <= length(b.lines) || return nothing
  into = item(e, j)
  into.content isa Sheet && return enter(e, into, into.content, by, x - item_room(e, into)[1])
  # A line of text shows little of its markup as plain text, so it's laid out as it reads
  f = flow(e, j, b.plain && !by_runs(b, j))
  (j, colat(f, by < 0 ? length(f.lines) : 1, x))
end

"""
The place one line up or down the screen from the caret. ↑ and ↓ stay in a
column of the page: they go through its blocks, and leave the group of columns
from the column's first and last line. Into a group, they go to the column
that's under the caret.
"""
vertical(e, by::Int) = begin
  p = line_step(e, by)
  s = laid_columns(e)
  s === nothing && return p
  b = e.buf
  i = b.caret[1]
  from, to = column_at(e, i), column_at(e, p[1])
  from == to && return p
  x = something(e.goal, 0px)
  if from !== nothing
    # In a table, the caret keeps its place across its cell. Out of the table it keeps its place across the page,
    # so that it comes back into the column that it left.
    it = item(e, i)
    at = it.content isa Grid ? gridcell(it.content, b.caret) : nothing
    at === nothing || (x = e.goal = cell_origin(it.content, at...)[1] + spot(it.content.flows[at[1]][at[2]], b.caret[2])[2])
    # Out of a column: only the line above the group or the line under it is next, not another column's
    (to === nothing || to.group != from.group) && return p
    mine = [c for c in s.columns if c.group == from.group]
    j = by > 0 ? last(mine).last + 1 : first(mine).first - 1
    return something(land(e, j, by, x, i), b.caret)
  end
  # Into a group: the column that the caret is over
  mine = [c for c in s.columns if c.group == to.group]
  c = mine[something(findlast(c -> c.left <= x, mine), 1)]
  something(land(e, by > 0 ? c.first : c.last, by, x, i), p)
end

"""
The view of a `columns` block. A block that says how many columns shows
nothing, and the layout gives it no room. One that doesn't say shows a faint
line with words that say how to write it.
"""
@def mutable struct ColumnsView <: SemanticUI
  n::Int = 0                                       # its place among the page's `columns` blocks
  first::Int = 0                                   # the lines of its block, when the page was last laid out
  last::Int = 0
  shares::Union{Nothing,Vector{Float64}} = nothing   # the share of each column, or nothing when the block doesn't say
  lines::Vector{String} = String[]                 # the lines that `shares` was read from
  parts::Dict{Any,Any} = Dict{Any,Any}()
end

reread!(v::ColumnsView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.shares = Columns.shares(lines)
  v
end

"What the line of a block that doesn't say how many columns says"
const COLUMN_WORDS = "Columns: write how many in the block, like 3"

# The block is a thin strip of the page. Its line and its words are drawn over the room above and below it.
describe(v::ColumnsView) = Box(width(grow=grow), height(COLUMN_MARK))
cursor(::ColumnsView) = :arrow

draw(ctx, size, ui::ConcreteRect, v::ColumnsView) = begin
  v.shares === nothing || return nothing   # a block that's right shows nothing
  e = editor(v)
  face = Face(SANS, "", body(e).size * 0.62, colours.dim, false)
  x, y = num(ui.left), num(ui.top)
  rectangle(ctx, ui.left, ui.top, ui.width, 1px, background=colours.line, border=0px)
  # The words stand on the line, at its left end, with a picture of two columns before them
  side = num(face.size)
  wide = side * 1.35 + num(measure(face, COLUMN_WORDS)) + 8
  rectangle(ctx, ui.left, ui.top - px(side), px(wide), px(2side), background=colours.bg, border=0px)
  round_box(ctx, x, y - side * 0.42, side * 0.4, side * 0.84, 1.5, line=face.color)
  round_box(ctx, x + side * 0.55, y - side * 0.42, side * 0.4, side * 0.84, 1.5, line=face.color)
  write_ink(ctx, COLUMN_WORDS, x + side * 1.35, y + num(capital(face)) / 2, face)
  nothing
end

"""
The columns of the page for a page of HTML: for each group, the first line, the
last line and the share of each column. A column that the group has no block
for has no lines, and keeps its room.
"""
html_columns(e) = map(filter(g -> !isempty(g.spans), column_groups(e))) do g
  map(eachindex(g.shares)) do k
    k <= length(g.spans) || return (last(g.spans[end]) + 1, last(g.spans[end]), g.shares[k])
    (first(Columns.reach(g, k)), last(Columns.reach(g, k)), g.shares[k])
  end
end

# In a page of HTML the block itself is nothing: its columns are there
columns_html(e, v::ColumnsView) = v.shares === nothing ? nothing : ""

# The language `column` means the same as `columns`
foreach(lang -> BLOCKS[lang] = ColumnsView, Columns.LANGS)
block_name(::Type{ColumnsView}) = "Columns"
block_icon(::Type{ColumnsView}) = "columns-gap"
block_insert(::Type{ColumnsView}) = ("Columns", ["```$COLUMN_BLOCK", "2", "```", "", ""], (5, 0))
block_outline_inside(::Type{ColumnsView}) = true
block_html(e, v::ColumnsView) = columns_html(e, v)
