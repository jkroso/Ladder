# Tests for the web view: web/form.jl, web/files.jl and web/browser.jl, and
# what live.jl does for a page that scrolls and takes the keyboard. Run them
# with `julia -O0 --project=. test/web_browser_test.jl`. They ask the web for
# nothing: a function of the test stands in for `curl`. Set `LADDER_SHOTS` to
# a folder, and they save pictures of the window there.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window Keys KeyPress KeyRelease Typed onkey ontype onscroll
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups clipboard
@use "github.com/jkroso/UI.jl/Interface/testing" click! move! press! type! holding
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "../web/dom" document Element attr
@use "../web/form" => Forms
@use "../web/files" => Fetch
@use "../web/live" => Live
@use "../web/browser" Browser go! back! forward! reload! can_back can_forward loading scroll!
@use "../web/browser" => Browsers
@use "../web/select" => Select

shot(name, w) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

"The first element of `doc` whose `id` is `id`"
byid(doc, id) = only(Forms.under(e -> attr(e, "id") == id, doc.root))

"""
A stand-in for `curl`: `site` has the kind and the text of the file at each
address. An address in `held` doesn't come until it's taken out of `held`.
`asked` lists each address that was asked for.
"""
fake(site; held=Set{String}(), asked=String[], shared=Dict{String,String}(), moved=Dict{String,String}()) = (address, file, about) -> begin
  push!(asked, address)
  () -> begin
    address in held && return false
    isfile(about) && return true
    to = get(moved, address, address)
    haskey(site, to) || return (write(about, "$to\n\n\n"); true)
    kind, body = site[to]
    write(file, body)
    write(about, "$to\n$kind\n$(get(shared, to, ""))\n")
    true
  end
end

@testset "what a form sends" begin
  doc = document("""<form id=f action="/search" method=GET>
    <input name=q value="julia lang & more"><input type=checkbox name=exact checked><input type=checkbox name=old value=1>
    <input type=radio name=sort value=new><input type=radio name=sort value=top checked>
    <select name=in><option value=docs>Docs<option value=blog selected>Blog</select>
    <textarea name=note>two
lines</textarea><input name=off value=x disabled><input value="no name">
    <button id=go name=by value=button>Go</button><input type=submit id=other name=by value=other></form>
    <form id=p method=post action="save"><input name=a value=1></form>""")
  f = byid(doc, "f")
  @test Forms.sent(f; base="https://example.com/dir/page?old=1#top") ==
    ("get", "https://example.com/search?q=julia+lang+%26+more&exact=on&sort=top&in=blog&note=two%0Alines")
  # Only the button that sent the form sends its own name
  @test endswith(Forms.sent(f, byid(doc, "go"); base="https://example.com/")[2], "&by=button")
  @test endswith(Forms.sent(f, byid(doc, "other"); base="https://example.com/")[2], "&by=other")
  @test Forms.sent(byid(doc, "p"); base="https://example.com/dir/page") == ("post", "https://example.com/dir/save")
  # A form with no address sends to its own page
  @test Forms.sent(document("<form id=f><input name=a value=b></form>") |> d -> byid(d, "f"); base="https://example.com/x?y=1") == ("get", "https://example.com/x?a=b")
  # A click changes a tick box, and chooses one round button of a set
  box, new, top = Forms.under(e -> attr(e, "name") == "exact", f)[1], Forms.under(e -> attr(e, "value") == "new", f)[1], Forms.under(e -> attr(e, "value") == "top", f)[1]
  @test Forms.tick!(box) && !haskey(box.attrs, "checked") && Forms.tick!(box) && haskey(box.attrs, "checked")
  @test Forms.tick!(new) && haskey(new.attrs, "checked") && !haskey(top.attrs, "checked") && !Forms.tick!(new)
  # What takes text from the keyboard
  @test Forms.typed(Forms.under(e -> attr(e, "name") == "q", f)[1]) && Forms.typed(Forms.under(e -> e.tag == "textarea", f)[1])
  @test !Forms.typed(box) && !Forms.typed(Forms.under(e -> attr(e, "name") == "off", f)[1]) && !Forms.typed(byid(doc, "go"))
  area = Forms.under(e -> e.tag == "textarea", f)[1]
  @test Forms.value(area) == "two\nlines" && Forms.value(Forms.value!(area, "one")) == "one" && Forms.value(Forms.value!(area, "")) == ""
end

