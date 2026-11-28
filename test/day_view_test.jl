# Tests for the `day` block of main.jl: a slider that sets the day that the
# page shows, and the parts of the page that follow it. Run them with
# `julia -O0 --project=. test/day_view_test.jl`. They drag the slider in a
# window that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they
# save pictures of the page there.

@use Test: @test, @testset
@use Dates: Dates, Date, Day
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const TODAY = Date(2026, 11, 20)   # a Friday
const dir = mktempdir()
const page = joinpath(dir, "job.md")
write(page, """
# A job

```day
```

- [x] Dig the trench
- [ ] Lay the pipe
- [ ] Test the pipe

```board
```

```schedule
start: 2026-11-18
days: every day
Dig the trench | 2 days
Lay the pipe | 3 days | after Dig the trench
Test the pipe | after Lay the pipe
```

```calendar
```

```timelog
2026-11-18 07:30-11:30 | Dig the trench
2026-11-19 08:00-10:00 | Dig the trench
2026-11-20 08:00-09:00 | Lay the pipe
```

```chart
```
""")

K.calendar_day[] = TODAY
try
  e = K.build_editor(page)
  w = Window(e, size=(1000px, 1900px))
  (; frames, at, press, release, click, shot) = drive(w, pressed=1)
  frames()
  block(lang) = e.nodes[(:block, lang, page, 1)]
  v, board, calendar, hours, chart, schedule = block(K.DAY_BLOCK), block(K.BOARD), block(K.CALENDAR), block(K.TIMELOG), block(K.CHART), block(K.SCHEDULE)
  spot(d) = (K.day_spot(v, findfirst(==(d), v.days)), v.box[2] + 30)
  lines() = (s = K.block_lines(e.buf, K.DAY_BLOCK, 1); e.buf.lines[s[1]+1:s[2]-1])
  names(c) = [t.name for t in K.columns!(board)[c]]
  button(key) = middle(rect(v.parts[(:button, key)]))
  rows() = K.shown!(chart)
  line(words) = findfirst(l -> occursin(words, l), e.buf.lines)
  "What the box of the item with `words` shows: true for a tick"
  box(words) = (i = line(words); K.pieces(e, e.buf.lines[i], K.kinds(e.buf)[i], false, i)[1].text == K.TODO_DONE)

  @testset "a page with an empty block shows today" begin
    @test K.page_day(e) == TODAY && !K.another_day(e) && !K.planned(board)
    # The slider's days cover the schedule's tasks and the log's rows
    @test first(v.days) == Date(2026, 11, 16) && last(v.days) >= Date(2026, 11, 25) && TODAY in v.days
    @test names(1) == ["Lay the pipe", "Test the pipe"] && names(3) == ["Dig the trench"]
    @test K.month_shown(calendar) == Date(2026, 11, 1)
    @test rows().labels == ["Dig the trench", "Lay the pipe"] && rows().series[1].values == [6.0, 1.0]
    @test any(en -> en.title == "Day", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Day", K.INSERTS)
    # The boxes of the to-do items show the page's own ticks
    @test box("Dig the trench") && !box("Lay the pipe") && !box("Test the pipe")
    shot("day-today.png")
  end

  @testset "the calendar shows the hours that the log has for each day" begin
    things = K.day_things(calendar, Date(2026, 11, 18))
    @test any(t -> t.kind == :log && t.words == "Dig the trench  4 h" && e.buf.lines[t.line] == "2026-11-18 07:30-11:30 | Dig the trench", things)
    @test K.thing_name(only(t for t in K.day_things(calendar, TODAY) if t.kind == :log)) == "Lay the pipe"
  end

  @testset "a drag of the slider changes the page's day while the mouse moves" begin
    press(spot(TODAY))
    at(spot(Date(2026, 11, 22)))
    frames()
    @test v.grab && K.page_day(e) == Date(2026, 11, 22) && lines() == String[]   # nothing is written until the mouse lets go
    # The plan has the trench dug and the pipe being laid on that day
    @test K.planned(board) && names(1) == ["Test the pipe"] && names(2) == ["Lay the pipe"] && names(3) == ["Dig the trench"]
    at(spot(Date(2026, 11, 23)))
    release()
    @test !v.grab && lines() == ["2026-11-23"] && K.page_day(e) == Date(2026, 11, 23)
    @test names(1) == String[] && names(2) == ["Test the pipe"] && names(3) == ["Dig the trench", "Lay the pipe"]
    tasks = Dict(t.todo.name => t for t in schedule.tasks)
    @test K.finished(e, tasks["Lay the pipe"]) && !K.finished(e, tasks["Test the pipe"]) && K.standing(e, tasks["Test the pipe"]) == :doing
    shot("day-later.png")
    # A card of a board that shows the plan stays where it is
    press(middle(rect(board.parts[(:card, "Test the pipe")])))
    @test board.grab === nothing
    release()
    # The item's line in the file is as it was, but its box shows the plan's tick, as the schedule and the board do
    @test "- [ ] Lay the pipe" in e.buf.lines
    @test box("Dig the trench") && box("Lay the pipe") && !box("Test the pipe")
    # A click on a box changes nothing while the page shows another day
    K.tick!(e, line("Test the pipe")); frames()
    @test "- [ ] Test the pipe" in e.buf.lines && !box("Test the pipe")
    # On a day after the plan's last day, every box has a tick
    K.set_day!(v, Date(2026, 11, 30)); frames()
    @test box("Dig the trench") && box("Lay the pipe") && box("Test the pipe")
    shot("day-done.png")
    K.set_day!(v, Date(2026, 11, 23)); frames()
  end

  @testset "a day that's past" begin
    click(spot(Date(2026, 11, 18)))
    @test lines() == ["2026-11-18"]
    # On that day the trench was being dug, whatever is ticked now
    @test names(1) == ["Lay the pipe", "Test the pipe"] && names(2) == ["Dig the trench"] && names(3) == String[]
    # The log and its chart have the hours to that day
    @test rows().labels == ["Dig the trench"] && rows().series[1].values == [4.0]
    # git doesn't keep this page, so its boxes show the plan's ticks: the trench wasn't dug yet
    @test !box("Dig the trench") && !box("Lay the pipe")
    shot("day-past.png")
  end

  @testset "the buttons and the keys" begin
    click(button(:on))
    @test lines() == ["2026-11-19"] && rows().series[1].values == [6.0]
    press(spot(Date(2026, 11, 19))); release()
    onkey(w, KeyPress{Keys.right}(0, w)); frames()
    @test K.page_day(e) == TODAY && lines() == String[]   # today takes the line away
    onkey(w, KeyPress{Keys.left}(0, w)); frames()
    @test lines() == ["2026-11-19"]
    click(button(:back))
    @test lines() == ["2026-11-18"]
    click(button(:today))
    @test lines() == String[] && K.page_day(e) == TODAY && !K.planned(board)
    @test names(1) == ["Lay the pipe", "Test the pipe"] && rows().series[1].values == [6.0, 1.0]
    @test box("Dig the trench") && !box("Lay the pipe")
    # ⌘Z puts the day back
    K.undo!(e.buf); frames()
    @test lines() == ["2026-11-18"] && K.page_day(e) == Date(2026, 11, 18)
  end

  @testset "the calendar shows the month of the page's day" begin
    K.set_day!(v, Date(2026, 12, 3)); frames()
    @test K.month_shown(calendar) == Date(2026, 12, 1)
    @test Date(2026, 12, 3) in v.days
    shot("day-december.png")
  end

  @testset "a page with no block shows today" begin
    s = K.block_lines(e.buf, K.DAY_BLOCK, 1)
    K.edit!(e.buf, (s[1], 0), K.line_end(e.buf, s[2]), "")
    frames()
    @test K.page_day(e) == TODAY && !K.planned(board) && K.month_shown(calendar) == Date(2026, 11, 1)
  end
  close(w)
finally
  K.calendar_day[] = nothing
end
