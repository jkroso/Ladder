# Tests for the `columns` block of main.jl: the blocks after it show side by
# side, and stay the page's own lines. Run them with
# `julia -O0 --project=. test/columns_view_test.jl`. They click and type in a
# window that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they
# save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
write(joinpath(dir, "other.md"), "# The other page\n")
# The level that these tests choose goes to a settings file of their own, not to the one that Ladder uses
const kept = joinpath(dir, "settings")
K.SETTINGS_FILE[] = kept

"A window that isn't on the screen, on a page with `text` in it"
window(name, text; size=(1100px, 900px)) = begin
  path = joinpath(dir, name)
  write(path, text)
  e = K.build_editor(path)
  w = Window(e, size=size)
  frame(w); frame(w)
  K.focus(e)
  e, w
end
frames(w, n=2) = foreach(_ -> frame(w), 1:n)
shot(w, name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
at(w, (x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(w, 1))
press(w, place, keys=Keys(0)) = (at(w, place); w.keys |= keys | Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release(w, keys=Keys(0)) = (w.keys ⊻= keys | Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(w))
click(w, place, keys=Keys(0)) = (press(w, place, keys); release(w, keys))
key(w, k, held=Keys(0)) = (w.keys = held; onkey(w, KeyPress{k}(0, w)); w.keys = Keys(0); frames(w))
type(e, w, text) = (foreach(c -> ontype(e, Typed(c, w)), text); frames(w))
caret!(e, w, p) = (e.buf.caret = e.buf.anchor = p; K.touch!(e); frames(w))
line(e, text) = findfirst(==(text), e.buf.lines)
columns(e) = K.laid_columns(e)
"Where a place of the page's text is in the window: `x` across and `y` down the item that shows line `i`"
spot(e, i, x, y) = (it = K.item(e, i); (K.num(e.origin[1]) + x, K.num(e.origin[2] + it.top) + y))
"Where column `col` of line `i` is in the window: the middle of its line on the screen"
place(e, i, col) = begin
  it = K.item(e, i)
  f = it.content::K.Flow
  k, x = K.spot(f, col)
  (K.num(e.origin[1] + x), K.num(e.origin[2] + it.top + K.line_top(f, k) + f.lines[k].high / 2))
end

const THREE = """
# Options

Before the columns.

```columns
3
```

First block of the page, with enough words in it to go on to a second line and a third line of its column.

- Second block,
- a list with [a link](other.md)
- [ ] and a task

| Third | block |
|---|---|
| a | table |

After the columns.
"""

@testset "three blocks side by side" begin
  e, w = window("three.md", THREE)
  s = columns(e)
  first_line, list, table, after = line(e, "- Second block,") - 2, line(e, "- Second block,"), line(e, "| Third | block |"), line(e, "After the columns.")
  @test s !== nothing && length(s.columns) == 3 && length(s.groups) == 1
  gap = K.num(K.column_gap(e))
  # Three columns of one width share the page's width, with a gap between them
  @test all(c -> K.num(c.wide) ≈ (K.num(e.width) - 2gap) / 3, s.columns)
  @test [K.num(c.left) for c in s.columns] ≈ [0, K.num(s.columns[1].wide) + gap, 2(K.num(s.columns[1].wide) + gap)]
  # Each column holds its block and the empty line after it. The last holds only its block.
  @test [(c.first, c.last) for c in s.columns] == [(first_line, first_line + 1), (list, list + 3), (table, table + 2)]
  # The columns line up at the top, and the page goes on under the tallest
  tops = [K.item(e, c.first).top for c in s.columns]
  g = s.groups[1]
  @test tops[1] == tops[2] && K.num(tops[3]) ≈ K.num(tops[1]) && tops[1] == g.top
  talls = [sum(it -> K.num(it.tall), filter(it -> c.first <= it.first <= c.last, e.layout)) for c in s.columns]
  @test K.num(g.tall) ≈ maximum(talls) && K.num(K.item(e, after - 1).top) ≈ K.num(g.top + g.tall)
  # A line of a column wraps at the column's width, and is placed at the column's left edge
  f = K.item(e, first_line).content
  @test length(f.lines) >= 3 && all(vl -> all(seg -> seg.x + seg.w <= s.columns[1].wide + 8px, vl.segs), f.lines)
  f = K.item(e, list).content
  @test first(first(f.lines).segs).x == s.columns[2].left
  @test K.cell_origin(K.item(e, table).content, 1, 1)[1] > s.columns[3].left
  @test K.num(sum(K.item(e, table).content.widths)) + 3 ≈ K.num(s.columns[3].wide)
  # The outline and the page's to-do items see the blocks as the page's own
  @test [en.title for en in K.outline(e.buf)] == ["Options", "Columns"] && [t.name for t in K.page_todos(e)] == ["and a task"]
  @test !K.dirty(e.buf)
  shot(w, "columns-three.png")
  # The mouse over the columns and the caret in them show nothing of the `columns` block
  at(w, spot(e, list, 300, 10)); caret!(e, w, (list, 3))
  shot(w, "columns-three-hover.png")
  close(w)
end

@testset "a click lands in the column under the mouse" begin
  e, w = window("clicks.md", THREE)
  s = columns(e)
  list, table, after = line(e, "- Second block,"), line(e, "| Third | block |"), line(e, "After the columns.")
  para = list - 2
  click(w, place(e, list + 1, 5))
  @test e.buf.caret == (list + 1, 5)
  click(w, place(e, para, 40))
  @test e.buf.caret == (para, 40)
  # In a cell of the table of the third column
  it = K.item(e, table)
  x, y = K.cell_origin(it.content, 2, 2)
  click(w, (K.num(e.origin[1] + x) + 8, K.num(e.origin[2] + it.top + y) + 8))
  @test e.buf.caret[1] == table + 2 && K.cellat(e.buf, e.buf.caret) == K.tablecells(e.buf.lines[table+2])[2]
  # Under a column that's shorter than the group, a click goes to the column's last line
  click(w, spot(e, list, K.num(s.columns[2].left) + 60, K.num(s.groups[1].tall) - 3))
  @test e.buf.caret == (list + 3, 0)
  # In the gap after a column, it goes to the end of the line beside it
  click(w, spot(e, para, K.num(s.columns[1].wide) + 6, 12))
  @test e.buf.caret[1] == para && e.buf.caret[2] == first(K.item(e, para).content.lines).to - 1
  # A click on a box ticks its item, and a click on a link with ⌘ held opens it
  click(w, place(e, list + 2, 0) .+ (6, 0))
  @test e.buf.lines[list+2] == "- [x] and a task"
  K.undo!(e.buf); frames(w)
  @test K.link_at(e, px.(place(e, list + 1, 16))) == "other.md" && K.link_on(e, px.(place(e, list + 1, 16))) == "other.md"
  @test K.link_on(e, px.(place(e, para, 10))) === nothing
  # A drag from one column into the next selects through both
  press(w, place(e, para, 6)); at(w, place(e, list, 4)); at(w, place(e, list + 1, 9)); release(w)
  @test e.buf.anchor == (para, 6) && e.buf.caret == (list + 1, 9)
  shot(w, "columns-selection.png")
  close(w)
end

@testset "typing in a column changes its own line" begin
  e, w = window("typing.md", THREE)
  list = line(e, "- Second block,")
  before = copy(e.buf.lines)
  click(w, place(e, list, 15))
  @test e.buf.caret == (list, 15)
  type(e, w, " and more words, so that the item goes on to its next line")
  @test e.buf.lines[list] == "- Second block, and more words, so that the item goes on to its next line"
  @test e.buf.lines[[1:list-1; list+1:end]] == before[[1:list-1; list+1:end]]
  # The item wraps in its column, and the caret is drawn at the end of what was typed
  f = K.item(e, list).content
  s = columns(e)
  @test length(f.lines) >= 2 && all(vl -> all(seg -> s.columns[2].left <= seg.x && seg.x + seg.w <= s.columns[2].left + s.columns[2].wide + 8px, vl.segs), f.lines)
  shot(w, "columns-caret.png")
  # Return carries the list on, in the same column
  key(w, Keys.enter); type(e, w, "third")
  @test e.buf.lines[list+1] == "- third" && columns(e).columns[2].first == list && K.item(e, list + 1).top > K.item(e, list).top
  # ⌘Z takes each change back
  while K.dirty(e.buf) && !isempty(e.buf.undo)
    K.undo!(e.buf)
  end
  frames(w)
  @test e.buf.lines == before && length(K.item(e, list).content.lines) == 1
  close(w)
end

@testset "the arrows in a column" begin
  e, w = window("arrows.md", THREE)
  list, table, after = line(e, "- Second block,"), line(e, "| Third | block |"), line(e, "After the columns.")
  para = list - 2
  # ↓ goes down the lines of the first column, then to the line under the group
  caret!(e, w, (para, 0))
  n = length(K.item(e, para).content.lines)
  foreach(_ -> key(w, Keys.down), 1:n-1)
  @test e.buf.caret[1] == para && K.spot(K.item(e, para).content, e.buf.caret[2])[1] == n
  key(w, Keys.down)
  @test e.buf.caret == (para + 1, 0)
  key(w, Keys.down)
  @test e.buf.caret == (after - 1, 0)
  key(w, Keys.down)
  @test e.buf.caret == (after, 0)
  # ↑ comes back into the column that's over the caret: its last line
  key(w, Keys.up); key(w, Keys.up)
  @test e.buf.caret == (para + 1, 0)
  # From the first line of the second column, ↑ leaves the group, to the line over the `columns` block, and ↓ comes back into that column
  caret!(e, w, (list, 9))
  key(w, Keys.up)
  @test e.buf.caret[1] == para - 5
  key(w, Keys.down)
  @test e.buf.caret == (list, 9)
  # ↓ goes through the second column's lines, and then under the group
  key(w, Keys.down); key(w, Keys.down)
  @test e.buf.caret[1] == list + 2
  key(w, Keys.down)
  @test e.buf.caret == (list + 3, 0)
  key(w, Keys.down)
  @test e.buf.caret == (after - 1, 0)
  # → at the end of a column's text goes on to the next column, and ← comes back
  caret!(e, w, (para, length(e.buf.lines[para])))
  key(w, Keys.right); key(w, Keys.right)
  @test e.buf.caret[1] == list
  key(w, Keys.left); key(w, Keys.left)
  @test e.buf.caret == (para, length(e.buf.lines[para]))
  # From the table of the third column, ↓ leaves the group and ↑ comes back to the table
  cell = K.tablecells(e.buf.lines[table+2])[1]
  caret!(e, w, (table + 2, cell.lo))
  key(w, Keys.down)
  @test e.buf.caret[1] == after - 1
  key(w, Keys.up)
  @test e.buf.caret[1] == table + 2
  key(w, Keys.up); key(w, Keys.up)
  @test e.buf.caret[1] == para - 5
  close(w)
end

const OPTIONS = """
# Pipes

```columns
3
```

### Option A

Cheapest.

- Two days

### Option B

Lasts longer, and so it's the one that most people choose for a house.

#### A lower heading

- Three days

### Option C

Both.

---

This paragraph is under the columns.
"""

@testset "a heading takes the blocks under it into its column" begin
  e, w = window("options.md", OPTIONS)
  s = columns(e)
  a, b, c, rule = line(e, "### Option A"), line(e, "### Option B"), line(e, "### Option C"), line(e, "---")
  @test [(col.first, col.last) for col in s.columns] == [(a, b - 1), (b, c - 1), (c, c + 2)]
  # The blocks of a column are one under another, at the column's width
  tops(col) = [K.num(K.item(e, i).top) for i in col.first:col.last]
  @test all(col -> issorted(tops(col)) && allunique(tops(col)), s.columns)
  @test K.item(e, a).top == K.item(e, b).top == K.item(e, c).top == s.groups[1].top
  @test first(first(K.item(e, b + 2).content.lines).segs).x == s.columns[2].left && length(K.item(e, b + 2).content.lines) > 1
  @test first(first(K.item(e, b + 4).content.lines).segs).x == s.columns[2].left && K.item(e, b + 4).content.kind == K.Kind.heading
  # The line across the page is under the tallest column, and the paragraph after it is as wide as the page
  g = s.groups[1]
  @test K.num(K.item(e, rule - 1).top) ≈ K.num(g.top + g.tall) && K.item(e, rule).top > g.top + g.tall
  @test K.column_at(e, rule) === nothing && K.column_at(e, rule + 2) === nothing && K.item_room(e, K.item(e, rule + 2)) == (0px, e.width)
  # The headings are still headings of the page
  @test [en.title for en in K.outline(e.buf)] == ["Pipes", "Columns", "Option A", "Option B", "A lower heading", "Option C"]
  # ↓ goes through the blocks of one column before it leaves the group
  caret!(e, w, (b, 4))
  seen = Int[]
  while e.buf.caret[1] < rule - 1 && length(seen) < 30
    key(w, Keys.down)
    push!(seen, e.buf.caret[1])
  end
  @test issorted(seen) && all(i -> b <= i < c || i == rule - 1, seen) && b + 6 in seen && last(seen) == rule - 1
  # ... and ↑ from the top of the third column goes over the group, not into the second column
  caret!(e, w, (c, 4))
  key(w, Keys.up)
  @test e.buf.caret[1] < a
  shot(w, "columns-headings.png")
  K.use!(K.NIGHT); e.theme = :night; K.restyle!(e); frames(w)
  caret!(e, w, (b + 2, 14))
  @test first(first(K.item(e, a).content.lines).segs).face.color == K.NIGHT.ink
  shot(w, "columns-night.png")
  K.use!(K.SEPIA)
  close(w)
end

@testset "shares, a table and a picture" begin
  e, w = window("shares.md", "# A plan\n\nText.\n")
  save_png(joinpath(dir, "shot.png"), w)   # a picture of the window, which is wider than a column
  close(w)
  e, w = window("shares.md", """
  # A plan

  ```columns
  2 1
  ```

  | Part | Cost | More |
  |---|---:|---|
  | Pipe | \$420 | A [link](other.md) |
  | Fittings | \$95 | |

  ![a picture](shot.png)

  After.
  """)
  s = columns(e)
  table, picture = line(e, "| Part | Cost | More |"), line(e, "![a picture](shot.png)")
  gap = K.num(K.column_gap(e))
  # The first column is twice as wide as the second
  @test length(s.columns) == 2 && K.num(s.columns[1].wide) ≈ 2K.num(s.columns[2].wide) && K.num(s.columns[1].wide + s.columns[2].wide) + gap ≈ K.num(e.width)
  # The table is laid out for its column, and the picture is no wider than its own
  g = K.item(e, table).content
  @test g isa K.Grid && K.num(sum(g.widths)) + 4 ≈ K.num(s.columns[1].wide)
  p = K.item(e, picture).content.node
  @test p isa K.Picture && p.w == s.columns[2].wide && K.num(rect(p).left) ≈ K.num(e.origin[1] + s.columns[2].left)
  @test K.num(K.item(e, picture).top) ≈ K.num(K.item(e, table).top)
  # A click in a cell puts the caret there, and Tab goes to the next cell
  it = K.item(e, table)
  x, y = K.cell_origin(g, 2, 1)
  click(w, (K.num(e.origin[1] + x) + 6, K.num(e.origin[2] + it.top + y) + 8))
  @test e.buf.caret[1] == table + 2 && K.cellat(e.buf, e.buf.caret) == K.tablecells(e.buf.lines[table+2])[1]
  type(e, w, "Long ")
  @test startswith(e.buf.lines[table+2], "| Long Pipe |")
  shot(w, "columns-table-picture.png")
  # The line round the picture, when the caret is on it as a whole, is round its column only
  caret!(e, w, (picture, 0))
  @test K.picked(e.buf) == (picture, picture) && K.item_room(e, K.item(e, picture)) == (s.columns[2].left, s.columns[2].wide)
  shot(w, "columns-picture-picked.png")
  # A selection from the table into the picture's line covers both
  e.buf.anchor, e.buf.caret = (table + 2, 3), (picture, 5); frames(w)
  shot(w, "columns-table-selection.png")
  close(w)
end

@testset "a narrow window shows the blocks one under another" begin
  e, w = window("narrow.md", THREE, size=(520px, 900px))
  @test K.num(e.width) < K.Columns.NARROW && isempty(columns(e).columns)
  list, table = line(e, "- Second block,"), line(e, "| Third | block |")
  tops = [K.num(K.item(e, i).top) for i in (list - 2, list, table)]
  @test issorted(tops) && allunique(tops) && first(first(K.item(e, list).content.lines).segs).x == 0px
  @test K.num(sum(K.item(e, table).content.widths)) + 3 ≈ K.num(e.width)
  # The `columns` block takes no room here either: one empty line is between the paragraph over it and the first block
  s, t = K.block_lines(e.buf, K.COLUMN_BLOCK, 1)
  @test K.num(K.item(e, s).tall) == 0 && K.num(K.item(e, t + 1).tall) == 0
  @test K.num(K.item(e, list - 2).top) ≈ K.num(K.item(e, s - 1).top + K.item(e, s - 1).tall)
  shot(w, "columns-narrow.png")
  close(w)
end

"How much room is between the line `above` and the line `below` of the page"
room(e, above, below) = K.num(K.item(e, line(e, below)).top - K.item(e, line(e, above)).top - K.item(e, line(e, above)).tall)
const PARA = "First block of the page, with enough words in it to go on to a second line and a third line of its column."

@testset "the `columns` block takes no room" begin
  e, w = window("block.md", THREE)
  s, t = K.block_lines(e.buf, K.COLUMN_BLOCK, 1)
  list = line(e, "- Second block,")
  para = list - 2
  # Its item is 0 tall, and so is the empty line after it: the lines that the caret steps over
  @test K.item(e, s).last == t && K.num(K.item(e, s).tall) == 0 && K.num(K.item(e, t + 1).tall) == 0 && K.num(K.item(e, s - 1).tall) > 20
  @test K.column_fold(e.buf, s) == K.column_fold(e.buf, s + 1) == K.column_fold(e.buf, t + 1) == (s, t + 1)
  @test K.column_fold(e.buf, s - 1) === nothing && K.column_fold(e.buf, para) === nothing
  # The room over the columns is the room in the same page without the block: one empty line
  bare, wb = window("bare.md", replace(THREE, "```columns\n3\n```\n\n" => ""))
  @test columns(bare) === nothing && room(e, "Before the columns.", PARA) ≈ room(bare, "Before the columns.", PARA) > 20
  close(wb)
  # A heading over the block keeps its own room, and a block with no empty line over it keeps the one under it
  for (top, between) in (("## A heading", "\n\n"), ("Text.", "\n"), ("Text.", "\n\n\n"))
    with, w1 = window("with.md", top * between * "```columns\n2\n```\n\none\n\ntwo\n")
    without, w2 = window("without.md", top * max(between, "\n\n") * "one\n\ntwo\n")
    @test length(columns(with).columns) == 2 && room(with, top, "one") ≈ room(without, top, "one")
    close(w1); close(w2)
  end
  # ↓ and ↑ go past the block, and so do → and ←
  caret!(e, w, (s - 2, 4)); key(w, Keys.down)
  @test e.buf.caret == (s - 1, 0)
  key(w, Keys.down)
  @test e.buf.caret[1] == para && K.picked(e.buf) === nothing
  key(w, Keys.up)
  @test e.buf.caret == (s - 1, 0)
  key(w, Keys.right)
  @test e.buf.caret == (para, 0)
  key(w, Keys.left)
  @test e.buf.caret == (s - 1, 0)
  # A click where the block is lands in the line over it or in the column under it
  click(w, spot(e, s, 60, -4))
  @test e.buf.caret[1] == s - 1
  click(w, spot(e, s, 60, 1))
  @test e.buf.caret[1] == para
  # A selection that goes across the block holds its lines
  caret!(e, w, (s - 2, 0)); key(w, Keys.down, Keys.shft); key(w, Keys.down, Keys.shft)
  @test e.buf.anchor == (s - 2, 0) && e.buf.caret[1] == para && occursin("```columns\n3\n```", K.excerpt(e.buf, K.selection(e.buf)...))
  # ⌫ at the start of the first column goes over the block and takes nothing away. ⌦ on the line before the block does nothing.
  before = copy(e.buf.lines)
  caret!(e, w, (para, 0)); key(w, Keys.backspace)
  @test e.buf.lines == before && e.buf.caret == (s - 1, 0)
  key(w, Keys.delete)
  @test e.buf.lines == before && e.buf.caret == (s - 1, 0)
  # ⌦ at the end of the paragraph over the block takes the empty line. The empty line under the block then shows, so the room is the same.
  caret!(e, w, (s - 2, length(e.buf.lines[s-2]))); key(w, Keys.delete)
  @test e.buf.lines[s-1] == "```columns" && K.column_fold(e.buf, s - 1) == (s - 1, t - 1) && room(e, "Before the columns.", PARA) > 20
  @test length(columns(e).columns) == 3
  K.undo!(e.buf); frames(w)
  @test e.buf.lines == before
  close(w)
end

@testset "as plain text the caret goes through the block" begin
  e, w = window("low.md", THREE)
  s, t = K.block_lines(e.buf, K.COLUMN_BLOCK, 1)
  list = line(e, "- Second block,")
  para = list - 2
  K.plain!(e, true); caret!(e, w, (s - 1, 0))
  @test K.num(K.item(e, s).tall) == 0
  # ↓ comes onto the block, and the block shows its lines: the fence lines and the number
  key(w, Keys.down)
  @test e.buf.caret == (s, 0) && all(i -> K.item(e, i).content isa K.Flow && K.num(K.item(e, i).tall) > 10, s:t+1)
  @test K.item(e, s).content.raw && K.item(e, s + 1).content.kind == K.Kind.code
  shot(w, "columns-low.png")
  # The columns stay as columns while the number is changed
  key(w, Keys.down)
  @test e.buf.caret[1] == s + 1 && length(columns(e).columns) == 3
  key(w, Keys.right); key(w, Keys.backspace); type(e, w, "2")
  @test e.buf.lines[s+1] == "2" && length(columns(e).columns) == 2
  # With two columns, the table is under them, as wide as the page
  table = line(e, "| Third | block |")
  @test K.column_at(e, table) === nothing && K.num(sum(K.item(e, table).content.widths)) + 3 ≈ K.num(e.width)
  # Shares in place of a count
  key(w, Keys.backspace); type(e, w, "1 3")
  @test [K.num(c.wide) for c in columns(e).columns][2] ≈ 3K.num(columns(e).columns[1].wide)
  # ↓ goes on through the line that closes the block and the empty line under it, into the first column
  key(w, Keys.down)
  @test e.buf.caret[1] == t
  key(w, Keys.down)
  @test e.buf.caret == (t + 1, 0) && K.num(K.item(e, s).tall) == 0 && K.num(K.item(e, t + 1).tall) > 10
  key(w, Keys.down)
  @test e.buf.caret[1] == para && K.num(K.item(e, t + 1).tall) == 0
  # ... and ↑ comes back through it
  key(w, Keys.up); key(w, Keys.up)
  @test e.buf.caret[1] == t && K.item(e, t).content.raw
  # Back as rich text, the caret leaves the block, and the block takes no room again
  K.plain!(e, false); frames(w)
  @test !(s <= e.buf.caret[1] <= t + 1) && K.num(K.item(e, s).tall) == 0
  close(w)
end

@testset "the sidebar's entry goes into the block" begin
  e, w = window("side.md", THREE)
  s, t = K.block_lines(e.buf, K.COLUMN_BLOCK, 1)
  entry = only(filter(en -> en.title == "Columns", K.outline(e.buf)))
  @test entry.line == s && entry.caret == s + 1
  # A click on the entry does this: the caret is after the number, and the block shows its lines
  label = K.EntryLabel(path=e.buf.path, line=entry.line, level=entry.level, title=entry.title, icon=entry.icon, caret=entry.caret)
  K.choose!(e, (firstchild=label,))
  K.tree_took!(e)   # the click itself comes to the page next, and takes this note away
  frames(w)
  @test e.buf.caret == (s + 1, 1) && K.item(e, s + 1).content isa K.Flow && K.item(e, s + 1).content.kind == K.Kind.code
  @test length(columns(e).columns) == 3
  shot(w, "columns-entry.png")
  # The number is changed there, and the caret leaves with ↓
  key(w, Keys.backspace); type(e, w, "2")
  @test e.buf.lines[s+1] == "2" && length(columns(e).columns) == 2
  key(w, Keys.down)
  @test e.buf.caret[1] > t + 1 && K.num(K.item(e, s).tall) == 0
  close(w)
end

@testset "a block that doesn't say how many" begin
  e, w = window("wrong.md", replace(THREE, "```columns\n3\n```" => "```columns\nlots\n```"))
  s, t = K.block_lines(e.buf, K.COLUMN_BLOCK, 1)
  v = e.nodes[(:block, K.COLUMN_BLOCK, e.buf.path, 1)]
  # It keeps its little room and its words, and puts nothing in columns
  @test columns(e) === nothing && v.shares === nothing && K.column_fold(e.buf, s) === nothing
  @test K.item(e, s).content isa K.Live && 10 < K.num(K.item(e, s).tall) < 20 && K.num(K.item(e, t + 1).tall) > 20
  shot(w, "columns-wrong.png")
  # The caret goes onto it as a whole, and Return shows its lines
  caret!(e, w, (s - 1, 0)); key(w, Keys.down)
  @test K.picked(e.buf) == (s, t)
  shot(w, "columns-wrong-picked.png")
  key(w, Keys.enter)
  @test e.buf.caret == (s + 1, 4) && K.item(e, s + 1).content isa K.Flow
  # With a number in it, it takes no room. With none, it has its room again.
  K.write_block!(v, K.COLUMN_BLOCK, ["5"]); caret!(e, w, (1, 0))
  @test K.num(K.item(e, s).tall) == 0 && length(columns(e).columns) == 4
  # More columns than blocks: the blocks that there are keep the width of one column of the number
  @test K.num(columns(e).columns[1].wide) ≈ (K.num(e.width) - 4K.num(K.column_gap(e))) / 5
  shot(w, "columns-five.png")
  K.write_block!(v, K.COLUMN_BLOCK, String[]); frames(w)
  @test columns(e) === nothing && K.num(K.item(e, s).tall) > 10
  # ⌫ on a block that's wrong takes it away
  caret!(e, w, (s, 0))
  @test K.picked(e.buf) == (s, s + 1)
  key(w, Keys.backspace)
  @test !any(l -> startswith(l, "```"), e.buf.lines)
  close(w)
end

@testset "the language `column`, and two groups" begin
  e, w = window("two.md", "```column\n2\n```\n\none\n\ntwo\n\n```columns\n3\n```\n\nthree\n\n```columns\n2\n```\n\nfour\n\nfive\n\nsix\n")
  s = columns(e)
  # A `columns` block ends the group before it
  @test length(s.groups) == 3 && [c.group for c in s.columns] == [1, 1, 2, 3, 3]
  @test K.item(e, line(e, "one")).top == K.item(e, line(e, "two")).top && K.item(e, line(e, "four")).top == K.item(e, line(e, "five")).top
  @test K.item(e, line(e, "four")).top > K.item(e, line(e, "three")).top > K.item(e, line(e, "two")).top
  @test K.column_at(e, line(e, "six")) === nothing && K.item(e, line(e, "six")).top > K.item(e, line(e, "five")).top
  @test count(en -> en.title == "Columns", K.outline(e.buf)) == 3
  shot(w, "columns-groups.png")
  close(w)
end

@testset "the page as HTML, and on paper" begin
  e, w = window("html.md", OPTIONS)
  html = K.page_html(e)
  @test occursin("<div class=\"columns\">\n<div style=\"flex: 1 1 0\">\n<h3>Option A</h3>\n<p>Cheapest.</p>\n<ul>\n<li>Two days</li></ul>\n</div>\n<div style=\"flex: 1 1 0\">\n<h3>Option B</h3>", html)
  @test occursin("<h4>A lower heading</h4>\n<ul>\n<li>Three days</li></ul>\n</div>\n<div style=\"flex: 1 1 0\">\n<h3>Option C</h3>\n<p>Both.</p>\n</div>\n</div>\n<hr>\n<p>This paragraph is under the columns.</p>", html)
  @test !occursin("language-columns", html) && occursin(".columns { display: flex;", html) && count("<div style=\"flex:", html) == 3
  close(w)
  # Shares are the flex values, and a column with no block keeps its room
  e, w = window("html2.md", "```columns\n2 1 1\n```\n\n- [ ] one\n\n> two\n")
  html = K.page_html(e)
  @test occursin("<div style=\"flex: 2 1 0\">\n<ul>\n<li class=\"todo\">", html) && occursin("</li></ul>\n</div>\n<div style=\"flex: 1 1 0\">\n<blockquote>\n<p>two</p>\n</blockquote>\n</div>\n<div style=\"flex: 1 1 0\">\n</div>\n</div>", html)
  # A block that says nothing is in the page as its lines
  K.write_block!(e.nodes[(:block, K.COLUMN_BLOCK, e.buf.path, 1)], K.COLUMN_BLOCK, ["lots"]); frames(w)
  @test occursin("language-columns", K.page_html(e)) && !occursin("<div class=\"columns\">", K.page_html(e))
  close(w)
  # Paper is wide enough for columns, and the page is laid out for the window again after it
  e, w = window("paper.md", OPTIONS)
  before = [(it.first, K.num(it.top)) for it in e.layout]
  bytes = K.print_pdf(e)
  @test String(bytes[1:5]) == "%PDF-" && [(it.first, K.num(it.top)) for it in e.layout] == before && columns(e) !== nothing
  close(w)
end

@testset "Insert adds a block of two columns" begin
  e, w = window("fresh.md", "# Fresh\n\nSome words.\n")
  caret!(e, w, (3, 0))
  _, lines, spot = K.INSERTS[findfirst(x -> x isa Tuple && x[1] == "Columns", K.INSERTS)]
  K.add_block!(e, lines, spot); frames(w)
  s, t = K.block_lines(e.buf, K.COLUMN_BLOCK, 1)
  @test e.buf.lines[s:t] == ["```columns", "2", "```"] && e.buf.caret == (t + 2, 0)
  # The two blocks that are typed under it are side by side
  type(e, w, "Left"); key(w, Keys.enter); key(w, Keys.enter); type(e, w, "Right")
  @test length(columns(e).columns) == 2 && K.item(e, line(e, "Left")).top == K.item(e, line(e, "Right")).top
  @test first(first(K.item(e, line(e, "Right")).content.lines).segs).x == columns(e).columns[2].left
  close(w)
end

@testset "other blocks in a column" begin
  e, w = window("blocks.md", """
  - [x] Dig the trench
  - [ ] Lay the pipe

  ```columns
  2
  ```

  ```mermaid
  flowchart LR
    A[Start] --> B[End]
  ```

  ```board
  ```

  ```columns
  3
  ```

  ```sheet
  wall = 12m * 2.4m
  two = wall * 2
  ```

  ```spreadsheet
  | 1 | 2 |
  | = A1 + B1 | |
  ```

  ```julia
  x = 1 + 2   # a line of code that's long enough to go on to the next line of its column
  ```

  After.
  """, size=(1100px, 1000px))
  s = columns(e)
  diagram, board, sheet, spread, code = line(e, "```mermaid"), line(e, "```board"), line(e, "```sheet"), line(e, "```spreadsheet"), line(e, "```julia")
  @test length(s.groups) == 2 && length(s.columns) == 5
  # A diagram and a board are made for their column
  d = K.item(e, diagram).content.node
  @test d isa K.Shown && d.value isa K.Mermaid && K.num(rect(d).width) <= K.num(s.columns[1].wide) + 1
  v = e.nodes[(:block, K.BOARD, e.buf.path, 1)]
  r = rect(v)
  @test K.num(r.left) ≈ K.num(e.origin[1] + s.columns[2].left) && K.num(r.width) ≈ K.num(s.columns[2].wide)
  @test K.num(rect(v.parts[(:column, 3)]).left + rect(v.parts[(:column, 3)]).width) <= K.num(r.left + r.width)
  # A sheet, a spreadsheet and code are in the three columns of the next group, each at its column's left edge
  @test K.item(e, sheet).content isa K.Sheet && K.item(e, sheet).top == K.item(e, spread).top == K.item(e, code).top
  g = K.item(e, spread).content
  @test g isa K.Grid && K.isspread(g) && K.cell_origin(g, 1, 1)[1] > s.columns[4].left
  f = K.item(e, code + 1).content
  @test f.kind == K.Kind.code && length(f.lines) > 1 && first(first(f.lines).segs).x >= s.columns[5].left
  # A click in a cell of the sheet and of the spreadsheet puts the caret in that cell
  it = K.item(e, sheet)
  click(w, (K.num(e.origin[1] + s.columns[3].left + K.expr_x(it.content)) + 12, K.num(e.origin[2] + it.top + K.row_top(it.content, 2)) + 10))
  @test e.buf.caret[1] == sheet + 2 && e.buf.caret[2] > 5
  it = K.item(e, spread)
  x, y = K.cell_origin(g, 1, 2)
  click(w, (K.num(e.origin[1] + x) + 6, K.num(e.origin[2] + it.top + y) + 6))
  @test e.buf.caret[1] == spread + 1 && K.cellat(e.buf, e.buf.caret) == K.spreadcells(e.buf.lines[spread+1])[2]
  type(e, w, "5")
  @test occursin("25", e.buf.lines[spread+1]) || occursin("52", e.buf.lines[spread+1])
  shot(w, "columns-blocks.png")
  # The kinds of block that a `find` block lists
  @test K.Searches.block_kind("column") == :columns && K.Searches.block_kind(K.COLUMN_BLOCK) == :columns && K.block_icon(:columns) == "columns-gap"
  found = K.Searches.matches(K.Searches.query(["what: columns"]), e.buf.path, e.buf.lines)
  @test length(found) == 2 && length(K.Searches.matches(K.Searches.query(["what: sheets"]), e.buf.path, e.buf.lines)) == 1
  close(w)
end

@testset "a column of one block beside a heading's column" begin
  e, w = window("mix.md", """
  ```columns
  3
  ```

  A paragraph, which is a column by itself.

  ### Option A

  Cheapest.

  - Two days

  ### Option B

  Lasts longer.

  ### Option C

  This heading is past the count, so it's under the columns.
  """)
  s = columns(e)
  para, a, b, c = line(e, "A paragraph, which is a column by itself."), line(e, "### Option A"), line(e, "### Option B"), line(e, "### Option C")
  @test [(col.first, col.last) for col in s.columns] == [(para, a - 1), (a, b - 1), (b, b + 2)]
  @test K.item(e, para).top == K.item(e, a).top == K.item(e, b).top
  # The heading that's past the count is as wide as the page, under the tallest column
  g = s.groups[1]
  @test K.column_at(e, c) === nothing && K.item(e, c).top >= g.top + g.tall && first(first(K.item(e, c).content.lines).segs).x == 0px
  @test first(first(K.item(e, c + 2).content.lines).segs).x == 0px && length(K.item(e, c + 2).content.lines) == 1
  shot(w, "columns-mix.png")
  # The same page with a line across it after the first heading's column: the group ends there
  i = b - 1
  K.edit!(e.buf, (i, 0), (i, 0), "---\n"); caret!(e, w, (1, 0))
  s = columns(e)
  @test length(s.columns) == 2 && K.column_at(e, line(e, "---")) === nothing && K.column_at(e, line(e, "### Option B")) === nothing
  @test K.item(e, line(e, "---")).top >= s.groups[1].top + s.groups[1].tall
  close(w)
end
