# The view of a `calendar` block: a calendar of the page's days
#
# A code block in the language `calendar` shows one month as a grid of days,
# from Monday to Sunday. calendar.jl says how the block is written. Each day
# shows the things of the page that are on it: the tasks of the page's
# schedule, the to-do items that have a day in their text, and the events
# that the block's own lines hold.
#
#   - The arrows at the top go to the month before and the month after, and
#     Today goes back to the month of today.
#   - Click a thing to select it, and click it twice to go to its line.
#   - Click the box of a to-do item to tick it in the page.
#   - Drag a to-do item or an event to another day. Ladder writes the new day
#     into the item's text or the event's line. A task stays where it is: the
#     schedule says when it's done.
#   - Click a day twice to add an event to it, type its words, and press Return.
#   - A day with more things than it has room for says how many more there
#     are. Click those words to make the week tall enough for all of them.
#
# A block with a line like `in: jobs` is a calendar of a folder: its to-do
# items are those of every page of the folder `jobs` beside the page, as a
# board of a folder has them. A tick and a new day are written into the
# item's own page: see `tick_page!` and `stamp_page!`. Two clicks on such an
# item open its page at its line.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! rect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "../html" escape
@use "../markdown" Kind words
@use "./sheet" parts shown
@use "./schedule" => Schedules
@use "./calendar" => Calendars
@use "./find" => Searches
@use "./timelog" => Timelogs
@use Colors: RGBA
@use Dates: Dates, Date
@use "../base" exports...
@use "./takeoff_view" exports...
@use "./sheet_view" exports...
@use "./schedule_view" exports...
@use "./board_view" exports...

export CALENDAR, DAY_ROWS, DAY_HEAD, THING_H, THING_GAP, DAY_TIGHT, calendar_day, CalendarView,
       CalendarDay, CalendarThing, CalendarTick, CalendarMore, CalendarDrag, month_shown,
       calendar_tasks, things!, calendar_folder, calendar_items, item_place, stamp_page!,
       log_things, day_things, thing_line, calendar_input, tight, words_room, drop_day, day_lines,
       week_rows, add_event!, thing_html, calendar_html, thing_name

const CALENDAR = Calendars.CALENDAR
push!(BLOCK_ICONS, "calendar3", "chevron-left", "chevron-right")
const DAY_ROWS = 3        # how many lines of things a day has room for
const DAY_HEAD = 26px     # how tall the number of a day is
const THING_H = 20px      # how tall a thing of a day is
const THING_GAP = 2px     # and the space under it
const DAY_TIGHT = 76px    # a day that's narrower than this has less space round its things, and no box or tick before their words

"The day that counts as today, or nothing for the real one. A test names a day here, so that it doesn't depend on the day that it runs."
const calendar_day = Ref{Union{Nothing,Date}}(nothing)
calendar_today() = something(calendar_day[], Dates.today())

"What a `calendar` block shows: a month, with the things of the page on their days"
@def mutable struct CalendarView <: SemanticUI
  n::Int = 0                               # its place among the page's calendars
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Calendars.Calendar = Calendars.Calendar()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  shown::Any = nothing                     # the version of the page and the day, and the things of each day for them
  picked::Any = nothing                    # the thing that's selected, by what `Calendars.id` gives
  grab::Any = nothing                      # the thing that the mouse holds, where the mouse took it, and whether it has moved since
  clicked::NTuple{3,Float64} = (0.0, 0.0, 0.0)   # when and where it was last clicked
  open::Set{Date} = Set{Date}()            # the Monday of each week that shows every thing of its days
  adding::Union{Nothing,Date} = nothing    # the day that a new event is being typed for
  wide::px = 0px                           # how wide a day is
  weeks::Int = 0                           # how many weeks the month that shows is in
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its buttons, days and things, kept between frames
end

"A day of a calendar"
@def mutable struct CalendarDay <: SemanticUI
  of::Any = nothing
  i::Int = 0                 # its place among the days that show
  day::Date = Date(2000)
  tall::px = 0px             # how tall its week is
end
"A thing of a day: a task, a to-do item or an event"
@def mutable struct CalendarThing <: SemanticUI
  of::Any = nothing
  thing::Any = nothing
  box::Any = nothing         # the box of a to-do item
  cut::Bool = false          # its words have no room, and end with …
