# The small bar over a table while the caret is in it: it adds and removes a row or a column

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" describe focus
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./markdown" tablecells
@use "./spreadsheet" spreadtexts
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
@use "./folder_page" exports...
@use "./views" exports...
@use "./sheet_view" exports...

export ALIGN_ICONS, BAR_H, DASHES, TABLE_ACTIONS, backrow!, emptyrow, tablebar, tableop!

# --- the bar over a table ----------------------------------------------------------------
#
# While the caret is in a table, a small bar floats over the table's top left
# corner. Its buttons add and remove a row or a column at the caret, and put the
# text of the caret's column on the left, in the centre or on the right.

const TABLE_ACTIONS = (:addrow => "+Row", :delrow => "−Row", :addcol => "+Col", :delcol => "−Col",
                       :left => "L", :center => "C", :right => "R")
const DASHES = (left=":---", center=":---:", right="---:")
const ALIGN_ICONS = (left="text-left", center="text-center", right="text-right")
const BAR_H = 26px

"Change the table the caret is in, then put the caret back in a cell"
tableop!(e, action::Symbol) = begin
  b = e.buf
  inspread(b, b.caret[1]) && return spreadop!(e, action)
  run = table(b, b.caret[1])
  run === nothing && return
  s, t = run
  i = b.caret[1] == s + 1 ? s : b.caret[1]
  cs = tablecells(b.lines[i])
  c = isempty(cs) ? 1 : nearest(cs, b.caret[2])
  rows = map(celltexts, b.lines[s:t])
  n = maximum(length, rows)
  rows = [[r; fill(k == 2 ? "---" : "", n - length(r))] for (k, r) in enumerate(rows)]
  k = i - s + 1   # the caret's row in `rows`, where row 2 is the line of dashes
  if action == :addrow
    k = max(k, 2) + 1
    insert!(rows, k, fill("", n))
  elseif action == :delrow
    k == 1 && return   # the heading row stays
    deleteat!(rows, k)
    k = k > length(rows) ? (length(rows) > 2 ? length(rows) : 1) : k
  elseif action == :addcol
    c += 1
    foreach((j, r) -> insert!(r, c, j == 2 ? "---" : ""), eachindex(rows), rows)
  elseif action == :delcol
    n == 1 && return
    foreach(r -> deleteat!(r, c), rows)
    c = min(c, n - 1)
  else
    rows[2][c] = getproperty(DASHES, action)
  end
  edit!(b, (s, 0), line_end(b, t), join(map(tableline, rows), "\n"))
  line = s + k - 1
  cell = tablecells(b.lines[line])[c]
  b.caret = b.anchor = (line, cell.hi)
  touch!(e)
end

# The three buttons that move a column's text show the usual picture of lines of text on that side
"True when the caret is in a row of a table, under the heading row, that has no text in any cell"
emptyrow(b::Buffer) = begin
  inspread(b, b.caret[1]) && return !selecting(b) && all(isempty, spreadtexts(b.lines[b.caret[1]]))
  run = table(b, b.caret[1])
  run !== nothing && !selecting(b) && b.caret[1] > run[1] + 1 && all(isempty, celltexts(b.lines[b.caret[1]]))
end

"Backspace in an empty row removes the row and puts the caret at the end of the row above"
backrow!(e) = begin
  b = e.buf
  inspread(b, b.caret[1]) && return droprow!(e)
  s, _ = table(b, b.caret[1])
  i = b.caret[1]
  tableop!(e, :delrow)
  above = i - 1 == s + 1 ? s : i - 1
  cs = tablecells(b.lines[above])
  isempty(cs) || (b.caret = b.anchor = (above, cs[end].hi))
  touch!(e)
end

describe(t::TableButton) =
  Box(height(BAR_H - 6px), padding(7px, 0px), radius(4px), background(ishovered(t) ? colours.hover : clear),
    haskey(ALIGN_ICONS, t.action) ? Icon(getproperty(ALIGN_ICONS, t.action), size=13px, color=colours.dim) :
                                    label(t.label, 11px, color=colours.dim))

cursor(::TableButton) = :hand
onkey(t::TableButton, ::KeyPress{Keys.mouse_left}) = (e = editor(t); tableop!(e, t.action); focus(e))

"The bar over the table the caret is in, placed in the window. Nothing when the caret isn't in a table."
tablebar(e) = begin
  b = e.buf
  (!caretless(b) && b.caret[1] == b.anchor[1] && !isempty(e.layout)) || return ()
  it = item(e, b.caret[1])
  it.content isa Grid || return ()
  top = above_page(e) + PAGE_TOP + it.top + TABLE_GAP - e.scroll.offset - BAR_H - 3px
  top >= above_page(e) || return ()
  bar = Row(height(BAR_H), padding(3px, 0px), radius(6px), background(colours.float), border(1px, :solid, colours.line), lifted,
    # A spreadsheet has no buttons that move a column's text: a number goes on the right and text on the left
    [node!(() -> TableButton(action=a, label=l), e, (:table, a)) for (a, l) in TABLE_ACTIONS[1:(isspread(it.content) ? 4 : end)]]...)
  # The page's text is in the middle of the space beside the file panel
  side, space = page_span(e)
  left = side + max(PAGE_X, (space - e.width) / 2) + item_room(e, it)[1]
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), bar),)
end
