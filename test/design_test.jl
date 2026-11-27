# Tests for the editor of a SolidCraft design: see "a SolidCraft design" in
# main.jl, and cad/view.jl. Run them with
# `julia -O0 --project=. test/design_test.jl`. They need SolidCraft.app on
# this Mac, and skip the editor's own checks without it. They make a design of
# their own in a temporary folder, and show it in a window that isn't on the
# screen. Set `LADDER_SHOTS` to a folder, and they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/JSON.jl" => JSON
@use "../cad/scene" => Scenes
@use "../cad/sketch" => Sketching
@use "../cad/commands" => Commands
@use "../cad/engine" => Engines
@use "../cad/design" => Models
@use "../cad/pieces" => Pieces
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Typed Keys onkey onmouse onscroll ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups scene draw
@use "github.com/jkroso/MiniFB.jl/skia" gpus GPU srgb
@use ModernGL...
@use Skia
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px
const V = K.Designs
K.RUN_WAIT[] = Inf   # what ⌘Return runs in a field has come back when the key's handler ends

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
  "The colour of the design's picture where the point `p` of the design shows: its red, green and blue"
  seen(p) = begin
    v = view()
    at = shows(p)
    dense = v.stage.wide / v.area[3]
    x, y = round(Int, (at[1] - v.area[1]) * dense), round(Int, (at[2] - v.area[2]) * dense)
    i = 4 * (y * v.stage.wide + x) + 1
    (v.stage.pixels[i], v.stage.pixels[i+1], v.stage.pixels[i+2])
  end
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

  @testset "Measure shows what it measures at once, with a line between two things" begin
    v = view()
    m = v.model
    undos = Models.undos(m)
    V.start!(v, "inspect.measure")
    frame(w)
    @test v.form.spec.title == "Measure" && v.form.active == "items"
    said() = Dict(V.measure_lines(v, V.measured(v).answer)[1])
    # One face: its own sizes
    click(shows((0.0, 0.0, 10.0)))                 # the top of the block, 40 by 20
    settle()
    @test said()["Area"] == "800 mm²" && said()["Perimeter"] == "120 mm"
    # A second thing: what's between the two, and a line in the design from one to the other
    click(shows((0.0, -10.0, 0.0)))                # the front's bottom edge
    settle()
    @test [p.kind for p in v.form.shows["items"]] == [:face, :edge]
    @test V.count_words(v.form.spec.fields[1], v.form.shows["items"]) == "1 face, 1 edge"
    @test said()["Closest"] == "10 mm" && said()["Along Z"] == "10 mm"
    line = V.measure_line(V.measured(v).answer)
    @test isapprox(line.gap, 10.0, atol=1e-6) && isapprox(abs(line.from[3] - line.to[3]), 10.0, atol=1e-6)
    shot("design-measure.png")
    # A third thing starts again with it alone
    click(shows((0.0, -10.0, 5.0)))                # the front, 40 by 10
    settle()
    @test length(v.form.shows["items"]) == 1 && said()["Area"] == "400 mm²"
    # A body's line in the browser puts the body in, and it's measured as a body
    click(v.parts[((:field, "inspect.measure", "items"), :clear)])
    @test isempty(v.form.shows["items"])
    click(v.parts[(:body, m.shapes[1].name)])
    settle()
    @test isempty(v.picked) && only(v.form.shows["items"]).kind == :body
    @test said()["Volume"] == "8,000 mm³" && said()["Size"] == "40 × 20 × 10 mm"
    # Measure changes nothing, and Return closes it
    key(Keys.enter)
    @test v.form === nothing && Models.undos(m) == undos && isempty(m.said)
  end

  @testset "the Inspect tab: Mass Centre, Properties, Section and Interference" begin
    v = view()
    m = v.model
    undos = Models.undos(m)
    v.tab = "Inspect"
    frame(w)
    @test all(id -> haskey(v.parts, (:tool, id)), ["inspect.measure", "inspect.center_of_mass", "component.properties", "inspect.section", "inspect.interference"])
    # Mass Centre is on or off, and marks the centre of mass of the bodies
    click(v.parts[(:tool, "inspect.center_of_mass")])
    settle()
    @test V.in_use(v, "inspect.center_of_mass") && isapprox(v.parts[:mass_centre].answer["center"], [0.0, 0.0, 5.0], atol=1e-6)
    shot("design-mass-centre.png")
    click(v.parts[(:tool, "inspect.center_of_mass")])
    @test !V.in_use(v, "inspect.center_of_mass")
    # Properties: what all the bodies come to together
    click(v.parts[(:tool, "component.properties")])
    settle()
    total = v.parts[:properties].answer["total"]
    @test isapprox(total["volume_mm3"], 8000, rtol=1e-6) && isapprox(total["center_of_mass"], [0.0, 0.0, 5.0], atol=1e-6)
    @test length(V.properties_rows(v, v.form)) > 12
    shot("design-properties.png")
    key(Keys.enter)
    @test v.form === nothing
    # Section: Ladder cuts the picture along the plane as the form changes, and OK keeps the cut
    before = seen((15.0, -10.0, 5.0))             # the front of the block, on the side that the cut takes away
    click(v.parts[(:tool, "inspect.section")])
    frame(w)
    f = v.form
    f.values["plane"] = "YZ"                      # as the plane's menu chooses it
    push!(f.shows["plane"], (kind=:plane, of="YZ", n=0, at=(0.0, 0.0, 0.0)))
    frame(w)
    s = V.shown_section(v)
    @test s.origin == (0.0, 0.0, 0.0) && s.normal == (1.0, 0.0, 0.0) && s.words == "X 0 mm · hatch"
    @test seen((15.0, -10.0, 5.0)) != before
    # The face of the cut shows, in the body's colour, hatched. (Its half where y > 0 is under the plane's own square.)
    @test length(Set(seen((0.0, y, 6.0)) for y in -9.0:0.25:-2.0)) >= 2
    f.values["hatch"] = false
    frame(w)
    body = only(x for x in V.things(v, (v.area[3], v.area[4]), 1.0, V.theme(v)) if x isa V.GLs.Solid).colour
    @test maximum(abs.(Int.(collect(seen((0.0, -7.0, 7.0)))) .- round.(Int, collect(body[1:3]) .* 0.8 .* 255))) <= 3
    f.values["hatch"] = true
    V.set_text!(v.parts[(:field, "inspect.section", "distance")], "5mm")
    frame(w)
    @test V.shown_section(v).origin == (-5.0, 0.0, 0.0) && V.shown_section(v).words == "X -5 mm · hatch"
    shot("design-section.png")
    click(v.parts[(:form, :ok)])
    @test v.form === nothing && V.in_use(v, "inspect.section") && haskey(v.parts, :section_chip)
    shot("design-section-on.png")
    # Its eye hides it, and its chip's button turns it off
    click(v.parts[(:eye, :section)])
    @test V.shown_section(v) === nothing
    click(v.parts[(:section, :off)])
    @test V.section_cut(v) === nothing && seen((15.0, -10.0, 5.0)) == before
    # Interference: Compute checks the bodies. A box that overlaps the block shows red.
    click(v.parts[(:tool, "inspect.interference")])
    frame(w)
    click(v.parts[(:form, :compute)])
    settle()
    @test V.interference(v).answer["bodies"] == 1 && isempty(V.interference(v).answer["overlaps"]) && isempty(V.clashing(v))
    Models.change!(m, "solid.box", JSON.Object("length" => "10 mm", "width" => "10 mm", "height" => "10 mm", "center" => Any[20, 0, 5], "operation" => "new"))
    settle()
    click(v.parts[(:form, :compute)])
    settle()
    @test length(V.interference(v).answer["overlaps"]) == 1 && length(V.clashing(v)) == 2
    shot("design-interference.png")
    key(Keys.enter)
    key(Keys.z, Keys.cmd)
    settle()
    # Nothing but the box changed the design
    @test v.form === nothing && Models.undos(m) == undos && isempty(m.said) && length(m.shapes) == 1
    v.tab = "Model"
    frame(w)
  end

  @testset "an extrude of a flat face of a body" begin
    v = view()
    m = v.model
    @test isempty(m.sketches)                    # no sketch shows, so only a face can be the profile
    V.start!(v, "solid.extrude")
    frame(w)
    @test v.form.active == "profiles"
    click(shows((-10.0, -5.0, 10.0)))            # the block's top
    p = only(v.form.shows["profiles"])
    @test p.kind == :face && p.of == m.shapes[1].name && m.shapes[1].flat[p.n]
    @test V.count_words(Commands.SPECS["solid.extrude"].fields[1], v.form.shows["profiles"]) == "1 face"
    # SolidCraft gets a point on each face in place of a sketch's regions
    command, params, _ = V.request(v, v.form)
    @test command == "solid.extrude" && !haskey(params, "profiles") && !haskey(params, "sketch")
    @test length(params["faces"]) == 1 && isapprox(params["faces"][1][3], 10.0, atol=1e-6) && params["face_body"] == p.of
    # A second click on the face takes it out again, and a third puts it back
    click(shows((-10.0, -5.0, 10.0)))
    @test isempty(v.form.shows["profiles"])
    click(shows((-10.0, -5.0, 10.0)))
    @test length(v.form.shows["profiles"]) == 1
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && isempty(m.said)
    # SolidCraft makes a sketch on the face, then the extrude of it, and one ⌘Z takes both back
    @test [s["type"] for s in Models.timeline(m)] == ["Sketch", "ExtrudeFeature", "Sketch", "ExtrudeFeature"] && length(m.shapes) == 1
    @test isapprox(m.shapes[1].high[3], 20.0, atol=1e-6)    # the form's 10 mm on top of the block's 10
    # Revolve takes one face, as `face`
    V.start!(v, "solid.revolve")
    frame(w)
    click(shows((-10.0, -5.0, 20.0)))
    click(shows((0.0, -10.0, 5.0)))              # the front: it takes the top's place
    p = only(v.form.shows["profiles"])
    @test p.kind == :face && isapprox(p.at[2], -10.0, atol=1e-6)
    _, params, _ = V.request(v, v.form)
    @test params["face"] isa Vector && length(params["face"]) == 3 && !haskey(params, "faces")
    v.form = nothing
    key(Keys.z, Keys.cmd)
    settle()
    @test length(Models.timeline(m)) == 2 && isapprox(m.shapes[1].high[3], 10.0, atol=1e-6)
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
    box = V.keyed(w.focus)
    V.set_text!(box, "")
    foreach(c -> ontype(w, Typed(c, w)), "8")
    # The field takes Julia code: ⌘Return shows what it comes to, and the field stays
    @test V.iscode(box)
    key(Keys.enter, Keys.cmd)
    @test any(p -> p.key == :ask, popups(w)) && K.field_outcome!(box).brief == "8"
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
    # Ladder shows what the cut takes away itself
    frame(w)
    @test m.trial !== nothing && m.trial.made !== nothing && all(==(:cut), values(m.trial.made.tints))
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
    @test V.text_of(box) == "10mm"              # SolidCraft's 10 mm, as Julia writes it
    V.set_text!(box, "14mm")
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
    @test V.text_of(box) == "2mm" && V.iscode(box)
    # The field is Ladder's editor of a file of Julia code, with the font and the colours of code
    @test box isa K.DesignField && K.kinds(box.sub.buf)[1].lang == "julia" && K.face(box.sub, K.kinds(box.sub.buf)[1]).family == K.codefont()
    # A click puts the caret in it, and the keys type there
    click(box)
    @test V.has_keys(w, box) && w.focus === box.sub
    key(Keys.a, Keys.cmd)
    foreach(c -> ontype(w, Typed(c, w)), "1.5mm + 2mm*0.25")
    frame(w)
    @test V.text_of(box) == "1.5mm + 2mm*0.25"
    # ⌘Return runs the code that's selected, and what it comes to shows after the code, in the box of a Julia file. The form stays.
    b = box.sub.buf
    b.anchor, b.caret = (1, 8), (1, 16)                # 2mm*0.25
    key(Keys.enter, Keys.cmd)
    o = K.field_outcome!(box)
    @test v.form !== nothing && o.brief == "0.5mm" && !o.failed
    @test any(n -> n === o, K.outcomes(box.sub))
    # With nothing selected, it runs all of the code
    b.anchor = b.caret = (1, 0)
    key(Keys.enter, Keys.cmd)
    @test K.field_outcome!(box).brief == "2mm"
    shot("design-7-julia.png")
    # What went wrong shows in red, and a click on its box shows the rest under the field
    key(Keys.a, Keys.cmd)
    foreach(c -> ontype(w, Typed(c, w)), "1.5mm + nothing_here")
    key(Keys.enter, Keys.cmd)
    o = K.field_outcome!(box)
    @test o.failed && occursin("nothing_here", o.brief) && o.more && V.under(box) === nothing
    click(o)
    @test o.open && V.under(box) !== nothing
    frame(w)
    # SolidCraft reads `1.5mm + 2mm*0.25` as Julia does, so it keeps the code itself
    V.set_text!(box, "1.5mm + 2mm*0.25")
    @test K.field_outcome!(box) === nothing            # the code has changed since it ran
    frame(w)                                           # the rest under the field has gone, so OK is higher
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

  @testset "the panel grows with the text of its fields, and Tab goes from field to field" begin
    v = view()
    V.start!(v, "solid.fillet")
    frame(w)
    click(shows((0.0, -10.0, 10.0)))
    box = v.parts[(:field, "solid.fillet", "radius")]
    @test V.side_w(v) == V.SIDE_W                       # a short text has room in the panel as it is
    click(box)
    key(Keys.a, Keys.cmd)
    foreach(c -> ontype(w, Typed(c, w)), "4.5cm + 2mm * 1.3 + 0.25mm * 7 - 1mm")
    frame(w)
    lines(box) = length(box.sub.layout[1].content.lines)
    # The panel is wider, and the text is on one line
    @test V.side_w(v) > V.SIDE_W && lines(box) == 1
    wide = V.side_w(v)
    # It's wider again for the box of what the code came to, after the code
    key(Keys.enter, Keys.cmd)
    @test V.side_w(v) > wide && lines(box) == 1
    # Text that needs more than half the design goes on to another line, and the field is taller
    foreach(c -> ontype(w, Typed(c, w)), " + 0.1mm"^12)
    frame(w)
    @test K.num(V.side_w(v)) ≈ v.area[3] / 2 && lines(box) > 1 && rect(box).height > V.FIELD_H
    # The caret is at the end of the text, on its last line
    f = box.sub.layout[1].content
    @test K.spot(f, length(V.text_of(box)))[1] == lines(box)
    key(Keys.escape)
    @test v.form === nothing
    # Tab goes to the next field, and selects its text. ⇧Tab goes back.
    V.start!(v, "solid.box")
    frame(w)
    long, wide = v.parts[(:field, "solid.box", "length")], v.parts[(:field, "solid.box", "width")]
    was = V.text_of(long)
    click(long)
    key(Keys.a, Keys.cmd)
    foreach(c -> ontype(w, Typed(c, w)), "deep")
    key(Keys.tab)
    @test V.has_keys(w, wide)
    key(Keys.tab, Keys.shft)
    @test V.has_keys(w, long) && long.sub.buf.anchor == (1, 0) && long.sub.buf.caret == (1, 4)
    # ⌘Z takes back what was typed in the field
    key(Keys.z, Keys.cmd)
    @test V.text_of(long) == was
    key(Keys.escape)
    @test v.form === nothing
  end

  @testset "code that SolidCraft reads in another way is kept in a comment" begin
    v = view()
    m = v.model
    open_step() = (click(v.parts[(:step, 2)]); click(v.parts[(:step, 2)]); settle())
    open_step()
    param = String(v.form.inputs[1]["param"])
    @test V.text_of(v.parts[(:field, "step", param)]) == "14mm"
    undo = Models.undos(m)
    # Julia's 2 + 1cm is 3 cm. SolidCraft reads it as 2 mm and 1 cm.
    V.set_text!(v.parts[(:field, "step", param)], "2 + 1cm")
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && isempty(m.said)
    @test isapprox(m.shapes[1].high[3], 30.0, atol=1e-9)
    p = V.param_named(v, param)
    @test p["expression"] == "30 mm" && p["comment"] == "Julia: 2 + 1cm = 30 mm"
    # The field shows the code again
    open_step()
    @test V.text_of(v.parts[(:field, "step", param)]) == "2 + 1cm"
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
    V.set_text!(v.parts[(:field, "step", param)], "14mm + nothing_here")
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form !== nothing && occursin("nothing_here", v.form.problem) && Models.undos(m) == undo
    click(v.parts[(:form, :cancel)])
    frame(w)
  end

  @testset "the parameters are a sheet" begin
    v = view()
    m = v.model
    type(text) = (foreach(c -> ontype(w, Typed(c, w)), text); frame(w))
    V.start!(v, "parameters")
    frame(w)
    @test v.panel == :params
    s = v.parts[:param_sheet]
    b = s.sub.buf
    "Put the caret at the end of row `r` of the sheet"
    to_row(r) = (b.caret = b.anchor = K.line_end(b, r + 1); frame(w))
    "What row `r` of the sheet comes to, as the sheet shows it"
    result(r) = s.sub.layout[1].content.results[r]
    # A row for each parameter. A design with none has one empty row.
    rows = V.param_rows(v)
    @test V.sheet_rows(s) == (isempty(rows) ? [("", "")] : rows)
    @test s.sub.layout[1].content isa K.Sheet && !result(1).failed
    # A click on the sheet gives it the keyboard. The design behind it doesn't take the keyboard back.
    @test !V.has_keys(w, s)
    click(s)
    @test V.has_keys(w, s) && w.focus === s.sub
    # A new row is a new parameter. Return at the end of the last row starts one, and Tab goes from its name to its code.
    # A design with no parameters has one empty row, which is the new one.
    K.focus(s)
    empty = V.sheet_rows(s) == [("", "")]
    b.caret = b.anchor = empty ? (2, 0) : K.line_end(b, length(b.lines) - 1)
    frame(w)
    empty || key(Keys.enter)
    @test V.has_keys(w, s) && V.sheet_rows(s)[V.caret_row(s)] == ("", "")
    type("wall")
    key(Keys.tab)
    type("3mm")
    @test result(V.caret_row(s)).text == "3mm"
    # It goes to SolidCraft when the caret leaves the row. Return starts a row under it, which keeps the caret.
    key(Keys.enter)
    settle()
    @test any(p -> p["name"] == "wall" && p["value"] == 3.0, Models.params(m))
    # The user's parameters come first
    @test V.sheet_rows(s)[1] == ("wall", "3mm") && V.sheet_rows(s)[V.caret_row(s)] == ("", "")
    # A row can use a row over it, before SolidCraft has the new value of that row
    k = V.caret_row(s)
    to_row(1)
    foreach(_ -> key(Keys.backspace), 1:3)
    type("4mm")
    b.caret = b.anchor = (k + 1, 0)
    frame(w)
    type("deep")
    key(Keys.tab)
    type("wall*2")
    @test V.caret_row(s) == k && result(k).text == "8mm"
    to_row(1)
    settle()
    @test V.param_named(v, "wall")["expression"] == "4mm" && V.param_named(v, "deep")["value"] == 8.0
    @test [r[1] for r in V.sheet_rows(s)[1:2]] == ["wall", "deep"]
    # A row's code is Julia code. SolidCraft reads π as pi, so it gets that, and the comment keeps the code as it was typed.
    foreach(_ -> key(Keys.backspace), 1:3)
    type("π*1mm")
    to_row(2)
    settle()
    @test V.param_named(v, "wall")["expression"] == "pi*1mm" && V.param_note(v, "wall") == "Julia: π*1mm = pi*1mm" && V.sheet_rows(s)[1] == ("wall", "π*1mm")
    # Code that's wrong shows a ! in its row, and SolidCraft gets nothing. The top of the design says what's wrong.
    to_row(1)
    type(" + ")
    @test result(1).failed
    to_row(2)
    settle()
    @test V.param_named(v, "wall")["expression"] == "pi*1mm" && occursin("wall", m.said)
    to_row(1)
    foreach(_ -> key(Keys.backspace), 1:8)
    type("3mm")
    to_row(2)
    settle()
    @test V.param_named(v, "wall")["expression"] == "3mm" && V.param_named(v, "deep")["value"] == 6.0
    # A new name renames the parameter, and the code that uses it follows
    b.caret = b.anchor = (2, 4)
    frame(w)
    type("s")
    to_row(2)
    settle()
    @test V.param_named(v, "wall") === nothing && V.param_named(v, "walls")["value"] == 3.0 && occursin("walls", V.param_named(v, "deep")["expression"])
    @test V.sheet_rows(s)[1][1] == "walls" && occursin("walls", V.sheet_rows(s)[2][2])
    # A row that's taken away deletes its parameter, and ⌘Z brings it back. As in a page's sheet, the row's cells are
    # emptied first, and then ⌫ on the empty row takes it away.
    b.anchor, b.caret = (3, 7), K.line_end(b, 3)
    frame(w)
    key(Keys.backspace)
    b.anchor, b.caret = (3, 0), (3, 4)
    key(Keys.backspace)
    @test b.lines[3] == " = "
    key(Keys.backspace)
    settle()
    @test V.param_named(v, "deep") === nothing && !any(r -> r[1] == "deep", V.sheet_rows(s))
    key(Keys.z, Keys.cmd)
    settle()
    @test V.param_named(v, "deep") !== nothing && any(r -> r[1] == "deep", V.sheet_rows(s))
    shot("design-6-parameters.png")
    # The next ⌘Z takes back the new name
    key(Keys.z, Keys.cmd)
    settle()
    @test V.param_named(v, "wall") !== nothing && V.sheet_rows(s)[1][1] == "wall"
    key(Keys.escape)
    @test v.panel == :none
  end

  @testset "a field of code offers the parameters whose names are typed" begin
    v = view()
    m = v.model
    "The names in the list under the field, or nothing when no list shows"
    names_shown() = (i = findfirst(p -> p.key == V.NAMES_KEY, popups(w)); i === nothing ? nothing : [first(n) for n in popups(w)[i].content.names])
    type(text) = (foreach(c -> ontype(w, Typed(c, w)), text); frame(w))
    V.start!(v, "solid.fillet")
    frame(w)
    box = v.parts[(:field, "solid.fillet", "radius")]
    click(box)
    key(Keys.a, Keys.cmd)
    type("wa")
    @test names_shown() == ["wall"] && V.names_for(w, box).names[1].second == "3.00 mm"
    # Return puts the name in, and the form stays open
    key(Keys.enter)
    @test V.text_of(box) == "wall" && names_shown() === nothing && v.form !== nothing
    # The lengths of the steps are offered too, each with the name of its step
    type("/2 + d")
    shot("design-6b-names.png")
    shown = names_shown()
    @test shown !== nothing && all(n -> startswith(n, "d"), shown) && any(n -> startswith(n.second, "Block  "), V.names_for(w, box).names)
    key(Keys.down)
    @test V.names_for(w, box).lit == mod1(2, length(shown))
    # Esc hides the list, and the form stays open. The next name has a list again.
    key(Keys.escape)
    @test names_shown() === nothing && v.form !== nothing
    type("1 + w")
    @test names_shown() == ["wall"]
    # Tab puts the name in too
    key(Keys.tab)
    @test V.text_of(box) == "wall/2 + d1 + wall" && V.has_keys(w, box)
    # A name just after a number is its unit, and a moved caret takes the list away
    type(" + 10m")
    @test names_shown() === nothing
    type(" + wa")
    @test names_shown() == ["wall"]
    key(Keys.left)
    @test names_shown() === nothing
    # Typing shows it again, and a whole name has no list
    key(Keys.right)
    type("l")
    @test names_shown() == ["wall"]
    type("l")
    @test names_shown() === nothing
    # A click on a name puts it in
    key(Keys.a, Keys.cmd)
    type("w")
    click(V.names_for(w, box).rows[1])
    @test V.text_of(box) == "wall" && names_shown() === nothing
    key(Keys.escape)
    @test v.form === nothing
    # In the sheet of parameters, a row's code is offered the names too, but not the row's own
    V.start!(v, "parameters")
    frame(w)
    s = v.parts[:param_sheet]
    b = s.sub.buf
    K.focus(s)
    b.caret = b.anchor = K.line_end(b, 2)
    frame(w)
    @test V.sheet_rows(s)[1][1] == "wall"
    type(" + wa")
    @test names_shown() === nothing
    key(Keys.z, Keys.cmd)
    n, code = length(V.sheet_rows(s)), V.sheet_rows(s)[2][2]
    b.caret = b.anchor = K.line_end(b, 3)
    frame(w)
    type(" + wa")
    @test names_shown() == ["wall"] && V.names_for(w, s).names[1].second == "3.00 mm"
    # Return puts the name in, and starts no row
    key(Keys.enter)
    @test V.sheet_rows(s)[2][2] == code * " + wall" && names_shown() === nothing && length(V.sheet_rows(s)) == n
    key(Keys.z, Keys.cmd)
    key(Keys.z, Keys.cmd)
    @test V.sheet_rows(s)[2][2] == code
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

  @testset "a profile is a region of a sketch on a face, and a body's face hides a sketch behind it" begin
    v = view()
    m = v.model
    id = Int(last(filter(s -> s["type"] == "Sketch", Models.timeline(m)))["id"])
    seen(id, on) = (Models.change!(m, "browser.visibility", JSON.Object("items" => Any[id], "visible" => on)); settle())
    was = haskey(m.sketches, id)
    was || seen(id, true)
    @test haskey(m.sketches, id) && haskey(m.sketches, 1)   # the sketch on the top, and the one under the block
    V.start!(v, "solid.extrude")
    frame(w)
    f = Sketching.Frame(m.sketches[id]["plane"])
    click(shows(Sketching.world(f, (-12.0, -4.0))))          # in the rectangle drawn on the top
    p = only(v.form.shows["profiles"])
    @test p.kind == :region && p.n == id
    # The sketch on the top has the top's outline too, so the rest of the top is a region of it as well
    click(shows((10.0, 5.0, 14.0)))
    @test length(v.form.shows["profiles"]) == 2 && all(p -> p.kind == :region && p.n == id, v.form.shows["profiles"])
    v.form = nothing
    # With that sketch hidden, the top is a face, and the sketch under the block doesn't show through it
    seen(id, false)
    V.start!(v, "solid.extrude")
    frame(w)
    click(shows((10.0, 5.0, 14.0)))
    p = only(v.form.shows["profiles"])
    @test p.kind == :face && isapprox(p.at[3], 14.0, atol=1e-6)
    v.form = nothing
    seen(id, was)
  end

  @testset "the view turns, moves and comes nearer as in Fusion 360" begin
    v = view()
    V.fit!(v); frame(w)
    was = v.eye
    empty = (330.0, 680.0)                                        # a place of the picture with no body and no panel
    @test V.panel_at(v, w, Vec2{px}(px(empty[1]), px(empty[2]))) === nothing
    press(empty); at((380.0, 660.0)); release()                   # a drag turns it
    @test v.eye.turn != was.turn && v.eye.tilt != was.tilt && isempty(v.picked)
    # A drag of the middle button from `from` to `to`
    middle(from, to) = (at(from); w.keys |= Keys.mouse_middle; onkey(w, KeyPress{Keys.mouse_middle}(0, w)); at(to);
                        w.keys ⊻= Keys.mouse_middle; onkey(w, KeyRelease{Keys.mouse_middle}(0, w)); frame(w))
    # The middle button moves it
    was = v.eye
    middle(empty, (380.0, 660.0))
    @test v.eye.target != was.target && (v.eye.turn, v.eye.tilt, v.eye.distance) == (was.turn, was.tilt, was.distance)
    # With ⇧ held it turns it
    was = v.eye
    holding(() -> middle(empty, (380.0, 660.0)), Keys.shft)
    @test v.eye.turn != was.turn && v.eye.tilt != was.tilt && v.drag === nothing
    # With ⌃⇧ held, a drag up brings it nearer
    was = v.eye
    holding(() -> middle(empty, (330.0, 600.0)), Keys.ctrl, Keys.shft)
    @test v.eye.distance < was.distance && (v.eye.turn, v.eye.tilt) == (was.turn, was.tilt)
    # The wheel brings it nearer, and two fingers on the trackpad do too
    at(empty)
    was = v.eye
    onscroll(w, Vec2{px}(px(0), px(3)), true); frame(w)
    @test v.eye.distance < was.distance && (v.eye.turn, v.eye.tilt) == (was.turn, was.tilt)
    was = v.eye
    onscroll(w, Vec2{px}(px(0), px(30)), false); frame(w)
    @test v.eye.distance < was.distance
    # With ⇧ held the wheel turns it
    was = v.eye
    holding(() -> (onscroll(w, Vec2{px}(px(30), px(0)), false); frame(w)), Keys.shft)
    @test v.eye.turn != was.turn && v.eye.distance == was.distance
    # ⇧ and a click of the middle button on a body put the point that a turn goes round there
    V.fit!(v); frame(w)
    mid = (v.area[3] / 2, v.area[4] / 2)
    hit = V.Scenes.hit(v.model.shapes, V.Scenes.ray(v.eye, (v.area[3], v.area[4]), mid); shown=V.Designs.shows(v.model))
    @test hit !== nothing
    spot = (v.area[1] + mid[1], v.area[2] + mid[2])
    holding(() -> middle(spot, spot), Keys.shft)
    @test v.parts[:pivot] == hit.point
    # A turn from anywhere then goes round it, so it stays where it shows
    was = v.eye
    shown = V.shown_at(v, hit.point)
    press(empty); at((380.0, 660.0))
    @test v.drag.pivot == hit.point
    release()
    @test all(isapprox.(V.shown_at(v, hit.point), shown, atol=0.5)) && v.eye.turn != was.turn
    # Two clicks of the middle button show all of it, as it's turned, and a turn goes round the point under the mouse again
    holding(() -> middle(empty, (330.0, 600.0)), Keys.ctrl, Keys.shft)
    fitted = V.Scenes.fit(v.eye, V.Scenes.box(V.showing(v)), (v.area[3], v.area[4]))
    @test v.eye != fitted
    middle(empty, empty); middle(empty, empty)
    @test v.eye == fitted && !haskey(v.parts, :pivot)
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

  @testset "a window that the graphics card draws shows the picture with no copy through the CPU" begin
    v = view()
    # A context like a window's, with a framebuffer like its screen's, that Skia draws on as MiniFB does
    screen = V.GLs.Stage()
    if screen === nothing
      @info "macOS gave no OpenGL context, so the picture on the graphics card isn't checked"
    else
      W, H = round(Int, 2 * K.num(w.size[1])), round(Int, 2 * K.num(w.size[2]))
      was = V.GLs.current()
      V.GLs.setcurrent(screen.cgl)
      fbo, colour, stencil = V.GLs.made(glGenFramebuffers), V.GLs.made(glGenRenderbuffers), V.GLs.made(glGenRenderbuffers)
      glBindRenderbuffer(GL_RENDERBUFFER, colour); glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, W, H)
      glBindRenderbuffer(GL_RENDERBUFFER, stencil); glRenderbufferStorage(GL_RENDERBUFFER, GL_STENCIL_INDEX8, W, H)
      glBindFramebuffer(GL_FRAMEBUFFER, fbo)
      glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colour)
      glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, stencil)
      face = Skia.gr_glinterface_create_native_interface()
      gr = Skia.gr_direct_context_make_gl(face)
      Skia.gr_glinterface_unref(face)
      target = Skia.gr_backendrendertarget_new_gl(Cint(W), Cint(H), Cint(0), Cint(8), Ref(Skia.gr_gl_framebufferinfo_t(fbo, 0x8058, false)))
      surface = Skia.sk_surface_new_backend_render_target(gr, target, Skia.GR_SURFACE_ORIGIN_BOTTOM_LEFT, Skia.SK_COLOR_TYPE_RGBA_8888, srgb[], C_NULL)
      V.GLs.setcurrent(was)
      "Draw the window's last layout with Skia on the graphics card, as MiniFB draws a window that's on the screen, and give its pixels"
      drawn() = begin
        V.GLs.setcurrent(screen.cgl)
        try
          Skia.gr_direct_context_reset(gr)
          canvas = Skia.sk_surface_get_canvas(surface)
          Skia.sk_canvas_save(canvas)
          Skia.sk_canvas_clear(canvas, 0x00000000)
          Skia.sk_canvas_scale(canvas, 2f0, 2f0)
          draw(canvas, w.size, scene(w))
          Skia.sk_canvas_restore(canvas)
          Skia.gr_direct_context_flush_and_submit(gr, false)
          glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo)
          out = zeros(UInt8, 4W * H)
          glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, out)
          out
        finally
          V.GLs.setcurrent(was)
        end
      end
      try
        frame(w)
        gpus[objectid(w)] = GPU(gr, target, surface, (W, H))
        direct = drawn()
        @test v.parts[:direct] === true          # the stage shares the window's context
        # Without the window's own context the stage reads its picture back, and Skia draws the bytes. The stage stays the one
        # that the window's frames use, so a picture for a file, like the one that an agent looks at, costs the window nothing.
        delete!(gpus, objectid(w))
        shared = v.stage
        read_back = drawn()
        @test v.stage === shared
        @test count(i -> abs(Int(direct[i]) - Int(read_back[i])) > 3, eachindex(direct)) == 0
        # The picture follows the eye
        gpus[objectid(w)] = GPU(gr, target, surface, (W, H))
        eye = v.eye
        v.eye = Scenes.Eye(eye.target, eye.turn + 30, eye.tilt, eye.distance, eye.wide)
        turned = drawn()
        v.eye = eye
        @test turned != direct && drawn() == direct
      finally
        delete!(gpus, objectid(w))
        V.GLs.setcurrent(screen.cgl)
        Skia.sk_surface_unref(surface)
        Skia.gr_backendrendertarget_delete(target)
        Skia.gr_direct_context_release_resources_and_abandon_context(gr)
        Skia.gr_direct_context_unref(gr)
        V.GLs.setcurrent(was)
        frame(w)
      end
    end
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
    V.set_text!(V.keyed(w.focus), "Block")
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

  @testset "the design shows what a command would make, before OK" begin
    v = view()
    m = v.model
    home()
    # SolidCraft's program tries a command that Ladder doesn't make itself. Ladder makes a fillet, so here it doesn't.
    own_fillet = pop!(V.Previews.MAKERS, "solid.fillet")
    try
    steps, undo, edited = length(Models.timeline(m)), m.doc["undo"], Models.edited(m)
    faces = length(m.shapes[1].flat)
    V.start!(v, "solid.fillet")
    frame(w)
    click_edge()
    @test length(v.form.values["edges"]) == 1
    V.set_text!(v.parts[(:field, "solid.fillet", "radius")], "1mm")
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
    V.set_text!(v.parts[(:field, "solid.fillet", "radius")], "1.5mm")
    again = tried()
    @test again !== nothing && again.key != trial.key && isempty(again.problem)
    # A radius that's too big: SolidCraft's words show in the form, and the body shows as it is
    V.set_text!(v.parts[(:field, "solid.fillet", "radius")], "500mm")
    failed = tried()
    @test failed !== nothing && !isempty(failed.problem) && !any(x -> x isa V.GLs.Solid && x.bare, drawn())
    V.set_text!(v.parts[(:field, "solid.fillet", "radius")], "1mm")
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
    V.set_text!(v.parts[(:field, "solid.fillet", "radius")], "1mm")
    @test tried() !== nothing
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && length(Models.timeline(m)) == steps + 1 && isempty(m.said)
    key(Keys.z, Keys.cmd)
    settle()
    @test length(Models.timeline(m)) == steps
    finally
      V.Previews.MAKERS["solid.fillet"] = own_fillet
    end
  end

  @testset "Ladder shows what a fillet would make at once, and SolidCraft's program makes it at OK" begin
    v = view()
    m = v.model
    home()
    settle()
    steps = length(Models.timeline(m))
    V.start!(v, "solid.fillet")
    frame(w)
    click_edge()
    @test length(v.form.values["edges"]) == 1
    asked = m.engine.next
    V.set_text!(v.parts[(:field, "solid.fillet", "radius")], "1mm")
    frame(w)
    # It's there in the same frame, and nothing was asked of SolidCraft's program
    t = m.trial
    @test t !== nothing && t.made !== nothing && t.key == v.form.key && m.engine.next == asked
    @test !isempty(t.shapes) && all(==(:cut), values(t.made.tints)) && t.made.ghost == [m.shapes[1].name]
    # The body shows faintly, and the piece that the fillet takes away shows in it
    list = drawn()
    @test any(x -> x isa V.GLs.Solid && x.key == (:solid, objectid(m.shapes[1])) && isapprox(x.colour[4], V.GHOST), list)
    @test count(x -> x isa V.GLs.Solid && any(s -> x.key == (:solid, objectid(s)), t.shapes), list) == length(t.shapes)
    shot("design-13-own-preview.png")
    piece, before = sum(Pieces.volume, t.shapes), Pieces.volume(m.shapes[1])
    # Another radius shows at once too
    V.set_text!(v.parts[(:field, "solid.fillet", "radius")], "1.5mm")
    frame(w)
    @test m.trial.key == v.form.key && m.trial !== t && m.engine.next == asked
    V.set_text!(v.parts[(:field, "solid.fillet", "radius")], "1mm")
    frame(w)
    click(v.parts[(:form, :ok)])
    settle()
    @test v.form === nothing && isempty(m.said) && length(Models.timeline(m)) == steps + 1
    # SolidCraft took away what the piece showed
    @test isapprox(before - Pieces.volume(m.shapes[1]), piece, rtol=0.1)
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

  @testset "a design in a view block takes the page's numbers by the names of its parameters" begin
    # A block whose height is the parameter `high`, and a parameter `wide` that no part uses
    given = joinpath(dir, "given.sc")
    let again = Engines.start(joinpath(dir, "given-new.sc"))
      Engines.tell(again, "new_design")
      Engines.ask(again, "parameters.add", JSON.Object("name" => "high", "expression" => "10 mm"))
      Engines.ask(again, "parameters.add", JSON.Object("name" => "wide", "expression" => "40 mm"))
      Engines.ask(again, "parameters.add", JSON.Object("name" => "turns", "expression" => "2", "unit" => ""))
      Engines.ask(again, "sketch.create", JSON.Object("plane" => "XY", "name" => "Base"))
      Engines.ask(again, "sketch.rectangle.center", JSON.Object("center" => Any[0, 0], "corner" => Any[20, 10]))
      Engines.ask(again, "sketch.finish")
      Engines.ask(again, "solid.extrude", JSON.Object("distance" => "high", "name" => "Block"))
      Engines.ask(again, "file.save", JSON.Object("path" => given))
      Engines.stop!(again)
    end
    @test [(p.name, p.unit) for p in Models.file_params(given)] == [("high", "mm"), ("wide", "mm"), ("turns", "")]
    # What a page's numbers change: a length in metres, a plain number, words for no parameter that takes words
    @test Models.changes(Models.file_params(given), Dict{String,Any}("high" => 0.025, "turns" => 3.5, "wide" => "words", "other" => 1.0)) ==
          Dict("high" => "25 mm", "turns" => "3.5")
    @test Models.amount(0.5235987755982988, "deg") == "0.523599 rad" && Models.amount(true, "") === nothing && Models.amount(NaN, "mm") === nothing
    saved = read(given)
    page = joinpath(dir, "gives.md")
    write(page, "# A design that follows the page\n\nThe block is !`high = 25mm` tall, and !`other = 7` is no parameter of it.\n\n```view\ngiven.sc\n```\n")
    e2 = K.build_editor(page)
    w2 = Window(e2, size=(900px, 700px))
    block() = e2.nodes[(:block, K.VIEW_BLOCK, page, 1)]
    until(done) = for _ in 1:1500
      frame(w2)
      done() && break
      sleep(0.01)
    end
    top(d) = maximum(s.high[3] for s in d.model.shapes)
    settled(d) = d.model !== nothing && !isempty(d.model.shapes) && !Models.busy(d.model) && !haskey(d.parts, :next)
    # The program stays open for as long as the checks take, here. A new process takes seconds to compile them.
    V.KEEP_OPEN[] = 600.0
    number!(from, to) = begin
      i = findfirst(l -> occursin("high = $from", l), e2.buf.lines)
      col = length(e2.buf.lines[i], 1, findfirst(from, e2.buf.lines[i])[1])
      K.edit!(e2.buf, (i, col - 1), (i, col - 1 + length(from) - 2), to, typing=true)
      e2.buf.caret = e2.buf.anchor = (1, 0)
    end
    frame(w2); frame(w2)
    d = block().crumb.viewer
    until(() -> settled(d))
    frame(w2)
    # The design opened with the page's number: the block is 25 mm tall
    @test d.parts[:given] == Dict("high" => "25 mm")
    @test top(d) ≈ 25 atol=0.01
    @test isempty(d.model.said)
    # SolidCraft's program stays open for a while, since a number that's dragged changes again soon
    @test d.model.engine !== nothing && V.kept_open(d)
    first_eye, first_model = d.eye, d.model
    # The page's number changes, and the program that's open makes the block again. It stays turned as it was.
    number!("25mm", "40")
    until(() -> settled(d) && top(d) > 30)
    frame(w2)
    @test d.parts[:given] == Dict("high" => "40 mm")
    @test top(d) ≈ 40 atol=0.01
    @test d.model === first_model && d.model.engine !== nothing && d.eye == first_eye
    # Frames with no change ask for nothing
    at = d.parts[:changed]
    foreach(_ -> frame(w2), 1:5)
    @test d.parts[:changed] == at && !Models.busy(d.model)
    # A number that SolidCraft can't make the block with is said over the design. From this change, the program stays open for a second.
    V.KEEP_OPEN[] = 1.0
    number!("40mm", "0")
    until(() -> !Models.busy(d.model) && !isempty(d.model.said))
    frame(w2)
    @test occursin("SolidCraft can't make", d.model.said) && occursin("Block", d.model.said)
    # The program ends by itself when the numbers haven't changed for a while, with no frame drawn
    sleep(V.KEEP_OPEN[] + 1)
    @test d.model.engine === nothing && !V.kept_open(d)
    frame(w2)
    @test d.model === first_model
    # Then a change opens the design again with the new number, and the one that showed stays until it's made
    number!("0mm", "30")
    frame(w2)
    @test haskey(d.parts, :next) && d.model === first_model
    until(() -> settled(d) && d.model !== first_model)
    frame(w2)
    @test top(d) ≈ 30 atol=0.01
    @test isempty(d.model.said)
    @test d.eye == first_eye
    V.KEEP_OPEN[] = 30.0
    # The file kept its own numbers
    @test read(given) == saved
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
