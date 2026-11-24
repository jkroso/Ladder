# Tests for the `canvas` block of main.jl: a board of cards that you put
# anywhere, as in the app Muse. Run them with
# `julia -O0 --project=. test/canvas_view_test.jl`. They draw in a window that
# isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save pictures
# of the board there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse onscroll Typed ontype onfiledrop
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect onpinch
@use "github.com/jkroso/UI.jl/Interface/save" save_png save_scene
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring
@use GeometryBasics: Vec2
const px = K.px
const C = K.Canvases

# What the board opens in the browser goes here, and nowhere else
const opened = String[]
K.BROWSER[] = to -> (push!(opened, to); nothing)
# ⌘V reads a clipboard that only this test uses
const pb = K.Pasteboard.private_board()
K.Pasteboard.other[] = pb
clear() = msg(pb, "clearContents")
put_text(s) = ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), pb, sel("setString:forType:"), nsstring(s), nsstring("public.utf8-plain-text"))
put_data(kind, bytes) = begin
  data = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt8}, UInt), cls("NSData"), sel("dataWithBytes:length:"), bytes, length(bytes))
  ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), pb, sel("setData:forType:"), data, nsstring(kind))
end

const dir = mktempdir()
# The web is never asked: a card of a web page shows its address
K.MEDIA_CACHE[] = joinpath(dir, "cache")
K.Cards.getter[] = (url, file, most) -> (() -> true)

