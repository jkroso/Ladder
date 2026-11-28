# A calendar shows one month as a grid of days, from Monday to Sunday, with
# the things of its page that have a day. In a document the calendar is a code
# block in the language `calendar`:
#
#     ```calendar
#     month: 2026-11
#
#     2026-11-25 | Concrete pour
#     2026-11-27 | Council inspection
#     ```
#
# `month` is the month that shows. Without it, the calendar shows the month of
# today. Each line under it is an event of the calendar's own: a day, a |, and
# the event's words.
#
# The calendar shows three kinds of thing on their days:
#
# - a task of the page's schedule, on every working day that the task runs
# - a to-do item of the page that has a day in its text, like
#   `- [ ] Order the tiles 2026-11-25`
# - an event of the calendar's own
# - the hours that a time log of the page has for each task on a day
#
# A to-do item with a day in its text shows on that day only, and not on the
# days that the schedule gives it.
#
# A line like `in: jobs` makes it a calendar of a folder: its to-do items are
# those of every page in the folder `jobs` beside the page, and in the folders
# inside that one. `in: .` is the page's own folder. The tasks, the events and
# the hours are still the page's own.
#
# This file reads and writes those lines, finds the day in a to-do item's
# text, and works out the things of each day. It draws nothing. schedule.jl
# works out the days of each task.

@use Dates: Dates, Date, Day
@use "../dates" day ISO
@use "./schedule" Todo Planned works

"The language of a code block that is a calendar"
const CALENDAR = "calendar"

"An event of the calendar's own"
struct Event
  line::Int       # the line of the block that it's on
  day::Date
  words::String
end

struct Calendar
  month::Union{Nothing,Date}   # the first day of the month that shows, or nothing for the month of today
  events::Vector{Event}
end

Calendar() = Calendar(nothing, Event[])

"A thing that the calendar shows on a day"
struct Thing
  kind::Symbol    # :task, :todo or :event, or :log for the hours that a time log has for a task on the day
  day::Date
  words::String
  done::Bool
  line::Int       # the line of the page that a task, a to-do item or a row of a log is on. For an event, its line of the block.
  key::String     # what a schedule calls the task or the to-do item, the task of a log's hours, or "" for an event
end

"What tells one thing from the others. A task has the same one on each of its days."
id(t::Thing) = (t.kind, t.kind == :event ? string(t.line) : t.key)

# --- reading -------------------------------------------------------------------------

"The first day of the month that `line` names, when it's a line like `month: 2026-11`, or nothing"
month(line::AbstractString) = begin
  m = match(r"^\s*month\s*:\s*(\d{4})-(\d{1,2})\s*$"i, line)
  m === nothing ? nothing : day(parse(Int, m[1]), parse(Int, m[2]), 1)
end

"The day and the words of `line`, when it's a line like `2026-11-25 | Concrete pour`, or nothing"
event(line::AbstractString) = begin
  m = match(r"^\s*(\d{4})-(\d{1,2})-(\d{1,2})\s*\|\s*(.*?)\s*$", line)
  m === nothing && return nothing
  d = day(m)
  d === nothing || isempty(m[4]) ? nothing : (d, String(m[4]))
end

"""
The folder whose pages the calendar shows the to-do items of, as a line like
`in: jobs` among `lines` names it: a folder beside the page, or `.` for the
page's own folder. It's nothing for a calendar of its own page's items.
"""
folder(lines) = begin
  for line in lines
    m = match(r"^\s*in\s*:\s*(.*?)\s*$"i, line)
    m === nothing || return isempty(m[1]) ? "." : String(m[1])
  end
  nothing
end

"Read a calendar from the lines of its block. A line that it can't read is left out."
calendar(lines) = begin
  shows, events = nothing, Event[]
  for (k, line) in enumerate(lines)
    shows === nothing && (shows = month(line))
    found = event(line)
    found === nothing || push!(events, Event(k, found...))
  end
  Calendar(shows, events)
end

# --- the month -----------------------------------------------------------------------

"The first day of the month that the calendar shows. `today` is the day that counts as today."
shown(c::Calendar; today::Date=Dates.today()) = something(c.month, Dates.firstdayofmonth(today))

"The Monday of the week that `d` is in"
monday(d::Date) = d - Day(Dates.dayofweek(d) - 1)

"The weeks that the month of `first` is in. Each week is its seven days, from Monday to Sunday."
weeks(first::Date) = begin
  start = monday(first)
  [[start + Day(7w + d) for d in 0:6] for w in 0:5 if start + Day(7w) <= Dates.lastdayofmonth(first)]
