# Tests for an HTML file, which shows as the page that its HTML makes: see
# "an HTML file as its page" in main.jl. Run them with
# `julia -O0 --project=. test/html_file_test.jl`. They write an HTML file into
# a temporary folder, and show it in a window that isn't on the screen. Set
# `LADDER_SHOTS` to a folder, and they save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse onscroll
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const site = joinpath(dir, "site.html")
const other = joinpath(dir, "other.html")
const notes = joinpath(dir, "notes.md")
write(joinpath(dir, "look.css"), "h1 { color: rgb(0, 90, 160) }")
write(site, """<!DOCTYPE html><title>A site</title><link rel=stylesheet href="look.css">
  <body style="margin:0;font:16px/20px Helvetica"><h1 id=top style="margin:0;height:60px">A page of HTML</h1>
  <a href="other.html" style="display:block;height:40px">Another page</a>
  <div style="height:3000px"></div><script>document.title = 'A site, with scripts'</script></body>""")
write(other, "<title>Other</title><body style='margin:0'><p style='margin:0'>The other page</p></body>")
write(notes, "# Notes\n\nSome words.\n")

const e = K.build_editor(site)
const w = Window(e, size=(1000px, 800px))
const (; frames, at, press, release, click, shot) = drive(w, frames=3)
frames()

"Press and let go of the key `k`, with the keys `held` down meanwhile"
key(k, held=nothing) = begin
  was = w.keys
  held === nothing || (w.keys |= held)
  onkey(w, KeyPress{k}(0, w))
  onkey(w, KeyRelease{k}(0, w))
  w.keys = was
  frames()
end
"Press ⌘E"
other_level() = key(Keys.e, Keys.cmd)
"The HTMLPage of the file that shows, and its Browser"
part() = e.nodes[(:html, e.buf.path)]
browser() = part().browser
live(code) = K.Browsers.Live.evaluate(browser().view.live, code)
"Draw frames until the page has had its last layout: a slow page rests after each layout, and shows the last one meanwhile"
settle() = (b = browser(); while time() < b.rest; sleep(0.02); frames(1) end; frames())
"Where a point of the page is in the window"
spot(x, y) = (r = rect(browser()); (K.num(r.left) + x, K.num(r.top) + y - K.Browsers.scrolled(browser())))

@testset "an HTML file opens as its page" begin
  b = browser()
  @test e.buf.view == :file && K.html_shown(e) && K.readonly(e.buf)
  @test b.title == "A site" && b.shown == "file://" * site && !b.failed && !K.Browsers.loading(b)
  @test live("document.title") == "A site, with scripts"
  # Its sheet beside it came, and its scripts ran
  @test live("getComputedStyle(document.querySelector('h1')).color") == "rgb(0, 90, 160)"
  # It has four levels, and shows at the highest: the ladder
  @test K.levels(e) == (K.FILE_LEVELS..., "the page that the HTML makes") && K.level(e) == 4
  @test haskey(e.nodes, :mode) && K.level_picture(e.nodes[:mode]).name == "Rich text"
  # It covers the page's whole space, as a browser's window would, and the mouse and the keys reach it
  r, (wide, high) = rect(b), K.page_room(e)
  @test r.width == wide && r.height == high && b.active
  shot("html-file.png")
end

@testset "the page is in dark mode when the Mac is" begin
  # WEB_DARK says what the Mac's appearance is. The page and its scripts follow it, and the scripts keep running.
  was, live_now = K.WEB_DARK[], browser().view.live
  K.WEB_DARK[] = () -> true
  frames()
  @test browser().dark && live("matchMedia('(prefers-color-scheme: dark)').matches") == true
  K.WEB_DARK[] = () -> false
  frames()
  @test !browser().dark && live("matchMedia('(prefers-color-scheme: dark)').matches") == false && browser().view.live === live_now
  K.WEB_DARK[] = was
end

@testset "the page is yours to use" begin
  b = browser()
  # The wheel scrolls the page
  at(middle(rect(b)))
  onscroll(w, Vec2{px}(0px, -3px), true)
  frames()
  @test K.Browsers.scrolled(b) > 0
  K.Browsers.scroll!(b, 0)
  frames()
  # A click gives it the keyboard, and then the arrows scroll it
  click(spot(400, 200))
  @test w.focus === b
  key(Keys.down)
  @test K.Browsers.scrolled(b) > 0
  K.Browsers.scroll!(b, 0)
  frames()
end

@testset "⌘E shows the file's text, and shows its page again" begin
  # It works while the page has the keyboard
  @test w.focus === browser()
  other_level()
  @test e.buf.view == :text && K.level(e) == 3 && !K.html_shown(e)
  @test e.buf.lines[1] == "<!DOCTYPE html><title>A site</title><link rel=stylesheet href=\"look.css\">"
  shot("html-file-text.png")
  other_level()
  @test e.buf.view == :file && K.level(e) == 4 && browser().title == "A site"
  # The slider's lower levels are there too
  K.level!(e, 2)
  frames()
  @test e.buf.view == :hex
  K.level!(e, 4)
  frames()
  @test e.buf.view == :file
end

@testset "a change to the file shows" begin
  b = browser()
  sleep(0.1)   # so the file's time changes
  write(site, "<title>Changed</title><body style='margin:0'><h1 style='margin:0'>Changed</h1></body>")
  frames()
  sleep(0.1)
  frames()
  @test b.title == "Changed" && live("document.querySelector('h1').textContent") == "Changed"
end

@testset "a link leads to another page" begin
  sleep(0.1)
  write(site, """<title>Back again</title><body style="margin:0"><a href="other.html" style="display:block;height:40px">Another page</a></body>""")
  frames()
  @test browser().title == "Back again"
  settle()
  click(spot(20, 20))
  frames()
  @test browser().title == "Other" && browser().shown == "file://" * other
end

@testset "another file ends the page" begin
  K.open!(e, notes)
  frames()
  @test e.buf.view == :markdown && !haskey(e.nodes, (:html, site))
  # A file of Markdown has no page of HTML
  @test K.levels(e) == K.PAGE_LEVELS
  K.open!(e, site)
  frames()
  @test K.html_shown(e) && browser().shown == "file://" * site
end
