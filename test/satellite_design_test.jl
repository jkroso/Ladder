# Tests for pages/satellite_design.jl, which makes the model of the satellite
# from a SolidCraft design. Run them with
# `julia -O0 --project=. test/satellite_design_test.jl`. They open no window.
# The last two sets need SolidCraft.app, and a Mac with none leaves them out.

@use Test: @test, @testset
@use "../pages/satellite_design" => D
@use "../pages/satellite" => S
@use "../cad/engine" => Engines

"Two opposite corners of the box round the shapes of `parts`"
box(parts) = begin
  at = [q for (_, shapes) in parts for (_, s) in shapes for q in s.at]
  reduce((a, b) -> min.(a, b), at), reduce((a, b) -> max.(a, b), at)
end
near(a, b, by) = all(abs.(a .- b) .<= by)

@testset "a body's triangles are shaded smooth only where they're one curve" begin
  # A cube has 8 corners. Three faces meet at each one, at 90°, so each face has its own corner there.
  at = [(x, y, z) for x in (0.0, 1.0) for y in (0.0, 1.0) for z in (0.0, 1.0)]
  quad(a, b, c, d) = [(a, b, c), (a, c, d)]
  cube = vcat(quad(1, 2, 4, 3), quad(5, 7, 8, 6), quad(1, 5, 6, 2), quad(3, 4, 8, 7), quad(1, 3, 7, 5), quad(2, 6, 8, 4))
  s = D.shape(:dark_metal, at, cube, (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  @test length(s.at) == 24 && length(s.corners) == 36
  @test all(n -> count(x -> abs(x) > 0.999, n) == 1, s.facing)
  # Each face looks out of the cube
  @test all(i -> S.dot(s.facing[i], s.at[i] .- (0.5, 0.5, 0.5)) > 0, eachindex(s.at))

  # A bar with 24 flat sides is one curve round its side, with a sharp edge at each end
  n = 24
  ring(y) = [(cos(2π * i / n), y, sin(2π * i / n)) for i in 0:n-1]
  at = vcat(ring(0.0), ring(1.0), [(0.0, 0.0, 0.0), (0.0, 1.0, 0.0)])
  bar = NTuple{3,Int}[]
  for i in 1:n
    j = mod1(i + 1, n)
    push!(bar, (i, i + n, j + n), (i, j + n, j), (2n + 1, i, j), (2n + 2, j + n, i + n))
  end
  s = D.shape(:dark_metal, at, bar, (-1.0, 0.0, -1.0), (1.0, 1.0, 1.0))
  # A corner of the rim is there twice: once for the side and once for the end
  @test length(s.at) == 4n + 2
  side = [i for i in eachindex(s.at) if abs(s.facing[i][2]) < 0.5]
  @test length(side) == 2n
  # On the side, the surface faces straight out from the bar's middle line
  @test all(i -> S.dot(s.facing[i], (s.at[i][1], 0.0, s.at[i][3])) > 0.999, side)
  @test all(i -> abs(s.facing[i][2]) > 0.999, setdiff(eachindex(s.at), side))
end

@testset "where a corner is in its material's pictures" begin
  lo, hi = (2.0, -4.0, 0.0), (4.75, 4.0, 0.002)
  # A cell is 12.5 cm, and the picture has 4 by 4: it starts at the top left of a bay's sunny side
  @test D.place(:cells, (2.0, 4.0, 0.002), (0.0, 0.0, 1.0), lo, hi) == (0.0, 0.0)
  @test D.place(:cells, (2.5, 3.5, 0.002), (0.0, 0.0, 1.0), lo, hi) == (1.0, 1.0)
  # A bay's thin edges and its back show the film between cells
  @test D.place(:cells, (2.5, 3.5, 0.0), (0.0, 0.0, -1.0), lo, hi) == (0.0, 0.0)
  # A foil has its whole picture on each face
  @test D.place(:gold_foil, (4.75, 4.0, 0.002), (0.0, 0.0, 1.0), lo, hi) == (1.0, 0.0)
  @test D.place(:gold_foil, (2.0, -4.0, 0.0), (1.0, 0.0, 0.0), lo, hi) == (0.0, 1.0)
  # The radiator has a tube every 10 cm along it
  @test D.place(:white_paint, (0.0, 0.0, 0.5), (1.0, 0.0, 0.0), (0.0, -1.0, 0.0), (0.02, 1.0, 9.0))[1] ≈ 5.0
  @test D.place(:dark_metal, (1.0, 2.0, 3.0), (1.0, 0.0, 0.0), lo, hi) == (0.0, 0.0)
end

@testset "the steps that build the design" begin
  l = D.lengths(S.sizes())
  @test l.body == 1700.0 && l.loop_d == 30.0 && l.lens == 20.0
  steps = D.steps(l)
  # The numbers that a page gives the design have the page's names, and they and the lengths worked out from them are named first, so that the parts can use the names
  @test keys(D.inputs()) == (:span, :sat_kg, :chord, :loop_d, :loop_out, :rad_high, :lens) && D.inputs().sat_kg == ("2180.0", "")
  @test [given.name for (command, given) in steps if command == "parameters.add"] == vcat(String.(collect(keys(D.inputs()))), first.(D.WORKED))
  names = [given.body_name for (_, given) in steps if haskey(given, :body_name)]
  @test allunique(names) && "Bus" in names && "Top loop" in names
  # Every look that a body gets is one that satellite.jl has a material for
  known = first.(S.MATERIALS)
  @test all(name -> any(l -> l[1] == D.look(name) && l[2][1] in known, D.LOOKS), names)
  @test D.look("Left cells (7)") == "Solar cells" && D.look("Bus") == "Gold foil" && D.look("Top cord, left") == "Pale paint"
  @test D.part_of("Left cells (7)") == "Left wing" && D.part_of("Deck") == "Body" && D.part_of("Front sleeve, top") == "Loops"
  # A radiator with no height keeps a strip, since SolidCraft can't make a box with none
  @test D.lengths(merge(S.sizes(), (rad_high=0.0,))).rad_high == 50.0
end

if Engines.available()
  @testset "SolidCraft builds the design, and its parts are those of satellite.jl" begin
    path = joinpath(mktempdir(), "satellite.sc")
    @test D.build(path) == 81 && isfile(path)
    p = D.program(path)
    try
      names = D.bodies(p)
      @test length(names) == 81 && "Left cells (12)" in names && "Right strut, top" in names
      parts = D.parts(p)
      own = S.satellite(S.sizes())
      @test sort(first.(parts)) == sort(first.(own))
      # The model is as big as the one that satellite.jl makes of its own triangles
      (lo, hi), (own_lo, own_hi) = box(parts), box(own)
      @test near(lo, own_lo, 0.01) && near(hi, own_hi, 0.01)
      # Each part has the same materials
      for (name, shapes) in parts
        theirs = own[findfirst(o -> o[1] == name, own)][2]
        @test Set(first.(shapes)) == Set(first.(theirs))
      end
      # Every triangle names corners that are there, and every corner faces some way
      for (_, shapes) in parts, (_, s) in shapes
        @test all(i -> 1 <= i <= length(s.at), s.corners) && all(n -> abs(S.dot(n, n) - 1) < 1e-6, s.facing)
      end
      # No two bays of cells are quite the same blue
      cells = [s for (name, shapes) in parts if name == "Right wing" for (m, s) in shapes if m == :cells]
      @test length(cells) == 12 && length(unique(s.tint[1] for s in cells)) == 12
      # The size of flat piece that each body got is kept. A loop of tube needed larger pieces than the first size
      # that was tried, and the next reading asks for those at once: one request for each body.
      @test length(D.READ_WITH) == 81 && D.READ_WITH["Top loop"][1] > 0.4 && D.READ_WITH["Top cord, left"][1] < 0.2
      asked = p.asked
      @test box(D.parts(p)) == (lo, hi) && p.asked - asked == 81 + 2
      # With no panel, the radiator is only its bars
      bare = D.parts(p, panel=false)
      @test !any(m == :white_paint for (_, shapes) in bare for (m, _) in shapes)
      # The whole design follows its named lengths
      D.ask(p, "parameters.change", (changes=Dict("reach" => "20000 mm", "chord" => "9000 mm", "deep" => "8000 mm"),))
      lo, hi = box(D.parts(p))
      # The bars at the wings' tips are 60 mm in radius, the bar at the radiator's tip 40 mm and the sleeve at the front 33 mm
      @test near((lo[1], hi[1]), (-21.506, 21.506), 0.01) && near((lo[3], hi[3]), (-8.04, 8.033), 0.01) && hi[2] - lo[2] > 9
    finally
      D.stop!(p)
    end
  end

  @testset "the model follows the page's sums" begin
    D.shut!(); D.MADE[] = nothing
    bytes = D.model(Dict{String,Any}())
    @test bytes[1:4] == b"glTF" && D.OPEN[] !== nothing
    first_parts = D.MADE[][2]
    @test near(box(first_parts)[2][1:1], (35.06,), 0.02)
    # The same sums again ask SolidCraft for nothing
    asked = D.OPEN[][1].asked
    D.model(Dict{String,Any}("span" => 70.0))
    @test D.OPEN[][1].asked == asked && D.MADE[][2] === first_parts
    # A wider span makes each wing longer, and its cells less tall, since their area stays
    D.model(Dict{String,Any}("span" => 100.0))
    lo, hi = box(D.MADE[][2])
    @test D.MADE[][2] !== first_parts && near((hi[1],), (50.06,), 0.02)
    # A size that SolidCraft can't build gives the model of satellite.jl, and the next size works again
    D.shut!()
    @test !isempty(D.made(S.sizes()))
    D.shut!()
    @test D.OPEN[] === nothing
  end
end
