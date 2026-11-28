# Tests for a line that holds only a CSV file, which the page shows as a table.
# See "a table from a CSV file" in media_view.jl. Run them with
# `julia -O0 --project=. test/csv_view_test.jl`. They write small CSV files
# into a temporary folder, and click in a window that isn't on the screen. Set
# `LADDER_SHOTS` to a folder, and they save pictures of the tables there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); write(path, text); path)

const prices = file("prices.csv", "Item,Price,Stock\nPaint,\$42.50,12\nTimber,\$8,340\nNails,\$3.20,\n")
file("notes.csv", """
Item,Note,Price
Paint,"Two coats, low sheen. The first coat dries in two hours, and the second goes on the next day.",42.5
Timber,"The ""good"" pine
from the yard",8
"Nails, 50 mm",,3.2
""")
const long = file("long.csv", "Day,Rain\n" * join(("$d,$(d % 7) mm" for d in 1:100), "\n") * "\n")
file("rooms.tsv", "Room\tLong\tWide\nKitchen\t4\t3\nLounge, big\t6\t5\n")
file("empty.csv", "")
file("wide.csv", "Work," * join(("Week $c" for c in 1:8), ",") * "\n" *
                 join(("\"Dig the trench for the new pipe, and fill it again\"," * join((string(r * c * 1000) for c in 1:8), ",") for r in 1:4), "\n"))

