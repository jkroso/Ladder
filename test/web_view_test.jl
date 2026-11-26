# Tests for web/view.jl: a page of HTML in a window that isn't on the screen.
# Run them with `julia -O0 --project=. test/web_view_test.jl`. Set
# `LADDER_SHOTS` to a folder, and they save a picture of the window there.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window Keys
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/testing" click! move!
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "../web/view" View
@use "../web" => Web
@use "../web/paint" => Paint
@use "../web/video" => Film
@use "../web/live" => Live

const HTML = """<!DOCTYPE html><body style="margin:20px;font:16px/20px Helvetica;background:#f4f4f4">
  <div style="background:white;border-radius:8px;border:1px solid #ddd;padding:16px">
  <h1 style="margin:0 0 10px;font-size:22px;line-height:26px">Your order has shipped</h1>
  <p style="margin:0 0 10px">Hello <b>Jake</b>, your order is on its way.</p>
  <a href="https://example.com/track" style="display:block;width:160px;line-height:36px;background:#0a66c2;color:white;text-align:center;border-radius:6px;text-decoration:none">Track your order</a>
  </div></body>"""

@testset "a page of HTML in a window" begin
  opened = String[]
  v = View(html=HTML, wide=400px, open=url -> push!(opened, url))
  w = Window(v, size=(400px, 300px))
  frame(w)
  r = rect(v)
  # The margin, the card's border and padding, the heading, the paragraph and the button, each with the room under it
  @test r.width == 400px && r.height == px(v.page.tall) && v.page.tall == 2 * (20 + 1 + 16) + 26 + 10 + 20 + 10 + 36
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "web-view.png"), w)
  # A click on the link opens it, and a click beside it opens nothing
  l = only(v.page.links)
  click!(w, (r.left + px(l.left + 5), r.top + px(l.top + 5)))
  @test opened == ["https://example.com/track"]
  click!(w, (r.left + px(l.left + l.wide + 20), r.top + px(l.top + 5)))
  @test length(opened) == 1
  # The page is laid out once, and again when its width changes
  page = v.page
  frame(w)
  @test v.page === page
  v.wide = 300px
  frame(w)
  @test v.page !== page && rect(v).width == 300px
end

@testset "a page with scripts in a window" begin
  opened = String[]
  said = String[]
  html = """<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica;background:white">
    <button id=b style="display:block;width:100px;height:30px">Add</button>
    <a id=stay href="https://example.com/stay" style="display:block;height:20px">stay</a>
    <a href="https://example.com/go" style="display:block;height:20px">go</a>
    <ul id=list style="margin:0"></ul>
    <script>
      var list = document.getElementById('list')
      document.getElementById('b').addEventListener('click', () => { list.appendChild(document.createElement('li')).textContent = 'item ' + list.children.length })
      document.getElementById('stay').addEventListener('click', e => { e.preventDefault(); console.log('stayed') })
      var go = false
      var timer = setInterval(() => { if (go) { clearInterval(timer); list.appendChild(document.createElement('li')).textContent = 'from a timer' } }, 10)
    </script></body>"""
  v = View(html=html, wide=300px, scripts=true, open=url -> push!(opened, url), say=(level, text) -> push!(said, text))
  w = Window(v, size=(300px, 300px))
  frame(w)
  r = rect(v)
  @test v.page.tall == 70 && r.height == 70px
  # A click that a script hears changes the page, and the window is as tall as the page is now
  click!(w, (r.left + 20px, r.top + 10px))
  frame(w)
  @test v.page.tall == 90 && rect(v).height == 90px
  # A link opens, unless a script said to do no more with the click
  click!(w, (r.left + 20px, r.top + 40px))
  @test isempty(opened) && said == ["stayed"]
  click!(w, (r.left + 20px, r.top + 60px))
  @test opened == ["https://example.com/go"]
  # The page's timer runs when it's due
  v.live.scripts.js["go"] = true
  sleep(0.05)
  frame(w)
  @test v.page.tall == 110
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "web-view-scripts.png"), w)
  # The scripts go on when the window is narrower, and they stop when the page is another
  live = v.live
  v.wide = 200px
  frame(w)
  @test v.live === live && v.page.wide == 200 && v.live.scripts.js["innerWidth"] == 200
  v.html = "<p>another</p>"
  frame(w)
  @test v.live !== live && !isopen(live)
end

