# Tests for the editor of a SolidCraft design: see "a SolidCraft design" in
# main.jl, and cad/view.jl. Run them with
# `julia -O0 --project=. test/design_test.jl`. They need SolidCraft.app on
# this Mac, and skip the editor's own checks without it. They make a design of
# their own in a temporary folder, and show it in a window that isn't on the
# screen. Set `LADDER_SHOTS` to a folder, and they save pictures there.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "../cad/json" => JSON
@use "../cad/scene" => Scenes
@use "../cad/sketch" => Sketching
@use "../cad/commands" => Commands
@use "../cad/engine" => Engines
@use "../cad/design" => Models
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Typed Keys onkey onmouse onscroll ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px
const V = K.Designs

@testset "JSON" begin
  @test JSON.parse("""{"a": [1, 2.5, null, true], "b": "x\\n\\u00e9"}""") == JSON.Object("a" => Any[1.0, 2.5, nothing, true], "b" => "x\né")
  @test JSON.parse(JSON.json(JSON.Object("edges" => [[30, 22.5, 6]], "radius" => "2 mm", "on" => true))) ==
        JSON.Object("edges" => Any[Any[30.0, 22.5, 6.0]], "radius" => "2 mm", "on" => true)
  @test JSON.json("a\"b\\c\n") == "\"a\\\"b\\\\c\\n\""
  @test_throws JSON.NotJSON JSON.parse("{\"a\": }")
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

if !Engines.available()
  @info "SolidCraft isn't on this Mac, so the editor's own checks are skipped."
