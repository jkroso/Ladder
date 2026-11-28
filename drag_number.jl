# A number that a drag changes: a sum, or a row of a sheet, that is one number

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/draw" ui
@use "./sheet" number_at
@use "./base" exports...
@use "./sheet_view" exports...
@use "./columns_view" item_under

export SCRUB_SPEEDUP, SCRUB_STEP, scrub_at, scrub_steps, underline_scrubs

# --- a number that a drag changes ---------------------------------------------------------------
#
# A sum in a line of text that is one number, like !`l = 16m`, shows what it
# comes to: 16m. So does a row of a sheet that is one number. A drag on that
# value, to the right or to the left, makes the number bigger or smaller. Each
# step of the drag writes the new number into the page's text, so every other
# part that reads it follows while the mouse moves: the rows of the sheet
# under that row, a chart of the sheet, and the sums in a line that use the
# sum's name. ⇧ makes each step ten times as big. A click that doesn't move
# puts the caret where a click puts it anywhere else.
#
# A sum in a line of text keeps what it made, so that it runs once. When a
# sum of the page changes, `inline_tick!` forgets what the sums after it made,
# and they run again from the top down.

const SCRUB_STEP = 5.0         # px that the mouse moves for one step of a number, near where the drag started
const SCRUB_SPEEDUP = 200.0    # px: each this much further from there, the steps come e times as fast

"""
How many steps of a number a drag of `dx` px from where it started makes. Near
the start it's one step for each `SCRUB_STEP` px, so a small change is easy to
make. Further away, the steps come faster and faster: 100px makes 26 steps, and
1000px makes 5,897, which is more than 200 times as many.
"""
scrub_steps(dx) = (k = SCRUB_SPEEDUP / SCRUB_STEP; round(Int, sign(dx) * k * expm1(abs(dx) / SCRUB_SPEEDUP)))

"""
The number at the place `pos` of the window that a drag can change: its line,
and the columns that it runs from and to. It's the number of a sum in a line
of text, under what the sum shows, or the number of a row of a sheet, under
what the row comes to. Nothing when the place has no such number.
"""
scrub_at(e, pos) = begin
  b = e.buf
  (isempty(e.layout) || readonly(b) || b.fixed || b.view != :markdown) && return nothing
  dx, dy = pos[1] - e.origin[1], pos[2] - e.origin[2]
  (dy >= 0px && pos[2] >= above_page(e)) || return nothing
  it = e.layout[item_under(e, dx, dy)]
  # Until the next frame, the layout is of the page that showed before, which can have more lines than this one
  it.last <= length(b.lines) || return nothing
  y = dy - it.top
  c = it.content
  if c isa Flow
    (!c.raw && 0px <= y < tall(c)) || return nothing
    chars = collect(b.lines[it.first])
    for seg in c.lines[line_at(c, y)].segs
      (seg.atomic && seg.node === nothing && seg.x <= dx < seg.x + seg.w) || continue
      # The piece stands for the code of !`code`
      (seg.col >= 2 && seg.col + seg.n <= length(chars) && chars[seg.col-1] == '!' && chars[seg.col] == '`') || continue
      at = number_at(String(chars[seg.col+1:seg.col+seg.n]))
      return at === nothing ? nothing : (it.first, seg.col + at[1], seg.col + at[2])
    end
  elseif c isa Sheet
    across, wide = item_room(e, it)
    r = rowunder(c, y)
    res = c.results[r]
    (res.failed || isempty(res.text) || !(row_top(c, r) <= y < row_top(c, r) + c.heights[r])) && return nothing
    # What the row comes to is at the right end of the row
    w = chip_w(Face(SHEET_FONT, SHEET_WEIGHT, c.size, colours.ink, false), res)
    (wide - SHEET_X - w <= dx - across < wide - SHEET_X) || return nothing
    cell = c.cells[r][end]
    at = number_at(rest(head(b.lines[c.rows[r]], cell.hi), cell.lo))
    return at === nothing ? nothing : (c.rows[r], cell.lo + at[1], cell.lo + at[2])
  end
  nothing
end

"""
Draw a line of dashes under each sum in a line of text that a drag can change,
so that it reads as a number to take hold of. The page's text is at `ui`.
"""
underline_scrubs(ctx, e, ui) = begin
  b = e.buf
  (readonly(b) || b.fixed || b.view != :markdown) && return
  for it in e.layout[e.shown]
    f = it.content
    (f isa Flow && !f.raw && occursin(INLINE, b.lines[it.first])) || continue
    chars = collect(b.lines[it.first])
    for vl in f.lines, seg in vl.segs
      (seg.atomic && seg.node === nothing && seg.col >= 2 && seg.col + seg.n <= length(chars) && chars[seg.col-1] == '!' && chars[seg.col] == '`') || continue
      number_at(String(chars[seg.col+1:seg.col+seg.n])) === nothing && continue
      y = num(ui.top + it.top + f.above + vl.top + vl.high / 2) + num(f.size) * 0.62
      trace(ctx, [(num(ui.left + seg.x), y), (num(ui.left + seg.x + seg.w), y)], tint(colours.accent, 0.75), 1.0, dashed=true)
    end
  end
end
