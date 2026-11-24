# Tests for the `web` block of main.jl: a page of the web in a document. Run
# them with `julia -O0 --project=. test/web_block_test.jl`. They draw in a
# window that isn't on the screen, and they ask the web for nothing: a
# function of the test stands in for `curl`. Set `LADDER_SHOTS` to a folder,
# and they save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse onscroll Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect onpinch
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const SITE = Dict(
  "https://example.com/" => ("text/html", """<!DOCTYPE html><title>Example</title><link rel=stylesheet href="look.css">
    <body style="margin:0;font:16px/20px Helvetica"><h1 style="margin:0;height:60px">An example</h1>
    <a id=more href="/more" style="display:block;height:40px">More</a>
    <form action="/find" style="margin:0"><input id=q name=q style="width:200px;margin:0"></form>
    <div style="height:2000px"></div><script>document.title = 'Example, with scripts'</script></body>"""),
  "https://example.com/look.css" => ("text/css", "h1 { color: rgb(0, 90, 160) }"),
  "https://example.com/more" => ("text/html", "<title>More</title><body style='margin:0'><p style='margin:0;height:50px'>More of it</p></body>"),
  "https://example.com/find?q=wood" => ("text/html", "<title>Found</title><p>Found wood</p>"),
  "https://julialang.org/" => ("text/html", "<title>Julia</title><p>The Julia language</p>"))
const asked = String[]
# What stands in for `curl`: it writes the file that the site has at the address, and says where it is and what kind it is
K.WEB_GETTER[] = (address, file, about) -> begin
  push!(asked, address)
  if haskey(SITE, address)
    write(file, SITE[address][2])
    write(about, "$address\n$(SITE[address][1])\n\n")
  end
  () -> true
end