end
"The box of a to-do item in a calendar. A click ticks the item in the page."
@def mutable struct CalendarTick <: SemanticUI
  of::Any = nothing          # the thing
end
"The words under a day that has more things than room: a click shows them all, or hides them again"
@def mutable struct CalendarMore <: SemanticUI
  of::Any = nothing
  day::Date = Date(2000)
  more::Int = 0              # how many things don't show, or 0 when they all do
end
"The thing that the mouse drags, drawn over the calendar"
@def mutable struct CalendarDrag <: SemanticUI
  of::Any = nothing
end

reread!(v::CalendarView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Calendars.calendar(lines)
  v.shown = nothing
  v
end

"The first day of the month that the calendar shows"
month_shown(v::CalendarView) = Calendars.shown(v.data, today=page_day(editor(v)))

"""
The tasks of the page's first schedule with their days, and whether its work
is done on Saturday and Sunday too. A page with no schedule has no tasks.
"""
calendar_tasks(e) = begin
  b = e.buf
  span = block_lines(b, SCHEDULE, 1)
  span === nothing && return Schedules.Planned[], false
  s = schedule_view(e, 1)
  reread!(s, b.lines[span[1]+1:span[2]-1])
  tasks!(s), s.data.weekends
end

"The things of each day. They're worked out again when the page has changed, and on a new day."
things!(v::CalendarView) = begin
  e = editor(v)
  items = calendar_items(v)
  # The items of a folder are one list until a page of the folder changes
  key = (e.buf.version, v.lines, calendar_today(), objectid(items))
  (v.shown !== nothing && v.shown[1] == key) || (v.shown = (key, Calendars.things(v.data, items, calendar_tasks(e)..., log_things(e))))
  v.shown[2]
end

"The folder whose pages the calendar shows the to-do items of, as a path, or nothing for a calendar of its own page's items"
calendar_folder(v::CalendarView) = begin
  name = Calendars.folder(v.lines)
  name === nothing ? nothing : abspath(joinpath(docdir(editor(v)), expanduser(name)))
end

"The to-do items that the calendar shows on their days: those of its page, or those of every page of its folder, as `folder_todos` gives them"
calendar_items(v::CalendarView) = (folder = calendar_folder(v); folder === nothing ? page_todos(editor(v)) : folder_todos(editor(v), folder).items)

"Where the to-do item called `key` is, for a calendar of a folder: its page, its line and its text. It's nothing for a calendar of its own page."
item_place(v::CalendarView, key) = (folder = calendar_folder(v); folder === nothing ? nothing : get(folder_todos(editor(v), folder).found, key, nothing))

"""
Write the day `to` in place of the day `from` in the text of the to-do item
`m`, in its own page. A page that's open is changed as if you'd typed the day
there. If it isn't the page that shows, and it had nothing to save, it's
saved. A page that isn't open is changed in its file. It gives the item's new
line, or nothing when the item or its day isn't there any more, or its page
can't be written.
"""
stamp_page!(e, m::Searches.Match, from::Date, to::Date) = begin
  b = get(e.buffers, m.path, nothing)
  if b !== nothing && !readonly(b)
    i = Searches.locate(m, b.lines, kinds(b))
    at = i === nothing ? nothing : Calendars.stamp_at(b.lines[i], from)
    at === nothing && return nothing
    clean = !dirty(b)
    caret, anchor = b.caret, b.anchor
    edit!(b, (i, at[1]), (i, at[2]), string(to))
    kept(p) = p[1] == i ? (i, min(p[2], length(b.lines[i]))) : p
    b.caret, b.anchor = kept(caret), kept(anchor)
    b !== e.buf && clean && save!(b)
    i
  else
    isfile(m.path) || return nothing
    lines = text(m.path)
    i = Searches.locate(m, lines)
    at = i === nothing ? nothing : Calendars.stamp_at(lines[i], from)
    at === nothing && return nothing
    lines[i] = first(lines[i], at[1]) * string(to) * join(Iterators.drop(lines[i], at[2]))
    try write(m.path, join(lines, "\n")) catch; return nothing end
    empty!(FOLDER_PAGES)   # the folder is read again, so that the calendar has the file as it is now
    i
  end
end

"""
The things that the page's time logs give its calendars: for each day of a
log, each task with the hours that the log has for it on that day. A click
on one, twice, goes to the first of its rows.
"""
log_things(e) = begin
  b = e.buf
  get!(e.flows, (:log_things, b.path, b.version)) do
    out = Calendars.Thing[]
    ks = kinds(b)
    at = Timelogs.now()
    for (i, k) in enumerate(ks)
      (k.kind == Kind.fence && k.level == 0 && k.lang == TIMELOG) || continue
      t = codeblock(b, i)[2]
      (t > i && ks[t].kind == Kind.fence && ks[t].level == 1) || continue
      lines = b.lines[i+1:t-1]
      rows = [Timelogs.stretch(String(strip(l))) for l in lines]
      for (day, task, minutes) in Timelogs.days(Timelogs.timelog(lines), at)
        minutes > 0 || continue
        r = findfirst(s -> s !== nothing && s.day == day && Timelogs.same(s.task, task), rows)
        push!(out, Calendars.Thing(:log, day, (isempty(task) ? "" : task * "  ") * Timelogs.hours(minutes), false, i + something(r, 0), task))
      end
    end
    out
  end
end

"The things of the day `d`"
day_things(v::CalendarView, d::Date) = get(things!(v), d, Calendars.Thing[])

"The line of the page that the thing `t` is on, or 0 when its block has gone"
thing_line(v::CalendarView, t) = begin
  t.kind == :event || return t.line
  span = block_lines(editor(v).buf, CALENDAR, v.n)
  span === nothing ? 0 : span[1] + t.line
end

"The text field of a calendar, for the words of a new event"
calendar_input(v::CalendarView) = block_part!(v, :input) do
  TextInput(placeholder="New event", font_family=SANS, font_size=12px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"True when the days are narrow, as they are in a narrow window"
tight(v::CalendarView) = v.wide < DAY_TIGHT

"How much room the words of a thing have in a day. `lead` is how wide the box or the tick before them is, with the space after it."
words_room(v::CalendarView, lead=0px) = max(v.wide - (tight(v) ? 13px : 19px) - lead, 1px)

"True while the mouse drags a thing of the calendar"
dragging(v::CalendarView) = v.grab !== nothing && v.grab[4]

"The day that the mouse is over, or nothing when the mouse isn't over a day"
drop_day(v::CalendarView) = begin
  w = window_of(v)
  w === nothing && return nothing
  x, y = w.mouse[1], w.mouse[2]
  for i in 1:7v.weeks
    c = get(v.parts, (:day, i), nothing)
    r = c === nothing ? nothing : rect(c)
    r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height && return c.day
  end
  nothing
end

"Note a click at `(x, y)`. True when it's the second of two clicks in one place."
click_twice!(v::CalendarView, x, y) = begin
  at, cx, cy = v.clicked
  v.clicked = (time(), x, y)
  time() - at < 0.35 && hypot(x - cx, y - cy) < 4
end

"How many lines the day `d` needs when its week shows every thing: its things, the field for a new event, and the words that hide them again"
day_lines(v::CalendarView, d::Date) = (n = length(day_things(v, d)); n + (v.adding == d ? 1 : 0) + (n > DAY_ROWS ? 1 : 0))

"How many lines of things each day of a week has room for. A week that shows every thing has room for the day with the most."
week_rows(v::CalendarView, week) = week[1] in v.open ? max(DAY_ROWS, maximum(d -> day_lines(v, d), week)) : DAY_ROWS

describe(t::CalendarTick) = begin
  thing = t.of.thing
  done = thing !== nothing && thing.done
  side = 13px
  Box(fixed(side), height(side), radius(3.5px), Alignment.Center, justify=Alignment.Center,
      (done ? (background(RGBA(colours.accent, 0.6)),) : (border(1.5px, :solid, ishovered(t) ? colours.accent : colours.marker),))...,
      (done ? (Icon("check", size=11px, color=colours.bg),) : ())...)
end

onkey(t::CalendarTick, ::KeyPress{Keys.mouse_left}) = begin
  c = t.of
  v, thing = c.of, c.thing
  settle!(v)
  e = editor(v)
  (thing === nothing || readonly(e.buf)) && return handled
  place = item_place(v, thing.key)
  # An item of another page is ticked in that page
  place === nothing || return (tick_page!(e, place, !thing.done); v.shown = nothing; handled)
  items = page_todos(e)
  k = findfirst(it -> it.key == thing.key, items)
  k === nothing || tick!(e, items[k].line)
  handled
end

describe(c::CalendarThing) = begin
  v, t = c.of, c.thing
  t === nothing && return Box(height(0px))
  on = v.picked == Calendars.id(t)
  taken = dragging(v) && Calendars.id(v.grab[1]) == Calendars.id(t)
  # A thing is marked while the mouse is on it in another part of the page, or on another of its days here
  lit = !taken && (t.kind == :task || !ishovered(c)) && marked(v, thing_name(t))
  c.box === nothing && (c.box = CalendarTick(of=c); setfield!(c.box, :parent, c))
  if t.kind == :task
    # A task looks like its bar in the schedule
    hue = t.done ? colours.string : colours.accent
    look = (background(RGBA(hue, on || lit ? 0.32 : 0.17)), border(on || lit ? 1.5px : 1px, :solid, RGBA(hue, 0.9)))
    lead = t.done && !tight(v) ? (Icon("check", size=12px, color=hue),) : ()
  elseif t.kind == :log
    # The hours of a time log are quiet: a small clock and grey words, with no box round them
    look = (background(lit ? mark_colour(takeoff_back()) : clear), border(1px, :solid, on || lit ? colours.accent : clear))
    lead = tight(v) ? () : (Icon("stopwatch", size=11px, color=colours.dim),)
  else
    look = (background(taken ? clear : lit ? mark_colour(colours.block) : colours.block),
            border(on && !taken ? 1.5px : 1px, :solid, taken ? colours.faint : on || lit ? colours.accent : ishovered(c) ? colours.marker : colours.line))
    # A narrow day has no room for the box: the words need it
    lead = t.kind == :todo && !tight(v) ? (c.box,) : ()
  end
  words = elide(t.words, 12px, words_room(v, isempty(lead) ? 0px : 18px))
  c.cut = words != t.words
  Row(width(grow=grow), height(THING_H), padding(tight(v) ? 3px : 5px, 0px), radius(5px), child_gap=5px, Alignment.Center, clip=true, name="Thing", look...,
    lead..., Box(label(words, 12px, color=taken ? colours.faint : t.done || t.kind == :log ? colours.dim : colours.ink)), Box(width(grow=grow)))
end

cursor(::Union{CalendarThing,CalendarTick,CalendarMore}) = :hand
cursor(::Union{CalendarView,CalendarDay,CalendarDrag}) = :arrow

onkey(c::CalendarThing, ev::KeyPress{Keys.mouse_left}) = begin
  v, w, t = c.of, ev.window, c.thing
  settle!(v)
  hide_tooltip!(w)
  t === nothing && return handled
  x, y = num(w.mouse[1]), num(w.mouse[2])
  twice = click_twice!(v, x, y)
  again = v.picked == Calendars.id(t)
  v.picked = Calendars.id(t)
  # Two clicks in one place go to the thing's line of the page, or of its own page for an item of a calendar of a folder
  if twice && again
    place = t.kind == :todo ? item_place(v, t.key) : nothing
    return place === nothing ? show_line!(editor(v), thing_line(v, t)) : visit!(editor(v), place.path, place)
  end
  # A task's days are the schedule's, and the hours of a log are the log's, so they stay where they are
  t.kind in (:task, :log) || readonly(editor(v).buf) || (v.grab = (t, x, y, false))
  # The press isn't a click on the page's text, so the text doesn't select when the mouse leaves the calendar with the thing
  e = editor(v)
  e.clicked = (e.clicked[1], e.clicked[2], 0)
  handled
end

# A thing whose words are cut short shows all of them over it
onmouse(c::CalendarThing, ev::MouseMove) = begin
  v, r = c.of, rect(c)
  (c.cut && c.thing !== nothing && v.grab === nothing && r !== nothing) || return nothing
  show_tooltip!(ev.window, tip_label(c.thing.words), r.left, r.top, r.width, r.height, placement=:top, gap=6px)
  nothing
end

describe(m::CalendarMore) = begin
  words = m.more > 0 ? "$(m.more) more" : "Fewer"
  Row(width(grow=grow), height(THING_H), padding(tight(m.of) ? 4px : 6px, 0px), Alignment.Center, clip=true, name="More",
    Box(label(elide(words, 11px, words_room(m.of)), 11px, color=ishovered(m) ? colours.accent : colours.dim)), Box(width(grow=grow)))
end

onkey(m::CalendarMore, ::KeyPress{Keys.mouse_left}) = begin
  v, week = m.of, Calendars.monday(m.day)
  settle!(v)
  week in v.open ? delete!(v.open, week) : push!(v.open, week)
  handled
end

describe(c::CalendarDay) = begin
  v, d = c.of, c.day
  list = day_things(v, d)
  open = Calendars.monday(d) in v.open
  some, more = open ? (list, 0) : Calendars.fit(list, DAY_ROWS)
  inside = Dates.month(d) == Dates.month(month_shown(v))
  weekend = Dates.dayofweek(d) > 5
  number = string(Dates.day(d))
  # The page's day has a circle. When that isn't today, today has a ring.
  head = d == page_day(editor(v)) ?
    Row(fixed(20px), height(20px), radius(10px), Alignment.Center, justify=Alignment.Center, background(colours.accent),
        Box(label(number, 11px, color=colours.bg, weight="Semibold"))) :
    d == calendar_today() ?
    Row(fixed(20px), height(20px), radius(10px), Alignment.Center, justify=Alignment.Center, border(1.5px, :solid, colours.accent),
        Box(label(number, 11px, color=colours.accent, weight="Semibold"))) :
    Row(height(20px), padding(4px, 0px), Alignment.Center,
        Box(label(number, 11px, color=!inside ? colours.faint : weekend ? colours.dim : colours.ink)))
  field = v.adding == d ?
    (Box(width(grow=grow), height(THING_H), padding(tight(v) ? 3px : 5px, 0px), radius(5px), border(1px, :solid, colours.accent), background(colours.bg), calendar_input(v)),) : ()
  under = more > 0 || (open && length(list) > DAY_ROWS) ?
    ((m = block_part!(() -> CalendarMore(of=v), v, (:more, c.i)); m.day = d; m.more = more; m),) : ()
  over = dragging(v) && drop_day(v) == d
  Column(width(grow=grow), height(c.tall), padding(tight(v) ? 2px : 3px, 0px), child_gap=THING_GAP, Alignment.Start, clip=true, name="Day",
         border(1px, :solid, colours.line)[(c.i % 7 == 1 ? (:top,) : (:top, :left))...],
         background(over ? RGBA(colours.accent, 0.14) : weekend ? RGBA(colours.ink, 0.035) : clear),
    Row(width(grow=grow), height(DAY_HEAD - THING_GAP), padding(tight(v) ? 2px : 1px, 0px), Alignment.Center, head, Box(width(grow=grow))),
    [(t = block_part!(() -> CalendarThing(of=v), v, (:thing, c.i, k)); t.thing = thing; t) for (k, thing) in enumerate(some)]...,
    field..., under...)
end

onkey(c::CalendarDay, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = c.of, ev.window
  settle!(v)
  v.picked = nothing
  # Two clicks on a day start a new event there
  click_twice!(v, num(w.mouse[1]), num(w.mouse[2])) && !readonly(editor(v).buf) && return add_event!(v, c.day)
  handled
end

"Show the field for a new event on the day `d`, and give it the keyboard"
add_event!(v::CalendarView, d::Date) = begin
  i = calendar_input(v)
  i.color = colours.ink
  i.text = ""
  i.anchor = i.cursor = 0
  v.adding = d
  v.clicked = (0.0, 0.0, 0.0)          # the next click isn't the second of two
  push!(v.open, Calendars.monday(d))   # the week grows, so that the field has room
  focus(i)
  handled
end

"Take the field for a new event away. With `keep`, the words that were typed are written into the block as an event."
settle!(v::CalendarView; keep=true) = begin
  d = v.adding
  d === nothing && return handled
  v.adding = nothing
  i = calendar_input(v)
  w = window_of(v)
  w !== nothing && w.focus === i && focus(editor(v))
  words = strip(replace(i.text, r"\s+" => " "))
  keep && !isempty(words) && write_block!(v, CALENDAR, Calendars.added(v.lines, d, words))
  handled
end

onkey(v::CalendarView, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (v.adding === nothing ? nothing : settle!(v)) : nothing
onkey(v::CalendarView, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (v.adding === nothing ? nothing : settle!(v, keep=false)) : nothing
# A click beside a button is the block's, and doesn't move the caret
onkey(v::CalendarView, ::KeyPress{Keys.mouse_left}) = (settle!(v); handled)
# A drag is the calendar's, so the page's text doesn't select
onmouse(v::CalendarView, ::MouseMove) = v.grab !== nothing || held(v, Keys.mouse_left) ? handled : nothing

"Do what a button of a calendar does: show the month before, the month after or the month of today"
act!(v::CalendarView, action, w) = begin
  settle!(v)
  empty!(v.open)
  to = action == :today ? nothing : month_shown(v) + Dates.Month(action == :before ? -1 : 1)
  write_block!(v, CALENDAR, Calendars.turned(v.lines, to))
  handled
end

describe(v::CalendarView) = begin
  e = editor(v)
  w = window_of(v)
  g = v.grab
  # A press that moves is a drag, and isn't the first click of two
  if g !== nothing && !g[4] && w !== nothing && hypot(num(w.mouse[1]) - g[2], num(w.mouse[2]) - g[3]) > 4
    v.grab = (g[1], g[2], g[3], true)
    v.clicked = (0.0, 0.0, 0.0)
  end
  calendar_input(v).color = colours.ink
  with_theme(component_theme(e.zoom)) do
    month = month_shown(v)
    weeks = Calendars.weeks(month)
    v.wide = (e.width - 2px) / 7   # each day is as wide as the next
    v.weeks = length(weeks)
    off = readonly(e.buf)
    bar = block_bar(
      block_button!(v, :before, :before, icon="chevron-left", tip="The month before", off=off),
      Row(fixed(max(min(122px, e.width - 150px), 10px)), Alignment.Center, justify=Alignment.Center, clip=true,
          Box(label(Calendars.title(month), 13px, weight="Semibold"))),
      block_button!(v, :after, :after, icon="chevron-right", tip="The month after", off=off),
      Box(width(grow=grow)),
      block_button!(v, :today, :today, words="Today", tip="Show the month of today", off=off || v.data.month === nothing))
    names = Row(width(grow=grow), height(24px), Alignment.Center,
      [Row(fixed(v.wide), padding(8px, 0px), Alignment.Center, clip=true,
           Box(label(name, 11px, color=i > 5 ? colours.faint : colours.dim)), Box(width(grow=grow))) for (i, name) in enumerate(Calendars.DAYS)]...)
    rows = map(enumerate(weeks)) do (k, week)
      tall = DAY_HEAD + week_rows(v, week) * (THING_H + THING_GAP) + 3px
      days = map(enumerate(week)) do (i, d)
        c = block_part!(() -> CalendarDay(of=v), v, (:day, 7(k - 1) + i))
        c.i, c.day, c.tall = 7(k - 1) + i, d, tall
        Box(fixed(v.wide), Alignment.Start, c)
      end
      Row(width(grow=grow), Alignment.Start, days...)
    end
    Stack(block_look()..., clip=true, name="Calendar", Column(width(grow=grow), Alignment.Start, bar, names, rows...),
          (dragging(v) ? (block_part!(() -> CalendarDrag(of=v), v, :drag),) : ())...)
  end
end

describe(::CalendarDrag) = Box(width(grow=grow), height(grow=grow))

draw(ctx, size, ui::ConcreteRect, layer::CalendarDrag) = begin
  v = layer.of
  w = window_of(v)
  (w === nothing || !dragging(v)) && return
  t = v.grab[1]
  # The thing stays under the mouse
  wide = max(num(v.wide) - 6, 40.0)
  x, y = num(w.mouse[1]) - wide / 2, num(w.mouse[2]) - 10
  face = Face(SANS, "", 12px, colours.ink, false)
  round_box(ctx, x + 1, y + 3, wide, 20, 5; fill=RGBA(0, 0, 0, 0.12))
  round_box(ctx, x, y, wide, 20, 5; fill=takeoff_back(), line=colours.accent, wide=1.5)
  write_ink(ctx, elide(t.words, 12px, px(wide - 12)), x + 6, y + 14, face)
end

"A drag ended. Ladder writes the day that the thing was dropped on into the to-do item's text, or into the event's line."
drop!(v::CalendarView) = begin
  g = v.grab
  v.grab = nothing
  (g === nothing || !g[4]) && return v
  t, d = g[1], drop_day(v)
  e = editor(v)
  b = e.buf
  (d === nothing || d == t.day || readonly(b)) && return v
  if t.kind == :event
    write_block!(v, CALENDAR, Calendars.moved(v.lines, t.line, d))
  elseif t.kind == :todo && calendar_folder(v) !== nothing
    # The item's own page gets the new day
    place = item_place(v, t.key)
    line = place === nothing ? nothing : stamp_page!(e, place, t.day, d)
    line === nothing && return v
    # The item's name has the new day in it, and the item stays selected
    found = folder_todos(e, calendar_folder(v)).found
    now = findfirst(m -> m.path == place.path && m.line == line, found)
    v.picked = now === nothing ? nothing : (:todo, now)
  elseif t.kind == :todo
    k = findfirst(it -> it.key == t.key, page_todos(e))
    k === nothing && return v
    line = page_todos(e)[k].line
    at = Calendars.stamp_at(b.lines[line], t.day)
    at === nothing && return v
    caret, anchor = b.caret, b.anchor
    edit!(b, (line, at[1]), (line, at[2]), string(d))
    kept(p) = p[1] == line ? (line, min(p[2], length(b.lines[line]))) : p
    b.caret, b.anchor = kept(caret), kept(anchor)
    # The item's name has the new day in it, and the item stays selected
    k = findfirst(it -> it.line == line, page_todos(e))
    k === nothing || (v.picked = (:todo, page_todos(e)[k].key))
  end
  v.shown = nothing
  v
end

"What happens to a calendar in each frame, before the page is laid out: a drag that ended is written down, and the field that lost the keyboard closes"
block_tick!(v::CalendarView) = begin
  v.grab !== nothing && !held(v, Keys.mouse_left) && drop!(v)
  w = window_of(v)
  # A click somewhere else took the keyboard from the field. The words that were typed are kept.
  v.adding !== nothing && w !== nothing && w.focus !== calendar_input(v) && settle!(v)
  v
end

"A thing of a day as HTML. A thing that's done has a tick, and is grey."
thing_html(t) = t.done ? "<span style=\"color: #8a8176\">✓ $(escape(t.words))</span>" : escape(t.words)

"The calendar as HTML: a table with a row for each week of the month, and the things of each day in the day's cell"
calendar_html(e, v::CalendarView) = begin
  month = month_shown(v)
  days = things!(v)
  cell(d) = begin
    number = Dates.month(d) == Dates.month(month) ? "<b>$(Dates.day(d))</b>" : "<span style=\"color: #a89f91\">$(Dates.day(d))</span>"
    "<td style=\"vertical-align: top\">" * join([number; thing_html.(get(days, d, Calendars.Thing[]))], "<br>") * "</td>"
  end
  heads = join("<th>$name</th>" for name in Calendars.DAYS)
  rows = join(("<tr>" * join(cell.(week)) * "</tr>" for week in Calendars.weeks(month)), "\n")
  "<table style=\"width: 100%; table-layout: fixed\">\n<caption>$(Calendars.title(month))</caption>\n<tr>$heads</tr>\n$rows\n</table>"
end

BLOCKS[CALENDAR] = CalendarView
block_name(::Type{CalendarView}) = "Calendar"
block_icon(::Type{CalendarView}) = "calendar3"
block_insert(::Type{CalendarView}) = ("Calendar", ["```$CALENDAR", "```", "", ""], (4, 0))
block_html(e, v::CalendarView) = calendar_html(e, v)

"What tells a thing of a calendar from the others for the rest of the page: the name of its task or its to-do item, or the words of an event"
thing_name(t::Calendars.Thing) = t.kind == :event ? t.words : t.key
