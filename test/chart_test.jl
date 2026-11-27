# Tests for chart.jl. Run them with `julia -O0 --project=. test/chart_test.jl`.

@use Test: @test, @testset
@use "../chart" => C
@use "github.com/jkroso/Units.jl/Money" USD
@use "github.com/jkroso/Units.jl" Percent yr

const TABLE = [["Month", "Sales", "Costs", "Note"],
               ["Jan", "\$1,200", "\$800", "slow"],
               ["Feb", "\$1,500.50", "\$900", ""],
               ["Mar", "-", "\$1,000", "wet"]]

@testset "numbers" begin
  @test C.number("12") == (12.0, "", "") && C.number(" 1,234.5 ") == (1234.5, "", "")
  @test C.number("\$1,200") == (1200.0, "\$", "") && C.number("45%") == (45.0, "", "%") && C.number("2.4 m") == (2.4, "", " m")
  @test C.number("-3") == (-3.0, "", "") && C.number("−\$3") == (-3.0, "\$", "") && C.number("**7**") == (7.0, "", "")
  @test C.number("3 days") == (3.0, "", " days") && C.number(".5") == (0.5, "", "")
  # Julia writes a very small or big number with an e, as a sheet shows it
  @test C.number("2.57816e-8%") == (2.57816e-8, "", "%") && C.number("1e6") == (1e6, "", "") && C.number("3E+2 m") == (300.0, "", " m")
  @test C.number("-1.5e-3") == (-1.5e-3, "", "") && C.number("2 eggs") == (2.0, "", " eggs") && C.number("2e") == (2.0, "", " e")
  @test C.number("Jan") === nothing && C.number("") === nothing && C.number("2026-11-16") === nothing && C.number("12 of 14") === nothing
  @test C.words(54.0) == "54" && C.words(14285.714) == "14,285.7" && C.words(0.256) == "0.26" && C.words(-1200) == "−1,200"
  @test C.words(1234567.5) == "1,234,567.5" && C.words(-0.001) == "0"
  @test C.short(20000, 40000) == "20K" && C.short(2.5e6, 5e6) == "2.5M" && C.short(2000, 8000) == "2,000"
  @test C.short(22.4e9, 24e9) == "22.4B"
  # A million and a billion are different amounts, not two small numbers with different words after them
  @test C.number("22.4 billion USD") == (22.4 * 1e9, "", " USD") && C.number("100 million USD") == (100e6, "", " USD")
  @test C.number("€2.5 million") == (2.5e6, "€", "") && C.number("-3 billion USD") == (-3e9, "", " USD")
  @test C.number("1.2 trillion USD")[1] == 1.2e12
  # The unit is on the value. The words in the cell are not what the chart measures.
  @test C.reading(22.4e9USD)[1] == Float64((22.4e9USD).value) && C.reading(100e6USD) == (1.0e8, "", " USD")
  @test C.reading(100e6USD)[1] < C.reading(22.4e9USD)[1] / 100
  # A rate goes right after its number, as the page writes it
  @test C.reading(1.0Percent/yr) == (1.0, "", "%/yr") && C.reading(0.5/yr) == (0.5, "", "/yr")
  @test C.number("1%/yr") == (1.0, "", "%/yr") && C.number("0.5/yr") == (0.5, "", "/yr")
end

@testset "the numbers beside a chart" begin
  @test C.ticks(0, 100) == [0, 20, 40, 60, 80, 100]
  @test C.ticks(0, 1500.5) == [0, 500, 1000, 1500, 2000]
  @test C.ticks(-30, 70) == [-40, -20, 0, 20, 40, 60, 80]
  @test C.ticks(0, 0.9) == [0, 0.2, 0.4, 0.6, 0.8, 1.0]
  @test first(C.ticks(5, 5)) < 5 < last(C.ticks(5, 5)) && first(C.ticks(0, 0)) < 0 < last(C.ticks(0, 0))
end

