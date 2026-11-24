# Tests for the `map` block of main.jl: the map of a place, the pin that
# Ladder draws on the place, the map's buttons, a drag that moves the map, a
# click that moves the place, and what the block shows while the place or the
# picture isn't there. Run them with
# `julia -O0 --project=. test/map_view_test.jl`. They click in a window that
# isn't on the screen. They use neither the network nor the program that
# asks Apple's maps, and they open no app: map_fake.jl takes the place of
# both. Set `LADDER_SHOTS` to a folder, and they save pictures of
# the page there.

@use Test: @test, @testset
@use "../main" => K
@use "./map_fake" => Fake
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use GeometryBasics: Vec2
@use Base64: base64decode
const px = K.px
const M = K.Maps

M.HELPER[] = Fake.helper
M.FINDER[] = Fake.finder
M.OPENER[] = Fake.opener
K.MEDIA_CACHE[] = mktempdir()   # the places and the pictures are kept here, and not in the Mac's caches

const WATTLE = "8 Wattle Street, Brunswick VIC 3056"
const dir = mktempdir()
const page = joinpath(dir, "job.md")
write(page, """
# The job at Wattle Street

```map
$WATTLE
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
view(n=1) = e.nodes[(:block, K.MAP, page, n)]
shot(name, window=w) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), window)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release(n=2) = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(n))
click(place) = (press(place); release())
"Press the mouse at one place, move it to another by way of the place between, and let go"
drag(from, to) = (press(from); at((from .+ to) ./ 2); at(to); release())
key(k, held=Keys(0)) = (w.keys = held; onkey(w, KeyPress{k}(0, w)); w.keys = Keys(0); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
button(name, n=1) = click(middle(rect(view(n).parts[(:button, name)])))
block(n=1) = (s = K.block_lines(e.buf, K.MAP, n); e.buf.lines[s[1]+1:s[2]-1])
wide() = round(Int, K.num(e.width))
"The file that keeps a picture of the page's width, whose middle is `centre`"
kept(centre, zoom=15; dark=false) = M.file(K.media_dir(), centre, zoom, wide(), M.TALL, dark)
"True when the page's first map has that picture"
shows(centre, zoom=15; kw...) = (s = view().shown; s !== nothing && s.file == kept(centre, zoom; kw...) && s.zoom == zoom)
"What the helper is asked for a picture of the page's width"
asked(centre, zoom=15; dark=false) = (centre=M.rounded(centre), zoom=zoom, wide=wide(), tall=280, dark=dark)
"Where the picture of the page's first map is in the window"
area() = rect(view().parts[:area])
"The latitude and the longitude at a place of the window, on a map whose middle is `centre`"
under(place, centre, zoom=15) = (r = area(); M.latlon(place .- (K.num(r.left), K.num(r.top)), centre, zoom, K.num(r.width), K.num(r.height)))
"Draw frames until `done()` is true, for 10 seconds at most"
until(done) = (t = time(); while !done() && time() - t < 10; sleep(0.02); frames(1); end; done())
"The red, the green and the blue of each pixel of a picture, by the pixel's place across and down"
rgb(dots) = (x, y) -> (c = dots[round(Int, y), round(Int, x)]; (Int((c >> 16) & 0xff), Int((c >> 8) & 0xff), Int(c & 0xff)))
"The red, the green and the blue of the window's pixel at each of some places, as the window was last drawn"
colours(places...) = begin
  file = joinpath(dir, "window.png")
  save_png(file, w)
  dots = pixels(file)
  k = size(dots, 2) / K.num(K.window_size(e)[1])
  map(p -> rgb(dots)(p[1] * k, p[2] * k), places)
end
colour(place) = colours(place)[1]
"True for the red of the pin that Ladder draws"
red(c) = all(abs.(c .- (235, 66, 54)) .< 14)
"True when the window shows a pin whose point is at `place`: the red of its head, and the white dot in it"
pinned(place) = ((head, dot) = colours(place .+ (-7, -26), place .+ (0, -26)); red(head) && dot == (255, 255, 255))
"True when the window shows red somewhere in the box from `from` to `to`, as a pin there would"
reddens(from, to) = any(red, colours([(x, y) for x in from[1]:5:to[1] for y in from[2]:5:to[2]]...))
"Write `lines` as the lines of the page's first map, as typing them does"
rewrite(lines...) = (K.write_block!(view(), K.MAP, String[lines...]); frames())
"The button beside the top right corner of the map that makes it fill the window, or nothing while it doesn't show"
corner() = (f = get(K.fills(e), objectid(view()), nothing); f === nothing || f.button === nothing || rect(f.button) === nothing ? nothing : f.button)
"The pixels of the picture that the page of HTML holds"
html_picture(html=K.page_html(e)) = begin
  file = joinpath(dir, "html.png")
  write(file, base64decode(match(r"<img src=\"data:image/png;base64,([^\"]+)\"", html)[1]))
  pixels(file)
end
"The middle of the map whose place is the fake's address and is in the middle"
const HOME = M.rounded(Fake.ADDRESS)

@testset "the map shows the picture of its place, with a pin on the place" begin
  v = view()
  # The place is asked for once, and then the picture whose middle is the place
  @test Fake.finds == [WATTLE] && Fake.calls == [asked(HOME)]
  @test shows(HOME) && isfile(kept(HOME)) && K.map_words(v) == ""
  @test K.map_pin(v) == Fake.ADDRESS && K.map_middle(v) == HOME && v.shown.centre == HOME
  # The picture is as wide as the page's text, but for the line round the block, and 280 px tall
  r = area()
  @test r.height == 280px && e.width - 4px <= r.width <= e.width
  # The picture has no pin in it. Ladder draws the pin, with its point on the place, which is in the middle of the map.
  @test pinned(middle(r)) && !red(rgb(pixels(kept(HOME)))(wide() - 14, 228))
  # The address that Apple has for the place is under the map
  @test K.map_address(v) == "$WATTLE, Australia"
  @test rect(v.parts[(:button, :open)]).top > r.top + r.height - 1px
  # The two buttons are on the map, in its top right corner. A map with its place in the middle has no third one.
  less, more = rect(v.parts[(:button, :out)]), rect(v.parts[(:button, :in)])
  @test r.top < less.top < r.top + 20px && less.left < more.left && r.left + r.width - 60px < more.left + more.width < r.left + r.width
  @test !haskey(v.parts, (:button, :home))
  @test any(en -> en.title == "Map", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Map", K.INSERTS)
  @test K.Searches.block_kind(K.MAP) == :map
  # The mouse over a map that a drag can move is a hand
  @test K.map_moves(v) && K.cursor(v.parts[:area]) == :hand
  # More frames ask for nothing more, and the file is as it was
  frames(5)
  @test length(Fake.calls) == 1 && length(Fake.finds) == 1 && !K.dirty(e.buf) && block() == [WATTLE]
  shot("map.png")
  println("The picture with a pin in it takes ", round(1000 * @elapsed(K.pinned_png(kept(HOME), (100.0, 100.0))), digits=1), " ms to make")
end

@testset "the + and the − change how much the map shows" begin
  v = view()
  button(:in)
  @test block() == [WATTLE, "zoom: 16"] && v.data.zoom == 16 && K.dirty(e.buf)
  @test Fake.calls[end] == asked(HOME, 16) && shows(HOME, 16) && pinned(middle(area()))
  button(:out); button(:out)
  @test block() == [WATTLE, "zoom: 14"] && shows(HOME, 14) && length(Fake.calls) == 3
  # ⌘Z takes each change back, and the map of that zoom is kept, so nothing is asked for again
  K.undo!(e.buf); frames()
  @test block() == [WATTLE, "zoom: 15"] && shows(HOME)
  K.undo!(e.buf); K.undo!(e.buf); frames()
  @test block() == [WATTLE] && v.data.zoom == 15 && length(Fake.calls) == 3
  # The address was found once. A change of zoom doesn't ask where it is again.
  @test Fake.finds == [WATTLE]
  # At the least zoom, the − does nothing, and at the most, the + does nothing
  rewrite(WATTLE, "zoom: $(first(M.ZOOMS))")
  @test v.parts[(:button, :out)].off && !v.parts[(:button, :in)].off
  button(:out)
  @test block() == [WATTLE, "zoom: $(first(M.ZOOMS))"]
  rewrite(WATTLE, "zoom: $(last(M.ZOOMS))")
  @test v.parts[(:button, :in)].off
  button(:in)
  @test block() == [WATTLE, "zoom: $(last(M.ZOOMS))"]
  # A line that the block doesn't know stays where it is
  rewrite(WATTLE, "The back gate")
  button(:in)
  @test block() == [WATTLE, "zoom: 16", "The back gate"]
  rewrite(WATTLE)
end

@testset "Open in Maps" begin
  empty!(Fake.opened)
  button(:open)
  @test Fake.opened == ["maps://?q=8%20Wattle%20Street%2C%20Brunswick%20VIC%203056"] && block() == [WATTLE]
end

@testset "a drag moves the map" begin
  v = view()
  m = middle(area())
  caret, scrolled, n = e.buf.caret, e.scroll.offset, length(Fake.calls)
  press(m); at(m .+ (60, -20)); at(m .+ (120, -40))
  # The picture moves with the mouse, and the pin with it. Nothing is written or asked for until the mouse lets go.
  @test pinned(m .+ (120, -40)) && !pinned(m) && block() == [WATTLE] && length(Fake.calls) == n && v.at !== nothing
  shot("map-dragging.png")
  release()
  # The middle of what shows is the block's centre line, and the picture for that middle is asked for
  c = M.rounded(M.moved(HOME, 120, -40, 15))
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c)] && v.data.centre == c && v.at === nothing && v.grab === nothing
  @test Fake.calls[end] == asked(c) && length(Fake.calls) == n + 1 && shows(c)
  # The pin stays on the place, which is where the drag left it. The place isn't asked for again.
  @test pinned(m .+ (120, -40)) && !pinned(m) && K.map_address(v) == "$WATTLE, Australia" && Fake.finds == [WATTLE]
  shot("map-dragged.png")
  # The + keeps the middle
  button(:in)
  @test block() == [WATTLE, "zoom: 16", "centre: " * M.text(c)] && Fake.calls[end] == asked(c, 16)
  button(:out)
  # A drag that leaves the map and lets go over the page's text moves the map all the same. It selects no text and scrolls nothing.
  to = (200.0, 560.0)
  press(m); at(m .+ (-100, 80)); at(to)
  @test v.at !== nothing && e.buf.caret == caret && e.buf.anchor == caret
  release()
  c2 = M.rounded(M.moved(c, (to .- m)..., 15))
  @test block()[3] == "centre: " * M.text(c2) && v.grab === nothing && shows(c2)
  @test e.buf.caret == caret && e.buf.anchor == caret && e.scroll.offset == scrolled && w.focus === e
  # And so does one that leaves the map and comes back
  press(m); at(to); at((900.0, 120.0)); at(m .+ (30, 30)); release()
  c3 = M.rounded(M.moved(c2, 30, 30, 15))
  @test block()[3] == "centre: " * M.text(c3) && e.buf.caret == caret && e.buf.anchor == caret && e.scroll.offset == scrolled
  # ⌘Z takes back each drag, and then the two changes of zoom and the first drag
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c2)] && shows(c2)
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c)] && shows(c)
  key(Keys.z, Keys.cmd); key(Keys.z, Keys.cmd); key(Keys.z, Keys.cmd)
  @test block() == [WATTLE] && shows(HOME) && pinned(m) && v.data.centre === nothing
end

@testset "a click moves the pin at once, and asks for no picture" begin
  v = view()
  m = middle(area())
  p = m .+ (150, -60)
  n, f, file = length(Fake.calls), length(Fake.finds), v.shown.file
  Fake.slow[] = true   # Apple takes a while to say what the point's address is
  press(p); release(1)
  # In the next frame the pin is where the click was, and the old pin is gone
  @test pinned(p) && !pinned(m)
  # The picture that fills the window isn't made in that frame
  @test v.pinned != (v.shown.file, K.map_pin_in(v))
  # The place is the latitude and the longitude of the point that was clicked. The middle that showed is written too, so the map stays still.
  clicked = M.text(under(p, HOME))
  @test block() == [clicked, "zoom: 15", "centre: " * M.text(HOME)]
  # The picture is the one that showed before, and no picture is asked for
  @test v.shown.file == file && shows(HOME) && length(Fake.calls) == n && K.map_words(v) == ""
  # The latitude and the longitude are under the map at once. Their address is asked for in the background, and comes later.
  @test K.map_address(v) == clicked && Fake.finds[end] == clicked && length(Fake.finds) == f + 1 && v.place.found.state == :coming
  shot("map-clicked.png")
  @test until(() -> K.map_address(v) == "1 Found Street, Brunswick VIC 3056, Australia")
  Fake.slow[] = false
  @test v.shown.file == file && length(Fake.calls) == n && pinned(p) && K.map_pin(v) == M.coordinates(clicked) && K.map_middle(v) == HOME
  shot("map-moved.png")
  # ⌘Z brings the old place back, with the place in the middle. Nothing is asked for: the place and the picture are kept.
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE] && shows(HOME) && pinned(m) && !pinned(p) && length(Fake.calls) == n && length(Fake.finds) == f + 1
  # A click on the same point again asks Apple for nothing: what it said of the point is kept
  click(p)
  @test block()[1] == clicked && pinned(p) && K.map_address(v) == "1 Found Street, Brunswick VIC 3056, Australia"
  @test length(Fake.finds) == f + 1 && length(Fake.calls) == n
  key(Keys.z, Keys.cmd)
  # A block that has a centre line keeps it. A press and a release 2 px apart are still a click.
  drag(m, m .+ (90, 0))
  c = v.data.centre
  n = length(Fake.calls)
  @test c == M.rounded(M.moved(HOME, 90, 0, 15)) && pinned(m .+ (90, 0))
  press(p); at(p .+ (2, 1)); release()
  @test block() == [M.text(under(p, c)), "zoom: 15", "centre: " * M.text(c)] && pinned(p) && !pinned(m .+ (90, 0)) && length(Fake.calls) == n
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c)] && pinned(m .+ (90, 0))
  # With ⌥ held, a click shows the block's lines, as it does on any block
  s = K.block_lines(e.buf, K.MAP, 1)[1]
  w.keys = Keys.opt
  click(m)
  w.keys = Keys(0); frames()
  @test K.item(e, s + 1).content isa K.Flow && block()[1] == WATTLE
  e.buf.caret = e.buf.anchor = (1, 0); K.touch!(e); frames()
  @test K.item(e, s).content isa K.Live
end

@testset "a button puts the place back in the middle" begin
  v = view()
  m = middle(area())
  c = v.data.centre
  @test c !== nothing && pinned(m .+ (90, 0))
  # The third button is beside the − and the +
  home, less = rect(v.parts[(:button, :home)]), rect(v.parts[(:button, :out)])
  @test home !== nothing && home.left < less.left && home.top == less.top && !isempty(v.parts[(:button, :home)].tip)
  shot("map-home.png")
  button(:home)
  @test block() == [WATTLE, "zoom: 15"] && v.data.centre === nothing && shows(HOME) && pinned(m)
  @test rect(v.parts[(:button, :home)]) === nothing
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c)] && rect(v.parts[(:button, :home)]) !== nothing
  rewrite(WATTLE)
end

@testset "a place that isn't in the map has no pin" begin
  v = view()
  r = area()
  m = middle(r)
  corners = ((K.num(r.left) + 2, K.num(r.top) + 2), (K.num(r.left + r.width) - 2, K.num(r.top + r.height) - 2))
  # The place is far to the south of what the map shows
  far = (-37.8, 144.94051)
  rewrite(WATTLE, "centre: " * M.text(far))
  @test shows(far) && K.map_pin_in(v) === nothing && !reddens(corners...) && K.map_address(v) == "$WATTLE, Australia"
  # The page of HTML has the picture as it is, with no pin drawn in it
  @test occursin(M.data_uri(kept(far)), K.page_html(e))
  shot("map-no-pin.png")
  # A place 5 px under the map's foot has no pin, though the pin's head would be in the map
  under_foot = M.rounded(M.moved(HOME, 0, 145, 15))
  rewrite(WATTLE, "centre: " * M.text(under_foot))
  @test shows(under_foot) && !reddens(corners...)
  # A place 5 px over the foot has its pin
  rewrite(WATTLE, "centre: " * M.text(M.rounded(M.moved(HOME, 0, 135, 15))))
  @test pinned(m .+ (0, 135))
  # A pin near the top of the map is cut off at the map's edge: nothing is drawn outside the map's box
  rewrite(WATTLE, "centre: " * M.text(M.rounded(M.moved(HOME, 0, -130, 15))))
  @test red(colour(m .+ (0, -137))) && !reddens((m[1] - 14, K.num(r.top) - 30), (m[1] + 14, K.num(r.top) - 3))
  shot("map-pin-at-top.png")
  rewrite(WATTLE)
end

@testset "the button beside the map, and Return, make it fill the window, with its pin" begin
  v = view()
  m = middle(area())
  # A click on the map doesn't fill the window: it moves the place
  @test K.zooming(e) === nothing
  # The picture with the pin in it is made a moment after the pin last moved
  @test until(() -> v.pinned == (v.shown.file, K.map_pin_in(v)))
  # The button shows beside the map's top right corner while the mouse is over the map
  at(m); frames()
  @test corner() !== nothing
  click(middle(rect(corner())))
  z = K.zooming(e)
  @test z !== nothing && z.what[1] == :picture && K.has_image(z.what[2]) && K.subject_size(z) == (2.0wide(), 560.0)
  frames()
  # What fills the window is the picture with the pin drawn in it. The pin is in the picture's middle, where the place is.
  "Where a point of the picture, in px, is in the window"
  inwindow(p) = (z.box[1] + (2p[1] - z.at[1]) * z.zoom, z.box[2] + (2p[2] - z.at[2]) * z.zoom)
  tip = (wide() / 2, 140.0)
  head, dot = colours(inwindow(tip .+ (-7, -26)), inwindow(tip .+ (0, -26)))
  @test red(head) && dot == (255, 255, 255)
  shot("map-full.png")
  # A zoom and a drag there keep the pin on its place, and change nothing in the block
  K.zoom_by!(z, 2.5, K.view_middle(z)...); frames()
  drag(m, m .+ (80, 40))
  head, dot = colours(inwindow(tip .+ (-7, -26)), inwindow(tip .+ (0, -26)))
  @test z.zoom > 1 && red(head) && dot == (255, 255, 255) && block() == [WATTLE] && v.grab === nothing
  shot("map-full-zoomed.png")
  key(Keys.escape)
  @test K.zooming(e) === nothing && w.focus === e
  # With the caret on the map as a whole, Return makes it fill the window too
  s, t = K.block_lines(e.buf, K.MAP, 1)
  e.buf.caret = e.buf.anchor = (s - 1, 0); K.touch!(e); frames()
  key(Keys.down)
  @test K.picked(e.buf) == (s, t)
  key(Keys.enter)
  @test K.zooming(e) !== nothing
  key(Keys.escape)
  e.buf.caret = e.buf.anchor = (1, 0); K.touch!(e); frames()
  @test K.zooming(e) === nothing && block() == [WATTLE]
end

@testset "while Apple finds the place, the block is a grey box with no pin" begin
  v = view()
  r = area()
  corners = ((K.num(r.left) + 2, K.num(r.top) + 2), (K.num(r.left + r.width) - 2, K.num(r.top + r.height) - 2))
  tall, n = rect(v).height, length(Fake.calls)
  rewrite("12 Slow Street, Kew")
  @test !K.map_shows(v) && K.map_words(v) == "Finding the place…" && v.place.found.state == :coming && K.map_pin(v) === nothing
  # No picture is asked for until the place is known
  @test length(Fake.calls) == n && !reddens(corners...)
  @test rect(v).height == tall && K.map_address(v) == "12 Slow Street, Kew" && K.cursor(v.parts[:area]) == :arrow
  shot("map-finding.png")
  # A click and a drag on the grey box change nothing, but put the caret on the block as a whole
  click(middle(area()) .+ (0, 60))
  drag(middle(area()), middle(area()) .+ (70, 20))
  @test K.zooming(e) === nothing && block() == ["12 Slow Street, Kew"] && K.picked(e.buf) !== nothing
  # The line round the block would tint the pin
  e.buf.caret = e.buf.anchor = (1, 0); K.touch!(e); frames()
  # The window draws again by itself, and the map shows when the place is known
  @test until(() -> K.map_shows(v))
  @test K.map_words(v) == "" && K.map_address(v) == "12 Slow Street, Kew, Australia" && K.cursor(v.parts[:area]) == :hand && pinned(middle(r))
  # Until the picture of another zoom is there, the picture of the last zoom shows in its place, and the pin is on it
  Fake.slow[] = true
  button(:in); button(:in)   # the picture of zoom 16 is kept, and the one of zoom 17 isn't
  @test shows(HOME, 16) && v.data.zoom == 17 && K.map_words(v) == "" && v.got[1].state == :coming && pinned(middle(r))
  @test until(() -> v.shown.zoom == 17)
  Fake.slow[] = false
  @test count(==("12 Slow Street, Kew"), Fake.finds) == 1
end

@testset "a place and a picture that can't be shown" begin
  v = view()
  m = middle(area())
  rewrite("1 Nowhere Road, Atlantis")
  @test !K.map_shows(v) && K.map_words(v) == M.LOST && K.map_address(v) == "1 Nowhere Road, Atlantis"
  shot("map-lost.png")
  n, f = length(Fake.calls), length(Fake.finds)
  frames(5)
  @test length(Fake.calls) == n && length(Fake.finds) == f   # Ladder doesn't ask again
  html = K.page_html(e)
  @test !occursin("<img", html) && occursin("<a href=\"https://maps.apple.com/?q=1%20Nowhere%20Road%2C%20Atlantis\">1 Nowhere Road, Atlantis</a>", html)
  # With a centre line, the map shows though Apple doesn't know the address. It has no pin, and the words under it say why.
  rewrite("1 Nowhere Road, Atlantis", "centre: " * M.text(HOME))
  @test shows(HOME) && K.map_pin(v) === nothing && !pinned(m) && K.map_address(v) == "1 Nowhere Road, Atlantis. " * M.LOST
  shot("map-lost-with-centre.png")
  # No network when the place is asked for
  rewrite("1 Offline Road, Kew")
  @test K.map_words(v) == M.FAILED * " It tries again in a minute." && v.place.found.state == :failed
  shot("map-failed.png")
  # No network when the picture is asked for
  Fake.offline[] = true
  rewrite(WATTLE, "centre: -30.00000, 140.00000")
  @test !K.map_shows(v) && K.map_words(v) == M.FAILED * " It tries again in a minute." && v.got[1].state == :failed
  Fake.offline[] = false
  # A file that's no picture is taken away
  Fake.broken[] = true
  rewrite(WATTLE, "centre: -31.00000, 141.00000")
  @test !K.map_shows(v) && v.got[1].state == :failed && !isfile(kept((-31.0, 141.0)))
  Fake.broken[] = false
  # A latitude and a longitude need no finding. Apple is asked only for their address.
  rewrite("-37.7701, 144.9610", "zoom: far")
  @test shows((-37.7701, 144.961)) && K.map_address(v) == "1 Found Street, Brunswick VIC 3056, Australia" && pinned(m)
  @test Fake.finds[end] == "-37.7701, 144.9610" && K.map_pin(v) == (-37.7701, 144.961)
  # An empty block says what to write in it, and has no buttons
  rewrite()
  @test isempty(block()) && rect(v).height < 100px
  shot("map-empty.png")
  @test K.page_html(e) !== nothing
  rewrite("zoom: 12")
  @test rect(v).height < 100px
  rewrite(WATTLE)
  @test shows(HOME) && pinned(m)
end

@testset "a dark page has a dark map" begin
  v = view()
  K.theme!(e, :night); frames()
  @test Fake.calls[end] == asked(HOME, dark=true) && shows(HOME, dark=true) && pinned(middle(area()))
  shot("map-dark.png")
  # The page of HTML is light, so it has the light map
  @test sum(rgb(html_picture())(40, 40)) > 600
  K.theme!(e, :sepia); frames()
  @test shows(HOME)
end

@testset "the map as HTML has the pin in its picture" begin
  html = K.page_html(e)
  @test occursin("<img src=\"data:image/png;base64,iVBOR", html) && occursin("alt=\"A map of $WATTLE, Australia\" width=\"$(wide())\">", html)
  @test occursin("<p><a href=\"https://maps.apple.com/?q=8%20Wattle%20Street%2C%20Brunswick%20VIC%203056\">$WATTLE, Australia</a></p>", html)
  # The picture has two pixels to the px. The pin's point is on the place, which is in the picture's middle.
  dots = html_picture(html)
  @test size(dots) == (560, 2wide()) && red(rgb(dots)(wide() - 14, 228)) && rgb(dots)(wide(), 228) == (255, 255, 255)
  # The picture that's kept has no pin
  @test !red(rgb(pixels(kept(HOME)))(wide() - 14, 228))
end

@testset "a page that can't be changed takes no drag and no click" begin
  locked = joinpath(dir, "locked.md")
  text = "# Locked\n\n```map\n$WATTLE\n```\n\nThe end.\n"
  write(locked, text)
  chmod(locked, 0o444)
  K.open!(e, locked); frames(3)
  v = e.nodes[(:block, K.MAP, locked, 1)]
  @test e.buf.fixed && K.map_shows(v) && !K.map_moves(v) && K.cursor(v.parts[:area]) == :arrow
  m = middle(rect(v.parts[:area]))
  n, f = length(Fake.calls), length(Fake.finds)
  drag(m, m .+ (80, 30))
  click(m .+ (100, -50))
  @test v.grab === nothing && v.at === nothing && v.data.centre === nothing && v.data.place == WATTLE
  @test length(Fake.calls) == n && length(Fake.finds) == f
  @test e.buf.lines[4] == WATTLE && !K.dirty(e.buf) && read(locked, String) == text && pinned(m)
  shot("map-locked.png")
  K.open!(e, page); frames(3)
  @test shows(HOME) && K.map_moves(view())
end

@testset "a page of another width" begin
  v = view()
  n = length(Fake.calls)
  was = wide()
  K.page_width!(e, 420); frames()
  # The picture of the old width shows, and no other is asked for until the width has stayed for a moment
  @test wide() < was && length(Fake.calls) == n && v.shown.file == M.file(K.media_dir(), HOME, 15, was, 280, false) && pinned(middle(area()))
  @test until(() -> length(Fake.calls) > n)
  @test Fake.calls[end].wide == wide() && shows(HOME)
  shot("map-narrow.png")
  # A drag works there too
  m = middle(area())
  drag(m, m .+ (-50, 40))
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(M.rounded(M.moved(HOME, -50, 40, 15)))] && pinned(m .+ (-50, 40))
  shot("map-narrow-dragged.png")
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE]
  # Paper has another width again. The page prints with the picture that's kept, and asks for no other.
  n = length(Fake.calls)
  @test length(K.print_pdf(e)) > 1000 && length(Fake.calls) == n
  frames()
  @test length(Fake.calls) == n && shows(HOME)
end

@testset "a window that isn't on the screen runs no program and opens no app" begin
  v = view()
  M.HELPER[], M.FINDER[], M.OPENER[] = M.run_program, M.find_program, M.open_app
  empty!(M.jobs)
  n, f = length(Fake.calls), length(Fake.finds)
  rewrite("77 Fresh Street, Kew")
  frames(3)
  @test isempty(M.jobs) && length(Fake.calls) == n && length(Fake.finds) == f && K.map_words(v) == M.FAILED && v.place.found.state == :none
  # A place that's kept has no picture made for a new middle
  rewrite(WATTLE, "centre: -37.70000, 144.90000")
  frames(3)
  @test isempty(M.jobs) && K.map_words(v) == M.FAILED && v.got[1].state == :none
  # A place and a picture that are kept show all the same
  rewrite(WATTLE)
  @test shows(HOME) && pinned(middle(area()))
  button(:open)
  @test length(Fake.opened) == 1
  M.HELPER[], M.FINDER[], M.OPENER[] = Fake.helper, Fake.finder, Fake.opener
end