end

"The name of a month with its year: November 2026"
title(first::Date) = "$(Dates.monthname(first)) $(Dates.year(first))"

"The short names of the days of a week, from Monday"
const DAYS = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

# --- the day in a to-do item's text --------------------------------------------------

"The first day that's written in `text` like 2026-11-25, or nothing"
stamp(text::AbstractString) = day(text; iso=true, anywhere=true)

"`text` without the first day that's written in it, and without the brackets and the marks that were round that day"
plain(text::AbstractString) = begin
  for m in eachmatch(ISO, text)
    day(m) === nothing && continue
    before = rstrip(c -> isspace(c) || c in "([-–—:,", text[1:prevind(text, m.offset)])
    after = lstrip(c -> isspace(c) || c in ")]-–—:,", text[m.offset+ncodeunits(m.match):end])
    return String(strip(isempty(before) || isempty(after) ? before * after : before * " " * after))
  end
  String(strip(text))
end

"""
Where `d` is written in `line`: how many characters come before it, and how
many come before its end. It's nothing when the line doesn't have that day.
"""
stamp_at(line::AbstractString, d::Date) = begin
  for m in eachmatch(ISO, line)
    day(m) == d || continue
    from = length(line, 1, prevind(line, m.offset))
    return (from, from + length(m.match))
  end
  nothing
end

# --- the things of each day ----------------------------------------------------------

"""
The things of each day. `items` are the page's to-do items, and `tasks` are
the tasks of its schedule with their days, as `plan!` of schedule.jl gives
them. `weekends` is true when the schedule's work is done on Saturday and
Sunday too. A day's tasks come first, then its to-do items, then its events.
`others` are things that other parts of the page give the calendar, like the
hours of a time log: they come last.
"""
things(c::Calendar, items, tasks=Planned[], weekends::Bool=false, others=Thing[]) = begin
  out = Dict{Date,Vector{Thing}}()
  add(t) = push!(get!(() -> Thing[], out, t.day), t)
  for task in tasks
    t = task.todo
    stamp(t.name) === nothing || continue
    for d in task.start:Day(1):task.finish
      works(d, weekends) && add(Thing(:task, d, t.name, t.done, t.line, t.key))
    end
  end
  for t in items
    d = stamp(t.name)
    d === nothing || add(Thing(:todo, d, plain(t.name), t.done, t.line, t.key))
  end
  foreach(e -> add(Thing(:event, e.day, e.words, false, e.line, "")), c.events)
  foreach(add, others)
  out
end

"""
The things of `list` that a day with room for `slots` lines shows, and how
many more there are. A day with more things than lines gives its last line to
the words that say how many more.
"""
fit(list, slots::Int) = (n = length(list) <= slots ? length(list) : max(slots - 1, 0); (list[1:n], length(list) - n))

# --- writing -------------------------------------------------------------------------
#
# Each of these gives the new lines of the block. The other lines stay as they are.

"The block's lines when the calendar shows the month of `first`. With nothing, the line that names a month goes, so the calendar shows the month of today."
turned(lines, first::Union{Nothing,Date}) = begin
  out = String[String(l) for l in lines]
  k = findfirst(l -> month(l) !== nothing, out)
  if first === nothing
    k === nothing && return out
    deleteat!(out, k)
    # The empty line under a month at the top goes with it
    k == 1 && !isempty(out) && isempty(strip(out[1])) && popfirst!(out)
  elseif k === nothing
    isempty(out) || isempty(strip(out[1])) || pushfirst!(out, "")
    pushfirst!(out, "month: " * Dates.format(first, "yyyy-mm"))
  else
    out[k] = "month: " * Dates.format(first, "yyyy-mm")
  end
  out
end

"The block's lines when the event on line `k` is on the day `d`"
moved(lines, k::Int, d::Date) = begin
  out = String[String(l) for l in lines]
  1 <= k <= length(out) && (out[k] = replace(out[k], ISO => string(d), count=1))
  out
end

"The block's lines with a new event on the day `d`"
added(lines, d::Date, words::AbstractString) = begin
  out = String[String(l) for l in lines]
  # The first event has an empty line over it
  isempty(out) || isempty(strip(out[end])) || any(l -> event(l) !== nothing, out) || push!(out, "")
  push!(out, "$d | $(strip(words))")
  out
end

export CALENDAR, Calendar, Event, Thing
