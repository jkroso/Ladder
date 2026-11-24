# Tests for the solids that Ladder makes itself to show what a command of a
# SolidCraft design would make: cad/pieces.jl and cad/preview.jl. Run them
# with `julia -O0 --project=. test/pieces_test.jl`. They need no window. The
# last sets need SolidCraft.app, and check each piece against what
# SolidCraft's program really makes: they're skipped without it.

@use Test: @test, @testset
@use "../cad/pieces" => Pieces
@use "../cad/preview" => Previews
@use "../cad/scene" => Scenes
@use "../cad/sketch" => Sketching
@use "../cad/engine" => Engines
@use "../cad/json" => JSON

const XY = Sketching.Frame((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0))
line(a, b) = Dict{String,Any}("type" => "line", "start_at" => Any[a...], "end_at" => Any[b...])
circle(c, r) = Dict{String,Any}("type" => "circle", "center_at" => Any[c...], "radius" => r)
sketch(curves...; id=1) = Dict{String,Any}("id" => id, "curves" => Any[curves...],
                                           "plane" => Dict{String,Any}("origin" => Any[0, 0, 0], "x_dir" => Any[1, 0, 0], "y_dir" => Any[0, 1, 0]))
rectangle(a, b) = (line(a, (b[1], a[2])), line((b[1], a[2]), b), line(b, (a[1], b[2])), line((a[1], b[2]), a))

"Is every side of every triangle of `s` a side of one other triangle? Then it's closed."
closed(s) = begin
  sides = Dict{NTuple{2,Int},Int}()
  for t in s.triangles, k in 1:3
    key = minmax(t[k], t[mod1(k + 1, 3)])
    sides[key] = get(sides, key, 0) + 1
  end
  all(==(2), values(sides))
end

"The face of `s` whose triangles face the way `w`"
face(s, w) = s.face[findfirst(i -> Pieces.dot(s.normals[3i-2], w) > 0.999, eachindex(s.triangles))]

@testset "the regions of a sketch follow its curves" begin
  # A rectangle with a circle in it: the ring round the circle, and the circle
  a = Pieces.Arrangement(sketch(rectangle((0, 0), (40, 20))..., circle((10, 10), 5)))
  ring, disc = Pieces.region(a, (30.0, 10.0)), Pieces.region(a, (10.0, 10.0))
  @test length(ring.holes) == 1 && isempty(disc.holes)
  @test isapprox(ring.outline.area + ring.holes[1].area, 800 - disc.outline.area)
  @test Pieces.region(a, (50.0, 10.0)) === nothing
  # Two circles that cross make three regions. A loose line and a construction line close nothing off.
  b = Pieces.Arrangement(sketch(circle((0, 0), 10), circle((10, 0), 10), line((-30, 30), (-20, 30)),
                                merge(line((0, 0), (3, 4)), Dict{String,Any}("construction" => true))))
  areas = [Pieces.region(b, p).outline.area for p in ((-5.0, 0.0), (5.0, 0.0), (15.0, 0.0))]
  @test isapprox(areas[1], areas[3]) && areas[2] < areas[1]
  @test count(l -> l.area > 0, b.loops) == 3
  # A line from side to side cuts a rectangle in two
  c = Pieces.Arrangement(sketch(rectangle((0, 0), (40, 20))..., line((15, 0), (15, 20))))
  @test isapprox(Pieces.region(c, (5.0, 5.0)).outline.area, 300) && isapprox(Pieces.region(c, (30.0, 5.0)).outline.area, 500)
end

