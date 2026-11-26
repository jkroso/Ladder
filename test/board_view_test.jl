# Tests for the `board` block of main.jl: the page's to-do items as cards in
# columns. Run them with `julia -O0 --project=. test/board_view_test.jl`. They
# drag cards in a window that isn't on the screen. Set `LADDER_SHOTS` to a
# folder, and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "job.md")
write(page, """
# A job

- [x] Dig the trench
- [ ] Lay the pipe
- [ ] Test the pipe
- [ ] Fill the trench, and then put back the turf and the paving that was lifted, all of it

```board
Lay the pipe | Doing
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, press, release, click, shot) = drive(w)
frames()
const v = e.nodes[(:block, K.BOARD, page, 1)]

"Press the mouse at one place, move it to another by way of the place between, and let go"
drag(from, to) = (press(from); at(((from[1] + to[1]) / 2, (from[2] + to[2]) / 2)); at(to); release())
block() = (s = K.block_lines(e.buf, K.BOARD, 1); e.buf.lines[s[1]+1:s[2]-1])
card(name) = middle(rect(v.parts[(:card, name)]))
column(c) = (r = rect(v.parts[(:column, c)]); (K.num(r.left + r.width / 2), K.num(r.top + r.height - 12)))
names(c) = [t.name for t in K.columns!(v)[c]]
line(name) = e.buf.lines[findfirst(l -> endswith(l, name), e.buf.lines)]
const FILL = "Fill the trench, and then put back the turf and the paving that was lifted, all of it"

@testset "the board shows the page's items in columns" begin
  @test names(1) == ["Test the pipe", FILL] && names(2) == ["Lay the pipe"] && names(3) == ["Dig the trench"]
  # The columns are side by side, each as wide as the next
  cols = [rect(v.parts[(:column, c)]) for c in 1:3]
  @test cols[1].left < cols[2].left < cols[3].left && cols[1].width ≈ cols[2].width ≈ cols[3].width
  # A long item wraps in its card
  @test rect(v.parts[(:card, FILL)]).height > rect(v.parts[(:card, "Test the pipe")]).height
  @test any(en -> en.title == "Board", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Board", K.INSERTS)
  @test !K.dirty(e.buf)
end

@testset "a drag moves a card" begin
  press(card("Test the pipe")); at(column(2) .- (30, 0)); at(column(2))
  @test K.dragging(v) && K.drop_column(v) == 2
  shot("board.png")
  release()
  @test names(2) == ["Lay the pipe", "Test the pipe"] && block() == ["Lay the pipe | Doing", "Test the pipe | Doing"] && v.grab === nothing
  # To the last column: the item is ticked, and its line of the board goes
  drag(card("Lay the pipe"), column(3))
  @test names(3) == ["Dig the trench", "Lay the pipe"] && line("Lay the pipe") == "- [x] Lay the pipe" && block() == ["Test the pipe | Doing"]
  # One ⌘Z takes back the tick and the board's line together
  K.undo!(e.buf); frames()
  @test line("Lay the pipe") == "- [ ] Lay the pipe" && block() == ["Lay the pipe | Doing", "Test the pipe | Doing"] && names(2) == ["Lay the pipe", "Test the pipe"]
  # Out of the last column: the tick goes
  drag(card("Dig the trench"), column(1))
  @test line("Dig the trench") == "- [ ] Dig the trench" && names(1) == ["Dig the trench", FILL] && length(block()) == 2
  # A card that's dropped on its own column, or away from the board, stays
  drag(card("Dig the trench"), column(1))
  drag(card("Dig the trench"), (500, 880))
  @test names(1) == ["Dig the trench", FILL] && length(block()) == 2
  @test e.buf.lines[end-1] == "The end."
end

@testset "the page changes, and the board with it" begin
  i = findfirst(==("- [ ] Test the pipe"), e.buf.lines)
  K.tick!(e, i); frames()
  @test names(3) == ["Test the pipe"] && names(2) == ["Lay the pipe"]
  K.tick!(e, i); frames()
  @test names(2) == ["Lay the pipe", "Test the pipe"]
  # An item whose text changes keeps its column
  K.edit!(e.buf, (i, length(e.buf.lines[i])), (i, length(e.buf.lines[i])), " twice")
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  @test names(2) == ["Lay the pipe", "Test the pipe twice"]
  html = K.page_html(e)
  @test occursin("<th>To do</th><th>Doing</th><th>Done</th>", html) && occursin("Lay the pipe<br>Test the pipe twice</td>", html)
end

@testset "two clicks on a card go to its line" begin
  click(card("Lay the pipe")); click(card("Lay the pipe"))
  @test e.buf.caret[1] == findfirst(==("- [ ] Lay the pipe"), e.buf.lines) && w.focus === e
end
