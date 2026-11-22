# A schedule says when each task of a page is done. The tasks are the page's
# to-do items: the lines that start with `- [ ]`. In a document the schedule
# is a code block in the language `schedule`:
#
#     ```schedule
#     start: 2026-11-16
#
#     Dig the trench | 3 days
#     Lay the new pipe | 2 days | after Dig the trench
#     Fill the trench | from 2026-11-25 | after Lay the new pipe
#     ```
#
# `start` is the day that the work starts. A task that waits for nothing
# starts then. `days: every day` counts Saturday and Sunday as working days.
# Without it, a task is done on weekdays only.
#
# Each line under those is for one task, by its name: the text of its to-do
# item. After the name it says how many working days the task takes, the first
# day that it can start, and each task that it waits for. A task with no line
# takes one day and waits for nothing.
#
# A task starts on the first working day after every task that it waits for
# is finished, and no sooner than the day its `from` gives.
#
# A task whose item says how often it repeats, as `- [ ] Water the plants
# every 2 days` does, runs again and again after its first run. repeats.jl
# reads those words. Each run takes as many days as the first. A limit after
# them, as in `every day for 3 days`, says how many runs it has in all.
#
# Each run, or time, of a task that repeats is like a task of its own: another
# task can wait for it, and it can wait for another task. The lines call the
# second time of a task `time 2 of` and its name, as in `Cut the joints | after
# time 2 of Water the slab every day for 3 days`. A task that waits for a task
# that repeats with a limit, by its name alone, waits for its last time. Each
# time starts after the time before it is finished, so a time that waits for
# another task moves the times after it too.
#
# This file reads and writes those lines, finds the page's to-do items, and
# works out the days of each task. It draws nothing.

@use Dates: Dates, Date, Day, dayofweek
@use "./markdown" Kind Line classify spans isdone
@use "./repeats" => Repeats

"The language of a code block that is a schedule"
const SCHEDULE = "schedule"

"What the block says of one task"
mutable struct Entry
  name::String                 # the text of the task's to-do item
  days::Int                    # how many working days it takes
  from::Union{Nothing,Date}    # the first day that it can start, or nothing
  after::Vector{String}        # the names of the tasks that it waits for
  other::Vector{String}        # what its line says that this file doesn't know, kept as it is
  place::Int                   # the place of its task among the page's tasks when the days were last worked out, or 0. It isn't written.
end

Entry(name::AbstractString) = Entry(String(name), 1, nothing, String[], String[], 0)

"True when `e` says no more than a task with no line: one day, any day, after nothing"
plain(e::Entry) = e.days == 1 && e.from === nothing && isempty(e.after) && isempty(e.other)

mutable struct Schedule
  start::Union{Nothing,Date}   # the day the work starts, or nothing until it's set
  weekends::Bool               # true when Saturday and Sunday are working days
  other::Vector{String}        # the lines at the top that this file doesn't know, kept as they are
  entries::Vector{Entry}
  count::Int                   # how many tasks the page had when the days were last worked out, or 0. It isn't written.
end

Schedule(start, weekends, other, entries) = Schedule(start, weekends, other, entries, 0)
Schedule() = Schedule(nothing, false, String[], Entry[])

# --- days --------------------------------------------------------------------------

const MONTHS = ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")

"The date `y`-`m`-`d`, or nothing when there's no such day"
day(y, m, d) = Dates.validargs(Date, y, m, d) === nothing ? Date(y, m, d) : nothing

