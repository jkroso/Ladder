# Tests for the `signature` block of main.jl: a box that a person signs in
# with the mouse. Run them with `julia -O0 --project=. test/signature_view_test.jl`.
# They draw in windows that aren't on the screen. Set `LADDER_SHOTS` to a
# folder, and they save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse onscroll Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use Dates: DateTime
const px = K.px
const S = K.Signatures

# The clock says 14 minutes past 9 on 18 November 2026, until a test moves it on
K.sign_clock[] = () -> DateTime(2026, 11, 18, 9, 14, 30)

const dir = mktempdir()
const page = joinpath(dir, "quote.md")
write(page, """
# A quote for the deck

The deck costs 4,200 dollars. Sign here to accept the quote.

```signature
name: Sam Lee
```

And the builder signs here.

```signature
```

""" * "One more line of the quote.\n\n"^60)

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2, w=w) = foreach(_ -> frame(w), 1:n)
frames()
const v = e.nodes[(:block, K.SIGNATURE, page, 1)]
const u = e.nodes[(:block, K.SIGNATURE, page, 2)]
shot(name, w=w) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

at((x, y), w=w) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1, w))
press(place, w=w) = (at(place, w); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release(w=w) = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2, w))
click(place, w=w) = (press(place, w); release(w))
"Press the mouse at the first place, move it through the others, and let go"
drag(places...; w=w) = (press(places[1], w); foreach(p -> at(p, w), places[2:end]); release(w))
key(k, held...) = (foreach(h -> w.keys |= h, held); onkey(w, KeyPress{k}(0, w)); foreach(h -> w.keys ⊻= h, held); frames())
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
"The lines of the `n`th signature of the page that `e` shows"
block(n, e=e) = (s = K.block_lines(e.buf, K.SIGNATURE, n); e.buf.lines[s[1]+1:s[2]-1])
"Where a place of the box of `v` is in the window"
spot(v, x, y) = (s = K.sign_scale(v); (v.box[1] + x * s, v.box[2] + y * s))
"True when a part of a block was drawn in the last frame"
shows(v, key) = haskey(v.parts, key) && rect(v.parts[key]) !== nothing