else
  const dir = mktempdir()
  const file = joinpath(dir, "block.sc")
  # A design of its own: a block of 40 by 20 by 10 from a sketch, made with SolidCraft's program
  let e = Engines.start(joinpath(dir, "new.sc"))
    Engines.tell(e, "new_design")
    Engines.ask(e, "sketch.create", JSON.Object("plane" => "XY", "name" => "Base"))
    Engines.ask(e, "sketch.rectangle.center", JSON.Object("center" => Any[0, 0], "corner" => Any[20, 10]))
    Engines.ask(e, "sketch.finish")
    Engines.ask(e, "solid.extrude", JSON.Object("distance" => "10 mm", "name" => "Block"))
    Engines.ask(e, "file.save", JSON.Object("path" => file))
    Engines.stop!(e)
  end

  const e = K.build_editor(file)
  const w = Window(e, size=(1300px, 860px))
  shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
  view() = e.nodes[(:design, file)]
  "Draw frames until SolidCraft's program has answered everything"
  settle() = begin
    frame(w)
    for _ in 1:2000
      Models.busy(view().model) || break
      sleep(0.005)
      frame(w)
    end
    frame(w); frame(w)
  end
  at((x, y)) = (p = Vec2{px}(px(x), px(y)); onmouse(w, MouseMove(p, w)); w.mouse = p; frame(w))
  press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
  release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frame(w))
  click(place) = (press(place); release())
  click(node::K.SemanticUI) = click(rect_middle(node))
  key(k, held...) = begin
    was = w.keys
    foreach(h -> w.keys |= h, held)
    onkey(w, KeyPress{k}(0, w)); onkey(w, KeyRelease{k}(0, w))
    w.keys = was
    frame(w)
  end
  rect_middle(node) = (r = rect(node); (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2)))
  "Hold the keys `held` while `f` runs"
  holding(f, held...) = (was = w.keys; foreach(h -> w.keys |= h, held); try f() finally w.keys = was end)
  "Where the point `p` of the design shows in the window"
  shows(p) = V.shown_at(view(), p)
  frame(w)
  settle()

  @testset "a design opens in the editor" begin
    v = view()
    m = v.model
    @test isempty(m.problem) && isempty(m.said)
    @test [s["name"] for s in Models.timeline(m)] == ["Base", "Block"]
    @test length(m.shapes) == 1 && length(m.shapes[1].flat) == 6 && length(m.shapes[1].edges) == 12
    @test m.shapes[1].high == (20.0, 10.0, 10.0)
    @test K.page_covered(e)                       # it fills the page, with no text round it
    @test v.fitted && v.tab == "Model"
    shot("design-1-open.png")
  end

  @testset "a button's tip is in the page's font, which has ⌘" begin
    # The tip is made when the mouse moves, where no theme is set. In UI.jl's own font, Helvetica, ⌘ was a box.
    at(rect_middle(view().parts[:undo]))
    tip = only(p for p in popups(w) if p.key == :tooltip)
    words = first(tip.content.content.children)
    @test words.content == "Undo (⌘Z)" && words.family == K.SANS
    V.hide_tooltip!(w)
  end

  @testset "the editor has the page's colours" begin
    was = e.theme
    for name in (:sepia, :paper, :night)
      e.theme = name
      K.restyle!(e)
      settle()
      t = V.theme(view())
      @test t.surface == K.colours.float && t.text == K.colours.ink && t.accent == K.colours.accent
      # Behind the design is a little darker than the panels, as in SolidCraft. In the night theme too.
      @test all(V.palette(t).back .< V.rgba(t.surface)[1:3])
    end
    e.theme = was
    K.restyle!(e)
    settle()
  end

  @testset "the mouse lights what it's over, and a click selects it" begin
    v = view()
    top = shows((0.0, 0.0, 10.0))
    at(top)
    @test v.hover !== nothing && v.hover.kind == :face
    click(top)
    @test length(v.picked) == 1 && v.picked[1].kind == :face
    edge = shows((0.0, -10.0, 10.0))
    at(edge)
    @test v.hover.kind == :edge
    key(Keys.escape)
    @test isempty(v.picked)
  end

  @testset "a fillet from its form" begin
    v = view()
    V.start!(v, "solid.fillet")
    frame(w)
    @test v.form !== nothing && v.form.active == "edges"
    click(shows((0.0, -10.0, 10.0)))
    @test length(v.form.values["edges"]) == 1
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && isempty(v.model.said)
    @test length(Models.timeline(v.model)) == 3
    @test length(v.model.shapes[1].flat) == 7     # the round is one more face, and it's curved
    @test count(!, v.model.shapes[1].flat) == 1
    @test Models.edited(v.model)
    shot("design-2-fillet.png")
    # ⌘Z takes it back
    key(Keys.z, Keys.cmd)
    settle()
    @test length(Models.timeline(v.model)) == 2 && length(v.model.shapes[1].flat) == 6
  end

  @testset "a sketch is drawn in" begin
    v = view()
    click(v.parts[(:step, 1)]); click(v.parts[(:step, 1)])       # two clicks on the sketch's step of the history
    settle()
    @test Models.editing(v.model) == 1 && v.tab == "Sketch"
    @test v.eye.tilt == 90.0                                      # it's seen flat
    s = V.sketch(v)
    before = length(s["curves"])
    V.start!(v, "sketch.circle.center")
    f = Sketching.Frame(s["plane"])
    click(shows(Sketching.world(f, (5.0, 2.0))))
    click(shows(Sketching.world(f, (8.0, 2.0))))
    settle()
    s = V.sketch(v)
    @test length(s["curves"]) == before + 1
    @test s["curves"][end]["type"] == "circle" && isapprox(s["curves"][end]["radius"], 3.0, atol=0.05)
    shot("design-3-sketch.png")
    key(Keys.escape)
    # A dimension on the circle, and a new length for it
    click(shows(Sketching.world(f, (8.0, 2.0))))
    @test length(v.picked) == 1 && v.picked[1].kind == :curve
    V.start!(v, "sketch.dimension")
    settle(); settle()
    @test any(p -> p.key == :ask, popups(w))
    box = w.focus
    box.text = ""; box.cursor = box.anchor = 0
    foreach(c -> ontype(w, Typed(c, w)), "8")
    # The field takes Julia code: ⌘Return shows what it comes to, and the field stays
    @test V.iscode(box)
    key(Keys.enter, Keys.cmd)
    @test any(p -> p.key == :ask, popups(w)) && V.outcomes(view())[box].shown == "8"
    key(Keys.enter)
    settle()
    @test isapprox(V.sketch(v)["curves"][end]["radius"], 4.0, atol=1e-6)
    V.start!(v, "sketch.finish")
    settle()
    @test Models.editing(v.model) === nothing && v.tab == "Model"
    @test length(v.model.shapes) == 1
  end

  @testset "an extrude of a region of a sketch" begin
    v = view()
    m = v.model
    Models.change!(m, "browser.visibility", JSON.Object("items" => Any[1], "visible" => true))
    settle()
    @test haskey(m.sketches, 1)
    V.start!(v, "solid.extrude")
    frame(w)
    @test v.form.active == "profiles"
    f = Sketching.Frame(m.sketches[1]["plane"])
    # The circle is under the block's top, so the view is from under the block
    v.eye = Scenes.fit(Scenes.Eye(v.eye.target, -90.0, -90.0, v.eye.distance, 0.0), Scenes.box(m.shapes), (v.area[3], v.area[4]))
    frame(w)
    click(shows(Sketching.world(f, (5.0, 2.0))))
    @test length(v.form.shows["profiles"]) == 1 && v.form.shows["profiles"][1].kind == :region
    v.form.values["operation"] = "cut"
    v.form.values["extent"] = "through_all"
    shot("design-4-extrude.png")
    key(Keys.enter)
    settle()
    @test v.form === nothing && isempty(m.said)
    @test count(!, m.shapes[1].flat) == 1          # the hole's wall
  end

  @testset "a step's lengths are changed in its form" begin
    v = view()
    m = v.model
    click(v.parts[(:step, 2)]); click(v.parts[(:step, 2)])       # two clicks on the block's step
    settle()
    @test v.form !== nothing && v.form.step == 2 && length(v.form.inputs) == 1
    box = v.parts[(:field, "step", String(v.form.inputs[1]["param"]))]
    @test box.text == "10mm"                    # SolidCraft's 10 mm, as Julia writes it
    box.text = "14mm"
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && isempty(m.said)
    @test isapprox(m.shapes[1].high[3], 14.0, atol=1e-9)
    shot("design-5-taller.png")
  end

  @testset "a field of numbers takes Julia code, and ⌘Return runs it" begin
    v = view()
    m = v.model
    steps = length(Models.timeline(m))
    V.start!(v, "solid.fillet")
    frame(w)
    click(shows((0.0, -10.0, 10.0)))
    box = v.parts[(:field, "solid.fillet", "radius")]
    @test box.text == "2mm" && V.iscode(box)
    # Its pieces have the colours of the page's code, in the font of code
    box.text = "1.5mm + 2mm*0.25"
    pieces = box.colours(box.text)
    @test sum(first, pieces) == length(box.text) && pieces[1] == (3 => K.colours.number)
    @test box.font_family == K.codefont()
    # ⌘Return runs the code that's selected, and what it comes to shows under the field. The form stays.
    click(box)
    @test w.focus === box
    box.anchor, box.cursor = 8, 16                     # 2mm*0.25
    key(Keys.enter, Keys.cmd)
    @test v.form !== nothing && V.outcomes(v)[box].shown == "0.5mm" && !V.outcomes(v)[box].failed
    # With nothing selected, it runs all of the code
    box.anchor = box.cursor = 0
    key(Keys.enter, Keys.cmd)
    @test V.outcomes(v)[box].shown == "2mm" && V.outcome(v, box) !== nothing
    shot("design-7-julia.png")
    # What went wrong shows in red
    box.text = "1.5mm + nothing_here"
    key(Keys.enter, Keys.cmd)
    @test V.outcomes(v)[box].failed && occursin("nothing_here", V.outcomes(v)[box].shown)
    # SolidCraft reads `1.5mm + 2mm*0.25` as Julia does, so it keeps the code itself
    box.text = "1.5mm + 2mm*0.25"
    @test V.outcome(v, box) === nothing                # the code has changed since it ran
    frame(w)                                           # the box under the field has gone, so OK is higher
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && isempty(m.said) && length(Models.timeline(m)) == steps + 1
    fillet = last(Models.timeline(m))["name"]
    p = only(p for p in m.parameters if get(p, "feature", "") == fillet)
    @test p["expression"] == "1.5mm + 2mm*0.25" && p["value"] == 2.0 && p["comment"] == ""
    key(Keys.z, Keys.cmd)
    settle()
    @test length(Models.timeline(m)) == steps
  end

  @testset "code that SolidCraft reads in another way is kept in a comment" begin
    v = view()
    m = v.model
    open_step() = (click(v.parts[(:step, 2)]); click(v.parts[(:step, 2)]); settle())
    open_step()
    param = String(v.form.inputs[1]["param"])
    @test v.parts[(:field, "step", param)].text == "14mm"
    undo = Models.undos(m)
    # Julia's 2 + 1cm is 3 cm. SolidCraft reads it as 2 mm and 1 cm.
    v.parts[(:field, "step", param)].text = "2 + 1cm"
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && isempty(m.said)
    @test isapprox(m.shapes[1].high[3], 30.0, atol=1e-9)
    p = V.param_named(v, param)
    @test p["expression"] == "30 mm" && p["comment"] == "Julia: 2 + 1cm = 30 mm"
    # The field shows the code again
    open_step()
    @test v.parts[(:field, "step", param)].text == "2 + 1cm"
    click(v.parts[(:form, :cancel)])
    frame(w)
    # ⌘Z takes back the change and its comment together, and ⇧⌘Z does both again
    key(Keys.z, Keys.cmd)
    settle()
    @test Models.undos(m) == undo && isapprox(m.shapes[1].high[3], 14.0, atol=1e-9) && V.param_note(v, param) == ""
    key(Keys.z, Keys.cmd, Keys.shft)
    settle()
    @test Models.undos(m) == undo + 2 && V.param_note(v, param) == "Julia: 2 + 1cm = 30 mm"
    key(Keys.z, Keys.cmd)
    settle()
    @test Models.undos(m) == undo
    # Code that's wrong says so in the form, and nothing changes
    open_step()
    v.parts[(:field, "step", param)].text = "14mm + nothing_here"
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form !== nothing && occursin("nothing_here", v.form.problem) && Models.undos(m) == undo
    click(v.parts[(:form, :cancel)])
    frame(w)
  end

  @testset "the parameters" begin
    v = view()
    m = v.model
    V.start!(v, "parameters")
    frame(w)
    @test v.panel == :params
    name, value = v.parts[(:newparam, :name)], v.parts[(:newparam, :value)]
    name.text, value.text = "wall", "3mm"
    click(v.parts[(:newparam, :add)])
    settle()
    @test any(p -> p["name"] == "wall" && p["value"] == 3.0, Models.params(m))
    # A parameter's field takes code too. Return sets it, and what SolidCraft got a number for shows as its code.
    box = v.parts[(:param, "wall")]
    @test box.text == "3mm" && V.iscode(box)
    click(box)
    box.text = "π*1mm"
    key(Keys.enter)
    settle()
    # SolidCraft reads π as pi, so it gets that, and the comment keeps the code as it was typed
    @test V.param_named(v, "wall")["expression"] == "pi*1mm" && V.param_note(v, "wall") == "Julia: π*1mm = pi*1mm" && box.text == "π*1mm"
    # Code that's wrong shows what's wrong under the field, which keeps the keyboard
    click(box)
    box.text = "π*"
    key(Keys.enter)
    @test w.focus === box && V.outcomes(v)[box].failed && V.outcome(v, box) !== nothing
    box.text = "3mm"
    key(Keys.enter)
    settle()
    @test V.param_named(v, "wall")["expression"] == "3mm"
    shot("design-6-parameters.png")
    key(Keys.escape)
    @test v.panel == :none
  end

  @testset "a new sketch on a face" begin
    v = view()
    m = v.model
    V.fit!(v)
    v.eye = Scenes.fit(Scenes.Eye(v.eye.target, -35.0, 28.0, v.eye.distance, 32.0), Scenes.box(m.shapes), (v.area[3], v.area[4]))
    frame(w)
    V.start!(v, "sketch.create")
    frame(w)
    @test v.form.active == "plane"
    click(shows((-10.0, -5.0, 14.0)))                             # the block's top
    @test v.form.values["plane"] isa AbstractDict
    key(Keys.enter)
    settle()
    @test Models.editing(m) !== nothing && v.tab == "Sketch" && isempty(m.said)
    @test v.eye.tilt == 90.0
    s = V.sketch(v)
    @test isapprox(Sketching.Frame(s["plane"]).origin[3], 14.0, atol=1e-6)
    V.start!(v, "sketch.rectangle.two_point")
    f = Sketching.Frame(s["plane"])
    click(shows(Sketching.world(f, (-15.0, -6.0))))
    click(shows(Sketching.world(f, (-9.0, -2.0))))
    settle()
    @test count(c -> c["type"] == "line" && get(c, "link", nothing) === nothing && c["construction"] == false, V.sketch(v)["curves"]) >= 4
    shot("design-7-new-sketch.png")
    V.start!(v, "sketch.finish")
    settle()
    @test Models.editing(m) === nothing && v.eye.tilt == 28.0     # the view is as it was before the sketch
  end

  @testset "the view turns, moves and comes nearer" begin
    v = view()
    V.fit!(v); frame(w)
    was = v.eye
    empty = (330.0, 680.0)                                        # a place of the picture with no body and no panel
    @test V.panel_at(v, w, Vec2{px}(px(empty[1]), px(empty[2]))) === nothing
    press(empty); at((380.0, 660.0)); release()                   # a drag turns it
    @test v.eye.turn != was.turn && v.eye.tilt != was.tilt && isempty(v.picked)
    was = v.eye
    at(empty)
    onscroll(w, Vec2{px}(px(0), px(30)), false); frame(w)                  # two fingers move it
    @test v.eye.target != was.target && v.eye.distance == was.distance
    was = v.eye
    holding(Keys.cmd) do
      onscroll(w, Vec2{px}(px(0), px(30)), false); frame(w)                # and with ⌘ bring it nearer
    end
    @test v.eye.distance < was.distance
    # A click on the ball of the z axis looks straight down
    ball = v.spots[findfirst(s -> s.what.kind == :look && s.what.of == 3 && s.what.n == 1, v.spots)]
    click((v.area[1] + ball.box[1] + 10, v.area[2] + ball.box[2] + 10))
    @test v.eye.tilt == 90.0
    click(v.parts[:home])
    @test (v.eye.turn, v.eye.tilt) == (-35.0, 28.0)
    click(v.parts[:wide])
    @test v.eye.wide == 0.0
    click(v.parts[:wide])
    @test v.eye.wide > 0
    # The wheel over the browser is the browser's, and not the design's
    was = v.eye
    at(rect_middle(v.parts[:browser]))
    onscroll(w, Vec2{px}(px(0), px(30)), false); frame(w)
    @test v.eye == was
  end

  @testset "the browser and the history" begin
    v = view()
    m = v.model
    click(v.parts[(:eye, :body, "Body1")])
    settle()
    @test !Models.shown(m, "Body1")
    click(v.parts[(:eye, :body, "Body1")])
    settle()
    @test Models.shown(m, "Body1")
    # Two clicks on a body's line ask for its new name
    click(v.parts[(:body, "Body1")]); click(v.parts[(:body, "Body1")])
    frame(w)
    @test any(p -> p.key == :ask, popups(w))
    w.focus.text = "Block"
    key(Keys.enter)
    settle()
    @test [b["name"] for b in Models.bodies(m)] == ["Block"]
    # The history rolls back and on
    click(v.parts[:back])
    settle()
    @test Models.marker(m) == length(Models.timeline(m)) - 1
    click(v.parts[:last])
    settle()
    @test Models.marker(m) == length(Models.timeline(m))
    # A right click on a step shows its menu over the step. It looks as the menu of a table's column does.
    step = rect_middle(v.parts[(:step, 2)])
    right_click() = (at(step); w.keys |= Keys.mouse_right; onkey(w, KeyPress{Keys.mouse_right}(0, w)); w.keys ⊻= Keys.mouse_right;
                     onkey(w, KeyRelease{Keys.mouse_right}(0, w)); frame(w))
    menu() = only(p for p in popups(w) if p.key == V.MENU_KEY)
    right_click()
    @test menu().content isa V.Menu
    @test menu().content.title == uppercase(Models.timeline(m)[2]["name"])
    @test [it isa Pair ? it.second : it for it in menu().content.items] == ["Edit", "Rename", "Suppress", "Roll the history to here", "-", "Delete"]
    @test K.num(menu().scene.top + menu().scene.height) < step[2]
    # The arrows light a line, past the rule, and Return picks it
    key(Keys.up); key(Keys.up)
    @test menu().content.active == 4
    key(Keys.down); key(Keys.down)
    @test menu().content.active == 1
    key(Keys.down); key(Keys.down)
    @test menu().content.active == 3
    key(Keys.enter)
    settle()
    @test !any(p -> p.key == V.MENU_KEY, popups(w))
    @test get(Models.timeline(m)[2], "suppressed", false) === true
    # A click on a line picks it too. The step is suppressed now, so its menu has Unsuppress.
    right_click()
    @test menu().content.items[3] == ("eye" => "Unsuppress")
    click(menu().content.lines[3])
    settle()
    @test !any(p -> p.key == V.MENU_KEY, popups(w))
    @test get(Models.timeline(m)[2], "suppressed", false) !== true
    right_click()
    key(Keys.escape)
    @test !any(p -> p.key == V.MENU_KEY, popups(w))
    # The menu of a group lists the commands that have no button, each with its icon
    click(v.parts[(:group, "Model", "Create")]); frame(w)
    @test menu().content isa V.Menu && all(it -> it isa Pair && !isempty(it.first), menu().content.items)
    key(Keys.escape)
  end

  @testset "a command with no form of its own" begin
    v = view()
    V.start!(v, "solid.thread")
    settle()
    @test v.form !== nothing && v.form.spec.title == "Thread"
    @test any(f -> f.key == "face" && f.kind == :face, v.form.spec.fields)
    @test !isempty(v.form.spec.help)
    shot("design-8-any-command.png")
    key(Keys.escape)
    @test v.form === nothing
  end

  @testset "the tools of a sketch" begin
    v = view()
    m = v.model
    V.edit_step!(v, 1)
    settle()
    s = V.sketch(v)
    f = Sketching.Frame(s["plane"])
    place(p) = shows(Sketching.world(f, p))
    count_of(kind) = count(c -> c["type"] == kind, V.sketch(v)["curves"])
    lines = count_of("line")
    # A line of two parts: three clicks, then Return
    ontype(w, Typed('l', w)); frame(w)
    @test v.tool isa Commands.Tool && v.tool.command == "sketch.line"
    click(place((-15.0, 4.0))); click(place((-10.0, 7.0))); settle()
    click(place((-4.0, 5.0))); settle()
    key(Keys.enter)
    @test count_of("line") == lines + 2 && isempty(v.clicks)
    key(Keys.escape)
    @test v.tool === nothing
    # The first of them is made level by the button of that constraint
    first_line = V.sketch(v)["curves"][end-1]
    click(place((-12.5, 5.5)))
    @test [p.of for p in v.picked] == [first_line["id"]]
    marks = length(V.sketch(v)["constraints"])
    click(v.parts[(:tool, "sketch.constraint.horizontal_vertical")])
    settle()
    @test length(V.sketch(v)["constraints"]) == marks + 1 && isempty(m.said)
    level = V.sketch(v)["curves"][end-1]
    @test isapprox(level["start_at"][2], level["end_at"][2], atol=1e-9) || isapprox(level["start_at"][1], level["end_at"][1], atol=1e-9)
    # A constraint with too little selected says what it needs
    click(v.parts[(:tool, "sketch.constraint.parallel")])
    frame(w)
    @test occursin("Select two things", m.said)
    m.said = ""
    # X makes what's selected a line to build with, and ⌫ takes it out
    last_line = V.sketch(v)["curves"][end]
    mid = ((last_line["start_at"][1] + last_line["end_at"][1]) / 2, (last_line["start_at"][2] + last_line["end_at"][2]) / 2)
    click(place(mid))
    ontype(w, Typed('x', w)); settle()
    @test V.sketch(v)["curves"][end]["construction"] == true
    @test length(v.picked) == 1                                   # it's still selected
    key(Keys.backspace)
    settle()
    @test count_of("line") == lines + 1
    # A drag moves a point as far as its constraints let it
    moved = V.sketch(v)["curves"][end]
    from, to = place(Tuple(moved["start_at"])), place((moved["start_at"][1], moved["start_at"][2] + 3))
    press(from)
    for k in 1:4
      at((from[1] + (to[1] - from[1]) * k / 4, from[2] + (to[2] - from[2]) * k / 4)); settle()
    end
    release(); settle()
    @test V.sketch(v)["curves"][end]["start_at"][2] > moved["start_at"][2] + 1
    # Trim cuts a piece of a line away: the circle from the earlier test loses the part that's clicked
    circles, arcs = count_of("circle"), count_of("arc")
    V.start!(v, "sketch.line")
    click(place((5.0, -8.0))); click(place((5.0, 9.0))); settle()
    key(Keys.escape); key(Keys.escape)
    V.start!(v, "sketch.trim")
    click(place((9.0, 2.0)))
    settle()
    @test count_of("circle") == circles - 1 && count_of("arc") == arcs + 1
    shot("design-9-sketch-tools.png")
    V.start!(v, "sketch.cancel")
    settle()
    @test Models.editing(m) === nothing
  end

  @testset "the colours of bodies and faces" begin
    v = view()
    m = v.model
    theme = K.component_theme()
    solid() = only(t for t in V.things(v, (v.area[3], v.area[4]), 1.0, theme) if t isa V.GLs.Solid)
    name = String(Models.bodies(m)[1]["name"])
    @test isempty(m.colours) && isempty(m.painted)
    grey = solid().colour
    @test grey[1] ≈ grey[2] atol = 0.05                           # a body with no colour of its own is grey
    Models.change!(m, "appearance.assign", JSON.Object("bodies" => Any[name], "color" => "#d9534a"))
    settle()
    @test all(isapprox.(m.colours[name], (0.851, 0.325, 0.29), atol=0.002))
    @test all(isapprox.(solid().colour, (0.851f0, 0.325f0, 0.29f0, 1f0), atol=0.002))
    @test !solid().through
    # One face in another colour: it's found again from the point that SolidCraft names it by
    Models.change!(m, "appearance.assign", JSON.Object("faces" => Any[Any[-10.0, -5.0, 14.0]], "body" => name, "color" => "#f0c83c"))
    settle()
    @test length(m.painted) == 1
    top = Scenes.hit(m.shapes, ((-10.0, -5.0, 50.0), (0.0, 0.0, -1.0))).face
    @test [p.first for p in solid().painted] == [top]
    @test all(isapprox.(solid().painted[1].second, (0.941f0, 0.784f0, 0.235f0, 1f0), atol=0.002))
    frame(w)
    shot("design-10-colours.png")
    # A body that's partly see-through is drawn after the lines, so that what's behind it shows
    Models.change!(m, "appearance.assign", JSON.Object("bodies" => Any[name], "color" => "#4a90d9", "opacity" => 0.4))
    settle()
    @test m.opacity[name] == 0.4 && solid().through && solid().colour[4] ≈ 0.4f0
    frame(w)
    shot("design-11-see-through.png")
    # With no colour, it's grey again
    Models.change!(m, "appearance.assign", JSON.Object("bodies" => Any[name]))
    settle()
    @test !haskey(m.colours, name) && !haskey(m.opacity, name) && solid().colour == grey
  end

  "The things that the graphics card draws now"
  drawn() = (v = view(); V.things(v, (v.area[3], v.area[4]), 1.0, V.theme(v)))
  "Draw frames until the command of the open form has been tried, and give what it made"
  tried() = begin
    v = view()
    for _ in 1:600
      frame(w)
      t = v.model.trial
      v.form !== nothing && t !== nothing && !v.model.trying && t.key == v.form.key && return t
      sleep(0.01)
    end
    nothing
  end
  home() = (v = view(); v.eye = Scenes.fit(Scenes.Eye(), Scenes.box(v.model.shapes), (v.area[3], v.area[4])); frame(w))
  "Click an edge of the first body that shows, and that no panel is over"
  click_edge() = begin
    v = view()
    for edge in v.model.shapes[1].edges
      place = shows(Scenes.middle(edge))
      (place === nothing || V.panel_at(v, w, Vec2{px}(px(place[1]), px(place[2]))) !== nothing) && continue
      at(place)
      (v.hover !== nothing && v.hover.kind == :edge) || continue
      return click(place)
    end
  end

  @testset "the faces of a body are SolidCraft's own" begin
    m = view().model
    @test !isempty(m.shapes)
    for s in m.shapes
      listed = Engines.ask(m.engine, "model.faces", JSON.Object("body" => s.name))["faces"]
      @test length(s.flat) == length(listed)
    end
  end

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

  @testset "the design shows what a command would make, before OK" begin
    v = view()
    m = v.model
    home()
    steps, undo, edited = length(Models.timeline(m)), m.doc["undo"], Models.edited(m)
    faces = length(m.shapes[1].flat)
    V.start!(v, "solid.fillet")
    frame(w)
    click_edge()
    @test length(v.form.values["edges"]) == 1
    v.parts[(:field, "solid.fillet", "radius")].text = "1mm"
    trial = tried()
    @test trial !== nothing && isempty(trial.problem) && trial.changed == [m.shapes[1].name]
    @test length(trial.shapes[1].flat) > faces                     # the round is a face more
    settle()
    # The design itself is as it was: no step more, nothing to undo more, and nothing to redo
    @test length(Models.timeline(m)) == steps && length(m.shapes[1].flat) == faces
    @test m.doc["undo"] == undo && Models.redoable(m) == 0 && Models.edited(m) == edited
    # The picture has the body as the command leaves it, and of the body as it is only what's lit
    list = drawn()
    @test count(x -> x isa V.GLs.Solid && x.bare, list) == 1 && count(x -> x isa V.GLs.Solid && !x.bare, list) == 1
    shot("design-12-preview.png")
    # Another radius is tried in its turn
    v.parts[(:field, "solid.fillet", "radius")].text = "1.5mm"
    again = tried()
    @test again !== nothing && again.key != trial.key && isempty(again.problem)
    # A radius that's too big: SolidCraft's words show in the form, and the body shows as it is
    v.parts[(:field, "solid.fillet", "radius")].text = "500mm"
    failed = tried()
    @test failed !== nothing && !isempty(failed.problem) && !any(x -> x isa V.GLs.Solid && x.bare, drawn())
    v.parts[(:field, "solid.fillet", "radius")].text = "1mm"
    @test tried() !== nothing
    # With Preview off, nothing is tried
    click(v.parts[(:form, :preview)])
    frame(w)
    @test !v.previews && m.trial === nothing
    click(v.parts[(:form, :preview)])
    @test v.previews && tried() !== nothing
    # Cancel leaves the design as it was. ⇧⌘Z has nothing to redo: a command that was tried isn't a step.
    click(v.parts[(:form, :cancel)])
    frame(w)
    @test v.form === nothing && m.trial === nothing
    settle()
    key(Keys.z, Keys.cmd, Keys.shft)
    settle()
    @test length(Models.timeline(m)) == steps && Models.redoable(m) == 0 && isempty(m.said)
    # OK after a preview runs the command once
    V.start!(v, "solid.fillet")
    frame(w)
    click_edge()
    v.parts[(:field, "solid.fillet", "radius")].text = "1mm"
    @test tried() !== nothing
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && length(Models.timeline(m)) == steps + 1 && isempty(m.said)
    key(Keys.z, Keys.cmd)
    settle()
    @test length(Models.timeline(m)) == steps
  end

  @testset "the origin and the construction planes" begin
    v = view()
    m = v.model
    home()
    @test m.origin_hidden && !Models.origin_shown(m, "XY")
    @test !any(x -> x isa V.GLs.Sheet && x.key[1] == :plane, drawn())
    # The eye of the Origin folder shows its point, its three axes and its three planes
    delete!(v.closed, "Origin")
    frame(w)
    click(v.parts[(:eye, :folder, "Origin")])
    settle()
    @test all(name -> Models.origin_shown(m, name), ("O", "X", "Y", "Z", "XY", "XZ", "YZ"))
    click(v.parts[(:eye, :origin, "XZ")])
    settle()
    @test !Models.origin_shown(m, "XZ") && Models.origin_shown(m, "XY")
    list = drawn()
    @test count(x -> x isa V.GLs.Sheet && x.key[1] == :plane, list) == 2 && count(x -> x isa V.GLs.Lines && x.key[1] == :axis, list) == 3
    # ⌘Z shows the plane again: the editor asks SolidCraft what's hidden after an Undo
    key(Keys.z, Keys.cmd)
    settle()
    @test Models.origin_shown(m, "XZ")
    # A construction plane 25 mm over the ground shows as a square round the point that SolidCraft gives
    Models.change!(m, "construct.plane.offset", JSON.Object("base" => "XY", "offset" => "25 mm"))
    settle()
    @test length(m.planes) == 1 && isapprox(m.planes[1].point[3], 25.0, atol=1e-9) && m.planes[1].normal == (0.0, 0.0, 1.0)
    plane = m.planes[1].name
    step = Int(Models.timeline(m)[end]["id"])
    @test haskey(v.parts, (:made, step)) && Models.plane_shown(m, plane)
    @test any(x -> x isa V.GLs.Sheet && x.key[1:2] == (:plane, plane), drawn())
    shot("design-13-origin-planes.png")
    # Create Sketch asks for a plane, and a click on the plane in the design gives its name
    V.start!(v, "sketch.create")
    frame(w)
    @test v.form.active == "plane" && v.form.values["plane"] == "XY"
    over = shows(m.planes[1].point .+ (2.0, 2.0, 0.0))
    at(over)
    @test v.hover !== nothing && v.hover.kind == :plane && v.hover.of == plane
    click(over)
    @test v.form.values["plane"] == plane
    key(Keys.escape)
    # Its eye in the browser hides it
    click(v.parts[(:eye, :made, step)])
    settle()
    @test !Models.plane_shown(m, plane) && !any(x -> x isa V.GLs.Sheet && x.key[1:2] == (:plane, plane), drawn())
    Models.show!(m, false; folder="origin")
    settle()
    @test !Models.origin_shown(m, "XY")
  end

  @testset "a sketch that isn't edited is drawn with the bodies, and the sketch panel" begin
    v = view()
    m = v.model
    home()
    sketches = Models.sketch_list(m)
    Models.show!(m, true; items=Any[Int(sketches[1]["id"])])
    settle()
    # The graphics card draws it, so that a body in front of it hides it
    lines = filter(x -> x isa V.GLs.Lines && x.key[1] == :sketch, drawn())
    @test !isempty(lines) && all(x -> x.hidden, lines) && any(x -> !isempty(x.data), lines)
    # While a form asks for profiles, every closed region shows faintly
    V.start!(v, "solid.extrude")
    frame(w)
    @test any(x -> x isa V.GLs.Sheet && x.key[1] == :region, drawn())
    key(Keys.escape)
    @test !any(x -> x isa V.GLs.Sheet && x.key[1] == :region, drawn())
    # The sketch that's edited is drawn over the picture, and its panel is laid out as SolidCraft's is
    V.edit_step!(v, Int(sketches[1]["id"]))
    settle()
    @test !any(x -> x isa V.GLs.Lines && x.key[1] == :sketch, drawn())
    @test occursin("freedom", V.held_words(V.sketch(v))[1]) || V.held_words(V.sketch(v))[1] == "Fully constrained"
    # Slice takes away what's between the sketch and the eye
    @test V.cut(v) === nothing
    click(v.parts[(:sketch, :slice)])
    frame(w)
    @test v.slice && V.cut(v) !== nothing
    shot("design-14-slice.png")
    click(v.parts[(:sketch, :slice)])
    @test !v.slice
    # X with nothing selected: what's drawn next is construction geometry
    f = Sketching.Frame(V.sketch(v)["plane"])
    place(p) = shows(Sketching.world(f, p))
    empty!(v.picked)
    ontype(w, Typed('x', w)); frame(w)
    @test v.building
    V.start!(v, "sketch.line")
    click(place((-16.0, -6.0))); click(place((-12.0, -3.0))); settle()
    key(Keys.escape); key(Keys.escape)
    @test V.sketch(v)["curves"][end]["construction"] == true
    click(v.parts[(:show, :building)])
    @test !v.building
    # With Snap off, a click near a point doesn't go to it
    corner = Sketching.spot(V.sketch(v)["curves"][end]["end_at"])
    near = place(corner) .+ (3.0, 0.0)
    @test V.aim(v, V.sketch(v), V.local_spot(v, near)).ref !== nothing
    click(v.parts[(:show, :snap)])
    @test !v.snap && V.aim(v, V.sketch(v), V.local_spot(v, near)).ref === nothing
    click(v.parts[(:show, :snap)])
    V.start!(v, "sketch.cancel")
    settle()
    @test Models.editing(m) === nothing
  end

  @testset "the file is written with ⌘S" begin
    v = view()
    @test Models.edited(v.model)
    was = mtime(file)
    sleep(1.1)
    key(Keys.s, Keys.cmd)
    settle()
    @test !Models.edited(v.model) && mtime(file) > was
    # SolidCraft opens what was written, with the hole
    let again = Engines.start(file)
      steps = Engines.ask(again, "document.inspect", JSON.Object("timeline" => "summary", "bodies" => "names"))["timeline"]
      @test [s["name"] for s in steps][1:2] == ["Base", "Block"] && length(steps) >= 4
      Engines.stop!(again)
    end
  end

  @testset "the program ends when the window leaves a design with no changes" begin
    v = view()
    engine = v.model.engine
    note = joinpath(dir, "note.md")
    write(note, "# A note\n")
    K.open!(e, note)
    frame(w)
    @test !haskey(e.nodes, (:design, file))
    @test !isempty(engine.stopped)
  end