@testset "reading and writing" begin
  c = C.chart(["kind: lines", "title: Sales and costs", "by: Month", "show: Sales, Costs", "from: Budget", "colour: red"])
  @test c.kind == :lines && c.title == "Sales and costs" && c.by == "Month" && c.show == ["Sales", "Costs"] && c.from == "Budget"
  @test c.other == ["colour: red"] && isempty(c.rows)
  @test C.written(c) == ["kind: lines", "title: Sales and costs", "by: Month", "show: Sales, Costs", "from: Budget", "colour: red"]
  # A block with nothing in it has bars, and the kind can stand by itself
  @test C.chart(String[]).kind == :bars && C.chart(["pie"]).kind == :pie && C.chart(["kind: line"]).kind == :lines
  @test C.written(C.chart(String[])) == ["kind: bars"]
  own = C.chart(["kind: pie", "", "Room | Area", "| Kitchen | 14 m² |", "Lounge | 22 m²"])
  @test own.rows == [["Room", "Area"], ["Kitchen", "14 m²"], ["Lounge", "22 m²"]]
  @test C.written(own) == ["kind: pie", "", "Room | Area", "Kitchen | 14 m²", "Lounge | 22 m²"]
  @test C.chart(C.written(own)).rows == own.rows
end

@testset "what a chart shows" begin
  d = C.data(C.Chart(), TABLE, headed=true)
  @test d.problem == "" && d.labels == ["Jan", "Feb", "Mar"]
  @test [s.name for s in d.series] == ["Sales", "Costs"]
  @test d.series[1].values == [1200.0, 1500.5, nothing] && d.series[2].values == [800.0, 900.0, 1000.0]
  @test d.before == "\$" && d.after == "" && C.amount(d, 1500.5) == "\$1,500.5" && C.amount(d, -20) == "−\$20"
  @test C.extent(d) == (800.0, 1500.5) && C.scale(d, :bars) == [0, 500, 1000, 1500, 2000]
  # The first row is the names of the columns when it has no numbers
  @test C.data(C.Chart(), TABLE).labels == d.labels
  @test C.data(C.Chart(), [["Jan", "3"], ["Feb", "5"]]).labels == ["Jan", "Feb"]
  @test C.data(C.Chart(), [["3"], ["5"], ["4"]]).labels == ["1", "2", "3"]
  # `show` and `by` choose the columns
  c = C.chart(["show: costs", "by: Note"])
  d = C.data(c, TABLE, headed=true)
  @test [s.name for s in d.series] == ["Costs"] && d.labels == ["slow", "", "wet"]
  @test occursin("Profit", C.data(C.chart(["show: Profit"]), TABLE, headed=true).problem)
  @test occursin("Week", C.data(C.chart(["by: Week"]), TABLE, headed=true).problem)
  @test occursin("no numbers", C.data(C.chart(["show: Note"]), TABLE, headed=true).problem)
  @test !isempty(C.data(C.Chart(), Vector{String}[]).problem) && !isempty(C.data(C.Chart(), [["a", "b"], ["c", "d"]]).problem)
  # Lines that are far from 0 don't show it
  far = C.data(C.Chart(), [["a", "90"], ["b", "100"]])
  @test first(C.scale(far, :lines)) > 0 && first(C.scale(far, :bars)) == 0
end

@testset "a pie" begin
  rows = vcat([["Room", "Area"]], [[string("Room ", k), string(k, " m²")] for k in 1:10], [["Hall", "0 m²"], ["Shed", "-"]])
  d = C.data(C.chart(["pie"]), rows)
  @test C.SLICES == C.MOST == 8
  @test length(d.labels) == C.SLICES && d.labels[1] == "Room 10" && d.labels[end] == "Other"
  @test d.series[1].values[end] == 1 + 2 + 3 && sum(d.series[1].values) == 55 && d.after == " m²"
  # A pie of 8 parts shows each of them, with no Other
  eight = C.data(C.chart(["pie"]), rows[1:9])
  @test length(eight.labels) == 8 && !("Other" in eight.labels)
  @test !isempty(C.data(C.chart(["pie"]), [["a", "0"], ["b", "-2"]]).problem)
end

# Each character is 6 wide at size 11, and wider in proportion at any other size
measure(text, size) = 6.0 * length(text) * size / 11