"""
The day that `text` names, or nothing when it names none. It reads 2026-11-16,
16 Nov 2026, 16 Nov, 16/11/2026 and 16/11. A day with no year is in the year
of `today`.
"""
date(text::AbstractString; today::Date=Dates.today()) = begin
  s = lowercase(strip(text))
  s == "today" && return today
  m = match(r"^(\d{4})-(\d{1,2})-(\d{1,2})$", s)
  m === nothing || return day(parse(Int, m[1]), parse(Int, m[2]), parse(Int, m[3]))
  year(y) = y === nothing ? Dates.year(today) : (n = parse(Int, y); n < 100 ? 2000 + n : n)
  m = match(r"^(\d{1,2})\s*([a-z]{3})[a-z]*\.?,?(?:\s+(\d{4}))?$", s)
  if m !== nothing
    month = findfirst(==(m[2]), MONTHS)
    return month === nothing ? nothing : day(year(m[3]), month, parse(Int, m[1]))
  end
  m = match(r"^(\d{1,2})/(\d{1,2})(?:/(\d{2}|\d{4}))?$", s)
  m === nothing ? nothing : day(year(m[3]), parse(Int, m[2]), parse(Int, m[1]))
end

"True when work is done on `d`"
works(d::Date, weekends::Bool) = weekends || dayofweek(d) <= 5

"`d`, or the first working day after it when no work is done on `d`"
workday(d::Date, weekends::Bool) = begin
  while !works(d, weekends)
    d += Day(1)
  end
  d
end

"The working day that's `n` working days after the working day `d`"
add(d::Date, n::Int, weekends::Bool) = begin
  for _ in 1:n
    d = workday(d + Day(1), weekends)
  end
  d
end

"How many working days there are from `a` to `b`, with both. It's 0 when `b` is before `a`."
span(a::Date, b::Date, weekends::Bool) = count(d -> works(d, weekends), a:Day(1):b)

"A number of days in words: 1 day, 3 days"
days_text(n::Integer) = n == 1 ? "1 day" : "$n days"

"A day as a schedule shows it: Mon 16 Nov"
short(d::Date) = "$(Dates.dayabbr(d)) $(Dates.day(d)) $(Dates.monthabbr(d))"

"A day with its year: 16 Nov 2026"
long(d::Date) = "$(Dates.day(d)) $(Dates.monthabbr(d)) $(Dates.year(d))"

# --- reading and writing -----------------------------------------------------------

"The parts of `line` between its | marks. A \\| is a | in a part's text."
cells(line::AbstractString) = begin
  out, part, escaped = String[], IOBuffer(), false
  for c in line
    if escaped
      c == '|' || write(part, '\\')
      write(part, c)
      escaped = false
    elseif c == '\\'
      escaped = true
    elseif c == '|'
      push!(out, String(strip(String(take!(part)))))
    else
      write(part, c)
    end
  end
  escaped && write(part, '\\')
  push!(out, String(strip(String(take!(part)))))
  out
end

"`name` as it's written in a line: each | in it has a \\ before it"
barred(name::AbstractString) = replace(name, "|" => "\\|")

"Read a schedule from the lines of its block"
schedule(lines) = begin
  s = Schedule()
  for line in lines
    isempty(strip(line)) && continue
    parts = cells(line)
    if length(parts) == 1
      # A line with no | is one of the lines at the top
      m = match(r"^\s*(\w+)\s*:\s*(.*?)\s*$", line)
      key, value = m === nothing ? ("", "") : (lowercase(m[1]), lowercase(m[2]))
      d = key == "start" ? date(value) : nothing
      if d !== nothing
        s.start = d
      elseif key == "days" && (startswith(value, "every") || startswith(value, "all") || startswith(value, "week"))
        s.weekends = !startswith(value, "week")
      else
        push!(s.other, String(line))
      end
      continue
    end
    isempty(parts[1]) && continue
    e = Entry(parts[1])
    for part in parts[2:end]
      isempty(part) && continue
      m = match(r"^(\d+)\s*(?:d|day|days)$"i, part)
      if m !== nothing
        e.days = max(1, parse(Int, m[1]))
        continue
      end
      m = match(r"^from\s+(.+)$"i, part)
      d = m === nothing ? nothing : date(m[1])
      if d !== nothing
        e.from = d
        continue
      end
      m = match(r"^after\s+(.+)$"i, part)
      m === nothing ? push!(e.other, part) : push!(e.after, String(strip(m[1])))
    end
    push!(s.entries, e)
  end
  s
end

