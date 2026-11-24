# Tests for a part of another page: a line like ![[costs#Prices]] shows that
# part of the page costs.md, and what you type in it changes costs.md. See "a
# part of another page" in main.jl. Run them with
# `julia -O0 --project=. test/transclusion_test.jl`. They click and type in a
# window that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save
# pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame hittest clipboard rect
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc sel msg nsstring
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

# ⌘V reads a clipboard that only this test uses, and ⌘C in a window that isn't on the screen writes to none
const pb = K.Pasteboard.private_board()
K.Pasteboard.other[] = pb
put_text(s) = (msg(pb, "clearContents"); ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), pb, sel("setString:forType:"), nsstring(s), nsstring("public.utf8-plain-text")))

const dir = mktempdir()
mkdir(joinpath(dir, ".git"))   # a project, so a wiki link finds a page in any of its folders
const costs = joinpath(dir, "costs.md")
const COSTS = """
# Costs

Some words about what the house costs. ^intro

## Prices

| Item | Price |
| --- | --- |
| Paint | \$42 |

| Tool | Hire |
| --- | --- |
| Ladder | \$30 |

^tools

- [ ] Buy paint
- [ ] Hire a ladder ^hire
  - from the yard

```board
```

## Later

The end."""
write(costs, COSTS)
const home = joinpath(dir, "home.md")
write(home, """
# Home

Before the part.

![[costs#Prices]]

After the part.

![[costs#^intro]]

![[nowhere#Plans]]

The last line.""")

@testset "the lines of a part that a link names" begin
  b = K.Buffer(path=costs, lines=String.(split(COSTS, '\n')))
  line(text) = findfirst(l -> occursin(text, l), b.lines)
  lines(part) = K.transclusion_lines(b, part)
  # A heading and the lines under it, up to the next heading that's as big
  @test lines("Prices") == (line("## Prices"), line("```board") + 1)
  @test lines("prices") == lines("Prices")
  @test lines("Costs") == (1, length(b.lines))
  # A kind and a number
  @test lines("table") == (line("| Item"), line("| Paint"))
  @test lines("table 2") == (line("| Tool"), line("| Ladder"))
  @test lines("table 3") === nothing
  @test lines("list") == (line("Buy paint"), line("from the yard"))
  @test lines("board") == (line("```board"), line("```board") + 1)
  @test lines("code") === nothing   # a board shows as a board, not as code
  @test lines("heading 2") == (line("## Prices"), line("## Prices"))
  @test lines("paragraph") == (line("Some words"), line("Some words"))
  # A name at the end of a block, on a line under a table, and on an item of a list
  @test lines("^intro") == (line("Some words"), line("Some words"))
  @test lines("^tools") == lines("table 2")
  @test lines("^hire") == (line("Hire a ladder"), line("from the yard"))
  @test lines("^nothing") === nothing
  # The whole page
  @test lines("") == (1, length(b.lines))
end

@testset "a block's name doesn't show in rich text" begin
  ss = K.spans("Some words ^intro")
  @test last(ss).markup && last(ss).text == " ^intro"
  @test join(s.text for s in ss if !s.markup) == "Some words"
  @test K.block_id("Some words ^intro") == "intro"
  @test K.block_id("^tools") == "tools" && K.only_id("^tools")
  @test K.block_id("a footnote[^1]") === nothing
  @test K.block_id("x^2") === nothing   # a ^ in a word isn't a name
end

const e = K.build_editor(home)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

"The line of the page that holds `text`"
line(text) = findfirst(l -> occursin(text, l), e.buf.lines)
"The view of the part that line `i` shows"
part(i) = (it = K.item(e, i); it.content isa K.Live && it.content.node isa K.Transclusion ? it.content.node : nothing)
at(x, y) = (w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(Vec2{px}(x, y), w)); frame(w))
click((x, y), held...) = begin
  at(x, y)
  foreach(h -> w.keys |= h, held)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
