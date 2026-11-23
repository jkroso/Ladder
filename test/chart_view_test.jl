# Tests for the `chart` block of main.jl: the chart of a table's numbers. Run
# them with `julia -O0 --project=. test/chart_view_test.jl`. They click in a
# window that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they
# save a picture of each kind of chart there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const C, px = K.Charts, K.px

const dir = mktempdir()
const page = joinpath(dir, "budget.md")
write(page, """
# Budget

| Month | Sales | Costs |
|---|---|---|
| Jan | \$1,200 | \$800 |
| Feb | **\$1,500** | \$900 |
| Mar | \$1,100 | \$1,000 |

```chart
title: Sales and costs
```

## Rooms

```spreadsheet
| Room | Long | Wide | Area |
| Kitchen | 4 | 3 | = B2 * C2 |
| Lounge | 6 | 5 | = B3 * C3 |
```

```chart
kind: pie
show: Area
```

```chart
from: Nowhere
```

```chart
kind: lines

Day | Rain
Mon | 3 mm
Tue | 12 mm
```

```sheet
Walls = 12 * 2.4
Floor = 4 * 5
```

```chart
```

## Cells

```sheet
Age = 0 to 10
Power = 100 - 2 * age
```

## Chips

```sheet
Age = 0 to 10
Working = 100 - 5 * age
```

```chart
kind: lines
from: Cells, Chips
```

```chart
from: Cells, Nowhere
```
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
chart(n) = e.nodes[(:block, K.CHART, page, n)]
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
block(n) = (s = K.block_lines(e.buf, K.CHART, n); e.buf.lines[s[1]+1:s[2]-1])
"Scroll the page until the `n`th chart has been laid out and drawn"
show_chart(n) = (K.show_line!(e, K.block_lines(e.buf, K.CHART, n)[2] + 1); frames(3); chart(n))

@testset "a chart draws the table over it" begin
  v = chart(1)
  d = K.shown!(v)
  @test d.problem == "" && d.labels == ["Jan", "Feb", "Mar"] && [s.name for s in d.series] == ["Sales", "Costs"]
  @test d.series[1].values == [1200.0, 1500.0, 1100.0] && d.before == "\$"
  bars = filter(m -> m.kind == :bar, v.marks)
  @test length(bars) == 6 && v.box[3] > 300
  @test any(en -> en.title == "Chart", K.outline(e.buf))
  @test any(x -> x isa Tuple && x[1] == "Chart", K.INSERTS)
  html = K.page_html(e)
  @test occursin("<strong>Sales and costs</strong>", html) && occursin("<svg", html) && occursin(">Feb</text>", html)
  @test !K.dirty(e.buf)
  shot("bars.png")
end

@testset "the buttons choose the kind of chart" begin
  v = chart(1)
  click(middle(rect(v.parts[(:button, :lines)])))
  @test v.spec.kind == :lines && block(1) == ["kind: lines", "title: Sales and costs"]
  @test count(m -> m.kind == :line, v.marks) == 2 && K.dirty(e.buf)
  click(middle(rect(v.parts[(:button, :pie)])))
  @test block(1)[1] == "kind: pie" && count(m -> m.kind == :slice, v.marks) == 3
  # ⌘Z takes the change back
  K.undo!(e.buf); frames()
  @test block(1)[1] == "kind: lines" && chart(1).spec.kind == :lines
  K.undo!(e.buf); frames()
  @test block(1) == ["title: Sales and costs"] && chart(1).spec.kind == :bars
end

@testset "the mouse over a bar says its number" begin
  v = chart(1)
  bar = first(m for m in v.marks if m.kind == :bar && m.label == 2 && m.series == 1)
  at((v.box[1] + bar.at[1] + bar.at[3] / 2, v.box[2] + bar.at[2] + 4))
  @test K.chart_hit(v) === first(m for m in chart(1).marks if m.kind == :bar && m.label == 2 && m.series == 1)
  @test C.said(K.shown!(v), K.chart_hit(v)) == "Feb  ·  Sales:  \$1,500"
end

@testset "the page changes, and the chart with it" begin
  i = findfirst(==("| Jan | \$1,200 | \$800 |"), e.buf.lines)
  K.edit!(e.buf, (i, 9), (i, 14), "2,400")
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
  @test K.shown!(chart(1)).series[1].values[1] == 2400.0
end

@testset "a spreadsheet, a heading, the chart's own rows and a sheet" begin
  v = show_chart(2)
  d = K.shown!(v)
  @test d.problem == "" && d.labels == ["Lounge", "Kitchen"] && d.series[1].values == [30.0, 12.0]
  @test count(m -> m.kind == :slice, v.marks) == 2
  shot("pie.png")
  @test occursin("Nowhere", K.shown!(show_chart(3)).problem)
  v = show_chart(4)
  @test K.shown!(v).labels == ["Mon", "Tue"] && K.shown!(v).after == " mm" && count(m -> m.kind == :dot, v.marks) == 2
  shot("lines.png")
  v = show_chart(5)
  @test K.shown!(v).labels == ["Walls", "Floor"] && K.shown!(v).series[1].values == [28.8, 20.0]
end

@testset "a chart of two sheets" begin
  v = show_chart(6)
  d = K.shown!(v)
  @test d.problem == "" && [s.name for s in d.series] == ["Power", "Working"] && d.labels[[1, end]] == ["0", "10"]
  @test d.series[1].values[end] == 80.0 && d.series[2].values[end] == 50.0
  @test count(m -> m.kind == :line, v.marks) == 2 && K.source_words(v) == "2 tables"
  shot("two sheets.png")
  @test occursin("“Nowhere”", K.shown!(show_chart(7)).problem)
end

@testset "⌘-click in a chart's list of tables adds a table" begin
  K.show_line!(e, 1); frames(3)   # from below, show_chart would leave the chart's top over the window
  v = chart(1)
  click(middle(rect(v.parts[:source])))
  c = v.parts[:sources]
  @test c.asking == :source
  row(name) = c.parts[(:choice_row, findfirst(r -> r.name == name, c.rows))]
  cmd_click(r) = (w.keys |= Keys.cmd; click(middle(rect(r))); w.keys ⊻= Keys.cmd)
  cmd_click(row("Rooms"))
  # The chart drew the table above it, so it names that table and the new one
  @test "from: Budget, Rooms" in block(1) && c.asking == :source
  d = K.shown!(chart(1))
  @test d.labels == ["Jan", "Feb", "Mar", "Kitchen", "Lounge"] && [s.name for s in d.series] == ["Sales", "Costs", "Long", "Wide", "Area"]
  @test K.chosen(c, row("Budget").of.rows[row("Budget").k]) && K.chosen(c, c.rows[row("Rooms").k])
  @test K.source_words(chart(1)) == "2 tables"
  # ⌘Return takes the picked table away again
  c.pick = row("Rooms").k
  w.keys |= Keys.cmd; onkey(w, KeyPress{Keys.enter}(0, w)); w.keys ⊻= Keys.cmd; frames()
  @test "from: Budget" in block(1) && c.asking == :source
  # A plain click picks one table and closes the list
  click(middle(rect(row("The table above"))))
  @test !any(l -> startswith(l, "from:"), block(1)) && c.asking === nothing
end