@testset "files from the web" begin
  site = Dict("https://example.com/" => ("text/html; charset=utf-8", "<p>home</p>"), "https://example.com/a.css" => ("text/css", "p { color: red }"),
              "https://example.com/latin" => ("text/plain; charset=iso-8859-1", UInt8[0x63, 0x61, 0x66, 0xe9]),
              "https://other.org/open.json" => ("application/json", "{}"), "https://other.org/shut.json" => ("application/json", "{}"))
  held, asked = Set(["https://example.com/a.css"]), String[]
  f = Fetch.Files(getter=fake(site; held, asked, shared=Dict("https://other.org/open.json" => "*"), moved=Dict("http://example.com/old" => "https://example.com/")))
  @test Fetch.state(f, "https://example.com/") == :none
  Fetch.ask!(f, "https://example.com/#top")
  @test Fetch.state(f, "https://example.com/") == :there && f.landed == 1
  got = Fetch.file(f, "https://example.com/")
  @test got.type == "text/html" && got.charset == "utf-8" && Fetch.text(got) == "<p>home</p>" && got.address == "https://example.com/"
  # A file is asked for once, and one that's on its way is `:waiting` to a page
  load = Fetch.loader(f, "https://example.com/")
  @test load("https://example.com/a.css") === :waiting && load("https://example.com/a.css") === :waiting && Fetch.coming(f) == 1
  @test count(==("https://example.com/a.css"), asked) == 1
  delete!(held, "https://example.com/a.css")
  @test String(load("https://example.com/a.css")) == "p { color: red }" && Fetch.coming(f) == 0 && f.landed == 2
  # One that the site doesn't have couldn't be had, and so is an address that's no web address
  @test load("https://example.com/none") === nothing && Fetch.state(f, "https://example.com/none") == :failed
  @test load("ftp://example.com/x") === nothing && load("") === nothing
  # A page that the site moved says where it ended up
  Fetch.ask!(f, "http://example.com/old")
  @test Fetch.file(f, "http://example.com/old").address == "https://example.com/"
  # Text that isn't in UTF-8
  load("https://example.com/latin")
  @test Fetch.text(Fetch.file(f, "https://example.com/latin")) == "café"
  # A page from the web gets no file of this computer. A page that's such a file does.
  mktempdir() do dir
    write(joinpath(dir, "note.txt"), "private")
    @test load(joinpath(dir, "note.txt")) === nothing && load("file://" * joinpath(dir, "note.txt")) === nothing
    here = Fetch.loader(f, "file://" * joinpath(dir, "page.html"))
    @test String(here("file://" * joinpath(dir, "note.txt"))) == "private" && String(here(joinpath(dir, "note.txt"))) == "private"
    @test Fetch.readable(f, joinpath(dir, "note.txt"), joinpath(dir, "page.html")) && !Fetch.readable(f, joinpath(dir, "note.txt"), "https://example.com/")
  end
  # A script reads the files of its page's own site, and another site's only when that site says so
  foreach(load, ("https://other.org/open.json", "https://other.org/shut.json"))
  @test Fetch.readable(f, "https://example.com/a.css", "https://example.com/page")
  @test Fetch.readable(f, "https://other.org/open.json", "https://example.com/page") && !Fetch.readable(f, "https://other.org/shut.json", "https://example.com/page")
  # With no web to ask, a file that isn't here couldn't be had
  off = Fetch.Files(getter=fake(site), online=() -> false)
  @test Fetch.loader(off, "https://example.com/")("https://example.com/") === nothing
  # No more than eight files come at a time, and the rest wait their turn
  many = ["https://example.com/n$i" for i in 1:12]
  slow, started = Set(many), String[]
  g = Fetch.Files(getter=fake(Dict(a => ("text/plain", "x") for a in many); held=slow, asked=started))
  foreach(a -> Fetch.ask!(g, a), many)
  @test started == many[1:8] && Fetch.coming(g) == 12 && Fetch.state(g, many[12]) == :coming
  delete!(slow, many[1])
  @test Fetch.state(g, many[1]) == :there && started == many[1:9]
  empty!(slow)
  while Fetch.coming(g) > 0 end
  @test started == many && all(a -> Fetch.state(g, a) == :there, many) && g.running == 0
  # Everything is asked for again after `forget!`
  Fetch.forget!(f)
  @test Fetch.state(f, "https://example.com/") == :none && f.held == 0
end

