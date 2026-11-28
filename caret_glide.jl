# The caret's glide: the caret moves to its new place in a short time, and doesn't jump there

@use "github.com/jkroso/MiniFB.jl/skia" rectangle
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw
@use "github.com/jkroso/UI.jl/Interface/objc" sel
@use "./markdown" Kind
@use Colors: RGBA
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
@use "./julia_levels" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./check_view" exports...
@use "./git_page" exports...
@use "./page_extras" exports...
@use "./check_fails" exports...
@use "./drag_number" exports...
@use "./day_view" exports...
@use "./givers" exports...
@use "./editing" exports...

export GLIDE_TIME, SHADE, carets, glide!, glide_to!, glided, gliding, margin, selection_boxes,
       shade_line, within_code

# --- the caret's glide ------------------------------------------------------------------
#
# When you type, or press a key that takes the caret a step, the caret doesn't
# jump to its new place. It moves there in a short time, fast at first and then
# slower, and its height changes on the way. A caret that's sent somewhere else
# before it arrives goes on from where it is. A step is a character, a word or
# a line: what the arrow keys do, with ⌥ or without.
#
# Anything else that moves the caret puts it at its new place at once: a click,
# a drag, a key that goes to the end of the line or of the page, a link to a
# heading. So does a page that's laid out again, because the window changed
# its width, say, and a page that has just opened. The settings page turns the
# glide off.

const GLIDE_TIME = 0.07   # seconds the caret takes to get to a new place

"Where a caret is at the time `now`: its left, its top and its height"
glided(g::Glide, now) = begin
  t = clamp((now - g.left_at) / GLIDE_TIME, 0.0, 1.0)
  g.from .+ (g.to .- g.from) .* (1 - (1 - t)^3)   # fast at first, then slower
end

"True while a caret of the page is on its way to a new place"
gliding(e, now=time()) = any(g -> g.from != g.to && now - g.left_at < GLIDE_TIME, values(e.glides))

"""
Where to draw the caret numbered `slot` at the time `now`, when its place in
the text is at `to` on the page. A caret that a step or a change to the text
gave a new place sets off for it from where it's drawn now.
"""
glide_to!(e, slot, to, now=time()) = begin
  b = e.buf
  key = (b.caret, b.version)
  g = get(e.glides, slot, nothing)
  if g !== nothing && e.glide && g.buf == objectid(b)
    if g.key == key
      # The same place in the text, at the same place on the page: it goes on with its move
      maximum(abs, g.to .- to) < 0.01 && return glided(g, now)
    elseif e.by_step || g.key[2] != b.version
      g.from, g.to, g.left_at, g.key = glided(g, now), to, now, key
      return g.from
    end
  end
  e.glides[slot] = Glide(to, to, now, objectid(b), key)
  to
end

"Turn the caret's glide on or off"
glide!(e, on::Bool) = (e.glide = on; save_settings!(e); rerun!(e, :glide); e)

"Draw the caret at column `col` of `f`, whose top left corner is at (x, y)"
caret(ctx, e, f::Flow, x, y, col) = begin
  w = window_of(e)
  (w !== nothing && w.focus === e) || return
  k, cx = spot(f, col)
  high = f.size * 1.25
  left, top = e.origin
  at = glide_to!(e, e.gliding, (num(x + cx - left), num(y + line_top(f, k) + (f.lines[k].high - high)/2 - top), num(high)))
  g = e.glides[e.gliding]
  moving = g.from != g.to && time() - g.left_at < GLIDE_TIME
  # The window draws each frame as soon as it can until the caret arrives
  moving && (w.animating = true)
  # A caret that's moving doesn't blink
  since = time() - e.blink
  (moving || since < 0.5 || mod(since - 0.5, 1.0) >= 0.5) || return
  rectangle(ctx, left + px(at[1]) - 0.75px, top + px(at[2]), 1.5px, px(at[3]), background=colours.ink, border=0px)
end

# The caret and the selection are drawn over the text, once it has been placed
draw(ctx, size, ui::ConcreteRect, d::Document) = begin
  e = editor(d)
  b = e.buf
  e.origin = (ui.left, ui.top)
  tint_new(ctx, e, ui)
  fill_selection(ctx, selection_boxes(ctx, e, ui))
  with_others(() -> fill_selection(ctx, selection_boxes(ctx, e, ui)), b)
  outline_same_word(ctx, e, ui)
  mark_pointed(ctx, e, ui)
  underline_scrubs(ctx, e, ui)
  mark_clickable(ctx, e, ui)
  note_peek!(e)   # the card of a footnote whose number the mouse is on
  mark_checks(ctx, e, ui)
  mark_steps(ctx, e, ui)
  ring_part(ctx, e, ui)
  annotate(ctx, e, ui)
  mark_commented(ctx, e, ui)
  glow_bracket_pair(ctx, e, ui)
  # A file that's only shown has a selection and no caret. So has a page that's never changed.
  if !(caretless(b) || readonly(b))
    # Each caret has a number, so that it moves from its own last place. When there are more carets or fewer, the others start again.
    n = 1 + length(others(b))
    n == e.carets || (filter!(kv -> kv.first == 1, e.glides); e.carets = n)
    e.gliding = 1
    carets(ctx, e, ui)
    with_others(() -> (e.gliding += 1; carets(ctx, e, ui)), b)
    e.gliding = 1
  end
  e.by_step = false   # the step has been drawn. What moves the caret next may be a click.
  veil_later(ctx, e, ui)
  margin(ctx, e, ui)
