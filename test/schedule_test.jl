# Tests for schedule.jl. Run them with `julia -O0 --project=. test/schedule_test.jl`.

@use Test: @test, @testset
@use Dates: Date, Day
@use "../schedule" => S

# 16 November 2026 is a Monday
const MON = Date(2026, 11, 16)

const PAGE = ["# A job", "",
              "- [x] Dig the trench",
              "- [ ] Lay the **new** pipe",
              "  - [ ] Test the pipe",
              "- [ ] Fill the trench",
              "- [ ] ",
              "```",
              "- [ ] Not a task",
              "```",
              "- [ ] Test the pipe"]

const BLOCK = ["start: 2026-11-16", "colour: red", "",
               "Dig the trench | 3 days",
               "Lay the new pipe | 2d | after Dig the trench",
               "Fill the trench | from 2026-11-30 | after Lay the new pipe | after Test the pipe | crew of 2"]

@testset "days" begin
  @test S.date("2026-11-16") == MON && S.date("16 Nov 2026") == MON && S.date("16/11/2026") == MON && S.date("16/11/26") == MON
  @test S.date("16 November", today=Date(2026, 3, 1)) == MON && S.date("16/11", today=Date(2026, 3, 1)) == MON
  @test S.date("today", today=MON) == MON
  @test S.date("31 Feb 2026") === nothing && S.date("soon") === nothing && S.date("") === nothing
  @test S.workday(MON + Day(5), false) == MON + Day(7) && S.workday(MON + Day(5), true) == MON + Day(5)
  # Three working days after a Thursday is the next Tuesday
  @test S.add(MON + Day(3), 3, false) == MON + Day(8) && S.add(MON + Day(3), 3, true) == MON + Day(6)
  @test S.span(MON, MON + Day(7), false) == 6 && S.span(MON, MON + Day(7), true) == 8 && S.span(MON, MON - Day(1), false) == 0
  @test S.short(MON) == "Mon 16 Nov" && S.long(MON) == "16 Nov 2026"
  @test S.days_text(1) == "1 day" && S.days_text(4) == "4 days"
end

@testset "reading and writing" begin
  s = S.schedule(BLOCK)
  @test s.start == MON && !s.weekends && s.other == ["colour: red"]
  @test [e.name for e in s.entries] == ["Dig the trench", "Lay the new pipe", "Fill the trench"]
  @test [e.days for e in s.entries] == [3, 2, 1]
  @test s.entries[3].from == Date(2026, 11, 30) && s.entries[3].after == ["Lay the new pipe", "Test the pipe"]
  @test s.entries[3].other == ["crew of 2"]
  # What's written reads as the same schedule
  lines = S.written(s)
  @test lines[1:3] == BLOCK[1:3] && lines[4] == BLOCK[4]
  @test lines[5] == "Lay the new pipe | 2 days | after Dig the trench"
  @test S.written(S.schedule(lines)) == lines
  # A task that takes a day and waits for nothing has no line
  push!(s.entries, S.Entry("Tidy up"))
  @test S.written(s) == lines
  @test S.written(S.Schedule()) == String[]
  @test S.schedule(["days: every day"]).weekends && S.written(S.schedule(["days: every day"])) == ["days: every day"]
  @test !S.schedule(["days: weekdays"]).weekends
  # A | in a name has a \ before it
  e = only(S.schedule(["Cut \\| fit the pipe | 2 days | after A \\| B"]).entries)
  @test e.name == "Cut | fit the pipe" && e.after == ["A | B"]
  @test S.written(S.Schedule(nothing, false, String[], [e])) == ["Cut \\| fit the pipe | 2 days | after A \\| B"]
end

@testset "the page's tasks" begin
  ts = S.todos(PAGE)
  @test [t.name for t in ts] == ["Dig the trench", "Lay the new pipe", "Test the pipe", "Fill the trench", "Test the pipe"]
  @test [t.key for t in ts] == ["Dig the trench", "Lay the new pipe", "Test the pipe", "Fill the trench", "Test the pipe #2"]
  @test [t.line for t in ts] == [3, 4, 5, 6, 11]
  @test [t.done for t in ts] == [true, false, false, false, false] && ts[3].level == 2
end

