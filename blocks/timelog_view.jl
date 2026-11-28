# The view of a `timelog` block: a log of the hours on each task
#
# A code block in the language `timelog` keeps the hours that someone works
# on each task. timelog.jl says how the block is written, and adds the hours
# up. The block shows a row for each stretch of work, and the totals under
# the rows. At its top, a field takes a task, and the button beside it starts
# the clock on that task: a new line for now, with no stop time. While a line
# runs, its row counts up, and the button is lit and reads Stop. A click on it
# then writes the time now into the line. A task that's typed in the field
# while a line runs makes the button read Start again: a click stops that
# line and starts the new task. The field offers the tasks that the log
# already has, in a list like the one under a button of a `find` block. A
# click on a time or a task of a row lets you change it where it is, with no
# box round it, and Return writes what's typed there into the line. A `chart` block under a log draws
# the hours of each task.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor redraw_in! rect popup! close_popup! placed!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "../html" escape
@use "../markdown" words
@use "./sheet" parts shown
@use "./schedule" => Schedules
@use "./timelog" => Timelogs
@use Colors: @colorant_str, RGBA
@use Dates: Dates
@use "../base" exports...
@use "./sketch_view" exports...
@use "./csv_view" exports...
@use "./schedule_view" exports...

export TASKS_KEY, MOST_TASKS, LOG_ROW, LOG_DAY, LOG_TIME, LOG_HOURS, LOG_NARROW, LOG_SLIM, LOG_WRONG,
       TimelogView, LogCell, TaskOffers, TaskOffer, task_input, cell_input, log_fixed, write_log!, starts,
       clock!, cell_words, settle_cell!, open_cell!, show_offers!, shut_offers!, take_offer!, log_narrow,
       log_column, on_task, timelog_html, hot_stretch, log_to_day

const TASKS_KEY = :timelog_tasks   # the key of the list of tasks under the field
const MOST_TASKS = 6               # the rows that the list shows before it scrolls
const LOG_ROW = 28px               # how tall a row of the log is
const LOG_DAY, LOG_TIME, LOG_HOURS = 104px, 58px, 124px   # how wide the columns before the task are
const LOG_NARROW = 470px           # a log that's narrower than this has each day on a line of its own, and no column for the day
const LOG_SLIM = (52px, 112px)     # how wide the columns of a time and of the hours are in such a log
const LOG_WRONG = colorant"rgb(214,69,65)"   # the line under a time that's being changed and can't be read
push!(BLOCK_ICONS, "stopwatch", "play-fill", "stop-fill")

"What a `timelog` block shows: a row for each stretch of work, the totals, and a field and a button that start the clock"
@def mutable struct TimelogView <: SemanticUI
  n::Int = 0                               # its place among the page's time logs
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Timelogs.Log = Timelogs.Log()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its fields, its button and its cells, kept between frames
  editing::Any = nothing                   # the cell that's being changed where it is: its row, and :from, :to or :task
  wrong::Bool = false                      # what's typed there isn't a time
  offers::Vector{String} = String[]        # the tasks that the list under the field offers
  pick::Int = 0                            # the one of them that Return takes, or 0 for none
  typed::Any = nothing                     # what the field held when the offers were last worked out, or nothing while it has no keyboard
  minute::Int = -1                         # the minute that the page's charts last drew a running log for
end

"A time or a task of a row. A click lets you change it where it is."
@def mutable struct LogCell <: SemanticUI
  of::Any = nothing
  i::Int = 0
  part::Symbol = :task
end
"The list of tasks that floats under the field of a log"
@def mutable struct TaskOffers <: SemanticUI
  of::Any = nothing
  side::Symbol = :bottom   # the side of the field that it's on
  pick::Int = 0            # the row that was picked when it was last drawn. A row that the keys pick is brought in sight.
end
"A row of that list: a task that the log has"
@def mutable struct TaskOffer <: SemanticUI
  of::Any = nothing
  k::Int = 0
end