"The lines of the block that say what `s` holds. A task that takes one day and waits for nothing has no line."
written(s::Schedule) = begin
  lines = String[]
  s.start === nothing || push!(lines, "start: $(s.start)")
  s.weekends && push!(lines, "days: every day")
  append!(lines, s.other)
  tasks = filter(!plain, s.entries)
  isempty(tasks) || isempty(lines) || push!(lines, "")
  for e in tasks
    parts = [barred(e.name)]
    e.days == 1 || push!(parts, days_text(e.days))
    e.from === nothing || push!(parts, "from $(e.from)")
    append!(parts, ["after " * barred(a) for a in e.after])
    append!(parts, e.other)
    push!(lines, join(parts, " | "))
  end
  lines
end

# --- the page's tasks ----------------------------------------------------------------

"A to-do item of the page"
struct Todo
  line::Int       # the line of the page that it's on
  name::String    # its text as it reads, without the marks of bold and the like
  key::String     # what a schedule calls it: its name, or its name and " #2" for the second task of that name
  level::Int      # how many spaces indent it
  done::Bool
end

"""
The to-do items among `lines`, from the top. `kinds` says what each line is,
as `classify` gives it. An item with no text yet is left out.
"""
todos(lines, kinds=classify(lines)) = begin
  out, seen = Todo[], Dict{String,Int}()
  for (i, l) in enumerate(kinds)
    l.kind == Kind.todo || continue
    text = String(chop(lines[i], head=l.prefix, tail=0))
    name = String(strip(join(s.text for s in spans(text) if !s.markup && !s.comment)))
    isempty(name) && continue
    n = seen[name] = get(seen, name, 0) + 1
    push!(out, Todo(i, name, n == 1 ? name : "$name #$n", l.level, isdone(lines[i])))
  end
  out
end

"How alike two names are, from 0 to 1: the share of the longer one's letters that both have, in the same order"
alike(a::AbstractString, b::AbstractString) = begin
  x, y = collect(lowercase(a)), collect(lowercase(b))
  (isempty(x) || isempty(y)) && return 0.0
  # The longest run of letters that's in both, not always side by side
  row = zeros(Int, length(y) + 1)
  for c in x
    before = 0
    for (j, d) in enumerate(y)
      kept = row[j+1]
      row[j+1] = c == d ? before + 1 : max(row[j+1], row[j])
      before = kept
    end
  end
  row[end] / max(length(x), length(y))
end

const ALIKE = 0.5   # two names that are this much alike are one task that was renamed

"""
The name that a schedule's lines give the `k`th time of the task called `key`,
when a link goes to or from that time: `time 2 of Water the slab every day`
"""
time_name(key::AbstractString, k::Integer) = "time $k of $key"

"The name of the task and the number of the time that `name` says, like `time 2 of Water the slab`, or nothing"
time_of(name::AbstractString) = begin
  m = match(r"^time\s+(\d+)\s+of\s+(.+)$"i, name)
  m === nothing ? nothing : (String(m[2]), parse(Int, m[1]))
end

"The task's name in the name `name`: the task that a time like `time 2 of Dig` is of, when `name` isn't one of `names` itself"
task_of(name::AbstractString, names) = (name in names || (t = time_of(name)) === nothing) ? String(name) : t[1]

"`name` with the task's name `old` in it made `new`: `name` itself, or a time of it, like `time 2 of` `old`"
renamed(name::AbstractString, old::AbstractString, new::AbstractString) = begin
  name == old && return String(new)
  t = time_of(name)
  t !== nothing && t[1] == old ? time_name(new, t[2]) : String(name)
end

"Give the task that's called `old` the name `new`, in its own lines and in the lines of the tasks that wait for it"
rename!(s::Schedule, old::AbstractString, new::AbstractString) = begin
  for e in s.entries
    e.name = renamed(e.name, old, new)
    e.after = [renamed(a, old, new) for a in e.after]
  end
  s
end