@testset "where the bars go" begin
  d = C.data(C.Chart(), TABLE, headed=true)
  marks = C.plot(d, :bars, 600, 260, measure)
  bars = filter(m -> m.kind == :bar, marks)
  @test length(bars) == 5   # March has no sales
  @test all(m -> m.at[3] <= C.BAR_MOST && m.at[1] >= 0 && m.at[1] + m.at[3] <= 600 && m.at[2] >= 0 && m.at[2] + m.at[4] <= 260, bars)
  # Every bar stands on the line of 0, and a bigger number has a taller bar
  zero = only(m for m in marks if m.kind == :rule && m.style == :strong).at[2]
  @test all(m -> m.at[2] + m.at[4] ≈ zero, bars)
  jan, feb = bars[1], bars[3]
  @test (jan.label, jan.series, feb.label, feb.series) == (1, 1, 2, 1) && feb.at[4] > jan.at[4]
  # Two bars of one month are side by side, with a gap between them
  @test bars[2].at[1] ≈ jan.at[1] + jan.at[3] + C.BAR_GAP
  # Two columns have their names over the chart, and the months are under it
  texts = [m.text for m in marks if m.kind == :words]
  @test all(in(texts), ["Sales", "Costs", "Jan", "Feb", "Mar", "\$0", "\$2,000"])
  @test count(m -> m.kind == :swatch, marks) == 2
  @test C.hit(marks, jan.at[1] + 2, 20).label == 1 && C.hit(marks, 2, 20) === nothing
  @test C.said(d, feb) == "Feb  ·  Sales:  \$1,500.5"
  # One column of numbers has no names over it, and each number is over its bar
  one = C.data(C.chart(["show: Costs"]), TABLE, headed=true)
  marks = C.plot(one, :bars, 600, 260, measure)
  @test count(m -> m.kind == :swatch, marks) == 0 && "\$900" in [m.text for m in marks if m.kind == :words]
  @test C.said(one, first(m for m in marks if m.kind == :bar)) == "Jan:  \$800"
  # A bar of a number under 0 hangs from the line of 0
  under = C.plot(C.data(C.Chart(), [["a", "5"], ["b", "-3"]]), :bars, 400, 200, measure)
  down = only(m for m in under if m.kind == :bar && m.style == :down)
  zero = only(m for m in under if m.kind == :rule && m.style == :strong).at[2]
  @test down.at[2] ≈ zero && down.at[4] > 0
  # A lot of bars have a name under only some of them
  many = C.data(C.Chart(), [[string("Week ", k), string(k)] for k in 1:60])
  marks = C.plot(many, :bars, 400, 200, measure)
  @test count(m -> m.kind == :bar, marks) == 60 && count(m -> m.kind == :words && startswith(m.text, "Week"), marks) < 20
  @test isempty(C.plot(C.data(C.Chart(), Vector{String}[]), :bars, 400, 200, measure))
end

