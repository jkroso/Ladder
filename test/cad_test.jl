# Tests for the cad/ files that don't need the rest of Ladder or a window:
# JSON, cad/scene.jl, cad/sketch.jl, cad/commands.jl, cad/expressions.jl,
# cad/gl.jl, cad/design.jl and the browser layout helper in cad/view.jl. Run
# them with `julia -O0 --project=. test/cad_test.jl`. The last set needs
# SolidCraft.app, and is skipped without it.

@use Test: @test, @testset, @test_throws
@use "github.com/jkroso/JSON.jl" => JSON
@use "../cad/scene" => Scenes
@use "../cad/sketch" => Sketching
@use "../cad/commands" => Commands
@use "../cad/design" => Models
@use "../cad/engine" => Engines
@use "../cad/view" => V

@testset "JSON" begin
  @test JSON.parse_json("""{"a": [1, 2.5, null, true], "b": "x\\n\\u00e9"}""", JSON.Object) == JSON.Object("a" => Any[1.0, 2.5, nothing, true], "b" => "x\né")
  @test JSON.parse_json(JSON.json(JSON.Object("edges" => [[30, 22.5, 6]], "radius" => "2 mm", "on" => true)), JSON.Object) ==
        JSON.Object("edges" => Any[Any[30.0, 22.5, 6.0]], "radius" => "2 mm", "on" => true)
  @test JSON.json("a\"b\\c\n") == "\"a\\\"b\\\\c\\n\""
  @test_throws JSON.NotJSON JSON.parse_json("{\"a\": }", JSON.Object)
end

"""
The bytes of a .glb file as SolidCraft writes one. Each of `bodies` is a name
and its parts. A part is the name of a look, the look's colour as amounts of
light, corners, the way the surface faces at each corner, and triangles that
name three corners each.
"""
glb(bodies) = begin
  bin = IOBuffer()
  views, accessors, materials, meshes, nodes = Any[], Any[], Any[], Any[], Any[]
  put(rows, T, kind, type) = begin
    at = position(bin)
    foreach(row -> foreach(x -> write(bin, T(x)), row), rows)
    push!(views, JSON.Object("buffer" => 0, "byteOffset" => at, "byteLength" => position(bin) - at))
    write(bin, zeros(UInt8, (4 - position(bin) % 4) % 4))
    push!(accessors, JSON.Object("bufferView" => length(views) - 1, "componentType" => kind, "count" => length(rows), "type" => type))
    length(accessors) - 1
  end
  for (name, parts) in bodies
    primitives = Any[]
    for (look, colour, points, normals, triangles) in parts
      push!(materials, JSON.Object("name" => look, "pbrMetallicRoughness" => JSON.Object("baseColorFactor" => Any[colour..., 1.0])))
      push!(primitives, JSON.Object("attributes" => JSON.Object("POSITION" => put(points, Float32, 5126, "VEC3"), "NORMAL" => put(normals, Float32, 5126, "VEC3")),
                                    "indices" => put([(c - 1,) for t in triangles for c in t], UInt16, 5123, "SCALAR"), "material" => length(materials) - 1))
    end
    push!(meshes, JSON.Object("primitives" => primitives))
    push!(nodes, JSON.Object("name" => name, "mesh" => length(meshes) - 1))
  end
  text = JSON.json(JSON.Object("asset" => JSON.Object("version" => "2.0"), "nodes" => nodes, "meshes" => meshes, "materials" => materials,
                               "accessors" => accessors, "bufferViews" => views, "buffers" => Any[JSON.Object("byteLength" => position(bin))]))
  text *= " "^((4 - sizeof(text) % 4) % 4)
  numbers = take!(bin)
  io = IOBuffer()
  write(io, 0x46546c67, UInt32(2), UInt32(28 + sizeof(text) + length(numbers)), UInt32(sizeof(text)), 0x4e4f534a, text, UInt32(length(numbers)), 0x004e4942, numbers)
  take!(io)
end

