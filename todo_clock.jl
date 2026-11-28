# The clock of a to-do item, on a page with a time log

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" describe handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! redraw_in!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./markdown" Kind words isdone
@use "./timelog" => Timelogs
@use Dates: Dates
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
@use "./schedule_view" exports...
@use "./timelog_view" exports...

export clocked, page_minutes, stop_clock!

# --- the clock of a to-do item -----------------------------------------------------------------
#
# On a page with a time log, the mouse over a to-do item shows a small
# button at the end of the item's line, with the hours that the log has for
# the item. A click starts the log's clock on the item: the log gets a new
# line for now, with the item's words as its task. While the clock runs on
# the item, the button stops it. A tick in the item's box stops it too.
#
# The item and the log send each other nothing. The button calls the log's
# own `Timelogs.start!` and `Timelogs.stop!` on the log's view, and writes
# the log's block. The schedule asks `worked` for the hours of each task, and
# shows them beside the task's name.

push!(BLOCK_ICONS, "play-fill", "stop-fill")

"The view of the page's first time log, read again from the lines of its block, or nothing when the page has none or can't be changed"
page_log(e) = begin
  b = e.buf
  (readonly(b) || b.fixed) && return nothing
  span = get!(() -> block_lines(b, TIMELOG, 1), e.flows, (:log_block, b.path, b.version))
  span === nothing && return nothing
  v = block_view(e, TIMELOG, 1)
  v.first, v.last = span
  reread!(v, b.lines[span[1]+1:span[2]-1])
end

"""
The minutes that the page's time logs have for each task, by the task's name
as `plain_name` gives it. A row that runs counts up to now, so they're worked
out again each minute, and when the page has changed.
"""
page_minutes(e) = begin
  b = e.buf
  at = Timelogs.now()
  get!(e.flows, (:minutes, b.path, b.version, Dates.format(at, "yyyymmddHHMM"))) do
    out = Dict{String,Int}()
    ks = kinds(b)
    for (i, k) in enumerate(ks)
      (k.kind == Kind.fence && k.level == 0 && k.lang == TIMELOG) || continue
      t = codeblock(b, i)[2]
      (t > i && ks[t].kind == Kind.fence && ks[t].level == 1) || continue
      for (task, minutes) in Timelogs.tasks(Timelogs.timelog(b.lines[i+1:t-1]), at)
        out[plain_name(task)] = get(out, plain_name(task), 0) + minutes
      end
    end
    out
  end
end

"The minutes that the page's time logs have for the task called `name`"
worked(e, name::AbstractString) = get(page_minutes(e), plain_name(name), 0)

"The to-do item of the page that a schedule calls `key`, or nothing"
todo_called(e, key) = (items = page_todos(e); k = findfirst(t -> t.key == key, items); k === nothing ? nothing : items[k])

"True when the clock of the log `log` runs on the task called `name`"
clocked(log::TimelogView, name::AbstractString) = begin
  run = Timelogs.running(log.data)
  run !== nothing && plain_name(log.data.rows[run].task) == plain_name(name)
end

describe(c::ItemClock) = begin
  e = editor(c)
  log, t = page_log(e), todo_called(e, c.key)
  (log === nothing || t === nothing) && return Box(width(0px), height(18px))
  on = clocked(log, t.name)
  on && redraw_in!(c, 1.0)   # the hours count up
  minutes = worked(e, t.name)
  words = on ? Timelogs.elapsed(Timelogs.seconds(log.data, Timelogs.running(log.data), Timelogs.now())) : minutes > 0 ? Timelogs.hours(minutes) : ""
  Row(height(18px), child_gap=4px, Alignment.Center, name="Clock",
    Box(width(18px), height(18px), radius(4px), Alignment.Center, justify=Alignment.Center,
        background(on ? colours.active : ishovered(c) ? colours.hover : clear),
      Icon(on ? "stop-fill" : "play-fill", size=12px, color=on ? colours.accent : colours.dim)),
    (isempty(words) ? () : (Box(label(words, 12px, color=on ? colours.accent : colours.dim)),))...)
end

cursor(::ItemClock) = :hand
draw(ctx, size, ui::ConcreteRect, c::ItemClock) = (c.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(c::ItemClock, ev::MouseMove) = begin
  e = editor(c)
  log, t = page_log(e), todo_called(e, c.key)
  (log === nothing || t === nothing) && return handled
  show_tooltip!(ev.window, tip_label(clocked(log, t.name) ? "Stop the clock" : "Start the clock on this item"), c.rect..., placement=:top, gap=6px)
  handled
end

onkey(c::ItemClock, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(c)
  log, t = page_log(e), todo_called(e, c.key)
  hide_tooltip!(ev.window)
  (log === nothing || t === nothing) && return handled
  at = Timelogs.now()
  clocked(log, t.name) ? Timelogs.stop!(log.data, at) : Timelogs.start!(log.data, t.name, at)
  write_log!(log)
  handled
end

"""
Stop the clock of the page's time log, when it runs on the to-do item of line
`i` and the item has just been ticked. The stop is taken back with the tick.
"""
stop_clock!(e, i::Int) = begin
  b = e.buf
  (1 <= i <= length(b.lines) && isdone(b.lines[i])) || return e
  log = page_log(e)
  log === nothing && return e
  k = findfirst(t -> t.line == i, page_todos(e))
  (k !== nothing && clocked(log, page_todos(e)[k].name)) || return e
  Timelogs.stop!(log.data, Timelogs.now())
  b.typed = time()   # the tick and the log's line change together, so one ⌘Z takes both back
  write_block!(log, TIMELOG, Timelogs.written(log.data), typing=true)
  b.typed = 0.0
  e
end
