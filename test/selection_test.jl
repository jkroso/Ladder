# Tests for where the colour of the selection goes. See `marks` in main.jl.
# Run them with `julia -O0 --project=. test/selection_test.jl`. They select text in a
# window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const file = joinpath(dir, "walls.md")
write(file, """
# Walls

Some words here.

```julia
width = 2.4
height = 3.6
```

> a quote
""")

const e = K.build_editor(file)
const w = Window(e, size=(1000px, 800px))
const (; frames) = drive(w)
frames()

"The boxes of the selection on line `i`, as the page draws them, from the left edge of the page's text"
boxes(i) = begin
  sel = K.selected(e.buf, i)
  sel === nothing ? K.Rect[] : K.marks(K.item(e, i).content, 0px, 0px, sel, margin=!K.within_code(e.buf) && K.selection(e.buf)[1][1] < i)
end
select!(lo, hi) = (e.buf.anchor = lo; e.buf.caret = hi; frames())
"Where the text of line `i` starts"
inset(i) = K.num(K.item(e, i).content.lines[1].x)

@testset "the selection starts where the text does" begin
  @test inset(7) > 0 && inset(10) > 0   # code and quotes are set in from the edge of the page
  # A word at the start of a line of code
  select!((7, 0), (7, 6))
  @test length(boxes(7)) == 1
  @test boxes(7)[1][1] == inset(7)
  # A word at the start of a quote, with its `> `
  select!((10, 0), (10, 3))
  @test boxes(10)[1][1] == inset(10)
  # A word that isn't at the start of its line
  select!((7, 9), (7, 12))
  @test boxes(7)[1][1] > inset(7)
end

@testset "the lines after the first go to the edge of the page" begin
  # The line it starts in begins at its text. Each line after it goes to the edge of the page,
  # so the left edge of the selection is straight from the paragraph to the code.
  select!((3, 5), (7, 6))
  @test boxes(3)[1][1] > 0
  @test all(i -> boxes(i)[1][1] == 0, 4:7)
  # The same goes for a selection that starts in the code and ends under the block
  select!((6, 0), (10, 3))
  @test boxes(6)[1][1] == inset(6)
  @test boxes(7)[1][1] == 0
  @test boxes(10)[1][1] == 0
end

@testset "a selection that's all in one code block leaves the block's padding alone" begin
  select!((6, 0), (7, 6))
  @test boxes(6)[1][1] == inset(6)
  @test boxes(7)[1][1] == inset(7)
  # From the line that opens the block to the line that closes it
  select!((5, 0), (8, 3))
  @test boxes(6)[1][1] == inset(6)
  @test boxes(7)[1][1] == inset(7)
end

@testset "a line with none of its text selected has no box" begin
  # A whole line and the line break after it. The caret is at the start of the next line.
  select!((7, 0), (8, 0))
  @test length(boxes(7)) == 1
  @test isempty(boxes(8))
  # A line with no text in a selection still shows
  select!((3, 0), (5, 3))
  @test length(boxes(4)) == 1
end

exit()