@testset "a page that scrolls, goes somewhere and waits for files" begin
  went, files = String[], Dict{String,Any}("https://example.com/dir/late.js" => :waiting, "https://example.com/dir/data.json" => :waiting,
                                           "https://other.org/secret.json" => "{\"secret\":1}")
  html = """<!DOCTYPE html><body style="margin:0"><div id=a style="height:1000px"></div><div id=b style="height:1000px"></div>
    <form id=f action="/find"><input id=q name=q value=""><button id=go>Go</button></form>
    <form id=stay action="/nowhere"><input name=x value=1></form>
    <script>
      var heard = [], got = null, late = 0
      addEventListener('scroll', () => heard.push('scroll ' + scrollY))
      document.getElementById('stay').addEventListener('submit', e => { e.preventDefault(); heard.push('stayed') })
      document.getElementById('q').addEventListener('input', e => heard.push('input ' + e.target.value))
      document.addEventListener('keydown', e => { heard.push('key ' + e.key + ' ' + e.keyCode); if (e.key === 'x') e.preventDefault() })
      fetch('data.json').then(r => r.json()).then(j => { got = j.n })
      var blocked = null
      fetch('https://other.org/secret.json').then(r => r.text()).then(t => { blocked = t }, e => { blocked = 'refused' })
      var s = document.createElement('script'); s.src = 'late.js'; document.body.appendChild(s)
    </script></body>"""
  l = Live.live(html; wide=400, high=300, base="https://example.com/dir/page", load=address -> get(files, address, nothing), go=address -> push!(went, address),
                allowed=address -> startswith(address, "https://example.com/"))
  js(code) = Live.evaluate(l, code)
  # The window scrolls as far as the page goes, and a script hears of it and reads how far
  @test Live.page!(l).tall > 2000 && Live.scroll!(l, 500) == 500 && l.scroll == 500
  @test js("scrollY") == 500 && js("pageYOffset + document.documentElement.scrollTop") == 1000 && js("heard.join()") == "scroll 500"
  @test Live.scroll!(l, 99999) == Live.page!(l).tall - 300 && Live.scroll!(l, -5) == 0
  # An element's rectangle is from the top of the window, and its place on the page stays
  Live.scroll!(l, 400)
  @test js("document.getElementById('b').getBoundingClientRect().top") == 600 && js("document.getElementById('b').offsetTop") == 1000
  @test js("document.elementFromPoint(10, 700).id") == "b"
  # A script scrolls the page
  js("scrollTo(0, 120)")
  @test l.scroll == 120
  js("scrollBy({top: 30}); document.getElementById('b').scrollIntoView()")
  @test l.scroll == 1000
  js("window.scrollTo({top: 0})")
  @test l.scroll == 0
  # A script that sets where the page is asks to go there, and so does a form that's sent
  js("location.href = '/other?x=1'")
  @test went == ["https://example.com/other?x=1"]
  f, q = byid(l.doc, "f"), byid(l.doc, "q")
  Live.input!(l, q, "julia set")
  @test attr(q, "value") == "julia set" && js("heard[heard.length - 1]") == "input julia set"
  Live.submit!(l, f)
  @test went[end] == "https://example.com/find?q=julia+set"
  js("document.getElementById('go').click()")
  @test length(went) == 3 && went[end] == "https://example.com/find?q=julia+set"
  # A form whose script says to do no more goes nowhere
  Live.submit!(l, byid(l.doc, "stay"))
  @test length(went) == 3 && js("heard[heard.length - 1]") == "stayed"
  js("document.getElementById('stay').submit()")
  @test went[end] == "https://example.com/nowhere?x=1"
  # The keyboard: the field that has it hears the keys, and a script can say to do no more with one
  @test Live.focus!(l, q) === q && js("document.activeElement.id") == "q"
  @test Live.key!(l, "keydown", "Enter") && js("heard[heard.length - 1]") == "key Enter 13"
  @test !Live.key!(l, "keydown", "x")
  js("document.getElementById('go').focus()")
  @test l.focused === byid(l.doc, "go")
  @test Live.focus!(l, nothing) === nothing && js("document.activeElement === document.body")
  # A file that's on its way: the script that asked for it goes on once it has come
  @test js("got") === nothing && js("late") == 0 && Live.waiting(l) !== nothing
  Live.step!(l)
  @test js("got") === nothing && js("late") == 0
  files["https://example.com/dir/data.json"] = "{\"n\": 7}"
  files["https://example.com/dir/late.js"] = "late = 1"
  Live.step!(l); Live.step!(l)
  @test js("got") == 7 && js("late") == 1
  # A script doesn't read what its page isn't allowed to
  @test js("blocked") == "refused"
  close(l)
