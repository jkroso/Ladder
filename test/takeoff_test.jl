# Tests for takeoff.jl. Run them with `julia -O0 --project=. test/takeoff_test.jl`.

@use Test: @test, @testset
@use "../blocks/takeoff" => T

const BLOCK = ["plan: ground-floor.pdf", "page: 2", "scale: 1:100", "scale 2: 1:50", "customer: J Smith", "colour: red", "",
               "count | Double power point | item 412",
               "  120,340 410,380 505,120",
               "  2: 10,10",
               "length | 20mm conduit | item 77 | +10%",
               "  0,0 720,0 720,720",
               "  2: 0,0 72,0",
               "area | Floor tiles",
               "  0,0 720,0 720,720 0,720"]

@testset "reading" begin
  t = T.takeoff(BLOCK)
  @test t.plan == "ground-floor.pdf" && t.page == 2 && t.customer == "J Smith" && t.made == ""
  @test t.scales == Dict(0 => 100.0, 2 => 50.0)
  @test t.other == ["colour" => "red"]
  @test [m.kind for m in t.measures] == [:count, :length, :area]
  @test [m.name for m in t.measures] == ["Double power point", "20mm conduit", "Floor tiles"]
  @test [m.item for m in t.measures] == ["item 412", "item 77", ""]
  @test [m.extra for m in t.measures] == [0.0, 0.1, 0.0]
  @test [s.page for s in t.measures[1].shapes] == [1, 2]
  @test t.measures[2].shapes[1].points == [(0.0, 0.0), (720.0, 0.0), (720.0, 720.0)]
  # An empty block, and lines that say nothing, give an empty takeoff
  @test isempty(T.takeoff(String[]).measures)
  @test isempty(T.takeoff(["", "what", "  1,2 3,4"]).measures)
  # A measure with no item: its waste comes after its name
  bare = T.takeoff(["area | Tiles | +5%"]).measures[1]
  @test bare.extra == 0.05 && bare.item == ""
  @test T.takeoff(["area | Tiles | | +5%"]).measures[1].extra == 0.05
  @test T.written(T.takeoff(["area | Tiles | +5%"])) == ["area | Tiles | +5%"]
  @test T.written(T.takeoff(["area | Tiles | item 4 | +5%"])) == ["area | Tiles | item 4 | +5%"]
  @test T.written(T.takeoff(["count | Taps | item 4"])) == ["count | Taps | item 4"]
  @test T.scale("1:100") == 100 && T.scale("1 : 50") == 50 && T.scale("20") == 20 && T.scale("1/200") == 200
  @test T.scale("big") === nothing && T.scale("1:0") === nothing
end

@testset "writing" begin
  t = T.takeoff(BLOCK)
  @test T.written(t) == BLOCK
  # What's written reads back as the same takeoff
  @test T.written(T.takeoff(T.written(t))) == T.written(t)
  @test T.written(T.Takeoff()) == String[]
  # The marks of a count share lines, ten to a line, a page at a time
  m = T.Measure(:count, "Lights")
  foreach(i -> T.mark!(m, 1, (Float64(i), 2.5)), 1:12)
  T.mark!(m, 3, (7.0, 8.0))
  T.mark!(m, 1, (13.0, 2.5))
  rows = T.drawn(m)
  @test length(rows) == 3
  @test rows[1] == "  " * join(("$i,2.5" for i in 1:10), " ")
  @test rows[2] == "  11,2.5 12,2.5 13,2.5"
  @test rows[3] == "  3: 7,8"
  @test T.number(12.04) == "12" && T.number(12.06) == "12.1" && T.number(-3) == "-3"
end

@testset "what a measure comes to" begin
  t = T.takeoff(BLOCK)
  count, len, area = t.measures
  @test T.amount(t, count) == 4
  # 720 points are 10 inches of paper. At 1:100 that's 25.4 m, and at 1:50 an inch is 1.27 m.
  @test T.amount(t, len) ≈ (2 * 25.4 + 1.27) * 1.1
  @test T.amount(t, area) ≈ 25.4^2
  @test T.shown(:count, 4.0) == "4" && T.shown(:length, 12.346) == "12.35 m" && T.shown(:area, 40.0) == "40 m²"
  # A page with no scale has no lengths yet, and its counts are still counts
  bare = T.takeoff(["length | Pipe", "  0,0 10,0", "count | Taps", "  1,1"])
  @test T.amount(bare, bare.measures[1]) === nothing
  @test T.amount(bare, bare.measures[2]) == 1
  # A scale from a length that's known: 720 points that are 12.7 m make 1:50
  @test T.scale((0.0, 0.0), (720.0, 0.0), 12.7) ≈ 50
  @test T.scale((0.0, 0.0), (0.0, 0.0), 12.7) === nothing
  @test T.inside([(0.0, 0.0), (4.0, 0.0), (4.0, 3.0)]) == 6
  @test T.inside([(0.0, 0.0), (4.0, 3.0), (4.0, 0.0)]) == 6   # the other way round
  @test T.inside([(0.0, 0.0), (4.0, 0.0)]) == 0