key(k, held...) = (foreach(h -> w.keys |= h, held); onkey(w, KeyPress{k}(0, w)); foreach(h -> w.keys ⊻= h, held); frames())
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
"The place in the window of column `col` of line `i` of the page that a part shows. In a table, it's in the first cell of the row."
spot(v, i, col=0) = begin
  sub = v.sub
  it = K.item(sub, i)
  c = it.content
  x0, y0 = sub.origin[1], sub.origin[2] + it.top
  if c isa K.Grid
    r = findfirst(==(i), c.rows)
    cx, cy = K.cell_origin(c, r, 1)
    x0, y0, f = x0 + cx, y0 + cy, c.flows[r][1]
  else
    f = c
  end
  k, x = K.spot(f, col)
  (x0 + x + 1px, y0 + K.line_top(f, k) + f.lines[k].high / 2)
end
"The line of the other page that holds `text`"
cline(v, text) = findfirst(l -> occursin(text, l), v.sub.buf.lines)

@testset "a line shows a part of another page" begin
  v = part(line("![[costs#Prices]]"))
  @test v !== nothing && isempty(v.note) && v.tall > 100px
  @test v.sub.buf.path == costs
  s, t = v.sub.nodes[:span]
  @test v.sub.buf.lines[s] == "## Prices" && v.sub.buf.lines[t] == "```"
  # The part's editor shows only the lines of the part
  @test first(v.sub.layout).first == s && last(v.sub.layout).last == t
  # A page that isn't there says so
  missing_part = part(line("nowhere"))
  @test missing_part !== nothing && occursin("no page called nowhere", missing_part.note)
  # A block with a name
  intro = part(line("![[costs#^intro]]"))
  @test intro !== nothing && isempty(intro.note)
  @test intro.sub !== v.sub && intro.sub.buf === v.sub.buf   # two parts of one page share its lines
  shot("transclusion.png")
end

@testset "what's typed in the part changes the other page" begin
  v = part(line("![[costs#Prices]]"))
  i = cline(v, "| Paint")
  click(spot(v, i, length("| Paint")))
  @test w.focus === v.sub
  @test v.sub.buf.caret == (i, length("| Paint"))
  typed(" and primer")
  @test v.sub.buf.lines[i] == "| Paint and primer | \$42 |"
  @test !K.dirty(e.buf)          # this page didn't change
  @test K.dirty(v.sub.buf)       # the other page did
  # The other part of the same page shows it too, since they share the lines
  intro = part(line("![[costs#^intro]]"))
  @test intro.sub.buf.lines[i] == "| Paint and primer | \$42 |"
  shot("transclusion_typed.png")
  # ⌘S saves the other page too
  key(Keys.s, Keys.cmd)
  @test occursin("| Paint and primer | \$42 |", read(costs, String))
  @test !K.dirty(v.sub.buf)
  # Return in the part makes a new line in it, and the part keeps it
  j = cline(v, "Buy paint")
  click(spot(v, j, length(v.sub.buf.lines[j])))
  key(Keys.enter); typed("Sand the walls")
  @test v.sub.buf.lines[j+1] == "- [ ] Sand the walls"
  s, t = v.sub.nodes[:span]
  @test s <= j + 1 <= t
  # ⌘Z takes it back in the other page
  key(Keys.z, Keys.cmd); key(Keys.z, Keys.cmd)
  @test !any(l -> occursin("Sand the walls", l), v.sub.buf.lines)
end

@testset "esc, ↑ and ↓ go back to the page" begin
  v = part(line("![[costs#Prices]]"))
  click(spot(v, cline(v, "## Prices"), 3))
  @test w.focus === v.sub
  key(Keys.escape)
  @test w.focus === e
  @test e.buf.caret == (line("![[costs#Prices]]"), 0)   # on the part as a whole
  @test K.picked(e.buf) !== nothing
  # Return gives the part the keyboard again, at its start
  key(Keys.enter)
  @test w.focus === v.sub
  @test v.sub.buf.caret[1] == cline(v, "## Prices")
  # ↑ on its first line goes to the line over it
  key(Keys.up)
  @test w.focus === e
  @test e.buf.caret[1] == line("![[costs#Prices]]") - 1
  # ↓ from its last line of text goes to the line under it
  key(Keys.down)
  @test e.buf.caret == (line("![[costs#Prices]]"), 0)
  key(Keys.enter)
  for _ in 1:40; w.focus === v.sub || break; key(Keys.down) end
  @test w.focus === e
  @test e.buf.caret[1] == line("![[costs#Prices]]") + 1
  # ⌫ at the start of the part doesn't join its first line to the line over it
  key(Keys.up); key(Keys.up)
  e.buf.caret = e.buf.anchor = (line("![[costs#Prices]]"), 0); K.touch!(e); frames()
  key(Keys.enter)
  had = copy(v.sub.buf.lines)
  v.sub.buf.caret = v.sub.buf.anchor = (cline(v, "## Prices"), 0)
  key(Keys.backspace)
  @test v.sub.buf.lines == had
  key(Keys.escape)