@testset "where the lines and the slices go" begin
  d = C.data(C.Chart(), TABLE, headed=true)
  marks = C.plot(d, :lines, 600, 260, measure)
  lines = filter(m -> m.kind == :line, marks)
  @test length(lines) == 2 && length(lines[1].points) == 2 && length(lines[2].points) == 3
  dots = filter(m -> m.kind == :dot, marks)
  @test length(dots) == 5 && all(m -> m.at[3] == 4, dots)
  @test C.hit(marks, dots[1].at[1] + 3, dots[1].at[2] - 3) === dots[1] && C.hit(marks, dots[1].at[1] + 40, dots[1].at[2] - 40) === nothing
  pie = C.data(C.chart(["pie"]), [["Kitchen", "10 m²"], ["Lounge", "30 m²"]])
  marks = C.plot(pie, :pie, 600, 240, measure)
  slices = filter(m -> m.kind == :slice, marks)
  @test length(slices) == 2 && slices[1].label == 1 && slices[1].at[3] ≈ -π / 2 && slices[1].at[4] ≈ π && slices[2].at[4] ≈ 3π / 2
  cx, cy, r = slices[1].at[1], slices[1].at[2], slices[1].size
  # The first slice starts at the top and goes round by the right
  @test C.hit(marks, cx + r / 2, cy) === slices[1] && C.hit(marks, cx - r / 2, cy - r / 2) === slices[2] && C.hit(marks, cx + 2r, cy) === nothing
  @test C.said(pie, slices[1]) == "Lounge:  30 m²  ·  75%"
  @test "30 m²  ·  75%" in [m.text for m in marks if m.kind == :words]
  # A narrow pie has no room for the shares too, so its names get all the room
  parts = C.data(C.chart(["pie"]), [["Part", "Cost"], ["Converters", "74,996.25 USD"], ["Attitude control", "54,750 USD"],
                                    ["What holds the cells out", "5,109.62 USD"]], headed=true)
  texts = [m.text for m in C.plot(parts, :pie, 420, 204, measure) if m.kind == :words]
  @test texts == ["Converters", "Attitude control", "What holds the cells out"]
  texts = [m.text for m in C.plot(parts, :pie, 900, 204, measure) if m.kind == :words]
  @test "What holds the cells out" in texts && any(t -> endswith(t, "%"), texts)
  # The total is not a slice. A million stays a million, and a billion stays a billion.
  costs = [["Part", "Cost"], ["The satellites", "22.4 billion USD"], ["The launches", "1.65 billion USD"],
           ["The design", "100 million USD"], ["Deorbit", "21 million USD"], ["In all", "24.2 billion USD"]]
  d = C.data(C.chart(["pie"]), costs, headed=true)
  @test d.labels == ["The satellites", "The launches", "The design", "Deorbit"]
  @test d.apart == ("In all", 24.2 * 1e9) && d.after == " USD"
  @test d.series[1].values == [22.4 * 1e9, 1.65 * 1e9, 100e6, 21e6]
  @test C.amount(d, 22.4 * 1e9) == "22.4 billion USD" && C.amount(d, 100e6) == "100 million USD"
  marks = C.plot(d, :pie, 700, 280, measure)
  @test count(m -> m.kind == :slice, marks) == 4
  texts = [m.text for m in marks if m.kind == :words]
  @test all(t -> any(s -> occursin(t, s), texts), ["In all", "24.2 billion USD", "22.4 billion USD", "100 million USD", "21 million USD"])
  bars = C.data(C.Chart(), costs, headed=true)
  @test bars.labels == ["The satellites", "The launches", "The design", "Deorbit"] && bars.apart[1] == "In all"
  @test C.data(C.Chart(), TABLE, headed=true).apart === nothing
  # The cell text says 1 and 2. The amounts are in USD, so the pie uses those.
  money = [["Part", "Cost"], ["Satellites", "1"], ["Design", "2"], ["In all", "3"]]
  amounts = Any[Any[nothing, nothing], Any[nothing, 22.4e9USD], Any[nothing, 100e6USD], Any[nothing, 22.5e9USD]]
  paid = C.data(C.chart(["pie"]), money, headed=true, values=amounts)
  @test paid.series[1].values == [Float64((22.4e9USD).value), 1.0e8]
  @test paid.apart == ("In all", Float64((22.5e9USD).value)) && paid.after == " USD"
end

@testset "a chart as a picture" begin
  d = C.data(C.Chart(), TABLE, headed=true)
  look = (colours=["#2a78d6", "#eb6834"], ink="#222", dim="#777", line="#ddd", surface="#fff")
  for kind in (:bars, :lines)
    picture = C.svg(C.plot(d, kind, 600, 260, measure), 600, 260; look...)
    @test startswith(picture, "<svg") && endswith(picture, "</svg>") && occursin("#eb6834", picture) && occursin(">Feb</text>", picture)
    @test occursin(kind == :bars ? "<path" : "<polyline", picture)
  end
  amp = C.data(C.chart(["pie"]), [["Nuts & bolts", "3"], ["<Glue>", "1"]])
  picture = C.svg(C.plot(amp, :pie, 600, 240, measure), 600, 240; look...)
  @test occursin("Nuts &amp; bolts", picture) && occursin("&lt;Glue&gt;", picture) && occursin("<polygon", picture)
  @test C.fit("A long name of a thing", 60, measure) == "A long na…" && C.fit("Short", 60, measure) == "Short"
end

