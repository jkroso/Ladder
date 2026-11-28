# Tests for calendar.jl. Run them with `julia -O0 --project=. test/calendar_test.jl`.

@use Test: @test, @testset
@use Dates: Date
@use "../blocks/calendar" => C
@use "../blocks/schedule" => S

const TODAY = Date(2026, 11, 18)   # the day that counts as today
const PAGE = ["# A job", "",
              "- [x] Dig the trench",
              "- [ ] Lay the **new** pipe",
              "- [ ] Order the tiles (2026-11-25)",
              "- [x] 2026-11-20: book the digger",
              "- [ ] Fill the trench"]
const SCHEDULE = ["start: 2026-11-19", "", "Dig the trench | 3 days", "Lay the new pipe | 2 days | after Dig the trench"]
items(page=PAGE) = S.todos(page)
tasks(page=PAGE, lines=SCHEDULE) = S.plan!(S.schedule(lines), items(page); today=TODAY)
words(list) = [t.words for t in list]

@testset "reading" begin
  c = C.calendar(["month: 2026-12", "colour: red", "", "2026-11-25 | Concrete pour", "2026-11-27|Council | 9 am", "2026-13-45 | No such day", "2026-11-28 |", "month: 2027-01"])
  @test c.month == Date(2026, 12, 1)
  @test [(e.line, e.day, e.words) for e in c.events] == [(4, Date(2026, 11, 25), "Concrete pour"), (5, Date(2026, 11, 27), "Council | 9 am")]
  # An empty block, and lines that can't be read, are a calendar with no month and no events
  @test C.calendar(String[]).month === nothing && isempty(C.calendar(String[]).events)
  @test C.calendar(["month: 2026-13", "month: soon", "| | |", "25 Nov | Pour"]) |> c -> c.month === nothing && isempty(c.events)
end

@testset "the month that shows" begin
  @test C.shown(C.calendar(String[]), today=TODAY) == Date(2026, 11, 1)
  @test C.shown(C.calendar(["month: 2027-02"]), today=TODAY) == Date(2027, 2, 1)
  @test C.title(Date(2026, 11, 1)) == "November 2026"
  # November 2026 starts on a Sunday, so its first week has six days of October
  ws = C.weeks(Date(2026, 11, 1))
  @test length(ws) == 6 && all(w -> length(w) == 7, ws) && ws[1][1] == Date(2026, 10, 26) && ws[1][7] == Date(2026, 11, 1) && ws[end][1] == Date(2026, 11, 30)
  # February 2027 starts on a Monday and has four weeks
  @test length(C.weeks(Date(2027, 2, 1))) == 4 && C.weeks(Date(2027, 2, 1))[1][1] == Date(2027, 2, 1)
  @test length(C.weeks(Date(2026, 12, 1))) == 5
end

@testset "the day in a to-do item's text" begin
  @test C.stamp("Order the tiles 2026-11-25") == Date(2026, 11, 25) && C.stamp("Order the tiles") === nothing
  # A day that there's no such day of isn't one, and the first day counts
  @test C.stamp("Job 2026-02-30, then 2026-3-4 and 2026-03-05") == Date(2026, 3, 4) && C.stamp("Part 12026-11-250") === nothing
  @test C.plain("Order the tiles (2026-11-25)") == "Order the tiles" && C.plain("2026-11-20: book the digger") == "book the digger"
  @test C.plain("Pour on 2026-11-25 at 7 am") == "Pour on at 7 am" && C.plain("Fill the trench") == "Fill the trench"
  @test C.stamp_at("- [ ] Order the tiles (2026-11-25)", Date(2026, 11, 25)) == (23, 33)
  # Letters that take more than one byte come before the day
  @test C.stamp_at("- [ ] Café – 2026-11-25", Date(2026, 11, 25)) == (13, 23)
  # The day of another date in the line isn't the one
  @test C.stamp_at("- [ ] [notes](notes-2026-11-01.md) due 2026-11-25", Date(2026, 11, 25)) == (39, 49)
  @test C.stamp_at("- [ ] Order the tiles", Date(2026, 11, 25)) === nothing
end