@testset "the faces and edges of a body" begin
  # A box of 10 by 10 by 10 as SolidCraft writes it: each of its 6 faces has 4 corners of its own, which all face one way
  corners = [(0, 0, 0), (10, 0, 0), (10, 10, 0), (0, 10, 0), (0, 0, 10), (10, 0, 10), (10, 10, 10), (0, 10, 10)]
  sides = [((1, 4, 3, 2), (0, 0, -1)), ((5, 6, 7, 8), (0, 0, 1)), ((1, 2, 6, 5), (0, -1, 0)), ((2, 3, 7, 6), (1, 0, 0)), ((3, 4, 8, 7), (0, 1, 0)), ((4, 1, 5, 8), (-1, 0, 0))]
  plain = Scenes.PLAIN
  "The box's corners, ways of facing and triangles. With `apart`, the two triangles of the top share no corner."
  box_part(; apart=false) = begin
    points, normals, triangles = [], [], []
    for (k, (around, out)) in enumerate(sides)
      n = length(points)
      if apart && k == 2
        append!(points, corners[collect(around[[1, 2, 3, 1, 3, 4]])]); append!(normals, fill(out, 6)); push!(triangles, (n + 1, n + 2, n + 3), (n + 4, n + 5, n + 6))
      else
        append!(points, corners[collect(around)]); append!(normals, fill(out, 4)); push!(triangles, (n + 1, n + 2, n + 3), (n + 1, n + 3, n + 4))
      end
    end
    points, normals, triangles
  end
  shapes, colours = Scenes.read_glb(glb(["Box" => [("Box", plain, box_part()...)]]))
  @test length(shapes) == 1
  box = shapes[1]
  @test box.name == "Box"
  # The 24 corners of the file are the 8 points of the box
  @test length(box.points) == 8 && length(box.triangles) == 12 && length(box.normals) == 36
  @test length(box.flat) == 6 && all(box.flat)       # six flat faces
  @test length(box.edges) == 12                      # and twelve edges, each between two of them
  @test all(e -> length(e.points) == 2 && !e.closed, box.edges)
  @test (box.low, box.high) == ((0.0, 0.0, 0.0), (10.0, 10.0, 10.0))
  # A look that's named after its body, in SolidCraft's grey, is no colour of the body's own
  @test isempty(colours)
  # The eye sees all of it, and a line of sight through its middle meets its top first when the eye is over it
  eye = Scenes.fit(Scenes.Eye((0.0, 0.0, 0.0), -90.0, 90.0, 100.0, 32.0), Scenes.box(shapes), (400, 300))
  hit = Scenes.hit(shapes, Scenes.ray(eye, (400, 300), (200, 150)))
  @test hit !== nothing && isapprox(hit.point[3], 10.0, atol=1e-6)
  x, y, depth = Scenes.at(eye, (400, 300), (5.0, 5.0, 10.0))
  @test isapprox(x, 200, atol=1e-6) && isapprox(y, 150, atol=1e-6) && depth > 0
  # An edge is found near where it shows
  ex, ey, _ = Scenes.at(eye, (400, 300), (5.0, 0.0, 10.0))
  found = Scenes.edge_at(shapes, eye, (400, 300), (ex, ey + 2), hit)
  @test found !== nothing && isapprox(found[3][2], 0.0, atol=1e-6) && isapprox(found[3][3], 10.0, atol=1e-6)
  # A face is the triangles that share corners in the file. Here the two triangles of the top share none, so they're two faces, with an edge between them.
  split_top = Scenes.read_glb(glb(["Box" => [("Box", plain, box_part(apart=true)...)]]))[1][1]
  @test length(split_top.points) == 8 && length(split_top.flat) == 7 && all(split_top.flat) && length(split_top.edges) == 13
  # A body with a look has the look's colour, as a screen's numbers. A face that was painted is a second part of the body, and its colour isn't the body's.
  top = (corners[[5, 6, 7, 8]], fill((0, 0, 1), 4), [(1, 2, 3), (1, 3, 4)])
  rest = begin
    points, normals, triangles = box_part()
    keep = [t for t in triangles if !all(c -> 5 <= c <= 8, t)]
    (points, normals, keep)
  end
  painted, colours = Scenes.read_glb(glb(["Box" => [("Custom", (0.0782, 0.2122, 0.4621), rest...), ("Custom", (0.0, 1.0, 0.0), top...)], "Bar" => [("Bar", plain, box_part()...)]]))
  @test [s.name for s in painted] == ["Box", "Bar"] && length(painted[1].flat) == 6 && length(painted[1].edges) == 12 && length(painted[1].points) == 8
  @test collect(keys(colours)) == ["Box"] && all(isapprox.(colours["Box"], (0.31, 0.498, 0.71), atol=0.002))
  # A curved face: its corners face different ways
  round_top = begin
    points, normals, triangles = box_part()
    normals[5:8] = [(-0.1, -0.1, 0.99), (0.1, -0.1, 0.99), (0.1, 0.1, 0.99), (-0.1, 0.1, 0.99)]
    Scenes.read_glb(glb(["Box" => [("Box", plain, points, normals, triangles)]]))[1][1]
  end
  @test count(round_top.flat) == 5 && length(round_top.flat) == 6
  # Bytes that are no .glb file, and a file that's cut short, give no bodies
  whole = glb(["Box" => [("Box", plain, box_part()...)]])
  @test isempty(Scenes.read_glb(UInt8[1, 2, 3])[1]) && isempty(Scenes.read_glb(whole[1:end-40])[1]) && isempty(Scenes.read_glb(Vector{UInt8}("glTF" * "x"^40))[1])
  # The bodies that SolidCraft should write a second time, finer: thin for their size, with a curved face
  thin(low, high, flat) = Scenes.Shape("", Scenes.Vec3[], Scenes.Vec3[], NTuple{3,Int}[], Int[], flat, Scenes.Edge[], low, high)
  @test Models.finer(thin((0.0, 0.0, 0.0), (70000.0, 21000.0, 30.0), [false])) == "finest"     # a loop of 30 mm tube, 70 m long
  @test Models.finer(thin((0.0, 0.0, 0.0), (1000.0, 1000.0, 5.0), [true, false])) == "fine"    # a plate with a hole
  @test Models.finer(thin((0.0, 0.0, 0.0), (1000.0, 1000.0, 5.0), [true, true])) === nothing   # a plate with none: flat faces are exact at any quality
  @test Models.finer(thin((0.0, 0.0, 0.0), (440.0, 440.0, 7900.0), [true, false])) === nothing # a drum
