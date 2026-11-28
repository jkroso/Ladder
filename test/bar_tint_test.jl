# Tests for the top bar over a web page, which takes the page's colour as a
# browser's bar does: see "the top bar over a web page" in top_bar.jl, and
# `edge_colour` in web/paint.jl. Run them with
# `julia -O0 --project=. test/bar_tint_test.jl`. They write HTML files into a
# temporary folder, and show them in a window that isn't on the screen. Set
# `LADDER_SHOTS` to a folder, and they save pictures of the window there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use GeometryBasics: Vec2
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use "./drive" drive
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")   # agent mode keeps the card's width there
file(name, text) = (path = joinpath(dir, name); write(path, text); path)

# A dark header over a light page, as many sites have
const site = file("site.html", """<!DOCTYPE html><title>A site</title>
  <body style="margin:0;background:rgb(251,250,247);font:16px/20px Helvetica">
  <header style="height:80px;background:rgb(20,40,70);color:white">A dark header</header>
  <div style="height:3000px">The article</div></body>""")
# A page that says its colour, over a gradient that has no one colour
const said = file("said.html", """<!DOCTYPE html><title>Said</title><meta name="theme-color" content="#7a1f3d">
  <body style="margin:0"><div style="height:80px;background:linear-gradient(to right, red, blue)"></div></body>""")
# A gradient along the top, and nothing said
const mixed = file("mixed.html", """<!DOCTYPE html><title>Mixed</title>
  <body style="margin:0"><div style="height:80px;background:linear-gradient(to right, red, blue)"></div></body>""")
# A page with no colour of its own is white, as a browser shows it
const plain = file("plain.html", "<title>Plain</title><body style='margin:0'><p>Words</p></body>")
const notes = file("notes.md", "# Notes\n\nSome words.\n")

const e = K.build_editor(site)
const w = Window(e, size=(1000px, 800px))
const (; frames, shot) = drive(w, frames=3)
e.panel = false   # the sidebar is closed, with no slide
frames()

browser() = e.nodes[(:html, e.buf.path)].browser
"Draw frames until the page has had its last layout: a slow page rests after each layout"
settle() = (b = browser(); while time() < b.rest; sleep(0.02); frames(1) end; frames())
"The colour of the window's picture at a place in the window, as red, green and blue"
colour_at((x, y)) = begin
  path = joinpath(dir, "window.png")
  save_png(path, w)
  ps = pixels(path)
  k = size(ps, 2) / K.num(K.window_size(e)[1])   # the picture's pixels to a px of the window
  p = ps[round(Int, y * k), round(Int, x * k)]
  (Int(p >> 16 & 0xff), Int(p >> 8 & 0xff), Int(p & 0xff))
end
rgb(c) = round.(Int, 255 .* Float64.((c.r, c.g, c.b)))
near(a, b) = all(abs.(a .- b) .< 6)
# A place in the bar with no button or name on it: over the buttons, right of the middle
const BAR_SPOT = (680, 3)

@testset "the colour along the top of a page" begin
  Paint = K.Web.Paint
  wide = 800.0
  list(items, background=0x00000000) = (l = Paint.List(Paint.Item[items...], Paint.Link[], Paint.Words[], wide, 600.0, background, s -> nothing, "",
                                                         nothing, nothing, Paint.Clip[], Paint.Order[], nothing, 0, IdDict{Paint.Box,Tuple{Float64,Float64}}(),
                                                         IdDict{Paint.Box,Tuple{Float64,Float64,Int}}(), Paint.SAME, 0, "",
                                                         Paint.Place[], Vector{Vector{Paint.Item}}[], Ref{Any}(nothing), NTuple{4,Float64}[]); l)
  fill(x, y, w, h, c) = Paint.Fill(x, y, w, h, Paint.SQUARE, c)
  # Nothing drawn: what's under the page, or the page's own background
  @test Paint.edge_colour(list(()), 0) == 0xffffffff
  @test Paint.edge_colour(list((), 0xff102030), 0) == 0xff102030
  # A header across the page, and the page under it further down
  head = fill(0, 0, wide, 80, 0xff142846)
  @test Paint.edge_colour(list((head,)), 0) == 0xff142846
  @test Paint.edge_colour(list((head,)), 100) == 0xffffffff
  # A column in the middle that's narrower than the page leaves the colour at the sides
  @test Paint.edge_colour(list((fill(300, 0, 200, 80, 0xff000000),)), 0) == 0xffffffff
  # A colour that's half see-through is mixed with what's under it
  @test Paint.edge_colour(list((fill(0, 0, wide, 80, 0x80000000),)), 0) == 0xff7f7f7f
  # What's cut off doesn't count, and nor does what's turned. What's only moved does.
  @test Paint.edge_colour(list((Paint.Clip(0, 200, wide, 100, Paint.SQUARE), head, Paint.Unclip())), 0) == 0xffffffff
  @test Paint.edge_colour(list((Paint.Move((0.0, 1.0, -1.0, 0.0, 0.0, 0.0)), head, Paint.Unmove())), 0) == 0xffffffff
  @test Paint.edge_colour(list((Paint.Move((1.0, 0.0, 0.0, 1.0, 0.0, 100.0)), head, Paint.Unmove())), 120) == 0xff142846
  # A piece that's half see-through
  @test Paint.edge_colour(list((Paint.Layer(0.5, :normal, Paint.Effect[], nothing), fill(0, 0, wide, 80, 0xff000000), Paint.Unlayer())), 0) == 0xff808080
end

