# Tests for the `sketch` block of main.jl: a drawing, and the tools that draw
# it. Run them with `julia -O0 --project=. test/sketch_view_test.jl`. They
# draw in a window that isn't on the screen. Set `LADDER_SHOTS` to a folder,
# and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse onscroll Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect onpinch
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "bathroom.md")
write(page, """
# The bathroom

```sketch
box 100,40 300,160
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
const v = e.nodes[(:block, K.SKETCH, page, 1)]
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
"Press the mouse at the first place, move it through the others, and let go"
drag(places...) = (press(places[1]); foreach(at, places[2:end]); release())
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
button(key) = click(middle(rect(v.parts[(:button, key)])))
block() = (s = K.block_lines(e.buf, K.SKETCH, 1); e.buf.lines[s[1]+1:s[2]-1])
"Where a place of the sketch is in the window"
spot(x, y) = (s = K.sketch_scale(v); (v.box[1] + x * s, v.box[2] + y * s))
shapes() = v.data.shapes
"True when a button of the sketch shows"
tools() = any(k -> k isa Tuple && k[1] == :button && rect(v.parts[k]) !== nothing, keys(v.parts))
"The button that shows beside the top right corner of the sketch while the mouse is over it, or nothing"
corner() = (f = get(K.fills(e), objectid(v), nothing); f === nothing || f.button === nothing || rect(f.button) === nothing ? nothing : f.button)

@testset "the block shows its drawing" begin
  @test length(shapes()) == 1 && shapes()[1].kind == :box && v.box[3] > 300
  # The sketch is 720 of its own measure wide, whatever the width of the page
  @test K.sketch_scale(v) ≈ v.box[3] / 720 && rect(v.parts[:area]).height ≈ px(K.Sketches.LEAST * K.sketch_scale(v))
  @test any(en -> en.title == "Sketch", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Sketch", K.INSERTS)
  @test !K.dirty(e.buf)
end

# How big it is in the page, and how far the page is scrolled, before it fills the window
const small, offset = v.box, e.scroll.offset

@testset "the page shows the tools over the drawing, and you draw there" begin
  @test !v.full && tools() && K.cursor(v.parts[:area]) == :crosshair && rect(v.parts[(:button, :pen)]).top < v.box[2]
  # Only a sketch that fills the window has the button that puts it back in the page
  @test !haskey(v.parts, (:button, :full)) || rect(v.parts[(:button, :full)]) === nothing
  # While the mouse is over it, a button shows beside its top right corner
  at(spot(300, 100))
  @test corner() !== nothing && K.num(rect(corner()).left) > v.box[1] + v.box[3]
  shot("corner.png")
  # A click draws nothing, and the sketch stays in the page, with the keyboard
  click(spot(300, 100))
  @test !v.full && K.full_block(e) === nothing && w.focus === v.parts[:area] && length(shapes()) == 1 && !K.dirty(e.buf)
  # A drag draws there
  drag(spot(400, 50), spot(450, 80), spot(500, 120))
  @test length(shapes()) == 2 && shapes()[2].kind == :pen && startswith(block()[2], "pen 400,50 ") && !v.full
  # The wheel is the page's, and a pinch doesn't make the sketch fill the window
  @test K.onscroll(v.parts[:area], K.MouseScroll(Vec2{px}(px(0), px(-2)), w, true)) === nothing
  onpinch(w, 1.2); frames()
  @test !v.full
  # Esc chooses the arrow, and then gives the keyboard back to the page's text
  key(Keys.escape)
  @test v.tool == :select && w.focus === v.parts[:area]
  key(Keys.escape)
  @test w.focus === e && !v.full
  K.undo!(e.buf); frames()
  @test length(shapes()) == 1
  button(:pen)
  # The button beside its corner makes it fill the window, with the button that puts it back at its top
  at(spot(300, 100))
  click(middle(rect(corner())))
  @test v.full && K.full_block(e) === v && tools() && w.focus === v.parts[:area] && corner() === nothing
  @test rect(v.parts[(:button, :full)]) !== nothing && length(shapes()) == 1 && v.tool == :pen
end

@testset "the tools draw shapes" begin
  # The pen draws through the places that the mouse goes through
  drag(spot(400, 50), spot(420, 60), spot(440, 90), spot(430, 120), spot(400, 130))
  @test length(shapes()) == 2 && shapes()[2].kind == :pen && length(shapes()[2].points) >= 3 && startswith(block()[2], "pen 400,50 ")
  @test endswith(block()[2], " 400,130") && K.dirty(e.buf)
  button(:arrow)
  drag(spot(500, 60), spot(520, 80), spot(350, 100))
  @test block()[3] == "arrow 500,60 350,100"
  button(:oval)
  click(middle(rect(v.parts[(:ink, :red)])))
  drag(spot(120, 60), spot(180, 90), spot(280, 140))
  @test block()[4] == "oval red 120,60 280,140"
  # A click without a drag draws nothing
  click(spot(600, 60))
  @test length(shapes()) == 4
  # Words are typed in the drawing, where the click was. The middle of their height is at the mouse.
  button(:text)
  click(spot(520, 144.4))
  @test v.asking == (520.0, 150.0) && w.focus === v.parts[:input]
  typed("The  drain")
  @test v.parts[:input].text == "The  drain" && length(shapes()) == 4 && rect(v.parts[(:button, :text)]).width > 0px
  shot("typing.png")
  key(Keys.enter)
  @test block()[5] == "text red 520,150 The drain" && v.asking === nothing
  # Esc leaves the words out. A colour and a size that are chosen while words are typed are theirs, and a click somewhere else adds them.
  click(spot(300, 190)); typed("No"); key(Keys.escape)
  @test length(shapes()) == 5 && v.asking === nothing
  click(spot(300, 190)); typed("Tap")
  click(middle(rect(v.parts[(:ink, :green)]))); button((:more, :size))
  @test v.asking !== nothing && w.focus === v.parts[:input]
  typed("s"); click(spot(650, 30))
  @test block()[6] == "text green size 17 300,195.6 Taps" && v.asking !== nothing
  key(Keys.escape)
  K.undo!(e.buf); frames()
  click(middle(rect(v.parts[(:ink, :red)]))); button((:less, :size))
  @test length(shapes()) == 5 && v.next[:size] == 16
  # ⌘Z takes the last shape back
  K.undo!(e.buf); frames()
  @test length(block()) == 4 && length(shapes()) == 4
  K.redo!(e.buf); frames()
  @test length(shapes()) == 5
  shot("sketch.png")
end

@testset "the arrow tool selects, moves and deletes" begin
  button(:select)
  click(spot(100, 100))   # the left edge of the box
  @test v.picked == 1 && haskey(v.parts, (:button, :delete))
  drag(spot(100, 100), spot(110, 105), spot(130, 110))
  @test block()[1] == "box 130,50 330,170" && v.picked == 1
  # A colour goes to the shape that's selected
  click(middle(rect(v.parts[(:ink, :blue)])))
  @test block()[1] == "box blue 130,50 330,170"
  key(Keys.backspace)
  @test length(shapes()) == 4 && v.picked == 0 && startswith(block()[1], "pen ")
  click(spot(650, 190))   # on nothing
  @test v.picked == 0
  # The drawing goes down to the window's foot, where there's room for a shape low down
  button(:line)
  drag(spot(50, 100), spot(60, 150), spot(80, 210))
  @test block()[end] == "line blue 50,100 80,210" && isapprox(v.box[2] + v.box[4], 900, atol=1)
  @test e.buf.lines[end-1] == "The end."
  html = K.page_html(e)
  @test occursin("<svg", html) && occursin("<ellipse", html) && occursin(">The drain</text>", html)
end

@testset "how a shape is drawn" begin
  # With a tool that draws, the numbers at the top are for the next shape
  button(:box)
  @test K.shown_settings(v) == (:width, :radius)
  button((:more, :width)); button((:more, :radius))
  drag(spot(500, 30), spot(550, 60), spot(620, 110))
  @test block()[end] == "box blue width 2.5 radius 4 500,30 620,110"
  # With the arrow tool, they're for the shape that's selected
  button(:select)
  @test isempty(K.shown_settings(v))
  click(spot(500, 70))   # the left edge of the new box
  @test v.picked == length(shapes()) && K.shown_settings(v) == (:width, :radius)
  button((:less, :width)); button((:less, :width))
  @test block()[end] == "box blue width 1.5 radius 4 500,30 620,110"
  # A line is never thinner than a half
  foreach(_ -> button((:less, :width)), 1:3)
  @test shapes()[end].width == 0.5 && v.parts[(:button, (:less, :width))].off
  # A click in a number selects it, and Return takes the number that's typed
  number(name) = click(middle(rect(v.parts[(:number, name)])))
  number(:radius)
  @test v.typing == :radius && w.focus === v.parts[(:number, :radius)]
  typed("12"); key(Keys.enter)
  @test block()[end] == "box blue width 0.5 radius 12 500,30 620,110" && v.typing === nothing && w.focus === v.parts[:area]
  # Esc leaves the number as it was, and so do words that aren't a number
  number(:radius); typed("7"); key(Keys.escape)
  number(:radius); typed("round"); key(Keys.enter)
  @test shapes()[end].radius == 12 && v.parts[(:number, :radius)].text == "12"
  # The corners of a box are no rounder than half its shorter side
  number(:radius); typed("99"); key(Keys.enter)
  @test block()[end] == "box blue width 0.5 radius 40 500,30 620,110" && v.parts[(:button, (:more, :radius))].off
  # A click somewhere else keeps the number that was typed, for the shape that it was typed for
  number(:width); typed("3"); click(spot(650, 190))
  @test v.picked == 0 && block()[end] == "box blue width 3 radius 40 500,30 620,110"
  # Words have a size
  click(spot(530, 145))
  @test shapes()[v.picked].kind == :text && K.shown_settings(v) == (:size,)
  button((:more, :size))
  @test block()[v.picked] == "text red size 17 520,150 The drain"
  # ⌘Z takes a change back
  K.undo!(e.buf); frames()
  @test block()[4] == "text red 520,150 The drain"
end

@testset "the circles of the shape that's selected" begin
  click(spot(500, 70))
  n = length(shapes())
  @test v.picked == n && K.cursor(v.parts[:area]) == :arrow
  # The mouse over a circle shows a hand, and a drag of the circle moves that corner of the box
  at(spot(620, 110))
  @test K.handle_under(v, w) == 3 && K.cursor(v.parts[:area]) == :hand
  shot("selected.png")
  drag(spot(620, 110), spot(630, 120), spot(660, 140))
  @test block()[end] == "box blue width 3 radius 40 500,30 660,140" && v.picked == n
  # Beside the circles, a drag moves the whole shape
  drag(spot(580, 30), spot(580, 35), spot(580, 40))
  @test block()[end] == "box blue width 3 radius 40 500,40 660,150"
  # The end of a line moves by itself
  click(spot(65, 155))
  @test shapes()[v.picked].kind == :line
  drag(spot(80, 210), spot(90, 200), spot(120, 180))
  @test block()[v.picked] == "line blue 50,100 120,180"
  key(Keys.escape)
  @test v.picked == 0
end

@testset "changing words where they are" begin
  field = v.parts[:input]
  twice(place) = (click(place); click(place))
  # Two clicks on words with the arrow tool open them, with the caret where the click was
  twice(spot(530, 136))
  @test v.editing == 4 && v.asking == (520.0, 150.0) && field.text == "The drain" && w.focus === field && 0 < field.cursor < 4
  @test K.shown_settings(v) == (:size,)
  # A click further along the words moves the caret, and what's typed goes in there
  click(spot(520 + K.sketch_measure("The drain", 16) + 2, 145))
  @test field.cursor == 9 && v.editing == 4
  typed(" pipe")
  shot("editing.png")
  key(Keys.enter)
  @test block()[4] == "text red 520,150 The drain pipe" && v.asking === nothing && v.editing == 0 && v.picked == 4
  # Esc leaves them as they were
  twice(spot(530, 136)); typed("x"); key(Keys.escape)
  @test block()[4] == "text red 520,150 The drain pipe" && v.editing == 0
  # A colour that's chosen while they're changed is theirs
  twice(spot(530, 136)); click(middle(rect(v.parts[(:ink, :green)])))
  @test v.editing == 4 && w.focus === field
  key(Keys.enter)
  @test block()[4] == "text green 520,150 The drain pipe"
  # With the tool for words, one click opens them. Words with nothing left in them are taken away.
  n = length(shapes())
  button(:text)
  click(spot(530, 136))
  @test v.editing == 4 && field.text == "The drain pipe"
  field.text = ""; field.anchor = field.cursor = 0
  key(Keys.enter)
  @test length(shapes()) == n - 1 && !any(s -> s.kind == :text, shapes()) && v.picked == 0
  K.undo!(e.buf); frames()
  @test block()[4] == "text green 520,150 The drain pipe"
  button(:select)
end

@testset "a sketch that fills the window" begin
  @test v.full && K.full_block(e) === v && w.focus === v.parts[:area]
  # It's as wide as the window, and its drawing goes down to the window's foot
  @test v.box[3] ≈ 1000 && K.sketch_scale(v) ≈ 1000 / 720 && isapprox(v.box[2] + v.box[4], 900, atol=1)
  shot("full.png")
  # A shape is drawn there as it is in the page
  button(:line)
  drag(spot(100, 300), spot(150, 320), spot(200, 350))
  @test block()[end] == "line green width 3 100,300 200,350"   # green was the last colour that was chosen
  # The wheel scrolls a drawing that's taller than the window, and the page under it stays where it was
  drag(spot(100, 500), spot(150, 520), spot(200, 570))
  top = v.box[2]
  at(spot(300, 200)); onscroll(w, Vec2{px}(px(0), px(-5))); frames()
  @test v.box[2] < top && v.box[2] + v.box[4] ≈ 900 && e.scroll.offset == offset
  # A click beside a button isn't the page's
  caret = e.buf.caret
  click((K.num(rect(v.parts[(:button, :full)]).left) - 60, K.num(rect(v.parts[(:button, :full)]).top) + 10))
  @test e.buf.caret == caret && w.focus === v.parts[:area] && v.full
  # Esc chooses the arrow tool first. With that tool, it puts the sketch back in the page, where the page was.
  key(Keys.escape)
  @test v.tool == :select && v.full
  key(Keys.escape)
  @test !v.full && K.full_block(e) === nothing && e.scroll.offset == offset && w.focus === e
  # Back in the page, its drawing is taller now, since a shape is low in it
  @test v.box[3] ≈ small[3] && v.box[4] > small[4] && tools()
  shot("page.png")
  # The button beside its corner makes it fill the window, and the last button at its top puts it back
  at(spot(300, 100))
  click(middle(rect(corner())))
  @test v.full && v.tool == :select
  button(:full)
  @test !v.full && w.focus === e
  # A pinch outwards on it doesn't make it fill the window
  at(spot(300, 100)); onpinch(w, 1.2); frames()
  @test !v.full
  # A click with ⌥ held shows its lines, and it stays in the page
  s = K.block_lines(e.buf, K.SKETCH, 1)[1]
  w.keys |= Keys.opt
  click(spot(300, 100))
  w.keys ⊻= Keys.opt
  @test !v.full && e.buf.caret == (s + 1, 0)
end