@testset "a page in a window in dark mode" begin
  html = """<meta name="color-scheme" content="light dark"><body style="margin:0"><p style="height:10px;margin:0;background:light-dark(red, blue)"></p></body>"""
  fills(v) = [i.color for i in v.page.list.items if i isa Paint.Fill]
  v = View(html=html, wide=300px)
  w = Window(v, size=(300px, 100px))
  frame(w)
  @test fills(v) == [0xffff0000]
  # The page is laid out again when the screen goes dark, and when it's light again
  v.dark = true
  frame(w)
  @test fills(v) == [0xff1e1e1e, 0xff0000ff]
  v.dark = false
  frame(w)
  @test fills(v) == [0xffff0000]
  # A page's scripts see it too, and its scripts keep running
  s = View(html=html * "<script>var at = 0</script>", wide=300px, scripts=true, dark=true)
  sw = Window(s, size=(300px, 100px))
  frame(sw)
  live = s.live
  dark() = Live.evaluate(s.live, "matchMedia('(prefers-color-scheme: dark)').matches")
  @test dark() == true && fills(s) == [0xff1e1e1e, 0xff0000ff]
  s.dark = false
  frame(sw)
  @test dark() == false && fills(s) == [0xffff0000] && s.live === live
end

@testset "a page that moves in a window" begin
  html = """<!DOCTYPE html><style>@keyframes go { from { margin-left: 0 } to { margin-left: 100px } } p { margin: 0; animation: go 0.3s linear forwards }</style>
    <body style="margin:0;background:white"><p>x</p></body>"""
  v = View(html=html, wide=300px)
  w = Window(v, size=(300px, 100px))
  frame(w)
  left() = v.page.words[1].edges[1]
  # The page is laid out again as time passes, for as long as its animation runs
  first = v.page
  @test Web.moving(first) && left() < 50
  sleep(0.15)
  frame(w)
  @test v.page !== first && 30 < left() < 100
  sleep(0.3)
  frame(w)
  @test left() == 100 && !Web.moving(v.page)
  page = v.page
  frame(w)
  @test v.page === page
  # Another width doesn't start the animation again
  v.wide = 200px
  frame(w)
  @test left() == 100 && v.page.wide == 200
  # With `moves=false`, the page is drawn once, as it comes to rest
  still = View(html=html, wide=300px, moves=false)
  frame(Window(still, size=(300px, 100px)))
  @test still.page.words[1].edges[1] == 100 && !Web.moving(still.page)
  # A click on a video that shows its buttons starts it. The test's video is 64 by 48, and 2 seconds long.
  clip = read(joinpath(@__DIR__, "web_clip.mp4"))
  film = View(html="""<!DOCTYPE html><body style="margin:0"><video src="clip.mp4" controls style="display:block"></video></body>""", wide=300px, load=src -> src == "clip.mp4" ? clip : nothing)
  fw = Window(film, size=(300px, 100px))
  frame(fw)
  arrows() = count(i -> i isa Paint.Widget, film.page.list.items)
  @test film.page.tall == 48 && !Web.moving(film.page) && arrows() == 1
  r = rect(film)
  click!(fw, (r.left + 20px, r.top + 20px))
  frame(fw)
  @test Web.moving(film.page) && arrows() == 0
  click!(fw, (r.left + 20px, r.top + 20px))
  frame(fw)
  @test !Web.moving(film.page) && arrows() == 1
  # A picture that moves, like a GIF, shows its next picture when that's due. The test's GIF changes each half second.
  gif = read(joinpath(@__DIR__, "web_moving.gif"))
  flick = View(html="""<!DOCTYPE html><body style="margin:0"><img src="m.gif"></body>""", wide=300px, load=src -> src == "m.gif" ? gif : nothing)
  gw = Window(flick, size=(300px, 100px))
  frame(gw)
  @test Web.moving(flick.page) && flick.page.next == 0.5 && count(x -> x isa Film.Reel, flick.page.held) == 1
  # The first frame of a window takes long, so the test goes on from a moment that's well before the GIF's next change
  now() = time() - flick.showing.since
  frame(gw)
  flick.page.next - now() < 0.2 && (sleep(0.25); frame(gw))
  shown = flick.page
  frame(gw)
  @test flick.page === shown   # nothing has changed yet, so the page isn't laid out again
  sleep(0.55)
  frame(gw)
  @test flick.page !== shown && flick.page.next == shown.next + 0.5 && flick.page.at >= shown.next
end