@testset "the days of each task" begin
  s = S.schedule(BLOCK)
  ts = S.plan!(s, S.todos(PAGE), today=MON)
  dig, lay, test, fill, again = ts
  @test (dig.start, dig.finish) == (MON, MON + Day(2))
  # Two days after the Wednesday are the Thursday and the Friday
  @test (lay.start, lay.finish) == (MON + Day(3), MON + Day(4)) && lay.after == [1]
  # A task with no line takes a day, and starts when the work does
  @test test.entry === nothing && (test.start, test.finish) == (MON, MON) && again.start == MON
  @test fill.after == [2, 3] && fill.start == Date(2026, 11, 30)
  # Without its own first day, it starts on the Monday after the pipe is laid
  fill.entry.from = nothing
  @test S.plan!(s, S.todos(PAGE), today=MON)[4].start == MON + Day(7)
  # With weekends worked, it starts on the Saturday
  s.weekends = true
  @test S.plan!(s, S.todos(PAGE), today=MON)[4].start == MON + Day(5)
  # With no start, the work starts today, on a working day
  @test S.plan!(S.Schedule(), S.todos(PAGE), today=MON + Day(5))[1].start == MON + Day(7)
  # Two tasks that wait for each other: one of the links is left out
  loop = S.schedule(["Dig the trench | after Fill the trench", "Fill the trench | after Dig the trench"])
  ts = S.plan!(loop, S.todos(PAGE), today=MON)
  @test ts[1].after == [4] && isempty(ts[4].after) && ts[1].start == MON + Day(1)
end

@testset "a task that repeats" begin
  page = ["- [ ] Water the plants every 2 days", "- [ ] Check the site every day", "- [x] Sweep up every day",
          "- [ ] Pay the rent every month", "- [ ] Hose the slab every 2 days"]
  s = S.schedule(["Pay the rent every month | from 2026-11-30", "Hose the slab every 2 days | 2 days"])
  water, check, sweep, rent, hose = S.plan!(s, S.todos(page), today=MON)
  d(n) = MON + Day(n)
  one(ns...) = [(d(n), d(n)) for n in ns]
  # Every two days from Monday 16: the run that's due on Sunday 22 is done on Monday 23, and Saturday 28 on Monday 30
  @test S.runs(water, d(14), false) == one(2, 4, 7, 8, 10, 14)
  @test S.runs(water, d(14), true) == one(2, 4, 6, 8, 10, 12, 14)
  @test S.runs(water, d(1), false) == [] && length(S.runs(water, d(14), false; most=3)) == 3
  # The runs of every day that are due on Saturday and Sunday are one run on Monday
  @test S.runs(check, d(8), false) == one(1, 2, 3, 4, 7, 8)
  # A ticked item doesn't repeat: its tick added the next item
  @test S.repeats(sweep.todo) === nothing && S.runs(sweep, d(14), false) == []
  # A month after 30 December is a Saturday, so that run is on the Monday after
  @test S.runs(rent, Date(2027, 2, 1), false) == [(Date(2026, 12, 30), Date(2026, 12, 30)), (Date(2027, 2, 1), Date(2027, 2, 1))]
  # Each run takes as many working days as the first. One that would start before the run before it is finished is left out.
  @test (hose.start, hose.finish) == (d(0), d(1))
  @test S.runs(hose, d(10), false) == [(d(2), d(3)), (d(4), d(7)), (d(8), d(9)), (d(10), d(11))]
  @test S.running(water, d(0), false) && S.running(water, d(7), false) && !S.running(water, d(5), false) && !S.running(water, d(9), false)
  @test S.running(hose, d(5), false) && !S.running(sweep, d(2), false)
  @test S.last_day(water, false) === nothing && S.last_day(sweep, false) === nothing
end

@testset "a task that repeats for a while" begin
  page = ["- [ ] Water the slab every day for 3 days", "- [ ] Hose it every 2 days for 2 weeks",
          "- [ ] Mop every day 3 times", "- [ ] Dig the trench"]
  s = S.schedule(["Mop every day 3 times | from 2026-11-20"])
  slab, hose, mop, dig = S.plan!(s, S.todos(page), today=MON)
  d(n) = MON + Day(n)
  one(ns...) = [(d(n), d(n)) for n in ns]
  # Three days in all: the first and two more
  @test S.runs(slab, d(30), false) == one(1, 2) && S.last_day(slab, false) == d(2)
  # Seven times in two weeks. The run that's due on Sunday 22 is on Monday 23, and Saturday 28 on Monday 30.
  @test S.runs(hose, d(30), false) == one(2, 4, 7, 8, 10, 14) && S.last_day(hose, false) == d(14)
  every = S.plan!(S.schedule(["days: every day"]), S.todos(page), today=MON)[2]
  @test S.runs(every, d(30), true) == one(2, 4, 6, 8, 10, 12)
  # From a Friday, the runs that are due on Saturday and Sunday are one run on Monday. A run that's left out doesn't count, so there are still three.
  @test (mop.start, S.runs(mop, d(30), false)) == (d(4), one(7, 8)) && S.last_day(mop, false) == d(8)
  @test S.running(slab, d(2), false) && !S.running(slab, d(3), false)
  # A task that doesn't repeat has no last day of its own
  @test S.last_day(dig, false) === nothing