"The field at the top of a log. It holds the task that Start starts."
task_input(v::TimelogView) = block_part!(v, :input) do
  TextInput(placeholder="What are you working on?", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"The field that takes the place of a time or a task while you change it"
cell_input(v::TimelogView) = block_part!(v, :edit) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

reread!(v::TimelogView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Timelogs.timelog(lines)
  # The row of the cell that's being changed can go, as when ⌘Z takes its line back
  v.editing === nothing || Timelogs.stretch(v.data, v.editing[1]) !== nothing || (v.editing = nothing)
  v
end

"True when the page can't be changed, so the log can't be"
log_fixed(v::TimelogView) = (b = editor(v).buf; readonly(b) || b.fixed)

"Write the log into the lines of its block"
write_log!(v::TimelogView) = write_block!(v, TIMELOG, Timelogs.written(v.data))

"True when the button starts the clock: no line runs, or the field holds a task to change to"
starts(v::TimelogView) = Timelogs.running(v.data) === nothing || !isempty(strip(task_input(v).text))

"What the button does: it starts the clock on the task in the field, or it stops the line that runs"
clock!(v::TimelogView) = begin
  log_fixed(v) && return handled
  input = task_input(v)
  at = Timelogs.now()
  starts(v) ? Timelogs.start!(v.data, input.text, at) : Timelogs.stop!(v.data, at)
  input.text = ""
  input.anchor = input.cursor = 0
  shut_offers!(v)
  write_log!(v)
  handled
end

# A click on the button gives the keyboard back to the page, if the field had it
act!(v::TimelogView, action, w) = (action == :clock && clock!(v); w.focus === task_input(v) && focus(editor(v)); handled)

"The words of a part of the stretch `s`: a time as its line has it, or its task"
cell_words(s::Timelogs.Stretch, part::Symbol) =
  part == :task ? s.task : part == :from ? Timelogs.hhmm(s.from) : s.to === nothing ? "" : Timelogs.hhmm(s.to)

"""
Write what the field in a row holds into its line, and take the field away.
It gives false, and the field stays, when a time can't be read.
"""
settle_cell!(v::TimelogView) = begin
  v.editing === nothing && return true
  i, part = v.editing
  s = Timelogs.stretch(v.data, i)
  text = cell_input(v).text
  if s !== nothing && !log_fixed(v) && strip(text) != cell_words(s, part)
    Timelogs.set!(v.data, i, part, text) || (v.wrong = true; return false)
    write_log!(v)
  end
  v.editing, v.wrong = nothing, false
  true
end

"Put a field in the place of the cell `c`, with the cell's words in it and selected"
open_cell!(c::LogCell) = begin
  v = c.of
  log_fixed(v) && return handled
  settle_cell!(v) || (v.editing = nothing)   # another cell that was being changed is written first
  s = Timelogs.stretch(v.data, c.i)
  s === nothing && return handled
  input = cell_input(v)
  input.color = colours.ink
  input.text = cell_words(s, c.part)
  input.anchor, input.cursor = 0, length(input.text)
  v.editing, v.wrong = (c.i, c.part), false
  focus(input)
  handled
end

"Show the list of the tasks to offer under the field"
show_offers!(v::TimelogView, w) = begin
  list = TaskOffers(of=v)
  v.parts[:offers] = list
  r = rect(task_input(v))
  # The keys stay with the field, and a click outside the list is the app's, as it is with no list
  popup!(w, list, anchor=task_input(v), placement=:bottom, gap=9px, width=max(220px, r === nothing ? 0px : r.width + 16px), key=TASKS_KEY, modal=false,
         onclose=() -> (v.offers = String[]; v.pick = 0), theme=component_theme(editor(v).zoom))
end

"Take the list of tasks away. It comes back when what's in the field changes."
shut_offers!(v::TimelogView) = begin
  v.offers, v.pick = String[], 0
  w = window_of(v)
  w === nothing || close_popup!(w, TASKS_KEY)
  handled
end

"Put the task at row `k` of the list in the field, with the caret after it. Start, or Return, then starts it."
take_offer!(v::TimelogView, k::Int) = begin
  input = task_input(v)
  k in eachindex(v.offers) && (input.text = v.offers[k]; input.anchor = input.cursor = length(input.text))
  v.typed = input.text
  focus(input)
  shut_offers!(v)
end

"""
What happens to a log in each frame, before the page is laid out. A click
somewhere else writes what the field in a row holds. The list under the top
field gets the tasks that have what's typed there, and goes when the field
loses the keyboard. A chart of a log that runs is drawn again each minute.
"""
block_tick!(v::TimelogView) = begin
  w = window_of(v)
  v.editing !== nothing && (w === nothing || w.focus !== cell_input(v)) && (settle_cell!(v) || (v.editing = nothing))
  input = task_input(v)
  if w === nothing || w.focus !== input
    v.typed === nothing || (v.typed = nothing; shut_offers!(v))
  elseif input.text != v.typed
    v.typed = input.text
    v.offers, v.pick = Timelogs.offered(v.data, input.text), 0
    isempty(v.offers) ? close_popup!(w, TASKS_KEY) : show_offers!(v, w)
  end
  if Timelogs.running(v.data) !== nothing && (minute = Dates.minute(Timelogs.now())) != v.minute
    v.minute = minute
    e = editor(v)
    delete!(e.flows, (:tables, e.buf.path, e.buf.version, table_reads[], sums_run[], page_day(e)))
    foreach(node -> node isa ChartView && (node.shown = nothing), values(e.nodes))
  end
  v
end

describe(o::TaskOffer) = begin
  v = o.of
  o.k <= length(v.offers) ? float_row(v.offers[o.k], picked=v.pick == o.k) : Box(height(0px))
end

cursor(::TaskOffer) = :hand
onkey(o::TaskOffer, ::KeyPress{Keys.mouse_left}) = take_offer!(o.of, o.k)
# The mouse picks the task that it's over, as the arrow keys do
onmouse(o::TaskOffer, ::MouseMove) = begin
  v = o.of
  v.pick = o.k
  list = get(v.parts, :offers, nothing)
  list === nothing || (list.pick = o.k)   # it's in sight already, so the list doesn't scroll to it
  handled
end

describe(l::TaskOffers) = begin
  v = l.of
  c = found_colours()
  n, high = length(v.offers), FLOAT_ROW
  scroll = get!(() -> Scroll(width(grow=grow)), v.parts, :offer_scroll)
  # Half a row at the bottom says that the list goes on
  scroll.height = height(n <= MOST_TASKS ? n * high : MOST_TASKS * high - high / 2)
  l.pick == v.pick || (l.pick = v.pick; v.pick > 0 && scroll_into_view!(scroll, high * (v.pick - 1), high * v.pick))
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Tasks",
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [block_part!(() -> TaskOffer(of=v, k=k), v, (:offer, k)) for k in 1:n]...)))
end

