# Tests for chart.jl. Run them with `julia -O0 --project=. test/chart_test.jl`.

@use Test: @test, @testset
@use "../chart" => C

const TABLE = [["Month", "Sales", "Costs", "Note"],
               ["Jan", "\$1,200", "\$800", "slow"],
               ["Feb", "\$1,500.50", "\$900", ""],
               ["Mar", "-", "\$1,000", "wet"]]

@testset "numbers" begin
  @test C.number("12") == (12.0, "", "") && C.number(" 1,234.5 ") == (1234.5, "", "")
  @test C.number("\$1,200") == (1200.0, "\$", "") && C.number("45%") == (45.0, "", "%") && C.number("2.4 m") == (2.4, "", " m")
  @test C.number("-3") == (-3.0, "", "") && C.number("−\$3") == (-3.0, "\$", "") && C.number("**7**") == (7.0, "", "")
  @test C.number("3 days") == (3.0, "", " days") && C.number(".5") == (0.5, "", "")
  @test C.number("Jan") === nothing && C.number("") === nothing && C.number("2026-11-16") === nothing && C.number("12 of 14") === nothing
  @test C.words(54.0) == "54" && C.words(14285.714) == "14,285.7" && C.words(0.256) == "0.26" && C.words(-1200) == "−1,200"
  @test C.words(1234567.5) == "1,234,567.5" && C.words(-0.001) == "0"
  @test C.short(20000, 40000) == "20K" && C.short(2.5e6, 5e6) == "2.5M" && C.short(2000, 8000) == "2,000"
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
  rows = vcat([["Room", "Area"]], [[string("Room ", k), string(k, " m²")] for k in 1:8], [["Hall", "0 m²"], ["Shed", "-"]])
  d = C.data(C.chart(["pie"]), rows)
  @test length(d.labels) == C.SLICES && d.labels[1] == "Room 8" && d.labels[end] == "Other"
  @test d.series[1].values[end] == 1 + 2 + 3 && sum(d.series[1].values) == 36 && d.after == " m²"
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
