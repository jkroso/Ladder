# Tests for a change of level while a block fills the window: the lines of the
# block fill the window in its place, as text. Run them with
# `julia -O0 --project=. test/level_test.jl`. They draw in a window that isn't
# on the screen. Set `LADDER_SHOTS` to a folder, and they save a picture of
# the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "bathroom.md")
write(page, """
# The bathroom

Some words before the schedule.

```schedule
start: 2026-11-16

Tile the floor | 3 days
```

The end.

- [ ] Tile the floor
- [ ] Paint the walls
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
e.panel = true   # the sidebar shows
frames()
const v = K.block_view(e, K.SCHEDULE, 1)
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())
"Press ⌘E"
level() = (w.keys |= Keys.cmd; onkey(w, KeyPress{Keys.e}(0, w)); w.keys ⊻= Keys.cmd; frames())
"Click the snake or the ladder in the top bar"
# After a click, the mouse is still over the picture, so the slider has opened out from it with the ladder where the picture was
mode() = (r = rect(e.nodes[:mode]); click((K.num(r.left + r.width - K.MODE_W / 2), K.num(r.top + r.height / 2))))
span() = K.block_lines(e.buf, K.SCHEDULE, 1)
"True when the lines of the schedule show as text"
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

"The part of the schedule that takes the keys"
area() = K.keyboard_part(v)

@testset "a click on the ladder while a schedule fills the window" begin
  s, t = span()
  n = length(e.layout)
  @test !astext() && icon() == "ladder" && sidebar()
  K.full!(v, true); frames()
  offset = e.scroll.offset
  @test v.full && K.full_block(e) === v && w.focus === area()
  @test K.tip(e.nodes[:mode]) == "Go down a level, to the symbols that make this  ⌘E"
  shot("level-full.png")
  # The lines of the schedule fill the window as text, with the caret in them. Nothing else of the page shows, and no sidebar.
  mode()
  @test e.plain && !v.full && K.full_block(e) === nothing && w.focus === e
  @test e.buf.caret == e.buf.anchor == (s + 1, 0) && astext() && icon() == "snake"
  @test alone(s, t) && !sidebar() && e.scroll.offset == 0px
  # The text is as wide as the window, less the page's edges
  @test e.width == 1000px - 2K.PAGE_X && K.text_left(e) == K.PAGE_X
  shot("level-text.png")
  # The caret stays in those lines
  key(Keys.up); key(Keys.up); key(Keys.up)
  @test e.buf.caret == (s, 0)
  foreach(_ -> key(Keys.down), 1:8)
  @test e.buf.caret[1] == t && alone(s, t)
  K.move!(e, (1, 0), false); frames()
  @test e.buf.caret == (s, 0)
  # What's typed there changes the schedule
  K.move!(e, (t, 0), false)
  K.type!(e, "Paint the walls | 2 days\n"); frames()
  @test alone(s, t + 1)
  # A click on the snake goes back up, and the schedule fills the window again, over the page where it was
  mode()
  @test !e.plain && v.full && K.full_block(e) === v && w.focus === area() && icon() == "ladder"
  @test e.buf.caret == (s, 0) && K.picked(e.buf) == (s, t + 1) && K.lowered(e) === nothing
  @test v.lines[end] == "Paint the walls | 2 days" && e.scroll.offset == offset
  # Back in the page, it shows as a schedule among the rest of the page
  K.full!(v, false); frames()
  @test !v.full && !astext() && length(e.layout) == n && sidebar() && e.scroll.offset == offset
end

@testset "⌘E while a schedule fills the window, and Esc" begin
  s, t = span()
  n = length(e.layout)
  K.full!(v, true); frames()
  level()
  @test e.plain && !v.full && w.focus === e && e.buf.caret == (s + 1, 0) && alone(s, t)
  level()
  @test !e.plain && v.full && w.focus === area() && K.lowered(e) === nothing
  # Esc puts the lines back among the lines of the page, which stays at the low level
  level()
  @test alone(s, t)
  key(Keys.escape)
  @test K.lowered(e) === nothing && e.plain && !v.full && astext() && sidebar() && !e.buf.reading
  @test first(e.layout).first == 1 && last(e.layout).last == length(e.buf.lines) && e.buf.caret == (s + 1, 0)
  @test e.width < 1000px - 2K.PAGE_X
  # From there, going up leaves the schedule in the page
  level()
  @test !e.plain && !v.full && K.full_block(e) === nothing && length(e.layout) == n
end

@testset "a schedule that fills the window while the page is at the low level" begin
  s, t = span()
  K.move!(e, (1, 0), false)
  K.plain!(e, true); frames()
  @test icon() == "snake" && !astext()
  # The window shows graphics, so the bar shows the ladder, and going down shows the schedule's lines
  K.full!(v, true); frames()
  @test e.plain && icon() == "ladder"
  level()
  @test e.plain && !v.full && alone(s, t) && icon() == "snake" && e.buf.caret == (s + 1, 0)
  level()
  @test !e.plain && v.full
  K.full!(v, false); frames()
end

@testset "the lines stop filling the window when the block goes" begin
  s, t = span()
  K.full!(v, true); frames()
  level()
  @test alone(s, t)
  # The line that opens the block is taken away, so the page has no such block
  K.move!(e, (s, 0), false); K.move!(e, (s + 1, 0), true)
  K.type!(e, ""); frames()
  @test K.lowered(e) === nothing && first(e.layout).first == 1 && last(e.layout).last == length(e.buf.lines) && sidebar()
  K.undo!(e.buf); frames()
  @test span() == (s, t) && K.lowered(e) === nothing
  K.move!(e, (1, 0), false)
  K.plain!(e, false); frames()
end
