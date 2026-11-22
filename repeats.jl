# To-do items that repeat. An item's words say how often, and a day like
# 2026-12-01 says when it's due:
#
#     - [ ] Test the smoke alarms 2026-12-01 every 3 months
#
# When its box is ticked, a new item goes under it: the same words with an
# empty box, on the next day that it's due, 2027-03-01 here. The ticked item
# stays as it is, so the page keeps the days that the work was done. An item
# with no day repeats from the day that it's ticked, and the new item gets a
# day, in front of the words that say how often.
#
# How often is one of these, in any case, at the end of the item's words or
# just before its day. Anywhere else they're only words, as in "Write the
# daily report":
#
# - `every day`, `every week`, `every fortnight`, `every month`, `every year`
# - a number before those, like `every 2 weeks` or `every 3 months`
# - `daily`, `weekly`, `fortnightly`, `monthly`, `yearly`
# - a day of the week, like `every Monday`
# - `every weekday`: each day from Monday to Friday
#
# The next day is the first of the item's days that's after today. So an item
# that's ticked late doesn't come back due at once: it skips the days that it
# missed. A month from the 31st of a month is the last day of a shorter month,
# and the days after it are worked out from the first day, so they come back to
# the 31st.
#
# Taking the tick away again takes away the item that the tick added, while
# that item is still as it was added. A tick of the new item adds the next.
#
# This file reads the words, and works out the new item. It draws nothing.

@use Dates: Dates, Date, Day, Week, Month, Year

"A day in an item's words, as calendar.jl reads it"
const DAY = r"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"

"A list item with a box: the spaces and the mark before the box, and what's in it"
const BOX = r"^(\s*[-*+]\s+\[)([ xX])(\])"

const UNITS = Dict("day" => Day(1), "week" => Week(1), "fortnight" => Week(2), "month" => Month(1), "year" => Year(1))
const ADVERBS = Dict("daily" => "day", "weekly" => "week", "fortnightly" => "fortnight", "monthly" => "month", "yearly" => "year")
const WEEKDAYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")

"The words that say how often an item repeats"
const HOW_OFTEN = Regex("\\b(?:every\\s+(?:(\\d+)\\s+)?(day|week|fortnight|month|year)s?|(daily|weekly|fortnightly|monthly|yearly)|every\\s+(" *
                        join(WEEKDAYS, '|') * "|weekday))\\b", "i")

"What may follow the words that say how often: a day, and a full stop"
const AFTER = r"^\s*(?:\d{4}-\d{1,2}-\d{1,2})?\s*[.!]?\s*$"

"The words of `text` that say how often an item repeats, as a match, or nothing when no such words end it"
how_often(text::AbstractString) = begin
  found = nothing
  for m in eachmatch(HOW_OFTEN, text)
    found = m
  end
  found === nothing && return nothing
  occursin(AFTER, text[found.offset+ncodeunits(found.match):end]) ? found : nothing
end

"""
How often the words `text` say that an item repeats: a function that gives the
`k`th day after a first day, or nothing when they don't say.
"""
rule(text::AbstractString) = begin
  m = how_often(text)
  m === nothing && return nothing
  if m[2] !== nothing || m[3] !== nothing
    n = m[1] === nothing ? 1 : parse(Int, m[1])
    n > 0 || return nothing
    step = UNITS[m[2] !== nothing ? lowercase(m[2]) : ADVERBS[lowercase(m[3])]]
    # Each day is worked out from the first, so a month from the 31st comes back to the 31st after a short month
    return (first, k) -> first + step * (n * k)
  end
  name = lowercase(m[4])
  if name == "weekday"
    return (first, k) -> begin
      d = first
      for _ in 1:k
        d += Day(1)
        while Dates.dayofweek(d) > 5
          d += Day(1)
        end
      end
      d
    end
  end
  wanted = findfirst(==(name), WEEKDAYS)
  # The first one is the next of that day after the first day, then a week after each
  (first, k) -> first + Day(mod1(wanted - Dates.dayofweek(first), 7)) + Week(k - 1)
end

"The first day in the words `text`, or nothing"
day_in(text::AbstractString) = begin
  m = match(DAY, text)
  m === nothing && return nothing
  y, mo, d = parse.(Int, (m[1], m[2], m[3]))
  Dates.validargs(Date, y, mo, d) === nothing ? Date(y, mo, d) : nothing
end

"The first of the days that `next` gives after `first` that's after `today`"
next_day(next, first::Date, today::Date) = begin
  for k in 1:100_000
    d = next(first, k)
    d > today && return d
  end
  next(first, 1)
end

"True when `line` is a to-do item whose box is ticked"
ticked(line::AbstractString) = (m = match(BOX, line); m !== nothing && m[2] != " ")

"`line`, a to-do item, with its box ticked when `done`, or empty"
with_tick(line::AbstractString, done::Bool) = replace(line, BOX => SubstitutionString("\\1" * (done ? "x" : " ") * "\\3"), count=1)

"""
The new item that a tick of the to-do item `line` adds under it: the same
words with an empty box, on the next day that it's due. It's nothing when
`line` isn't a ticked item, or its words don't say how often it repeats.
"""
repeated(line::AbstractString; today::Date=Dates.today()) = begin
  ticked(line) || return nothing
  words = replace(line, BOX => "", count=1)
  next = rule(words)
  next === nothing && return nothing
  first = day_in(words)
  open = with_tick(line, false)
  first !== nothing && return replace(open, DAY => string(next_day(next, first, today)), count=1)
  # With no day, it repeats from today. The day goes in front of the words that say how often.
  d = string(next_day(next, today, today))
  m = how_often(open)
  open[1:prevind(open, m.offset)] * d * " " * open[m.offset:end]
end

"How far the line `line` is indented"
indent(line::AbstractString) = length(line) - length(lstrip(line))

"The last line of the to-do item on line `i` of `lines`: its own, or of the items under it"
item_end(lines, i::Int) = begin
  z = i
  while z < length(lines) && !isempty(strip(lines[z+1])) && indent(lines[z+1]) > indent(lines[i])
    z += 1
  end
  z
end

"""
What lines `i` to `z` of `lines` become when the box of the to-do item on line
`i` is ticked, when `done`, or emptied: the lines, and `z`. A tick of an item
that repeats adds the next one after the items under it. Taking the tick away
takes away the item that the tick added, while it's still as it was added.
"""
tick(lines, i::Int, done::Bool; today::Date=Dates.today()) = begin
  line = with_tick(lines[i], done)
  z = item_end(lines, i)
  under = lines[i+1:z]
  if done
    new = repeated(line; today)
    new === nothing || ticked(lines[i]) || return ([line; under; new], z)
  elseif z < length(lines) && (added = repeated(lines[i]; today)) !== nothing && lines[z+1] == added
    return ([line; under], z + 1)
  end
  ([line], i)
end