end

# A window asks before it closes with a design that has changes
if Engines.available()
  @testset "a view block only shows a design, and its button goes to the editor" begin
    shown = joinpath(dir, "shown.sc")
    cp(file, shown)
    page = joinpath(dir, "shows.md")
    write(page, "# A design\n\n```view\nshown.sc\n```\n\nThe end.\n")
    e2 = K.build_editor(page)
    w2 = Window(e2, size=(900px, 700px))
    block() = e2.nodes[(:block, K.VIEW_BLOCK, page, 1)]
    until(done) = for _ in 1:1500
      frame(w2)
      done() && break
      sleep(0.01)
    end
    frame(w2); frame(w2)
    d = block().crumb.viewer
    @test d isa V.DesignView && d.readonly && !d.fill
    until(() -> d.model !== nothing && !isempty(d.model.shapes) && d.model.engine === nothing)
    frame(w2)
    # SolidCraft's program gave the bodies, and ended
    @test !isempty(d.model.shapes) && d.model.engine === nothing && isempty(d.model.problem)
    # The design shows alone, as tall as a model in a page: it has no toolbar and no browser
    @test haskey(d.parts, :scene) && !haskey(d.parts, :ribbon) && !any(n -> n isa V.Card, values(d.parts))
    @test K.num(rect(d).height) == K.num(K.MODEL_HEIGHT) && K.num(rect(d).width) > 400
    @test d.image !== nothing && d.image.image != C_NULL
    haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "design-16-in-a-page.png"), w2)
    r = rect(d)
    mid = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
    move((x, y)) = (w2.mouse = typeof(w2.mouse)(px(x), px(y)); onmouse(w2, MouseMove(Vec2{px}(px(x), px(y)), w2)); frame(w2))
    down() = (w2.keys |= Keys.mouse_left; onkey(w2, KeyPress{Keys.mouse_left}(0, w2)))
    up() = (w2.keys ⊻= Keys.mouse_left; onkey(w2, KeyRelease{Keys.mouse_left}(0, w2)); frame(w2))
    first_eye = d.eye
    # The mouse lights nothing, and a click selects nothing
    move(mid)
    @test d.hover === nothing
    down(); up()
    @test isempty(d.picked) && d.form === nothing && d.eye == first_eye
    sleep(0.5)
    # A drag turns the design
    down(); move(mid .+ (60, 20)); up()
    @test d.eye != first_eye && d.drag === nothing && isempty(d.picked)
    # Two clicks show all of it again, as it was first shown
    move(mid)
    down(); up(); down(); up()
    @test d.eye == first_eye
    sleep(0.5)
    # Two fingers scroll the page. With ⌘ held they bring the design nearer.
    @test onscroll(d, K.MouseScroll(Vec2{px}(px(0), px(-30)), w2)) === nothing && d.eye == first_eye
    w2.keys |= Keys.cmd
    onscroll(d, K.MouseScroll(Vec2{px}(px(0), px(-30)), w2))
    w2.keys ⊻= Keys.cmd
    @test d.eye != first_eye
    # The first button beside the block makes the design fill the window, still with no panels
    @test K.view_fills(block(), e2) == (:node, d)
    K.zoom_in!(e2, (:node, d), block())
    frame(w2); frame(w2)
    @test d.fill && K.num(rect(d).height) > 500 && !haskey(d.parts, :ribbon) && e2.buf.path == page
    K.zoom_out!(K.zooming(e2))
    frame(w2); frame(w2)
    @test !d.fill && K.num(rect(d).height) == K.num(K.MODEL_HEIGHT)
    # When the file changes, the view reads it again
    was = d.model
    sleep(1.1)
    let again = Engines.start(shown)
      Engines.ask(again, "solid.box", JSON.Object("length" => 5, "width" => 5, "height" => 5, "corner" => Any[40, 40, 0]))
      Engines.ask(again, "file.save", JSON.Object("path" => shown))
      Engines.stop!(again)
    end
    until(() -> d.model !== was && d.model.engine === nothing)
    @test d.model !== was && length(d.model.shapes) == length(was.shapes) + 1 && was.engine === nothing
    # The second button goes to the file, and there the design has its editor
    K.go_view!(block())
    frame(w2); frame(w2)
    full = get(e2.nodes, (:design, shown), nothing)
    @test e2.buf.path == shown && full isa V.DesignView && !full.readonly && full !== d
    until(() -> full.model !== nothing && !isempty(full.model.shapes) && !Models.busy(full.model))
    @test haskey(full.parts, :ribbon) && full.model.engine !== nothing
    K.close_designs!(e2)
  end

  @testset "a window asks before it closes with a design that has changes" begin
    K.open!(e, file)
    frame(w); settle()
    v = view()
    m = v.model
    @test K.closes!(e, w)                          # with no changes, it closes
    Models.change!(m, "solid.box", JSON.Object("length" => 5, "width" => 5, "height" => 5, "corner" => Any[40, 40, 0]))
    settle()
    @test Models.edited(m) && K.unsaved_designs(e) == [v]
    @test !K.closes!(e, w)                         # with changes, it asks
    frame(w)
    asked = only(p for p in popups(w) if p.key == :close_ask).content
    shot("design-15-ask-close.png")
    # Cancel keeps the window and the changes
    click(asked.parts[:cancel])
    frame(w)
    @test isempty([p for p in popups(w) if p.key == :close_ask]) && Models.edited(m) && K.designs(e) == [v]
    # ⌘W in a window that shows no file asks too
    engine = m.engine
    was = mtime(file)
    sleep(1.1)
    @test !K.closes!(e, w)
    frame(w)
    asked = only(p for p in popups(w) if p.key == :close_ask).content
    # Save writes the design, then the window closes and SolidCraft's program ends
    click(asked.parts[:save])
    for _ in 1:600
      isempty(K.designs(e)) && break
      frame(w); sleep(0.01)
    end
    @test mtime(file) > was && isempty(K.designs(e))
    @test !isempty(engine.stopped)
  end
end

# A design that a failed check left open gives up SolidCraft's program, so that none is left running
if @isdefined(e)
  for (key, node) in collect(e.nodes)
    key isa Tuple && !isempty(key) && key[1] == :design && V.close!(node)
  end
end