end

const HOME = """<!DOCTYPE html><title>Home &amp; garden</title><link rel=stylesheet href="look.css"><script src="count.js"></script>
  <body style="margin:0;font:16px/20px Helvetica">
  <a id=next href="/next" style="display:block;height:40px">Next page</a>
  <a id=down href="#low" style="display:block;height:40px">Further down</a>
  <a id=mail href="mailto:jake@example.com" style="display:block;height:40px">Write</a>
  <form action="/find" style="margin:0;height:40px"><input id=q name=q style="width:200px;height:20px;margin:0;font:16px/20px Helvetica">
    <input type=checkbox id=tick name=exact style="margin:0"></form>
  <select id=pick style="display:block;height:20px;margin:0"><option>One<option>Two<option>Three</select>
  <div style="height:1500px"></div><p id=low style="margin:0">The foot</p>
  <script>var ticks = 0; document.getElementById('tick').addEventListener('change', () => ticks++)</script></body>"""

@testset "a web view in a window" begin
  site = Dict("https://example.com/" => ("text/html", HOME), "https://example.com/look.css" => ("text/css", "a { color: rgb(200, 0, 0) }"),
              "https://example.com/count.js" => ("text/javascript", "var counted = 1"),
              "https://example.com/next" => ("text/html", "<title>Next</title><body style='margin:0'><p>The next page</p><img src='dot.png'>"),
              "https://example.com/find?q=snow+day&exact=on" => ("text/html", "<title>Found</title><p>Found it</p>"),
              "https://example.com/plain.txt" => ("text/plain", "just <text>"))
  held, asked, opened = Set(["https://example.com/look.css"]), String[], String[]
  b = Browser(address="example.com", wide=500px, high=300px, files=Fetch.Files(getter=fake(site; held, asked)), open=url -> push!(opened, url))
  w = Window(b, size=(500px, 300px))
  frame(w)
  # The page waits for its sheet before it shows
  @test loading(b) && b.shown == "" && asked == ["https://example.com/", "https://example.com/look.css", "https://example.com/count.js"]
  frame(w)
  @test loading(b)
  delete!(held, "https://example.com/look.css")
  frame(w)
  @test !loading(b) && b.shown == "https://example.com/" && b.title == "Home & garden" && !b.failed
  l = b.view.live
  @test Live.evaluate(l, "counted") == 1 && Live.evaluate(l, "getComputedStyle(document.getElementById('next')).color") == "rgb(200, 0, 0)"
  @test rect(b).width == 500px && rect(b).height == 300px && b.view.page.tall > 1500
  shot("web-browser.png", w)

  # The wheel and the keys scroll the page
  move!(w, (250px, 150px))
  onscroll(w, typeof(w.mouse)(0px, -2px), true)
  frame(w)
  @test Browsers.scrolled(b) == 60
  click!(w, (250px, 290px))   # a click on no field gives the view the keyboard
  press!(w, Keys.space)
  @test Browsers.scrolled(b) == 60 + 270
  press!(w, Keys._end)
  @test Browsers.scrolled(b) == b.view.page.tall - 300
  press!(w, Keys.home)
  @test Browsers.scrolled(b) == 0

  # A link to a place in the page scrolls there, and a link that's no page goes to `open`
  click!(w, (40px, 60px))
  @test Browsers.scrolled(b) == b.view.page.tall - 300 && b.shown == "https://example.com/" && !loading(b)
  scroll!(b, 0)
  frame(w)
  click!(w, (40px, 100px))
  @test opened == ["mailto:jake@example.com"]

  # A tick box, with the page's script hearing of it
  tick = byid(l.doc, "tick")
  at = Browsers.place(b, tick)
  click!(w, (px(at[1] + at[3] / 2), px(at[2] + at[4] / 2)))
  frame(w)
  @test haskey(tick.attrs, "checked") && Live.evaluate(l, "ticks") == 1

  # A list of choices shows its choices in a menu
  click!(w, (20px, 170px))
  @test length(popups(w)) == 1
  press!(w, Keys.down); press!(w, Keys.down); press!(w, Keys.enter)
  frame(w)
  @test isempty(popups(w)) && Live.evaluate(l, "document.getElementById('pick').value") == "Two"

  # Typing in a field: the caret, a selection, and Return sends the form
  q = byid(l.doc, "q")
  click!(w, (50px, 130px))
  @test Browsers.field(b) === q && Live.evaluate(l, "document.activeElement.id") == "q"
  type!(w, "snow dya")
  @test attr(q, "value") == "snow dya" && b.caret == 8
  press!(w, Keys.backspace); press!(w, Keys.backspace)
  type!(w, "ay")
  @test attr(q, "value") == "snow day"
  press!(w, Keys.left); press!(w, Keys.left, Keys.shft)
  @test (b.caret, b.anchor) == (6, 7)
  press!(w, Keys.a, Keys.cmd)
  press!(w, Keys.c, Keys.cmd)
  press!(w, Keys.right)
  press!(w, Keys.v, Keys.cmd)
  @test attr(q, "value") == "snow daysnow day" && b.caret == 16
  press!(w, Keys.a, Keys.cmd)
  type!(w, "snow day")
  @test attr(q, "value") == "snow day"
  shot("web-browser-typing.png", w)
  # The caret is where the page drew the letters: after the last one, inside the field
  stops = Browsers.caret_stops(b, q)
  @test length(stops) == 9 && issorted(first.(stops)) && 0 < stops[1][1] < stops[end][1] < 210 && 120 <= stops[1][2] < 140
  # A click in the text puts the caret there
  click!(w, (px(stops[4][1] + 1), 130px))
  @test b.caret == 3 && b.anchor == 3
  # Return sends the form, with what the tick box says too
  press!(w, Keys.enter)
  frame(w); frame(w)
  @test b.shown == "https://example.com/find?q=snow+day&exact=on" && b.title == "Found" && Browsers.field(b) === nothing

  # Back and forward
  @test can_back(b) && !can_forward(b)
  back!(b)
  frame(w); frame(w)
  @test b.shown == "https://example.com/" && can_forward(b) && !can_back(b)
  click!(w, (40px, 20px))
  frame(w); frame(w)
  @test b.shown == "https://example.com/next" && b.title == "Next" && b.trail == ["https://example.com/", "https://example.com/next"]
  # The picture that the page names was asked for, and the page was laid out again when it couldn't be had
  @test "https://example.com/dot.png" in asked
  back!(b); frame(w); frame(w)
  forward!(b); frame(w); frame(w)
  @test b.shown == "https://example.com/next"

  # A page that isn't there says so, and a file of text shows as text
  go!(b, "https://example.com/missing")
  frame(w); frame(w)
  @test b.failed && b.shown == "https://example.com/missing" && occursin("didn't come", b.view.html)
  go!(b, "https://example.com/plain.txt")
  frame(w); frame(w)
  @test !b.failed && occursin("just &lt;text&gt;", b.view.html)
  # The page is asked for again when it's loaded again
  n = count(==("https://example.com/plain.txt"), asked)
  reload!(b)
  frame(w); frame(w)
  @test count(==("https://example.com/plain.txt"), asked) == n + 1 && b.shown == "https://example.com/plain.txt"

  # While it isn't active, the page only shows: a click goes nowhere
  go!(b, "https://example.com/")
  frame(w); frame(w)
  b.active = false
  click!(w, (40px, 20px))
  frame(w); frame(w)
  @test b.shown == "https://example.com/" && !loading(b)
  close(w)
