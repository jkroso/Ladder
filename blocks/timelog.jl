# A time log keeps the hours that someone works on each task. In a document
# it's a code block in the language `timelog`:
#
#     ```timelog
#     rate: 85
#     round: 15
#
#     2026-11-17 07:30-12:00 | Framing
#     2026-11-17 12:30-15:45 | Framing
#     2026-11-18 08:10- | Roofing
#     ```
#
# Each line under the settings is one stretch of work: the day, the time it
# started, a -, the time it stopped, a |, and the task. A line with no stop
# time is the one that runs now. If more than one line has none, the last of
# them runs, and the others count for nothing. Times are written with 24
# hours, like 07:30. `7:30am`, `3:45pm` and `7am` are read too. A stop time
# that's earlier than the start time is on the next day, so 22:00-01:30 is 3
# hours and 30 minutes.
#
# `rate` is dollars for each hour. With it, the totals show money too. `round`
# is a number of minutes. With it, each stretch is rounded to the nearest
# that many minutes when the hours are added up. The lines keep the true
# times. A line that can't be read is kept as it is, and counts for nothing.
#
# This file reads and writes those lines, adds the hours up, and starts and
# stops the clock. Each function that needs the time now takes it. `now()`
# gives it, and a test puts another function in `CLOCK`. It draws nothing.

@use Dates: Dates, Date, Time, DateTime

"The language of a code block that is a time log"
const TIMELOG = "timelog"

"The function that gives the time now. A test puts its own here."
const CLOCK = Ref{Function}(Dates.now)

"The time now, on this Mac's clock"
now() = CLOCK[]()::DateTime

"One stretch of work on a task: a line of the log"
mutable struct Stretch
  day::Date
  from::Time
  to::Union{Time,Nothing}   # nothing when the line has no stop time
  task::String
end

mutable struct Log
  rate::Union{Float64,Nothing}          # dollars for each hour, or nothing
  round::Int                            # the minutes that each stretch is rounded to, or 0
  rows::Vector{Union{Stretch,String}}   # each line: a stretch, or the text of a line that can't be read
end

Log() = Log(nothing, 0, Union{Stretch,String}[])

"The time that `text` says, like 07:30, 7:30am or 3pm, or nothing"
time_of(text::AbstractString) = begin
  m = match(r"^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?$"i, strip(text))
  m === nothing && return nothing
  hour, minute = parse(Int, m[1]), m[2] === nothing ? 0 : parse(Int, m[2])
  if m[3] !== nothing
    1 <= hour <= 12 || return nothing
    hour = hour % 12 + (lowercase(m[3]) == "pm" ? 12 : 0)
  end
  hour <= 23 && minute <= 59 ? Time(hour, minute) : nothing
end

"The stretch that a line says, or nothing when it can't be read"
stretch(line::AbstractString) = begin
  m = match(r"^(\d{4})-(\d{1,2})-(\d{1,2})\s+([^|]*?)\s*(?:\|(.*))?$", strip(line))
  m === nothing && return nothing
  date = parse.(Int, (m[1], m[2], m[3]))
  Dates.validargs(Date, date...) === nothing || return nothing
  times = match(r"^([^-–]+)[-–]([^-–]*)$", m[4])
  times === nothing && return nothing
  from = time_of(times[1])
  to = isempty(strip(times[2])) ? nothing : time_of(times[2])
  (from === nothing || (to === nothing && !isempty(strip(times[2])))) && return nothing
  Stretch(Date(date...), from, to, m[5] === nothing ? "" : String(strip(m[5])))
end

"Read a log from the lines of its block"
timelog(lines) = begin
  log = Log()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    rate = match(r"^rate\s*:\s*\$?\s*(\d[\d,]*(?:\.\d+)?)$"i, text)
    step = match(r"^round\s*:\s*(\d{1,4})\s*(?:min\w*)?$"i, text)
    if rate !== nothing
      log.rate = parse(Float64, replace(rate[1], ',' => ""))
    elseif step !== nothing
      log.round = parse(Int, step[1])
    else
      push!(log.rows, something(stretch(text), String(text)))
    end
  end
  log
