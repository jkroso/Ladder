# Tests for a change of level while a sketch fills the window: the lines of
# its block fill the window in its place, as text. `level_test.jl` has the
# rest of what those lines do. Run them with
# `julia -O0 --project=. test/sketch_level_test.jl`. They draw in a window that isn't
# on the screen. Set `LADDER_SHOTS` to a folder, and they save a picture of
# the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "bathroom.md")
write(page, """
# The bathroom

Some words before the drawing.

```sketch
box 100,40 300,160
oval red 120,60 200,120
```

The end.

```schedule
```

- [ ] Tile the floor
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, press, release, click, key, shot) = drive(w)
e.panel = true   # the sidebar shows
frames()
const v = e.nodes[(:block, K.SKETCH, page, 1)]

"Press ⌘E"
level() = (w.keys |= Keys.cmd; onkey(w, KeyPress{Keys.e}(0, w)); w.keys ⊻= Keys.cmd; frames())
"Click the snake or the ladder in the top bar"
# After a click, the mouse is still over the picture, so the slider has opened out from it with the ladder where the picture was
mode() = (r = rect(e.nodes[:mode]); click((K.num(r.left + r.width - K.MODE_W / 2), K.num(r.top + r.height / 2))))
span() = K.block_lines(e.buf, K.SKETCH, 1)
"True when the lines of the sketch show as text"
astext() = (it = K.item(e, span()[1]); !(it.content isa K.Live))
"True when the lines of the block from line `s` to line `t` are all that the window shows"
alone(s, t) = K.lowered(e) == (s, t) && first(e.layout).first == s && last(e.layout).last == t
"True when the sidebar shows"
sidebar() = any(n -> n.from isa K.Sidebar, K.describe(e).children[1].children)
# An icon is in the button as the box that it draws in, and the box knows the icon that it came from
icons(node, out=String[]) = begin
  (node isa K.GeometricUI && !(node isa K.Text)) || return out
  hasproperty(node, :from) && node.from isa K.Icon && push!(out, node.from.name)
  foreach(n -> icons(n, out), node.children)
  out
end
icon() = only(icons(K.level_picture(e.nodes[:mode])))   # the picture that shows while the slider is closed

@testset "a click on the ladder while a sketch fills the window" begin
  s, t = span()
  @test !astext() && icon() == "ladder" && sidebar()
  K.full!(v, true); frames()
  offset = e.scroll.offset
  @test v.full && K.full_block(e) === v && w.focus === v.parts[:area]
  @test K.tip(e.nodes[:mode]) == "Go down a level, to the symbols that make this  ⌘E"
  shot("sketch-full.png")
  # The lines of the sketch fill the window as text, with the caret in them. Nothing else of the page shows, and no sidebar.
  mode()
  @test e.plain && !v.full && K.full_block(e) === nothing && w.focus === e
  @test e.buf.caret == e.buf.anchor == (s + 1, 0) && astext() && icon() == "snake"
  @test alone(s, t) && !sidebar() && e.scroll.offset == 0px
  shot("sketch-text.png")
  # What's typed there changes the sketch
  K.type!(e, "line 10,10 50,50\n"); frames()
  @test alone(s, t + 1) && length(v.data.shapes) == 2
  # A click on the snake goes back up, and the sketch fills the window again, over the page where it was
  mode()
  @test !e.plain && v.full && K.full_block(e) === v && w.focus === v.parts[:area] && icon() == "ladder"
  @test e.buf.caret == (s, 0) && K.picked(e.buf) == (s, t + 1) && K.lowered(e) === nothing
  @test length(v.data.shapes) == 3 && v.data.shapes[1].kind == :line && e.scroll.offset == offset
  # Esc puts it back in the page, where it shows as a drawing
  key(Keys.escape); key(Keys.escape)
  @test !v.full && !astext() && sidebar()
end

@testset "⌘E while a sketch fills the window" begin
  s, t = span()
  K.full!(v, true); frames()
  level()
  @test e.plain && !v.full && w.focus === e && e.buf.caret == (s + 1, 0) && alone(s, t)
  level()
  @test !e.plain && v.full && w.focus === v.parts[:area] && K.lowered(e) === nothing
  key(Keys.escape); key(Keys.escape)
  @test !v.full
end