end

@testset "a page that's written in place of an address" begin
  mktempdir() do dir
    write(joinpath(dir, "side.js"), "document.getElementById('out').textContent = 'from a file'")
    b = Browser(html="""<body style="margin:0"><p id=out>nothing yet</p><input id=name value="Jake"><script src="side.js"></script></body>""",
                base="file://" * joinpath(dir, "page.html"), wide=300px, high=200px)
    w = Window(b, size=(300px, 200px))
    frame(w); frame(w)
    @test !loading(b) && Live.evaluate(b.view.live, "document.getElementById('out').textContent") == "from a file"
    # With no scripts, a field still takes what's typed
    b.scripts = false
    frame(w)
    @test b.view.live === nothing
    r = Browsers.place(b, only(Forms.under(e -> e.tag == "input", b.view.showing.doc.root)))
    click!(w, (px(r[1] + r[3] - 4), px(r[2] + r[4] / 2)))
    type!(w, "!")
    @test attr(Browsers.field(b), "value") == "Jake!"
    close(w)
  end
end

@testset "a page in dark mode" begin
  # A page that can be dark is dark when the view is, also under its end when it's shorter than the view
  b = Browser(html="""<meta name="color-scheme" content="light dark"><body style="margin:0"><p>short</p></body>""", wide=300px, high=200px, scripts=false)
  w = Window(b, size=(300px, 200px))
  frame(w)
  @test Browsers.under(b) == "white" && b.view.page.list.background == 0
  b.dark = true
  frame(w)
  @test Browsers.under(b) == "#1e1e1e" && b.view.page.list.background == 0xff1e1e1e
  # A page that gives its own background has it under its end
  b.html = """<body style="margin:0;background:#123456"><p>short</p></body>"""
  frame(w); frame(w)
  @test Browsers.under(b) == "#123456"
  close(w)
