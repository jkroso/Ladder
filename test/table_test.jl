# Tests for a table in a page: how its columns share the width of the page. See
# `grid` in main.jl. Run them with `julia -O0 --project=. test/table_test.jl`.
# They use a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")

"A window that isn't on the screen, on a file with `text` in it"
window(text; name="page.md") = begin
  path = joinpath(dir, name)
  write(path, text)
  e = K.build_editor(path)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  e, w
end

"The text of each line on screen of a flow"
words(flow) = [join(seg.text for seg in vl.segs) for vl in flow.lines]

"How far the text of a flow reaches across its cell"
reach(flow) = maximum(vl -> isempty(vl.segs) ? 0px : vl.segs[end].x + vl.segs[end].w, flow.lines)

@testset "a table too wide for the page wraps its long text, and cuts no word short" begin
  # The list of a folder on a blog: a long description, and two columns of days
  e, w = window("""
    | Name | Description | Created | Modified |
    | --- | --- | --- | --- |
    | [Book Reviews](a.md) | I try and write notes on all the books I read. Sometimes I actually do, and sometimes I write a lot more than notes | 2026-03-18 | 2026-11-24 |
    | [Politics and Economics](b.md) | The allocation of resources within society | 2025-07-03 | 2026-10-04 |
    """)
  g = K.item(e, 1).content
  @test g isa K.Grid && length(g.widths) == 4
  # The columns fill the page
  @test isapprox(K.num(sum(g.widths)), K.num(e.width) - 5, atol=0.01)
  for r in 1:3, c in 1:4
    f = g.flows[r][c]
    # Each word of each cell is inside its cell
    @test reach(f) <= g.widths[c] - K.CELL_X + 0.5px
  end
  # A day is on one line, and so is the name of a column
  @test words(g.flows[2][3]) == ["2026-03-18"] && words(g.flows[2][4]) == ["2026-11-24"]
  @test words(g.flows[1][4]) == ["Modified"]
  # The description takes the room that's left, and wraps
  @test length(g.flows[2][2].lines) > 1 && g.widths[2] == maximum(g.widths)
end