const page = joinpath(dir, "job.md")
write(page, """
# A job

The prices are in a file.

![Prices](prices.csv)

```chart
title: Prices
show: Price
```

![Notes on each item](notes.csv)

![](long.csv)

![Rooms](rooms.tsv)

```chart
from: rooms.tsv
show: Long
```

![Nothing](empty.csv)

![Gone](gone.csv)

![Wide](wide.csv)

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

"The line of the page that holds `text`"
line(text) = findfirst(l -> occursin(text, l), e.buf.lines)
"The node that shows the line that holds `text`"
shown(text) = K.item(e, line(text)).content.node
"Scroll the page until the line that holds `text` is near the top of the window"
goto(text) = (e.scroll.offset = max(0px, K.item(e, line(text)).top - 60px); frames(3))
"Scroll the page until the end of what the line that holds `text` shows is in the window"
goto_end(text) = (it = K.item(e, line(text)); e.scroll.offset = max(0px, it.top + it.tall - 500px); frames(3))
press(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
click(node) = begin
  r = rect(node)
  w.mouse = typeof(w.mouse)(r.left + r.width / 2, r.top + r.height / 2)
  frame(w)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  frames()
end
caret!(i, col=0) = (e.buf.caret = e.buf.anchor = (i, col); K.touch!(e); frames())
"The text of each line on screen of a cell"
words(flow) = [join(seg.text for seg in vl.segs) for vl in flow.lines]

@testset "a line that holds only a CSV file shows a table" begin
  t = shown("prices.csv")
  @test t isa K.TableLine && t.words == "Prices" && t.path == prices
  g = t.laid
  @test g.rows == 4 && length(g.widths) == 3
  # The columns share the width of the page, as the columns of a table of the page do
  @test isapprox(K.num(sum(g.widths)), K.num(e.width) - 4, atol=0.01)
  @test K.num(K.item(e, line("prices.csv")).tall) ≈ K.num(K.tall(t)) + 2K.num(K.LIVE_GAP)
  # The names of the columns are bold, and a column of numbers has its text on the right
  head, row = K.row_flows(g, 1), K.row_flows(g, 2)
  @test words(row[1]) == ["Paint"] && words(row[2]) == ["\$42.50"] && words(head[2]) == ["Price"]
  @test K.weight_of(head[1].lines[1].segs[1].face.style) >= 700 > K.weight_of(row[1].lines[1].segs[1].face.style)
  @test row[1].lines[1].segs[1].x == K.CELL_X
  ends(flow) = (seg = flow.lines[1].segs[end]; K.num(seg.x + seg.w))
  @test ends(row[2]) ≈ K.num(g.widths[2] - K.CELL_X) && ends(head[2]) ≈ ends(row[2])
  # The table has no line under it, because every row shows
  @test !K.has_more(t)
  shot("csv.png")
end

@testset "cells in quotes, and a cell with long text" begin
  goto("notes.csv")
  g = shown("notes.csv").laid
  # Long text goes onto more lines, and its row is taller
  @test length(K.row_flows(g, 2)[2].lines) > 1 && g.heights[2] > g.heights[4]
  # A line break in a cell is a space
  @test join(words(K.row_flows(g, 3)[2])) == "The \"good\" pine from the yard"
  shot("csv-notes.png")
end

@testset "a long file shows its first rows, and a click shows the rest" begin
  goto("long.csv")
  t = shown("long.csv")
  @test t.laid.rows == 31 && K.more_words(t) == ("and 70 more rows", "")
  short = K.tall(t)
  shot("csv-long.png")
  goto_end("long.csv")
  more = t.parts[:more]
  shot("csv-long-more.png")
  click(more)
  @test t.whole && t.laid.rows == 101 && K.more_words(t)[1] == "Show the first 30 rows only"
  @test K.tall(t) > short && K.num(K.item(e, line("long.csv")).tall) ≈ K.num(K.tall(t)) + 2K.num(K.LIVE_GAP)
  # Only the rows that the window shows are built
  lo, hi = K.rows_shown(e, t, t.laid)
  @test lo > 1 && hi < 80 && hi - lo < 45
  @test length(t.laid.flows) < 60
  shot("csv-long-all.png")
  # At the end of the table, the first rows aren't built, and the last ones are
  goto_end("long.csv")
  lo, hi = K.rows_shown(e, t, t.laid)
  @test lo > 50 && hi == 101
  shot("csv-long-end.png")
  # A click on the line under the last row shows the first rows only again, and the line stays under the mouse
  y = rect(more).top
  click(more)
  @test !t.whole && t.laid.rows == 31 && K.tall(t) == short
  @test abs(K.num(rect(more).top - y)) < 1
end

@testset "a file that isn't there, and one with no rows" begin
  goto("empty.csv")
  @test shown("empty.csv") isa K.MediaNote && occursin("empty.csv has no rows", shown("empty.csv").words)
  @test shown("gone.csv") isa K.MediaNote && occursin("can't find the file gone.csv", shown("gone.csv").words)
  shot("csv-problems.png")
end

@testset "a table with more columns than the page has room for" begin
  goto("wide.csv")
  g = shown("wide.csv").laid
  @test isapprox(K.num(sum(g.widths)), K.num(e.width) - 10, atol=0.01)
  # A number isn't cut: its column keeps the room that it needs, and the long text goes onto more lines
  fits = [K.num(K.measure(g.base, g.table.rows[5][c])) <= K.num(g.widths[c] - 2K.CELL_X) + 0.01 for c in 2:9]
  @test all(fits)
  @test length(K.row_flows(g, 2)[1].lines) > 2
  shot("csv-wide.png")
end

@testset "the caret goes onto the table as a whole" begin
  i = line("prices.csv")
  caret!(i - 2, 0)
  press(Keys.down); press(Keys.down)
  @test e.buf.caret == (i, 0) && K.picked(e.buf) == (i, i)
  @test K.item(e, i).content isa K.Live
  shot("csv-picked.png")
  # ↓ goes on to the line after it, and ↑ comes back onto it
  press(Keys.down)
  @test e.buf.caret[1] == i + 1 && K.picked(e.buf) === nothing
  press(Keys.up)
  @test K.picked(e.buf) == (i, i)
  # A click on the table puts the caret on it as a whole
  caret!(1, 0)
  goto("A job")
  click(shown("prices.csv"))
  @test e.buf.caret == (i, 0) && K.picked(e.buf) == (i, i) && K.cursor(shown("prices.csv")) == :arrow
  # With ⌥ held, a click puts the caret in its line, which then shows as it's written
  caret!(1, 0)
  goto("A job")
  w.keys |= Keys.opt; click(shown("prices.csv")); w.keys ⊻= Keys.opt
  @test e.buf.caret == (i, length(e.buf.lines[i]))
  @test (c = K.item(e, i).content; c isa K.Flow && c.raw)
  shot("csv-raw.png")
  # The line shows as text while it's typed, and as a table when the caret leaves it
  foreach(c -> ontype(e, Typed(c, w)), " "); frames()
  @test K.item(e, i).content isa K.Flow
  press(Keys.z, Keys.cmd)
  @test e.buf.lines[i] == "![Prices](prices.csv)"
  caret!(1, 0)
  @test shown("prices.csv") isa K.TableLine
  # ⌫ on the table as a whole takes its line away, and ⌘Z brings it back
  caret!(i, 0)
  @test K.picked(e.buf) == (i, i)
  press(Keys.backspace)
  @test line("prices.csv") === nothing
  press(Keys.z, Keys.cmd)
  @test line("prices.csv") == i
  caret!(1, 0)
end

@testset "a chart draws the file's numbers" begin
  goto("A job")
  chart(n) = e.nodes[(:block, K.CHART, page, n)]
  d = K.shown!(chart(1))
  @test d.problem == "" && d.labels == ["Paint", "Timber", "Nails"]
  @test [s.name for s in d.series] == ["Price"] && d.series[1].values == [42.5, 8.0, 3.2] && d.before == "\$"
  # `from` names a file
  d = K.shown!(chart(2))
  @test d.problem == "" && d.labels == ["Kitchen", "Lounge, big"] && d.series[1].values == [4.0, 6.0]
  shot("csv-chart.png")
  # A file that isn't there says so
  v = K.ChartView(spec=K.Charts.chart(["from: gone.csv"]))
  @test occursin("can't find the file gone.csv", K.chart_file(e, v.spec).problem)
  @test K.chart_file(e, K.Charts.chart(["from: Budget"])) === nothing
end

@testset "the table shows the file's new numbers when the file changes" begin
  goto("A job")
  chart = e.nodes[(:block, K.CHART, page, 1)]
  # The file is read once, however many frames are drawn
  reads = K.table_reads[]
  frames(5)
  @test K.table_reads[] == reads
  sleep(0.02)
  write(prices, "Item,Price,Stock\nPaint,\$45,10\nTimber,\$9,300\nNails,\$3.20,\nGlue,\$12,4\n")
  frames()
  @test K.table_reads[] == reads + 1
  t = shown("prices.csv")
  @test t.laid.rows == 5 && t.laid.table.rows[5] == ["Glue", "\$12", "4"]
  @test K.shown!(chart).series[1].values == [45.0, 9.0, 3.2, 12.0]
  # The file goes, and comes back
  rm(prices); frames()
  @test shown("prices.csv") isa K.MediaNote
  # The chart then draws the next table of the page: the one under it
  @test K.shown!(chart).labels == ["Paint", "Timber", "Nails, 50 mm"]
  write(prices, "Item,Price\nPaint,\$45\n"); frames()
  @test shown("prices.csv") isa K.TableLine && shown("prices.csv").laid.rows == 2
end

@testset "the page as HTML has the file as a table" begin
  out = K.page_html(e)
  @test occursin("<table>\n<caption>Prices (prices.csv)</caption>\n<thead><tr><th>Item</th><th style=\"text-align: right\">Price</th></tr></thead>", out)
  @test occursin("<tr><td>Paint</td><td style=\"text-align: right\">\$45</td></tr>", out)
  # A line break in a cell, a quote, and a file whose link has no words
  @test occursin("<td>The &quot;good&quot; pine<br>from the yard</td>", out)
  @test occursin("<caption>long.csv</caption>", out)
  # Every row of a long file is in the page
  @test occursin("<tr><td style=\"text-align: right\">100</td><td style=\"text-align: right\">2 mm</td></tr>", out)
  @test occursin("<p><em>Ladder can't find the file gone.csv.</em></p>", out)
  @test !occursin("<img", out)
end

@testset "a CSV file that's dropped on the page goes in as a line of its own" begin
  i = line("The prices are in a file.")
  before = copy(e.buf.lines)
  K.put_files!(e, [joinpath(dir, "rooms.tsv")], (i, 3))
  frames()
  @test e.buf.lines[i+2] == "![rooms](rooms.tsv)" && e.buf.lines[i] == "The prices are in a file."
  caret!(1, 0)
  @test K.item(e, i + 2).content.node isa K.TableLine
  # Two lines that hold one file each have a table of their own
  @test K.item(e, i + 2).content.node !== shown("![Rooms](rooms.tsv)")
  K.undo!(e.buf); frames()
  @test e.buf.lines == before
end

@testset "the table of a file under a file path reads the file as before" begin
  # That table's reader is csv.jl's now
  t = K.tabled(joinpath(dir, "rooms.tsv"))
  @test t.rows == [["Room", "Long", "Wide"], ["Kitchen", "4", "3"], ["Lounge, big", "6", "5"]] && length(t.widths) == 3 && !t.more
  @test K.tabled(joinpath(dir, "empty.csv")) === nothing
end

@testset "the page on paper, in the dark, and in a narrow window" begin
  # On paper, every row of a table that shows all its rows is drawn
  t = shown("long.csv")
  t.whole = true; frames()
  @test length(K.print_pdf(e)) > 10_000
  frames()
  @test t.laid.rows == 101
  t.whole = false; frames()
  e.theme = :night; K.restyle!(e)
  goto("A job"); shot("csv-night.png")
  goto("notes.csv"); shot("csv-night-notes.png")
  e.theme = :sepia; K.restyle!(e); frames()
  close(w)
  narrow = Window(e, size=(460px, 800px))
  foreach(_ -> frame(narrow), 1:3)
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "csv-narrow.png"), narrow)
  e.scroll.offset = max(0px, K.item(e, line("wide.csv")).top - 60px)
  foreach(_ -> frame(narrow), 1:3)
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "csv-narrow-wide.png"), narrow)
  @test isapprox(K.num(sum(shown("wide.csv").laid.widths)), K.num(e.width) - 10, atol=0.01)
end

exit()