const dir = mktempdir()
const page = joinpath(dir, "links.md")
write(joinpath(dir, "beside.html"), "<title>Beside</title><body style='margin:0'><p style='margin:0;height:30px'>A file beside the document</p></body>")
write(page, """
# Pages of the web

```web
https://example.com
```

Some words.

```web
<h2 style="margin:0;height:40px">Written here</h2>
<p id=out style="margin:0;height:20px">no script ran</p>
<script>document.getElementById('out').textContent = 'a script ran'</script>
```

```web
beside.html
```

```web
```

```web
<body style="margin:0"><a id=away href="https://julialang.org/" style="display:block;height:30px">Away</a></body>
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()
const v = e.nodes[(:block, K.WEBVIEW, page, 1)]
const b = v.browser
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
"Press and let go of the key `k`, with the keys `held` down meanwhile"
key(k, held=nothing) = begin
  was = w.keys
  held === nothing || (w.keys |= held)
  onkey(w, KeyPress{k}(0, w))
  onkey(w, KeyRelease{k}(0, w))
  w.keys = was
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
button(name) = click(middle(rect(v.parts[(:button, name)])))
"Click the button beside the top right corner of the first block, which shows while the mouse is over the block"
fill_button() = (at(middle(rect(b))); click(middle(rect(K.fills(e)[objectid(v)].button))))
"Where a point of the page of the web is in the window"
spot(x, y) = (r = rect(b); (K.num(r.left) + x, K.num(r.top) + y - K.Browsers.scrolled(b)))
live(code) = K.Browsers.Live.evaluate(b.view.live, code)
"The lines of the `n`th web block of the document"
block_text(n) = (span = K.block_lines(e.buf, K.WEBVIEW, n); span === nothing ? nothing : e.buf.lines[span[1]+1:span[2]-1])

@testset "the block shows the page" begin
  @test b.shown == "https://example.com/" && !b.failed && !K.Browsers.loading(b)
  @test asked[1:2] == ["https://example.com/", "https://example.com/look.css"]
  # The page's scripts ran, and its sheet came
  @test live("document.title") == "Example, with scripts" && live("getComputedStyle(document.querySelector('h1')).color") == "rgb(0, 90, 160)"
  # In the document it's as wide as the text, and no taller than `WEB_HIGH`
  r = rect(b)
  @test r.width == e.width - 2px && r.height == K.WEB_HIGH && b.active
  @test any(en -> en.title == "Web page", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Web Page", K.INSERTS)
  @test !K.dirty(e.buf)
  # A page that the block holds shows, as tall as it is with the margin that a page has, and its scripts run
  held = e.nodes[(:block, K.WEBVIEW, page, 2)].browser
  @test rect(held).height == 76px && K.Browsers.Live.evaluate(held.view.live, "document.getElementById('out').textContent") == "a script ran"
  # A file beside the document is a page too
  beside = e.nodes[(:block, K.WEBVIEW, page, 3)].browser
  @test beside.title == "Beside" && beside.shown == "file://" * joinpath(dir, "beside.html") && rect(beside).height == K.WEB_LEAST
  # A block with no address has no page
  @test e.nodes[(:block, K.WEBVIEW, page, 4)].browser.view.page === nothing
  shot("web-block.png")
end

@testset "in the document the page is yours to use where it is" begin
  # The wheel over it scrolls the document, and not the page of the web
  at(middle(rect(b)))
  onscroll(w, Vec2{px}(0px, -2px), true)
  frames()
  @test K.Browsers.scrolled(b) == 0 && e.scroll.offset > 0px
  e.scroll.offset = 0px
  frames()
  live("window.clicks = 0; window.dragged = 0; window.wheels = []; addEventListener('click', () => clicks++);" *
       "addEventListener('mousemove', ev => { if (ev.buttons) dragged++ });" *
       "addEventListener('wheel', ev => wheels.push([ev.deltaY, ev.ctrlKey, ev.metaKey]))")
  # A click is the page's, and the block stays in the document. The page has the keyboard after it.
  click(spot(20, 30))
  @test live("clicks") == 1 && !v.full && w.focus === b
  # A drag reaches the page's scripts, as a drag turns a model that a script draws
  press(spot(20, 30))
  at(spot(60, 40))
  at(spot(90, 45))
  release()
  @test live("dragged") >= 2 && live("clicks") == 1 && !v.full
  # With ⌘ held the wheel is the page's: its scripts hear it, and it scrolls the page and not the document
  w.keys |= Keys.cmd
  onscroll(w, Vec2{px}(0px, -2px), true)
  w.keys ⊻= Keys.cmd
  frames()
  @test K.Browsers.scrolled(b) == 60 && e.scroll.offset == 0px && live("wheels.length") == 1 && live("wheels[0][2]") == true
  K.Browsers.scroll!(b, 0.0)
  # A pinch reaches the scripts as a browser sends it: as the wheel with Ctrl held
  onpinch(w, 1.1)
  frames()
  @test live("wheels.length") == 2 && live("wheels[1][1]") == true && isapprox(live("wheels[1][0]"), -100log(1.1), atol=0.01)
  @test !v.full && e.scroll.offset == 0px
  # Esc gives the keyboard back to the document
  key(Keys.escape)
  @test w.focus === e && !v.full
  # A click with ⌥ held is the document's, which shows the block's lines, and the page doesn't hear it
  w.keys |= Keys.opt
  click(spot(20, 30))
  w.keys ⊻= Keys.opt
  @test live("clicks") == 1 && w.focus === e && !v.full && e.buf.caret[1] == K.block_lines(e.buf, K.WEBVIEW, 1)[1] + 1
  e.buf.caret = e.buf.anchor = (length(e.buf.lines), 0)
  frames()
  # A click with ⌘ held opens the page in the browser
  opened = String[]
  old = K.BROWSER[]
  K.BROWSER[] = url -> push!(opened, url)
  was = w.keys
  w.keys |= Keys.cmd
  click(middle(rect(b)))
  w.keys = was
  @test opened == ["https://example.com/"] && !v.full
  K.BROWSER[] = old
end

@testset "its button makes it fill the window, and the page is yours to use there too" begin
  fill_button()
  @test v.full && b.shown == "https://example.com/" && b.active && w.focus === b
  r = rect(b)
  @test r.left == 0px && r.width == 1000px && r.top == K.TOPBAR_H + 38px && r.height == 900px - K.TOPBAR_H - 38px
  @test K.web_input(v).text == "https://example.com/"
  shot("web-block-full.png")
  # The wheel scrolls the page of the web now
  at(middle(r))
  onscroll(w, Vec2{px}(0px, -3px), true)
  frames()
  @test K.Browsers.scrolled(b) == 90 && live("scrollY") == 90
  key(Keys.home)
  @test K.Browsers.scrolled(b) == 0
  @test !K.dirty(e.buf)
  # A click follows a link, and the field shows where the page is. The block's line says it too.
  click(spot(20, 80))
  @test b.shown == "https://example.com/more" && b.title == "More" && K.web_input(v).text == "https://example.com/more"
  @test block_text(1) == ["https://example.com/more"] && K.dirty(e.buf)
  # Back, forward, and the keys for them. The block's line goes with them, and the page isn't got again for it.
  n = length(asked)
  button(:back)
  @test b.shown == "https://example.com/" && block_text(1) == ["https://example.com/"]
  button(:forward)
  @test b.shown == "https://example.com/more" && block_text(1) == ["https://example.com/more"]
  key(Keys.left_bracket, Keys.cmd)
  @test b.shown == "https://example.com/" && block_text(1) == ["https://example.com/"] && K.Browsers.can_forward(b)
  @test length(asked) == n
  # Typing in a field of the page, and Return sends its form
  click(spot(30, 112))
  @test K.Browsers.field(b) !== nothing
  typed("wood")
  key(Keys.enter)
  @test b.shown == "https://example.com/find?q=wood" && b.title == "Found" && block_text(1) == ["https://example.com/find?q=wood"]
end

@testset "another address, and back to the document" begin
  # ⌘L gives the keyboard to the field, with its text selected. What's typed takes its place.
  key(Keys.l, Keys.cmd)
  @test w.focus === K.web_input(v)
  typed("julialang.org")
  @test b.shown == "https://example.com/find?q=wood"
  key(Keys.enter)
  @test b.shown == "https://julialang.org/" && b.title == "Julia" && w.focus === b
  # The page is asked for again
  n = count(==("https://julialang.org/"), asked)
  key(Keys.r, Keys.cmd)
  @test count(==("https://julialang.org/"), asked) == n + 1
  # Esc leaves the field first, and then the block goes back into the document
  key(Keys.l, Keys.cmd)
  key(Keys.escape)
  @test v.full && w.focus === b
  key(Keys.escape)
  @test !v.full && w.focus === e
  # The block's line is the page that shows
  @test block_text(1) == ["https://julialang.org/"] && b.shown == "https://julialang.org/"
  # The button of the bar does the same
  fill_button()
  @test v.full
  button(:full)
  @test !v.full
end

@testset "the lines of a page that the block holds" begin
  v5 = e.nodes[(:block, K.WEBVIEW, page, 5)]
  b5 = v5.browser
  written = block_text(5)
  @test !K.Browsers.can_back(b5)
  # In the document, a link out of the page that the block holds goes to its page there, and puts its address in the
  # block, in place of the HTML
  r = rect(b5)
  # The document scrolls to it, if it's under the bottom of the window
  r.top + 30px > 900px && (e.scroll.offset += r.top - 400px; frames(); r = rect(b5))
  click((K.num(r.left) + 10, K.num(r.top) + 15))
  @test !v5.full && b5.shown == "https://julialang.org/" && block_text(5) == ["https://julialang.org/"]
  K.full!(v5, true)
  frames()
  # ⌘E shows the lines of the block: the address of the page that shows
  key(Keys.e, Keys.cmd)
  @test e.plain && !v5.full && e.buf.lines[e.buf.caret[1]] == "https://julialang.org/"
  key(Keys.e, Keys.cmd)
  @test v5.full && !e.plain
  # Back goes to the page that the block held, and puts its HTML back
  K.act!(v5, :back, w)
  frames()
  @test block_text(5) == written && K.Browsers.can_forward(b5) && startswith(b5.shown, "file://")
  K.act!(v5, :forward, w)
  frames()
  @test block_text(5) == ["https://julialang.org/"] && b5.shown == "https://julialang.org/"
  # ⌘Z in the document takes the line back, and the view shows the page that the block holds again
  K.undo!(e.buf)
  frames()
  @test block_text(5) == written && b5.html == join(written, "\n") && startswith(b5.shown, "file://")
  K.full!(v5, false)
  frames()
end

@testset "the block as HTML, and an email" begin
  @test K.web_html(e, v) == "<p><a href=\"https://julialang.org/\">https://julialang.org/</a></p>"
  @test startswith(K.web_html(e, e.nodes[(:block, K.WEBVIEW, page, 2)]), "<iframe srcdoc=\"<h2 style=&quot;margin:0;height:40px&quot;>Written here</h2>")
  @test K.web_html(e, e.nodes[(:block, K.WEBVIEW, page, 4)]) === nothing
  # A page of an email asks the web for nothing
  mail = joinpath(dir, "note.eml")
  write(mail, "From: a@example.com\r\nTo: b@example.com\r\nSubject: A page\r\nContent-Type: text/plain\r\n\r\n```web\r\nhttps://julialang.org\r\n```\r\n")
  e2 = K.build_editor(mail)
  w2 = Window(e2, size=(800px, 600px))
  n = length(asked)
  foreach(_ -> frame(w2), 1:3)
  @test length(asked) == n
  close(w2)
end

close(w)
