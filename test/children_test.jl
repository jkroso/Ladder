# Tests for the children of the document, in main.jl: the parts of the page that
# shows are the document's children, so one part can find another by a walk of
# the tree. See `own!` and `unlist!`. Run them with
# `julia -O0 --project=. test/children_test.jl`. They draw in a window that isn't
# on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

# The folder is the test's own each time, so that two test processes that run at once don't write the same files
const dir = mktempdir()
const page = joinpath(dir, "job.md")
const other = joinpath(dir, "other.md")

write(joinpath(dir, "shout.jl"), """
shout(lines) = uppercase(join(lines, " "))
""")

write(page, """
# A job

Here is a switch !`Toggle(on=true)` in a line.

| Month | Sales |
|---|---|
| Jan | 1200 |
| Feb | 1500 |

```chart
title: Sales
```

```shout
lay the pipe
```

```ui
Text("made by code")
```

The end.
""")

write(other, """
# Another page

```shout
dig the trench
```
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
doc() = e.nodes[:document]
children() = collect(doc().children)
place(node) = findfirst(c -> c === node, children())
chart() = e.nodes[(:block, "chart", page, 1)]
shout(path=page) = e.nodes[(:block, "shout", path, 1)]
live() = only(v for (k, v) in e.nodes if k isa Tuple && k[1] == :live)

@testset "the parts of the page are the document's children" begin
  @test chart() isa K.ChartView && shout() isa K.FileBlock && live() isa K.Shown
  @test all(node -> node.parent === doc() && place(node) !== nothing, [chart(), shout(), live()])
  # They come in the order of their lines
  @test place(chart()) < place(shout()) < place(live())
  # The blocks that are made for the lines on screen are children too
  @test any(c -> c isa K.Heading, children()) && any(c -> c isa K.Paragraph, children()) && any(c -> c isa K.Table, children())
  # Each child is there once, and its neighbours point back at it
  @test allunique(objectid.(children()))
  @test all(i -> children()[i].prevsibling === (i == 1 ? nothing : children()[i-1]), eachindex(children()))
  @test all(c -> c.parent === doc(), children())
end

@testset "one part finds another by a walk of the tree" begin
  # From what the block shows, up to the document, and down to the chart
  found = [c for c in shout().shown.parent.parent.children if c isa K.ChartView]
  @test found == [chart()]
  @test K.editor(found[1]) === e
end

@testset "a frame doesn't add to the children" begin
  n = length(children())
  before = filter(c -> c isa K.Paragraph, children())
  frames(5)
  @test length(children()) == n
  # A paragraph is made again on each frame. The one from the frame before has left the list, and can still reach the editor.
  @test !any(old -> place(old) !== nothing, before)
  @test all(old -> K.editor(old) === e, before)
end

@testset "what code in a line makes belongs to its line" begin
  inline = [v for (k, v) in e.nodes if k isa Tuple && k[1] == :inline && v isa K.Shown]
  @test length(inline) == 1 && inline[1].parent === doc()
  @test place(inline[1]) === nothing
end

@testset "a block that shows as its lines isn't a child" begin
  s = K.block_lines(e.buf, "shout", 1)
  e.buf.caret = e.buf.anchor = (s[1] + 1, 0); frames()
  @test place(shout()) === nothing && place(chart()) !== nothing
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  @test place(chart()) < place(shout()) < place(live())
end

@testset "the children are those of the page that shows" begin
  first_page = [chart(), shout(), live()]
  K.open!(e, other); frames()
  @test place(shout(other)) !== nothing
  @test !any(node -> place(node) !== nothing, first_page)
  K.open!(e, page); frames()
  @test all(node -> place(node) !== nothing, first_page)
  @test place(shout(other)) === nothing
  @test allunique(objectid.(children()))
end