end

@testset "the unit of a measure" begin
  # It's written after the kind, and a measure with none is in its kind's own unit
  t = T.takeoff(["scale: 1:100", "", "length in mm | Cable | +10%", "  0,0 720,0", "area in ft² | Tiles", "count | Taps"])
  len, area, taps = t.measures
  @test (len.unit, area.unit, taps.unit) == ("mm", "ft²", "")
  @test (T.unit(len), T.unit(area), T.unit(taps)) == ("mm", "ft²", "Piece")
  @test len.extra == 0.1 && len.name == "Cable"
  @test T.written(t) == ["scale: 1:100", "", "length in mm | Cable | +10%", "  0,0 720,0", "area in ft² | Tiles", "count | Taps"]
  # Its kind's own unit is written as none, and a unit of another kind, or none that Centient knows, is left out
  @test T.takeoff(["length in m | Cable"]).measures[1].unit == ""
  @test T.takeoff(["length in ft² | Cable"]).measures[1].unit == ""
  @test T.takeoff(["length in furlong | Cable"]).measures[1].unit == ""
  @test T.measure("width in mm | Cable") === nothing
  # The amount shows in its unit. A foot and an inch are marks. Less than one shows three figures.
  @test T.shown(len, 25.4) == "25400 mm"
  @test T.shown(:length, 12.54, "km") == "0.0125 km" && T.shown(:length, 3.048, "ft") == "10'" && T.shown(:length, 0.0254, "inch") == "1\""
  @test T.shown(:area, 10_000.0, "hectare") == "1 hectare" && T.shown(:count, 4.0, "Piece") == "4"
  @test T.in_unit(1.0, "mm") ≈ 1000
  @test T.in_unit(1.0, "ft²") ≈ 10.7639 atol=1e-4
  @test T.unit_kind("yard") == :length && T.unit_kind("acre") == :area && T.unit_kind("Piece") == :count && T.unit_kind("hr") === nothing
end

@testset "the kind of measure for an item's unit" begin
  @test all(u -> T.kind_for(u) == :length, ("m", "M", "metre", "Metres", "per metre", "lm", "LM", "lin. m", "lineal metre", "/m", "mm"))
  @test all(u -> T.kind_for(u) == :area, ("m²", "m2", "sqm", "SQM", "sq. m", "square metres", "per m²", "square meter"))
  @test all(u -> T.kind_for(u) == :count, ("Piece", "each", "", "hr", "box", "kg", "L", "pack of 10"))
  @test T.kind_for(nothing) == :count
  # Centient's own names for units
  @test all(u -> T.kind_for(u) == :length, ("ft", "inch", "yard", "mile", "km"))
  @test all(u -> T.kind_for(u) == :area, ("ft²", "acre", "hectare", "km²"))
end

@testset "what's under the mouse" begin
  t = T.takeoff(BLOCK)
  @test T.corner(t, 1, (121.0, 341.0), 5) == (1, 1, 1)
  @test T.corner(t, 1, (721.0, 1.0), 5) in ((2, 1, 2), (3, 1, 2))
  @test T.corner(t, 1, (300.0, 300.0), 5) === nothing
  @test T.corner(t, 2, (10.0, 10.0), 5) == (1, 2, 1)
  # A line is nearer than the outline it's in
  @test T.shape(t, 1, (400.0, 1.0), 5) in ((2, 1), (3, 1))
  @test T.shape(t, 1, (1.0, 400.0), 5) == (3, 1)     # the edge that closes the outline
  @test T.shape(t, 1, (300.0, 500.0), 5) == (3, 1)   # inside it
  @test T.shape(t, 1, (900.0, 900.0), 5) === nothing
  @test T.shape(t, 1, (410.0, 381.0), 5) == (1, 1)
  @test T.shape(t, 2, (36.0, 2.0), 5) == (2, 2)
end

@testset "changing it" begin
  t = T.takeoff(BLOCK)
  T.remove!(t.measures[1], 1, 2)
  @test t.measures[1].shapes[1].points == [(120.0, 340.0), (505.0, 120.0)]
  T.remove!(t.measures[1], 2, 1)
  @test length(t.measures[1].shapes) == 1   # the page's last mark took its shape with it
  T.remove!(t.measures[2], 2, 1)
  @test length(t.measures[2].shapes) == 1   # a line needs two corners
  T.remove!(t.measures[3], 1, 1)
  @test length(t.measures[3].shapes) == 1 && length(t.measures[3].shapes[1].points) == 3
  T.remove!(t.measures[3], 1, 1)
  @test isempty(t.measures[3].shapes)       # an outline needs three