@testset "the bar takes the colour of the page's top" begin
  @test K.html_shown(e)
  tint = K.bar_tint(e)
  @test tint !== nothing && rgb(tint) == (20, 40, 70)
  # The window's ink doesn't show on a dark colour, so the bar has the dark theme's
  inks = K.bar_inks(e)
  @test all(p -> p === K.TINT_COLOURS, inks)
  @test K.TINT_COLOURS.ink == K.NIGHT.ink && K.TINT_COLOURS.bg == tint
  @test near(colour_at(BAR_SPOT), (20, 40, 70))
  # The bar's part and the page meet with no line between them
  @test near(colour_at((680, K.num(K.TOPBAR_H) - 0.25)), (20, 40, 70))
  # The window's own colours are back after the bar: the page's colours are in use
  @test K.colours_over[] === nothing && K.colours.bg != K.TINT_COLOURS.bg
  shot("bar-tint-dark")
end

@testset "the colour changes as the page scrolls" begin
  K.Browsers.scroll!(browser(), 400)
  settle()
  @test rgb(K.bar_tint(e)) == (251, 250, 247)
  # The window's own ink shows on a light colour
  @test K.TINT_COLOURS.ink == K.colours.ink
  @test near(colour_at(BAR_SPOT), (251, 250, 247))
  shot("bar-tint-light")
  K.Browsers.scroll!(browser(), 0)
  settle()
  @test rgb(K.bar_tint(e)) == (20, 40, 70)
end

@testset "over the sidebar the bar keeps the window's colours" begin
  e.panel = true
  frames()
  inks = K.bar_inks(e)
  @test inks[1] === nothing && inks[2] === K.TINT_COLOURS && inks[3] === K.TINT_COLOURS
  side = K.num(K.side_w(e))
  @test near(colour_at((side / 2, 3)), rgb(K.colours.panel))
  @test near(colour_at((side + 300, 3)), (20, 40, 70))
  shot("bar-tint-sidebar")
  e.panel = false
  frames()
end

@testset "a page's theme-color" begin
  K.open!(e, said)
  frames()
  settle()
  @test rgb(K.bar_tint(e)) == (0x7a, 0x1f, 0x3d)
  @test near(colour_at(BAR_SPOT), (0x7a, 0x1f, 0x3d))
end

@testset "a page with no one colour at its top leaves the bar as it was" begin
  K.open!(e, mixed)
  frames()
  settle()
  @test K.bar_tint(e) === nothing && K.bar_inks(e) == (nothing, nothing, nothing)
  @test near(colour_at(BAR_SPOT), rgb(K.colours.bg))
  # A page with no colour of its own is white, as a browser shows it
  K.open!(e, plain)
  frames()
  settle()
  @test rgb(K.bar_tint(e)) == (255, 255, 255)
end

@testset "only a page of HTML gives the bar its colour" begin
  K.open!(e, site)
  frames()
  settle()
  @test K.bar_tint(e) !== nothing
  # ⌘E shows the file's text, and the bar has the window's colours
  was = w.keys
  w.keys |= Keys.cmd
  onkey(w, KeyPress{Keys.e}(0, w))
  onkey(w, KeyRelease{Keys.e}(0, w))
  w.keys = was
  frames()
  @test e.buf.view == :text && K.bar_tint(e) === nothing
  @test near(colour_at(BAR_SPOT), rgb(K.colours.bg))
  K.open!(e, notes)
  frames()
  @test K.bar_tint(e) === nothing && K.bar_inks(e) == (nothing, nothing, nothing)
end

@testset "a page of HTML has no button that opens it in a web browser" begin
  K.open!(e, site)
  frames()
  @test K.html_page(e.buf) && K.outside_button(e) == ()
end

@testset "the path over the file's name has the bar's colours" begin
  K.open!(e, site)
  frames()
  K.level!(e, 4)   # its page: an earlier test left it at its text
  frames()
  settle()
  r = rect(e.nodes[:title])
  x, y = K.num(r.left + r.width / 2), K.num(r.top + r.height / 2)
  w.mouse = typeof(w.mouse)(px(x), px(y))
  onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w))
  frames(1)
  sleep(K.TT_WAIT + 0.05)
  frames()
  @test any(p -> p.key == :title_trail, popups(w))
  path = rect(K.state_of(e, K.TitlePathState).trail)
  @test near(colour_at((K.num(path.left) + 4, K.num(path.top + path.height / 2))), (20, 40, 70))
  shot("bar-tint-path")
  # Over a page with no colour of its own the path has the window's colours, as before
  K.open!(e, notes)
  frames()
  sleep(K.TT_WAIT + 0.05)
  frames()
  path = rect(K.state_of(e, K.TitlePathState).trail)
  any(p -> p.key == :title_trail, popups(w)) && @test near(colour_at((K.num(path.left) + 4, K.num(path.top + path.height / 2))), rgb(K.colours.bg))
end

@testset "in agent mode the top of the page's card has the page's colour" begin
  K.open!(e, site)
  frames()
  K.level!(e, 4)
  frames()
  settle()
  K.agent_mode!(e)
  frames()
  settle()
  @test K.agent_shows(e) && rgb(K.bar_tint(e)) == (20, 40, 70)
  # The two ends of the bar lie over the dark panes, and its middle over the card
  inks = K.bar_inks(e)
  @test inks[1] === K.PANE_COLOURS && inks[2] === K.TINT_COLOURS && inks[3] === K.PANE_COLOURS
  left, wide = K.page_card_span(e)
  @test near(colour_at((K.num(left + wide) - 30, K.num(K.TOPBAR_H) - 3)), (20, 40, 70))
  shot("bar-tint-agent")
  K.agent_mode!(e)
  frames()
  @test !K.agent_shows(e)
end