end

@testset "⌥-click on the part shows the link that names it" begin
  v = part(line("![[costs#Prices]]"))
  click(spot(v, cline(v, "Buy paint"), 3), Keys.opt)
  @test w.focus === e
  @test e.buf.caret == K.line_end(e.buf, line("![[costs#Prices]]"))
  @test part(line("![[costs#Prices]]")) === nothing   # the line shows as it's written
  e.buf.caret = e.buf.anchor = (line("Before the part"), 0); K.touch!(e); frames()
  @test part(line("![[costs#Prices]]")) !== nothing
end

@testset "a live block in the part is only shown" begin
  v = part(line("![[costs#Prices]]"))
  i = cline(v, "```board")
  it = K.item(v.sub, i)
  @test it.content isa K.Live
  x, y = v.sub.origin[1] + 40px, v.sub.origin[2] + it.top + it.tall / 2
  at(x, y)
  @test hittest(w) isa K.LiveCover
  had = copy(v.sub.buf.lines)
  click((x, y))
  @test v.sub.buf.lines == had
end

@testset "a link in the part opens its page in the window" begin
  v = part(line("![[costs#Prices]]"))
  # The button shows while the mouse is over the part, and stays while the mouse goes on to it
  at(spot(v, cline(v, "## Prices"))...)
  source = v.sub.nodes[:source]
  r = rect(source)
  x, y = r.left + r.width / 2, r.top + r.height / 2
  at(x, y)
  @test hittest(w) === source
  shot("part_button.png")
  click((x, y))
  @test e.buf.path == costs
  @test e.buf.caret[1] == findfirst(==("## Prices"), e.buf.lines)
  K.go_back!(e); frames()
  @test e.buf.path == home
end

@testset "a part can't show its own page, or show parts too deeply" begin
  self = joinpath(dir, "self.md")
  write(self, "# Self\n\n![[self#Self]]\n")
  K.open!(e, self); frames()
  v = part(3)
  @test v !== nothing && occursin("can't show a part of itself", v.note)
  K.go_back!(e); frames()
end

@testset "Copy Link To Block names the block at the caret" begin
  page = joinpath(dir, "notes.md")
  write(page, "# Notes\n\nPaint the fence on Sunday.\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\nThe end.\n")
  K.open!(e, page); frames()
  b = e.buf
  b.caret = b.anchor = (3, 4); frames()
  @test K.block_link!(e) == "![[notes#^paint-the-fence]]"
  @test b.lines[3] == "Paint the fence on Sunday. ^paint-the-fence"
  @test b.caret == (3, 4)
  # Again, it uses the name that the block has
  @test K.block_link!(e) == "![[notes#^paint-the-fence]]"
  # A table gets its name on a line under it
  b.caret = b.anchor = (7, 2); frames()
  @test K.block_link!(e) == "![[notes#^table]]"
  @test b.lines[8] == "^table"
  @test K.transclusion_lines(b, "^table") == (5, 7)
  K.go_back!(e); frames()
end