end

@testset "a link to or from one time of a task that repeats" begin
  page = ["- [ ] Pour the slab", "- [ ] Water the slab every day for 3 days", "- [ ] Cut the joints",
          "- [ ] Take the forms off", "- [ ] Book the pump"]
  W = "Water the slab every day for 3 days"
  s = S.schedule(["$W | after Pour the slab", "Cut the joints | after time 2 of $W", "Take the forms off | after $W",
                  "Book the pump | 5 days"])
  plan() = S.plan!(s, S.todos(page), today=MON)
  d(n) = MON + Day(n)
  ts = plan()
  pour, water, cut, forms, pump = ts
  # The joints wait for the second time, and the forms for the last, as the name alone says
  @test (water.start, water.runs) == (d(1), [(d(2), d(2)), (d(3), d(3))])
  @test (cut.start, cut.after, cut.after_time) == (d(3), [2], [2]) && (forms.start, forms.after_time) == (d(4), [0])
  @test S.links(ts) == [(1, 0, 2, 1), (2, 2, 3, 1), (2, 0, 4, 1)]
  @test S.whole(water, 3) == 0 && S.whole(water, 2) == 2 && S.whole(pour, 1) == 0 && S.bar_of(water, 0) == 3
  @test S.time_days(water, 3, false) == (d(3), d(3)) && S.time_days(water, 4, false) === nothing
  # A time can wait for another task. It moves, and the times after it move after it.
  @test S.link!(s, ts, 5, 2; to=2) == :ok
  @test S.written(s)[end] == "time 2 of $W | after Book the pump"
  ts = plan()
  # The pump takes Monday 16 to Friday 20, so the second time is on Monday 23 and the third on Tuesday 24
  @test ts[2].runs == [(d(7), d(7)), (d(8), d(8))] && ts[3].start == d(8) && ts[4].start == d(9)
  @test (5, 0, 2, 2) in S.links(ts)
  # A link that would make a time wait for itself, through other tasks, isn't made
  @test S.link!(s, ts, 3, 2; to=2) == :loop && S.link!(s, ts, 4, 2; to=3) == :loop
  @test S.link!(s, ts, 2, 3; from=3) == :ok && S.link!(s, ts, 5, 2; to=2) == :there && S.link!(s, ts, 2, 2; to=3) == :same
  ts = plan()
  @test ts[3].after == [2, 2] && ts[3].after_time == [2, 3] && ts[3].start == d(9)
  # A link to a time is taken away, and the line of a time that says nothing goes
  S.unlink!(s, ts, 5, 2; to=2)
  S.unlink!(s, ts, 2, 3; from=3)
  @test !any(startswith("time 2"), S.written(s)) && plan()[2].runs == [(d(2), d(2)), (d(3), d(3))]
  # A renamed task's times keep their links
  page[2] = "- [ ] Water the slab each day for 3 days"
  @test S.link!(s, plan(), 5, 2; to=3) == :ok
  page[2] = "- [ ] Water the slab every day for 3 days, gently"
  ts = plan()
  @test "Cut the joints | after time 2 of Water the slab every day for 3 days, gently" in S.written(s)
  # The item doesn't repeat now, so the time lines wait to be needed again, and the task is one bar
  @test isempty(ts[2].runs) && ts[3].start == d(2)
  # A task that the page doesn't have any more takes its times with it
  S.prune!(s, S.todos(page[[1, 3, 4, 5]]))
  @test S.written(s) == ["Book the pump | 5 days"]
end

