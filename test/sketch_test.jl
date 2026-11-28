# Tests for sketch.jl. Run them with `julia -O0 --project=. test/sketch_test.jl`.

@use Test: @test, @testset
@use "../blocks/sketch" => S

const BLOCK = ["pen 12,30 14,32.5 18,40", "line 10,10 80,60", "arrow red 10,10 80,60", "box 100,50 200,120",
               "oval blue 300,50 400,150", "text green 120,80 The sink  goes here", "star 1,1 2,2", "box 1,1"]

@testset "reading and writing" begin
  s = S.sketch(BLOCK)
  @test [x.kind for x in s.shapes] == [:pen, :line, :arrow, :box, :oval, :text]
  @test [x.colour for x in s.shapes] == [:ink, :ink, :red, :ink, :blue, :green]
  @test s.shapes[1].points == [(12.0, 30.0), (14.0, 32.5), (18.0, 40.0)] && s.shapes[6].points == [(120.0, 80.0)]
  @test s.shapes[6].text == "The sink goes here" && s.other == ["star 1,1 2,2", "box 1,1"]
  @test S.written(s) == ["pen 12,30 14,32.5 18,40", "line 10,10 80,60", "arrow red 10,10 80,60", "box 100,50 200,120",
                         "oval blue 300,50 400,150", "text green 120,80 The sink goes here", "star 1,1 2,2", "box 1,1"]
  @test S.written(S.sketch(S.written(s))) == S.written(s)
  # The words of a text can start with a number, and a colour's name can be one of them
  t = S.sketch(["text 5,20 3,4 is a place", "text 5,40 red is a colour"])
  @test t.shapes[1].text == "3,4 is a place" && t.shapes[2].text == "red is a colour" && t.shapes[2].colour == :ink
  @test isempty(S.written(S.Sketch())) && S.figure(12.04) == "12" && S.figure(12.26) == "12.3"
end

@testset "how big it is" begin
  s = S.sketch(BLOCK)
  @test S.bounds(s.shapes[4]) == (100.0, 50.0, 200.0, 120.0) && S.bounds(s.shapes[1]) == (12.0, 30.0, 18.0, 40.0)
  l, t, r, b = S.bounds(s.shapes[6])
  @test l == 120 && t < 80 < b && r > 200
  @test S.tall(S.Sketch()) == S.LEAST && S.tall(s) == S.LEAST
  push!(s.shapes, S.Shape(:line, :ink, [(0.0, 0.0), (10.0, 400.0)]))
  @test S.tall(s) == 400 + S.ROOM
end

@testset "what a click is on" begin
  s = S.sketch(BLOCK)
  @test S.hit(s, (45.0, 36.0)) == 3          # on the arrow, which is over the line
  @test S.hit(s, (150.0, 51.0)) == 4 && S.hit(s, (150.0, 75.0)) == 6   # the edge of the box, and the words in it
  @test S.hit(s, (150.0, 108.0)) === nothing # in the box, under the words
  @test S.hit(s, (300.0, 100.0)) == 5 && S.hit(s, (350.0, 100.0)) === nothing   # the edge of the oval, and its middle
  @test S.hit(s, (15.0, 34.0)) == 1 && S.hit(s, (600.0, 200.0)) === nothing
  S.move!(s.shapes[4], 10, -5)
  @test s.shapes[4].points == [(110.0, 45.0), (210.0, 115.0)]
  @test S.slight(S.Shape(:box, :ink, [(5.0, 5.0), (6.0, 6.0)])) && !S.slight(s.shapes[4]) && !S.slight(s.shapes[1])
end

@testset "how a shape is drawn" begin
  s = S.sketch(["box red width 4 radius 12 100,50 200,120", "text size 24 120,80 The sink", "line radius 5 width 0.2 0,0 10,10",
                "oval width 2 radius 3 0,0 10,10", "text 5,20 width 4 is thick", "box width 100,50 200,120"])
  box, text, line, oval, words = s.shapes
  @test (box.width, box.radius, box.colour) == (4.0, 12.0, :red) && (text.size, text.text) == (24.0, "The sink")
  # A number that's too small becomes the least that it can be
  @test line.width == 0.5 && line.radius == 5 && (oval.width, oval.radius, oval.size) == (S.WIDTH, S.RADIUS, S.TEXT_SIZE)
  # After the place of a text, the words are its words. A word with no number after it isn't read.
  @test words.text == "width 4 is thick" && words.width == S.WIDTH && s.other == ["box width 100,50 200,120"]
  @test S.written(s) == ["box red width 4 radius 12 100,50 200,120", "text size 24 120,80 The sink", "line width 0.5 radius 5 0,0 10,10",
                         "oval 0,0 10,10", "text 5,20 width 4 is thick", "box width 100,50 200,120"]
  @test S.settings(box) == (:width, :radius) && S.settings(line) == (:width,) && S.settings(text) == (:size,)
  S.set!(box, :width, 99)
  @test box.width == 24
  # Bigger words take more room, and a thick line is reached from further away
  @test S.bounds(text)[2] == 80 - 24 && S.bounds(text)[3] > S.bounds(S.Shape(:text, :ink, [(120.0, 80.0)], "The sink"))[3]
  thin, thick = S.sketch(["line 0,0 100,0"]), S.sketch(["line width 20 0,0 100,0"])
  @test S.hit(thin, (50.0, 14.0)) === nothing && S.hit(thick, (50.0, 14.0)) == 1
  picture = S.svg(s, colours=(ink="#222", red="#c00", blue="#00c", green="#0a0", orange="#f80"))
  @test occursin("rx=\"12\" fill=\"none\" stroke=\"#c00\" stroke-width=\"24\"", picture) && occursin("font-size=\"24\"", picture)
