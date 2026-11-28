# The day that the page shows, with the slider that changes it, and the page's text on that day as git has it

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" rectangle
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw cursor with_clip
@use "./transcribe" finished
@use "./markdown" Kind words
@use "./sheet" parts
@use "./merge" changes
@use "./schedule" => Schedules
@use "./calendar" => Calendars
@use "./day" => Days
@use "./dates" => DatesRead
@use "./git" => Git
@use Colors: RGBA
@use Dates: Dates, Date, Day
@use "./base" exports...
@use "./julia_levels" exports...
@use "./schedule_view" exports...
@use "./calendar_view" exports...
@use "./gallery_view" exports...
@use "./slides_view" exports...
@use "./page_extras" exports...

export COMMIT_LINES, DAY_BLOCK, DAY_KNOB, DAY_PAD, DAY_TRACK, DayTrack, DayView, HISTORY_FRESH,
       LATER_VEIL, PAGE_HISTORY, commit_lines, day_block, day_html, day_near, day_spot, page_days,
       page_history, planned_ticks, set_day!, then_words, unticked, veil_later

# --- the day that the page shows ---------------------------------------------------------------
#
# A page shows itself as it stands on one day: today, until the page has a
# code block in the language `day`. day.jl says how that block is written. It
# shows a line of days with a slider on it. Drag the slider, click a day, or
# press ← and →, and the page's day changes while the mouse moves. When the
# mouse lets go, the day goes into the block's line. Today takes the line
# away, so the page follows the real day again.
#
# No part of the page is told. Each part that would ask for today asks
# `page_day(e)`:
#
#   - A schedule draws its line of today on that day. A task that the plan
#     finishes before that day shows as done.
#   - The box of each to-do item that the schedule has a task for shows the
#     same: a tick when the plan has the task finished by then. A past day
#     that git keeps the page for has git's ticks instead.
#   - A board puts each card where the schedule's plan has its task on that
#     day: to do, doing or done. Its cards stay where they are while it does.
#   - A calendar shows the month of that day, with a circle round the day.
#   - A time log adds up the hours to that day, when the day is past. A chart
#     of the log draws those hours.
#   - The text shows what git has of the page for that day, when the day is
#     past and git keeps the page: see "the page's text on its day".
#
# The slider goes from the first to the last day of the things of the page.
# `page_days` finds those: it asks the schedule for its tasks, and reads the
# days of the to-do items, the events and the rows of the logs.

const DAY_BLOCK = Days.DAY
const DAY_TRACK = 50px    # how tall the line of days is
const DAY_PAD = 20.0      # px from each end of that line to the edge of the block
const DAY_KNOB = 7.0      # the radius of the slider
push!(BLOCK_ICONS, "calendar-day")

"What a `day` block shows: a line of days with a slider on it, which sets the day that the page shows"
@def mutable struct DayView <: SemanticUI
  n::Int = 0                               # its place among the page's blocks of this kind
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  day::Union{Nothing,Date} = nothing       # the day that its lines say, or nothing for today
  lines::Vector{String} = String[]         # the lines that `day` was read from
  at::Union{Nothing,Date} = nothing        # the day that the slider is on while the mouse drags it
  grab::Bool = false                       # the mouse holds the slider
  days::Vector{Date} = Date[]              # the days that the line shows
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the line of days was last drawn in the window
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its buttons and its line of days, kept between frames
end

"The line of days of a `day` block, with the slider on it"
@def mutable struct DayTrack <: SemanticUI
  of::Any = nothing
end