@testset "a region swept along its plane's normal, and round an axis" begin
  a = Pieces.Arrangement(sketch(rectangle((0, 0), (40, 20))..., circle((10, 10), 5)))
  ring, disc = Pieces.region(a, (30.0, 10.0)), Pieces.region(a, (10.0, 10.0))
  s = Pieces.extrude("ring", XY, Pieces.profile(a, [ring]), 0.0, 10.0)
  @test closed(s) && isapprox(Pieces.volume(s), (800 - disc.outline.area) * 10)
  @test length(s.flat) == 7 && length(s.edges) == 14      # two ends, four sides, the hole's wall
  # Both regions together make the whole block: the side between them isn't a wall
  both = Pieces.extrude("both", XY, Pieces.profile(a, [ring, disc]), 0.0, 10.0)
  @test isapprox(Pieces.volume(both), 8000) && length(both.flat) == 6 && length(both.edges) == 12
  # A taper of 10° makes the far end bigger
  t = Pieces.extrude("t", XY, Pieces.polygon(Sketching.Spot[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)]), 0.0, 7.0; taper=deg2rad(10))
  @test isapprox(t.high[1], 10 + 7tand(10)) && isapprox(t.low[1], -7tand(10))
  # A ring of 10 by 20 turned round the y axis is a tube
  square = Pieces.polygon(Sketching.Spot[(5.0, 0.0), (15.0, 0.0), (15.0, 20.0), (5.0, 20.0)])
  tube = Pieces.revolve("tube", XY, square, (0.0, 0.0, 0.0), (0.0, 1.0, 0.0), 0.0, 2π)
  @test closed(tube) && isapprox(Pieces.volume(tube), π * (15^2 - 5^2) * 20, rtol=1e-3) && length(tube.flat) == 4
  quarter = Pieces.revolve("quarter", XY, square, (0.0, 0.0, 0.0), (0.0, 1.0, 0.0), 0.0, π / 2)
  @test closed(quarter) && isapprox(Pieces.volume(quarter), π * (15^2 - 5^2) * 5, rtol=1e-3)
end

