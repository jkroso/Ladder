# Tests for names that one part of a page has from another, in main.jl and
# sheet.jl: a row of a sheet that uses a measure of a takeoff, a task of a
# time log or a row of another sheet, a sum in a line of text that uses a
# row of a sheet, a sheet that uses a sum in a line of text, a chart of a
# table that has sums, and a node that a sum makes from the page's numbers. Run them with `julia -O0 --project=. test/given_test.jl`.

@use Test: @test, @testset
@use "../main" => K
@use "../sheet" tally known name_values needed
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "./drive" drive
const px = K.px

@testset "a sheet with names from outside it" begin
  given = [("Kitchen floor", "18m^2"), ("Coats", "3")]
  rows = [("Tile", "0.36m^2"), ("Tiles", "ceil(kitchen floor / tile)"), ("Coats", "2"), ("Paint", "coats * 4")]
  @test [r.text for r in tally(rows; given)] == ["0.36m²", "50", "2", "8"]   # a row with the same name takes the name
  @test [r.failed for r in tally(rows)] == [false, true, false, false]
  @test known(rows, 2, given) == ["Kitchen floor", "Coats", "Tile"] && known(rows, 2) == ["Tile"]
  values = Dict(name_values([given; rows]))
  @test values["tiles"] == 50 && values["coats"] == 2 && string(values["kitchen_floor"]) == "18m²"
end