@testset "the things of each day" begin
  c = C.calendar(["2026-11-25 | Concrete pour", "2026-11-20 | Skip arrives"])
  days = C.things(c, items(), tasks())
  # A task is on each working day that it runs: three days from Thursday go round the weekend
  dig = [d for (d, list) in days if any(t -> t.kind == :task && t.key == "Dig the trench", list)]
  @test sort(dig) == [Date(2026, 11, 19), Date(2026, 11, 20), Date(2026, 11, 23)]
  @test words(days[Date(2026, 11, 24)]) == ["Lay the new pipe"] && !haskey(days, Date(2026, 11, 21))
  # A day's tasks come first, then its to-do items, then its events
  @test [(t.kind, t.words, t.done) for t in days[Date(2026, 11, 20)]] ==
        [(:task, "Dig the trench", true), (:todo, "book the digger", true), (:event, "Skip arrives", false)]
  @test [(t.kind, t.words, t.line) for t in days[Date(2026, 11, 25)]] == [(:task, "Lay the new pipe", 4), (:todo, "Order the tiles", 5), (:event, "Concrete pour", 1)]
  # An item with a day in its text is on that day only, and an item with no line of the schedule takes the first day
  @test count(t -> t.key == "Order the tiles (2026-11-25)", vcat(values(days)...)) == 1
  @test words(days[Date(2026, 11, 19)]) == ["Dig the trench", "Fill the trench"]
  # Work at the weekend puts a task on Saturday and Sunday too
  every = C.things(c, items(), tasks(PAGE, ["days: every day"; SCHEDULE]), true)
  @test haskey(every, Date(2026, 11, 21)) && words(every[Date(2026, 11, 22)]) == ["Lay the new pipe"]
  # A page with no schedule shows its to-do items that have a day, and the events
  alone = C.things(c, items())
  @test sort(collect(keys(alone))) == [Date(2026, 11, 20), Date(2026, 11, 25)] && words(alone[Date(2026, 11, 25)]) == ["Order the tiles", "Concrete pour"]
  # One task has the same id on each of its days, and two things never share one
  @test C.id(days[Date(2026, 11, 19)][1]) == C.id(days[Date(2026, 11, 20)][1]) && allunique(C.id.(days[Date(2026, 11, 25)]))
end

@testset "more things than a day has room for" begin
  list = collect(1:5)
  @test C.fit(list, 3) == ([1, 2], 3) && C.fit(list[1:3], 3) == ([1, 2, 3], 0) && C.fit(Int[], 3) == (Int[], 0) && C.fit(list, 5) == (list, 0)
end

@testset "writing" begin
  # The month goes at the top, and takes the place of the one that was there
  @test C.turned(String[], Date(2026, 12, 1)) == ["month: 2026-12"]
  @test C.turned(["2026-11-25 | Pour"], Date(2026, 12, 1)) == ["month: 2026-12", "", "2026-11-25 | Pour"]
  @test C.turned(["colour: red", "Month : 2026-11", "2026-11-25 | Pour"], Date(2027, 1, 1)) == ["colour: red", "month: 2027-01", "2026-11-25 | Pour"]
  # With nothing, the month's line goes
  @test C.turned(["month: 2026-12", "", "2026-11-25 | Pour"], nothing) == ["2026-11-25 | Pour"] && isempty(C.turned(["month: 2026-12"], nothing))
  @test C.turned(["2026-11-25 | Pour"], nothing) == ["2026-11-25 | Pour"]
  # An event that moves keeps its words, and the other lines stay
  lines = ["month: 2026-11", "", "2026-11-25 | Pour | 7 am", "  2026-11-27|Council"]
  @test C.moved(lines, 4, Date(2026, 12, 2)) == [lines[1:3]; "  2026-12-02|Council"] && C.moved(lines, 9, Date(2026, 12, 2)) == lines
  @test C.added(String[], Date(2026, 11, 25), " Pour ") == ["2026-11-25 | Pour"]
  @test C.added(["month: 2026-11"], Date(2026, 11, 25), "Pour") == ["month: 2026-11", "", "2026-11-25 | Pour"]
  @test C.added(lines, Date(2026, 11, 30), "Skip") == [lines; "2026-11-30 | Skip"]
  # What's written reads back
  @test C.calendar(C.added(C.turned(String[], Date(2026, 11, 1)), Date(2026, 11, 25), "Pour")) |> c -> c.month == Date(2026, 11, 1) && c.events[1].words == "Pour"
end
