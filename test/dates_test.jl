# Tests for dates.jl: reading a day or time of day from text, in each way that
# blog.jl, calendar.jl, csv.jl, forms.jl, schedule.jl and main.jl read one.
# Run them with `julia -O0 --project=. test/dates_test.jl`.

@use Test: @test, @testset
@use Dates: Date, DateTime
@use "../dates" => D

const TUE = Date(2026, 11, 24)   # a Tuesday

@testset "valid dates and epoch seconds" begin
  @test D.day(2026, 11, 25) == Date(2026, 11, 25)
  @test D.day(2024, 2, 29) == Date(2024, 2, 29)
  @test D.day(2026, 2, 29) === nothing && D.day(2026, 13, 1) === nothing && D.day(2026, 0, 10) === nothing
  @test D.day(match(D.ISO, "2026-11-25")) == Date(2026, 11, 25)
  @test D.day(match(D.ISO, "2026-02-30")) === nothing
  now = time()
  @test D.day(now) == Date(Libc.strftime("%Y-%m-%d", now))
end

@testset "ISO dates, alone and inside text" begin
  @test D.day("2026-11-25"; iso=true) == Date(2026, 11, 25)
  @test D.day(" 2026-3-4 "; iso=true) == Date(2026, 3, 4)
  # Bare numbers, year-only strings, and non-ISO dates are rejected in iso mode
  @test D.day("2026"; iso=true) === nothing && D.day("42"; iso=true) === nothing && D.day("2026-11"; iso=true) === nothing
  @test D.day("25 Nov 2026"; iso=true) === nothing && D.day("25/11/2026"; iso=true) === nothing
  @test D.day("2026-02-30"; iso=true) === nothing && D.day(""; iso=true) === nothing
  # Finding the first valid ISO date inside text
  @test D.day("2026-11-20-hello"; iso=true, anywhere=true) == Date(2026, 11, 20)
  @test D.day("on 2026-13-40 and 2026-02-28"; iso=true, anywhere=true) == Date(2026, 2, 28)
  @test D.day("Job 2026-02-30, then 2026-3-4 and 2026-03-05"; iso=true, anywhere=true) == Date(2026, 3, 4)
  @test D.day("Part 12026-11-250"; iso=true, anywhere=true) === nothing
  @test D.day("no day"; iso=true, anywhere=true) === nothing
end

@testset "numeric dates and day-first against month-first" begin
  @test D.day("2026-11-25") == Date(2026, 11, 25) && D.day("2026/11/25") == Date(2026, 11, 25)
  @test D.day("25/11/2026") == Date(2026, 11, 25) && D.day("25/11/26") == Date(2026, 11, 25)
  @test D.day("25.11.2026") == Date(2026, 11, 25) && D.day("25-11-2026") == Date(2026, 11, 25)
  # Day-first vs month-first
  @test D.day("3/4/2026"; dayfirst=true) == Date(2026, 4, 3)
  @test D.day("3/4/2026"; dayfirst=false) == Date(2026, 3, 4)
  @test D.day("4/23/2026"; dayfirst=false) == Date(2026, 4, 23)
  @test D.day("4/23/2026"; dayfirst=true) === nothing
  @test D.day("3.4.2026"; dayfirst=false) == Date(2026, 3, 4)
  # Version numbers and mixed separators are not dates
  @test D.day("1.2.10") === nothing && D.day("1-2-10") === nothing
  @test D.day("1.2/25") === nothing && D.day("25/11-2026") === nothing && D.day("2026-11/25") === nothing
  @test D.day("31/2/2026") === nothing && D.day("25/11") === nothing
end

@testset "month names, weekdays and ordinals" begin
  @test D.day("25 Nov 2026") == Date(2026, 11, 25)
  @test D.day("25 November 2026") == Date(2026, 11, 25)
  @test D.day("25th Nov. 2026") == Date(2026, 11, 25)
  @test D.day("1 Sept 2026") == Date(2026, 9, 1)
  @test D.day("Wed, 25 Nov 2026") == Date(2026, 11, 25)
  @test D.day("Wednesday 25 Nov 2026") == Date(2026, 11, 25)
  @test D.day("November 25, 2026") == Date(2026, 11, 25)
  @test D.day("Nov 25 2026") == Date(2026, 11, 25)
  @test D.day("Wed, Nov 25th, 2026") == Date(2026, 11, 25)
  @test D.day("16Nov 2026") == Date(2026, 11, 16)
  # Words that only start with three letters of a month, or non-weekday prefixes, are not dates
  @test D.day("16 maybe 2026") === nothing && D.day("3 apples 2026") === nothing
  @test D.day("Paid 25 Nov 2026") === nothing && D.day("About Nov 1, 2026") === nothing
  @test D.day("31 Feb 2026") === nothing && D.day("May 2026") === nothing
end

