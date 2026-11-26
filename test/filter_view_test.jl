# Tests for the `filter` block of main.jl, which shows only the rows of a table
# that meet some conditions. See "a filter of a table's rows". Run them with
# `julia -O0 --project=. test/filter_view_test.jl`. They write a CSV file and
# a JSON file into a temporary folder, and click in a window that isn't on the
# screen. Set `LADDER_SHOTS` to a folder, and they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse onscroll Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); write(path, text); path)

const orders = file("orders.json", """
{"count": 5, "data": {"orders": [
  {"id": "A1", "status": "shipped", "total": 250, "customer": {"name": "Ann", "city": "Sydney"}, "tags": ["gift", "rush"]},
  {"id": "A2", "status": "packed", "total": 80.5, "customer": {"name": "Bob", "city": "Perth"}, "tags": []},
  {"id": "A3", "status": "Shipped", "total": 1200, "customer": {"name": "Cy", "city": "Sydney"}, "tags": ["rush"]},
  {"id": "A4", "status": "waiting", "total": 40, "customer": {"name": "Di", "city": "Hobart"}, "note": null},
  {"id": "A5", "status": "packed", "total": 130, "customer": {"name": "Ed", "city": "Perth"}, "tags": [{"x": 1}]}
]}}
""")
const NAMES = ["Ann", "Bob", "Cy", "Di", "Ed", "Flo", "Gus", "Hal", "Ivy", "Jo", "Kim", "Lee", "Max", "Ned", "Oli",
               "Pat", "Quin", "Ray", "Sam", "Tom", "Una", "Val", "Wes", "Xan", "Yen", "Zed"]
file("wide.csv", join(("Column $c" for c in 1:10), ",") * "\n" * join(("\"Dig the trench for the new pipe, column $c\"" for c in 1:10), ",") * "\n")
const people = file("people.csv", "Name,Age\n" * join(("$(NAMES[mod1(k, 26)]) $k,$(20 + k)" for k in 1:45), "\n") * "\n")

