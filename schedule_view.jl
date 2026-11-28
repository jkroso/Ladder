# The view of a `schedule` block, and a to-do item of a page that has a schedule
#
# A code block in the language `schedule` shows each to-do item of the page as
# a bar on a line of days. schedule.jl says how the block is written.
#
#   - Drag a bar to say the first day that its task can start.
#   - Drag the right end of a bar to say how many working days the task takes.
#   - Drag from the circle after a bar to another task. That task then waits
#     for this one, and starts when this one is finished. An arrow shows it.
#   - Click an arrow and press Delete to take it away.
#   - Click a task twice to go to its line of the page.
#   - Drag the days, or scroll sideways, to see other days. Pinch, or scroll
#     with ⌘ held, to show more days or fewer.
#   - The button at the top right makes the schedule fill the window. Esc puts
#     it back in the page.
#
# Every change is written into the block's lines, so the file holds the whole
# schedule. While the page has a schedule, the mouse over a to-do item shows
# the task's days beside the item, with buttons that make the task a day
# longer or shorter.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! rect MouseScroll Pinch onpinch with_clip
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./transcribe" finished
@use "./html" escape
@use "./markdown" words
@use "./sheet" parts
@use "./schedule" => Schedules
@use "./repeats" => Repeats
@use "./day" => Days
@use Colors: RGBA
@use Dates: Dates, Date, Day
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
@use "./takeoff_view" exports...
@use "./fill_view" exports...
@use "./file_view" exports...
@use "./live_view" exports...
@use "./columns_view" item_under

export TASK_H, TASK_BAR, DATES_H, DAY_MOST, DAY_LEAST, DAY_USUAL, TASK_BAR_EDGE, KNOB, KNOB_GAP,
       NAMES_W, NAMES_FULL, DETAILS_H, DAY_ZERO, SCHEDULE_ICONS, ScheduleView, ChartArea, TaskName,
       TaskDetails, DayButton, schedule_input, chart, page_todos, schedule_view, replan!, tasks!,
       task_place, chart_h, save_page!, daynum, numday, day_x, x_day, bar_box, task_bar, task_runs,
       time_bar, row_bars, knob_place, knob, time_at, time_words, link_points, away, under, hot_row,
       task_days, task_words, zoom_days!, arrow, draw_days, task_hue, run_done, draw_bar, hot_time,
       draw_bars, draw_links, zoom_x, names_w, page_schedule, todo_line, task_over, task_of,
       page_log

const TASK_H = 30.0        # px: how tall the row of a task is
const TASK_BAR = 20.0         # and how tall its bar is
const DATES_H = 46.0       # how tall the months and the days over the rows are
const DAY_MOST = 60.0      # the most px to a day
const DAY_LEAST = 2.5      # and the least
const DAY_USUAL = 34.0     # the most px to a day when a schedule shows all its tasks
const TASK_BAR_EDGE = 7.0  # px at the right end of a bar, where a drag makes the task longer or shorter
const KNOB = 4.5           # the radius of the circle after a bar, which a link is dragged from
const KNOB_GAP = 11.0      # from the end of a bar to the middle of that circle
const NAMES_W = 250px      # how wide the names of the tasks are at the most
const NAMES_FULL = 360px   # and at the most in a schedule that fills the window
const DETAILS_H = 24px     # how tall the days of a to-do item are beside the item
const DAY_ZERO = Date(2000, 1, 1)   # day number 0
"Every icon that a schedule can show. The built app reads them all when it's made."
const SCHEDULE_ICONS = ["bar-chart-steps", "calendar-event", "zoom-out", "zoom-in", "aspect-ratio", "dash", "plus", "check",
                        "arrows-fullscreen", "fullscreen-exit"]

"What a `schedule` block shows: the page's tasks, each as a bar on a line of days"
@def mutable struct ScheduleView <: SemanticUI
  n::Int = 0                              # its place among the page's schedules
  first::Int = 0                          # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Schedules.Schedule = Schedules.Schedule()
  lines::Vector{String} = String[]        # the lines that `data` was read from
  tasks::Vector{Schedules.Planned} = Schedules.Planned[]   # the page's tasks, with the days of each
  planned::Any = nothing                  # the version of the page, and the day, that `tasks` was worked out for
  renamed::Bool = false                   # a task has a new name that the block's lines don't have yet
  zoom::Float64 = 0.0                     # px to a day. 0 shows every task.
  at::Float64 = 0.0                       # the number of the day at the left edge of the bars
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the days and the bars were last drawn in the window
  picked::Any = nothing                   # what's selected: (:task, key), or (:link, key, key) for the link from one task to the next
  grab::Any = nothing                     # a drag: of a bar, of a bar's end, of a link or of the days
  clicked::NTuple{3,Float64} = (0.0, 0.0, 0.0)   # when and where it was last clicked
  asking::Bool = false                    # the text field for the day that the work starts shows
  said::String = ""                       # what the top of the block says when something can't be done
  parts::Dict{Any,Any} = Dict{Any,Any}()  # its buttons, names and text field, kept between frames
  full::Bool = false                      # it fills the window, over the page
  tall::px = 0px                          # how tall it was in the page when it was last laid out there
  pinned::px = 0px                        # how far the page was scrolled when it filled the window
end

"The part of a schedule that shows the days and the bars"
@def mutable struct ChartArea <: SemanticUI
  of::Any = nothing
end
"The name of a task, beside its bar"
@def mutable struct TaskName <: SemanticUI
  of::Any = nothing
  key::String = ""
end
"""
The days of the to-do item under the mouse. They show beside the item while
the page has a schedule: the task's first and last day, how many days it
takes, and what it waits for.
"""
@def mutable struct TaskDetails <: SemanticUI
  of::Any = nothing                # the schedule
  key::String = ""                 # the task
  floats::Bool = false             # it's under the item's first line, because that line has no room for it
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where it was last put in the window
  less::Any = nothing              # its two buttons
  more::Any = nothing
end
"A button beside a to-do item that makes its task a day longer or a day shorter"
@def mutable struct DayButton <: SemanticUI
  by::Int = 1
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
end

"The button of `v` that's kept under `key`, with what it does and shows now"
button!(v::ScheduleView, key, action; icon="", words="", tip="", off=false) = block_button!(v, key, action; icon, words, tip, off)

"The text field of a schedule, for the day that the work starts"
schedule_input(v::ScheduleView) = part!(v, :input) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

field(v::ScheduleView, wide=width(grow=grow)) =
  Box(wide, height(24px), padding(6px, 0px), radius(5px), border(1px, :solid, colours.accent), background(colours.bg), schedule_input(v))

chart(v::ScheduleView) = part!(() -> ChartArea(of=v), v, :area)

# --- the block's lines and the page's tasks -------------------------------------------------

"The to-do items of the page that shows"
page_todos(e) = (b = e.buf; get!(() -> Schedules.todos(b.lines, kinds(b)), e.flows, (:todos, b.path, b.version)))

"The view of the `n`th schedule of the page that shows"
schedule_view(e, n) = block_view(e, SCHEDULE, n)