end

"""
True when the selection is all in one code block, or in a file of code. The
space to the left of the code is the block's padding. There's no line outside
the block for the selection to line up with, so that space gets no colour.
"""
within_code(b::Buffer) = begin
  lo, hi = selection(b)
  kinds(b)[lo[1]].kind in (Kind.code, Kind.fence) && hi[1] <= codeblock(b, lo[1])[2]
end

"""
The boxes that cover the selection on the page, whose text is at `ui`. The
part of it that's in the cells of a table is filled here, a cell at a time.
"""
selection_boxes(ctx, e, ui) = begin
  b = e.buf
  # A line takes in the space left of its text only when the selection came into it from the line above
  margins = !within_code(b)
  # The selection goes under the caret, as one shape for each run of lines that touch
  rects = Rect[]
  for it in e.layout[e.shown]
    top = ui.top + it.top
    across, wide = item_room(e, it)   # an item in a column of the page starts at the column's left edge, and is as wide as the column
    left = ui.left + across
    if it.content isa Grid
      g = it.content
      if b.caret[1] != b.anchor[1]
        # A selection that covers several lines takes each row whole
        lo, hi = selection(b)
        y = top + TABLE_GAP
        lo[1] < it.first && hi[1] >= it.first && push!(rects, (num(left), num(top), num(left + 7px), num(y)))
        y += g.head   # a spreadsheet's row of letters isn't part of the text, so it's never selected
        for (r, i) in enumerate(g.rows)
          h = g.heights[r] + (r == length(g.rows) ? 2px : 1px)
          lo[1] <= i <= hi[1] && push!(rects, (num(left), num(y), num(left + wide), num(y + h)))
          y += h
        end
        lo[1] <= it.last && hi[1] > it.last && push!(rects, (num(left), num(y), num(left + 7px), num(y + TABLE_GAP)))
        continue
      end
      for (r, i) in enumerate(g.rows), (c, cell) in enumerate(g.cells[r])
        sel = selected(b, i)
        (sel !== nothing && sel[1] < cell.limit && sel[2] > cell.lo) || continue
        x, y = cell_origin(g, r, c)
        fill_selection(ctx, marks(g.flows[r][c], ui.left + x, top + y, (max(sel[1], cell.lo), min(sel[2], cell.limit), false), margin=false))
      end
    elseif it.content isa Sheet
      append!(rects, marks(e, it, it.content, left, top))
    elseif it.content isa Live
      # A live block is selected whole
      lo, hi = selection(b)
      selecting(b) && lo[1] <= it.first && hi[1] >= it.last &&
        push!(rects, (num(left), num(top), num(left + wide), num(top + it.tall)))
    else
      sel = selected(b, it.first)
      sel === nothing || append!(rects, marks(it.content, ui.left, top, sel, margin=margins && selection(b)[1][1] < it.first, edge=across))
    end
  end
  rects
end

"""
Draw the numbers of the lines, and the bars beside the lines that just changed,
in the room on the left of the text. The text of a page that's scrolled to the
right goes under that room, so the room is filled with the page's colour first.
"""
margin(ctx, e, ui) = begin
  across = sideways(e)
  left = ui.left + across   # where the text starts when it isn't scrolled
  room = PAGE_X + gutter(e)
  across > 0px && rectangle(ctx, left - room, ui.top, room, ui.height, background=colours.bg, border=0px)
  shade_line(ctx, e, left - room, ui.top)
  draw_numbers(ctx, e, left, ui.top)
  draw_fresh(ctx, e, left, ui.top)
  draw_diff_bars(ctx, e, left, ui.top)
end

const SHADE = 0.05   # how much of the colour of the text the shade of the caret's line has

"""
Shade the line that the caret is on, from `x` to the right edge of the window,
in a file of code whose settings ask for it. The shade is faint, so the text
shows through it. There's none while text is selected.
"""
shade_line(ctx, e, x, top) = begin
  b = e.buf
  (e.shade && numbered(b) && !caretless(b) && !readonly(b) && !selecting(b) && !isempty(e.layout)) || return
  it = item(e, b.caret[1])
  w, _ = window_size(e)
  rectangle(ctx, x, top + it.top, w - x, it.tall, background=RGBA(colours.ink, SHADE), border=0px)
end

"Draw the caret on the page, whose text is at `ui`"
carets(ctx, e, ui) = begin
  b = e.buf
  picked(b) === nothing || return   # a line round the part shows where the caret is
  for it in e.layout[e.shown]
    top = ui.top + it.top
    if it.content isa Grid
      g = it.content
      at = gridcell(g, b.caret)
      isspread(g) && at !== nothing && b.caret[1] == b.anchor[1] && ring(ctx, g, at, ui.left, top)
      for (r, i) in enumerate(g.rows), (c, cell) in enumerate(g.cells[r])
        x, y = cell_origin(g, r, c)
        at == (r, c) && caret(ctx, e, g.flows[r][c], ui.left + x, top + y, b.caret[2])
      end
      continue
    end
    it.content isa Sheet && caret(ctx, e, it.content, ui.left + item_room(e, it)[1], top)
    it.first == b.caret[1] && it.content isa Flow && caret(ctx, e, it.content, ui.left, top, b.caret[2])
  end
end