@testset "days with no year" begin
  # :need refuses them
  @test D.day("16 Nov"; today=TUE, year=:need) === nothing
  @test D.day("16/11"; today=TUE, year=:need) === nothing
  # :same takes the year of today
  @test D.day("16 November"; today=Date(2026, 3, 1), year=:same) == Date(2026, 11, 16)
  @test D.day("16Nov"; today=Date(2026, 3, 1), year=:same) == Date(2026, 11, 16)
  @test D.day("Nov 16"; today=Date(2026, 3, 1), year=:same) == Date(2026, 11, 16)
  @test D.day("16/11"; today=Date(2026, 3, 1), year=:same) == Date(2026, 11, 16)
  @test D.day("16 maybe"; today=TUE, year=:same) === nothing
  @test D.day("29 Feb"; today=TUE, year=:same) === nothing
  @test D.day("29 Feb"; today=Date(2024, 3, 1), year=:same) == Date(2024, 2, 29)
  # :past takes the last such day up to today
  ref = Date(2026, 11, 23)
  @test D.day("1 Nov"; today=ref, year=:past) == Date(2026, 11, 1)
  @test D.day("Nov 1"; today=ref, year=:past) == Date(2026, 11, 1)
  @test D.day("23 Nov"; today=ref, year=:past) == Date(2026, 11, 23)
  @test D.day("25 Dec"; today=ref, year=:past) == Date(2025, 12, 25)
  @test D.day("25/12"; today=ref, year=:past) == Date(2025, 12, 25)
  @test D.day("1/11"; today=ref, year=:past) == Date(2026, 11, 1)
  # Leap day with no year resolves to the last 29 February up to today
  @test D.day("29 Feb"; today=Date(2024, 3, 1), year=:past) == Date(2024, 2, 29)
  @test D.day("29 Feb"; today=Date(2026, 11, 23), year=:past) == Date(2024, 2, 29)
  @test D.day("29 Feb"; today=Date(2024, 1, 15), year=:past) == Date(2020, 2, 29)
  @test D.day("30 Feb"; today=Date(2024, 3, 1), year=:past) === nothing
end

@testset "relative words and shortcuts" begin
  @test D.day("today"; today=TUE, relative=:none) === nothing
  @test D.day("today"; today=TUE, relative=:today) == TUE
  @test D.day("tomorrow"; today=TUE, relative=:today) === nothing
  @test D.day("fri"; today=TUE, relative=:today) === nothing
  @test D.day("3"; today=TUE, relative=:today) === nothing
  @test D.day("today"; today=TUE, relative=:all) == TUE
  @test D.day("tomorrow"; today=TUE, relative=:all) == Date(2026, 11, 25)
  @test D.day("yesterday"; today=TUE, relative=:all) == Date(2026, 11, 23)
  @test D.day("+3"; today=TUE, relative=:all) == Date(2026, 11, 27)
  @test D.day("+0"; today=TUE, relative=:all) == TUE
  @test D.day("24"; today=TUE, relative=:all) == Date(2026, 11, 24)
  @test D.day("3"; today=TUE, relative=:all) == Date(2026, 12, 3)
  @test D.day("31"; today=TUE, relative=:all) == Date(2026, 12, 31)
  @test D.day("32"; today=TUE, relative=:all) === nothing && D.day("0"; today=TUE, relative=:all) === nothing
  @test D.day("fri"; today=TUE, relative=:all) == Date(2026, 11, 27)
  @test D.day("tuesday"; today=TUE, relative=:all) == Date(2026, 12, 1)
  @test D.day("thurs"; today=TUE, relative=:all) == Date(2026, 11, 26)
  @test D.day("soon"; today=TUE, relative=:all) === nothing
end

@testset "day styles" begin
  @test D.style("2026-11-25") == :iso
  @test D.style("25 Nov 2026") == :words && D.style("25 November 2026") == :words
  @test D.style("25/11/2026") == :slashes
  @test D.style("25 Nov") === nothing && D.style("2026-02-30") === nothing && D.style("25 maybe 2026") === nothing
  @test D.style("today") === nothing && D.style("soon") === nothing
end

@testset "days with times of day, and day-first inference" begin
  @test D.when("2026-11-25") == DateTime(2026, 11, 25)
  @test D.when("2026-11-25 22:29") == DateTime(2026, 11, 25, 22, 29)
  @test D.when("2026-11-25T22:29:05.123Z") == DateTime(2026, 11, 25, 22, 29, 5)
  @test D.when("25/11/2026, 10:30 pm") == DateTime(2026, 11, 25, 22, 30)
  @test D.when("25/11/26 12:00 am") == DateTime(2026, 11, 25, 0, 0)
  @test D.when("25/11/26 12:30 pm") == DateTime(2026, 11, 25, 12, 30)
  @test D.when("Wed, 25 Nov 2026 09:05:12 +11:00") == DateTime(2026, 11, 25, 9, 5, 12)
  @test D.when("November 25, 2026 10:30 am AEST") == DateTime(2026, 11, 25, 10, 30)
  @test D.when("3/4/2026 08:15"; dayfirst=true) == DateTime(2026, 4, 3, 8, 15)
  @test D.when("3/4/2026 08:15"; dayfirst=false) == DateTime(2026, 3, 4, 8, 15)
  # Invalid times and non-dates
  @test D.when("2026-11-25 25:00") === nothing && D.when("2026-11-25 13:00 pm") === nothing && D.when("2026-11-25 0:30 am") === nothing
  @test D.when("10:30") === nothing && D.when(" 10:30") === nothing && D.when("1.2.10") === nothing
  @test D.when("25 Nov") === nothing && D.when("today") === nothing
  # Inferring day-first vs month-first across a column of cells
  @test D.dayfirst(["3/4/2026", "5/6/2026"])
  @test D.dayfirst(["3/4/2026", "25/11/2026"])
  @test !D.dayfirst(["3/4/2026", "4/23/2026"])
  @test !D.dayfirst(["4/23/26 10:30", "3/4/26"])
  # A day > 12 first wins even if it comes after a month-first-looking cell, and version numbers are ignored
  @test D.dayfirst(["4/23/2026", "25/11/2026"])
  @test D.dayfirst(["1.20.3", "3/4/2026"])
end