end

@testset "a cut-out is subtracted from its area" begin
  # A wall of 720 by 360 points with a window of 72 by 72: at 1:100 an inch of paper is 2.54 m
  wall = ["scale: 1:100", "", "area | Wall", "  0,0 720,0 720,360 0,360", "  cut 72,72 144,72 144,144 72,144"]
  t = T.takeoff(wall)
  m = only(t.measures)
  @test [s.cut for s in m.shapes] == [false, true]
  @test T.written(t) == wall
  @test T.amount(t, m) ≈ (10 * 5 - 1) * 2.54^2
  # The outline comes to what's left of it, and the cut-out to what it takes away
  @test T.amount(t, m, 1) ≈ 49 * 2.54^2
  @test T.amount(t, m, 2) ≈ 2.54^2
  @test T.outline(m, 2) == 1 && T.outline(m, 1) == 1 && T.cuts(m, 1) == 2:2
  # Only the part of a cut-out that's in the outline is subtracted: half of this one is outside
  half = T.takeoff(["scale: 1:100", "area | Wall", "  0,0 720,0 720,360 0,360", "  cut -72,72 72,72 72,144 -72,144"])
  @test T.amount(half, half.measures[1]) ≈ 49 * 2.54^2
  # Where two cut-outs overlap, that part is subtracted once
  both = T.takeoff(["scale: 1:100", "area | Wall", "  0,0 720,0 720,360 0,360",
                    "  cut 72,72 216,72 216,144 72,144", "  cut 144,72 288,72 288,144 144,144"])
  @test T.amount(both, both.measures[1]) ≈ (50 - 3) * 2.54^2
  # A cut-out that shares an edge with its outline, and one with slanted edges
  @test T.left([(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)], [[(0.0, 0.0), (5.0, 0.0), (5.0, 10.0), (0.0, 10.0)]]) ≈ 50
  @test T.left([(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)], [[(5.0, 2.0), (8.0, 5.0), (5.0, 8.0), (2.0, 5.0)]]) ≈ 100 - 18
  @test T.left([(0.0, 0.0), (10.0, 0.0), (0.0, 10.0)], [[(-5.0, -5.0), (20.0, -5.0), (20.0, 20.0), (-5.0, 20.0)]]) ≈ 0 atol=1e-9
  # A cut-out belongs to the outline above it, and each outline keeps its own
  two = T.takeoff(["scale: 1:100", "area | Walls", "  0,0 72,0 72,72 0,72", "  cut 0,0 36,0 36,36 0,36", "  2: 0,0 72,0 72,72 0,72",
                   "  2: cut 0,0 72,0 72,36 0,36"])
  @test [(s.page, s.cut) for s in two.measures[1].shapes] == [(1, false), (1, true), (2, false), (2, true)]
  @test T.amount(two, two.measures[1]) ≈ (0.75 + 0.5) * 2.54^2
  @test T.written(two)[end] == "  2: cut 0,0 72,0 72,36 0,36"
  # A cut-out with no outline to be cut from, or under a length, is left out
  @test isempty(T.takeoff(["area | Wall", "  cut 0,0 72,0 72,72"]).measures[1].shapes)
  @test length(T.takeoff(["length | Pipe", "  0,0 72,0", "  cut 0,0 72,0 72,72"]).measures[1].shapes) == 1
  # A click in a cut-out finds it before its outline
  @test T.shape(t, 1, (100.0, 100.0), 5) == (1, 2)
  @test T.shape(t, 1, (400.0, 200.0), 5) == (1, 1)
  # An outline that's taken away takes its cut-outs with it, and a cut-out goes by itself
  T.remove!(m, 2)
  @test length(m.shapes) == 1
  t = T.takeoff(wall)
  T.remove!(only(t.measures), 1)
  @test isempty(only(t.measures).shapes)
  t = T.takeoff(wall)
  foreach(_ -> T.remove!(only(t.measures), 1, 1), 1:2)   # an outline with two corners left is none
  @test isempty(only(t.measures).shapes)
end

