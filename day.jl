# A page shows itself as it stands on one day. That day is today, until the
# page has a code block in the language `day`. Such a block shows a line of
# days with a slider on it, and the day that the slider is on is the page's
# day:
#
#     ```day
#     2026-11-25
#     ```
#
# A block with no day in it means today. The other parts of the page ask for
# the page's day where they would ask for today: a schedule draws its line of
# today there and shows which tasks are finished by then, the boxes of the
# to-do items have a tick for those tasks, a board puts each
# card in the column that the schedule's plan gives it on that day, a calendar
# shows that day's month, and a time log adds up the hours to that day.
#
# This file reads and writes the block's line, and says how a task stands on
# a day. It draws nothing.

@use Dates: Dates, Date, Day

"The language of a code block that sets the page's day"
const DAY = "day"

const WRITTEN = r"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"

"The day that the lines of a block say: the first one written like 2026-11-25. It's nothing when they say none."
day(lines) = begin
  for line in lines
    m = match(WRITTEN, line)
    m === nothing && continue
    y, mo, d = parse.(Int, m.captures)
    Dates.validargs(Date, y, mo, d) === nothing && return Date(y, mo, d)
  end
  nothing
end

"The block's lines when its day is `d`. With nothing, the day goes, so the block means today. The other lines stay."
written(lines, d::Union{Nothing,Date}) = begin
  out = String[String(l) for l in lines if match(WRITTEN, l) === nothing && !isempty(strip(l))]
  d === nothing || pushfirst!(out, string(d))
  out
end

"""
How a task stands on the day `d`: `:done`, `:doing` or `:todo`. The task runs
from `start` to `finish` in the plan, and `done` says whether it's ticked
now. `today` is the real day. On a day that's past, only the plan says: what's
ticked now may not have been ticked then. On a day to come, a task that's
ticked now stays done. Today, a task is done when it's ticked, and not before.
"""
stands(start::Date, finish::Date, done::Bool, d::Date, today::Date) =
  d == today ? (done ? :done : start <= d ? :doing : :todo) :
  finish < d || (done && d > today) ? :done : start <= d ? :doing : :todo

"""
The days that a slider shows, for a page whose things are on the days `days`:
from a few days before the first of them to a few days after the last, and
two weeks at the least. `today` and the page's day `d` are always among them.
"""
span(days, today::Date, d::Date=today) = begin
  lo, hi = extrema([collect(Date, days); today; d])
  lo, hi = lo - Day(2), hi + Day(2)
  short = 13 - Dates.value(hi - lo)
  short > 0 && (hi += Day(short))
  lo:Day(1):hi
end

"How far the day `d` is from `today`, in words: today, tomorrow, yesterday, in 5 days, 3 days ago"
away(d::Date, today::Date) = begin
  n = Dates.value(d - today)
  n == 0 ? "today" : n == 1 ? "tomorrow" : n == -1 ? "yesterday" : n > 0 ? "in $n days" : "$(-n) days ago"
end

export DAY