end

@testset "the regions of a sketch" begin
  line(id, a, b) = JSON.Object("id" => id, "type" => "line", "start_at" => Any[a...], "end_at" => Any[b...], "construction" => false)
  sketch = JSON.Object("id" => 1, "plane" => JSON.Object("origin" => Any[0, 0, 5], "x_dir" => Any[1, 0, 0], "y_dir" => Any[0, 1, 0]),
    "points" => Any[JSON.Object("id" => "p1", "at" => Any[0, 0])],
    "curves" => Any[line("l1", (0, 0), (40, 0)), line("l2", (40, 0), (40, 20)), line("l3", (40, 20), (0, 20)), line("l4", (0, 20), (0, 0)),
                    JSON.Object("id" => "c1", "type" => "circle", "center_at" => Any[10, 10], "radius" => 5, "construction" => false)])
  r = Sketching.Regions(sketch)
  @test r.count == 2                                         # the circle, and the box round it
  inside, around = Sketching.region(r, (10.0, 10.0)), Sketching.region(r, (30.0, 10.0))
  @test inside >= 2 && around >= 2 && inside != around
  @test Sketching.region(r, (50.0, 10.0)) == 0               # outside the box
  @test Sketching.region(r, Sketching.inside(r, around)) == around
  f = Sketching.Frame(sketch["plane"])
  @test Sketching.world(f, (3.0, 4.0)) == (3.0, 4.0, 5.0)
  @test Sketching.on_plane(f, ((3.0, 4.0, 50.0), (0.0, 0.0, -1.0))) == (3.0, 4.0)
  @test Sketching.nearest(sketch, (0.3, 0.2), 1.0)[1:2] == (:point, "p1")
  @test Sketching.nearest(sketch, (20.0, 0.4), 1.0)[1:2] == (:curve, "l1")
  @test Sketching.fixed(45) == "45.00" && Sketching.length_words(7.126) == "7.13 mm"
  # A spline through points goes through each of them, and bends as SolidCraft's does: this place is from a spline that SolidCraft drew
  points = Sketching.Spot[(0.0, 30.0), (10.0, 40.0), (25.0, 32.0), (40.0, 45.0)]
  curve = Sketching.outline(JSON.Object("type" => "spline", "points_at" => Any[Any[p...] for p in points]))
  @test all(p -> any(q -> hypot(q[1] - p[1], q[2] - p[2]) < 1e-9, curve), points)
  @test Sketching.off((3.925408452, 35.862638949), curve)[1] < 0.02
  # A spline with control points starts at the first and ends at the last, and only comes near the others
  pulled = Sketching.outline(JSON.Object("type" => "spline", "control" => true, "points_at" => Any[Any[0, 50], Any[10, 65], Any[25, 45], Any[40, 60]]))
  @test pulled[1] == (0.0, 50.0) && pulled[end] == (40.0, 60.0) && Sketching.off((10.0, 65.0), pulled)[1] > 3
  @test all(isapprox.(pulled[length(pulled)÷2+1], (18.125, 55.0), atol=1e-6))
