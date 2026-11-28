# Tests for where a block's rows come from: the button at the top of a filter,
# a load block, a save block and a chart, and the list that it opens of the
# page's tables, with a row that picks a file. See "where a block's rows come
# from" in main.jl. Run them with `julia -O0 --project=. test/source_test.jl`.
# They click in a window that isn't on the screen. Set `LADDER_SHOTS` to a
# folder, and they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
write(joinpath(dir, "rows.csv"), "Item,Cost\nNails,3\n")
write(joinpath(dir, "things.json"), """[{"Item": "Glue", "Cost": 9}]""")

const page = joinpath(dir, "sources.md")
write(page, """
Some words.

| A | B |
|---|---|
| 1 | 2 |

# Costs

| Item | Cost |
|---|---|
| Sand | 120 |

| Item | Cost |
|---|---|
| Pipe | 45 |

## Narrow

```filter
from: Costs 2
```

```chart
```

```save
to: out.csv
```

## Below

| X | Y |
|---|---|
| a | 1 |

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1100px))
const (; frames, at, press, release, click, key, shot) = drive(w)
frames()

view(lang, n) = e.nodes[(:block, lang, page, n)]
block(lang, n) = (s = K.block_lines(e.buf, lang, n); e.buf.lines[s[1]+1:s[2]-1])
"Scroll the page until the top of the `n`th block in `lang` is near the top of the window, and it has been laid out and drawn"
show_block(lang, n) = begin
  s = K.block_lines(e.buf, lang, n)
  K.show_line!(e, s[2] + 1); frames(2)
  e.scroll.offset = max(0px, K.item(e, s[1]).top - 40px); frames(3)
  view(lang, n)
end
"Click the button at the top of `v` that says where its rows come from. A chart shows it only while the mouse is on the chart."
open_list(v) = (v isa K.ChartView && at(middle(v)); click(middle(v.parts[:source])))
chooser(v) = v.parts[:sources]
names(v) = [r.name for r in chooser(v).rows]
"Click the row of the open list of `v` called `name`"
take(v, name) = (c = chooser(v); click(middle(c.parts[(:choice_row, findfirst(r -> r.name == name, c.rows))])))
"The names in the list of a breadcrumb that picks a file"
files(p) = [basename(x.path) for x in K.contents(p) if x isa K.FileEntry]
"Click the line of the breadcrumb `p` that has `name`"
pick(p, name) = click(middle(only(x for x in K.contents(p) if x isa K.FileEntry && basename(x.path) == name)))
shown(v) = (x = K.filter_shown!(v); x.subset === nothing ? [] : K.filter_table(x.data, x.subset))

@testset "a table is called by the heading over it and a number" begin
  ts = K.page_tables(e)
  called = [K.table_name(e, ts, k) for k in eachindex(ts)]
  # A table with no heading over it has the name of the page's file
  @test called == ["sources", "Costs", "Costs 2", "Narrow", "Below"]
  @test [K.named_table(e, ts, n) for n in called] == collect(1:5)
  @test K.named_table(e, ts, "costs 2") == 3 && K.named_table(e, ts, "Costs 3") === nothing && K.named_table(e, ts, "Nothing") === nothing
  @test shown(show_block(K.FILTER, 1)) == [["Item", "Cost"], ["Pipe", "45"]]
end

@testset "a filter's name opens a list of the tables above it" begin
  v = show_block(K.FILTER, 1)
  @test K.source_words(v) == "Costs 2"
  open_list(v)
  c = chooser(v)
  @test c.asking == :source && names(v) == ["The table above", "sources", "Costs", "Costs 2", "Choose a file…"]
  @test [r.short for r in c.rows] == ["", "table", "table", "table", ""]
  # The row of where the rows come from now is picked
  @test c.rows[c.pick].name == "Costs 2"
  shot("source-list.png")
  # Words in the field keep the rows that have them, and Return takes the one picked
  K.choice_input(c).text = "costs"; frames(2)
  @test names(v) == ["Costs", "Costs 2"] && c.rows[c.pick].name == "Costs"
  key(Keys.enter)
  @test c.asking === nothing && block(K.FILTER, 1) == ["from: Costs"] && shown(v) == [["Item", "Cost"], ["Sand", "120"]]
  # The table above takes the line away
  open_list(v); take(v, "The table above")
  @test block(K.FILTER, 1) == String[] && K.source_words(v) == "The table above"
end

@testset "Choose a file… picks a file of rows" begin
  v = show_block(K.FILTER, 1)
  open_list(v); take(v, "Choose a file…")
  @test K.picks_file(v) && files(v.parts[:picker]) == ["rows.csv", "things.json"]
  pick(v.parts[:picker], "rows.csv")
  @test block(K.FILTER, 1) == ["from: rows.csv"] && !K.picks_file(v) && shown(v) == [["Item", "Cost"], ["Nails", "3"]]
  # The list has that file now
  open_list(v)
  @test names(v) == ["The table above", "sources", "Costs", "Costs 2", "rows.csv", "Choose a file…"] && chooser(v).rows[chooser(v).pick].name == "rows.csv"
  key(Keys.escape)
  @test chooser(v).asking === nothing
end

@testset "a chart's list has the tables under it too" begin
  v = show_block(K.CHART, 1)
  @test K.source_words(v) == "The table above"
  open_list(v)
  @test names(v) == ["The table above", "sources", "Costs", "Costs 2", "Narrow", "Below", "Choose a file…"]
  take(v, "Below")
  @test block(K.CHART, 1) == ["from: Below"] && isempty(K.shown!(v).problem)
  # A chart draws a CSV file, so the list of files has no JSON file
  open_list(v); take(v, "Choose a file…")
  @test v.sourcing && files(v.parts[:from_picker]) == ["rows.csv"]
  shot("source-chart-file.png")
  click(middle(v.parts[(:button, :close_picker)].rect))
  @test !v.sourcing && block(K.CHART, 1) == ["from: Below"]
end

@testset "a save block reads a table it's given, or a file" begin
  v = show_block(K.SAVE, 1)
  open_list(v)
  @test names(v) == ["The table above", "sources", "Costs", "Costs 2", "Narrow", "Choose a file…"]
  take(v, "Costs")
  @test block(K.SAVE, 1) == ["from: Costs", "to: out.csv"] && K.save_data(v).rows == [["Item", "Cost"], ["Sand", "120"]]
  open_list(v); take(v, "Choose a file…")
  @test v.sourcing && files(v.parts[:from_picker]) == ["rows.csv", "things.json"]
  pick(v.parts[:from_picker], "things.json")
  @test block(K.SAVE, 1) == ["from: things.json", "to: out.csv"] && !v.sourcing
  d = K.save_data(v)
  @test d.rows == [["Item", "Cost"], ["Glue", "9"]] && d.name == "things.json"
end