@testset "the block shows a box to sign in" begin
  # The box is 420 px wide and 130 px tall at the usual size of the text
  @test v.box[3] ≈ 420 && v.box[4] ≈ 130 && u.box[3] ≈ 420 && K.sign_scale(v) ≈ 1
  @test !S.issigned(v.data) && v.data.name == "Sam Lee" && u.data.name == ""
  # A block with a name shows the name. One with no name has a field to type it in.
  @test !shows(v, :input) && shows(u, :input) && !shows(v, (:button, :clear))
  @test K.cursor(v.parts[:area]) == :crosshair
  @test any(en -> en.title == "Signature", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Signature", K.INSERTS)
  @test !K.dirty(e.buf)
  shot("signature-empty.png")
end

@testset "a drag draws a stroke, and the first one writes the day" begin
  # A click without a drag doesn't sign the page
  click(spot(v, 80, 70))
  @test block(1) == ["name: Sam Lee"] && !K.dirty(e.buf) && v.draft === nothing
  press(spot(v, 60, 70))
  @test v.draft == [(60.0, 70.0)]
  at(spot(v, 70, 50)); at(spot(v, 85, 88)); at(spot(v, 100, 55)); at(spot(v, 120, 85))
  @test length(v.draft) == 5 && block(1) == ["name: Sam Lee"]
  shot("signature-drawing.png")
  release()
  @test block(1) == ["name: Sam Lee", "signed: 2026-11-18 09:14", "pen 60,70 70,50 85,88 100,55 120,85"]
  @test v.draft === nothing && S.issigned(v.data) && K.dirty(e.buf) && w.focus === e
  # The next stroke is another line, and the day stays as the first stroke wrote it
  K.sign_clock[] = () -> DateTime(2026, 11, 20, 16, 0)
  drag(spot(v, 140, 60), spot(v, 160, 90), spot(v, 200, 80))
  @test block(1)[2:end] == ["signed: 2026-11-18 09:14", "pen 60,70 70,50 85,88 100,55 120,85", "pen 140,60 160,90 200,80"]
  # In a signed block, a click is a dot
  click(spot(v, 210, 60))
  @test block(1)[end] == "pen 210,60 210,60" && length(v.data.strokes) == 3
  K.sign_clock[] = () -> DateTime(2026, 11, 18, 9, 14, 30)
  # With ⌥ held, a press shows the block's lines and draws nothing
  w.keys |= Keys.opt; click(spot(v, 100, 60)); w.keys ⊻= Keys.opt
  @test length(block(1)) == 5 && v.draft === nothing && v.first < e.buf.caret[1] <= v.last
  e.buf.caret = e.buf.anchor = (1, 0); frames()
end

@testset "a stroke that leaves the box goes on, and the page stays as it is" begin
  caret, offset = e.buf.caret, e.scroll.offset
  # The wheel scrolls this page
  at((500, 600)); onscroll(w, Vec2{px}(0px, -30px)); frames()
  @test e.scroll.offset > offset
  e.scroll.offset = offset; frames()
  press(spot(v, 250, 60))
  at(spot(v, 260, 20)); at(spot(v, 270, -40)); at(spot(v, 300, -60))
  # Out of the box, over the page's text, the stroke goes on. The wheel doesn't scroll the page meanwhile.
  @test v.draft[end] == (300.0, -60.0)
  onscroll(w, Vec2{px}(0px, -30px)); frames()
  @test e.scroll.offset == offset
  at(spot(v, 330, 30)); at(spot(v, 340, 80))
  release()
  @test block(1)[end] == "pen 250,60 260,20 270,-40 300,-60 330,30 340,80" && length(v.data.strokes) == 4
  # No text of the page is selected, and the page didn't scroll. The press put the caret on the block as a whole.
  @test e.buf.caret == (v.first, 0) && K.picked(e.buf) !== nothing && e.buf.anchor == e.buf.caret && e.scroll.offset == offset
  # Once the mouse is up, the wheel scrolls the page again
  at((500, 600)); onscroll(w, Vec2{px}(0px, -30px)); frames()
  @test e.scroll.offset > offset
  e.scroll.offset = offset; frames()
  at(spot(v, 200, 60))
  shot("signature-signed.png")
end

@testset "⌘Z takes back the last stroke" begin
  key(Keys.z, Keys.cmd)
  @test length(v.data.strokes) == 3 && block(1)[end] == "pen 210,60 210,60"
  key(Keys.z, Keys.cmd); key(Keys.z, Keys.cmd)
  @test block(1) == ["name: Sam Lee", "signed: 2026-11-18 09:14", "pen 60,70 70,50 85,88 100,55 120,85"]
  # The first stroke and the day go together
  key(Keys.z, Keys.cmd)
  @test block(1) == ["name: Sam Lee"] && !S.issigned(v.data) && v.data.when === nothing && !K.dirty(e.buf)
  K.redo!(e.buf); K.redo!(e.buf); frames()
  @test length(v.data.strokes) == 2 && v.data.when == DateTime(2026, 11, 18, 9, 14)
end

@testset "Clear takes the signature away in one change" begin
  # The button shows only while the mouse is over the signed block
  at((900, 700))
  @test !shows(v, (:button, :clear))
  at(spot(v, 200, 60)); frames()
  @test shows(v, (:button, :clear)) && !shows(u, (:button, :clear))
  # It's under the box, at the box's right end, so it covers none of the ink
  r = rect(v.parts[(:button, :clear)])
  @test K.num(r.top) >= v.box[2] + v.box[4] && K.num(r.left + r.width) <= v.box[1] + v.box[3] + 1
  shot("signature-clear.png")
  click(middle(r))
  @test block(1) == ["name: Sam Lee"] && !S.issigned(v.data) && !shows(v, (:button, :clear))
  # One ⌘Z brings the strokes and the day back
  key(Keys.z, Keys.cmd)
  @test length(block(1)) == 4 && length(v.data.strokes) == 2 && v.data.when == DateTime(2026, 11, 18, 9, 14)
end

@testset "a block with no name takes the name in its field" begin
  click(middle(rect(u.parts[:input])))
  @test w.focus === u.parts[:input]
  typed("Jo ")
  @test block(2) == ["name: Jo"] && u.parts[:input].text == "Jo "
  typed("Ng")
  @test block(2) == ["name: Jo Ng"] && shows(u, :input)
  shot("signature-name.png")
  # Return gives the keyboard back to the page, and the field stays, to change the name
  key(Keys.enter)
  @test w.focus === e && shows(u, :input) && block(2) == ["name: Jo Ng"]
  # ⌘Z takes the name back, out of the field too. Letters that are typed one soon after another go back together.
  key(Keys.z, Keys.cmd)
  isempty(block(2)) || key(Keys.z, Keys.cmd)
  @test isempty(block(2)) && u.parts[:input].text == ""
  # A block that's signed with no name says only the day
  drag(spot(u, 60, 70), spot(u, 90, 40), spot(u, 120, 90))
  @test block(2) == ["signed: 2026-11-18 09:14", "pen 60,70 90,40 120,90"] && S.caption(u.data) == "Signed on 18 November 2026"
  @test !shows(u, :input)
  key(Keys.z, Keys.cmd)
  # A stroke takes the keyboard from the field, and the name is kept
  click(middle(rect(u.parts[:input]))); typed("Jo Ng")
  drag(spot(u, 60, 70), spot(u, 90, 40), spot(u, 120, 90))
  @test block(2) == ["name: Jo Ng", "signed: 2026-11-18 09:14", "pen 60,70 90,40 120,90"] && w.focus === e
  @test S.caption(u.data) == "Signed by Jo Ng on 18 November 2026"
end

@testset "the page as HTML and on paper" begin
  html = K.page_html(e)
  @test count("<svg ", html) == 2 && occursin("d=\"M60 70 Q70 50 77.5 69 Q85 88 92.5 71.5 Q100 55 110 70 L120 85\"", html)
  @test occursin("Signed by Sam Lee on 18 November 2026</p>", html) && occursin("Signed by Jo Ng on 18 November 2026</p>", html)
  @test !occursin("```signature", html) && !occursin("pen 60,70", html)
  # Printing draws the page for paper, and leaves the window as it was
  at(spot(v, 200, 60))
  @test length(K.print_pdf(e)) > 1000
  frames()
  @test v.box[3] ≈ 420 && shows(v, (:button, :clear)) && length(v.data.strokes) == 2
end

@testset "the dark page" begin
  e.theme = :night; K.restyle!(e); frames()
  at((900, 700))
  shot("signature-night.png")
  # And with the second block as it was before its stroke: an empty box, with the name in its field
  K.undo!(e.buf); frames()
  @test !S.issigned(u.data) && shows(u, :input) && u.parts[:input].text == "Jo Ng"
  shot("signature-night-empty.png")
  K.redo!(e.buf); frames()
  @test S.issigned(u.data) && !shows(u, :input)
  e.theme = :sepia; K.restyle!(e); frames()
end

@testset "the signature keeps its shape in a page that's zoomed" begin
  lines = copy(block(1))
  K.text_size!(e, 26); frames(3)
  @test e.zoom > 1.4 && v.box[3] ≈ 420 * e.zoom && v.box[4] / v.box[3] ≈ 130 / 420
  # A place of the box is the same place, whatever size the box is
  drag(spot(v, 300, 40), spot(v, 320, 80), spot(v, 350, 50))
  @test block(1) == [lines..., "pen 300,40 320,80 350,50"]
  shot("signature-zoomed.png")
  key(Keys.z, Keys.cmd)
  K.text_size!(e, 17); frames(3)
  @test v.box[3] ≈ 420
end

@testset "a narrow window" begin
  K.save!(e.buf)
  e2 = K.build_editor(page)
  w2 = Window(e2, size=(340px, 700px))
  frames(3, w2)
  v2 = e2.nodes[(:block, K.SIGNATURE, page, 1)]
  # The box is as wide as the page's text, and as tall as its shape needs
  @test v2.box[3] ≈ K.num(e2.width) && v2.box[3] < 400 && v2.box[4] / v2.box[3] ≈ 130 / 420
  @test v2.box[1] + v2.box[3] <= 340
  drag(spot(v2, 300, 40), spot(v2, 320, 80), spot(v2, 350, 50); w=w2)
  @test block(1, e2)[end] == "pen 300,40 320,80 350,50"
  shot("signature-narrow.png", w2)
  close(w2)
end

@testset "a block whose lines are wrong shows the empty box" begin
  wrong = joinpath(dir, "wrong.md")
  write(wrong, """
  # Wrong

  ```signature
  signed: last week
  pen 1,2
  pen ten,twenty 30,40
  box 1,1 20,20
  name
  ```

  ```signature
  pen 10,20 30,40
  ```

  ```signature
  """)
  e3 = K.build_editor(wrong)
  w3 = Window(e3, size=(800px, 700px))
  frames(3, w3)
  v3 = e3.nodes[(:block, K.SIGNATURE, wrong, 1)]
  @test v3.box[3] ≈ 420 && !S.issigned(v3.data) && length(v3.data.other) == 5 && shows(v3, :input)
  shot("signature-wrong.png", w3)
  @test occursin("<svg ", K.page_html(e3))
  # The block takes a stroke, and keeps the lines that it couldn't read
  drag(spot(v3, 60, 70), spot(v3, 90, 40), spot(v3, 120, 90); w=w3)
  @test block(1, e3) == ["signed: 2026-11-18 09:14", "pen 60,70 90,40 120,90", "pen 1,2", "pen ten,twenty 30,40", "box 1,1 20,20", "name"]
  close(w3)
end

@testset "a page that can't be changed takes no strokes" begin
  fixed = joinpath(dir, "fixed.md")
  write(fixed, "# Signed\n\n```signature\nname: Sam Lee\nsigned: 2026-11-18 09:14\npen 60,70 90,40 120,90\n```\n\n```signature\n```\n")
  chmod(fixed, 0o444)
  e4 = K.build_editor(fixed)
  w4 = Window(e4, size=(800px, 700px))
  frames(3, w4)
  v4, u4 = e4.nodes[(:block, K.SIGNATURE, fixed, 1)], e4.nodes[(:block, K.SIGNATURE, fixed, 2)]
  @test e4.buf.fixed && K.locked(v4) && K.cursor(v4.parts[:area]) == :arrow
  drag(spot(v4, 200, 70), spot(v4, 230, 40), spot(v4, 260, 90); w=w4)
  drag(spot(u4, 200, 70), spot(u4, 230, 40), spot(u4, 260, 90); w=w4)
  @test v4.draft === nothing && length(v4.data.strokes) == 1 && isempty(block(2, e4)) && !K.dirty(e4.buf)
  # It has no Clear button and no field for the name
  at(spot(v4, 200, 60), w4); frames(2, w4)
  @test !shows(v4, (:button, :clear)) && !shows(u4, :input)
  shot("signature-fixed.png", w4)
  close(w4)
  chmod(fixed, 0o644)
end

close(w)
