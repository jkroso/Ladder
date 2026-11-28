# Tests for main.jl's "move a block by its handle": the line round a block that
# a click with ⌘ and ⌥ down chose has a handle at its top left, and a drag of
# the handle moves the block to the gap between two other blocks. Run them with
# `julia -O0 --project=. test/block_handle_test.jl`. They click in a window
# that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a
# picture of the handle and of the line that shows where a block would go.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect scene draw draw_tool window_tool
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

# The folder is the test's own each time, so that two test processes that run at once don't write the same files
const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "handles.md")
const start = """
---
title: Handles
---

# Handles

First paragraph, with a [link](https://example.com).

Second paragraph.

- one
- two

```board
```

Last words."""
write(page, start)

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
frames(n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames(4)
e.buf.anchor = e.buf.caret = (17, 0); K.touch!(e); frames(3)

shot(name) = haskey(ENV, "LADDER_SHOTS") &&
  save_png(joinpath(ENV["LADDER_SHOTS"], name), w.size) do ctx, size
    draw(ctx, size, scene(w))
    draw_tool(ctx, w, window_tool(w), scene(w))
  end

"The middle of the start of line `i` in the window"
spot(i) = (it = K.item(e, i); (e.origin[1] + 30px, e.origin[2] + it.top + it.tall / 2))
"The run of line `i` whose text starts with `text`, and the middle of it in the window"
spot(i, text) = begin
  it = K.item(e, i)
  f = it.content
  for vl in f.lines, seg in vl.segs
    startswith(seg.text, text) || continue
    return (e.origin[1] + seg.x + seg.w / 2, e.origin[2] + it.top + f.above + vl.top + vl.high / 2)
  end
  error("no run $text on line $i")
end
"The top of line `i` in the window"
top_of(i) = e.origin[2] + K.item(e, i).top
move(x, y) = begin
  x, y = convert(px, x), convert(px, y)
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  nothing
end

"Click with ⌘ and ⌥ down at the point `(x, y)` of the window, then draw some frames"
cmd_opt_click(x, y) = begin
  move(x, y)
  w.keys |= Keys.cmd; w.keys |= Keys.opt; frames(1)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.cmd; w.keys ⊻= Keys.opt
  frames(3)
end

const t = K.code_picker(e)
handle() = K.block_drag(e).at
"The middle of the handle"
grip() = (h = handle(); (h[1] + h[3] / 2, h[2] + h[4] / 2))

"Drag the handle of the chosen block to the height `y` of the window, and let go there, unless `esc`"
drag_to(y; esc=false) = begin
  move(grip()...)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  frames(1)
  move(grip()[1], y); frames(1)
  move(grip()[1], y + 1); frames(1)
  esc && (onkey(w, KeyPress{Keys.escape}(0, w)); frames(1))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames(3)
end

lines() = copy(e.buf.lines)

@testset "a whole block that ⌘⌥ chose has a handle, and a part of one has none" begin
  cmd_opt_click(spot(7, "First")...)
  @test t.chosen[1] isa K.Paragraph && t.chosen[1].first == 7
  @test handle() !== nothing
  # It's at the left of the line round the block, level with its top
  r = rect(K.shown_now(t.chosen[1]))
  @test handle()[1] + handle()[3] <= K.num(r.left) && handle()[2] == K.num(r.top)
  # The mouse shows a hand over it
  @test K.tool_cursor(t, w, convert.(px, grip())) == :hand
  shot("block-handle.png")
  # A link is a run of a paragraph's text, not a block
  cmd_opt_click(spot(7, "link")...)
  @test t.chosen[1] isa K.TextRun && handle() === nothing
  # A heading is a block
  cmd_opt_click(spot(5, "Handles")...)
  @test t.chosen[1] isa K.Heading && handle() !== nothing
  onkey(w, KeyPress{Keys.escape}(0, w)); frames(1)
  @test t.chosen === nothing && handle() === nothing
  # A board is all that its block shows, so it's that block. The front matter has no handle.
  parts = K.shown_parts(e)
  board = only(p for p in parts if p isa K.LiveBlock && e.buf.lines[p.first] == "```board")
  view = only(it.content.node for it in board.items if it.content isa K.Live)
  @test K.whole_block(e, view) === board
  matter = only(p for p in parts if p isa K.LiveBlock && p.first == 1)
  @test K.whole_block(e, matter) === nothing
  @test K.whole_block(e, only(it.content.node for it in matter.items)) === nothing
end

@testset "a drag of the handle moves the block to the gap where it's let go" begin
  cmd_opt_click(spot(7, "First")...)
  # Down, into the gap between the second paragraph and the list
  drag_to(top_of(11) - 3px)
  @test e.buf.lines[5:13] == ["# Handles", "", "Second paragraph.", "", "First paragraph, with a [link](https://example.com).", "", "- one", "- two", ""]
  # It keeps its line in its new place, with its handle
  @test t.chosen[1] isa K.Paragraph && t.chosen[1].first == 9 && handle() !== nothing
  @test K.dragging(t) == false
  # One ⌘Z puts it back
  K.undo!(e.buf); frames(2)
  @test join(lines(), "\n") == start
  # Up, to the gap under the heading: the list goes in front of the first paragraph
  cmd_opt_click(spot(11, "one")...)
  @test t.chosen[1] isa K.List && t.chosen[1].first == 11
  drag_to(top_of(7) - 3px)
  @test e.buf.lines[5:12] == ["# Handles", "", "- one", "- two", "", "First paragraph, with a [link](https://example.com).", "", "Second paragraph."]
  @test t.chosen[1] isa K.List && t.chosen[1].first == 7
  K.undo!(e.buf); frames(2)
  @test join(lines(), "\n") == start
  # To the end of the page, under the last block
  cmd_opt_click(spot(7, "First")...)
  drag_to(top_of(17) + K.item(e, 17).tall + 8px)
  @test e.buf.lines[end-2:end] == ["Last words.", "", "First paragraph, with a [link](https://example.com)."]
  K.undo!(e.buf); frames(2)
  @test join(lines(), "\n") == start
end

@testset "a drag shows a line at the gap, and Esc stops it" begin
  cmd_opt_click(spot(7, "First")...)
  move(grip()...)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  frames(1)
  @test K.dragging(t)
  x = K.num(grip()[1])
  move(x, top_of(11) - 3px); frames(1)
  found = K.drop_target(e, K.block_drag(e).lines, x, K.num(top_of(11) - 3px))
  @test found !== nothing && found[1].side == :gap && found[1].line == 11
  # The page selects no text while the mouse moves
  @test e.buf.caret == e.buf.anchor
  shot("block-handle-drag.png")
  # Over the block's own place, it would stay where it is, so there's no line
  @test K.drop_target(e, K.block_drag(e).lines, x, K.num(top_of(7) + 2px)) === nothing
  onkey(w, KeyPress{Keys.escape}(0, w)); frames(1)
  @test !K.dragging(t)
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames(2)
  @test join(lines(), "\n") == start
  # The block keeps its line after the drag stopped
  @test t.chosen !== nothing && t.chosen[1] isa K.Paragraph
  # Nothing goes in front of the front matter
  @test K.drop_target(e, (9, 9), x, 0.0)[1].line == 5
  onkey(w, KeyPress{Keys.escape}(0, w)); frames(1)
end

"What the lines `ls` are after lines `s` to `t` go to the place `drop`, or nothing"
moved(ls, s, t, drop) = begin
  ks = K.classify(ls)
  gs = K.Columns.groups(ls, ks, alone=i -> K.alone_line(ls, ks, i))
  doc = K.rearranged(ls, ks, gs, s, t, drop)
  doc === nothing ? nothing : last.(doc)
end
gap(line; after=false, inner=false) = K.Drop(:gap, line, after, inner, 0.0, 0.0, 0.0)
side(s, line) = K.Drop(s, line, false, false, 0.0, 0.0, 0.0)

@testset "the lines that a move gives" begin
  # Only empty lines between: it stays where it is
  @test moved(["a", "", "b"], 1, 1, gap(3)) === nothing
  @test moved(["a", "", "b"], 3, 3, gap(1, after=true)) === nothing
  @test moved(["a", "", "b"], 1, 1, gap(3, after=true)) == ["b", "", "a"]
  # An empty line keeps the block apart from the lines that it meets
  @test moved(["# H", "P", "", "B"], 4, 4, gap(2)) == ["# H", "", "B", "", "P"]
  # Where it leaves two empty lines together, one goes
  @test moved(["A", "", "B", "", "C"], 1, 1, gap(5)) == ["B", "", "A", "", "C"]
  # The caret goes with its text
  b = e.buf
  b.caret = b.anchor = (9, 3)
  doc = K.rearranged(b.lines, K.kinds(b), K.column_groups(e), 9, 9, gap(7))
  @test K.rearrange!(e, doc, 9) == 7
  @test b.lines[7] == "Second paragraph." && b.caret == (7, 3)
  K.undo!(b); frames(2)
  @test join(lines(), "\n") == start
end

@testset "a block that goes beside another makes columns" begin
  @test moved(["A", "", "B"], 1, 1, side(:right, 3)) == ["```columns", "2", "```", "", "B", "", "A"]
  @test moved(["A", "", "B"], 3, 3, side(:left, 1)) == ["```columns", "2", "```", "", "B", "", "A"]
  # Beside a column, it's a new column, and the number grows
  two = ["```columns", "2", "```", "", "A", "", "B", "", "C"]
  @test moved(two, 9, 9, side(:left, 7)) == ["```columns", "3", "```", "", "A", "", "C", "", "B"]
  # A column's width goes with it to its new place in its group. A new column is as wide as the one it's beside.
  shared = ["```columns", "3 1", "```", "", "A", "", "B", "", "C"]
  @test moved(shared, 5, 5, side(:right, 7)) == ["```columns", "1 3", "```", "", "B", "", "A", "", "C"]
  @test moved(shared, 9, 9, side(:left, 5)) == ["```columns", "3 3 1", "```", "", "C", "", "A", "", "B"]
  # A column that leaves a group of two leaves one, so the `columns` block goes
  @test moved(two, 7, 7, gap(9, after=true)) == ["A", "", "C", "", "B"]
  # A heading takes the blocks under it, and a column that starts with a heading moves with them
  heads = ["```columns", "2", "```", "", "### X", "", "x", "", "### Y", "", "y", "", "---", "", "z"]
  @test moved(heads, 9, 9, side(:left, 5)) == ["```columns", "2", "```", "", "### Y", "", "y", "", "### X", "", "x", "", "---", "", "z"]
  # A gap between the blocks under a heading that's a column puts the block in that column
  @test moved(heads, 15, 15, gap(7, after=true, inner=true)) == ["```columns", "2", "```", "", "### X", "", "x", "", "z", "", "### Y", "", "y", "", "---"]
  # A paragraph at the right of a heading's column would be in that column, so it can't go there
  @test moved(heads, 15, 15, side(:right, 9)) === nothing
  # A paragraph after a group whose last column is a heading's would be in that column too
  # A block under a heading that's a column can leave it, to go over the group
  @test moved(["```columns", "2", "```", "", "### X", "", "### Y", "", "y", "", "z"], 11, 11, gap(1)) ==
    ["z", "", "```columns", "2", "```", "", "### X", "", "### Y", "", "y"]
  @test moved(["```columns", "2", "```", "", "### X", "", "x", "", "### Y", "", "---", "", "z"], 13, 13, gap(9, after=true)) === nothing
end

"The room in the window of the block of the page that starts on line `i`: left, top, width and height"
room(i) = (p = only(p for p in K.shown_parts(e) if p isa K.Block && p.first == i); r = rect(p); K.num.((r.left, r.top, r.width, r.height)))

"Drag the handle of the chosen block to `(x, y)` and let go there"
drag_at(x, y) = begin
  move(grip()...)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  frames(1)
  move(x, y); frames(1)
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames(3)
end

@testset "a drag over the side of a block makes columns in the window" begin
  # Over the right quarter of the second paragraph, a blue line down its side
  cmd_opt_click(spot(7, "First")...)
  left, top, wide, tall = room(9)
  found = K.drop_target(e, (7, 7), left + wide * 0.9, top + tall / 2)
  @test found !== nothing && found[1].side == :right && found[1].line == 9
  # In the middle of the block, and in the margin where the handle is, it's a gap: here the one under the block
  @test K.drop_target(e, (7, 7), left + wide / 2, top + tall * 0.8)[1].side == :gap
  @test K.drop_target(e, (7, 7), left + 8, top + tall * 0.8)[1].side == :gap
  # A paragraph at the right of the page's heading would join the heading's column, so that's a gap too
  hl, ht, hw, hh = room(5)
  sideways = K.drop_target(e, (7, 7), hl + hw * 0.9, ht + hh / 2)
  @test sideways === nothing || sideways[1].side == :gap
  move(grip()...)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  frames(1)
  move(left + wide * 0.9, top + tall / 2); frames(1)
  shot("block-handle-side.png")
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames(3)
  @test e.buf.lines[5:16] == ["# Handles", "", "```columns", "2", "```", "", "Second paragraph.", "", "First paragraph, with a [link](https://example.com).", "", "- one", "- two"]
  # The two show side by side, and the moved block keeps its line
  @test K.column_at(e, 11) !== nothing && K.column_at(e, 13) !== nothing
  @test room(11)[1] < room(13)[1] && room(11)[2] == room(13)[2]
  @test t.chosen[1] isa K.Paragraph && t.chosen[1].first == 13 && handle() !== nothing
  shot("block-handle-columns.png")
  # The list goes at the left of the first column: three columns
  cmd_opt_click(spot(15, "one")...)
  l1, t1, w1, h1 = room(11)
  drag_at(l1 + K.SIDE_DEAD + 6, t1 + h1 / 2)
  @test e.buf.lines[7:18] == ["```columns", "3", "```", "", "- one", "- two", "", "Second paragraph.", "", "First paragraph, with a [link](https://example.com).", "", "```board"]
  # Out of the group again, to the gap over the board: two columns are left
  cmd_opt_click(spot(11, "one")...)
  drag_at(grip()[1], top_of(18) - 3px)
  @test e.buf.lines[7:18] == ["```columns", "2", "```", "", "Second paragraph.", "", "First paragraph, with a [link](https://example.com).", "", "- one", "- two", "", "```board"]
  # The first paragraph out as well: one column is no columns
  cmd_opt_click(spot(13, "First")...)
  drag_at(grip()[1], top_of(15) - 3px)
  @test e.buf.lines[5:11] == ["# Handles", "", "Second paragraph.", "", "First paragraph, with a [link](https://example.com).", "", "- one"]
  @test K.column_at(e, 7) === nothing
  # Each drop was one edit
  foreach(_ -> K.undo!(e.buf), 1:4); frames(2)
  @test join(lines(), "\n") == start
  onkey(w, KeyPress{Keys.escape}(0, w)); frames(1)
end