end

@testset "the places that change a shape" begin
  s = S.sketch(["box 100,50 200,120", "oval 300,50 400,150", "line 10,10 80,60", "pen 0,0 5,5 10,0", "text 5,20 Words"])
  box, oval, line, pen, text = s.shapes
  @test S.handles(box) == [(100.0, 50.0), (200.0, 50.0), (200.0, 120.0), (100.0, 120.0)]
  @test S.handles(oval) == [(300.0, 100.0), (350.0, 50.0), (400.0, 100.0), (350.0, 150.0)]
  @test S.handles(line) == line.points && length(S.handles(pen)) == 3 && isempty(S.handles(text))
  @test S.handle(box, (198.0, 52.0)) == 2 && S.handle(box, (150.0, 85.0)) === nothing && S.handle(text, (5.0, 20.0)) === nothing
  # A corner of a box takes its two sides with it, and the corner across from it stays
  S.pull!(box, 2, (240.0, 30.0))
  @test S.bounds(box) == (100.0, 30.0, 240.0, 120.0)
  # It keeps its number when it's pulled past the corner across from it
  S.pull!(box, 2, (60.0, 140.0))
  @test S.bounds(box) == (60.0, 120.0, 100.0, 140.0) && S.handles(box)[2] == (60.0, 140.0)
  S.pull!(oval, 1, (280.0, 0.0)); S.pull!(oval, 4, (0.0, 170.0))
  @test S.bounds(oval) == (280.0, 50.0, 400.0, 170.0)
  S.pull!(line, 2, (90.0, 5.0)); S.pull!(pen, 2, (5.0, 9.0))
  @test line.points == [(10.0, 10.0), (90.0, 5.0)] && pen.points == [(0.0, 0.0), (5.0, 9.0), (10.0, 0.0)]
  # A thick arrow has a long head
  a, _ = S.barbs(S.sketch(["arrow 0,0 100,0"]).shapes[1])
  b, _ = S.barbs(S.sketch(["arrow width 6 0,0 100,0"]).shapes[1])
  @test a[1] ≈ 89 && b[1] ≈ 81
end

@testset "a line drawn by hand" begin
  straight = [(Float64(x), 10.0 + 0.2 * (x % 2)) for x in 0:50]
  @test S.simplify(straight) == [(0.0, 10.0), (50.0, 10.0)]
  bent = [[(Float64(x), 0.0) for x in 0:20]; [(20.0, Float64(y)) for y in 1:20]]
  @test S.simplify(bent) == [(0.0, 0.0), (20.0, 0.0), (20.0, 20.0)]
  @test S.simplify([(1.0, 1.0)]) == [(1.0, 1.0)]
  a, b = S.barbs((0.0, 0.0), (100.0, 0.0))
  @test a[1] ≈ 89 && b[1] ≈ 89 && a[2] ≈ -b[2] && abs(a[2]) > 3
end

@testset "a sketch as a picture" begin
  s = S.sketch([BLOCK; "text 5,200 Nuts & <bolts>"])
  picture = S.svg(s, colours=(ink="#222", red="#c00", blue="#00c", green="#0a0", orange="#f80"))
  @test startswith(picture, "<svg") && endswith(picture, "</svg>") && occursin("viewBox=\"0 0 720 253\"", picture)
  @test occursin("<rect x=\"100\" y=\"50\" width=\"100\" height=\"70\"", picture) && occursin("<ellipse cx=\"350\" cy=\"100\" rx=\"50\" ry=\"50\"", picture)
  @test occursin("stroke=\"#c00\"", picture) && occursin("Nuts &amp; &lt;bolts&gt;", picture) && count("<polyline", picture) == 4
end