end

@testset "the parameters of a command" begin
  spec = Commands.SPECS["solid.fillet"]
  @test Commands.params(spec, Dict("edges" => Any[], "radius" => "2 mm")) == "Choose the edges in the design."
  @test Commands.params(spec, Dict("edges" => Any[Any[1, 2, 3]], "radius" => "2 mm", "tangent_chain" => true)) ==
        JSON.Object("edges" => Any[Any[1, 2, 3]], "radius" => "2 mm", "type" => "constant", "tangent_chain" => true)
  # A form's own fields become the parameters that the command takes: Through All has no distance, and Reverse Direction turns the direction round
  cut = Commands.params(Commands.SPECS["solid.extrude"], Dict("profiles" => Any[JSON.Object("point" => Any[1, 2])], "distance" => "10 mm", "extent" => "through_all",
                                                              "direction" => "positive", "reverse" => true, "operation" => "cut"))
  @test cut["through_all"] === true && !haskey(cut, "distance") && !haskey(cut, "extent") && cut["direction"] == "negative" && !haskey(cut, "reverse")
  # Each field is in a part of the form, as in SolidCraft's forms
  @test [Commands.section(f) for f in Commands.SPECS["solid.extrude"].fields] == ["", "", "", "", "", "", "Options", "Advanced"]
  box = Commands.params(Commands.SPECS["solid.box"], Dict("length" => "20", "width" => "w / 2", "height" => "5 mm", "center" => "0, 0, 2.5", "operation" => "new"))
  @test box["length"] == 20.0 && box["width"] == "w / 2" && box["center"] == Any[0.0, 0.0, 2.5]
  # A command with no form of its own gets one from what SolidCraft says of its parameters
  made = Commands.spec(JSON.Object("id" => "solid.rib", "label" => "Rib", "icon" => "rib", "params" => "sketch, curves"),
    JSON.Object("input" => JSON.Object("required" => Any["thickness"], "properties" => JSON.Object(
      "thickness" => JSON.Object("type" => "string"), "flip" => JSON.Object("type" => "boolean"), "direction" => JSON.Object("enum" => Any["in_plane", "normal"])))))
  @test [f.key => f.kind for f in made.fields] == ["thickness" => :text, "direction" => :choice, "flip" => :flag]
  # A number, or a number that can be text, is Julia code in the form
  numbers = Commands.spec(JSON.Object("id" => "solid.thing", "label" => "Thing", "params" => ""),
    JSON.Object("input" => JSON.Object("required" => Any["count", "size"], "properties" => JSON.Object(
      "count" => JSON.Object("type" => "integer"), "size" => JSON.Object("type" => Any["number", "string"])))))
  @test [f.key => f.kind for f in numbers.fields] == ["count" => :number, "size" => :number]
  @test all(Commands.iscode, numbers.fields)
  # With a reader, a field of code gets what the reader gives for its code
  reader(f, text) = text == "oops" ? "The radius is wrong" : Some(f.key * " is " * text)
  @test Commands.params(spec, Dict("edges" => Any[Any[1, 2, 3]], "radius" => "1mm*2"); read=reader)["radius"] == "radius is 1mm*2"
  @test Commands.params(spec, Dict("edges" => Any[Any[1, 2, 3]], "radius" => "oops"); read=reader) == "The radius is wrong"
end

