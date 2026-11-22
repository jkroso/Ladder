# Tests for repeats.jl and for to-do items that repeat in a page: a tick of an
# item that ends with words like "every 3 months" adds the next one under it.
# Run them with `julia -O0 --project=. test/repeats_test.jl`.

@use Test: @test, @testset
@use Dates: Date
@use "../repeats" => R
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const today = Date(2026, 11, 22)

@testset "the next item of one that repeats" begin
  next(line) = R.repeated(line; today)
  @test next("- [x] Test the smoke alarms 2026-12-01 every 3 months") == "- [ ] Test the smoke alarms 2027-03-01 every 3 months"
  @test next("- [x] Bins every Monday 2026-11-23") == "- [ ] Bins every Monday 2026-11-30"
  @test next("  * [X] Standup every weekday 2026-11-20.") == "  * [ ] Standup every weekday 2026-11-23."
  @test next("- [x] Rent monthly 2026-11-25") == "- [ ] Rent monthly 2026-12-25"
  @test next("- [x] Rates every 2 weeks 2026-11-20") == "- [ ] Rates every 2 weeks 2026-12-04"
  @test next("- [x] Service the ute yearly 2026-03-01") == "- [ ] Service the ute yearly 2027-03-01"
  @test next("- [x] Pay EVERY FORTNIGHT 2026-11-21") == "- [ ] Pay EVERY FORTNIGHT 2026-12-05"
  # With no day, it repeats from today, and the day goes in front of the words that say how often
  @test next("- [x] Water the plants every week") == "- [ ] Water the plants 2026-11-29 every week"
  # A late one skips the days that it missed
  @test next("- [x] Gutters 2026-01-01 every 2 months") == "- [ ] Gutters 2027-01-01 every 2 months"
  # A month from the 31st is the last day of a shorter month, and each day is worked out from the first
  @test next("- [x] Invoice monthly 2026-01-31") == "- [ ] Invoice monthly 2026-11-30"
  @test R.repeated("- [x] Invoice monthly 2026-01-31"; today=Date(2026, 11, 30)) == "- [ ] Invoice monthly 2026-12-31"
  # Words that say how often only count at the end of the item, or just before its day
  @test next("- [x] Write the daily report") === nothing
  @test next("- [x] Every day counts here, done") === nothing
  # An empty box, a line that isn't a to-do item, and none of the words: nothing
  @test next("- [ ] Water the plants every week") === nothing
  @test next("Water the plants every week") === nothing
  @test next("- [x] Order the tiles 2026-11-25") === nothing
end

@testset "a tick adds the next item, after the items under it, and taking it away takes that away" begin
  lines = ["- [ ] Smoke alarms 2026-12-01 every 3 months", "  - [ ] The hall one", "- [ ] Other"]
  new, z = R.tick(lines, 1, true; today)
  @test z == 2 && new == ["- [x] Smoke alarms 2026-12-01 every 3 months", "  - [ ] The hall one", "- [ ] Smoke alarms 2027-03-01 every 3 months"]
  after = [new; lines[3:end]]
  @test R.tick(after, 1, false; today) == (["- [ ] Smoke alarms 2026-12-01 every 3 months", "  - [ ] The hall one"], 3)
  # An item that was changed after it was added stays
  changed = copy(after); changed[3] *= " (the new ones)"
  @test R.tick(changed, 1, false; today) == (["- [ ] Smoke alarms 2026-12-01 every 3 months"], 1)
  # An item that doesn't repeat only gets its tick
  @test R.tick(["- [ ] Other"], 1, true; today) == (["- [x] Other"], 1)
end

const dir = joinpath(tempdir(), "ladder-repeats-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
@eval K settings_file() = $(joinpath(dir, "settings"))
const page = joinpath(dir, "jobs.md")
const start = """
# Jobs

- [ ] Test the smoke alarms 2026-12-01 every 3 months
- [ ] Order the tiles

The end."""
write(page, start)

@testset "a tick in the page adds the next item, and one ⌘Z takes both back" begin
  K.calendar_day[] = today
  try
    e = K.build_editor(page)
    w = Window(e, size=(800px, 500px))
    foreach(_ -> Base.invokelatest(frame, w), 1:3)
    b = e.buf
    b.caret = b.anchor = (6, 3)
    K.tick!(e, 3)
    @test b.lines[3:5] == ["- [x] Test the smoke alarms 2026-12-01 every 3 months", "- [ ] Test the smoke alarms 2027-03-01 every 3 months", "- [ ] Order the tiles"]
    # The caret stays with its text, a line further down
    @test b.caret == (7, 3)
    K.undo!(b)
    @test join(b.lines, "\n") == start
    # Taking the tick away again takes the added item away
    K.tick!(e, 3)
    K.tick!(e, 3)
    @test join(b.lines, "\n") == start
    # An item that doesn't repeat only gets its tick
    K.tick!(e, 4)
    @test b.lines[4] == "- [x] Order the tiles" && length(b.lines) == 6
    close(w)
  finally
    K.calendar_day[] = nothing
  end
end