const dir = mktempdir()
const page = joinpath(dir, "kitchen.md")
write(page, """
# Kitchen

```takeoff
scale: 1:100

count | Power point
  10,10 20,20 30,30
area | Kitchen floor
  0,0 283.465,0 283.465,141.7325 0,141.7325
```

```timelog
2026-11-17 08:00-12:00 | Tiling
2026-11-18 08:00-10:30 | Tiling
```

```sheet
Tile = 0.5m^2
Tiles = floor(kitchen floor / tile)
Points = power point
```

The floor takes !`tiles` tiles. Each costs !`price = 12`, so they cost !`tiles * price`.

```sheet
Rate = 80
Labour = tiling / hr * rate
Both = labour + tiles * 12
```

The grout costs !`grout = tiles / 10 * 4`. This sum goes wrong: !`waste = nope(1)`.

```sheet
Tile price = 10 to 20
Floor = tiles * tile price + grout
Bill = floor + price
```

```chart
kind: lines
show: Bill
```

| Room | Cost |
|---|---|
| Kitchen | \$!`kitchen = tiles * price` |
| Laundry | \$!`kitchen / 2` |

```chart
```

| Part | Cost |
|---|---|
| Satellites | !`sats = 22.4e9USD` |
| Design | !`draw = 100e6USD` |
| In all | !`sats + draw` |

```chart
kind: pie
```

The tiles cost this much of the budget: !`ProgressBar(value = price / 24)`. A switch: !`Toggle()`.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1500px))
const (; frames) = drive(w)
frames()
sheet(n) = K.item(e, findall(==("```sheet"), e.buf.lines)[n] + 1).content
results(n) = [r.text for r in sheet(n).results]
said(code) = K.made(e, code, 1)[1]
row!(old, new) = (i = findfirst(==(old), e.buf.lines); K.edit!(e.buf, (i, 0), K.line_end(e.buf, i), new); frames())

@testset "what each kind of block gives" begin
  # 283.465 points of a page at 1:100 are 10 metres
  @test K.block_names(K.TAKEOFF, ["scale: 1:100", "", "count | Power point", "  10,10 20,20 30,30", "length | ", "  0,0 10,0"]) == [("Power point", "3.0")]
  @test K.block_names(K.TIMELOG, ["2026-11-17 08:00-12:00 | Tiling", "2026-11-18 08:00-10:30 | tiling"]) == [("Tiling", "6.5hr")]
  @test K.block_names(K.SHEET, ["A = 1", "2 + 2", " = 3"]) == [("A", "1")]
  @test K.block_names("board", ["x"]) == []
end

@testset "a row uses a measure of the takeoff over it" begin
  @test [name for (name, _) in K.page_given(e, findfirst(==("```sheet"), e.buf.lines))] == ["Power point", "Kitchen floor", "Tiling"]
  @test results(1) == ["0.5m²", "100", "3"]
  # A name from outside shows as a chip, as the name of a row does
  @test any(seg -> seg.face.chip && seg.text == "kitchen floor", sheet(1).exprs[2].lines[1].segs)
end

@testset "a sheet uses a task of the log, and a row of the sheet over it" begin
  @test results(2) == ["80", "520", "1,720"]
  # The first sheet is over the log's names for the second one, and not the other way
  @test length(K.page_given(e, findall(==("```sheet"), e.buf.lines)[2])) == 6
end

@testset "a sum in a line of text uses a row of a sheet" begin
  @test said("tiles") == "100" && said("tiles * price") == "1,200"
  # The sheet changes, and the sums and the next sheet follow
  row!("Tile = 0.5m^2", "Tile = 0.25m^2")
  @test results(1)[2] == "200" && said("tiles") == "200" && said("tiles * price") == "2,400" && results(2)[3] == "2,920"
  # The takeoff changes, and the sheet follows
  row!("  10,10 20,20 30,30", "  10,10 20,20 30,30 40,40")
  @test results(1)[3] == "4"
  K.undo!(e.buf); K.undo!(e.buf); frames()
  @test results(1) == ["0.5m²", "100", "3"] && said("tiles") == "100"
end

@testset "a sheet uses a sum in a line of text over it" begin
  @test K.sum_names("a !`x = 2GW` b !`x * 2` c !`f(y) = 1` !`y=3` !`x == 2` !`farm_cost = 1`") == [("x", "2GW"), ("y", "3"), ("farm cost", "1")]
  @test [r.text for r in tally([("Twice", "farm cost * 2"), ("Again", "farm_cost * 2")]; given=K.sum_names("!`farm_cost = 3`"))] == ["6", "6"]
  third = findall(==("```sheet"), e.buf.lines)[3]
  @test [name for (name, _) in K.page_given(e, third, sums=true)] ==
    ["Power point", "Kitchen floor", "Tiling", "Tile", "Tiles", "Points", "price", "Rate", "Labour", "Both", "grout", "waste"]
  @test !any(n -> n in ("price", "grout"), first.(K.page_given(e, third)))   # the page's code has them already
  # The sheet works out only the names that it reads, so the sum that goes wrong does no harm
  @test first.(needed(K.page_given(e, third, sums=true), [("Tile price", "10"), ("Floor", "tiles * tile price + grout")])) == ["Kitchen floor", "Tile", "Tiles", "grout"]
  @test results(3) == ["10 to 20", "1,040 to 2,040", "1,052 to 2,052"]
  # The chart draws the sheet at each tile price
  d = K.shown!(e.nodes[(:block, K.CHART, page, 1)])
  @test isempty(d.problem) && d.labels[1] == "10" && d.labels[end] == "20" && d.series[1].values[[1, end]] == [1052.0, 2052.0]
  # A drag on a sum changes its number, and the sheet follows
  i = findfirst(l -> occursin("!`price = 12`", l), e.buf.lines)
  at = findfirst("price = 12", e.buf.lines[i])
  K.edit!(e.buf, (i, at.stop - 2), (i, at.stop), "13", typing=true); frames()
  @test said("tiles * price") == "1,300" && results(3) == ["10 to 20", "1,040 to 2,040", "1,053 to 2,053"]
  K.undo!(e.buf); frames()
  @test results(3)[3] == "1,052 to 2,052"
end

@testset "a chart draws what the sums of a table show" begin
  t = only(t for t in K.page_tables(e) if t.rows[1] == ["Room", "Cost"])
  @test t.rows[2:3] == [["Kitchen", "\$1,200"], ["Laundry", "\$600"]]
  chart() = K.shown!(e.nodes[(:block, K.CHART, page, 2)])
  @test chart().labels == ["Kitchen", "Laundry"] && chart().series[1].values == [1200.0, 600.0] && chart().before == "\$"
  # A sum over the table changes, and the chart follows
  i = findfirst(l -> occursin("!`price = 12`", l), e.buf.lines)
  at = findfirst("price = 12", e.buf.lines[i])
  K.edit!(e.buf, (i, at.stop - 2), (i, at.stop), "13", typing=true); frames()
  @test chart().series[1].values == [1300.0, 650.0]
  K.undo!(e.buf); frames()
  @test chart().series[1].values == [1200.0, 600.0]
end

@testset "a chart reads the unit on a sum" begin
  d = K.shown!(e.nodes[(:block, K.CHART, page, 3)])
  sats = get(e.nodes, (:amount, page, "sats = 22.4e9USD", 1), nothing)
  @test sats isa K.Units.Unit && Float64(sats.value) > 1e9
  @test d.labels == ["Satellites", "Design"] && d.apart[1] == "In all" && d.after == " USD"
  @test d.series[1].values[1] == Float64(sats.value) && d.series[1].values[2] == 100e6
  @test d.series[1].values[1] > d.series[1].values[2] * 100
end

@testset "a node that a sum makes follows the numbers that it uses" begin
  @test K.follows("p = ProgressBar(value=x / y)", Set([:x])) && !K.follows("p = ProgressBar(value=1)", Set([:value, :p]))
  @test !K.follows("Toggle()", Set([:price])) && K.follows("let a = price; a end", Set([:price]))
  node(code) = K.made(e, code, 1).value
  bar = "ProgressBar(value = price / 24)"
  @test node(bar).value == 0.5
  node("Toggle()").on = true
  # A sum over them changes. The bar is made again, and the switch stays on.
  i = findfirst(l -> occursin("!`price = 12`", l), e.buf.lines)
  at = findfirst("price = 12", e.buf.lines[i])
  K.edit!(e.buf, (i, at.stop - 2), (i, at.stop), "18", typing=true); frames()
  @test node(bar).value == 0.75 && node("Toggle()").on
  K.undo!(e.buf); frames()
  @test node(bar).value == 0.5 && node("Toggle()").on
end

@testset "a name of the page's code stays as it is" begin
  m = K.workspace(e)
  @test Base.invokelatest(getfield, m, :price) == 12
  i = findfirst(==("Rate = 80"), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, 0), "Sum = 5\nPrice = 99\n"); frames()
  @test Base.invokelatest(getfield, m, :sum) === sum && Base.invokelatest(getfield, m, :price) == 12
  @test said("tiles * price") == "1,200"
end

close(w)

@testset "a sheet takes what a sum over it came to, and doesn't run the sum again" begin
  # How many times the slow sum has run. It's in Main, which the page's code can name.
  runs = Core.eval(Main, :(given_test_runs = Ref(0)))
  slow = joinpath(dir, "slow.md")
  write(slow, """
  A sum that takes long: !`slow = (Main.given_test_runs[] += 1; 5)`. Twice that is !`twice = slow * 2`.

  ```sheet
  Price = 1 to 3
  Cost = price * twice
  ```

  ```chart
  kind: lines
  show: Cost
  ```
  """)
  e2 = K.build_editor(slow)
  w2 = Window(e2, size=(1000px, 800px))
  foreach(_ -> frame(w2), 1:2)
  costs() = [r.text for r in K.item(e2, findfirst(==("```sheet"), e2.buf.lines) + 1).content.results]
  # The sum ran for its line, and the sheet and its chart took its value
  @test costs() == ["1 to 3", "10 to 30"] && runs[] == 1
  @test K.shown!(e2.nodes[(:block, K.CHART, slow, 1)]).series[1].values[[1, end]] == [10.0, 30.0]
  # A sum that the sheet reads changes, and the sheet follows it
  at = findfirst("slow * 2", e2.buf.lines[1])
  K.edit!(e2.buf, (1, at.stop - 1), (1, at.stop), "3", typing=true)
  foreach(_ -> frame(w2), 1:2)
  @test costs() == ["1 to 3", "15 to 45"] && runs[] == 1
  close(w2)
end

@testset "a sum that makes a function is compiled once" begin
  ok(code) = K.in_function(Meta.parse(code), true)
  @test ok("sum(k^2 for k in 1:n)") && ok("let a = n * 2; findfirst(t -> t > a, 1:100) end") && ok("round(x, digits=2)") && ok("(a=1, b=2)")
  # Code that gives a name a value, defines a function or has a macro means something else in a function
  @test !ok("begin w = 5; w * 2 end") && !ok("function f(x) x end") && !ok("@show x") && !ok("for k in 1:3; s += k end")
  @test K.makes_function(Meta.parse("sum(k for k in 1:n)")) && !K.makes_function(Meta.parse("let a = 2; a * n end"))
  p = joinpath(dir, "function.md")
  write(p, """
  There are !`n = 3` of them, which add up to !`total = sum(k for k in 1:n)`. This one gives two names: !`z = begin w = 5; w * 2 end`.
  """)
  e3 = K.build_editor(p)
  w3 = Window(e3, size=(1000px, 600px))
  foreach(_ -> frame(w3), 1:2)
  m = K.workspace(e3)
  @test K.made(e3, "total = sum(k for k in 1:n)", 1)[1] == "6" && Base.invokelatest(getglobal, m, :total) == 6
  f = K.sum_function(m, "total = sum(k for k in 1:n)")
  @test f isa Function
  # n changes, as on a step of a drag, and the sum follows with the same function
  at = findfirst("n = 3", e3.buf.lines[1])
  K.edit!(e3.buf, (1, at.stop - 1), (1, at.stop), "4", typing=true)
  foreach(_ -> frame(w3), 1:2)
  @test K.made(e3, "total = sum(k for k in 1:n)", 1)[1] == "10" && K.sum_function(m, "total = sum(k for k in 1:n)") === f
  # The sum that gives w a value runs as code, so w is a name of the page too
  @test K.made(e3, "z = begin w = 5; w * 2 end", 1)[1] == "10" && K.sum_function(m, "z = begin w = 5; w * 2 end") === nothing
  @test Base.invokelatest(getglobal, m, :w) == 5
  close(w3)
end