@testset "the colours of a pie" begin
  # Each slice has the colour of its row in the table, so two pies of one table show a row in the same colour
  parts = [[["Part", "Cost", "Weight"]]; [[string("Part ", k), string(k), string(12 - k)] for k in 1:11]]
  cost = C.data(C.chart(["kind: pie", "show: Cost"]), parts, headed=true)
  weight = C.data(C.chart(["kind: pie", "show: Weight"]), parts, headed=true)
  @test cost.labels[1] == "Part 11" && cost.colours[1] == 11 && weight.labels[1] == "Part 1" && weight.colours[1] == 1
  # Other is a different set of rows in each pie, so it has the colour of no row
  @test cost.labels[end] == weight.labels[end] == "Other" && cost.colours[end] == weight.colours[end] == 0
  both = setdiff(intersect(cost.labels, weight.labels), ["Other"])
  @test both == ["Part 7", "Part 6", "Part 5"]
  @test all(l -> cost.colours[findfirst(==(l), cost.labels)] == weight.colours[findfirst(==(l), weight.labels)], both)
  marks = C.plot(cost, :pie, 600, 240, measure)
  @test [m.colour for m in marks if m.kind == :slice] == [m.colour for m in marks if m.kind == :swatch] == cost.colours
  # A total row and an empty row don't move the colours of the rows after them
  @test C.data(C.chart(["pie"]), [["a", "1"], ["", ""], ["b", "5"], ["Total", "6"]]).colours == [2, 1]
  # Past the last colour, the colours come round again darker, then lighter
  @test C.shade(3, 8) == (3, 0.0) && C.shade(11, 8) == (3, -0.35) && C.shade(19, 8) == (3, 0.4) && C.shade(27, 8) == (3, 0.0)
  two = ["#2a78d6", "#eb6834"]
  @test C.coloured(two, 2) == "#eb6834" && C.coloured(two, 3) == "#1b4e8b" && C.coloured(two, 5) == "#7faee6"
  @test C.coloured(["red", "blue"], 3) == "red"
  eight = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"]
  picture = C.svg(marks, 600, 240, colours=eight, ink="#222", dim="#777", line="#ddd", surface="#fff")
  @test occursin("fill=\"#1b4e8b\"", picture) && occursin("fill=\"#777\"", picture)
  # Bars and lines still have a colour for each column
  @test C.data(C.Chart(), TABLE, headed=true).colours == Int[]
end

@testset "a chart of several tables" begin
  cells = [["Age", "Power"], ["0", "100%"], ["5", "90%"], ["10", "80%"]]
  chips = [["Age", "Working"], ["0", "100%"], ["10", "60%"], ["20", "20%"]]
  c = C.chart(["kind: lines", "from: Cells, Chips"])
  parts = [C.data(c, cells, headed=true, by_first=true, part=true), C.data(c, chips, headed=true, by_first=true, part=true)]
  d = C.joined(c, parts, ["Cells", "Chips"])
  # The names of both go in the order of their numbers, and a name that a table hasn't got is a gap in its line
  @test d.problem == "" && d.labels == ["0", "5", "10", "20"] && [s.name for s in d.series] == ["Power", "Working"]
  @test d.series[1].values == [100.0, 90.0, 80.0, nothing] && d.series[2].values == [100.0, nothing, 60.0, 20.0] && d.after == "%"
  # `show` names columns of any of the tables
  c.show = ["Working"]
  d = C.joined(c, [C.data(c, t, headed=true, by_first=true, part=true) for t in (cells, chips)], ["Cells", "Chips"])
  @test [s.name for s in d.series] == ["Working"] && d.labels == ["0", "10", "20"]
  c.show = ["Heat"]
  @test C.joined(c, [C.data(c, t, headed=true, by_first=true, part=true) for t in (cells, chips)], ["Cells", "Chips"]).problem == "No table has a column called “Heat”."
  # Two columns with one name get the names of their tables, and words stay in the order the tables have them
  c = C.chart(String[])
  d = C.joined(c, [C.data(c, TABLE, headed=true, part=true), C.data(c, [["Month", "Sales"], ["Apr", "\$700"], ["Jan", "\$5"]], headed=true, part=true)], ["2025", "2026"])
  @test d.labels == ["Jan", "Feb", "Mar", "Apr"] && [s.name for s in d.series] == ["Sales (2025)", "Costs", "Sales (2026)"]
  @test d.series[3].values == [5.0, nothing, nothing, 700.0] && d.before == "\$"
  # A table's problem says which table it is
  @test C.joined(c, [C.data(c, TABLE, headed=true, part=true), C.nothing_to_draw("This table has no rows yet.")], ["2025", "2026"]).problem ==
        "The table “2026” has no rows yet."
end