end

"A time as a line has it: 07:30"
hhmm(t::Time) = lpad(Dates.hour(t), 2, '0') * ":" * lpad(Dates.minute(t), 2, '0')

"The line of the stretch `s`"
written(s::Stretch) = "$(s.day) $(hhmm(s.from))-$(s.to === nothing ? "" : hhmm(s.to))" * (isempty(s.task) ? "" : " | " * s.task)

"The lines of a log's block: its settings, then a line for each stretch"
written(log::Log) = begin
  out = String[]
  log.rate === nothing || push!(out, "rate: " * (isinteger(log.rate) ? string(round(Int, log.rate)) : string(log.rate)))
  log.round > 0 && push!(out, "round: $(log.round)")
  isempty(out) || isempty(log.rows) || push!(out, "")
  append!(out, (r isa Stretch ? written(r) : r for r in log.rows))
  out
end

"The place of the row that runs now: the last stretch with no stop time. It's nothing when no line runs."
running(log::Log) = findlast(r -> r isa Stretch && r.to === nothing, log.rows)

"The stretch at row `i`, or nothing when that row is a line that can't be read"
stretch(log::Log, i::Int) = i in eachindex(log.rows) && log.rows[i] isa Stretch ? log.rows[i] : nothing

"""
How many seconds row `i` took. The row that runs counts up to `now`. A stop
time that's earlier than the start time is on the next day. A line that can't
be read counts for nothing, and so does a line with no stop time that isn't
the one that runs.
"""
seconds(log::Log, i::Int, now::DateTime) = begin
  s = stretch(log, i)
  s === nothing && return 0
  if s.to === nothing
    i == running(log) || return 0
    return max(0, Dates.value(now - DateTime(s.day, s.from)) ÷ 1000)
  end
  n = Dates.value(s.to - s.from) ÷ 1_000_000_000
  n < 0 ? n + 86400 : n
end

"The log with only the stretches of the days up to `d`. A line that can't be read is left out."
upto(log::Log, d::Date) = Log(log.rate, log.round, Union{Stretch,String}[r for r in log.rows if r isa Stretch && r.day <= d])

"The whole minutes of row `i`, as its times say"
minutes(log::Log, i::Int, now::DateTime) = seconds(log, i, now) ÷ 60

"The minutes of row `i` that are added up: rounded to the nearest `round` minutes, when the log has that setting"
counted(log::Log, i::Int, now::DateTime) = begin
  m = minutes(log, i, now)
  log.round > 0 ? floor(Int, m / log.round + 0.5) * log.round : m
end

"The minutes of every row, added up"
total(log::Log, now::DateTime) = sum(i -> counted(log, i, now), eachindex(log.rows), init=0)

same(a::AbstractString, b::AbstractString) = lowercase(strip(a)) == lowercase(strip(b))

"The tasks of the log, in the order that it first has them, with the minutes of each. Capital letters don't make another task."
tasks(log::Log, now::DateTime) = begin
  out = Pair{String,Int}[]
  for (i, r) in enumerate(log.rows)
    r isa Stretch || continue
    k = findfirst(p -> same(p.first, r.task), out)
    k === nothing ? push!(out, r.task => counted(log, i, now)) : (out[k] = out[k].first => out[k].second + counted(log, i, now))
  end
  out
end

"The minutes of each task on each day, in the order of the log: the day, the task and the minutes. Capital letters don't make another task."
days(log::Log, now::DateTime) = begin
  out = Tuple{Date,String,Int}[]
  for (i, r) in enumerate(log.rows)
    r isa Stretch || continue
    k = findfirst(d -> d[1] == r.day && same(d[2], r.task), out)
    m = counted(log, i, now)
    k === nothing ? push!(out, (r.day, r.task, m)) : (out[k] = (out[k][1], out[k][2], out[k][3] + m))
  end
  out