"""
Make the names in `s` follow the page's to-do items. A line of the schedule
whose name is no item's is for an item that was renamed. That item is the one
at the line's old place in the page, when the page has as many items as it had
and that one has no line. If not, it's the item with no line whose name is
most like the line's, when it's enough like it. The line, and the tasks that
wait for it, take the new name.
"""
match!(s::Schedule, items) = begin
  names = Set(t.key for t in items)
  # The line of a time, like `time 2 of Dig`, is for the task that it's a time of
  of(e) = task_of(e.name, names)
  has = Set(of(e) for e in s.entries)
  spare = [t.key for t in items if !(t.key in has)]
  take!(old, key) = (rename!(s, old, key); filter!(!=(key), spare))
  if s.count == length(items)
    for e in [e for e in s.entries if !(e.name in names) && of(e) == e.name]
      1 <= e.place <= length(items) && items[e.place].key in spare && take!(e.name, items[e.place].key)
    end
  end
  for old in unique([of(e) for e in s.entries if !(of(e) in names)])
    isempty(spare) && break
    scores = [alike(old, key) for key in spare]
    best = argmax(scores)
    scores[best] >= ALIKE && take!(old, spare[best])
  end
  s
end

"Take out of `s` the lines of tasks that the page no longer has, and what the other lines say of them"
prune!(s::Schedule, items) = begin
  names = Set(t.key for t in items)
  filter!(e -> task_of(e.name, names) in names, s.entries)
  foreach(e -> filter!(a -> task_of(a, names) in names, e.after), s.entries)
  s
end

# --- the days of each task ---------------------------------------------------------

"A task with its days worked out"
mutable struct Planned
  todo::Todo
  entry::Union{Nothing,Entry}   # its line of the schedule, or nothing when it has none
  days::Int
  from::Union{Nothing,Date}
  after::Vector{Int}            # the places, in the list of tasks, of the tasks that it waits for
  start::Date                   # its first day
  finish::Date                  # its last day
  # For a task that repeats:
  after_time::Vector{Int}       # for each task in `after`, the time of it that this one waits for, or 0 for the task as a whole
  times::Union{Nothing,Int}     # how many times it's done in all, when its item says, or nothing
  runs::Vector{Tuple{Date,Date}}   # the first and the last day of each time after the first that's worked out
  due::Int                      # which of the days that its item's words give the last of `runs` was due on, or 0
  waits::Dict{Int,Vector{Tuple{Int,Int}}}   # for a time after the first, the tasks that it waits for, and the time of each
  lines::Dict{Int,Entry}        # the lines of the schedule for the times after the first, by number
end

Planned(todo, entry, days, from, after, start, finish) =
  Planned(todo, entry, days, from, after, start, finish, zeros(Int, length(after)), nothing, Tuple{Date,Date}[], 0,
          Dict{Int,Vector{Tuple{Int,Int}}}(), Dict{Int,Entry}())

"""
Which task, and which time of it, the name `ref` in a line is: the place of the
task in `place`, and the number of the time, or 0 for the task as a whole. It's
nothing when there's no such task.
"""
part(ref::AbstractString, place) = begin
  i = get(place, ref, nothing)
  i === nothing || return (i, 0)
  t = time_of(ref)
  t === nothing && return nothing
  i = get(place, t[1], nothing)
  i === nothing || t[2] < 1 ? nothing : (i, t[2])
end

"""
The page's tasks, in the order of the page, each with the days that `s` gives
it. `today` is the day that the work starts when `s` doesn't say.
"""
plan!(s::Schedule, items; today::Date=Dates.today()) = begin
  match!(s, items)
  entries = Dict{String,Entry}()
  foreach(e -> get!(entries, e.name, e), s.entries)
  place = Dict(t.key => i for (i, t) in enumerate(items))
  # Each line remembers where its task is in the page, to find the task again when its name changes
  foreach(e -> e.place = get(entries, e.name, nothing) === e ? get(place, e.name, 0) : 0, s.entries)
  s.count = length(items)
  waits(e, i) = unique!(Tuple{Int,Int}[p for p in (part(a, place) for a in e.after) if p !== nothing && p[1] != i])
  tasks = map(enumerate(items)) do (i, t)
    e = get(entries, t.key, nothing)
    e === nothing && return Planned(t, nothing, 1, nothing, Int[], today, today)
    ps = waits(e, i)
    p = Planned(t, e, e.days, e.from, first.(ps), today, today)
    p.after_time = last.(ps)
    p
  end
  # The lines of the times after the first of a task that repeats
  for e in s.entries
    haskey(place, e.name) && continue
    t = time_of(e.name)
    (t === nothing || t[2] < 2 || !haskey(place, t[1])) && continue
    i = place[t[1]]
    haskey(tasks[i].lines, t[2]) && continue
    tasks[i].lines[t[2]] = e
    tasks[i].waits[t[2]] = waits(e, i)
  end
  settle!(tasks, origin(s, today), s.weekends)
