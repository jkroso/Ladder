# Tests for a `view` block of main.jl that names a Julia file: the file's
# function `view` makes what the block shows, from the document's sums. Run
# them with `julia -O0 --project=. test/view_made_test.jl`. They draw in a
# window that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they
# save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use GeometryBasics: Vec2
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

# Every run has come back when a frame ends
K.RUN_WAIT[] = Inf

const dir = mktempdir()
const page = joinpath(dir, "made.md")
const shape = joinpath(dir, "shape.jl")

# A wedge with four faces that's as wide as the sum `span`, as the bytes of a .glb file
const SHAPE = raw"""
const calls = Ref(0)
const TEXT = "{'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0}],'meshes':[{'primitives':[{'attributes':{'POSITION':0}}]}]," *
             "'accessors':[{'bufferView':0,'componentType':5126,'count':12,'type':'VEC3','min':[0,0,0],'max':[WIDE,1,1]}]," *
             "'bufferViews':[{'buffer':0,'byteOffset':0,'byteLength':144}],'buffers':[{'byteLength':144}]}"
view(sums) = begin
  calls[] += 1
  w = Float32(get(sums, "span", 1.0)) * SCALE   # the tests write this file with a number here
  bin = collect(reinterpret(UInt8, Float32[0, 0, 0, w, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, w, 0, 0, w, 0, 0, 0, 0, 1, 0, 1, 0]))
  text = replace(TEXT, '\'' => '"', "WIDE" => string(w))
  text *= " "^((4 - sizeof(text) % 4) % 4)
  io = IOBuffer()
  write(io, 0x46546c67, UInt32(2), UInt32(28 + sizeof(text) + length(bin)), UInt32(sizeof(text)), 0x4e4f534a, text, UInt32(length(bin)), 0x004e4942, bin)
  take!(io)
end
"""
shape_code(scale) = replace(SHAPE, "SCALE" => string(scale), count=1)
write(shape, shape_code(1))
write(joinpath(dir, "words.jl"), "view(sums) = \"The wing is \$(round(Int, sums[\"span\"])) metres\"\n")
write(joinpath(dir, "plain.jl"), "width(sums) = 4\n")
write(joinpath(dir, "broken.jl"), "view(sums) = error(\"no wing today\")\n")
write(page, """
# Made

The wing spans !`span = 70m`.

```view
shape.jl
```

```view
words.jl
```

```view
plain.jl
```

```view
broken.jl
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1600px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()
view(n) = e.nodes[(:block, K.VIEW_BLOCK, page, n)]
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
"The Fillable of the `n`th view, with its buttons, which show while the mouse is over the view"
over(n) = (at(middle(rect(view(n)))); K.fills(e)[objectid(view(n))])
"The module of the file `shape.jl`"
shape_module() = K.Kip.modules[realpath(shape)]
calls() = Base.invokelatest(getglobal, shape_module(), :calls)[]

@testset "a Julia file's function makes what the view shows" begin
  @test K.view_made(view(1)) && K.view_made(view(2)) && K.view_made(view(4))
  m = view(1).made
  # The bytes of a .glb file show as a model, which is as wide as the document's sum
  @test m.ready && isempty(m.fault) && m.node isa K.STLViewer && m.node.model isa K.Mesh
  @test m.node.model.size[1] == 70 && m.sums["span"] == 70
  @test rect(m.node) !== nothing && m.node.parent === view(1)
  # The viewer has a frame, so the block adds none: it's as big as the viewer. No line under the model names the file.
  @test rect(view(1)).width == rect(m.node).width && rect(view(1)).height == rect(m.node).height
  @test !m.node.foot && length(rect(m.node).children) == 1
  # Words have the block's frame round them, and the file's name under them
  @test rect(view(2)).height > 40px
  # The function ran once: the sums hadn't changed in the frames after
  @test calls() == 1
  # Any other value shows as text
  @test view(2).made.value == "The wing is 70 metres" && view(2).made.node === nothing
  # A file with no function called `view` shows its code
  @test !K.view_made(view(3)) && view(3).made === nothing && view(3).crumb !== nothing
  # A function that fails says why
  @test occursin("no wing today", view(4).made.fault)
  # The view has the button that goes to the file
  @test K.fills(e)[objectid(view(1))].what == (:go, shape)
  @test !K.dirty(e.buf)
  shot("view-made.png")
end

@testset "the model follows a sum, and stays turned as it was" begin
  m = view(1).made
  viewer, before = m.node, m.node.model
  viewer.turn, viewer.zoom = 80.0, 2.5
  i = findfirst(l -> occursin("span = 70m", l), e.buf.lines)
  col = length(e.buf.lines[i], 1, findfirst("70m", e.buf.lines[i])[1])
  K.edit!(e.buf, (i, col - 1), (i, col + 1), "85", typing=true)
  frames()
  @test m.node === viewer && viewer.model !== before && viewer.model.size[1] == 85
  @test viewer.turn == 80.0 && viewer.zoom == 2.5
  @test calls() == 2 && view(2).made.value == "The wing is 85 metres"
  # Frames with no change don't run the function again
  frames(5)
  @test calls() == 2
end

@testset "the first button makes the model fill the window, and the second goes to the file" begin
  m = view(1).made
  viewer, high = m.node, m.node.height
  f = over(1)
  @test f.what == (:go, shape) && f.also == (:node, viewer)
  @test f.expand !== nothing && f.button !== nothing && rect(f.expand).top < rect(f.button).top
  # Words have nothing to fill the window with, so their view has only the button that goes to the file
  words = over(2)
  @test words.also === nothing && words.expand === nothing
  f = over(1)
  click(middle(rect(f.expand)))
  # The model has the window under the top bar, with no frame, and the window is still on the document
  z = K.zooming(e)
  @test z !== nothing && z.what == (:node, viewer) && e.buf.path == page && viewer.fill
  r = rect(viewer)
  @test (r.left, r.top, r.width, r.height) == (0px, K.TOPBAR_H, 1000px, 1600px - K.TOPBAR_H)
  # Nothing lies over the model: no button of the view that fills the window shows
  @test !any(b -> b isa K.PlanButton && rect(b) !== nothing, values(z.parts))
  shot("view-made-full.png")
  # Esc puts the document back, with the model in it as it was
  onkey(w, KeyPress{Keys.escape}(0, w)); frames()
  @test K.zooming(e) === nothing && !viewer.fill && viewer.height == high && rect(view(1)).height == rect(viewer).height
  # The second button goes to the file, and ⌘⌥← comes back
  click(middle(rect(over(1).button)))
  @test e.buf.path == shape
  K.go_back!(e); frames()
  @test e.buf.path == page
end

@testset "a saved file runs again" begin
  m = view(1).made
  viewer = m.node
  sleep(1.1)   # so that the disk gives the file a later time
  write(shape, shape_code(2))
  frames()
  @test m.node === viewer && viewer.model.size[1] == 170 && isempty(m.fault)
  # A file that no longer loads says why, and one that's mended shows its model again
  sleep(1.1)
  write(shape, shape_code(2) * "\nview(sums) = undefined_name\n")
  frames()
  @test occursin("undefined_name", m.fault)
  sleep(1.1)
  write(shape, shape_code(3))
  frames()
  @test isempty(m.fault) && viewer.model.size[1] == 255
end

@testset "the wall of the welcome page is as long and as high as its sums" begin
  cp(joinpath(K.pages_dir[], "wall.jl"), joinpath(dir, "wall.jl"))
  walls = joinpath(dir, "walls.md")
  # The same wall as a .glb file, which a view shows in the same way
  code = K.Kip.require(realpath(joinpath(dir, "wall.jl")))
  write(joinpath(dir, "wall.glb"), Base.invokelatest(Base.invokelatest(getglobal, code, :view), Dict{String,Any}()))
  write(walls, "A wall that is !`l = 12m` long and !`h = 3m` high.\n\n```view\nwall.jl\n```\n\n```view\nwall.glb\n```\n")
  e2 = K.build_editor(walls)
  w2 = Window(e2, size=(900px, 900px))
  foreach(_ -> frame(w2), 1:3)
  m = e2.nodes[(:block, K.VIEW_BLOCK, walls, 1)].made
  @test isempty(m.fault) && m.node.model isa K.Mesh
  # The person beside it stands 1.15 metres out from its back
  @test all(isapprox.(m.node.model.size, (12, 1.15, 3), atol=1e-4))
  @test length(m.node.model.normals) == 24
  made, file = e2.nodes[(:block, K.VIEW_BLOCK, walls, 1)], e2.nodes[(:block, K.VIEW_BLOCK, walls, 2)]
  @test file.crumb.viewer isa K.STLViewer && file.crumb.viewer.model.size[1] == 16 && !file.crumb.viewer.foot
  # A model's file in a view has both buttons too
  @test K.view_fills(file, e2) == (:node, file.crumb.viewer) && K.fills(e2)[objectid(file)].also == (:node, file.crumb.viewer)
  @test rect(made).height == rect(m.node).height && rect(file).height == rect(file.crumb.viewer).height
  @test rect(file).width == rect(file.crumb.viewer).width == rect(made).width
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "view-wall.png"), w2)
end

@testset "a page from somebody else runs no file" begin
  @test K.foreign("https://example.com/made.md")
  was = e.buf.path
  e.buf.path = "https://example.com/made.md"
  @test !K.view_made(view(1))
  e.buf.path = was
end

exit()