"Read the schedule again from the lines of its block, if they've changed"
reread!(v::ScheduleView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  start = v.data.start
  v.data = Schedules.schedule(lines)
  v.planned = nothing
  v.renamed = false
  # When the work starts on another day, as it does after ⌘Z takes a new day back, every task shows again
  v.data.start == start || (v.zoom = 0.0)
  v
end

"Work out the days of the page's tasks again. A task that was renamed in the page keeps its line of the schedule."
replan!(v::ScheduleView) = begin
  e = editor(v)
  names = [entry.name for entry in v.data.entries]
  v.tasks = Schedules.plan!(v.data, page_todos(e))
  names == [entry.name for entry in v.data.entries] || (v.renamed = true)
  v.planned = (e.buf.version, Dates.today())
  v
end

"The page's tasks with the days of each. They're worked out again when the page has changed, and on a new day."
tasks!(v::ScheduleView) = (v.planned == (editor(v).buf.version, Dates.today()) || replan!(v); v.tasks)

"The place of the task called `key` in the list of tasks, or nothing"
task_place(v::ScheduleView, key) = findfirst(t -> t.todo.key == key, v.tasks)

"""
Write the schedule into its block. The caret stays where it was in the text,
and ⌘Z takes the change back. If the block's lines aren't the ones that the
schedule was read from, something else changed them, and the schedule is read
again. The lines of tasks that the page no longer has go.
"""
commit!(v::ScheduleView) = begin
  e = editor(v)
  b = e.buf
  readonly(b) && return v
  span = block_lines(b, SCHEDULE, v.n)
  span === nothing && return v
  i, t = span
  v.first, v.last = i, t
  b.lines[i+1:t-1] == v.lines || return reread!(v, b.lines[i+1:t-1])
  # The day that the work starts is written down, so that it's the same day tomorrow
  v.data.start === nothing && (v.data.start = Schedules.workday(Dates.today(), v.data.weekends))
  Schedules.prune!(v.data, page_todos(e))
  new = Schedules.written(v.data)
  v.planned = nothing
  v.renamed = false
  new == v.lines && return v
  write_block!(v, SCHEDULE, new, reread=false)
end

prepare_block!(e, v::ScheduleView) = (tasks!(v); v)
before_fill!(v::ScheduleView, ::Bool) = (v.zoom = 0.0)
fill_focus(v::ScheduleView, ::Bool) = keyboard_part(v)

before_save!(v::ScheduleView) = begin
  b = editor(v).buf
  span = block_lines(b, SCHEDULE, v.n)
  span === nothing && return v
  reread!(v, b.lines[span[1]+1:span[2]-1])
  tasks!(v)
  v.renamed && commit!(v)
  v
end

"How tall the names and the bars are in a schedule that fills the window, when its tasks need less: the window, under the top bar and the schedule's buttons"
full_room(v::ScheduleView) = num(window_size(editor(v))[2] - above_page(editor(v)) - 38px)

"How tall the names and the bars of a schedule are"
chart_h(v::ScheduleView) = (rows = DATES_H + TASK_H * length(v.tasks); px(v.full ? max(rows, full_room(v)) : rows))

"""
Write the page to its file. A block that has changes to commit before saving
does so first (for instance, a schedule records renamed tasks). A page from a
web server is a file in the browser folder, so it's written there and never to
the server.
"""
save_page!(e) = begin
  write_blocks!(e)   # what a block that a file defines holds now goes into its lines
  for (key, node) in collect(e.nodes)
    (key isa Tuple && length(key) == 4 && key[1] == :block && key[3] == e.buf.path) || continue
    before_save!(node)
  end
  save!(e.buf)
  # A page that a part of this one shows, and that was changed there, is saved with it
  foreach(b -> dirty(b) && save!(b), shown_buffers(e))
end

# --- where things are ------------------------------------------------------------------------

"The number of the day `d`: one more for each day that passes"
daynum(d::Date) = Float64(Dates.value(d - DAY_ZERO))
"The day with the number `n`"
numday(n::Real) = DAY_ZERO + Day(floor(Int, n))

"How far across the window day number `n` starts"
day_x(v::ScheduleView, n::Real) = v.box[1] + (n - v.at) * v.zoom
"The number of the day at `x` across the window, with the part of the day that's passed"
x_day(v::ScheduleView, x::Real) = v.at + (x - v.box[1]) / v.zoom

"Where the bar of the task at place `i` is in the window for its run from `start` to `finish`: its left, top, width and height"
bar_box(v::ScheduleView, i::Int, start::Date, finish::Date) = begin
  left, right = day_x(v, daynum(start)) + 1, day_x(v, daynum(finish) + 1) - 1
  (left, v.box[2] + DATES_H + (i - 1) * TASK_H + (TASK_H - TASK_BAR) / 2, max(right - left, 3.0), TASK_BAR)
end

"Where the bar of the first run of the task at place `i` is in the window: its left, top, width and height"
task_bar(v::ScheduleView, i::Int) = (t = v.tasks[i]; bar_box(v, i, t.start, t.finish))

"The first and the last day of each run after the first of the task at place `i`, when its item says how often it repeats, up to the last day in sight"
task_runs(v::ScheduleView, i::Int) =
  v.zoom > 0 ? Schedules.runs(v.tasks[i], numday(v.at + v.box[3] / v.zoom), v.data.weekends) : Tuple{Date,Date}[]

"Where the bar of the time `k` of the task at place `i` is in the window: its first bar when `k` is 1. Nothing when it has no such time."
time_bar(v::ScheduleView, i::Int, k::Int) = begin
  k == 1 && return task_bar(v, i)
  d = Schedules.time_days(v.tasks[i], k, v.data.weekends)
  d === nothing ? nothing : bar_box(v, i, d...)
end

"The bars of the task at place `i` that are in sight, or before them: its first, then each time after it up to the last day in sight"
row_bars(v::ScheduleView, i::Int) = [task_bar(v, i); [bar_box(v, i, a, z) for (a, z) in task_runs(v, i)]]

"""
The middle of the circle that a link is dragged from, for the bar `b`, when the
next bar of its task is `n`, or nothing: after the bar, or on its top right
corner when `n` leaves no room after it. And true when it's on the corner.
"""
knob_place(b, n) = n === nothing || n[1] - (b[1] + b[3]) >= KNOB_GAP + KNOB + 3 ?
  ((b[1] + b[3] + KNOB_GAP, b[2] + b[4] / 2), false) : ((b[1] + b[3] - KNOB - 2, b[2]), true)

"The middle of the circle that a link is dragged from, for the time `k` of the task at place `i`"
knob(v::ScheduleView, i::Int, k::Int=1) = knob_place(time_bar(v, i, k), time_bar(v, i, k + 1))[1]

"Which time of the task at place `i` has its bar at `x` across the window: its number, or 1 when no later time has"
time_at(v::ScheduleView, i::Int, x::Real) = begin
  for (k, (a, z)) in enumerate(task_runs(v, i))
    rx, _, rw, _ = bar_box(v, i, a, z)
    rx <= x < rx + rw && return k + 1
  end
  1
end

"The task at place `i` in words, with the day of its time `k` when it repeats: “Water the slab” on Wed 9 Dec"
time_words(v::ScheduleView, i::Int, k::Int) = begin
  t = v.tasks[i]
  words = "“$(t.todo.name)”"
  Schedules.repeats(t.todo) === nothing && return words
  d = Schedules.time_days(t, k, v.data.weekends)
  d === nothing ? words : words * " on " * Schedules.short(d[1])
end

"The place of the task whose row is `y` down the window, or nothing"
row_at(v::ScheduleView, y::Real) = begin
  i = floor(Int, (y - v.box[2] - DATES_H) / TASK_H) + 1
  1 <= i <= length(v.tasks) ? i : nothing
end

"""
The corners of the arrow from the end of the bar of time `ka` of task `a` to
the start of the bar of time `kb` of task `b`, or nothing when one has no such
time. Where the bars leave no room to turn between them, it goes round,
between two rows.
"""
link_points(v::ScheduleView, a::Int, b::Int) = link_points(v, a, 1, b, 1)
link_points(v::ScheduleView, a::Int, ka::Int, b::Int, kb::Int) = begin
  from, to = time_bar(v, a, ka), time_bar(v, b, kb)
  (from === nothing || to === nothing) && return nothing
  sx, sy = from[1] + from[3], from[2] + from[4] / 2
  tx, ty = to[1], to[2] + to[4] / 2
  out = sx + 8
  tx - out >= 8 && return [(sx, sy), (out, sy), (out, ty), (tx, ty)]
  between = sy + sign(ty - sy) * TASK_H / 2
  back = tx - 9
  [(sx, sy), (out, sy), (out, between), (back, between), (back, ty), (tx, ty)]
end

"How far the place `(x, y)` is from the line through the places `ps`"
away(ps, x, y) = minimum(1:length(ps)-1) do k
  (ax, ay), (bx, by) = ps[k], ps[k+1]
  long = (bx - ax)^2 + (by - ay)^2
  along = long == 0 ? 0.0 : clamp(((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / long, 0, 1)
  hypot(x - ax - along * (bx - ax), y - ay - along * (by - ay))
end

"""
What's at the place `(x, y)` of a schedule's bars: `(:knob, i, k)` for the
circle of the time `k` of the task at place `i` (1 for its first bar),
`(:edge, i)` for the right end of its first bar, `(:bar, i)` for the rest of
the bar, `(:run, i, start, finish)` for the bar of a later time of a task that
repeats, `(:link, a, b, r, k)` for the arrow from task `a` to the time `k` of
task `b`, where `r` is the time of `a` as `Schedules.links` gives it,
`(:row, i)` for the rest of the task's row, or nothing.
"""
under(v::ScheduleView, x::Real, y::Real) = begin
  left, top, wide, tall = v.box
  (v.zoom > 0 && left <= x < left + wide && top + DATES_H <= y < top + tall) || return nothing
  i = row_at(v, y)
  i === nothing && return nothing
  bx, by, bw, bh = task_bar(v, i)
  # The circle of each bar of the task. One on a bar's corner reaches less far, so the bar's end can still be dragged.
  bars = row_bars(v, i)
  for k in eachindex(bars)
    (kx, ky), corner = knob_place(bars[k], get(bars, k + 1, nothing))
    hypot(x - kx, y - ky) <= (corner ? KNOB + 1.5 : KNOB + 3) && return (:knob, i, k)
  end
  if by - 2 <= y < by + bh + 2
    bx <= x < bx + bw + 3 && return x >= bx + bw - min(TASK_BAR_EDGE, bw / 2) ? (:edge, i) : (:bar, i)
    for (a, z) in task_runs(v, i)
      rx, _, rw, _ = bar_box(v, i, a, z)
      rx <= x < rx + rw && return (:run, i, a, z)
    end
  end
  for (a, r, b, k) in Schedules.links(v.tasks)
    ps = link_points(v, a, Schedules.bar_of(v.tasks[a], r), b, k)
    ps === nothing || away(ps, x, y) > 4 || return (:link, a, b, r, k)
  end
  (:row, i)
end

"The place of the task whose row the mouse is over, in its name or in its bar's row, or 0"
hot_row(v::ScheduleView) = begin
  w = window_of(v)
  (w === nothing || !ishovered(v) || v.zoom <= 0) && return 0
  something(row_at(v, num(w.mouse[2])), 0)
end

"The days of a task in words: Mon 16 Nov – Wed 18 Nov"
task_days(t) = t.start == t.finish ? Schedules.short(t.start) : Schedules.short(t.start) * " – " * Schedules.short(t.finish)
"The days of a task and how many they are: Mon 16 Nov – Wed 18 Nov  ·  3 days"
task_words(t) = task_days(t) * "  ·  " * Schedules.days_text(t.days)

"""
Show every task: the days from the day before the first task starts to the
day after the last one finishes. A task that repeats with a limit, like `every
day for 3 days`, finishes with its last run. One that repeats for ever finishes
with its first. A short schedule's days are no wider than `DAY_USUAL` in the
page, and no wider than `DAY_MOST` when it fills the window.
"""
fit!(v::ScheduleView) = begin
  ts = v.tasks
  today = Dates.today()
  ends(t) = something(Schedules.last_day(t, v.data.weekends), t.finish)
  lo, hi = isempty(ts) ? (today, today + Day(13)) : (minimum(t -> t.start, ts), maximum(ends, ts))
  days = daynum(hi) - daynum(lo) + 3.5
  v.zoom = clamp(max(v.box[3], 1.0) / days, DAY_LEAST, v.full ? DAY_MOST : DAY_USUAL)
  v.at = daynum(lo) - 1
  v
end

"Make each day `by` times as wide. The day at `x` across the window stays there."
zoom_days!(v::ScheduleView, by, x) = begin
  v.zoom > 0 || return handled
  day = x_day(v, x)
  v.zoom = clamp(v.zoom * by, DAY_LEAST, DAY_MOST)
  v.at = day - (x - v.box[1]) / v.zoom
  handled
end

# --- drawing -------------------------------------------------------------------------------

"Draw a line through the corners `ps`, each corner a little round, with the head of an arrow at its end"
arrow(ctx, ps, colour, wide) = begin
  shape = Skia.sk_path_new()
  Skia.sk_path_move_to(shape, Float32(ps[1][1]), Float32(ps[1][2]))
  for k in 2:length(ps)-1
    before, corner, after = ps[k-1], ps[k], ps[k+1]
    d1, d2 = hypot((corner .- before)...), hypot((after .- corner)...)
    r = min(4.0, d1 / 2, d2 / 2)
    a = corner .+ (before .- corner) .* (r / max(d1, 1e-6))
    b = corner .+ (after .- corner) .* (r / max(d2, 1e-6))
    Skia.sk_path_line_to(shape, Float32(a[1]), Float32(a[2]))
    # A conic with this weight is a quarter of a circle
    Skia.sk_path_conic_to(shape, Float32(corner[1]), Float32(corner[2]), Float32(b[1]), Float32(b[2]), Float32(sqrt(0.5)))
  end
  # The line stops where the head starts
  tip, from = ps[end], ps[end-1]
  along = (tip .- from) ./ max(hypot((tip .- from)...), 1e-6)
  base = tip .- along .* 5.5
  Skia.sk_path_line_to(shape, Float32(base[1]), Float32(base[2]))
  paint = ink(colour, wide)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_paint_delete(paint)
  Skia.sk_path_delete(shape)
  across = (-along[2], along[1]) .* 3.4
  trace(ctx, [tip, base .+ across, base .- across], colour, 0.6; fill=colour, closed=true)
end

"Draw the months and the days over the rows, the lines between them, the days when no work is done, and today"
draw_days(ctx, v::ScheduleView) = begin
  left, top, wide, tall = v.box
  z = v.zoom
  rows = top + DATES_H
  small = Face(SANS, "", 11px, colours.dim, false)
  each_day, each_week = z >= 20, 7z >= 46
  for n in floor(Int, v.at):ceil(Int, v.at + wide / z)
    d = numday(n)
    x = day_x(v, n)
    off = !Schedules.works(d, v.data.weekends)
    off && round_box(ctx, x, rows, z, tall - DATES_H, 0; fill=RGBA(colours.ink, 0.05))
    month, monday = Dates.day(d) == 1, Dates.dayofweek(d) == 1
    if month
      trace(ctx, [(x, top + 4), (x, top + tall)], RGBA(colours.ink, 0.16), 1.0)
    elseif each_day || (monday && each_week)
      trace(ctx, [(x, rows), (x, top + tall)], RGBA(colours.ink, monday ? 0.1 : 0.05), 1.0)
    end
    if each_day
      words = string(Dates.day(d))
      face = off ? Face(small, color=colours.faint) : small
      write_ink(ctx, words, x + (z - num(measure(face, words))) / 2, top + 37, face)
    elseif monday && each_week
      write_ink(ctx, "$(Dates.day(d)) $(Dates.monthabbr(d))", x + 5, top + 37, small)
    end
  end
  # Today's name goes over the middle of today, when today is in sight. A page that shows another day has that day's name there.
  e = editor(v)
  other = another_day(e)
  at = other ? page_day(e) : Dates.today()
  pill_text = other ? "$(Dates.day(at)) $(Dates.monthabbr(at))" : "Today"
  now = day_x(v, daynum(at)) + z / 2
  today = Face(SANS, "Semibold", 10.5px, colours.bg, false)
  pill = num(measure(today, pill_text)) + 12
  shows = left <= now <= left + wide
  # Each month's name is at the month's first day, or at the left edge when that day is out of sight.
  # A name that today's name would cover goes after it.
  bold = Face(SANS, "Medium", 12px, colours.ink, false)
  month = Dates.firstdayofmonth(numday(v.at))
  while day_x(v, daynum(month)) < left + wide
    next = month + Dates.Month(1)
    words = "$(Dates.monthname(month)) $(Dates.year(month))"
    long = num(measure(bold, words))
    x = max(left + 8, day_x(v, daynum(month)) + 6)
    shows && x < now + pill / 2 + 6 && x + long > now - pill / 2 - 6 && (x = now + pill / 2 + 8)
    write_ink(ctx, words, min(x, day_x(v, daynum(next)) - long - 8), top + 18, bold)
    month = next
  end
  trace(ctx, [(left, rows), (left + wide, rows)], colours.line, 1.0)
  for i in 1:length(v.tasks)
    y = rows + i * TASK_H
    trace(ctx, [(left, y), (left + wide, y)], RGBA(colours.line, 0.6), 1.0)
  end
  # Today has a line down the rows, under its name
  if shows
    trace(ctx, [(now, rows), (now, top + tall)], RGBA(colours.ink, 0.6), 1.0)
    round_box(ctx, now - pill / 2, top + 6, pill, 16, 4; fill=colours.ink)
    write_ink(ctx, pill_text, now - pill / 2 + 6, top + 17.5, today)
  end
end

"The colour of a task's bar: one for a task that's done, and one for a task that isn't"
task_hue(done::Bool) = done ? colours.string : colours.accent

"""
True when the bar of a task's run from `start` to `finish` shows as done.
`done` is true when the task's item is ticked. On another day than today, the
plan says: a run that's finished by then is done.
"""
run_done(e, start::Date, finish::Date, done::Bool) = another_day(e) ? Days.stands(start, finish, done, page_day(e), calendar_today()) == :done : done

"""
Draw a bar of a task, `days` long, at `(x, y)`, `w` wide and `h` tall. A bar
that's `done` has a tick, a `strong` one is darker, and a bar with room says
how many days it is. It gives the bar's colour.
"""
draw_bar(ctx, x, y, w, h, days::Int, done::Bool, strong::Bool) = begin
  hue = task_hue(done)
  round_box(ctx, x, y, w, h, 5; fill=RGBA(hue, strong ? 0.32 : 0.17), line=RGBA(hue, 0.9), wide=strong ? 1.8 : 1.0)
  inset = 6.0
  if done && w >= 18
    trace(ctx, [(x + 5.5, y + h / 2 + 0.5), (x + 8.5, y + h / 2 + 3.5), (x + 13.5, y + h / 2 - 3.5)], hue, 1.6)
    inset = 18.0
  end
  face = Face(SANS, "Medium", 10.5px, hue, false)
  words = "$(days)d"
  num(measure(face, words)) + inset + 5 <= w && write_ink(ctx, words, x + inset, y + h / 2 + 3.8, face)
  hue
end

"""
Which time of the task at place `i` shows the circle that a link is dragged
from: the one under the mouse, or else the task as a whole, which is its last
time when its item says how many, and its first otherwise.
"""
hot_time(v::ScheduleView, i::Int) = begin
  t = v.tasks[i]
  whole = Schedules.bar_of(t, 0)
  w = window_of(v)
  w === nothing && return whole
  hit = under(v, num(w.mouse[1]), num(w.mouse[2]))
  (hit === nothing || hit[2] != i) && return whole
  hit[1] == :knob ? hit[3] : hit[1] in (:bar, :edge) ? 1 : hit[1] == :run ? time_at(v, i, num(w.mouse[1])) : whole
end

"""
Draw the bar of each task. A task whose item says how often it repeats has a
bar for each time, to the right edge of the days, or to its last time. The
task under the mouse, and the one that's selected, have the circle that a link
is dragged from: after the bar of the time under the mouse, or of the task as
a whole.
"""
draw_bars(ctx, v::ScheduleView) = begin
  left, _, wide, _ = v.box
  hot = hot_row(v)
  g = v.grab
  e = editor(v)
  for (i, t) in enumerate(v.tasks)
    on = v.picked == (:task, t.todo.key)
    # A bar is marked while the mouse is on its task in another part of the page
    lit = i != hot && marked(v, t.todo.key)
    for (a, z) in task_runs(v, i)
      x, y, w, h = bar_box(v, i, a, z)
      x + w < left || draw_bar(ctx, x, y, w, h, t.days, run_done(e, a, z, false), on || lit)
    end
    x, y, w, h = task_bar(v, i)
    (x + w + 2KNOB_GAP < left || x > left + wide) && continue
    # On another day than today, the plan says which runs are done
    hue = draw_bar(ctx, x, y, w, h, t.days, run_done(e, t.start, t.finish, t.todo.done), on || lit)
    linking = g !== nothing && g[1] == :link && g[2] == t.todo.key
    if (g === nothing && (i == hot || on)) || linking
      k = linking ? g[3] : hot_time(v, i)
      b = time_bar(v, i, k)
      b === nothing && continue
      (kx, ky), corner = knob_place(b, time_bar(v, i, k + 1))
      corner || trace(ctx, [(b[1] + b[3], ky), (kx - KNOB, ky)], RGBA(hue, 0.7), 1.2)
      for (r, colour) in ((KNOB, hue), (KNOB - 1.5, takeoff_back()))
        paint = ink(colour)
        Skia.sk_canvas_draw_circle(ctx, Float32(kx), Float32(ky), Float32(r), paint)
        Skia.sk_paint_delete(paint)
      end
    end
  end
end

"""
Draw an arrow from each task to each task that waits for it, from and to the
bars of the times that they say. Each time of a task that repeats waits for
the time before it, so a short arrow joins them where there's room between
their bars.
"""
draw_links(ctx, v::ScheduleView) = begin
  for (a, r, b, k) in Schedules.links(v.tasks)
    ps = link_points(v, a, Schedules.bar_of(v.tasks[a], r), b, k)
    ps === nothing && continue
    on = v.picked == (:link, v.tasks[a].todo.key, v.tasks[b].todo.key, r, k)
    arrow(ctx, ps, on ? colours.accent : RGBA(colours.dim, 0.9), on ? 2.0 : 1.2)
  end
  left, _, wide, _ = v.box
  for (i, t) in enumerate(v.tasks)
    Schedules.repeats(t.todo) === nothing && continue
    bars = row_bars(v, i)
    for k in 1:length(bars)-1
      x, y, w, h = bars[k]
      nx = bars[k+1][1]
      (nx < left || x > left + wide) && continue
      mid = y + h / 2
      if nx - (x + w) >= 10
        arrow(ctx, [(x + w + 1, mid), (nx - 1, mid)], RGBA(colours.dim, 0.9), 1.2)
      elseif nx - (x + w) >= 4
        trace(ctx, [(x + w, mid), (nx, mid)], RGBA(colours.dim, 0.9), 1.2)
      end
    end
  end
end

"Draw what a drag is doing: the link that's being made, or the days of the bar that's being moved"
draw_drag(ctx, v::ScheduleView) = begin
  g = v.grab
  (g === nothing || g[1] == :pan) && return
  i = task_place(v, g[2])
  i === nothing && return
  x, y, w, h = task_bar(v, i)
  if g[1] == :link
    win = window_of(v)
    win === nothing && return
    mx, my = num(win.mouse[1]), num(win.mouse[2])
    trace(ctx, [knob(v, i, g[3]), (mx, my)], colours.accent, 1.5)
    # The task that the link would go to has a line round its bar: the bar of the time under the mouse, or its first
    j = row_at(v, my)
    if j !== nothing && j != i
      tx, ty, tw, th = time_bar(v, j, time_at(v, j, mx))
      round_box(ctx, tx - 2, ty - 2, tw + 4, th + 4, 7; line=colours.accent, wide=1.5)
    end
  else
    tag(ctx, (x + w - 4, y + 2), task_words(v.tasks[i]))
  end
end

describe(a::ChartArea) = Box(width(grow=grow), height(chart_h(a.of)))

draw(ctx, size, ui::ConcreteRect, a::ChartArea) = begin
  v = a.of
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  v.box[3] > 0 || return
  v.zoom > 0 || fit!(v)
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    draw_days(ctx, v)
    draw_links(ctx, v)
    draw_bars(ctx, v)
    draw_drag(ctx, v)
  end
end

cursor(a::ChartArea) = begin
  v = a.of
  g = v.grab
  g === nothing || return g[1] == :size ? :resize_x : g[1] == :pan ? :arrow : :hand
  w = window_of(v)
  w === nothing && return :arrow
  hit = under(v, num(w.mouse[1]), num(w.mouse[2]))
  hit === nothing || hit[1] == :row ? :arrow : hit[1] == :edge ? :resize_x : :hand
end

# --- the mouse and the keys on the bars -----------------------------------------------------

"Put the caret at the end of line `i` of the page, and bring the line in sight"
show_line!(e, i::Int) = begin
  b = e.buf
  1 <= i <= length(b.lines) || return handled
  b.caret = b.anchor = line_end(b, i)
  focus(e)
  touch!(e)
  handled
end

"Note a click at `(x, y)`. True when it's the second of two clicks in one place."
click_twice!(v::ScheduleView, x, y) = begin
  at, cx, cy = v.clicked
  v.clicked = (time(), x, y)
  time() - at < 0.35 && hypot(x - cx, y - cy) < 4
end

onkey(a::ChartArea, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = a.of, ev.window
  focus(a)
  v.said = ""
  v.zoom > 0 || return handled
  x, y = num(w.mouse[1]), num(w.mouse[2])
  twice = click_twice!(v, x, y)
  hit = under(v, x, y)
  if hit === nothing || hit[1] == :row
    # A drag of anything but a bar moves the days
    v.picked = nothing
    v.grab = (:pan, x, v.at)
  elseif hit[1] == :link
    v.picked = (:link, v.tasks[hit[2]].todo.key, v.tasks[hit[3]].todo.key, hit[4], hit[5])
  else
    t = v.tasks[hit[2]]
    key = t.todo.key
    v.picked = (:task, key)
    if hit[1] == :knob
      # The link goes from the time whose circle it is
      v.grab = (:link, key, hit[3])
    elseif hit[1] == :edge
      v.grab = (:size, key, false)
    elseif twice
      return show_line!(editor(v), t.todo.line)
    else
      # The bar keeps the place where the mouse took hold of it
      v.grab = (:move, key, x - day_x(v, daynum(t.start)), false)
    end
  end
  handled
end

"A drag ended. A link is made, or the bar that moved is written down."
drop!(v::ScheduleView) = begin
  g = v.grab
  v.grab = nothing
  g === nothing && return v
  if g[1] == :link
    w = window_of(v)
    a = task_place(v, g[2])
    b = w === nothing ? nothing : row_at(v, num(w.mouse[2]))
    (a === nothing || b === nothing) && return v
    # It goes to the time whose bar is under the mouse, or to the task's first time
    to = time_at(v, b, num(w.mouse[1]))
    did = Schedules.link!(v.data, v.tasks, a, b; from=Schedules.whole(v.tasks[a], g[3]), to)
    did == :ok && return commit!(v)
    did == :loop && (v.said = "$(time_words(v, a, g[3])) waits for $(time_words(v, b, to)), so it can't go before it")
  elseif g[1] in (:move, :size) && g[end]
    commit!(v)
  end
  v
end

onmouse(a::ChartArea, ev::MouseMove) = begin
  v = a.of
  v.zoom > 0 || return nothing
  x, y = num(ev.position[1]), num(ev.position[2])
  g = v.grab
  if g === nothing
    # A bar says its days, and the other parts say what they're for
    hit = under(v, x, y)
    if hit !== nothing && hit[1] in (:bar, :edge)
      show_tooltip!(ev.window, tip_label(task_words(v.tasks[hit[2]])), px.(task_bar(v, hit[2]))..., placement=:top, gap=6px)
    elseif hit !== nothing && hit[1] == :run
      # A later run of a task that repeats says its own days, and how often the task repeats
      t = v.tasks[hit[2]]
      words = task_words((start=hit[3], finish=hit[4], days=t.days)) * "  ·  " * Repeats.how_often(t.todo.name).match
      show_tooltip!(ev.window, tip_label(words), px.(bar_box(v, hit[2], hit[3], hit[4]))..., placement=:top, gap=6px)
    elseif hit !== nothing && hit[1] == :knob
      kx, ky = knob(v, hit[2], hit[3])
      show_tooltip!(ev.window, tip_label("Drag to the task that waits for this one"), px(kx - KNOB), px(ky - KNOB), px(2KNOB), px(2KNOB), placement=:top, gap=6px)
    elseif hit !== nothing && hit[1] == :link
      a, b, r, k = hit[2:5]
      words = "$(time_words(v, b, k)) waits for $(time_words(v, a, Schedules.bar_of(v.tasks[a], r))).  Click, then Delete takes the link away"
      show_tooltip!(ev.window, tip_label(words), px(x - 4), px(y - 4), 8px, 8px, placement=:top, gap=6px)
    end
    return handled
  end
  Keys.mouse_left in ev.window.keys || (drop!(v); return handled)
  # A press that became a drag isn't the first click of two
  hypot(x - v.clicked[2], y - v.clicked[3]) > 4 && (v.clicked = (0.0, 0.0, 0.0))
  if g[1] == :pan
    v.at = g[3] - (x - g[2]) / v.zoom
    return handled
  end
  i = task_place(v, g[2])
  i === nothing && return handled
  t = v.tasks[i]
  if g[1] == :move
    d = Schedules.workday(numday(round(x_day(v, x - g[3]))), v.data.weekends)
    d == t.start && return handled
    Schedules.move!(v.data, v.tasks, t, d)
    replan!(v)
    v.grab = (:move, g[2], g[3], true)
  elseif g[1] == :size
    # The bar ends at the line between two days that's nearest the mouse
    days = max(1, Schedules.span(t.start, numday(round(x_day(v, x))) - Day(1), v.data.weekends))
    days == t.days && return handled
    Schedules.days!(v.data, t, days)
    replan!(v)
    v.grab = (:size, g[2], true)
  end
  handled   # the drag is the schedule's, so the page's text doesn't select
end

"The place across the window that the days grow or shrink round: the mouse, or the nearest end of the days when the mouse is beside them"
zoom_x(v::ScheduleView, w) = clamp(num(w.mouse[1]), v.box[1], v.box[1] + v.box[3])

# Scrolling sideways moves the days, and scrolling with ⌘ held shows more days or fewer, round the mouse.
# They do that anywhere on the schedule: over the bars, the days, the names of the tasks or the buttons.
# Scrolling up and down scrolls the page that the schedule is on.
onscroll(v::ScheduleView, ev::MouseScroll) = begin
  w = ev.window
  v.zoom > 0 || return nothing
  dx, dy = num(ev.delta[1]), num(ev.delta[2])
  only_held(w, Keys.cmd) && return zoom_days!(v, exp(dy / 10), zoom_x(v, w))
  abs(dx) > abs(dy) || return nothing
  v.at -= 30dx / v.zoom
  handled
end
onscroll(a::ChartArea, ev::MouseScroll) = onscroll(a.of, ev)

onpinch(v::ScheduleView, ev::Pinch) = zoom_days!(v, ev.scale, zoom_x(v, ev.window))
onpinch(a::ChartArea, ev::Pinch) = onpinch(a.of, ev)

# Esc takes the selection away, then puts a schedule that fills the window back in the page, then gives the keyboard back to the text
onkey(a::ChartArea, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  v = a.of
  v.picked === nothing || return (v.picked = nothing; handled)
  v.full ? full!(v, false) : nothing
end
onkey(a::ChartArea, ::KeyPress{K}) where K = begin
  v = a.of
  if K in (Keys.backspace, Keys.delete) && unmodified(window_of(a))
    # Delete takes away the link that's selected
    p = v.picked
    (p !== nothing && p[1] == :link) || return handled
    from, to = task_place(v, p[2]), task_place(v, p[3])
    v.picked = nothing
    (from === nothing || to === nothing) && return handled
    Schedules.unlink!(v.data, v.tasks, from, to; from=p[4], to=p[5])
    commit!(v)
    return handled
  elseif (command = command_of(editor(v), window_of(a), K)) in (:undo, :redo)
    b = editor(v).buf
    command == :redo ? redo!(b) : undo!(b)
    return handled
  end
  nothing
end

# --- the names, the buttons and the whole block -----------------------------------------------

"How wide the names of the tasks are, beside the bars"
names_w(v::ScheduleView) = v.full ? min(NAMES_FULL, window_size(editor(v))[1] * 0.3) : min(NAMES_W, editor(v).width * 0.36)

describe(n::TaskName) = begin
  v = n.of
  i = task_place(v, n.key)
  i === nothing && return Box(width(grow=grow), height(px(TASK_H)))
  t = v.tasks[i]
  on = v.picked == (:task, n.key)
  done = finished(editor(v), t)
  # A task under another, further in, is further in here too
  indent = 12px + 14px * min(t.todo.level ÷ 2, 4)
  # The hours that the page's time logs have for the task show at the end of its name
  minutes = worked(editor(v), t.todo.name)
  hours = minutes > 0 ? (minutes % 60 == 0 ? "$(minutes ÷ 60) h" : "$(round(minutes / 60, digits=1)) h") : ""
  room = names_w(v) - indent - 12px - (done ? 20px : 0px) - (isempty(hours) ? 0px : measure(Face(SANS, "", 11px, colours.dim, false), hours) + 8px)
  Row(width(grow=grow), height(px(TASK_H)), padding(0px, 12px, 0px, indent), child_gap=6px, Alignment.Center, clip=true,
      background(on ? colours.active : hot_row(v) == i ? colours.hover : marked(v, n.key) ? tint(colours.accent, MARK_FILL) : clear),
    (done ? (Icon("check", size=14px, color=colours.string),) : ())...,
    Box(label(elide(t.todo.name, 13px, room), 13px, color=done ? colours.dim : colours.ink)),
    (isempty(hours) ? () : (Box(width(grow=grow)), Box(label(hours, 11px, color=colours.dim))))...)
end

cursor(::TaskName) = :hand

onkey(n::TaskName, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = n.of, ev.window
  focus(chart(v))
  twice = click_twice!(v, num(w.mouse[1]), num(w.mouse[2]))
  v.picked = (:task, n.key)
  i = task_place(v, n.key)
  twice && i !== nothing ? show_line!(editor(v), v.tasks[i].todo.line) : handled
end

toolbar(v::ScheduleView) = begin
  s = v.data
  start = v.asking ?
    (Box(width(6px)), label("Starts on", 12px), Box(width(6px)), field(v, fixed(120px)), Box(width(8px)),
     label("like 16 Nov, then Return", 12px, color=colours.dim)) :
    (button!(v, :start, :start, icon="calendar-event", words="Starts " * Schedules.long(Schedules.origin(s)),
             tip="Change the day that the work starts"),)
  Row(width(grow=grow), height(38px), padding(6px, 0px), child_gap=2px, Alignment.Center, background(colours.block),
    start..., rule(),
    button!(v, :weekends, :weekends, words=s.weekends ? "Every day" : "Weekdays",
            tip=s.weekends ? "Work is done every day. Click to leave out Saturday and Sunday." :
                             "Work is done from Monday to Friday. Click to count Saturday and Sunday too."),
    Row(width(grow=grow), padding(8px, 0px), clip=true, justify=Alignment.End, Box(label(v.said, 12px, color=colours.accent))),
    button!(v, :smaller, (:zoom, 1 / 1.4), icon="zoom-out", tip="Show more days"),
    button!(v, :bigger, (:zoom, 1.4), icon="zoom-in", tip="Show fewer days  pinch, or ⌘ and scroll"),
    button!(v, :fit, :fit, icon="aspect-ratio", tip="Show every task"),
    button!(v, :full, :full, icon=v.full ? "fullscreen-exit" : "arrows-fullscreen", tip=v.full ? "Back to the page  esc" : "Fill the window"))
end

"Do what a button of a schedule does"
act!(v::ScheduleView, action, w) = begin
  a = action isa Tuple ? action[1] : action
  v.said = ""
  if a == :start
    i = schedule_input(v)
    i.color = colours.ink
    i.text = Schedules.long(Schedules.origin(v.data))
    i.anchor, i.cursor = 0, length(i.text)
    v.asking = true
    focus(i)
  elseif a == :weekends
    v.data.weekends = !v.data.weekends
    commit!(v)
  elseif a == :zoom
    zoom_days!(v, action[2], v.box[1] + v.box[3] / 2)
  elseif a == :fit
    fit!(v)
  elseif a == :full
    full!(v, !v.full)
  end
  handled
end

"Take the day that was typed as the day that the work starts, and show every task again"
answer!(v::ScheduleView) = begin
  v.asking || return handled
  d = Schedules.date(schedule_input(v).text)
  d === nothing && return (v.said = "Ladder can't read that day. Type it like 16 Nov 2026."; handled)
  v.data.start = d
  stop_asking!(v)
  commit!(v)
  v.zoom = 0.0
  handled
end

"Take the text field away. The keyboard goes back to the bars."
stop_asking!(v::ScheduleView) = begin
  v.asking = false
  w = window_of(v)
  w !== nothing && w.focus === schedule_input(v) && focus(chart(v))
  handled
end

onkey(v::ScheduleView, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (v.asking ? answer!(v) : nothing) : nothing
onkey(v::ScheduleView, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (v.asking ? stop_asking!(v) : nothing) : nothing

"What happens to a schedule in each frame, before the page is laid out: a drag that ended is written down, and the text field that lost the keyboard closes"
block_tick!(v::ScheduleView) = begin
  w = window_of(v)
  v.grab !== nothing && !held(v, Keys.mouse_left) && drop!(v)
  # A click somewhere else took the keyboard from the text field. A day that reads is kept.
  if v.asking && w !== nothing && w.focus !== schedule_input(v)
    Schedules.date(schedule_input(v).text) === nothing ? stop_asking!(v) : answer!(v)
  end
  v
end

describe(v::ScheduleView) = begin
  e = editor(v)
  schedule_input(v).color = colours.ink
  ts = tasks!(v)
  # The names of tasks that the page had once are forgotten
  length(v.parts) > 2length(ts) + 40 && filter!(p -> !(p[1] isa Tuple && p[1][1] == :name) || task_place(v, p[1][2]) !== nothing, v.parts)
  with_theme(component_theme(e.zoom)) do
    # In the page it's a box with round corners. In the window it takes all the room under the top bar.
    look = v.full ? (width(grow=grow), height(grow=grow), Alignment.Start, background(takeoff_back())) :
                    (width(grow=grow), Alignment.Start, radius(8px), border(1px, :solid, colours.line), background(takeoff_back()))
    isempty(ts) && return Column(look..., clip=true, name="Schedule", toolbar(v),
      Row(width(grow=grow), height(64px), padding(16px, 0px), Alignment.Center, clip=true,
          Box(label("This page has no to-do items yet. Start a line with - [ ] to make a task.", 13px, color=colours.dim))))
    names = Column(fixed(names_w(v)), height(chart_h(v)), Alignment.Start, border(1px, :solid, colours.line)[:right],
      Row(width(grow=grow), height(px(DATES_H)), padding(12px, 0px, 9px, 12px), Alignment.End, border(1px, :solid, colours.line)[:bottom],
          Box(label("Task", 11px, color=colours.dim))),
      [part!(() -> TaskName(of=v, key=t.todo.key), v, (:name, t.todo.key)) for t in ts]...)
    rows = Row(width(grow=grow), Alignment.Start, names, chart(v))
    v.full || return Column(look..., clip=true, name="Schedule", toolbar(v), rows)
    # The wheel scrolls through more tasks than the window has room for
    list = get!(() -> Scroll(width(grow=grow), height(grow=grow)), v.parts, :list)
    Column(look..., name="Schedule", toolbar(v), reuse!(list, rows))
  end
end

cursor(::ScheduleView) = :arrow
# A click beside a button is the block's, and takes the keyboard from the text field
onkey(v::ScheduleView, ::KeyPress{Keys.mouse_left}) = (focus(chart(v)); handled)
onmouse(v::ScheduleView, ::MouseMove) = held(v, Keys.mouse_left) ? handled : nothing

"The `schedule` code block as HTML: a table of the page's tasks and the days of each"
block_html(e, v::ScheduleView) = begin
  tasks = Schedules.plan!(Schedules.schedule(v.lines), page_todos(e))
  isempty(tasks) && return nothing
  rows = map(tasks) do task
    cells = [task.todo.name, Schedules.short(task.start), Schedules.short(task.finish), Schedules.days_text(task.days),
             join((tasks[j].todo.name for j in task.after), ", ")]
    "<tr>" * join("<td>$(escape(c))</td>" for c in cells) * "</tr>"
  end
  "<table>\n<tr><th>Task</th><th>Starts</th><th>Ends</th><th>Takes</th><th>After</th></tr>\n" * join(rows, "\n") * "\n</table>"
end

BLOCKS[SCHEDULE] = ScheduleView
block_name(::Type{ScheduleView}) = "Schedule"
block_icon(::Type{ScheduleView}) = "bar-chart-steps"
block_insert(::Type{ScheduleView}) = ("Schedule", ["```$SCHEDULE", "```", "", ""], (4, 0))

# --- a to-do item of a page that has a schedule ------------------------------------------------
#
# A to-do item reads as it always does: a box and its text. While the page has
# a schedule, the item is a task, and the mouse over it shows the task's days
# at the right end of its line: its first and last day, how many working days
# it takes, with a button each side that makes it a day shorter or longer, and
# what it waits for. An item whose lines have no room for them shows them under
# the item.

"The schedule that the page's to-do items are in: the page's first, or nothing when it has none"
page_schedule(e) = begin
  b = e.buf
  readonly(b) && return nothing
  span = block_lines(b, SCHEDULE, 1)
  span === nothing && return nothing
  v = schedule_view(e, 1)
  reread!(v, b.lines[span[1]+1:span[2]-1])
  v
end

"The line of the to-do item whose row of the page is at the place `(x, y)` in the window, or nothing. An item that shows its markup isn't one."
todo_line(e, x, y) = begin
  dx, dy = px(x) - e.origin[1], px(y) - e.origin[2]
  (-30px <= dx < e.width && y >= num(above_page(e))) || return nothing
  dy >= 0px || return nothing
  it = e.layout[item_under(e, dx, dy)]
  f = it.content
  dy < it.top + it.tall && shows_box(f) ? it.first : nothing
end

"""
The days of the to-do item under the mouse, beside the item. They stay while
the mouse is on them, so that their buttons can be clicked.
"""
task_over(e) = begin
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return ()
  win = window_of(e)
  (win === nothing || isempty(e.layout) || readonly(e.buf)) && return ()
  d = node!(TaskDetails, e, :task_details)
  x, y = num(win.mouse[1]), num(win.mouse[2])
  on_details = d.of !== nothing && d.box[1] <= x < d.box[1] + d.box[3] && d.box[2] <= y < d.box[2] + d.box[4]
  hide() = (d.of = nothing; ())
  line = on_details ? nothing : ishovered(node!(Document, e, :document)) && !held(e, Keys.mouse_left) ? todo_line(e, x, y) : nothing
  (on_details || line !== nothing) || return hide()
  # A page with a schedule shows the task's days. A page with a time log shows the item's clock.
  v, log = page_schedule(e), page_log(e)
  (v === nothing && log === nothing) && return hide()
  v === nothing || tasks!(v)
  items = page_todos(e)
  i = on_details ? findfirst(t -> t.key == d.key, items) : findfirst(t -> t.line == line, items)
  i === nothing && return hide()
  it = item(e, items[i].line)
  f = it.content
  shows_box(f) || return hide()
  d.of, d.key = something(v, log), items[i].key
  wide = describe(Row(Alignment.Start, geometry(d)), (9999px, 9999px)).width
  # They go at the right end of the first of the item's lines that has room for them, or under the item when none has
  edge = sum(item_room(e, it))   # the right edge of the item's column, or of the page
  k = findfirst(vl -> maximum(seg -> seg.x + seg.w, vl.segs, init=0px) + 24px + wide <= edge, f.lines)
  d.floats = k === nothing
  vl = f.lines[something(k, length(f.lines))]
  left = e.origin[1] + edge - wide
  top = e.origin[2] + it.top + f.above + vl.top
  top = d.floats ? top + vl.high - 2px : top + (vl.high - DETAILS_H) / 2
  top >= above_page(e) || return hide()
  d.box = (num(left), num(top), num(wide), num(DETAILS_H))
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), d),)
end

describe(d::TaskDetails) = begin
  e = editor(d)
  v = d.of isa ScheduleView ? d.of : nothing
  i = v === nothing ? nothing : task_place(v, d.key)
  # On a page with a time log, the item has a button that starts and stops the log's clock on it
  clock = page_log(e) === nothing || todo_called(e, d.key) === nothing ? () :
    ((c = node!(ItemClock, e, :item_clock); c.key = d.key; c.parent === d || setfield!(c, :parent, d); c),)
  (i === nothing && isempty(clock)) && return Box(width(0px), height(DETAILS_H))
  dot() = Box(label("·", 12px, color=colours.faint))
  # Under the line, they float over the text of the next line
  look = d.floats ? (background(colours.float), border(1px, :solid, colours.line), lifted) : (background(colours.bg),)
  i === nothing && return Row(height(DETAILS_H), padding(8px, 0px), child_gap=6px, Alignment.Center, radius(6px), look..., name="Task", clock...)
  t = v.tasks[i]
  d.less === nothing && (d.less = own!(d, DayButton(by=-1)); d.more = own!(d, DayButton(by=1)))
  first_name = isempty(t.after) ? "" : v.tasks[t.after[1]].todo.name
  waits = isempty(t.after) ? "" : length(t.after) > 1 ? "after $(length(t.after)) tasks" :
          "after " * (length(first_name) > 30 ? first(first_name, 29) * "…" : first_name)
  Row(height(DETAILS_H), padding(8px, 0px), child_gap=6px, Alignment.Center, radius(6px), look..., name="Task",
    Icon("calendar-event", size=12px, color=colours.dim), Box(label(task_days(t), 12px, color=colours.dim)), dot(),
    d.less, Box(label(Schedules.days_text(t.days), 12px)), d.more,
    (isempty(waits) ? () : (dot(), Box(label(waits, 12px, color=colours.dim))))...,
    (isempty(clock) ? () : (dot(), clock...))...)
end

cursor(::TaskDetails) = :arrow
# A click beside a button does nothing, and doesn't move the caret
onkey(::TaskDetails, ::KeyPress{Keys.mouse_left}) = handled
onmouse(::TaskDetails, ::MouseMove) = handled

"The task that the details `d` show, or nothing when the page has it no more"
task_of(d::TaskDetails) = (i = d.of isa ScheduleView ? task_place(d.of, d.key) : nothing; i === nothing ? nothing : d.of.tasks[i])

describe(b::DayButton) = begin
  t = task_of(b.parent)
  off = b.by < 0 && (t === nothing || t.days <= 1)
  Box(width(18px), height(18px), radius(4px), Alignment.Center, justify=Alignment.Center, name="Button",
      background(ishovered(b) && !off ? colours.hover : clear),
    Icon(b.by < 0 ? "dash" : "plus", size=13px, color=off ? colours.faint : colours.dim))
end

cursor(::DayButton) = :hand
draw(ctx, size, ui::ConcreteRect, b::DayButton) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::DayButton, ev::MouseMove) = begin
  show_tooltip!(ev.window, tip_label(b.by < 0 ? "A day shorter" : "A day longer"), b.rect..., placement=:top, gap=6px)
  handled
end

onkey(b::DayButton, ev::KeyPress{Keys.mouse_left}) = begin
  d = b.parent
  t = task_of(d)
  hide_tooltip!(ev.window)
  (t === nothing || t.days + b.by < 1) && return handled
  Schedules.days!(d.of.data, t, t.days + b.by)
  commit!(d.of)
  handled
end

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
