# Tests for day.jl: the line of a `day` block, and how a task stands on a day.
# Run them with `julia -O0 --project=. test/day_test.jl`.

@use Test: @test, @testset
@use Dates: Date, Day
@use "../blocks/day" => D

@testset "the day of a block" begin
  @test D.day(String[]) === nothing && D.day(["", "soon"]) === nothing
  @test D.day(["2026-11-25"]) == Date(2026, 11, 25) && D.day(["day: 2026-1-5 "]) == Date(2026, 1, 5)
  @test D.day(["2026-13-40", "2026-11-26"]) == Date(2026, 11, 26)   # a day that there's no such day of is passed over
  @test D.written(String[], Date(2026, 11, 25)) == ["2026-11-25"]
  @test D.written(["2026-11-25"], nothing) == String[]
  @test D.written(["2026-11-25", "note: the pour"], Date(2026, 12, 1)) == ["2026-12-01", "note: the pour"]
end

@testset "how a task stands on a day" begin
  today = Date(2026, 11, 20)
  start, finish = Date(2026, 11, 23), Date(2026, 11, 25)
  @test D.stands(start, finish, false, today, today) == :todo
  @test D.stands(start, finish, true, today, today) == :done          # today, a tick says so
  @test D.stands(Date(2026, 11, 10), Date(2026, 11, 12), false, today, today) == :doing   # a task that's late isn't done
  @test D.stands(start, finish, false, Date(2026, 11, 24), today) == :doing
  @test D.stands(start, finish, false, Date(2026, 11, 25), today) == :doing
  @test D.stands(start, finish, false, Date(2026, 11, 26), today) == :done
  @test D.stands(start, finish, true, Date(2026, 11, 21), today) == :done     # on a day to come, what's ticked stays done
  # On a day that's past, only the plan says
  @test D.stands(Date(2026, 11, 10), Date(2026, 11, 12), true, Date(2026, 11, 11), today) == :doing
  @test D.stands(Date(2026, 11, 10), Date(2026, 11, 12), true, Date(2026, 11, 9), today) == :todo
end

@testset "the days of a slider" begin
  today = Date(2026, 11, 20)
  days = D.span(Date[], today)
  @test first(days) == Date(2026, 11, 18) && length(days) == 14
  days = D.span([Date(2026, 11, 2), Date(2026, 12, 24)], today, Date(2027, 1, 3))
  @test first(days) == Date(2026, 10, 31) && last(days) == Date(2027, 1, 5)
  @test D.away(today, today) == "today" && D.away(today + Day(1), today) == "tomorrow" && D.away(today - Day(1), today) == "yesterday"
  @test D.away(today + Day(5), today) == "in 5 days" && D.away(today - Day(3), today) == "3 days ago"
end