# A picture that's wider than it's tall
save_scene(joinpath(dir, "sink.png"), K.Row(K.width(160px), K.height(80px), K.background(K.colorant"rgb(60,120,200)")), (160px, 80px))
const bathroom = joinpath(dir, "Bathroom.md")
write(bathroom, """
# The bathroom

Tiles to the ceiling.

```canvas
note 0,0 Basin
note 280,0 Shower
join 1 2
```
""")
const page = joinpath(dir, "plans.md")
write(page, """
# Plans

```canvas
note 0,0 Kitchen
note 300,0 Tiles
join 1 2
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1100px, 800px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
const v = e.nodes[(:block, K.CANVAS, page, 1)]
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
"Click twice in one place, soon enough to be one double click however slow the frames are"
twice(place) = (v.clicked = (0.0, 0.0, 0.0); click(place); v.clicked = (time(), place...); click(place))
"Press the mouse at the first place, move it through the others, and let go"
drag(places...) = (press(places[1]); foreach(at, places[2:end]); release())
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())
"Press `k` with the modifier keys `held`"
key(k, held) = (w.keys |= held; onkey(w, KeyPress{k}(0, w)); w.keys ⊻= held; frames())
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
button(key) = click(middle(rect(v.parts[(:button, key)])))
block() = (s = K.block_lines(e.buf, K.CANVAS, 1); e.buf.lines[s[1]+1:s[2]-1])
"Where a place on the board is in the window"
spot(p) = K.window_place(v, p)
"The card whose words, path, page or address are `s`"
card(s) = only(filter(c -> c.content == s, v.data.cards))
"Where the middle of a card is in the window"
mid(c) = spot(c.at .+ K.card_size(v, c) ./ 2)
"The place on the board at the share `fx` across and `fy` down of what shows of it. No card is near it."
free(fx, fy) = begin
  p = K.board_place(v, v.box[1] + fx * v.box[3], v.box[2] + fy * v.box[4])
  @assert K.card_under(v, p, reach=30) === nothing
  p
end
"A place on the board that shows, with no card, no line between cards and no line drawn by hand near it"
free() = begin
  for fy in 0.1:0.1:0.9, fx in 0.1:0.1:0.9
    p = K.board_place(v, v.box[1] + fx * v.box[3], v.box[2] + fy * v.box[4])
    K.card_under(v, p, reach=40) === nothing && C.stroke_at(v.data, p; reach=20) === nothing &&
      C.join_at(v.data, p, c -> K.card_size(v, c), reach=20) === nothing && return p
  end
  error("no empty place shows")
end
"True when a line joins the card `a` to the card `b`"
joined(a, b) = any(j -> j[1] === card(a) && j[2] === card(b), v.data.joins)

@testset "the block shows the whole board in the page" begin
  @test length(v.data.cards) == 2 && length(v.data.joins) == 1 && !v.full
  @test 0 < v.zoom <= 1 && K.CANVAS_LEAST <= K.num(rect(v.parts[:area]).height) <= K.CANVAS_MOST
  # Both cards show, inside the block
  for c in v.data.cards
    x, y = spot(c.at)
    @test v.box[1] <= x && x + K.card_size(v, c)[1] * v.zoom <= v.box[1] + v.box[3] && v.box[2] <= y
  end
  @test any(en -> en.title == "Canvas", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Canvas", K.INSERTS)
  @test K.cursor(v.parts[:area]) == :arrow && !K.dirty(e.buf)
  # Its tools are over it. Only a board that fills the window has the button that puts it back in the page.
  @test rect(v.parts[(:button, :pen)]).top < v.box[2] && (!haskey(v.parts, (:button, :full)) || rect(v.parts[(:button, :full)]) === nothing)
  shot("canvas-page.png")
end

@testset "you change the board where it is in the page" begin
  # A click selects a card, and the board stays in the page, with the keyboard
  c = card("Kitchen")
  click(mid(c))
  @test v.picked === c && !v.full && K.full_block(e) === nothing && w.focus === v.parts[:area]
  # A drag moves it. The press isn't the second of two clicks, which would type in the note.
  from, z = c.at, v.zoom
  v.clicked = (0.0, 0.0, 0.0)
  drag(mid(c), mid(c) .+ (10, 5), mid(c) .+ (20, 10))
  @test all(c.at .≈ from .+ (20, 10) ./ z) && v.zoom == z && !v.full && K.dirty(e.buf)
  # The wheel scrolls the page past it. With ⌘ held it makes the board bigger, and so does a pinch.
  at(mid(c))
  @test K.onscroll(v.parts[:area], K.MouseScroll(Vec2{px}(px(0), px(2)), w, true)) === nothing && v.zoom == z
  w.keys |= Keys.cmd
  onscroll(w, Vec2{px}(px(0), px(2)), true)
  w.keys ⊻= Keys.cmd
  frames()
  @test v.zoom ≈ z * exp(0.2) && !v.full
  onpinch(w, 1.2); frames()
  @test v.zoom ≈ z * exp(0.2) * 1.2 && !v.full
  # Fit shows the whole board again
  button(:fit)
  @test isapprox(v.zoom, z, rtol=0.05)
  # ⌘Z takes the move back
  K.undo!(e.buf); frames()
  @test card("Kitchen").at == from && block()[1] == "note 0,0 Kitchen"
  # Esc lets go of the card, and then gives the keyboard back to the page's text
  v.clicked = (0.0, 0.0, 0.0)
  click(mid(card("Kitchen")))
  key(Keys.escape)
  @test v.picked === nothing && w.focus === v.parts[:area]
  key(Keys.escape)
  @test w.focus === e && !v.full
end

@testset "the button beside its corner makes it fill the window" begin
  at(middle(rect(v.parts[:area])))
  click(middle(rect(K.fills(e)[objectid(v)].button)))
  @test v.full && K.full_block(e) === v && w.focus === v.parts[:area] && rect(v.parts[(:button, :full)]) !== nothing
  @test v.zoom == 1 && haskey(v.parts, (:button, :pen))   # a small board shows at its own size
end

@testset "two clicks on an empty place make a note, and you type in it" begin
  twice(spot((0, 200)))
  @test v.typing !== nothing && v.fresh && w.focus === v.parts[:input] && v.typing.kind == :note
  typed("Buy the tiles")
  @test v.typing.content == "Buy the tiles" && !any(l -> occursin("Buy", l), block())   # it's written when the typing ends
  key(Keys.escape)
  @test v.typing === nothing && w.focus === v.parts[:area] && any(l -> startswith(l, "note ") && endswith(l, " Buy the tiles"), block())
  # Two clicks on an empty place and no words make nothing
  n = length(block())
  twice(spot(free(0.3, 0.92))); key(Keys.escape)
  @test length(block()) == n && length(v.data.cards) == 3
end

@testset "Return starts a new line in a note, and the note grows" begin
  c = card("Kitchen")
  tall = K.card_size(v, c)[2]
  click(mid(c))
  @test v.picked === c
  key(Keys.enter)
  @test v.typing === c && v.parts[:input].cursor == length("Kitchen")
  key(Keys.enter); typed("and laundry")
  @test K.card_size(v, c)[2] > tall
  shot("canvas-typing.png")
  key(Keys.escape)
  @test block()[1:2] == ["note 0,0 Kitchen", "  and laundry"]
  # Up goes to the line above, as near across as it can
  click(mid(card("Kitchen\nand laundry"))); key(Keys.enter)
  key(Keys.up)
  @test v.parts[:input].cursor == length("Kitchen")
  key(Keys.escape)
  # A click in the words puts the caret there
  c = card("Kitchen\nand laundry")
  twice(spot(c.at .+ (K.NOTE_PAD + 1, K.NOTE_PAD + 5)))
  @test v.typing === c && v.parts[:input].cursor == 0
  key(Keys.escape)
end

@testset "Tab makes a joined note to the right, as in a mind map" begin
  t = card("Tiles")
  click(mid(t)); key(Keys.tab)
  @test v.typing !== nothing && v.fresh && v.typing.at[1] > t.at[1] + t.width
  typed("Grout")
  key(Keys.tab)   # Tab while typing ends the note and makes the next one
  typed("White"); key(Keys.escape)
  @test joined("Tiles", "Grout") && joined("Grout", "White") && card("White").at[1] > card("Grout").at[1]
  # ⇧Return makes a note under it, joined to the card that it's joined from
  click(mid(card("White"))); key(Keys.enter, Keys.shft)
  typed("Black"); key(Keys.escape)
  @test joined("Grout", "Black") && card("Black").at[2] > card("White").at[2] && card("Black").at[1] == card("White").at[1]
  @test any(==("join 1 2"), block())   # Kitchen and Tiles are still joined
  shot("canvas-mindmap.png")
end

@testset "a drag moves a card, and the cards it's joined to stay joined" begin
  c = card("Tiles")
  from = c.at
  drag(mid(c), mid(c) .+ (40, 30), mid(c) .+ (80, 60))
  @test c.at == from .+ (80, 60) ./ v.zoom
  # A card that's moved goes over the others: it's the last card of the block now
  @test v.data.cards[end] === c && joined("Kitchen\nand laundry", "Tiles") && joined("Tiles", "Grout")
  @test C.written(C.canvas(block())) == block()
  # The circle on its corner makes it wider
  wide = c.width
  drag(K.width_knob(v, c), K.width_knob(v, c) .+ (60, 0))
  @test c.width ≈ wide + 60 / v.zoom && any(l -> startswith(l, "note width "), block())
end

@testset "the circle beside a card draws a line from it" begin
  k, b = card("Kitchen\nand laundry"), card("Black")
  drag(K.join_knob(v, k), mid(b) .- (10, 0), mid(b))
  @test joined("Kitchen\nand laundry", "Black")
  # Let go on an empty place, and a new note there is joined to it
  drag(K.join_knob(v, k), spot(free(0.1, 0.92)))
  @test v.typing !== nothing && v.fresh
  typed("Paint"); key(Keys.escape)
  @test joined("Kitchen\nand laundry", "Paint")
end

@testset "Delete takes away what's selected" begin
  n = length(v.data.joins)
  click(mid(card("Paint"))); key(Keys.backspace)
  @test !any(c -> c.content == "Paint", v.data.cards) && length(v.data.joins) == n - 1
  # A click on a line selects it
  j = first(filter(j -> j[2] === card("Black") && j[1] === card("Kitchen\nand laundry"), v.data.joins))
  curve = C.join_curve(C.edges(j[1], K.card_size(v, j[1])), C.edges(j[2], K.card_size(v, j[2])))
  click(spot(C.along(curve, 0.5)))
  @test v.picked === j
  key(Keys.delete)
  @test !joined("Kitchen\nand laundry", "Black") && length(v.data.joins) == n - 2
end

@testset "the pen draws, and the text tool writes on the board" begin
  button(:pen)
  @test v.tool == :pen && K.cursor(v.parts[:area]) == :crosshair
  a, b = free(0.3, 0.15), free(0.4, 0.25)
  drag(spot(a), spot((a .+ b) ./ 2 .+ (0, 20)), spot(b))
  @test length(v.data.strokes) == 1 && any(l -> startswith(l, "pen "), block())
  click(v.parts[(:ink, :red)] |> rect |> middle)
  drag(spot(free(0.5, 0.15)), spot(free(0.55, 0.25)))
  @test v.data.strokes[end].colour == :red
  button(:text)
  click(spot(free(0.7, 0.2)))
  @test v.typing !== nothing && v.typing.kind == :text
  typed("Kitchen plan"); key(Keys.escape)
  @test any(l -> startswith(l, "text red ") && endswith(l, " Kitchen plan"), block())
  # The buttons for the size of the words change the text that's selected
  key(Keys.escape)
  @test v.tool == :select
  click(mid(card("Kitchen plan")))
  button(:bigger)
  @test card("Kitchen plan").size == 24 && any(l -> occursin("text red size 24 ", l), block())
  # Text can be as wide as its words, and the corner gives it an edge
  t = card("Kitchen plan")
  @test t.width == 0
  drag(K.width_knob(v, t), K.width_knob(v, t) .- (60, 0))
  @test t.width > 0 && length(K.card_lines(t)) >= 2
end

@testset "⌘V puts what the clipboard holds on the board" begin
  at((v.box[1] + 0.8v.box[3], v.box[2] + 0.5v.box[4]))
  clear(); put_text("https://example.com/tiles")
  key(Keys.v, Keys.cmd)
  @test card("https://example.com/tiles").kind == :link
  clear(); put_text("[[Bathroom]]")
  key(Keys.v, Keys.cmd)
  @test card("Bathroom").kind == :page && any(l -> occursin(r"^page -?[\d.]+,-?[\d.]+ Bathroom$", l), block())
  clear(); put_text("Ring the plumber")
  key(Keys.v, Keys.cmd)
  @test card("Ring the plumber").kind == :note
  # A picture that was copied as itself goes in the media folder beside the page
  clear(); put_data("public.png", read(joinpath(dir, "sink.png")))
  key(Keys.v, Keys.cmd)
  p = v.data.cards[end]
  @test p.kind == :picture && startswith(p.content, ".media/pasted-") && isfile(joinpath(dir, p.content))
  @test K.card_size(v, p)[2] ≈ p.width / 2   # the picture keeps its shape
  # A note whose words are a web address becomes a card of the web page when the typing ends
  twice(spot(free())); typed("https://example.com/grout"); key(Keys.escape)
  @test card("https://example.com/grout").kind == :link
  shot("canvas-cards.png")
end

@testset "a file dropped on the board goes where it's dropped" begin
  place = (v.box[1] + 0.3v.box[3], v.box[2] + 0.6v.box[4])
  at(place)
  onfiledrop(w, [joinpath(dir, "sink.png")]); frames()
  c = card("sink.png")
  @test c.kind == :picture && abs(mid(c)[1] - place[1]) < 2
  # A Markdown file is a card of its page
  onfiledrop(w, [bathroom]); frames()
  @test count(c -> c.kind == :page && c.content == "Bathroom", v.data.cards) == 2
end

@testset "two clicks open a card of a web page, and a card of a page" begin
  twice(mid(card("https://example.com/tiles")))
  @test opened == ["https://example.com/tiles"]
  b = first(filter(c -> c.content == "Bathroom", v.data.cards))
  @test K.page_glance(e, "Bathroom").board !== nothing && K.card_size(v, b)[2] > K.PAGE_HEAD + 100
  twice(mid(b)); frames(3)
  @test e.buf.path == bathroom
  inner = e.nodes[(:block, K.CANVAS, bathroom, 1)]
  @test inner.full && K.full_block(e) === inner
  shot("canvas-inner.png")
  K.go_back!(e); frames(3)
  @test e.buf.path == page && v.full && K.full_block(e) === v && w.focus === v.parts[:area]
end

@testset "a pinch and two fingers move round the board" begin
  place = mid(card("Tiles"))
  at(place)
  z, under = v.zoom, K.board_place(v, place...)
  onpinch(w, 1.5); frames()
  @test v.zoom ≈ 1.5z && all(K.board_place(v, place...) .≈ under)
  from = v.at
  onscroll(w, Vec2{px}(px(0), px(2))); frames()
  @test v.at[2] < from[2] && v.zoom ≈ 1.5z
  button(:fit)
  frames()
  l, t, r, b = K.board_extent(v)
  @test spot((l, t))[1] >= v.box[1] && spot((r, b))[2] <= v.box[2] + v.box[4]
end

@testset "⌘Z takes back the last change, and Esc puts the board back in the page" begin
  before = copy(block())
  click(mid(card("Ring the plumber"))); key(Keys.backspace)
  @test length(block()) == length(before) - 1
  key(Keys.z, Keys.cmd)
  @test block() == before && card("Ring the plumber").kind == :note
  key(Keys.escape); key(Keys.escape)
  @test !v.full && K.full_block(e) === nothing && w.focus === e
  html = (K.layout!(e); K.page_html(e))
  @test occursin("<svg", html) && occursin("Kitchen", html) && occursin("sink.png", html)
  shot("canvas-page-after.png")
end

@testset "⌘E shows the lines of the block, and again shows the board" begin
  K.full!(v, true); frames()
  @test v.full && w.focus === v.parts[:area]
  K.page_level!(e); frames()
  @test e.plain && !v.full && w.focus === e
  # What's typed there changes the board
  K.type!(e, "note 0,-200 Typed as text\n"); frames()
  @test block()[1] == "note 0,-200 Typed as text"
  K.page_level!(e); frames()
  @test !e.plain && v.full && w.focus === v.parts[:area] && card("Typed as text").at == (0.0, -200.0)
  key(Keys.escape)
  @test !v.full
end

@testset "a new board, as the Insert menu makes it" begin
  empty = joinpath(dir, "empty.md")
  write(empty, "# Empty\n\n```canvas\n```\n")
  e2 = K.build_editor(empty)
  w2 = Window(e2, size=(900px, 700px))
  frame(w2); frame(w2)
  v2 = e2.nodes[(:block, K.CANVAS, empty, 1)]
  @test isempty(v2.data.cards) && K.CANVAS_LEAST <= K.num(rect(v2.parts[:area]).height) <= K.CANVAS_MOST
  K.full!(v2, true); frame(w2); frame(w2)
  @test v2.full && v2.zoom == 1
  close(w2)
end

@testset "the dark theme" begin
  K.use!(K.NIGHT); e.theme = :night; K.restyle!(e)
  K.full!(v, true); frames()
  @test K.canvas_back() == K.NIGHT.bg && K.card_back() == K.NIGHT.float
  shot("canvas-night.png")
  K.full!(v, false)
  K.use!(K.SEPIA); e.theme = :sepia; K.restyle!(e); frames()
end
