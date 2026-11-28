# Tests for timelog.jl. Run them with `julia -O0 --project=. test/timelog_test.jl`.
# Each one gives the time now itself, so none depends on the clock.

@use Test: @test, @testset
@use "../blocks/timelog" => T
@use Dates: Date, Time, DateTime

const LINES = ["2026-11-17 07:30-12:00 | Framing",
               "2026-11-17 12:30-15:45 | Framing",
               "2026-11-18 08:10- | Roofing"]
const NOW = DateTime(2026, 11, 18, 9, 12, 7)

@testset "reading and writing" begin
  log = T.timelog(LINES)
  @test length(log.rows) == 3 && log.rate === nothing && log.round == 0
  s = log.rows[1]
  @test (s.day, s.from, s.to, s.task) == (Date(2026, 11, 17), Time(7, 30), Time(12), "Framing")
  @test log.rows[3].to === nothing && T.running(log) == 3
  @test T.written(log) == LINES
  # An empty block is an empty log, and stays empty
  @test isempty(T.timelog(String[]).rows) && isempty(T.written(T.timelog(["", "  "])))
  # Times with am and pm are read, and written with 24 hours
  log = T.timelog(["2026-11-17 7:30am - 3:45pm | Framing", "2026-11-17 12am-12pm|Night", "2026-11-17 7-9.15", "2026-1-5 9:05 – 17:00 | A | B"])
  @test T.written(log) == ["2026-11-17 07:30-15:45 | Framing", "2026-11-17 00:00-12:00 | Night", "2026-11-17 07:00-09:15", "2026-01-05 09:05-17:00 | A | B"]
  @test T.time_of("12:15am") == Time(0, 15) && T.time_of("12:15 PM") == Time(12, 15) && T.time_of("23:59") == Time(23, 59)
  @test all(t -> T.time_of(t) === nothing, ["24:00", "7:60", "13pm", "0am", "seven", "", "7:5"])
  # The settings go first, and a blank line parts them from the stretches
  log = T.timelog(["2026-11-17 07:30-12:00 | Framing", "round: 15 minutes", "Rate: \$1,085.50", ""])
  @test log.rate == 1085.5 && log.round == 15
  @test T.written(log) == ["rate: 1085.5", "round: 15", "", "2026-11-17 07:30-12:00 | Framing"]
  @test T.written(T.timelog(["rate: 85"])) == ["rate: 85"]
end

@testset "a line that can't be read" begin
  bad = ["Framing all day", "2026-11-17 07:30 | no dash", "2026-13-40 07:30-08:00 | no such day", "2026-11-17 07:30-25:00 | no such time",
         "rate: lots", "2026-11-17 07:30-08:00-09:00 | two stops"]
  log = T.timelog([bad; "2026-11-17 07:30-08:00 | Good"])
  @test log.rows[1:6] == bad && log.rows[7] isa T.Stretch && log.rate === nothing
  # It's kept as it is, and counts for nothing
  @test T.written(log) == [bad; "2026-11-17 07:30-08:00 | Good"]
  @test all(i -> T.minutes(log, i, NOW) == 0, 1:6) && T.total(log, NOW) == 30
  @test T.tasks(log, NOW) == ["Good" => 30]
  @test T.stretch(log, 1) === nothing && T.stretch(log, 99) === nothing && !T.set!(log, 1, :task, "x")
end

@testset "sums" begin
  log = T.timelog(LINES)
  @test T.minutes(log, 1, NOW) == 270 && T.minutes(log, 2, NOW) == 195
  # The row that runs counts up to the time now
  @test T.seconds(log, 3, NOW) == 3727 && T.minutes(log, 3, NOW) == 62
  @test T.seconds(log, 3, DateTime(2026, 11, 18, 8, 0)) == 0   # a clock that's behind the line doesn't count back
  @test T.total(log, NOW) == 270 + 195 + 62
  @test T.tasks(log, NOW) == ["Framing" => 465, "Roofing" => 62]
  @test T.hours(270) == "4 h 30 min" && T.hours(240) == "4 h" && T.hours(45) == "45 min" && T.hours(0) == "0 min" && T.hours(1565) == "26 h 5 min"
  @test T.elapsed(3727) == "1 h 02 min 07 s" && T.elapsed(127) == "2 min 07 s" && T.elapsed(7) == "7 s"
  @test T.day(Date(2026, 11, 17)) == "Tue 17 Nov" && T.day(Date(2026, 1, 5)) == "Mon 5 Jan"
  # Capital letters don't make another task, and a stretch with no task is a task of its own
  log = T.timelog(["2026-11-17 07:00-08:00 | Framing", "2026-11-17 08:00-08:30 | framing ", "2026-11-17 09:00-09:10"])
  @test T.tasks(log, NOW) == ["Framing" => 90, "" => 10]
  @test T.table(log, NOW) == [["Task", "Hours"], ["Framing", "1.5"], ["No task", "0.17"]]
  # Of two lines with no stop time, the last one runs, and the other counts for nothing
  log = T.timelog(["2026-11-18 07:00- | Old", "2026-11-18 09:00- | New"])
  @test T.running(log) == 2 && T.minutes(log, 1, NOW) == 0 && T.minutes(log, 2, NOW) == 12
end