end

"The day that the work starts"
origin(s::Schedule, today::Date=Dates.today()) = something(s.start, today)

"""
Work out the first and the last day of each task. A task starts on `origin`,
or on its own `from`, and after every task that it waits for. A task that
repeats has its times after the first worked out too: each of those that has
a line, and every one when its item says how many. A link that would make a
task wait for itself, through other tasks, is left out.
"""
settle!(tasks::Vector{Planned}, origin::Date, weekends::Bool) = begin
  state = Dict{Tuple{Int,Int},Int8}()   # for a time of a task: 1 while it's being worked out, 2 once it is
  # The last day of the time `k` of task `i`, or of the whole task when `k` is 0. Nothing when it must wait for itself.
  ends(i, k) = begin
    visit(i, 1) || return nothing
    t = tasks[i]
    k = repeats(t.todo) === nothing ? 1 : k == 0 ? something(t.times, 1) : k
    t.times === nothing || k <= t.times || return nothing
    visit(i, k) || return nothing
    k == 1 ? t.finish : t.runs[k-1][2]
  end
  # Work out the time `k` of task `i`, and the times before it. False when it must wait for itself.
  visit(i, k) = begin
    get(state, (i, k), 0) == 2 && return true
    t = tasks[i]
    if k == 1
      get(state, (i, 1), 0) == 1 && return false
      state[(i, 1)] = 1
      start = something(t.from, origin)
      kept = Tuple{Int,Int}[]
      for (j, r) in zip(t.after, t.after_time)
        d = ends(j, r)
        d === nothing && continue
        push!(kept, (j, r))
        start = max(start, d + Day(1))
      end
      t.after, t.after_time = first.(kept), last.(kept)
      t.start = workday(start, weekends)
      t.finish = add(t.start, t.days - 1, weekends)
      empty!(t.runs)
      t.due = 0
      t.times = repeats(t.todo) === nothing ? nothing : Repeats.times(t.todo.name, t.start)
      state[(i, 1)] = 2
      return true
    end
    visit(i, 1) || return false
    next = repeats(t.todo)
    next === nothing && return false
    while length(t.runs) + 1 < k
      m = length(t.runs) + 2
      get(state, (i, m), 0) == 1 && return false
      state[(i, m)] = 1
      # Due on the first of the item's days that's after the time before it is finished
      finish = isempty(t.runs) ? t.finish : t.runs[end][2]
      u, start = t.due, finish
      while start <= finish && u < t.due + 100_000
        u += 1
        start = workday(next(t.start, u), weekends)
      end
      kept = Tuple{Int,Int}[]
      for (j, r) in get(t.waits, m, Tuple{Int,Int}[])
        d = ends(j, r)
        d === nothing && continue
        push!(kept, (j, r))
        start = max(start, d + Day(1))
      end
      haskey(t.waits, m) && (t.waits[m] = kept)
      start = workday(start, weekends)
      push!(t.runs, (start, add(start, t.days - 1, weekends)))
      t.due = u
      state[(i, m)] = 2
    end
    true
  end
  for (i, t) in enumerate(tasks)
    visit(i, 1)
    repeats(t.todo) === nothing && continue
    # Every time when the item says how many, or else as many as the lines go to
    visit(i, t.times === nothing ? maximum(keys(t.lines), init=1) : t.times)
  end
  tasks