@testset "Julia code in a field of numbers" begin
  X = V.Expressions
  m = X.workspace()
  X.parameters!(m, [JSON.Object("name" => "d1", "value" => 48.0, "unit" => "mm"), JSON.Object("name" => "tilt", "value" => 30.0, "unit" => "deg")])
  value, failed = X.evaluate(m, "4.5cm + 2mm*1.5")
  @test !failed && X.shown(value) == "48mm"
  @test X.reading(value, :length) == (sent="48 mm", kind="length", number=48.0)
  # The design's parameters are names, a length in mm and an angle in degrees
  @test X.reading(first(X.evaluate(m, "d1/2")), :length).number == 24.0
  @test X.reading(first(X.evaluate(m, "tilt + 15deg")), :angle).sent == "45 deg"
  # What isn't the field's kind of value is wrong
  @test X.reading(first(X.evaluate(m, "2mm*3mm")), :length) isa String       # an area
  @test X.reading(2.5, :count) isa String && X.reading(3.0, :count).sent == "3"
  @test X.reading(first(X.evaluate(m, "0, 0, 10mm")), :vector).sent == Any[0, 0, 10.0]
  # A name that code gives a value stays for the next code
  X.evaluate(m, "wall = 3mm")
  @test X.reading(first(X.evaluate(m, "2wall")), :length).sent == "6 mm"
  value, failed = X.evaluate(m, "1 +")
  @test failed && startswith(X.shown(value, true), "ParseError: ")
  # SolidCraft's text as Julia's, and Julia's as SolidCraft reads it
  @test X.julia_code("8 mm") == "8mm" && X.julia_code("16 in + w/2 - 6") == "16inch + w/2 - 6" && X.julia_code("30 deg") == "30deg"
  @test X.solidcraft_code("π*2mm") == "pi*2mm"
  # A comment keeps the code while the parameter is still the number it came to, under the comment's own words
  note = X.with_code("wall thickness", X.comment("π*2mm", "6.283185307179586 mm"))
  @test note == "wall thickness\nJulia: π*2mm = 6.283185307179586 mm"
  @test X.field_code("6.283185307179586 mm", note) == "π*2mm"
  @test X.field_code("7 mm", note) == "7mm"
  @test X.field_code("6.283185307179586 mm", X.comment("x = 2π*1mm", "6.283185307179586 mm")) == "x = 2π*1mm"
  @test X.with_code(note, nothing) == "wall thickness"
  # The pieces of code have the colours of a code block, and every character is in one
  palette = (number=:N, call=:C, string=:S, comment=:M, keyword=:K, type=:T)
  @test X.pieces("sqrt(2)*10mm", palette) == [4 => :C, 1 => nothing, 1 => :N, 2 => nothing, 2 => :N, 2 => nothing]
  @test sum(first, X.pieces("a = 2mm  # wall", palette)) == length("a = 2mm  # wall")
end

@testset "the browser lays out only the lines in sight" begin
  rows = [V.Press() for _ in 1:100]
  line = V.num(V.ROW_H)
  laid = collect(V.in_sight(rows, 40line, 300.0))
  lines = filter(r -> r isa V.Press, laid)
  @test 12 <= length(lines) < 25 && rows[42] in lines && !(rows[1] in lines) && !(rows[100] in lines)
  # Room above and below keeps each line where it was
  @test !(first(laid) isa V.Press) && !(last(laid) isa V.Press) && lines == rows[findfirst(==(lines[1]), rows) .+ (0:length(lines)-1)]
  # At the top there's no room above, and a short list is all laid out
  @test first(V.in_sight(rows, 0.0, 300.0)) === rows[1]
  @test collect(V.in_sight(rows[1:5], 0.0, 300.0)) == rows[1:5]
end

