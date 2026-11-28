# One thing in many parts of the page: the mouse on a thing in one part marks it in the others

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered
@use "./calendar" => Calendars
@use "./timelog" => Timelogs
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
@use "./fill_view" exports...
@use "./sheet_view" exports...
@use "./schedule_view" exports...
@use "./board_view" exports...
@use "./calendar_view" exports...
@use "./timelog_view" exports...
@use "./chart_view" exports...
@use "./columns_view" item_under

export item_table, named_rows, pointed_line, row_name, PointedThing, point_tick!

# --- one thing in many parts of the page -------------------------------------------------------
#
# One thing can show in many parts of a page. A to-do item is a line of the
# text, a card of a board, a bar of a schedule, a thing of a calendar's day
# and the rows of a time log. A row of a table is a bar of a chart. While the
# mouse is on a thing in one part, each other part marks the same thing, so
# you see where it is in all of them.
#
# A thing is known by its name: the words of a to-do item, the task of a row
# of a log, the first cell of a row of a table. No part sends another a
# message. `pointed(part)` is the name of what the mouse is on in a part, and
# `marked(part, name)` is true while the mouse is on a thing of that name
# anywhere in the page. A kind of block joins in with a method of `pointed`,
# and a call of `marked` where it draws a thing.

"A name as two parts of the page compare it. Capital letters, and the space round it, make no other name."
plain_name(name::AbstractString) = lowercase(strip(name))

"The colour `back` with the accent colour over it, as strong as a mark is: what's behind a thing that's marked"
mark_colour(back) = begin
  a, b = convert(RGBA{Float64}, back), convert(RGBA{Float64}, colours.accent)
  RGBA(a.r + (b.r - a.r) * MARK_FILL, a.g + (b.g - a.g) * MARK_FILL, a.b + (b.b - a.b) * MARK_FILL, 1.0)
end

"The name of the thing that the mouse is on in `part`, or nothing. A kind of block that shows things by name has a method."
pointed(part) = nothing

"What tells a thing of a calendar from the others for the rest of the page: the name of its task or its to-do item, or the words of an event"
thing_name(t::Calendars.Thing) = t.kind == :event ? t.words : t.key

pointed(v::BoardView) = begin
  v.grab === nothing || return nothing
  for card in values(v.parts)
    card isa BoardCard && ishovered(card) && return card.key
  end
  nothing
end

pointed(v::CalendarView) = begin
  v.grab === nothing || return nothing
  for c in values(v.parts)
    c isa CalendarThing && c.thing !== nothing && ishovered(c) && return thing_name(c.thing)
  end
  nothing
end

pointed(v::ScheduleView) = (i = v.grab === nothing ? hot_row(v) : 0; i == 0 ? nothing : v.tasks[i].todo.key)

pointed(v::TimelogView) = begin
  s = Timelogs.stretch(v.data, hot_stretch(v))
  s === nothing || isempty(s.task) ? nothing : s.task
end

pointed(v::ChartView) = begin
  a = get(v.parts, :area, nothing)
  (a === nothing || !ishovered(a) || v.shown === nothing) && return nothing
  m, labels = chart_hit(v), v.shown[2].labels
  m !== nothing && 1 <= m.label <= length(labels) ? labels[m.label] : nothing
end

"Each part of the page that shows: the children of the document, in the order of their lines"
shown_parts(e) = begin
  out = Any[]
  child = getfield(node!(Document, e, :document), :firstchild)
  while child !== nothing
    push!(out, child)
    child = getfield(child, :nextsibling)
  end
  out
end

"The table of the page that the item `it` shows, as `page_tables` gives it, or nothing"
item_table(e, it::Item) = (ts = page_tables(e); k = findfirst(t -> t.first == it.first, ts); k === nothing ? nothing : ts[k])

"The name of row `r` of a table of the page: its first cell that holds something. The row of the columns' names has none."
row_name(table, r::Int) = begin
  (1 <= r <= length(table.rows) && !(r == 1 && table.headed)) || return nothing
  k = findfirst(!isempty, table.rows[r])
  k === nothing ? nothing : table.rows[r][k]
end