end

# --- a task that repeats -------------------------------------------------------------

"""
How often the task of the to-do item `t` repeats: a function that gives the
`k`th day after a first day, as `rule` of repeats.jl gives it, or nothing. A
ticked item doesn't repeat, because its tick added the next item under it.
"""
repeats(t::Todo) = t.done ? nothing : Repeats.rule(t.name)

"""
The first and the last day of each run of the task `t` after its first run,
up to the run that starts after `last`. The `k`th run is due on the `k`th day
that the item's words give after the task's first day. A run that's due on a
day with no work starts on the next working day. A run that would start before
the run before it is finished is left out, as two runs of `every day` that are
due on a Saturday and a Sunday are. An item with a limit, like `every day
for 3 days`, has as many runs in all as `times` of repeats.jl gives from the
task's first day, counting the first, so a run that's left out doesn't count.
There are `most` runs at the most.
"""
runs(t::Planned, last::Date, weekends::Bool; most::Int=1000) = begin
  out = Tuple{Date,Date}[]
  next = repeats(t.todo)
  next === nothing && return out
  # The times that `plan!` worked out, then the ones after them
  for r in t.runs
    (r[1] > last || length(out) >= most) && return out
    push!(out, r)
  end
  left = something(t.times, typemax(Int)) - 1 - length(t.runs)
  finish = isempty(t.runs) ? t.finish : t.runs[end][2]
  u = t.due
  while left > 0 && length(out) < most && u < t.due + 100_000
    u += 1
    start = workday(next(t.start, u), weekends)
    start > last && break
    start > finish || continue
    finish = add(start, t.days - 1, weekends)
    push!(out, (start, finish))
    left -= 1
  end
  out
end

"The first and the last day of the time `k` of the task `t`: its first time when `k` is 1. Nothing when it has no such time."
time_days(t::Planned, k::Int, weekends::Bool) = begin
  k == 1 && return (t.start, t.finish)
  k < 1 && return nothing
  rs = k - 1 <= length(t.runs) ? t.runs : runs(t, typemax(Date), weekends; most=k - 1)
  length(rs) >= k - 1 ? rs[k-1] : nothing
end

"""
The number of the time of the task `t` that the time `k` is, as a link writes
it: 0 when it's the task as a whole. That's its last time when its item says
how many, its first time when it repeats for ever, and any time when it doesn't repeat.
"""
whole(t::Planned, k::Int) = repeats(t.todo) === nothing || k == something(t.times, 1) ? 0 : k

"The number of the bar of the task `t` that its time `r` is, when `r` is 0 for the task as a whole: its last time, or its first"
bar_of(t::Planned, r::Int) = repeats(t.todo) === nothing ? 1 : r == 0 ? something(t.times, 1) : r

"""
Each link between the tasks `tasks`: the place of the task that's waited for,
the time of it as the line writes it (0 for the whole task), the place of the
task that waits, and the time of it that waits (1 for the first).
"""
links(tasks::Vector{Planned}) = begin
  out = NTuple{4,Int}[]
  for (b, t) in enumerate(tasks)
    append!(out, [(a, r, b, 1) for (a, r) in zip(t.after, t.after_time)])
    for k in sort!(collect(keys(t.waits))), (a, r) in t.waits[k]
      push!(out, (a, r, b, k))
    end
  end
  out
end

"""
The last day of the last run of the task `t`, when its item repeats with a
limit like `every day for 3 days`, or nothing when it repeats for ever or not at all.
"""
last_day(t::Planned, weekends::Bool) = begin
  (repeats(t.todo) === nothing || t.times === nothing) && return nothing
  time_days(t, t.times, weekends)[2]
end

"True when the task `t` runs on the day `d`: in its first run, or in a run after it"
running(t::Planned, d::Date, weekends::Bool) = t.start <= d <= t.finish || any(r -> r[1] <= d <= r[2], runs(t, d, weekends))