@testset "a shared framebuffer is deleted in its own context" begin
  screen = V.GLs.Stage()
  if screen === nothing
    @info "macOS gave no OpenGL context, so the shared framebuffer isn't checked"
  else
    s = V.GLs.Stage(screen.cgl)
    was = V.GLs.current()
    V.GLs.setcurrent(screen.cgl)
    try
      V.GLs.picture!(s, 16, 16, Scenes.Eye(), Any[], (0f0, 0f0, 0f0); read=false)
      o = V.GLs.over!(s)
      @test o !== nothing && o.fbo != 0 && V.GLs.glIsFramebuffer(o.fbo) == V.GLs.GL_TRUE
      fbo = o.fbo
      V.GLs.drop!(o)
      @test o.fbo == 0 && V.GLs.glIsFramebuffer(fbo) == V.GLs.GL_FALSE
      # A framebuffer that's retired isn't deleted until destroy_gone! runs
      o2 = V.GLs.over!(s)
      @test o2 !== nothing && o2.fbo != 0 && V.GLs.glIsFramebuffer(o2.fbo) == V.GLs.GL_TRUE
      fbo2 = o2.fbo
      V.GLs.retire!(o2)
      @test V.GLs.glIsFramebuffer(fbo2) == V.GLs.GL_TRUE
      V.GLs.destroy_gone!()
      @test V.GLs.glIsFramebuffer(fbo2) == V.GLs.GL_FALSE
    finally
      V.GLs.setcurrent(was)
    end
    # Changing a DesignView's stage or closing it deletes its framebuffer in the context it was made in
    v = V.DesignView()
    V.GLs.setcurrent(screen.cgl)
    @test V.stage!(v, screen.cgl)
    V.GLs.picture!(v.stage, 16, 16, Scenes.Eye(), Any[], (0f0, 0f0, 0f0); read=false)
    v.parts[:over] = V.GLs.over!(v.stage)
    fbo3 = v.parts[:over].fbo
    @test V.GLs.glIsFramebuffer(fbo3) == V.GLs.GL_TRUE
    V.GLs.setcurrent(was)
    @test !V.stage!(v, C_NULL) && !haskey(v.parts, :over) && V.GLs.current() == was
    V.GLs.setcurrent(screen.cgl)
    try
      @test V.GLs.glIsFramebuffer(fbo3) == V.GLs.GL_FALSE
      @test V.stage!(v, screen.cgl)
      V.GLs.picture!(v.stage, 16, 16, Scenes.Eye(), Any[], (0f0, 0f0, 0f0); read=false)
      v.parts[:over] = V.GLs.over!(v.stage)
      fbo4 = v.parts[:over].fbo
      @test V.GLs.glIsFramebuffer(fbo4) == V.GLs.GL_TRUE
      V.GLs.setcurrent(was)
      V.close!(v)
      @test !haskey(v.parts, :over) && V.GLs.current() == was
      V.GLs.setcurrent(screen.cgl)
      @test V.GLs.glIsFramebuffer(fbo4) == V.GLs.GL_FALSE
    finally
      V.GLs.setcurrent(was)
    end
  end
end

if !Engines.available()
  @info "SolidCraft isn't on this Mac, so the finer-body check is skipped."
else
  @testset "a body that's thin for its size is cut finer" begin
    # A design of its own: a rod 4 mm across and 4 m long, and a block. At SolidCraft's usual quality the rod would have three sides.
    m = Models.open_design(joinpath(mktempdir(), "rod.sc"))
    try
      Models.change!(m, "solid.cylinder", JSON.Object("radius" => 2, "height" => 4000, "operation" => "new", "body_name" => "Rod"))
      Models.change!(m, "solid.box", JSON.Object("length" => 20, "width" => 20, "height" => 20, "corner" => Any[50, 0, 0], "body_name" => "Block"))
      Models.settle!(m)
      @test [s.name for s in m.shapes] == ["Rod", "Block"]
      rod, block = m.shapes
      @test Models.finer(rod) == "finest" && Models.finer(block) === nothing
      # A side of a triangle that slants along the rod's wall stays near the wall: its middle is within a 20th of the
      # radius of it. With three or four sides round the rod, that middle would be 0.6 mm inside.
      from_axis(p) = hypot(p[1], p[2])
      slanting = [(rod.points[t[k]], rod.points[t[mod1(k + 1, 3)]]) for t in rod.triangles for k in 1:3 if rod.points[t[k]][3] != rod.points[t[mod1(k + 1, 3)]][3]]
      @test !isempty(slanting) && all(((a, b),) -> from_axis((a .+ b) ./ 2) > 1.9, slanting)
      @test length(rod.flat) == 3 && count(rod.flat) == 2 && length(rod.edges) == 2 && all(e -> e.closed, rod.edges)
      @test length(block.triangles) == 12 && length(block.flat) == 6 && length(block.edges) == 12
    finally
      Models.close!(m)
    end
  end
end
