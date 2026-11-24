# Tests for a page of the web in a `view` block of main.jl. Run
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

```view
https://example.com
```

Some words.

```view
<h2 style="margin:0;height:40px">Written here</h2>
<p id=out style="margin:0;height:20px">no script ran</p>
<script>document.getElementById('out').textContent = 'a script ran'</script>
```

```web
beside.html
```

```view
```

```view
<body style="margin:0"><a id=away href="https://julialang.org/" style="display:block;height:30px">Away</a></body>
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()
const v = e.nodes[(:block, K.VIEW_BLOCK, page, 1)]
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
"The button beside the top right corner of the first block, which shows while the mouse is over the block"
go_button() = (at(middle(rect(b))); K.fills(e)[objectid(v)].button)
"Where a point of the page of the web is in the window"
spot(x, y) = (r = rect(b); (K.num(r.left) + x, K.num(r.top) + y - K.Browsers.scrolled(b)))
live(code) = K.Browsers.Live.evaluate(b.view.live, code)
"The lines of the `n`th `view` block of the document"
block_text(n) = (span = K.block_lines(e.buf, K.VIEW_BLOCK, n); span === nothing ? nothing : e.buf.lines[span[1]+1:span[2]-1])

@testset "the block shows the page" begin
  @test b.shown == "https://example.com/" && !b.failed && !K.Browsers.loading(b)
  @test asked[1:2] == ["https://example.com/", "https://example.com/look.css"]
  # The page's scripts ran, and its sheet came
  @test live("document.title") == "Example, with scripts" && live("getComputedStyle(document.querySelector('h1')).color") == "rgb(0, 90, 160)"
  # In the document it's as wide as the text, and no taller than `WEB_HIGH`
  r = rect(b)
  @test r.width == e.width - 2px && r.height == K.WEB_HIGH && b.active
  @test count(en -> en.title == "View", K.outline(e.buf)) == 5
  @test any(x -> x isa Tuple && x[1] == "View", K.INSERTS) && !any(x -> x isa Tuple && x[1] == "Web Page", K.INSERTS)
  @test !K.dirty(e.buf)
  # A page that the block holds shows, as tall as it is with the margin that a page has, and its scripts run
  held = e.nodes[(:block, K.VIEW_BLOCK, page, 2)].browser
  @test rect(held).height == 76px && K.Browsers.Live.evaluate(held.view.live, "document.getElementById('out').textContent") == "a script ran"
  # A file beside the document is a page too. A block in the language `web`, the old name, is a view.
  beside = e.nodes[(:block, K.WEBVIEW, page, 1)]
  @test beside isa K.ViewBlock && beside.lang == K.WEBVIEW && beside.browser.title == "Beside"
  @test beside.browser.shown == "file://" * joinpath(dir, "beside.html") && rect(beside.browser).height == K.WEB_LEAST
  # A block with no address has no page
  @test e.nodes[(:block, K.VIEW_BLOCK, page, 3)].browser === nothing
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
  @test live("clicks") == 1 && w.focus === b && e.buf.path == page
  # A drag reaches the page's scripts, as a drag turns a model that a script draws
  press(spot(20, 30))
  at(spot(60, 40))
  at(spot(90, 45))
  release()
  @test live("dragged") >= 2 && live("clicks") == 1
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
  @test e.scroll.offset == 0px
  # Esc gives the keyboard back to the document
  key(Keys.escape)
  @test w.focus === e
  # A click with ⌥ held is the document's, which shows the block's lines, and the page doesn't hear it
  w.keys |= Keys.opt
  click(spot(20, 30))
  w.keys ⊻= Keys.opt
  @test live("clicks") == 1 && w.focus === e && e.buf.caret[1] == K.block_lines(e.buf, K.VIEW_BLOCK, 1)[1] + 1
  e.buf.caret = e.buf.anchor = (length(e.buf.lines), 0)
  frames()
end

@testset "its button goes to the page, and so does a click with ⌘ held" begin
  opened = String[]
  old = K.BROWSER[]
  K.BROWSER[] = url -> push!(opened, url)
  button = go_button()
  @test K.fills(e)[objectid(v)].what == (:go, "https://example.com")
  # A page of the web that isn't Markdown opens in your browser, and the document stays
  click(middle(rect(button)))
  @test opened == ["https://example.com"] && e.buf.path == page
  was = w.keys
  w.keys |= Keys.cmd
  click(middle(rect(b)))
  w.keys = was
  @test opened == ["https://example.com", "https://example.com"] && e.buf.path == page
  K.BROWSER[] = old
  # A page that the block holds is in no file, so no button goes to one. Its one button makes it fill the window.
  held = e.nodes[(:block, K.VIEW_BLOCK, page, 2)]
  @test K.fills(e)[objectid(held)].what == (:node, held.browser) && K.fills(e)[objectid(held)].also === nothing
end

@testset "a link goes to its page where it is, and the block's line says it" begin
  click(spot(20, 80))
  @test b.shown == "https://example.com/more" && b.title == "More" && e.buf.path == page
  @test block_text(1) == ["https://example.com/more"] && K.dirty(e.buf)
  # ⌘Z in the document takes the line back, and the page with it
  K.undo!(e.buf)
  frames()
  @test block_text(1) == ["https://example.com"] && b.shown == "https://example.com/"
  # Typing in a field of the page, and Return sends its form
  click(spot(30, 112))
  @test K.Browsers.field(b) !== nothing && w.focus === b
  typed("wood")
  key(Keys.enter)
  @test b.shown == "https://example.com/find?q=wood" && b.title == "Found" && block_text(1) == ["https://example.com/find?q=wood"]
  key(Keys.escape)
  key(Keys.escape)
  @test w.focus === e
end

@testset "the lines of a page that the block holds" begin
  v5 = e.nodes[(:block, K.VIEW_BLOCK, page, 4)]
  b5 = v5.browser
  written = block_text(4)
  # A link out of the page that the block holds goes to its page there, and puts its address in the block, in place of the HTML
  r = rect(b5)
  # The document scrolls to it, if it's under the bottom of the window
  r.top + 30px > 900px && (e.scroll.offset += r.top - 400px; frames(); r = rect(b5))
  click((K.num(r.left) + 10, K.num(r.top) + 15))
  @test b5.shown == "https://julialang.org/" && block_text(4) == ["https://julialang.org/"] && !v5.held
  # Now it goes to that page
  @test K.fills(e)[objectid(v5)].what == (:go, "https://julialang.org/")
  # ⌘Z in the document takes the line back, and the view shows the page that the block holds again
  K.undo!(e.buf)
  frames()
  @test block_text(4) == written && v5.held && b5.html == join(written, "\n") && startswith(b5.shown, "file://")
end

@testset "the block as HTML, and an email" begin
  @test K.view_html(e, v) == "<p><a href=\"https://example.com/find?q=wood\">https://example.com/find?q=wood</a></p>"
  @test startswith(K.view_html(e, e.nodes[(:block, K.VIEW_BLOCK, page, 2)]), "<iframe srcdoc=\"<h2 style=&quot;margin:0;height:40px&quot;>Written here</h2>")
  @test K.view_html(e, e.nodes[(:block, K.VIEW_BLOCK, page, 3)]) === nothing
  # A page of an email asks the web for nothing
  mail = joinpath(dir, "note.eml")
  write(mail, "From: a@example.com\r\nTo: b@example.com\r\nSubject: A page\r\nContent-Type: text/plain\r\n\r\n```view\r\nhttps://julialang.org\r\n```\r\n")
  e2 = K.build_editor(mail)
  w2 = Window(e2, size=(800px, 600px))
  n = length(asked)
  foreach(_ -> frame(w2), 1:3)
  @test length(asked) == n
  close(w2)
end

close(w)