# --- changing it -------------------------------------------------------------------
#
# Each of these changes the schedule `s`. The days of the tasks are worked out
# again with `plan!`.

"The line of the schedule for task `t`. A task with none gets one."
entry!(s::Schedule, t::Planned) = begin
  t.entry === nothing || return t.entry
  t.entry = Entry(t.todo.key)
  push!(s.entries, t.entry)
  t.entry
end

"The line of the schedule for the time `k` of task `t`: its own line when `k` is 1. A time with none gets one."
entry!(s::Schedule, t::Planned, k::Int) = begin
  k <= 1 && return entry!(s, t)
  haskey(t.lines, k) && return t.lines[k]
  e = t.lines[k] = Entry(time_name(t.todo.key, k))
  push!(s.entries, e)
  e
end

"Make task `t` take `n` working days"
days!(s::Schedule, t::Planned, n::Integer) = (entry!(s, t).days = max(1, Int(n)); s)

"""
Start task `t` on `d`, or on the first working day after it. A day that's no
later than the task would start anyway takes its `from` away, so the task
starts as soon as the tasks that it waits for are finished.
"""
move!(s::Schedule, tasks::Vector{Planned}, t::Planned, d::Date; today::Date=Dates.today()) = begin
  d = workday(d, s.weekends)
  ready = isempty(t.after) ? nothing :
    workday(maximum(time_days(tasks[j], bar_of(tasks[j], r), s.weekends)[2] for (j, r) in zip(t.after, t.after_time)) + Day(1), s.weekends)
  free = ready === nothing ? d == workday(origin(s, today), s.weekends) : d <= ready
  (free && t.entry === nothing) || (entry!(s, t).from = free ? nothing : d)
  s
end

"""
True when the time `k` of task `a` waits for the time `m` of task `b`, or for
a task that waits for it. A time waits for the times of its task before it.
"""
waits(tasks::Vector{Planned}, a::Int, k::Int, b::Int, m::Int, seen=Set{Tuple{Int,Int}}()) = begin
  (a, k) in seen && return false
  push!(seen, (a, k))
  a == b && k >= m && return true
  t = tasks[a]
  waited = k == 1 ? zip(t.after, t.after_time) : get(t.waits, k, Tuple{Int,Int}[])
  any(((j, r),) -> waits(tasks, j, bar_of(tasks[j], r), b, m, seen), waited) ||
    (k > 1 && waits(tasks, a, k - 1, b, m, seen))
end

"True when task `a` waits for task `b`, or for a task that waits for it"
waits(tasks::Vector{Planned}, a::Int, b::Int) = waits(tasks, a, bar_of(tasks[a], 0), b, 1)

"""
Make the time `to` of task `b` wait for the time `from` of task `a`: 0 is task
`a` as a whole, and 1 is the first time of `b`. It says what happened: `:ok`,
`:same` when they're one task, `:there` when it waits for it already, or
`:loop` when `a` waits for `b`, so that neither could start.
"""
link!(s::Schedule, tasks::Vector{Planned}, a::Int, b::Int; from::Int=0, to::Int=1) = begin
  a == b && return :same
  waited = to <= 1 ? collect(zip(tasks[b].after, tasks[b].after_time)) : get(tasks[b].waits, to, Tuple{Int,Int}[])
  (a, from) in waited && return :there
  waits(tasks, a, bar_of(tasks[a], from), b, max(to, 1)) && return :loop
  key = tasks[a].todo.key
  push!(entry!(s, tasks[b], to).after, from == 0 ? key : time_name(key, from))
  :ok
end

"Make the time `to` of task `b` wait for the time `from` of task `a` no more"
unlink!(s::Schedule, tasks::Vector{Planned}, a::Int, b::Int; from::Int=0, to::Int=1) = begin
  e = to <= 1 ? tasks[b].entry : get(tasks[b].lines, to, nothing)
  place = Dict(t.todo.key => i for (i, t) in enumerate(tasks))
  e === nothing || filter!(x -> part(x, place) != (a, from), e.after)
  s
end

export SCHEDULE, Schedule, Entry, Todo, Planned