reread!(v::DayView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.day = Days.day(lines)
  v
end

"The lines that open and close the page's first `day` block, or nothing. They're found again when the page has changed."
day_block(e) = (b = e.buf; get!(() -> block_lines(b, DAY_BLOCK, 1), e.flows, (:day_block, b.path, b.version)))

"""
The day that the page shows itself on: today, unless the page has a `day`
block that says another. Each part of the page that shows what's done, what's
running or what's to come asks for this day.
"""
page_day(e) = begin
  today = calendar_today()
  span = day_block(e)
  span === nothing && return today
  v = block_view(e, DAY_BLOCK, 1)
  reread!(v, e.buf.lines[span[1]+1:span[2]-1])
  something(v.at, v.day, today)
end

"True when the page shows a day that isn't today"
another_day(e) = page_day(e) != calendar_today()

"""
How the task `t` of a schedule stands on the page's day: `:done`, `:doing` or
`:todo`. On another day than today, a task that repeats isn't done while its
next run is still to come: it's `:doing` on the days of a run. One with a limit,
like `every day for 3 days`, is done after the last day of its last run.
"""
standing(e, t::Schedules.Planned) = begin
  d, today = page_day(e), calendar_today()
  if d != today && Schedules.repeats(t.todo) !== nothing
    weekends = calendar_tasks(e)[2]
    z = Schedules.last_day(t, weekends)
    z !== nothing && d > z && return Days.stands(t.start, z, t.todo.done, d, today)
    return Schedules.running(t, d, weekends) ? :doing : :todo
  end
  Days.stands(t.start, t.finish, t.todo.done, d, today)
end

"True when the task `t` shows as done: it's ticked, or on another day than today, the plan has it finished by then"
finished(e, t::Schedules.Planned) = another_day(e) ? standing(e, t) == :done : t.todo.done

"The tasks of the page's schedule, when the page shows another day than today. On the real day, and with no schedule, there are none: the page shows what's ticked."
planned_tasks(e) = another_day(e) ? calendar_tasks(e)[1] : Schedules.Planned[]

"""
The days of the things of the page: the days of its schedule's tasks, of its
to-do items that have a day, of its calendars' events and of the rows of its
time logs. They're found again when the page has changed.
"""
page_days(e) = begin
  b = e.buf
  get!(e.flows, (:page_days, b.path, b.version, calendar_today())) do
    out = Date[]
    foreach(t -> push!(out, t.start, t.finish), calendar_tasks(e)[1])
    for t in page_todos(e)
      d = Calendars.stamp(t.name)
      d === nothing || push!(out, d)
    end
    for (i, k) in enumerate(kinds(b))
      (k.kind == Kind.code && k.lang in (CALENDAR, TIMELOG)) || continue
      d = Days.day((b.lines[i],))
      d === nothing || push!(out, d)
    end
    # The slider goes back to the page's first commit, when git keeps the page: see "the page's text on its day"
    h = !isempty(b.path) && isfile(b.path) ? page_history(page_key(b.path)) : nothing
    h === nothing || push!(out, h.commits[end][2])
    out
  end
end

"Make `d` the page's day, and write it into the block's line. Today takes the line away."
set_day!(v::DayView, d::Date) = begin
  v.at = nothing
  write_block!(v, DAY_BLOCK, Days.written(v.lines, d == calendar_today() ? nothing : d))
  handled
end

act!(v::DayView, action, w) = begin
  e = editor(v)
  action == :today ? set_day!(v, calendar_today()) : set_day!(v, page_day(e) + Day(action == :back ? -1 : 1))
end

"How far across the window the middle of the day at place `i` of the line is"
day_spot(v::DayView, i::Real) = v.box[1] + DAY_PAD + (i - 0.5) * (v.box[3] - 2DAY_PAD) / max(length(v.days), 1)

"The day of the line that's nearest to `x` across the window"
day_near(v::DayView, x::Real) = begin
  n = length(v.days)
  n == 0 && return calendar_today()
  v.days[clamp(floor(Int, (x - v.box[1] - DAY_PAD) / max((v.box[3] - 2DAY_PAD) / n, 1e-6)) + 1, 1, n)]
end

"What happens to a `day` block in each frame, before the page is laid out: the slider follows the mouse that holds it, and its day is written down when the mouse lets go"
block_tick!(v::DayView) = begin
  v.grab || return v
  w = window_of(v)
  w === nothing && return (v.grab = false; v)
  if held(v, Keys.mouse_left)
    v.at = day_near(v, num(w.mouse[1]))
  else
    v.grab = false
    v.at === nothing || set_day!(v, v.at)
  end
  v
end

describe(v::DayView) = begin
  e = editor(v)
  today, d = calendar_today(), page_day(e)
  v.days = collect(Days.span(page_days(e), today, d))
  with_theme(component_theme(e.zoom)) do
    off = readonly(e.buf)
    bar = block_bar(
      block_button!(v, :back, :back, icon="chevron-left", tip="The day before", off=off),
      block_button!(v, :on, :on, icon="chevron-right", tip="The day after", off=off),
      Box(width(6px)),
      Box(label("$(Dates.dayname(d)) $(Schedules.long(d))", 13px, weight="Semibold")),
      Box(width(8px)),
      # The row is as tall as the bar, so that it doesn't cut the tails of its letters off
      Row(width(grow=grow), height(grow=grow), clip=true, Alignment.Center,
          Box(label(d == today ? "Today" : uppercasefirst(Days.away(d, today)) * (isempty(then_words(e)) ? "" : ", and " * then_words(e)), 12px, color=colours.dim)), Box(width(grow=grow))),
      block_button!(v, :today, :today, words="Today", tip="Show the page as it is today", off=off || (d == today && v.day === nothing)))
    Column(block_look()..., clip=true, name="Day", bar, block_part!(() -> DayTrack(of=v), v, :track))
  end
end

describe(::DayTrack) = Box(width(grow=grow), height(DAY_TRACK))

draw(ctx, size, ui::ConcreteRect, t::DayTrack) = begin
  v = t.of
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  n = length(v.days)
  (v.box[3] > 2DAY_PAD && n > 0) || return
  e = editor(v)
  left, top = v.box[1], v.box[2]
  today, d = calendar_today(), page_day(e)
  step = (v.box[3] - 2DAY_PAD) / n
  line = top + 30
  small = Face(SANS, "", 11px, colours.dim, false)
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    round_box(ctx, left + DAY_PAD, line - 2, v.box[3] - 2DAY_PAD, 4, 2; fill=RGBA(colours.ink, 0.1))
    # The names of the days go over the line: each Monday, or the first day of each month when the days are narrow
    weekly = 7step >= 50
    for (i, day) in enumerate(v.days)
      x = day_spot(v, i)
      monday, first = Dates.dayofweek(day) == 1, Dates.day(day) == 1
      step >= 7 && trace(ctx, [(x, line - 6), (x, line - 3)], RGBA(colours.ink, monday ? 0.35 : 0.15), 1.0)
      (weekly ? monday : first) || continue
      words = weekly ? "$(Dates.day(day)) $(Dates.monthabbr(day))" : Dates.monthabbr(day)
      write_ink(ctx, words, x - num(measure(small, words)) / 2, top + 16, small)
    end
    # The line is coloured from today to the page's day, and today has its name under it
    a, b = findfirst(==(today), v.days), findfirst(==(d), v.days)
    if a !== nothing
      x = day_spot(v, a)
      b === nothing || a == b || round_box(ctx, min(x, day_spot(v, b)), line - 2, abs(day_spot(v, b) - x), 4, 2; fill=RGBA(colours.accent, 0.45))
      disc(ctx, x, line, 3.5, colours.ink)
      words = "Today"
      write_ink(ctx, words, clamp(x - num(measure(small, words)) / 2, left + 4, left + v.box[3] - num(measure(small, words)) - 4), line + 16, small)
    end
    if b !== nothing
      x = day_spot(v, b)
      disc(ctx, x, line, DAY_KNOB + 2, takeoff_back())
      disc(ctx, x, line, DAY_KNOB, colours.accent)
    end
  end
end

cursor(::DayTrack) = :hand
cursor(::DayView) = :arrow

onkey(t::DayTrack, ev::KeyPress{Keys.mouse_left}) = begin
  v = t.of
  readonly(editor(v).buf) && return handled
  focus(t)
  v.grab = true
  v.at = day_near(v, num(ev.window.mouse[1]))
  handled
end
onkey(t::DayTrack, ev::KeyPress{Keys.left}) = unmodified(ev) ? act!(t.of, :back, nothing) : nothing
onkey(t::DayTrack, ev::KeyPress{Keys.right}) = unmodified(ev) ? act!(t.of, :on, nothing) : nothing
onkey(t::DayTrack, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (focus(editor(t.of)); handled) : nothing
# A click beside a button is the block's, and doesn't move the caret
onkey(::DayView, ::KeyPress{Keys.mouse_left}) = handled
# A drag is the slider's, so the page's text doesn't select
onmouse(v::DayView, ::MouseMove) = v.grab ? handled : nothing

"The block as HTML: the day that the page shows"
day_html(e, v::DayView) = (d = something(v.day, calendar_today()); "<p><strong>$(Dates.dayname(d)) $(Schedules.long(d))</strong></p>")

BLOCKS[DAY_BLOCK] = DayView
block_name(::Type{DayView}) = "Day"
block_icon(::Type{DayView}) = "calendar-day"
block_insert(::Type{DayView}) = ("Day", ["```$DAY_BLOCK", "```", "", ""], (4, 0))
block_html(e, v::DayView) = day_html(e, v)

# --- the page's text on its day ------------------------------------------------------------------
#
# A page in a folder that git keeps has its past. On a day before today, the
# text shows that past too: Ladder asks git for the page as its last commit
# of that day had it, and compares it with the page as it is now.
#
#   - The box of a to-do item shows a tick only if the item was ticked then.
#     A click on a box does nothing until the page shows today again.
#   - A line that wasn't on the page then, or that read another way, is
#     fainter, with a grey bar beside it. A tick alone is no other way to read.
#   - A board with no schedule to plan from puts each card where its item
#     was then.
#
# The slider of a `day` block goes back to the day of the page's first
# commit. A page that git doesn't keep, and a day with nothing to compare,
# shows as it is.

"How many seconds the commits of a page stay good, before git is asked for them again"
const HISTORY_FRESH = 30.0
"The commits of each page that was asked for, by the page's real path: when git was asked, the top folder of the page's repository, the page's place in it, and the commits, newest first, each as its hash and its day"
const PAGE_HISTORY = Dict{String,Any}()
"The lines of a page in a commit, by the repository's folder, the commit's hash and the page's place. A commit never changes, so they're kept."
const COMMIT_LINES = Dict{Tuple{String,String,String},Vector{String}}()

"""
What git has of the page at `path`: the top folder of its repository, its
place in that folder, and its commits, the newest first, each as its hash and
its day. It's nothing for a page that no repository holds, or that has no
commit yet.
"""
page_history(path::AbstractString) = begin
  kept = get(PAGE_HISTORY, path, nothing)
  kept !== nothing && time() - kept.at < HISTORY_FRESH && return kept.found
  found = try
    root = Git.top(path)
    if isempty(root)
      nothing
    else
      rel = relpath(path, realpath(root))
      commits = [(hash, DatesRead.day(at)) for (hash, at) in Git.history(root, rel)]
      isempty(commits) ? nothing : (root=root, rel=rel, commits=commits)
    end
  catch
    nothing   # no git on this Mac, or a folder that macOS doesn't let Ladder read
  end
  length(PAGE_HISTORY) > 500 && empty!(PAGE_HISTORY)
  PAGE_HISTORY[path] = (at=time(), found=found)
  found
end

"The lines of the page at `rel` in the commit `hash` of the repository at `root`, or none when the commit hasn't got the page"
commit_lines(root, hash, rel) = begin
  length(COMMIT_LINES) > 200 && empty!(COMMIT_LINES)
  get!(COMMIT_LINES, (root, hash, rel)) do
    text = Git.at_commit(root, hash, rel)
    text === nothing ? String[] : String.(split(chomp(text), '\n'))
  end
end

"The line `text` with the box of a to-do item empty, so that a tick alone doesn't make two lines differ"
unticked(text::AbstractString) = replace(text, r"^(\s*[-*+] \[)[xX](\])" => s"\1 \2")

"""
The page as git has it for the page's day, when that day is before today:

  - `lines`: its lines in the last commit of that day or before it. There
    are none when its first commit came later.
  - `later`: for each line of the page as it is now, true when the line
    wasn't there then, or read another way.
  - `ticks`: for the line of each to-do item of the page now, true when the
    item was ticked then.

It's nothing when the page shows today, and for a page that git doesn't keep.
"""
page_then(e) = begin
  b = e.buf
  (b.view == :markdown && !isempty(b.path)) || return nothing
  d = page_day(e)
  d < calendar_today() || return nothing
  # Each to-do item of the page asks in each frame, so what was found is good for a second without a look at the disk
  kept = get(e.flows, (:page_then_at, b.path, b.version, d), nothing)
  kept !== nothing && time() - kept[1] < 1 && return kept[2]
  found = page_then(e, d)
  e.flows[(:page_then_at, b.path, b.version, d)] = (time(), found)
  found
end

"The page as git has it for the day `d`, as `page_then(e)` gives it for the page's day. It looks at the disk, for whether the page's file is there."
page_then(e, d::Date) = begin
  b = e.buf
  h = isfile(b.path) ? page_history(page_key(b.path)) : nothing
  h === nothing && return nothing
  k = findfirst(c -> c[2] <= d, h.commits)
  hash = k === nothing ? "" : h.commits[k][1]
  get!(e.flows, (:page_then, b.path, b.version, hash)) do
    lines = k === nothing ? String[] : commit_lines(h.root, hash, h.rel)
    later = falses(length(b.lines))
    for (_, new) in changes(unticked.(lines), unticked.(b.lines)), i in new
      later[i] = true
    end
    was = Dict(t.key => t.done for t in Schedules.todos(lines))
    ticks = Dict{Int,Bool}(t.line => get(was, t.key, false) for t in page_todos(e))
    (lines=lines, later=later, ticks=ticks)
  end
end

"""
True or false when the box of the to-do item on line `i` shows how the item
stands on the page's day, ticked or not. On a day before today that git has
the page for, it's git's tick of that day. On any other day than today, it's
the schedule's plan: a task that the plan has finished by then has a tick.
It's nothing when the page shows today, and for an item that neither says
anything about, and so the box shows the line's own tick.
"""
ticked_then(e, i::Int) = begin
  i > 0 || return nothing
  then = page_then(e)
  then === nothing || return get(then.ticks, i, nothing)
  get(planned_ticks(e), i, nothing)
end

"For the line of each to-do item that the page's schedule has a task for, true when the plan has that task finished by the page's day. There are none on the real day, and on a page with no schedule."
planned_ticks(e) = begin
  another_day(e) || return Dict{Int,Bool}()
  b = e.buf
  get!(e.flows, (:planned_ticks, b.path, b.version, page_day(e), calendar_today())) do
    Dict{Int,Bool}(t.todo.line => finished(e, t) for t in planned_tasks(e))
  end
end

"The to-do items of the page as they stand on the page's day: each is done if git has it ticked then. On the real day, and for a page that git doesn't keep, they're the page's own."
todos_then(e) = begin
  then = page_then(e)
  then === nothing && return page_todos(e)
  b = e.buf
  get!(e.flows, (:todos_then, b.path, b.version, objectid(then))) do
    [Schedules.Todo(t.line, t.name, t.key, t.level, get(then.ticks, t.line, false)) for t in page_todos(e)]
  end
end

"How strongly the page's own colour covers a line that wasn't on the page on its day"
const LATER_VEIL = 0.62

"Make each line of text that wasn't on the page on its day fainter, and draw a grey bar in the margin beside it. The text is drawn already."
veil_later(ctx, e, ui) = begin
  then = page_then(e)
  (then === nothing || slideshow(e) !== nothing) && return
  left = ui.left + sideways(e)
  n = length(then.later)
  for it in e.layout[e.shown]
    (it.content isa Flow && it.first <= n && all(i -> then.later[i], it.first:min(it.last, n))) || continue
    isempty(strip(e.buf.lines[it.first])) && it.first == it.last && continue   # an empty line has nothing to make fainter
    rectangle(ctx, ui.left, ui.top + it.top, ui.width, it.tall, background=RGBA(colours.bg, LATER_VEIL), border=0px)
    rectangle(ctx, left - 16px, ui.top + it.top, 3px, it.tall, background=RGBA(colours.ink, 0.22), border=0px)
  end
end

"What a `day` block says of the page's text on a day before today: that it shows as git has it, or that git has none so early. It's \"\" when the text shows as it is."
then_words(e) = begin
  then = page_then(e)
  then === nothing && return ""
  isempty(then.lines) && return "before this page's first commit"
  n = count(i -> then.later[i] && !isempty(strip(e.buf.lines[i])), eachindex(then.later))   # an empty line is no line to read
  n == 0 ? "the text is as it was" : "$n line$(n == 1 ? "" : "s") came later"
end