const page = joinpath(dir, "orders.md")
write(page, """
# Orders

```filter
from: orders.json
```

## Big orders

```filter
from: orders.json
where: total > 100
show: id, customer.name, total
sort: total, largest first
```

```chart
show: total
```

## People

```filter
from: people.csv
```

## Rooms

| Room | Area |
|---|---|
| Kitchen | 14 |
| Lounge | 22 |
| Hall | 4 |

```filter
where: Area >= 10
```

```filter
from: nowhere.json
```

```filter
from: orders.json
at: data.nothing
```

```filter
from: wide.csv
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1100px))
const (; frames, at, press, release, click, typed, key, shot) = drive(w)
frames()

block(n) = (s = K.block_lines(e.buf, K.FILTER, n); e.buf.lines[s[1]+1:s[2]-1])
view(n) = e.nodes[(:block, K.FILTER, page, n)]
"Scroll the page until the top of the `n`th filter is near the top of the window, and it has been laid out and drawn"
show_filter(n) = begin
  s = K.block_lines(e.buf, K.FILTER, n)
  K.show_line!(e, s[2] + 1); frames(2)
  e.scroll.offset = max(0px, K.item(e, s[1]).top - 40px); frames(3)
  view(n)
end
"The rows that the `n`th filter shows, each as the cells of its columns that show"
shown(n) = (x = K.filter_shown!(view(n)); K.filter_table(x.data, x.subset))
menu() = (i = findfirst(p -> p.key == K.FILTER_KEY, popups(w)); i === nothing ? nothing : popups(w)[i])
head(n, name) = (v = view(n); v.parts[(:head, findfirst(==(name), K.filter_shown!(v).data.rows[1]))])
pick(n, what, value="") = view(n).parts[(:pick, what, value)]

@testset "a JSON file's things are rows" begin
  v = view(1)
  d, s = K.filter_shown!(v)
  # The list is the first list of objects in the file, and an object in a thing makes columns with dots
  @test d.problem == "" && d.rows[1] == ["id", "status", "total", "customer.name", "customer.city", "tags", "note"]
  @test d.rows[2] == ["A1", "shipped", "250", "Ann", "Sydney", "gift, rush", ""]
  @test d.rows[6][6] == "[{\"x\": 1}]" && d.numbers == [false, false, true, false, false, false, false]
  @test length(s.rows) == 5 && d.name == "orders.json"
  @test any(en -> en.title == "Filter", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Filter", K.INSERTS)
  @test !K.dirty(e.buf)
  shot("filter-json.png")
end

@testset "the conditions, the columns and the order" begin
  @test shown(2) == [["id", "customer.name", "total"], ["A3", "Cy", "1200"], ["A1", "Ann", "250"], ["A5", "Ed", "130"]]
  # A chart under the filter draws the rows that it shows
  c = e.nodes[(:block, K.CHART, page, 1)]
  @test K.shown!(c).labels == ["A3", "A1", "A5"] && K.shown!(c).series[1].values == [1200.0, 250.0, 130.0]
  # A filter reads the table above it, and says why it has no rows
  @test shown(4) == [["Room", "Area"], ["Kitchen", "14"], ["Lounge", "22"]]
  @test K.filter_shown!(view(5)).data.problem == "Ladder can't find the file nowhere.json."
  @test K.filter_shown!(view(6)).data.problem == "The file has nothing at “data.nothing”."
  html = K.page_html(e)
  @test occursin("<caption>orders.json: 3 of 5 rows, where total &gt; 100</caption>", html) && occursin("<td>Cy</td>", html)
  @test occursin("Ladder can&#39;t find the file nowhere.json.", html) || occursin("Ladder can't find the file nowhere.json.", html)
  show_filter(2)
  shot("filter-big.png")
  # Typing in another part of the page doesn't work a filter of a file out again
  before = K.filter_shown!(view(2))
  i = findfirst(==("The end."), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, 0), "Still "); frames()
  @test e.buf.lines[i] == "Still The end." && K.filter_shown!(view(2)) === before
  K.undo!(e.buf); frames()
  @test e.buf.lines[i] == "The end."
end

@testset "a wide table scrolls sideways" begin
  v = show_filter(7)
  widths = v.widths[2]
  room = sum(widths) - (e.width - 2px)
  @test length(widths) == 10 && room > 0px
  at(middle(rect(v.parts[:grid])))
  onscroll(w, Vec2{px}(-10px, 0px)); frames()
  @test v.across == 300px
  onscroll(w, Vec2{px}(-1000px, 0px)); frames()
  @test K.num(v.across) ≈ K.num(room)
  shot("filter-wide.png")
end

@testset "a heading's menu writes the block's lines" begin
  v = show_filter(1)
  click(middle(rect(head(1, "status"))))
  @test menu() !== nothing && v.asking == 2
  # Capitals don't count, so shipped and Shipped are one value
  @test [p for p in K.filter_values(v, 2)] == [("packed", 2), ("shipped", 2), ("waiting", 1)]
  shot("filter-menu.png")
  click(middle(rect(pick(1, :value, "shipped"))))
  @test block(1) == ["from: orders.json", "where: status is shipped"] && [r[1] for r in shown(1)[2:end]] == ["A1", "A3"]
  click(middle(rect(pick(1, :value, "packed"))))
  @test block(1) == ["from: orders.json", "where: status is shipped, packed"] && length(shown(1)) == 5
  # The heading of a column that shows fewer rows is in the accent colour, with a funnel
  @test any(x -> x.column == 2, K.filter_shown!(v).subset.conditions)
  click(middle(rect(pick(1, :desc))))
  @test block(1)[end] == "sort: status, Z to A" && [r[2] for r in shown(1)[2:end]] == ["shipped", "Shipped", "packed", "packed"]
  # Esc puts back the lines that the block had when the menu opened
  key(Keys.escape)
  @test menu() === nothing && block(1) == ["from: orders.json"] && v.asking == 0 && w.focus === e
  # ⌘Z isn't needed for that, but it still takes back each change
  click(middle(rect(head(1, "total"))))
  click(middle(rect(pick(1, :desc))))
  @test block(1) == ["from: orders.json", "sort: total, largest first"] && shown(1)[2][1] == "A3"
  click(middle(rect(pick(1, :desc))))   # a click on the order that the rows have puts them back
  @test block(1) == ["from: orders.json"]
  click(middle(rect(pick(1, :hide))))
  @test menu() === nothing && block(1) == ["from: orders.json", "show: id, status, customer.name, customer.city, tags, note"]
  @test length(shown(1)[1]) == 6
  # A chip says how many columns are hidden, and its × shows them again
  @test K.chip_words(v.parts[(:chip, 0)]) == "1 column hidden"
  frames()
  click(middle(rect(v.parts[(:cross, 0)])))
  @test block(1) == ["from: orders.json"]
end

@testset "a column with many values has a field" begin
  v = show_filter(3)
  d, s = K.filter_shown!(v)
  @test length(s.rows) == 45 && K.filter_values(v, 1) === nothing
  # The table shows the first rows, and a line under them says how many more there are
  @test K.rows_to_show(v, 45) == 30 && K.more_words(v) == "and 15 more rows"
  click(middle(rect(head(3, "Name"))))
  @test menu() !== nothing && w.focus === K.filter_field(v)
  typed("an")
  @test block(3) == ["from: people.csv", "where: Name has an"] && [r[1] for r in shown(3)[2:end]] == ["Ann 1", "Xan 24", "Ann 27"]
  key(Keys.enter)
  @test menu() === nothing && w.focus === e && block(3) == ["from: people.csv", "where: Name has an"]
  shot("filter-field.png")
  # The chip's × takes the condition away
  frames()
  click(middle(rect(v.parts[(:cross, 1)])))
  @test block(3) == ["from: people.csv"]
  # The field at the top adds a condition
  adder = K.filter_adder(v)
  click(middle(rect(adder)))
  @test w.focus === adder
  typed("Age >= 60")
  key(Keys.enter)
  @test block(3) == ["from: people.csv", "where: Age >= 60"] && length(shown(3)) == 7 && adder.text == ""
  typed("Colour is red")
  key(Keys.enter)
  @test block(3)[end] == "where: Colour is red"
  @test K.chip_problem(v.parts[(:chip, 2)]) == "No column is called “Colour”." && length(shown(3)) == 7
  key(Keys.escape)
  @test w.focus === e
  shot("filter-problem.png")
  # A click on the line under the table shows every row
  K.write_block!(v, K.FILTER, ["from: people.csv"]); frames()
  click(middle(rect(v.parts[:more])))
  @test v.whole && K.rows_to_show(v, 45) == 45 && K.more_words(v) == "Show the first 30 rows only"
end

@testset "the rows that show can be saved, and a changed file shows its new rows" begin
  v = view(2)
  out = joinpath(dir, "big.json")
  @test K.save_rows(v, out) == 3
  saved = K.json_value(read(out))
  @test saved isa Vector{Any} && length(saved) == 3 && saved[1].values[1] == "A3" && "tags" in saved[1].keys
  out = joinpath(dir, "big.csv")
  @test K.save_rows(v, out) == 3 && readlines(out) == ["id,customer.name,total", "A3,Cy,1200", "A1,Ann,250", "A5,Ed,130"]
  @test K.save_name(v) == "orders (filtered).json"
  write(orders, """[{"id": "B1", "total": 900}, {"id": "B2", "total": 50}]""")
  frames()
  @test shown(2) == [["id", "total"], ["B1", "900"]] && K.filter_shown!(view(2)).subset.problems == ["No column is called “customer.name”, so it doesn't show."]
end