end

@testset "a video in a frame" begin
  # A script gives the frame its address, as YouTube's own script does. A click on the frame opens the video's page in a browser: the view stays where it is.
  site = Dict("https://example.com/" => ("text/html", """<!DOCTYPE html><body style="margin:0"><iframe id=v width="320" height="180" frameborder="0"></iframe>
    <script>document.getElementById('v').src = 'https://www.youtube.com/embed/abc?enablejsapi=1'</script></body>"""))
  asked, opened = String[], String[]
  b = Browser(address="example.com", wide=500px, high=300px, files=Fetch.Files(getter=fake(site; asked)), open=url -> push!(opened, url))
  w = Window(b, size=(500px, 300px))
  for _ in 1:8
    frame(w)
  end
  @test !loading(b) && "https://www.youtube.com/oembed?format=json&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dabc" in asked
  click!(w, (100px, 100px))
  @test opened == ["https://www.youtube.com/watch?v=abc"] && b.shown == "https://example.com/" && !loading(b)
  shot("browser_video.png", w)
  close(w)
end

@testset "selecting the words of a page" begin
  opened = String[]
  b = Browser(html="""<!DOCTYPE html><body style="margin:0;font:16px/20px sans-serif">
    <p style="margin:0">One two three, and <a href="mailto:jake@example.com">a link</a> here.</p><p style="margin:0">A second paragraph</p>
    <input id=q value="in a field" style="margin:0">
    <div style="height:20px;width:120px;overflow:hidden"><p style="margin:0;white-space:nowrap">Cut at the right edge of its box</p><p style="margin:0">Hidden under</p></div>
    <div style="height:600px"></div><p style="margin:0">The end</p></body>""",
    base="https://example.com/", wide=400px, high=200px, open=url -> push!(opened, url))
  w = Window(b, size=(400px, 200px))
  frame(w); frame(w)
  ws = b.view.page.words
  letters = join(String(p.letters) for p in ws)
  # The places before and after the first `words` in the page's words
  around(words) = (r = findfirst(words, letters); (first(r) - 1, last(r)))
  # A point of the window just inside the left of the letter after place `a`, where the page is scrolled to now
  spot(a) = (p = ws[findlast(p -> p.from <= a, ws)]; (px(p.edges[a - p.from + 1] + 1), px(p.top + p.tall / 2 - Browsers.scrolled(b))))
  # Hold the button down at `from`, move to `to`, and let it go there
  drag!(from, to) = begin
    move!(w, from)
    w.keys |= Keys.mouse_left
    onkey(w, KeyPress{Keys.mouse_left}(0, w))
    move!(w, to)
    w.keys ⊻= Keys.mouse_left
    onkey(w, KeyRelease{Keys.mouse_left}(0, w))
    frame(w)
  end

  # A drag over words selects them, and ⌘C copies them
  a, z = around("One two three")
  move!(w, spot(a))
  @test Browsers.cursor(b) == :ibeam
  move!(w, (390px, 150px))
  @test Browsers.cursor(b) == :arrow
  drag!(spot(a), spot(z))
  @test Browsers.selected_words(b) == "One two three" && b.drag == :none && b.down === nothing
  press!(w, Keys.c, Keys.cmd)
  @test clipboard(w) == "One two three"
  shot("web-browser-selected.png", w)
  # A drag that starts on a link selects its words, and doesn't follow it
  drag!(spot(around("a link")[1]), spot(around("a link")[2]))
  @test Browsers.selected_words(b) == "a link" && isempty(opened)
  # A click selects nothing. Two select a word, three its paragraph, and four start again.
  at = spot(around("second")[1] + 2)
  click!(w, at)
  @test Browsers.selected_words(b) == ""
  click!(w, at)
  @test Browsers.selected_words(b) == "second"
  click!(w, at)
  @test Browsers.selected_words(b) == "A second paragraph"
  click!(w, at)
  @test Browsers.selected_words(b) == ""
  # A drag after two clicks selects whole words
  click!(w, spot(a + 1))
  move!(w, spot(a + 1))
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  move!(w, spot(around("three")[1] + 1))
  @test Browsers.selected_words(b) == "One two three"
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  # A click with ⇧ held moves the end of the selection there
  sleep(0.5)
  click!(w, spot(a))
  click!(w, spot(around("second")[2]), Keys.shft)
  @test Browsers.selected_words(b) == "One two three, and a link here.\nA second"
  # ⌘A selects all of the page's words
  press!(w, Keys.a, Keys.cmd)
  @test startswith(Browsers.selected_words(b), "One two") && endswith(Browsers.selected_words(b), "The end")

  # A box that cuts what's in it hides its words. They have no marks where they can't be seen, and the mouse doesn't
  # land on them. A selection over them copies them, as a browser does.
  hid, cut = around("Hidden under"), around("Cut at the right edge of its box")
  @test isempty(Select.marks(ws, hid...))
  m = Select.marks(ws, cut...)
  @test length(m) == 1 && 100 < m[1][1] + m[1][3] <= 120.5
  under = ws[findlast(p -> p.from <= hid[1], ws)]
  @test !(hid[1] < Select.place(ws, 20, under.top + under.tall / 2) < hid[2]) && !Select.over_words(ws, 20, under.top + under.tall / 2)
  @test Select.copied(ws, cut[1], hid[2]) == "Cut at the right edge of its box\nHidden under"

  # A drag below the view scrolls the page, and selects what comes into view. The button can come up where the view doesn't hear it.
  start = around("A second")[1]
  move!(w, spot(start))
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  move!(w, (200px, 260px))
  for _ in 1:12
    sleep(0.03)
    frame(w)
  end
  @test Browsers.scrolled(b) > 100 && Browsers.selection(b)[1] == start && Browsers.selection(b)[2] > around("in a field")[2]
  w.keys ⊻= Keys.mouse_left
  frame(w)
  far = Browsers.scrolled(b)
  frame(w)
  @test b.drag == :none && b.down === nothing && Browsers.scrolled(b) == far
  scroll!(b, 0)
  frame(w)

  # A drag in a field selects its letters, and the page's words are no longer selected
  f = around("in a field")[1]
  drag!(spot(f), spot(f + 4))
  @test Browsers.field(b) !== nothing && (b.anchor, b.caret) == (0, 4) && Browsers.selected_words(b) == ""
  press!(w, Keys.c, Keys.cmd)
  @test clipboard(w) == "in a"
  close(w)
