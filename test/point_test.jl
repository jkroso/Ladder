# Tests for one thing in many parts of a page, in main.jl: while the mouse is
# on a thing in one part, each other part marks the same thing. Run them with
# `julia -O0 --project=. test/point_test.jl`. They move the mouse in a window
# that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save
# pictures of the page there.

@use Test: @test, @testset
@use Dates
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window MouseMove onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "job.md")
const today = Dates.today()
write(page, """
# A job

- [x] Dig the trench
- [ ] Lay the pipe
- [ ] Test the pipe

```board
Lay the pipe | Doing
```

```schedule
start: $(today)
days: every day
Dig the trench | 2 days
Lay the pipe | 3 days | after Dig the trench
```

```calendar
month: $(Dates.format(today + Dates.Day(3), "yyyy-mm"))

$(today + Dates.Day(3)) | Lay the pipe
```

```timelog
2026-11-17 07:30-12:00 | Lay the pipe
2026-11-17 12:30-15:45 | Dig the trench
2026-11-18 08:10-11:40 | lay the pipe
```

| Month | Sales |
|---|---|
| July | 4200 |
| August | 5100 |
| September | 4800 |

```chart
```

```sheet
July = 12m
Wall = 3m
```
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 2300px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
shot(name) = (path = joinpath(dir, name); save_png(path, w); haskey(ENV, "LADDER_SHOTS") && cp(path, joinpath(ENV["LADDER_SHOTS"], name), force=true); pixels(path))

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
block(lang) = e.nodes[(:block, lang, page, 1)]
const board, calendar, hours, chart, schedule = block(K.BOARD), block(K.CALENDAR), block(K.TIMELOG), block(K.CHART), block(K.SCHEDULE)
"The middle of the page's line `i`, in the window"
line_at(i) = (it = K.item(e, i); (K.num(e.origin[1]) + 120.0, K.num(e.origin[2] + it.top + it.tall / 2)))
line(text) = findfirst(==(text), e.buf.lines)
"The middle of row `r` of the item that shows line `i`: a table or a sheet"
row_at(i, r) = (it = K.item(e, i); (_, top, high) = K.named_rows(e, it)[r]; (K.num(e.origin[1]) + 30.0, K.num(e.origin[2] + it.top + top + high / 2)))
card(name) = middle(rect(board.parts[(:card, name)]))
"True when the picture `b` differs from the picture `a` round the place `(x, y)`"
changed(a, b, (x, y); by=12) = begin
  k = size(a, 2) / 1000   # a picture has more than one pixel to a px of the window on some screens
  rows = max(1, round(Int, k * (y - by))):min(size(a, 1), round(Int, k * (y + by)))
  cols = max(1, round(Int, k * (x - by))):min(size(a, 2), round(Int, k * (x + by)))
  a[rows, cols] != b[rows, cols]
end

# A place with nothing under it: the window's bottom corner. The top corner has the ladder, which opens into a
# slider while the mouse is on it, so a picture there depends on how long the mouse has been there.
const nowhere = (990, 2290)
at(nowhere)
const plain = shot("point-none.png")

@testset "nothing is pointed at until the mouse is on a thing" begin
  @test K.pointed(e) === nothing
  @test !K.marked(e, "Lay the pipe") && !K.marked(board, "Lay the pipe")
end

@testset "a card of the board" begin
  at(card("Lay the pipe"))
  @test K.pointed(board) == "Lay the pipe" && K.pointed(e) == "lay the pipe"
  @test K.marked(schedule, "Lay the pipe") && K.marked(hours, "lay the pipe") && !K.marked(hours, "Dig the trench")
  lit = shot("point-card.png")
  # The item's line of the text has a box behind it, and the next item's has none
  @test changed(plain, lit, line_at(line("- [ ] Lay the pipe")) .- (100, 0))
  @test !changed(plain, lit, line_at(line("- [ ] Test the pipe")) .- (100, 0))
  # The task's name in the schedule, its event in the calendar and its two rows of the log are marked
  @test changed(plain, lit, middle(rect(schedule.parts[(:name, "Lay the pipe")])) .+ (100, 0); by=4)
  @test !changed(plain, lit, middle(rect(schedule.parts[(:name, "Dig the trench")])) .+ (100, 0); by=4)
  first_row, second_row, third_row = [middle(rect(hours.parts[(:cell, i, :task)])) .+ (150, 0) for i in 1:3]
  @test changed(plain, lit, first_row; by=3) && changed(plain, lit, third_row; by=3) && !changed(plain, lit, second_row; by=3)
end

@testset "a to-do item of the text" begin
  at(line_at(line("- [x] Dig the trench")))
  @test K.pointed_line(e) == (line("- [x] Dig the trench"), "Dig the trench") && K.pointed(e) == "dig the trench"
  lit = shot("point-item.png")
  @test changed(plain, lit, card("Dig the trench") .+ (0, 0); by=30)
  @test !changed(plain, lit, card("Test the pipe"); by=30)
  # The line that the mouse is on has no box of its own
  @test !changed(plain, lit, line_at(line("- [x] Dig the trench")) .- (118, 0); by=3)
end

@testset "a bar of the schedule, a thing of the calendar and a row of the log" begin
  at(middle(rect(schedule.parts[(:name, "Lay the pipe")])))
  @test K.pointed(schedule) == "Lay the pipe" && K.pointed(e) == "lay the pipe"
  thing = only(c for c in values(calendar.parts) if c isa K.CalendarThing && c.thing !== nothing && c.thing.kind == :event && rect(c) !== nothing)
  at(middle(rect(thing)))
  @test K.pointed(calendar) == "Lay the pipe" && K.pointed(e) == "lay the pipe"
  at(middle(rect(hours.parts[(:cell, 2, :task)])) .+ (150, 0))
  @test K.hot_stretch(hours) == 2 && K.pointed(hours) == "Dig the trench" && K.marked(board, "Dig the trench")
end

@testset "a row of a table and a bar of its chart" begin
  table = line("| Month | Sales |")
  at(row_at(table, 2))
  @test K.pointed(e) == "august"
  lit = shot("point-row.png")
  # The bars of the other rows are pale
  bars = [m for m in chart.marks if m.kind == :bar]
  spot(m) = (chart.box[1] + m.at[1] + m.at[3] / 2, chart.box[2] + m.at[2] + m.at[4] / 2)
  @test length(bars) == 3 && changed(plain, lit, spot(bars[1]); by=2) && !changed(plain, lit, spot(bars[2]); by=2) && changed(plain, lit, spot(bars[3]); by=2)
  # The names of the columns are no row to point at
  at(row_at(table, 1) .- (0, 30))
  @test K.pointed(e) === nothing
  # A bar marks its row of the table, and the row of a sheet that has its name
  at(spot(bars[1]))
  @test K.pointed(chart) == "July" && K.pointed(e) == "july"
  lit = shot("point-bar.png")
  @test changed(plain, lit, row_at(table, 1); by=3) && !changed(plain, lit, row_at(table, 2); by=3)
  sheet = findfirst(==("```sheet"), e.buf.lines)
  @test changed(plain, lit, row_at(sheet, 1) .+ (300, 0); by=3) && !changed(plain, lit, row_at(sheet, 2) .+ (300, 0); by=3)
end

@testset "the mouse leaves, and the marks go" begin
  at(nowhere)
  @test K.pointed(e) === nothing
  @test shot("point-gone.png") == plain
end

close(w)