@testset "past midnight" begin
  log = T.timelog(["2026-11-17 22:00-01:30 | Night pour", "2026-11-17 23:59-00:00 | A minute", "2026-11-17 09:00-09:00 | Nothing"])
  @test T.minutes(log, 1, NOW) == 210 && T.hours(T.minutes(log, 1, NOW)) == "3 h 30 min"
  @test T.minutes(log, 2, NOW) == 1 && T.minutes(log, 3, NOW) == 0
  # A row that started yesterday and still runs counts across midnight too
  log = T.timelog(["2026-11-17 22:00- | Night pour"])
  @test T.minutes(log, 1, DateTime(2026, 11, 18, 1, 30)) == 210
  T.stop!(log, DateTime(2026, 11, 18, 1, 30, 59))
  @test T.written(log) == ["2026-11-17 22:00-01:30 | Night pour"] && T.minutes(log, 1, NOW) == 210
end

@testset "rounding" begin
  log = T.timelog(["round: 15", "2026-11-17 07:00-07:07 | A", "2026-11-17 08:00-08:08 | A", "2026-11-17 09:00-10:22 | B", "2026-11-17 11:00-11:23 | B"])
  @test [T.counted(log, i, NOW) for i in 1:4] == [0, 15, 75, 30]
  @test T.total(log, NOW) == 120 && T.tasks(log, NOW) == ["A" => 15, "B" => 105]
  # The lines keep the true times
  @test [T.minutes(log, i, NOW) for i in 1:4] == [7, 8, 82, 23] && T.written(log)[3] == "2026-11-17 07:00-07:07 | A"
  # Half way goes up
  log = T.timelog(["round: 30", "2026-11-17 07:00-07:15 | A", "2026-11-17 07:00-07:45 | A", "2026-11-17 07:00-07:14 | A"])
  @test [T.counted(log, i, NOW) for i in 1:3] == [30, 60, 0]
  @test T.counted(T.timelog(["round: 0", "2026-11-17 07:00-07:07 | A"]), 1, NOW) == 7
end

@testset "the rate" begin
  log = T.timelog(["rate: 85"; LINES[1:2]; "2026-11-18 07:00-12:15 | Roofing"])
  @test T.total(log, NOW) == 780 && T.money(log, T.total(log, NOW)) == "\$1,105.00"
  @test [T.money(log, m) for (_, m) in T.tasks(log, NOW)] == ["\$658.75", "\$446.25"]
  @test T.money(log, 0) == "\$0.00" && T.money(log, 1) == "\$1.42" && T.money(log, 60 * 20_000) == "\$1,700,000.00"
  @test T.money(T.timelog(LINES), 60) === nothing
  # A rate and a stretch that are far too big still come to something
  log = T.timelog(["rate: 99999999999999999999999999", "0001-01-01 00:00- | Since the year 1"])
  @test startswith(T.money(log, T.total(log, NOW)), "\$9,000,000") && endswith(T.hours(T.total(log, NOW)), " min")
  # The money is for the hours that are added up, so it's rounded with them
  log = T.timelog(["rate: 60", "round: 15", "2026-11-17 07:00-07:08 | A"])
  @test T.money(log, T.total(log, NOW)) == "\$15.00"
end

@testset "starting and stopping the clock" begin
  log = T.timelog(LINES[1:2])
  @test T.running(log) === nothing && !T.stop!(log, NOW)
  # With no task, the new line has the task of the last one. The line keeps the minute, not the second.
  T.start!(log, "  ", NOW)
  @test T.written(log)[3] == "2026-11-18 09:12- | Framing" && T.running(log) == 3
  # Only one line runs: a start stops the one that runs first
  later = DateTime(2026, 11, 18, 10, 30)
  T.start!(log, " Roofing  the  shed ", later)
  @test T.written(log)[3:4] == ["2026-11-18 09:12-10:30 | Framing", "2026-11-18 10:30- | Roofing the shed"] && T.running(log) == 4
  @test T.stop!(log, DateTime(2026, 11, 18, 12, 0, 30)) && T.running(log) === nothing
  @test T.written(log)[4] == "2026-11-18 10:30-12:00 | Roofing the shed"
  # A log with nothing in it starts a line with no task
  log = T.Log()
  T.start!(log, "", NOW)
  @test T.written(log) == ["2026-11-18 09:12-"] && T.last_task(log) == ""
end

@testset "changing a time or a task" begin
  log = T.timelog(LINES)
  @test T.set!(log, 1, :from, "7am") && T.set!(log, 1, :to, "11:45") && T.set!(log, 2, :task, " Cladding ")
  @test T.written(log)[1:2] == ["2026-11-17 07:00-11:45 | Framing", "2026-11-17 12:30-15:45 | Cladding"]
  # A time that can't be read changes nothing
  @test !T.set!(log, 1, :from, "early") && !T.set!(log, 1, :to, "25:00") && T.written(log)[1] == "2026-11-17 07:00-11:45 | Framing"
  # A stop time for the row that runs stops it
  @test T.set!(log, 3, :to, "9:30") && T.running(log) === nothing
  # An empty stop time makes a row run again, but only when no other row runs
  @test T.set!(log, 3, :to, "") && T.running(log) == 3
  @test !T.set!(log, 1, :to, "") && log.rows[1].to == Time(11, 45)
end

@testset "the tasks that a field offers" begin
  log = T.timelog([LINES; "2026-11-18 10:00-11:00 | Roof framing"; "2026-11-18 11:00-12:00 | framing"])
  @test T.offered(log, "") == ["framing", "Roof framing", "Roofing"]
  # The tasks that start with what was typed come first
  @test T.offered(log, "roo") == ["Roof framing", "Roofing"] && T.offered(log, "fram") == ["framing", "Roof framing"]
  # A task that's all of what was typed isn't offered, and nothing is when no task has it
  @test T.offered(log, "Roofing") == String[] && T.offered(log, "FRAMING") == ["Roof framing"] && isempty(T.offered(log, "paint"))
end