@testset "shapes of their own" begin
  @test isapprox(Pieces.volume(Pieces.box("b", (0.0, 0.0, 10.0), (20.0, 30.0, 20.0))), 12000)
  for (s, v) in ((Pieces.cylinder("c", (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 20, 20), π * 100 * 20),
                 (Pieces.cone("k", (0.0, 0.0, 0.0), (1.0, 0.0, 0.0), 20, 0, 30), π * 100 * 10),
                 (Pieces.sphere("s", (0.0, 0.0, 0.0), 20), 4 / 3 * π * 1000),
                 (Pieces.torus("t", (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 20, 5), 2π^2 * 20 * 25))
    @test closed(s) && isapprox(Pieces.volume(s), v, rtol=5e-3)
  end
  @test Pieces.inside(Pieces.sphere("s", (0.0, 0.0, 0.0), 20), (3.0, 4.0, 5.0)) && !Pieces.inside(Pieces.sphere("s", (0.0, 0.0, 0.0), 20), (9.0, 9.0, 0.0))
end

@testset "faces moved, a shell, a draft, and the pieces on edges" begin
  b = Pieces.box("b", (0.0, 0.0, 5.0), (40.0, 20.0, 10.0))
  top, side, front = face(b, (0.0, 0.0, 1.0)), face(b, (1.0, 0.0, 0.0)), face(b, (0.0, 1.0, 0.0))
  up = Pieces.offset("up", b, [top], 3.0)
  @test closed(up) && isapprox(Pieces.volume(up), 2400) && up.low[3] == 10 && up.high[3] == 13
  two = Pieces.offset("two", b, [top, side], 2.0)
  @test isapprox(Pieces.volume(two), 40 * 20 * 2 + 10 * 20 * 2 + 2 * 2 * 20) && two.high[1] == 22 && two.high[3] == 12
  # A shell 2 mm thick that's open at the top takes out a box 36 by 16 by 8
  hollow = Pieces.hollow("h", b, [top], 2.0)
  @test isapprox(Pieces.volume(hollow), 36 * 16 * 8) && hollow.low == (-18.0, -8.0, 2.0) && hollow.high[3] == 10
  # A draft of 10° on a side keeps the top flat: the wedge goes from the bottom edge to 10 tan 10° in at the top
  wedge, out = Pieces.drafted("d", b, [side], (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), deg2rad(10))
  @test out < 0 && isapprox(Pieces.volume(wedge), 0.5 * 10 * 10tand(10) * 20)
  corner, _ = Pieces.drafted("d", b, [side, front], (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), deg2rad(5))
  @test isapprox(Pieces.volume(corner), 259.91, rtol=1e-4)    # as SolidCraft makes it
  # A fillet of 2 on the top's edge at the side takes away (4 - π) mm² along it. A chamfer of 1 by 2 takes away a triangle.
  edge = findfirst(e -> Set(e.faces) == Set([top, side]), b.edges)
  round, out = Pieces.edge_piece("f", b, edge; r=2.0)
  @test out && closed(round) && isapprox(Pieces.volume(round), (4 - π) * 20, rtol=0.02)
  flat, _ = Pieces.edge_piece("c", b, edge; chamfer=(1.0, 2.0))
  @test isapprox(Pieces.volume(flat), 20)
  # An edge in a corner gets a piece added
  l = Pieces.extrude("L", XY, Pieces.polygon(Sketching.Spot[(0.0, 0.0), (20.0, 0.0), (20.0, 5.0), (5.0, 5.0), (5.0, 20.0), (0.0, 20.0)]), 0.0, 10.0)
  inner = findfirst(e -> all(p -> p[1] == 5 && p[2] == 5, e.points), l.edges)
  fill, out = Pieces.edge_piece("l", l, inner; r=2.0)
  @test !out && isapprox(Pieces.volume(fill), (4 - π) * 10, rtol=0.02)
  # The four edges round the top of a cylinder are one ring, and a ring's edges go on smoothly into each other
  cyl = Pieces.cylinder("c", (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 20, 10)
  @test length(cyl.edges) == 2 && Pieces.chained(cyl, [1]) == [1]
  @test length(Pieces.chained(b, [edge])) == 1          # a box's edges meet at corners, so none goes on from another
end

@testset "bodies moved, mirrored and scaled" begin
  b = Pieces.box("b", (30.0, 0.0, 5.0), (40.0, 20.0, 10.0))
  m = Pieces.mirrored(b, "m", (0.0, 0.0, 0.0), (1.0, 0.0, 0.0))
  @test m.low[1] == -50 && m.high[1] == -10 && isapprox(Pieces.volume(m), 8000)   # mirrored, and its triangles still face out
  t = Pieces.turned(b, "t", (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), π / 2)
  @test all(isapprox.(t.low, (-10.0, 10.0, 0.0), atol=1e-9)) && all(isapprox.(t.high, (10.0, 50.0, 10.0), atol=1e-9))
  s = Pieces.scaled(b, "s", (0.0, 0.0, 0.0), 2)
  @test isapprox(Pieces.volume(s), 64000) && s.high == (100.0, 20.0, 20.0)
  @test length(Pieces.section(b, (30.0, 0.0, 0.0), (1.0, 0.0, 0.0))) == 8 * 6   # the two triangles of each of four sides
end

@testset "what a form's command makes" begin
  b = Pieces.box("Body1", (0.0, 0.0, 5.0), (40.0, 20.0, 10.0))
  sk = sketch(rectangle((0, 0), (40, 20))..., circle((10, 10), 5))
  made(command, params, picks=Dict{String,Any}()) = Previews.made(command, Dict{String,Any}(params...), Dict{String,Any}(), picks, [b], Dict(1 => sk))
  region(at) = Dict{String,Any}("profiles" => Any[(kind=:region, of=2, n=1, at=(at..., 0.0))])
  # An extrude that's Auto cuts where it goes into a body, and joins where it doesn't
  into = made("solid.extrude", ("sketch" => 1, "distance" => "4 mm", "operation" => "auto"), region((10.0, 10.0)))
  @test into.tints[into.shapes[1].name] == :cut && into.ghost == ["Body1"]
  below = made("solid.extrude", ("sketch" => 1, "distance" => "4 mm", "direction" => "negative", "operation" => "auto"), region((10.0, 10.0)))
  @test below.tints[below.shapes[1].name] == :add && isempty(below.ghost) && below.shapes[1].low[3] == -4
  # Through All goes as far as the bodies go
  through = made("solid.extrude", ("sketch" => 1, "through_all" => true, "operation" => "cut"), region((10.0, 10.0)))
  @test through.shapes[1].high[3] > 10
  # A command that has more than its form gives, or one that Ladder doesn't make, is left to SolidCraft
  @test made("solid.extrude", ("sketch" => 1, "distance" => "4 mm", "thin" => true), region((10.0, 10.0))) === nothing
  @test made("solid.sweep", ("profile" => 1,)) === nothing
  @test made("solid.extrude", ("sketch" => 1, "distance" => "4 mm", "direction" => "symmetric", "taper" => "5 deg"), region((10.0, 10.0))) === nothing
  # A body that's moved shows faintly where it was. Removing a body hides it, and a red copy shows in its place.
  moved = made("solid.move", ("bodies" => Any["Body1"], "translate" => Any[0, 0, 20]))
  @test moved.ghost == ["Body1"] && moved.shapes[1].low[3] == 20
  gone = made("solid.remove", ("bodies" => Any["Body1"],))
  @test gone.hide == ["Body1"] && all(==(:cut), values(gone.tints))
  # Deleting a face shows the face red, and Split Body shows where the plane cuts
  @test made("face.delete", ("faces" => Any[Any[20, 0, 5]],), Dict{String,Any}("faces" => Any[(kind=:face, of="Body1", n=1, at=(20.0, 0.0, 5.0))])).faces == [("Body1", 1)]
  @test !isempty(made("solid.split_body", ("body" => "Body1", "plane" => "YZ")).lines)
end

if !Engines.available()
  @info "SolidCraft isn't on this Mac, so the pieces aren't checked against what it makes."
else
  # Each piece against SolidCraft's own result: a block of 40 by 20 by 10, and a sketch of a square beside it
  O(pairs...) = JSON.Object(pairs...)
  const dir = mktempdir()
  const e = Engines.start(joinpath(dir, "pieces.sc"), rooms=[dir])
  Engines.tell(e, "new_design")
  Engines.ask(e, "sketch.create", O("plane" => "XY", "name" => "Base"))
  Engines.ask(e, "sketch.rectangle.center", O("center" => Any[0, 0], "corner" => Any[20, 10]))
  Engines.ask(e, "sketch.finish")
  Engines.ask(e, "solid.extrude", O("distance" => "10 mm", "name" => "Block"))
  Engines.ask(e, "sketch.create", O("plane" => "XY", "name" => "Side"))
  Engines.ask(e, "sketch.rectangle.two_point", O("p0" => Any[25, 0], "p1" => Any[35, 10]))
  Engines.ask(e, "sketch.finish")
  const side = Int(Engines.ask(e, "document.inspect", O("sketch_counts" => true))["sketches"][end]["id"])
  const sketches = Dict(side => Engines.ask(e, "sketch.inspect", O("sketch" => side)))
  "The bodies of the design as SolidCraft writes them"
  bodies() = (f = joinpath(dir, "b$(rand(UInt32)).glb"); Engines.ask(e, "file.export", O("path" => f, "format" => "glb", "quality" => "finest", "hierarchy" => false)); Scenes.read_glb(read(f))[1])
  volume(shapes) = sum(Pieces.volume, shapes; init=0.0)
  box(shapes) = (reduce((a, b) -> min.(a, b), [s.low for s in shapes]), reduce((a, b) -> max.(a, b), [s.high for s in shapes]))
  near(a, b) = all(isapprox.(a[1], b[1], atol=0.02)) && all(isapprox.(a[2], b[2], atol=0.02))
  "What Ladder makes for the command, and what SolidCraft makes: the bodies before and after, and the new ones. The command is taken back after."
  both(command, params, picks=Dict{String,Any}()) = begin
    before = bodies()
    made = Previews.made(command, params, Dict{String,Any}(), picks, before, sketches)
    Engines.ask(e, command, params)
    after = bodies()
    Engines.tell(e, "undo")
    (; made, before, after, new=[s for s in after if !any(b -> b.name == s.name, before)])
  end
  const block = bodies()[1]
  pick(n, at) = (kind=:face, of=block.name, n=n, at=at)
  const top, end_ = face(block, (0.0, 0.0, 1.0)), face(block, (1.0, 0.0, 0.0))

  @testset "extrudes and revolves are where SolidCraft makes them" begin
    square = Dict{String,Any}("profiles" => Any[(kind=:region, of=2, n=side, at=(30.0, 5.0, 0.0))])
    base = O("sketch" => side, "profiles" => Any[O("point" => Any[30, 5])], "operation" => "new")
    for extra in (O("axis" => "y", "angle" => "90 deg"), O("axis" => "x", "angle" => "90 deg"), O("axis" => "Y", "angle" => "120 deg"),
                  O("axis" => "X", "angle" => "45 deg", "direction" => "symmetric"))
      r = both("solid.revolve", merge(base, extra), square)
      @test near(box(r.made.shapes), box(r.new)) && isapprox(volume(r.made.shapes), volume(r.new), rtol=2e-3)
    end
    for extra in (O("distance" => "7 mm"), O("distance" => "7 mm", "direction" => "negative"), O("distance" => "7 mm", "direction" => "symmetric"),
                  O("distance" => "7 mm", "taper" => "10 deg"))
      r = both("solid.extrude", merge(base, extra), square)
      @test near(box(r.made.shapes), box(r.new)) && isapprox(volume(r.made.shapes), volume(r.new), rtol=1e-6)
    end
  end

  @testset "shapes of their own are where SolidCraft makes them" begin
    for (command, params) in (("solid.box", O("length" => "20 mm", "width" => "10 mm", "height" => "6 mm", "center" => Any[50, 0, 10])),
                              ("solid.cylinder", O("diameter" => "20 mm", "height" => "15 mm", "base" => Any[50, 0, 0], "axis" => "X")),
                              ("solid.cone", O("diameter" => "20 mm", "top_diameter" => "8 mm", "height" => "15 mm", "base" => Any[50, 0, 0], "axis" => "Y")),
                              ("solid.sphere", O("diameter" => "20 mm", "center" => Any[50, 0, 0])),
                              ("solid.torus", O("major" => "20 mm", "minor" => "5 mm", "center" => Any[50, 0, 0])))
      r = both(command, merge(params, O("operation" => "new")))
      @test near(box(r.made.shapes), box(r.new)) && isapprox(volume(r.made.shapes), volume(r.new), rtol=5e-3)
    end
  end

  @testset "what holes, fillets, chamfers, shells and drafts take away is what SolidCraft takes away" begin
    for (command, params, picks, rtol) in (
        ("solid.hole", O("position" => Any[5, 2, 10], "depth" => "6 mm", "diameter" => "5 mm"), Dict("position" => Any[pick(top, (5.0, 2.0, 10.0))]), 2e-3),
        ("solid.hole", O("position" => Any[5, 2, 10], "depth" => "6 mm", "diameter" => "5 mm", "tip_angle" => "118 deg"), Dict("position" => Any[pick(top, (5.0, 2.0, 10.0))]), 2e-3),
        ("solid.hole", O("position" => Any[5, 2, 10], "depth" => "6 mm", "diameter" => "5 mm", "type" => "counterbore", "cb_diameter" => "9 mm", "cb_depth" => "2 mm"),
         Dict("position" => Any[pick(top, (5.0, 2.0, 10.0))]), 2e-3),
        ("solid.hole", O("position" => Any[5, 2, 10], "depth" => "6 mm", "diameter" => "5 mm", "type" => "countersink", "cs_diameter" => "9 mm", "cs_angle" => "90 deg"),
         Dict("position" => Any[pick(top, (5.0, 2.0, 10.0))]), 2e-3),
        ("solid.press_pull", O("face" => Any[0, 0, 10], "distance" => "-3 mm"), Dict("face" => Any[pick(top, (0.0, 0.0, 10.0))]), 1e-6),
        ("solid.fillet", O("edges" => Any[Any[20, 0, 10]], "radius" => "2 mm"),
         Dict("edges" => Any[(kind=:edge, of=block.name, n=findfirst(x -> Set(x.faces) == Set([top, end_]), block.edges), at=(20.0, 0.0, 10.0))]), 0.02),
        ("solid.chamfer", O("edges" => Any[Any[20, 0, 10]], "distance" => "1 mm", "distance2" => "3 mm"),
         Dict("edges" => Any[(kind=:edge, of=block.name, n=findfirst(x -> Set(x.faces) == Set([top, end_]), block.edges), at=(20.0, 0.0, 10.0))]), 1e-6),
        ("solid.shell", O("faces" => Any[Any[0, 0, 10]], "thickness" => "2 mm"), Dict("faces" => Any[pick(top, (0.0, 0.0, 10.0))]), 1e-6),
        ("solid.draft", O("faces" => Any[Any[20, 0, 5]], "angle" => "10 deg", "neutral" => "XY"), Dict("faces" => Any[pick(end_, (20.0, 0.0, 5.0))]), 1e-4))
      r = both(command, params, picks)
      @test all(==(:cut), values(r.made.tints)) && isapprox(volume(r.made.shapes), volume(r.before) - volume(r.after); rtol)
    end
    # What Press Pull and Offset Face add is what SolidCraft adds
    r = both("solid.offset_face", O("faces" => Any[Any[0, 0, 10], Any[20, 0, 5]], "distance" => "2 mm"),
             Dict("faces" => Any[pick(top, (0.0, 0.0, 10.0)), pick(end_, (20.0, 0.0, 5.0))]))
    @test all(==(:add), values(r.made.tints)) && isapprox(volume(r.made.shapes), volume(r.after) - volume(r.before))
  end

  @testset "bodies moved and copied go where SolidCraft puts them" begin
    for (command, params) in (("solid.mirror", O("bodies" => Any[block.name], "plane" => "XY")),
                              ("solid.pattern.rectangular", O("bodies" => Any[block.name], "dir1" => Any[1, 0, 0], "count1" => "2", "spacing1" => "50 mm",
                                                              "dir2" => Any[0, 1, 0], "count2" => "2", "spacing2" => "30 mm")),
                              ("solid.pattern.circular", O("bodies" => Any[block.name], "axis" => "X", "count" => "3", "angle" => "90 deg")),
                              ("solid.move", O("bodies" => Any[block.name], "translate" => Any[5, 0, 0], "angle" => "90 deg", "axis" => Any[0, 0, 1], "copy" => true)))
      r = both(command, params)
      @test near(box(r.made.shapes), box(r.new)) && isapprox(volume(r.made.shapes), volume(r.new))
    end
    Engines.ask(e, "solid.move", O("bodies" => Any[block.name], "translate" => Any[30, 0, 0]))
    for (command, params) in (("solid.move", O("bodies" => Any[block.name], "translate" => Any[0, 0, 0], "angle" => "90 deg", "axis" => Any[0, 0, 1])),
                              ("solid.scale", O("bodies" => Any[block.name], "factor" => "2")))
      r = both(command, params)
      @test near(box(r.made.shapes), box(r.after))
    end
    Engines.tell(e, "undo")
  end

  Engines.stop!(e)
end
