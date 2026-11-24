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

@testset "the faces and edges of a body" begin
  # A box of 10 by 10 by 10 as an OBJ file: 8 corners, 6 ways of facing, 12 triangles
  obj = """
  o Box
  v 0 0 0\nv 10 0 0\nv 10 10 0\nv 0 10 0\nv 0 0 10\nv 10 0 10\nv 10 10 10\nv 0 10 10
  vn 0 0 -1\nvn 0 0 1\nvn 0 -1 0\nvn 1 0 0\nvn 0 1 0\nvn -1 0 0
  f 1//1 3//1 2//1\nf 1//1 4//1 3//1\nf 5//2 6//2 7//2\nf 5//2 7//2 8//2
  f 1//3 2//3 6//3\nf 1//3 6//3 5//3\nf 2//4 3//4 7//4\nf 2//4 7//4 6//4
  f 3//5 4//5 8//5\nf 3//5 8//5 7//5\nf 4//6 1//6 5//6\nf 4//6 5//6 8//6
  """
  shapes = Scenes.read_obj(Vector{UInt8}(replace(obj, r"^\s+"m => "")))
  @test length(shapes) == 1
  box = shapes[1]
  @test box.name == "Box"
  @test length(box.triangles) == 12
  @test length(box.flat) == 6 && all(box.flat)       # six flat faces
  @test length(box.edges) == 12                      # and twelve edges, each between two of them
  @test all(e -> length(e.points) == 2 && !e.closed, box.edges)
  @test (box.low, box.high) == ((0.0, 0.0, 0.0), (10.0, 10.0, 10.0))
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
  # SolidCraft also says which face each triangle is of. Here it has the two triangles of the top as two faces, which the triangles alone don't show.
  corners = join(("""<vertex x="$x" y="$y" z="$z"/>""" for (x, y, z) in ((0, 0, 0), (10, 0, 0), (10, 10, 0), (0, 10, 0), (0, 0, 10), (10, 0, 10), (10, 10, 10), (0, 10, 10))), "\n")
  triangles = join(("""<triangle v1="$(a - 1)" v2="$(b - 1)" v3="$(c - 1)" ft:face="$face"/>""" for ((a, b, c), face) in
    zip(((1, 3, 2), (1, 4, 3), (5, 6, 7), (5, 7, 8), (1, 2, 6), (1, 6, 5), (2, 3, 7), (2, 7, 6), (3, 4, 8), (3, 8, 7), (4, 1, 5), (4, 5, 8)), (0, 0, 1, 6, 2, 2, 3, 3, 4, 4, 5, 5))), "\n")
  tagged = Scenes.tagged("<model>\n<object id=\"1\" name=\"Box\" ft:faces=\"7\">\n<mesh>\n<vertices>\n$corners\n</vertices>\n<triangles>\n$triangles\n</triangles>\n</mesh>\n</object>\n</model>")
  @test length(tagged) == 1 && tagged[1].name == "Box" && length(tagged[1].triangles) == 12 && tagged[1].faces[4] == 6
  split_top = Scenes.read_obj(Vector{UInt8}(replace(obj, r"^\s+"m => "")); faces=tagged)[1]
  @test length(split_top.flat) == 7 && all(split_top.flat) && length(split_top.edges) == 13
  # Tags of other triangles are left alone: the faces are then found in the triangles
  other = [(name=t.name, points=[p .+ (1.0, 0.0, 0.0) for p in t.points], triangles=t.triangles, faces=t.faces) for t in tagged]
  @test length(Scenes.read_obj(Vector{UInt8}(replace(obj, r"^\s+"m => "")); faces=other)[1].flat) == 6
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
    @test box.text == "10 mm"
    box.text = "14 mm"
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && isempty(m.said)
    @test isapprox(m.shapes[1].high[3], 14.0, atol=1e-9)
    shot("design-5-taller.png")
  end

  @testset "the parameters" begin
    v = view()
    m = v.model
    V.start!(v, "parameters")
    frame(w)
    @test v.panel == :params
    name, value = v.parts[(:newparam, :name)], v.parts[(:newparam, :value)]
    name.text, value.text = "wall", "3 mm"
    click(v.parts[(:newparam, :add)])
    settle()
    @test any(p -> p["name"] == "wall" && p["value"] == 3.0, Models.params(m))
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
    # A right click on a step shows its menu
    step = rect_middle(v.parts[(:step, 2)])
    at(step); w.keys |= Keys.mouse_right; onkey(w, KeyPress{Keys.mouse_right}(0, w)); w.keys ⊻= Keys.mouse_right
    onkey(w, KeyRelease{Keys.mouse_right}(0, w)); frame(w)
    @test any(p -> p.key == :menu, popups(w))
    key(Keys.escape)
    # The menu of a group lists the commands that have no button
    click(v.parts[(:group, "Model", "Create")]); frame(w)
    @test any(p -> p.key == :menu, popups(w))
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
    v.parts[(:field, "solid.fillet", "radius")].text = "1 mm"
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
    v.parts[(:field, "solid.fillet", "radius")].text = "1.5 mm"
    again = tried()
    @test again !== nothing && again.key != trial.key && isempty(again.problem)
    # A radius that's too big: SolidCraft's words show in the form, and the body shows as it is
    v.parts[(:field, "solid.fillet", "radius")].text = "500 mm"
    failed = tried()
    @test failed !== nothing && !isempty(failed.problem) && !any(x -> x isa V.GLs.Solid && x.bare, drawn())
    v.parts[(:field, "solid.fillet", "radius")].text = "1 mm"
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
    v.parts[(:field, "solid.fillet", "radius")].text = "1 mm"
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