@testset "a whole block that's copied pastes in another page as a part of its page" begin
  jobs, plan = joinpath(dir, "jobs.md"), joinpath(dir, "plan.md")
  write(jobs, "# Jobs\n\nSand the walls before the paint goes on.\n\n| Room | Hours |\n| --- | --- |\n| Hall | 3 |\n\n## Kitchen\n\nTiles to the ceiling.\n\n- [ ] Order tiles\n- [ ] Book the tiler\n\n## Later\n\n```board\n```\n\nThe end.")
  write(plan, "# Plan\n\nThe first line.\n\nThe last line.")
  at(i) = findfirst(l -> occursin(i, l), e.buf.lines)
  select!(from, to) = begin
    e.buf.anchor, e.buf.caret = from, to
    K.touch!(e); frames()
  end
  copy!() = (key(Keys.c, Keys.cmd); put_text(clipboard(w)))
  # Paste in plan.md, on its empty line before its last line
  paste_in_plan!(held...) = begin
    K.open!(e, plan); frames()
    k = at("The last line") - 1
    e.buf.caret = e.buf.anchor = (k, 0); K.touch!(e); frames()
    key(Keys.v, Keys.cmd, held...)
    k
  end
  K.open!(e, jobs); frames()
  # A paragraph that's selected from its start to its end is a whole block
  i = at("Sand the walls")
  select!((i, 0), K.line_end(e.buf, i))
  copy!()
  @test clipboard(w) == "Sand the walls before the paint goes on."
  j = paste_in_plan!()
  @test e.buf.lines[j] == "![[jobs#^sand-the-walls]]"
  @test part(j) !== nothing && isempty(part(j).note)
  @test e.buf.caret == (j, 0)   # on the part as a whole
  # The block got its name in its own page, which had no other changes, so it was saved
  @test occursin("Sand the walls before the paint goes on. ^sand-the-walls", read(jobs, String))
  # ⌘⇧V pastes the lines instead
  K.undo!(e.buf); frames()
  j = paste_in_plan!(Keys.shft)
  @test e.buf.lines[j] == "Sand the walls before the paint goes on."
  K.undo!(e.buf); frames()
  # A paste in the page that the block came from is a copy of its lines
  K.open!(e, jobs); frames()
  e.buf.caret = e.buf.anchor = K.line_end(e.buf, at("The end")); frames()
  key(Keys.v, Keys.cmd)
  @test e.buf.lines[end] == "The end.Sand the walls before the paint goes on."
  K.undo!(e.buf); frames()
  # A heading with the lines under it is one block
  h = at("## Kitchen")
  select!((h, 0), K.line_end(e.buf, at("Book the tiler")))
  copy!()
  j = paste_in_plan!()
  @test e.buf.lines[j] == "![[jobs#^kitchen]]"
  v = part(j)
  @test v !== nothing && v.sub.nodes[:span] == (h, h + 5)
  K.undo!(e.buf); frames()
  # Some of a block's words aren't a block
  K.open!(e, jobs); frames()
  i = at("Tiles to the ceiling")
  select!((i, 0), (i, 5))
  copy!()
  @test K.COPIED_BLOCK[] === nothing
  j = paste_in_plan!()
  @test e.buf.lines[j] == "Tiles"
  K.undo!(e.buf); frames()
  # The caret on a block as a whole, like a board, copies it whole. Its name goes on a line under it.
  K.open!(e, jobs); frames()
  i = at("```board")
  e.buf.caret = e.buf.anchor = (i, 0); K.touch!(e); frames()
  @test K.picked(e.buf) == (i, i + 1)
  copy!()
  @test clipboard(w) == "```board\n```"
  j = paste_in_plan!()
  @test e.buf.lines[j] == "![[jobs#^board]]"
  @test e.buffers[jobs].lines[i+2] == "^board"
  K.undo!(e.buf); frames()
  # A block that a click with ⌘ and ⌥ down chose, like a table
  K.open!(e, jobs); frames()
  i = at("| Room")
  it = K.item(e, i)
  x, y = e.origin[1] + 40px, e.origin[2] + it.top + it.tall / 2
  w.mouse = typeof(w.mouse)(x, y)
  w.keys |= Keys.cmd; w.keys |= Keys.opt; frames(1)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.opt; frames()
  @test K.code_picker(e).chosen !== nothing
  onkey(w, KeyPress{Keys.c}(0, w)); w.keys ⊻= Keys.cmd; frames()
  put_text(clipboard(w))
  @test clipboard(w) == "| Room | Hours |\n| --- | --- |\n| Hall | 3 |"
  K.unchoose!(K.code_picker(e))
  j = paste_in_plan!()
  @test e.buf.lines[j] == "![[jobs#^table]]"
  K.undo!(e.buf); frames()
  # A block that's cut leaves its page, so it pastes as its lines
  K.open!(e, jobs); frames()
  i = at("Tiles to the ceiling")
  select!((i, 0), K.line_end(e.buf, i))
  key(Keys.x, Keys.cmd); put_text(clipboard(w))
  @test K.COPIED_BLOCK[] === nothing
  j = paste_in_plan!()
  @test e.buf.lines[j] == "Tiles to the ceiling."
  K.undo!(e.buf); frames()
  K.open!(e, jobs); frames(); K.undo!(e.buf); frames()
end