"""
The rows of the table or the sheet that the item `it` shows, each with its
name, how far its top is from the top of the item, and how tall it is. A row
with no name is left out.
"""
named_rows(e, it::Item) = begin
  out = Tuple{String,px,px}[]
  g = it.content
  g isa Union{Grid,Sheet} || return out
  table = item_table(e, it)
  (table === nothing || table.ranged) && return out   # the rows of a sheet over a range are its values, and not its own rows
  y = g isa Grid ? TABLE_GAP + g.head : 0px
  for r in eachindex(g.rows)
    top, high = g isa Grid ? (y, g.heights[r] + 1px) : (row_top(g, r), g.heights[r])
    y += high
    name = row_name(table, r)
    name === nothing || push!(out, (name, top, high))
  end
  out
end

"""
The line of the page's text that the mouse is on, and the name of the thing
on it: a to-do item, or a row of a table, of a spreadsheet or of a sheet. It's
nothing when the mouse is on no such line.
"""
pointed_line(e) = begin
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return nothing
  win = window_of(e)
  (win === nothing || isempty(e.layout) || held(e, Keys.mouse_left) || !ishovered(node!(Document, e, :document))) && return nothing
  x, y = num(win.mouse[1]), num(win.mouse[2])
  line = todo_line(e, x, y)
  if line !== nothing
    k = findfirst(t -> t.line == line, page_todos(e))
    return k === nothing ? nothing : (line, page_todos(e)[k].key)
  end
  dx, dy = px(x) - e.origin[1], px(y) - e.origin[2]
  (0px <= dx < e.width && y >= num(above_page(e)) && dy >= 0px) || return nothing
  it = e.layout[item_under(e, dx, dy)]
  for (r, (name, top, high)) in enumerate(named_rows(e, it))
    it.top + top <= dy < it.top + top + high && return (it.first + r, name)
  end
  nothing
end

"The thing that the mouse is on in a window, as the last frame found it"
@def mutable struct PointedThing
  found::Union{Nothing,Tuple{Int,String}} = nothing   # the line of the page's text that the mouse is on, or 0, and the thing's name. Nothing when it's on no thing.
end

"""
Find the thing that the mouse is on, before the page is laid out: in the
page's text, or else in the first part of the page that says so. `pointed(e)`
gives its name until the next frame.
"""
point_tick!(e) = begin
  found = pointed_line(e)
  if found === nothing
    for part in shown_parts(e)
      name = pointed(part)
      name === nothing || (found = (0, name); break)
    end
  end
  state_of(e, PointedThing).found = found === nothing ? nothing : (found[1], plain_name(found[2]))
  e
end

"The name of the thing that the mouse is on, in any part of the page that shows, or nothing"
pointed(e::Editor) = (p = state_of(e, PointedThing).found; p === nothing ? nothing : p[2])

"True while the mouse is on a thing called `name`, in any part of the page"
marked(e::Editor, name::AbstractString) = (p = pointed(e); p !== nothing && p == plain_name(name))
marked(part, name::AbstractString) = marked(editor(part), name)

"""
Mark the thing that the mouse is on where the page's text has it too: a soft
box behind each to-do item and each row of a table that has its name. The line
that the mouse is on has none. The page's text is at `ui`.
"""
mark_pointed(ctx, e, ui) = begin
  p = state_of(e, PointedThing).found
  p === nothing && return
  from, name = p
  fill = tint(colours.accent, MARK_FILL)
  todos = nothing
  for it in e.layout[e.shown]
    across, wide = item_room(e, it)
    left, top = num(ui.left + across), num(ui.top + it.top)
    f = it.content
    if shows_box(f) && it.first != from
      todos === nothing && (todos = page_todos(e))
      k = findfirst(t -> t.line == it.first, todos)
      k !== nothing && plain_name(todos[k].key) == name && round_box(ctx, left - 6, top, num(wide) + 12, num(it.tall), 5; fill)
    elseif f isa Union{Grid,Sheet}
      long = f isa Grid ? num(f.left + sum(f.widths, init=0px) + 1px * (length(f.widths) + 1)) : num(wide)
      for (r, (row, y, high)) in enumerate(named_rows(e, it))
        plain_name(row) == name && it.first + r != from && round_box(ctx, left, top + num(y), long, num(high), 0; fill)
      end
    end
  end
end
