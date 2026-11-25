# Tests for the `result` block of main.jl, which shows what Julia code comes to:
# the code in the block, or a Julia file that it names. Run them with
# `julia -O0 --project=. test/result_block_test.jl`. They draw in a window
# that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a
# picture of the page there.

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

# A wedge with four faces that's as wide as the page's sum `span`, as the bytes of a .glb file
const SHAPE = raw"""
const calls = Ref(0)
const TEXT = "{'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0}],'meshes':[{'primitives':[{'attributes':{'POSITION':0}}]}]," *
             "'accessors':[{'bufferView':0,'componentType':5126,'count':12,'type':'VEC3','min':[0,0,0],'max':[WIDE,1,1]}]," *
             "'bufferViews':[{'buffer':0,'byteOffset':0,'byteLength':144}],'buffers':[{'byteLength':144}]}"
"The wedge"
wedge(span) = begin
  calls[] += 1
  w = Float32(convert(Float64, span)) * SCALE   # the tests write this file with a number here
  bin = collect(reinterpret(UInt8, Float32[0, 0, 0, w, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, w, 0, 0, w, 0, 0, 0, 0, 1, 0, 1, 0]))
  text = replace(TEXT, '\'' => '"', "WIDE" => string(w))
  text *= " "^((4 - sizeof(text) % 4) % 4)
  io = IOBuffer()
  write(io, 0x46546c67, UInt32(2), UInt32(28 + sizeof(text) + length(bin)), UInt32(sizeof(text)), 0x4e4f534a, text, UInt32(length(bin)), 0x004e4942, bin)
  take!(io)
end
"""
# The file of a `result` block ends with a line that reads the page's sums
shape_code(scale) = replace(SHAPE, "SCALE" => string(scale), count=1) * "wedge(span)\n"
write(shape, shape_code(1))
# A file that other code loads has no such line, since it has no page's sums then
write(joinpath(dir, "wedges.jl"), replace(SHAPE, "SCALE" => "3", count=1))
write(joinpath(dir, "broken.jl"), "x = 1\nerror(\"no wing today\")\n")
# A file's names stay in its own module: N is a newton on the page
write(joinpath(dir, "own.jl"), "const N = 512\ntwice(x) = 2x\ntwice(N)\n")
write(page, """
# Made

The wing spans !`span = 70m`, and pulls with !`pull = 3N`.

```result
shape.jl
```

```result
"The wing is \$(round(Int, convert(Float64, span))) metres"
```

```result
broken.jl
```

```result
own.jl
```

```result
area = span * 2m
undefined_thing + area
```

```result
fs"shape.jl"
```

```result
missing.jl
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 2000px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()
block(n) = e.nodes[(:block, K.RESULT, page, n)]
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
"The Fillable of the `n`th block, with its buttons, which show while the mouse is over the block"
over(n) = (at(middle(rect(block(n)))); K.fills(e)[objectid(block(n))])
"The module that the file `shape.jl` runs in"
shape_module() = K.RESULT_MODULES[(K.page_key(page), block(1).file)]
calls() = Base.invokelatest(getglobal, shape_module(), :calls)[]
"The world in which the file's function `wedge` was made, which is later each time the function is made again"
made_at() = first(methods(Base.invokelatest(getglobal, shape_module(), :wedge))).primary_world
"The line of the page that has `text`, and the column where `part` starts in it"
place(text, part) = (i = findfirst(l -> occursin(text, l), e.buf.lines); (i, length(e.buf.lines[i], 1, findfirst(part, e.buf.lines[i])[1]) - 1))

@testset "which lines stay between runs" begin
  lasting(code) = K.lasting(Meta.parse(code))
  @test lasting("f(x) = 2x") && lasting("f(x)::Int = 2x") && lasting("f(x::T) where T = x") && lasting("function f(x) x end")
  @test lasting("const N = 5") && lasting("struct P; x::Int end") && lasting("abstract type Q end") && lasting("macro m() end")
  @test lasting("using Base64") && lasting("import Base: show") && lasting("@use \"./x.jl\" y") && lasting("module M end")
  @test lasting("Base.@kwdef struct R; x::Int = 1 end") && lasting("Base.show(io::IO, p::P) = print(io, 1)")
  # A docstring before a function is a part of it
  @test K.lasting(Meta.parseall("\"Two times x\"\nf(x) = 2x").args[2])
  @test !lasting("x = 5") && !lasting("x::Int = 5") && !lasting("f(2)") && !lasting("a, b = 1, 2") && !lasting("@show x") && !lasting("begin f(x) = x end")
  @test K.ends_lasting("x = 1\nf(x) = x") && !K.ends_lasting("f(x) = x\nf(1)")
  # A file gets the sums whose names it uses and doesn't make itself
  u = K.used_names("const tubes = 3\n\"Doc\"\nf(x)::Int = x + l\nstruct P{T} <: Any; a::T end\ny = 2\nf(h) * y")
  @test :l in u && :h in u && !any(in(u), (:tubes, :f, :P, :y))
  # A block names a file with one line that ends in .jl, and no space in it
  @test K.result_named(["", "wall.jl", ""]) == "wall.jl" && K.result_named(["~/code/wall.jl"]) == "~/code/wall.jl"
  @test K.result_named(["wall(l, h)"]) == "" && K.result_named(["wall.jl", "x"]) == "" && K.result_named(["\"a.jl\""]) == ""
end

@testset "a block shows what its code or its file comes to" begin
  v = block(1)
  # The bytes of a .glb file show as a model, which is as wide as the page's sum
  @test v.named == "shape.jl" && v.file == shape && v.ready && isempty(v.fault)
  @test v.node isa K.STLViewer && v.node.model isa K.Mesh && v.node.model.size[1] == 70
  @test rect(v.node) !== nothing && v.node.parent === v
  # The viewer has a frame, so the block adds none: it's as big as the viewer. No line under the model names the file.
  @test rect(v).width == rect(v.node).width && rect(v).height == rect(v.node).height && !v.node.foot
  # The file ran once: the sums hadn't changed in the frames after
  @test calls() == 1
  # Code in the block runs too, and has the page's sums with their units. A value that's no node shows as text.
  @test block(2).named == "" && block(2).value == "The wing is 70 metres" && block(2).node === nothing && block(2).text == "The wing is 70 metres"
  # Code that fails says on which line of its file
  @test block(3).fault == "Line 2 of broken.jl: no wing today"
  # A file's names are its own: the page's N is still a newton, and the page has no `twice`
  @test block(4).text == "1024" && !Base.invokelatest(isdefined, K.workspace(e), :twice)
  @test K.made(e, "pull = 3N", 1)[1] == "3N"
  # Code in the block runs in the page's module, and fails on the line of the page that it's on
  i = findfirst(==("undefined_thing + area"), e.buf.lines)
  name(n) = Base.invokelatest(getglobal, K.workspace(e), n)
  @test startswith(block(5).fault, "Line $i of made.md: UndefVarError") && name(:area) == name(:span) * 2 * name(:m)
  # It doesn't name the page's module, whose name is the page's long path
  @test !occursin("Main.", block(5).fault)
  # A node shows as itself. A path is beside the page.
  @test block(6).node isa K.Shown && block(6).node.value isa K.Breadcrumb && block(6).node.value.at == realpath(shape)
  # A file that isn't there says so, and runs nothing
  @test !block(7).ready && rect(block(7)) !== nothing
  # The block of a file has the button that goes to it. Text has no button.
  @test K.fills(e)[objectid(block(1))].what == (:go, shape)
  @test !haskey(K.fills(e), objectid(block(2)))
  @test !K.dirty(e.buf)
  shot("result-block.png")
end

@testset "the model follows a sum, and the file's functions aren't made again" begin
  v = block(1)
  viewer, before, world = v.node, v.node.model, made_at()
  viewer.turn, viewer.zoom = 80.0, 2.5
  i, col = place("span = 70m", "70m")
  K.edit!(e.buf, (i, col), (i, col + 2), "85", typing=true)
  frames()
  @test v.node === viewer && viewer.model !== before && viewer.model.size[1] == 85
  @test viewer.turn == 80.0 && viewer.zoom == 2.5
  # Only the last line ran again, so `calls` kept its count and `wedge` is the function it was
  @test calls() == 2 && made_at() == world && !v.whole
  @test block(2).value == "The wing is 85 metres"
  # Frames with no change don't run the code again
  frames(5)
  @test calls() == 2
end

@testset "a run of the page's code runs the blocks again" begin
  v = block(2)
  K.code_ran!(page)
  frames()
  @test v.given[2] == K.PAGE_RUNS[K.page_key(page)] && calls() == 3
end

@testset "the first button makes the model fill the window, and the second goes to the file" begin
  v = block(1)
  viewer, high = v.node, v.node.height
  f = over(1)
  @test f.what == (:go, shape) && f.also == (:node, viewer)
  @test f.expand !== nothing && f.button !== nothing && rect(f.expand).top < rect(f.button).top
  click(middle(rect(f.expand)))
  # The model has the window under the top bar, and the window is still on the page
  z = K.zooming(e)
  @test z !== nothing && z.what == (:node, viewer) && e.buf.path == page && viewer.fill
  r = rect(viewer)
  @test (r.left, r.top, r.width, r.height) == (0px, K.TOPBAR_H, 1000px, 2000px - K.TOPBAR_H)
  # Esc puts the page back, with the model in it as it was
  onkey(w, KeyPress{Keys.escape}(0, w)); frames()
  @test K.zooming(e) === nothing && !viewer.fill && viewer.height == high && rect(block(1)).height == rect(viewer).height
  # The second button goes to the file, and ⌘⌥← comes back
  click(middle(rect(over(1).button)))
  @test e.buf.path == shape
  K.go_back!(e); frames()
  @test e.buf.path == page
end

@testset "a saved file runs again, all of it" begin
  v = block(1)
  viewer, world = v.node, made_at()
  sleep(1.1)   # so that the disk gives the file a later time
  write(shape, shape_code(2))
  frames()
  @test v.node === viewer && viewer.model.size[1] == 170 && isempty(v.fault) && v.whole && made_at() > world
  # A file that no longer runs says why, and one that's mended shows its model again
  sleep(1.1)
  write(shape, shape_code(2) * "\nundefined_name\n")
  frames()
  @test occursin("undefined_name", v.fault)
  sleep(1.1)
  write(shape, shape_code(3))
  frames()
  @test isempty(v.fault) && viewer.model.size[1] == 255
end

@testset "the wall of the welcome page is as long and as high as its sums" begin
  cp(joinpath(K.pages_dir[], "wall.jl"), joinpath(dir, "wall.jl"))
  walls = joinpath(dir, "walls.md")
  write(walls, "A wall that is !`l = 12m` long and !`h = 3m` high.\n\n```result\nwall.jl\n```\n\n```result\nwall(8, 2)\n```\n")
  e2 = K.build_editor(walls)
  w2 = Window(e2, size=(900px, 900px))
  foreach(_ -> frame(w2), 1:3)
  v = e2.nodes[(:block, K.RESULT, walls, 1)]
  @test isempty(v.fault) && v.node.model isa K.Mesh
  # The person beside it stands 1.15 metres out from its back
  @test all(isapprox.(v.node.model.size, (12, 1.15, 3), atol=1e-4))
  @test length(v.node.model.normals) == 24
  # Code in the block can't call what the file made: the file runs in a module of its own
  @test occursin("wall", e2.nodes[(:block, K.RESULT, walls, 2)].fault)
  # The same wall as a .glb file shows in a `view` block as big as the block
  write(joinpath(dir, "wall.glb"), v.value)
  under = joinpath(dir, "under.md")
  write(under, "```result\nwall.jl\n```\n\n```view\nwall.glb\n```\n\nA wall that is !`l = 12m` long and !`h = 3m` high.\n")
  e5 = K.build_editor(under)
  w5 = Window(e5, size=(900px, 900px))
  foreach(_ -> frame(w5), 1:4)
  made, file = e5.nodes[(:block, K.RESULT, under, 1)], e5.nodes[(:block, K.VIEW_BLOCK, under, 1)]
  # The sums are under the block, so it shows the wall once they've run
  @test isempty(made.fault) && all(isapprox.(made.node.model.size, (12, 1.15, 3), atol=1e-4))
  @test file.crumb.viewer isa K.STLViewer && file.crumb.viewer.model.size[1] == 12
  @test rect(made).width == rect(file).width && rect(made).height == rect(made.node).height
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "result-wall.png"), w5)
end

@testset "a line `aspect:` sets the shape of a model" begin
  shapes = joinpath(dir, "shapes.md")
  write(shapes, "The wing spans !`span = 70m`.\n\n```result\nshape.jl\naspect: 2:1\n```\n\n```result\nshape.jl\n```\n")
  e3 = K.build_editor(shapes)
  w3 = Window(e3, size=(900px, 1200px))
  foreach(_ -> frame(w3), 1:3)
  v3(n) = e3.nodes[(:block, K.RESULT, shapes, n)]
  set, plain = v3(1), v3(2)
  @test set.aspect == 2 && set.settings == ["aspect: 2:1"] && set.named == "shape.jl" && plain.aspect == 0
  # The viewer's frame and the rounding to a whole pixel take up to 3 pixels from the shape
  r = rect(set.node)
  @test abs(r.height - r.width / 2) <= 3px && rect(set).height == r.height
  @test plain.node.height == K.MODEL_HEIGHT
end

@testset "a code block shows a model, with the button that fills the window" begin
  coded = joinpath(dir, "coded.md")
  write(coded, "The wing spans !`span = 70m`.\n\n```result\n@use \"./wedges.jl\" wedge\nwedge(span)\n```\n")
  e4 = K.build_editor(coded)
  w4 = Window(e4, size=(900px, 900px))
  foreach(_ -> frame(w4), 1:3)
  v = e4.nodes[(:block, K.RESULT, coded, 1)]
  @test isempty(v.fault) && v.node isa K.STLViewer && v.node.model.size[1] == 210
  # It names no file, so its one button makes the model fill the window
  @test K.fills(e4)[objectid(v)].what == (:node, v.node) && K.fills(e4)[objectid(v)].also === nothing
end

@testset "a file's constant and a sum with the same name don't clash" begin
  write(joinpath(dir, "clash.jl"), "const tubes = 3\nconst runs = Ref(0)\nruns[] += 1\ntubes * convert(Float64, span)\n")
  clash = joinpath(dir, "clash.md")
  write(clash, "There are !`tubes = 4` tubes and a span of !`span = 2m`.\n\n```result\nclash.jl\n```\n")
  e6 = K.build_editor(clash)
  w6 = Window(e6, size=(900px, 600px))
  foreach(_ -> frame(w6), 1:3)
  v = e6.nodes[(:block, K.RESULT, clash, 1)]
  runs() = Base.invokelatest(getglobal, K.RESULT_MODULES[(K.page_key(clash), v.file)], :runs)[]
  @test isempty(v.fault) && v.value == 6.0 && runs() == 1 && :span in v.wanted && !(:tubes in v.wanted)
  # A sum that the file doesn't use changes nothing, and one that it uses runs it again
  edit(text, part, new) = (i = findfirst(l -> occursin(text, l), e6.buf.lines); c = length(e6.buf.lines[i], 1, findfirst(part, e6.buf.lines[i])[1]) - 1;
                           K.edit!(e6.buf, (i, c), (i, c + length(part)), new, typing=true); foreach(_ -> frame(w6), 1:3))
  edit("tubes = 4", "4", "5")
  @test runs() == 1 && v.value == 6.0
  edit("span = 2m", "2m", "3m")
  @test isempty(v.fault) && runs() == 2 && v.value == 9.0 && !v.whole
end

@testset "the block's lines are Julia, and the Insert menu has it" begin
  @test K.shared_lang(K.RESULT) == "julia" && !(K.RESULT in K.NO_NAMES)
  @test any(i -> i[1] == "Result", K.INSERTS)
end

exit()