@testset "drawing a cut-out" begin
  t = T.takeoff(["scale: 1:100", "area | Paint", "  0,0 720,0 720,360 0,360", "length | Skirting", "  0,360 720,360",
                 "area | Plaster", "  0,0 720,0 720,360 0,360", "  2: 0,0 720,0 720,360 0,360"])
  window = [(72.0, 72.0), (144.0, 72.0), (144.0, 144.0), (72.0, 144.0)]
  # It goes after the outline that it's over, on the page that it's drawn on
  @test T.cut!(t, 1, copy(window)) == (1, 2)
  @test t.measures[1].shapes[2].cut && t.measures[1].shapes[2].points == window
  # Drawn again, it takes nothing more from that outline, so the other measure that covers the window takes it
  @test T.cut!(t, 1, copy(window)) == (3, 2)
  @test [s.cut for s in t.measures[3].shapes] == [false, true, false]
  # The measure that's chosen takes it before another that it would take more from
  t = T.takeoff(["area | Small", "  0,0 100,0 100,100 0,100", "area | Big", "  0,0 720,0 720,360 0,360"])
  wide = [(50.0, 50.0), (300.0, 50.0), (300.0, 90.0), (50.0, 90.0)]
  @test T.cut_from(t, 1, wide) == (2, 1)
  @test T.cut_from(t, 1, wide, 1) == (1, 1)
  # Over no outline, it changes nothing
  @test T.cut!(t, 1, [(800.0, 0.0), (900.0, 0.0), (900.0, 50.0)]) === nothing
  @test T.cut!(t, 2, copy(wide)) === nothing
  @test all(m -> length(m.shapes) == 1, t.measures)
end

@testset "snapping to the lines of the plan" begin
  # A room of 200 by 100 points, a wall across it and a curve of three pieces
  lines = T.Line[(100.0, 100.0, 300.0, 100.0), (300.0, 100.0, 300.0, 200.0), (300.0, 200.0, 100.0, 200.0), (100.0, 200.0, 100.0, 100.0),
                 (200.0, 50.0, 200.0, 250.0),
                 (400.0, 100.0, 410.0, 110.0), (410.0, 110.0, 420.0, 130.0), (420.0, 130.0, 425.0, 160.0)]
  l = T.Lines(lines, 600, 400, UInt8[3, 3, 3, 3, 3, 1, 0, 2])
  # The end of a line
  @test T.snap(l, (103.0, 98.0), 8) == ((100.0, 100.0), :corner)
  # Where two lines cross, though neither ends there
  @test T.snap(l, (203.0, 104.0), 8) == ((200.0, 100.0), :crossing)
  # The nearest point of a line, when no corner is near
  @test T.snap(l, (250.0, 96.0), 8) == ((250.0, 100.0), :line)
  @test T.snap(l, (304.0, 150.0), 8) == ((300.0, 150.0), :line)
  # A corner comes before a nearer line
  @test T.snap(l, (106.0, 100.5), 8) == ((100.0, 100.0), :corner)
  # Nothing near
  @test T.snap(l, (150.0, 150.0), 8) === nothing
  @test T.snap(l, (-50.0, -50.0), 8) === nothing
  @test T.snap(T.Lines(), (150.0, 150.0), 8) === nothing
  # The ends of a curve are corners, and the joins of its pieces aren't
  @test T.snap(l, (401.0, 99.0), 5) == ((400.0, 100.0), :corner)
  @test T.snap(l, (426.0, 161.0), 5) == ((425.0, 160.0), :corner)
  @test T.snap(l, (411.0, 109.0), 5)[2] == :line
  # A long slanted line is found all along it, and far from it nothing is
  slant = T.Lines(T.Line[(0.0, 0.0, 3000.0, 2000.0)], 3000, 2000)
  @test all(k -> T.snap(slant, (3k + 2.0, 2k - 1.0), 6) !== nothing, 10:10:990)
  @test T.snap(slant, (1500.0, 900.0), 6) === nothing
  # Many lines: each one is found, and only the ones that are near
  many = T.Lines(T.Line[(Float64(x), 0.0, Float64(x), 1000.0) for x in 0:5:1000], 1000, 1000)
  @test length(T.near(many, (502.0, 500.0), 4)) == 2
  @test T.snap(many, (502.0, 500.0), 4) == ((500.0, 500.0), :line)
  # A corner of something that's already measured is snapped to as well, but not the corner that's being moved
  t = T.takeoff(["area | Floor", "  150,150 180,150 180,180 150,180", "count | Taps", "  160,160"])
  @test T.snap(t, l, 1, (152.0, 151.0), 8) == ((150.0, 150.0), :corner)
  @test T.snap(t, l, 1, (152.0, 151.0), 8, skip=(1, 1, 1)) === nothing
  @test T.snap(t, l, 2, (152.0, 151.0), 8) === nothing        # another page
  @test T.snap(t, l, 1, (161.0, 161.0), 3) === nothing        # the mark of a count isn't a corner
  @test T.snap(t, l, 1, (103.0, 98.0), 8) == ((100.0, 100.0), :corner)
  @test T.snap(t, T.Lines(), 1, (181.0, 181.0), 8) == ((180.0, 180.0), :corner)
end
