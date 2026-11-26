# Tests for a calendar of a folder, in main.jl: a `calendar` block with a line
# like `in: jobs` shows the to-do items of every page of a folder on their
# days. A tick and a new day are written into the item's own page. Run them
# with `julia -O0 --project=. test/calendar_folder_test.jl`. They click and
# drag in a window that isn't on the screen. Set `LADDER_SHOTS` to a folder,
# and they save a picture of the page there.

@use Test: @test, @testset
@use Dates: Dates, Date, Day
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

# Wednesday 18 November 2026 counts as today
K.calendar_day[] = Date(2026, 11, 18)
nov(d) = Date(2026, 11, d)

const dir = realpath(mktempdir())
@eval K settings_file() = $(joinpath(dir, "settings"))
const jobs = joinpath(dir, "jobs")
mkpath(jobs)
const kitchen = joinpath(jobs, "kitchen.md")
const bath = joinpath(jobs, "bath.md")
write(kitchen, "# Kitchen\n\n- [ ] Order the sink 2026-11-20\n- [ ] No day for this one\n")
write(bath, "# Bath\n\n- [ ] Grout é 2026-11-24\n- [x] Order the tiles 2026-11-20\n")
const page = joinpath(dir, "all.md")
write(page, """
# Every job

- [ ] An item of this page 2026-11-19, which the calendar of the folder leaves out

```calendar
month: 2026-11
in: jobs

2026-11-25 | Concrete pour
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1200px))
const (; frames, at, press, release, click, shot) = drive(w)
frames()
const v = e.nodes[(:block, K.CALENDAR, page, 1)]

drag(from, to) = (press(from); at(((from[1] + to[1]) / 2, (from[2] + to[2]) / 2)); at(to); release())
block() = (s = K.block_lines(e.buf, K.CALENDAR, 1); e.buf.lines[s[1]+1:s[2]-1])
cells() = [v.parts[(:day, i)] for i in 1:7v.weeks]
cell(d) = only(c for c in cells() if c.day == d)
chips(d) = (c = cell(d); [v.parts[(:thing, c.i, k)] for k in 1:length(K.day_things(v, d))])
chip(d, words) = only(c for c in chips(d) if c.thing.words == words)
words(d) = [t.words for t in K.day_things(v, d)]
empty(d) = (r = rect(cell(d)); (K.num(r.left + r.width / 2), K.num(r.top + r.height - 6)))

@testset "the block names a folder" begin
  C = K.Calendars
  @test C.folder(["month: 2026-11", "in: jobs"]) == "jobs" && C.folder(["In:  ."]) == "." && C.folder(["in:"]) == "."
  @test C.folder(["month: 2026-11", "2026-11-25 | Check in: the hotel"]) === nothing
  @test K.calendar_folder(v) == jobs
  # The line is no event, and the month and the events read as they did
  @test v.data.month == nov(1) && [ev.words for ev in v.data.events] == ["Concrete pour"]
end

@testset "the calendar shows the items of every page of the folder" begin
  @test words(nov(20)) == ["Order the tiles", "Order the sink"] && words(nov(24)) == ["Grout é"]
  # The page's own items stay out, and its own events stay in
  @test isempty(K.day_things(v, nov(19))) && words(nov(25)) == ["Concrete pour"]
  @test K.item_place(v, "bath: Grout é 2026-11-24").path == bath
  shot("calendar-folder.png")
end

@testset "a tick goes to the item's own page" begin
  click(middle(rect(chip(nov(20), "Order the sink").box)))
  @test readlines(kitchen)[3] == "- [x] Order the sink 2026-11-20"
  frames()
  @test all(t -> t.done, K.day_things(v, nov(20)))
  click(middle(rect(chip(nov(20), "Order the sink").box)))
  @test readlines(kitchen)[3] == "- [ ] Order the sink 2026-11-20"
  # The page of the calendar has no change of its own
  @test !K.dirty(e.buf)
end

@testset "a drag writes the new day in the item's own page" begin
  drag(middle(rect(chip(nov(24), "Grout é"))), empty(nov(26)))
  @test readlines(bath)[3] == "- [ ] Grout é 2026-11-26"
  frames()
  @test words(nov(26)) == ["Grout é"] && isempty(K.day_things(v, nov(24)))
  @test v.picked == (:todo, "bath: Grout é 2026-11-26") && !K.dirty(e.buf)
  # A page that's open is changed as if the day were typed there, and saved when it had nothing to save
  K.open!(e, bath); frames(); K.open!(e, page); frames()
  drag(middle(rect(chip(nov(26), "Grout é"))), empty(nov(27)))
  @test readlines(bath)[3] == "- [ ] Grout é 2026-11-27" && e.buffers[bath].lines[3] == "- [ ] Grout é 2026-11-27"
  shot("calendar-folder-moved.png")
end

@testset "two clicks on an item open its page at the item" begin
  place = middle(rect(chip(nov(20), "Order the sink")))
  click(place); click(place)
  @test e.buf.path == kitchen && e.buf.caret[1] == 3
end

K.calendar_day[] = nothing
close(w)