end

@testset "a game that has the mouse and the keys" begin
  # What a key's code is, wherever the keyboard's layout puts what it types
  @test Live.code_of("w") == "KeyW" && Live.code_of("W") == "KeyW" && Live.code_of("1") == "Digit1" && Live.code_of(" ") == "Space"
  @test Live.code_of("Shift") == "ShiftLeft" && Live.code_of("Enter") == "Enter" && Live.code_of("-") == "Minus" && Live.code_of("é") == ""
  @test Browsers.key_code(Keys.w) == "KeyW" && Browsers.key_code(getproperty(Keys, Symbol("7"))) == "Digit7" && Browsers.key_code(Keys.ctrl) == "ControlLeft"
  @test Browsers.key_name(getproperty(Keys, Symbol("1")), true) == "!" && Browsers.key_name(Keys.slash, false) == "/"

  # A page that turns its view with the mouse and moves with W, A, S and D, as 3D.html in Jake's City folder does
  b = Browser(html="""<body style="margin:0"><canvas id=c width=400 height=300 style="display:block"></canvas><script>
    var heard = [], c = document.getElementById('c')
    c.addEventListener('mousedown', e => { heard.push('down ' + e.button + ' ' + e.buttons); c.requestPointerLock() })
    c.addEventListener('click', () => heard.push('click'))
    document.addEventListener('pointerlockchange', () => heard.push('locked ' + (document.pointerLockElement === c)))
    document.addEventListener('mousemove', e => heard.push('move ' + e.movementX + ' ' + e.movementY + ' ' + (e.target === c)))
    addEventListener('keydown', e => { heard.push('down ' + e.key + ' ' + e.code + ' ' + e.repeat); if (e.code === 'Space') e.preventDefault() })
    addEventListener('keyup', e => heard.push('up ' + e.code))
    c.addEventListener('wheel', e => { heard.push('wheel ' + e.deltaY + ' ' + (e instanceof WheelEvent)); e.preventDefault() }, {passive: false})
    </script></body>""", wide=400px, high=300px)
  w = Window(b, size=(400px, 300px))
  frame(w); frame(w)
  l = b.view.live
  last() = Live.evaluate(l, "heard[heard.length - 1]")
  heard() = Live.evaluate(l, "heard.join('|')")
  forget() = Live.evaluate(l, "heard.length = 0")

  # Before a click, a move of the mouse says how far it went
  move!(w, (100px, 100px))
  move!(w, (110px, 95px))
  @test last() == "move 10 -5 true" && b.locked === nothing

  # A click gives the canvas the mouse to itself, and the pointer is kept in the middle of the view
  forget()
  click!(w, (110px, 95px))
  @test Live.locked(l) && b.locked == (200px, 150px)
  @test endswith(heard(), "|down 0 1|locked true|click")   # the click moves the mouse there first
  # A move says how far the mouse went from there, and nothing else hears it
  forget()
  move!(w, (207px, 147px))
  @test heard() == "move 7 -3 true"
  move!(w, (195px, 150px))
  @test last() == "move -5 0 true"

  # The keys say where they are, whether they go down again as they're held, and ⇧ goes down too
  forget()
  w.keys |= Keys.w
  onkey(w, KeyPress{Keys.w}(0, false, w))
  onkey(w, KeyPress{Keys.w}(0, true, w))
  w.keys ⊻= Keys.w
  onkey(w, KeyRelease{Keys.w}(0, w))
  press!(w, getproperty(Keys, Symbol("1")))
  holding(w, [Keys.shft]) do
    onkey(w, KeyPress{Keys.shft}(0, w))
    onkey(w, KeyRelease{Keys.shft}(0, w))
  end
  press!(w, Keys.space)
  @test heard() == "down w KeyW false|down w KeyW true|up KeyW|down 1 Digit1 false|up Digit1|down Shift ShiftLeft false|up ShiftLeft|down   Space false|up Space"
  # The wheel goes to the canvas, which keeps it from scrolling the page
  forget()
  onscroll(w, typeof(w.mouse)(0px, -2px), true)
  @test heard() == "wheel 60 true" && Browsers.scrolled(b) == 0

  # Esc takes the mouse back, and the page hears that it no longer has it, but not the Esc
  forget()
  press!(w, Keys.escape)
  @test !Live.locked(l)
  @test b.locked === nothing
  @test heard() == "locked false|up Escape"
  # The script can let the mouse go itself, and a view that loses the keyboard takes it back
  click!(w, (200px, 150px))
  @test b.locked !== nothing
  Live.evaluate(l, "document.exitPointerLock()")
  frame(w)
  @test b.locked === nothing && last() == "locked false"
  click!(w, (200px, 150px))
  @test b.locked !== nothing
  w.focus = nothing
  frame(w)
  @test b.locked === nothing && !Live.locked(l)
  close(w)
end

@testset "the middle button of the mouse" begin
  # A 3D view moves what it shows across while the middle button is held. The scripts hear the button, and the
  # page's words aren't selected by it.
  b = Browser(html="""<body style="margin:0"><p>Some words to select</p><script>
    var heard = []
    addEventListener('mousedown', e => heard.push('down ' + e.button + ' ' + e.buttons))
    addEventListener('mousemove', e => heard.push('move ' + e.buttons))
    addEventListener('mouseup', e => heard.push('up ' + e.button + ' ' + e.buttons))
    </script></body>""", wide=400px, high=300px)
  w = Window(b, size=(400px, 300px))
  frame(w); frame(w)
  l = b.view.live
  move!(w, (20px, 10px))
  Live.evaluate(l, "heard.length = 0")
  w.keys |= Keys.mouse_middle
  onkey(w, KeyPress{Keys.mouse_middle}(0, w))
  move!(w, (120px, 10px))
  w.keys ⊻= Keys.mouse_middle
  onkey(w, KeyRelease{Keys.mouse_middle}(0, w))
  @test Live.evaluate(l, "heard.join('|')") == "down 1 4|move 4|up 1 0"
  @test Browsers.selected_words(b) == ""
  close(w)
end