@testset "a task that was renamed" begin
  s = S.schedule(BLOCK)
  page = replace(PAGE, "- [x] Dig the trench" => "- [x] Dig out the trench")
  ts = S.plan!(s, S.todos(page), today=MON)
  @test ts[1].entry !== nothing && ts[1].days == 3
  @test s.entries[1].name == "Dig out the trench" && s.entries[2].after == ["Dig out the trench"] && ts[2].after == [1]
  # A task with another name altogether is a new task, in a schedule that was just read
  s = S.schedule(BLOCK)
  ts = S.plan!(s, S.todos(replace(PAGE, "- [x] Dig the trench" => "- [x] Order sand")), today=MON)
  @test ts[1].entry === nothing && s.entries[1].name == "Dig the trench"
  # Once the days are worked out, a task that gets a new name in its place keeps its line, whatever the name
  s = S.schedule(BLOCK)
  S.plan!(s, S.todos(PAGE), today=MON)
  ts = S.plan!(s, S.todos(replace(PAGE, "- [x] Dig the trench" => "- [x] Order sand")), today=MON)
  @test ts[1].days == 3 && s.entries[1].name == "Order sand" && ts[2].after == [1]
  # A name that's more like another task's still goes with its own place
  page = replace(PAGE, "- [ ] Lay the **new** pipe" => "- [ ] Lay the new pipe in its bed of sand, and fill the trench")
  ts = S.plan!(s, S.todos(page), today=MON)
  @test ts[2].days == 2 && ts[4].after == [2, 3] && ts[4].from == Date(2026, 11, 30)
  # With a task more or fewer in the page, the places say nothing, and the names do
  s = S.schedule(BLOCK)
  S.plan!(s, S.todos(PAGE), today=MON)
  ts = S.plan!(s, S.todos(vcat(["- [ ] First of all", "- [x] Dig all of the trench"], PAGE[4:end])), today=MON)
  @test ts[1].entry === nothing && ts[2].days == 3
  s = S.schedule(BLOCK)
  ts = S.plan!(s, S.todos(replace(PAGE, "- [x] Dig the trench" => "- [x] Order sand")), today=MON)
  # Its line goes when the schedule is next written
  S.prune!(s, S.todos(replace(PAGE, "- [x] Dig the trench" => "- [x] Order sand")))
  @test [e.name for e in s.entries] == ["Lay the new pipe", "Fill the trench"] && isempty(s.entries[1].after)
  @test S.alike("Dig the trench", "Dig the trench") == 1 && S.alike("abc", "xyz") == 0 && S.alike("", "a") == 0
end

@testset "changing it" begin
  s = S.Schedule()
  plan() = S.plan!(s, S.todos(PAGE), today=MON)
  ts = plan()
  S.days!(s, ts[1], 4)
  @test S.written(s) == ["Dig the trench | 4 days"]
  @test S.link!(s, ts, 1, 2) == :ok
  ts = plan()
  @test ts[2].after == [1] && ts[2].start == MON + Day(4)
  @test S.link!(s, ts, 1, 2) == :there && S.link!(s, ts, 2, 2) == :same && S.link!(s, ts, 2, 1) == :loop
  @test S.link!(s, ts, 2, 4) == :ok
  ts = plan()
  @test S.link!(s, ts, 4, 1) == :loop && S.waits(ts, 4, 1) && !S.waits(ts, 1, 4)
  # A day after the task is ready is kept. A day before it isn't.
  S.move!(s, ts, ts[2], MON + Day(8), today=MON)
  @test s.entries[2].from == MON + Day(8)
  ts = plan()
  @test ts[2].start == MON + Day(8) && ts[4].start == MON + Day(9)
  S.move!(s, ts, ts[2], MON + Day(1), today=MON)
  @test s.entries[2].from === nothing && plan()[2].start == MON + Day(4)
  # A task that waits for nothing starts on the day it's moved to, and a Saturday is the Monday after
  ts = plan()
  S.move!(s, ts, ts[3], MON + Day(12), today=MON)
  @test plan()[3].start == MON + Day(14)
  # Moved back to the day that the work starts, it has nothing to say
  ts = plan()
  S.move!(s, ts, ts[3], MON, today=MON)
  @test ts[3].entry.from === nothing && S.plain(ts[3].entry)
  # A task with no line that's moved to the start gets none
  S.move!(s, ts, ts[5], MON, today=MON)
  @test ts[5].entry === nothing
  S.unlink!(s, ts, 1, 2)
  @test isempty(plan()[2].after)
  @test S.written(s) == ["Dig the trench | 4 days", "Fill the trench | after Lay the new pipe"]
end