placed!(l::TaskOffers, side) = (l.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, l::TaskOffers) = caret(ctx, ui, l.side, rect(task_input(l.of)))

# The keys that a field of the log has no use for come here. Return in the field of a row writes what's typed
# there. In the top field, it takes the task that's picked in the list, or does what the button does.
onkey(v::TimelogView, ev::KeyPress{Keys.enter}) = begin
  unmodified(ev) || return nothing
  w = ev.window
  if w.focus === cell_input(v)
    settle_cell!(v) && focus(editor(v))
  elseif w.focus === task_input(v)
    v.pick > 0 && return take_offer!(v, v.pick)
    starts(v) && clock!(v)
    focus(editor(v))
  else
    return nothing
  end
  handled
end
# Esc leaves a row as it was. In the top field, it closes the list, and then gives the keyboard back to the page.
onkey(v::TimelogView, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  w = ev.window
  if w.focus === cell_input(v)
    v.editing, v.wrong = nothing, false
    focus(editor(v))
  elseif w.focus === task_input(v)
    isempty(v.offers) ? focus(editor(v)) : shut_offers!(v)
  else
    return nothing
  end
  handled
end
onkey(v::TimelogView, ev::KeyPress{Keys.down}) = unmodified(ev) ? (isempty(v.offers) ? nothing : (v.pick = min(v.pick + 1, length(v.offers)); handled)) : nothing
onkey(v::TimelogView, ev::KeyPress{Keys.up}) = unmodified(ev) ? (isempty(v.offers) ? nothing : (v.pick = max(v.pick - 1, 0); handled)) : nothing

"True when the log is too narrow for a column of days. Each day is then on a line of its own, over its rows."
log_narrow(v::TimelogView) = editor(v).width < LOG_NARROW

"Words in a column of a log. `wide` says how wide the column is."
log_column(wide, words; size=13px, color=colours.ink, weight="") =
  Row(wide, height(24px), padding(6px, 0px), Alignment.Center, clip=true, Box(label(words, size, color=color, weight=weight)))

describe(c::LogCell) = begin
  v = c.of
  s = Timelogs.stretch(v.data, c.i)
  s === nothing && return Box(width(0px))
  wide = c.part == :task ? width(grow=grow) : fixed(log_narrow(v) ? LOG_SLIM[1] : LOG_TIME)
  if v.editing == (c.i, c.part)
    # The words are changed where they are, with no box round them. A time that can't be read has a red line under it.
    field = Row(wide, height(24px), padding(6px, 0px), Alignment.Center, Box(width(grow=grow), height(grow=grow), cell_input(v)))
    v.wrong && (field.border = border(1px, :solid, LOG_WRONG)[:bottom])
    return field
  end
  words = cell_words(s, c.part)
  # A row with no stop time says "now" while it runs. A row with no task says so.
  shown = !isempty(words) ? words : c.part == :task ? "No task" : Timelogs.running(v.data) == c.i ? "now" : "–"
  Row(wide, height(24px), padding(6px, 0px), radius(5px), Alignment.Center, clip=true, background(ishovered(c) && !log_fixed(v) ? colours.hover : clear),
      Box(label(shown, 13px, color=isempty(words) ? colours.faint : colours.ink)))
end

cursor(c::LogCell) = log_fixed(c.of) ? :arrow : :ibeam
cursor(::TimelogView) = :arrow
onkey(c::LogCell, ::KeyPress{Keys.mouse_left}) = c.of.editing == (c.i, c.part) ? nothing : open_cell!(c)

"What the button's tooltip says after \"Start the clock\": the task, if there is one"
on_task(task) = isempty(task) ? "" : " on " * task

describe(v::TimelogView) = begin
  e = editor(v)
  log = v.data
  at = Timelogs.now()
  run = Timelogs.running(log)
  # The row that runs counts up, so the window draws again when the next second starts
  run === nothing || redraw_in!(v, 1.02 - Dates.millisecond(at) / 1000)
  with_theme(component_theme(e.zoom)) do
    input = task_input(v)
    input.color = colours.ink
    w = window_of(v)
    typing = w !== nothing && w.focus === input
    field = Row(width(grow=grow), height(26px), padding(8px, 0px), child_gap=7px, radius(6px), Alignment.Center, background(colours.bg),
                border(1px, :solid, typing ? colours.accent : colours.line),
                Icon("stopwatch", size=12px, color=run === nothing ? colours.dim : colours.accent), Box(width(grow=grow), height(grow=grow), input))
    # The button reads what a click does. It's lit while a line runs, and its tooltip says which task the click is for.
    typed = Timelogs.tidy(input.text)
    next = on_task(isempty(typed) ? Timelogs.last_task(log) : typed)
    button = !starts(v) ? block_button!(v, :clock, :clock, icon="stop-fill", words="Stop", on=true, tip="Stop the clock" * on_task(log.rows[run].task)) :
             block_button!(v, :clock, :clock, icon="play-fill", words="Start", bold=true, off=log_fixed(v),
                           tip=run === nothing ? "Start the clock" * next : "Stop the clock" * on_task(log.rows[run].task) * ", and start it" * next)
    bar = block_bar(field, Box(width(4px)), button)
    isempty(log.rows) && return Column(block_look()..., clip=true, name="Time log", bar,
      block_note("This log has no hours yet. Type a task in the field and click Start."))
    narrow = log_narrow(v)
    time_wide, hours_wide = narrow ? LOG_SLIM : (LOG_TIME, LOG_HOURS)
    head = Row(width(grow=grow), height(24px), padding(6px, 0px), Alignment.Center,
      (narrow ? () : (log_column(fixed(LOG_DAY), "Day", size=11px, color=colours.dim),))...,
      log_column(fixed(time_wide), "From", size=11px, color=colours.dim), log_column(fixed(time_wide), "To", size=11px, color=colours.dim),
      log_column(fixed(hours_wide), "Hours", size=11px, color=colours.dim), log_column(width(grow=grow), "Task", size=11px, color=colours.dim))
    rows, day, hot = Any[], nothing, hot_stretch(v)
    for (i, r) in enumerate(log.rows)
      if r isa String
        # A line that can't be read shows as it's written
        push!(rows, Row(width(grow=grow), height(LOG_ROW), padding(12px, 0px), Alignment.Center, clip=true, Box(label(r, 13px, color=colours.faint)), Box(width(grow=grow))))
        continue
      end
      # The day shows once, for the first of its rows
      fresh = r.day != day
      day = r.day
      narrow && fresh && push!(rows, Row(width(grow=grow), height(24px), padding(12px, 0px), Alignment.Center,
                                         Box(label(Timelogs.day(r.day), 12px, color=colours.dim, weight="Semibold")), Box(width(grow=grow))))
      runs = i == run
      hours = runs ? Timelogs.elapsed(Timelogs.seconds(log, i, at)) : r.to === nothing ? "–" : Timelogs.hours(Timelogs.counted(log, i, at))
      # A row is marked while the mouse is on its task: in another row, or in another part of the page
      lit = !isempty(r.task) && i != hot && marked(v, r.task)
      push!(rows, Row(width(grow=grow), height(LOG_ROW), padding(6px, 0px), Alignment.Center, background(lit ? tint(colours.accent, MARK_FILL) : runs ? RGBA(colours.accent, 0.09) : clear),
        (narrow ? () : (log_column(fixed(LOG_DAY), fresh ? Timelogs.day(r.day) : "", color=colours.dim),))...,
        block_part!(() -> LogCell(of=v, i=i, part=:from), v, (:cell, i, :from)), block_part!(() -> LogCell(of=v, i=i, part=:to), v, (:cell, i, :to)),
        log_column(fixed(hours_wide), hours, color=runs ? colours.accent : r.to === nothing || r.day > page_day(e) ? colours.faint : colours.ink, weight=runs ? "Semibold" : ""),
        block_part!(() -> LogCell(of=v, i=i, part=:task), v, (:cell, i, :task))))
    end
    # Under the rows: the total, and the hours of each task when the log has more than one
    sums = Any[]
    if any(r -> r isa Timelogs.Stretch, log.rows)
      lead = (narrow ? 0px : LOG_DAY) + 2time_wide
      sum_row(name, minutes, weight) = Row(width(grow=grow), height(LOG_ROW), padding(6px, 0px), Alignment.Center,
        background(isempty(weight) && marked(v, name) ? tint(colours.accent, MARK_FILL) : clear),
        log_column(fixed(lead), elide(name, 13px, lead - 12px), color=isempty(weight) ? colours.dim : colours.ink, weight=weight),
        log_column(fixed(hours_wide), Timelogs.hours(minutes), weight=weight),
        log_column(width(grow=grow), something(Timelogs.money(log, minutes), ""), weight=weight))
      # A page that shows a day that's past adds up the hours to that day
      counted = log_to_day(e, log)
      tasks = Timelogs.tasks(counted, at)
      push!(sums, Box(width(grow=grow), padding(12px, 4px), Box(width(grow=grow), height(1px), background(colours.line))),
            sum_row(counted === log ? "Total" : "To " * Schedules.short(page_day(e)), Timelogs.total(counted, at), "Semibold"))
      length(tasks) > 1 && append!(sums, (sum_row(isempty(name) ? "No task" : name, minutes, "") for (name, minutes) in tasks))
    end
    Column(block_look()..., clip=true, name="Time log", bar, head, rows..., sums..., Box(height(6px)))
  end
end

"The log as HTML: a table with a row for each stretch of work, and the totals at its foot"
timelog_html(e, v::TimelogView) = begin
  log = v.data
  isempty(log.rows) && return nothing
  at = Timelogs.now()
  run = Timelogs.running(log)
  rows, day = String[], nothing
  for (i, r) in enumerate(log.rows)
    if r isa String
      push!(rows, "<tr><td colspan=\"5\" style=\"color: #a39a8a\">$(escape(r))</td></tr>")
      continue
    end
    shown = r.day == day ? "" : Timelogs.day(r.day)
    day = r.day
    to = r.to !== nothing ? Timelogs.hhmm(r.to) : i == run ? "now" : ""
    hours = r.to === nothing && i != run ? "" : Timelogs.hours(Timelogs.counted(log, i, at))
    push!(rows, "<tr><td>$shown</td><td>$(Timelogs.hhmm(r.from))</td><td>$to</td><td>$hours</td><td>$(escape(r.task))</td></tr>")
  end
  sum_row(name, minutes, cell) =
    "<tr><$cell colspan=\"3\">$(escape(name))</$cell><$cell>$(Timelogs.hours(minutes))</$cell><$cell>$(something(Timelogs.money(log, minutes), ""))</$cell></tr>"
  sums = String[]
  if any(r -> r isa Timelogs.Stretch, log.rows)
    tasks = Timelogs.tasks(log, at)
    push!(sums, sum_row("Total", Timelogs.total(log, at), "th"))
    length(tasks) > 1 && append!(sums, (sum_row(isempty(name) ? "No task" : name, minutes, "td") for (name, minutes) in tasks))
  end
  "<table>\n<thead><tr><th>Day</th><th>From</th><th>To</th><th>Hours</th><th>Task</th></tr></thead>\n<tbody>\n" * join(rows, "\n") *
  "\n</tbody>\n<tfoot>\n" * join(sums, "\n") * "\n</tfoot>\n</table>"
end

BLOCKS[TIMELOG] = TimelogView
block_name(::Type{TimelogView}) = "Time log"
block_icon(::Type{TimelogView}) = "stopwatch"
block_insert(::Type{TimelogView}) = ("Time Log", ["```$TIMELOG", "```", "", ""], (4, 0))
block_table_kind(::Type{TimelogView}) = "time log"
block_html(e, v::TimelogView) = timelog_html(e, v)
block_tables!(::Type{TimelogView}, e, i::Int, t::Int, under::AbstractString, out) = begin
  rows = Timelogs.table(log_to_day(e, Timelogs.timelog(e.buf.lines[i+1:t-1])), Timelogs.now())
  length(rows) > 1 && push!(out, (first=i, last=t, under=under, rows=rows, headed=true, ranged=false))
end
block_names(::Type{TimelogView}, lines) = Tuple{String,String}[(task, string(round(minutes / 60, digits=4)) * "hr")
                                                               for (task, minutes) in Timelogs.tasks(Timelogs.timelog(lines), Timelogs.now()) if !isempty(strip(task))]

"The place of the row of a log that the mouse is on, or 0"
hot_stretch(v::TimelogView) = begin
  w = window_of(v)
  (w === nothing || !ishovered(v)) && return 0
  y = w.mouse[2]
  for i in eachindex(v.data.rows)
    c = get(v.parts, (:cell, i, :task), nothing)
    r = c === nothing ? nothing : rect(c)
    r !== nothing && r.top - 2px <= y < r.top + r.height + 2px && return i
  end
  0
end

"A log with only the hours to the page's day, when that day is past. If not, the log itself."
log_to_day(e, log::Timelogs.Log) = (d = page_day(e); d < calendar_today() ? Timelogs.upto(log, d) : log)