@testset "the names of the axes" begin
  # The heading of the column that names the bars is under the chart. One column of numbers names the numbers on the left.
  d = C.data(C.chart(["show: Costs"]), TABLE, headed=true)
  @test (d.x, d.y) == ("Month", "Costs")
  # Several columns have their names over the chart, so the numbers on the left have none
  @test (C.data(C.Chart(), TABLE, headed=true).x, C.data(C.Chart(), TABLE, headed=true).y) == ("Month", "")
  # The block can name them, or take a name away
  c = C.chart(["x: The month", "y: none"])
  @test (c.x, c.y) == ("The month", "none") && C.written(c) == ["kind: bars", "x: The month", "y: none"]
  d = C.data(c, TABLE, headed=true)
  @test (d.x, d.y) == ("The month", "")
  @test C.data(C.chart(["y: Dollars"]), TABLE, headed=true).y == "Dollars"
  # A table with no headings has no names, and nor do rows that only have their numbers
  @test (C.data(C.Chart(), [["Jan", "3"], ["Feb", "5"]]).x, C.data(C.Chart(), [["3"], ["5"]]).x) == ("", "")
  # When every column is numbers, the first names the rows, as the sizes along the bottom of a line do
  sizes = [["Concurrent tokens (batch)", "Chip throughput (tokens/s)"], ["1", "125"], ["50", "6250"], ["100", "12500"]]
  d = C.data(C.chart(["kind: lines"]), sizes)
  @test d.labels == ["1", "50", "100"] && [s.name for s in d.series] == ["Chip throughput (tokens/s)"]
  @test (d.x, d.y) == ("Concurrent tokens (batch)", "Chip throughput (tokens/s)")
  # unless `show` draws that column
  @test [s.name for s in C.data(C.chart(["show: Concurrent tokens (batch)"]), sizes).series] == ["Concurrent tokens (batch)"]
  # The names go under the chart and at the top of the numbers on the left. The chart is taller by as much, so its lines keep their room.
  marks = C.plot(d, :lines, 600, 260 + C.axis_room(d, :lines), measure)
  words = Dict(m.text => m for m in marks if m.kind == :words)
  under, up, first_size = words["Concurrent tokens (batch)"], words["Chip throughput (tokens/s)"], words["50"]
  @test under.style == :middle && under.at[2] > first_size.at[2] && under.at[2] <= 260 + C.axis_room(d, :lines)
  @test up.style == :start && up.at[2] < minimum(m.at[2] for m in marks if m.kind == :rule)
  plain = C.data(C.chart(["x: none", "y: none"]), sizes)
  @test C.axis_room(plain, :lines) == 0 && C.axis_room(d, :lines) == 2C.AXIS_H && C.axis_room(d, :pie) == 0
  dots(m) = sort([p.at[2] for p in m if p.kind == :dot])
  @test dots(marks) ≈ dots(C.plot(plain, :lines, 600, 260, measure)) .+ C.AXIS_H
  # A total shares its row with the name of the numbers
  costs = [["Part", "Cost"], ["Cells", "3"], ["Chips", "5"], ["In all", "8"]]
  withtotal = C.data(C.Chart(), costs)
  @test withtotal.y == "Cost" && C.axis_room(withtotal, :bars) == C.AXIS_H
  marks = C.plot(withtotal, :bars, 600, 260, measure)
  @test only(m for m in marks if m.text == "Cost").at[2] == only(m for m in marks if startswith(m.text, "In all")).at[2]
  # A picture has them too
  @test occursin(">Concurrent tokens (batch)</text>", C.svg(C.plot(d, :lines, 600, 296, measure), 600, 296, colours=["#2a78d6"], ink="#222", dim="#777", line="#ddd", surface="#fff"))
  # Several tables have a name under the chart when they agree on it
  parts = [C.data(C.chart(String[]), t, headed=true, by_first=true, part=true) for t in ([["Age", "Power"], ["0", "100"]], [["Age", "Working"], ["0", "90"]])]
  @test C.joined(C.chart(String[]), parts, ["Cells", "Chips"]).x == "Age" && C.joined(C.chart(String[]), parts, ["Cells", "Chips"]).y == ""
  parts[2] = C.data(C.chart(String[]), [["Year", "Working"], ["0", "90"]], headed=true, by_first=true, part=true)
  @test C.joined(C.chart(["y: %"]), parts, ["Cells", "Chips"]).x == "" && C.joined(C.chart(["y: %"]), parts, ["Cells", "Chips"]).y == "%"
end