end

"What `minutes` of work cost at the log's rate, like \$1,105.00, or nothing when the log has no rate"
money(log::Log, minutes::Int) = begin
  log.rate === nothing && return nothing
  cents = floor(Int, min(minutes * log.rate * 100 / 60 + 0.5, 9.0e17))   # a rate with too many digits doesn't stop the page
  "\$" * replace(string(cents ÷ 100), r"(?<=\d)(?=(\d{3})+$)" => ",") * "." * lpad(cents % 100, 2, '0')
end

"A number of minutes as hours and minutes: 4 h 30 min"
hours(minutes::Int) = begin
  h, m = divrem(minutes, 60)
  h == 0 ? "$m min" : m == 0 ? "$h h" : "$h h $m min"
end

"The time that has gone by on the row that runs, to the second: 1 h 02 min 07 s"
elapsed(seconds::Int) = begin
  h, rest = divrem(seconds, 3600)
  m, s = divrem(rest, 60)
  h > 0 ? "$h h $(lpad(m, 2, '0')) min $(lpad(s, 2, '0')) s" : m > 0 ? "$m min $(lpad(s, 2, '0')) s" : "$s s"
end

"A day as a row shows it: Tue 17 Nov"
day(d::Date) = Dates.format(d, "e d u")

"The time `at` without its seconds, as a line keeps it"
to_minute(at::DateTime) = Time(Dates.hour(at), Dates.minute(at))

"The task of the last stretch, or \"\" when the log has none"
last_task(log::Log) = (k = findlast(r -> r isa Stretch, log.rows); k === nothing ? "" : log.rows[k].task)

"A task as one line of the block can hold it"
tidy(task::AbstractString) = String(strip(replace(task, r"\s+" => " ")))

"Stop the row that runs, at `at`. It gives false when no row runs."
stop!(log::Log, at::DateTime) = begin
  i = running(log)
  i === nothing && return false
  log.rows[i].to = to_minute(at)
  true
end

"""
Start the clock on `task` at `at`: a new line with no stop time. The row that
runs is stopped first, so only one runs. With no task, the new line has the
task of the last one.
"""
start!(log::Log, task::AbstractString, at::DateTime) = begin
  task = tidy(task)
  isempty(task) && (task = last_task(log))
  stop!(log, at)
  push!(log.rows, Stretch(Date(at), to_minute(at), nothing, task))
  log
end

"""
Change a part of row `i` to what `text` says: `:from` or `:to` for a time, or
`:task`. It gives false, and changes nothing, when a time can't be read. An
empty stop time makes the row run again, if no other row runs.
"""
set!(log::Log, i::Int, part::Symbol, text::AbstractString) = begin
  s = stretch(log, i)
  s === nothing && return false
  part == :task && return (s.task = tidy(text); true)
  if part == :to && isempty(strip(text))
    something(running(log), i) == i || return false
    s.to = nothing
    return true
  end
  t = time_of(text)
  t === nothing && return false
  part == :from ? (s.from = t) : (s.to = t)
  true
end

"""
The tasks of the log that have `typed` in them, for a field to offer: the ones
that start with it first, and the newest first among those. A task that's
all of what was typed isn't offered.
"""
offered(log::Log, typed::AbstractString) = begin
  typed = lowercase(tidy(typed))
  names = String[]
  for r in Iterators.reverse(log.rows)
    r isa Stretch && !isempty(r.task) && !any(n -> same(n, r.task), names) && push!(names, r.task)
  end
  filter!(n -> occursin(typed, lowercase(n)) && lowercase(n) != typed, names)
  sort!(names, by=n -> !startswith(lowercase(n), typed))
end

"The log as the rows of a table for a chart: the names of its two columns, then each task with its hours as a number"
table(log::Log, now::DateTime) =
  Vector{String}[["Task", "Hours"], ([isempty(name) ? "No task" : name, string(round(m / 60, digits=2))] for (name, m) in tasks(log, now))...]
