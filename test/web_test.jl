# Tests for web/, which draws a page of HTML with no browser: how it reads
# HTML and CSS, the style that each element gets, where layout puts each box,
# and what the page's links and words are. The second half is the HTML and CSS
# of today: flex boxes, grids, variables, what CSS makes, boxes with a place
# of their own, forms and SVG. The last part is what moves: animations,
# transitions, video and pictures that move. Run them with
# `julia -O0 --project=. test/web_test.jl`. They use the fonts of this Mac and
# no web.

@use Test: @test, @testset
@use Skia
@use Base64: base64decode
using Base64: base64encode
@use "../web/dom" => Dom
@use "../web/css" => Css
@use "../web/style" => Styles
@use "../web/box" => Boxes
@use "../web/layout" => Layout
@use "../web" => Web
@use "../web/paint" => Paint
@use "../web/svg" => Svg
@use "../web/video" => Film
@use "../web/embed" => Embed

"The first element of `e`'s tree that `ok` is true of"
function element(ok, e::Dom.Element)
  ok(e) && return e
  for c in e.children
    c isa Dom.Element || continue
    found = element(ok, c)
    found === nothing || return found
  end
  nothing
end
tagged(doc, tag) = element(e -> e.tag == tag, doc.root)
named(doc, id) = element(e -> Dom.attr(e, "id") == id, doc.root)

"The box of the element `e` under `b`"
function box(b::Boxes.Box, e)
  b.element === e && return b
  for k in b.children
    found = box(k, e)
    found === nothing || return found
  end
  nothing
end

"The page that `html` writes, laid out `wide` px wide: its document, its styles and the box of its <html>"
function laid(html; wide=400)
  doc = Dom.document(html)
  look = Styles.styles(doc, wide)
  root = Boxes.boxes(doc, look)
  tall = Layout.layout!(root, wide, doc.mode)
  (doc=doc, look=look, root=root, tall=tall, box=id -> box(root, named(doc, id)))
end

"Where the border of `b` is on the page"
function place(root::Boxes.Box, b::Boxes.Box)
  walk(at, x, y) = begin
    at === b && return (x + at.x, y + at.y)
    for k in [at.children; at.over]
      found = walk(k, x + at.x, y + at.y)
      found === nothing || return found
    end
    nothing
  end
  walk(root, 0.0, 0.0)
end

tags(e::Dom.Element) = [c.tag for c in e.children if c isa Dom.Element]

@testset "reading HTML" begin
  doc = Dom.document("<p>Hi <b>there</b><div>block</div>Tom &amp; Sam&rsquo;s &#8212; <!-- gone -->")
  @test tags(doc.root) == ["body"] && tags(doc.body) == ["p", "div"]   # the <p> ends where the block starts
  @test Dom.text(doc.body) == "Hi thereblockTom & Sam’s — "
  @test doc.mode == :quirks
  @test Dom.document("<!DOCTYPE html><p>x").mode == :standards
  @test Dom.document("""<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><p>x""").mode == :limited
  # A table's rows get a <tbody>, a cell ends where the next starts, and what's in no cell goes before the table
  doc = Dom.document("<table><tr><td>one<td>two</tr>stray<tr><td><table><td>in</table></table>after")
  @test tags(doc.body) == ["table"] && Dom.text(doc.body.children[1]) == "stray"
  table = tagged(doc, "table")
  @test tags(table) == ["tbody"] && tags(table.children[1]) == ["tr", "tr"] && tags(table.children[1].children[1]) == ["td", "td"]
  @test Dom.text(element(e -> e.tag == "table" && e !== table, doc.root)) == "in"
  # A list item ends where the next starts, and a part of a table that's in no table is nothing
  @test tags(tagged(Dom.document("<ul><li>a<li>b<ul><li>c</ul><li>d</ul>"), "ul")) == ["li", "li", "li"]
  @test Dom.text(Dom.document("<td>loose</td><tr>row").body) == "looserow"
  # The head's tags stay out of the body, and a style's text is kept as it's written
  doc = Dom.document("<title>T</title><style>a > b { color: red }</style><p>x")
  @test tags(doc.root) == ["head", "body"] && doc.sheets == [("a > b { color: red }", "")]
  # What a comment for Outlook hides is hidden, and what it shows to the rest is shown
  @test Dom.text(Dom.document("a<!--[if mso]>no<![endif]-->b<!--[if !mso]><!-->c<!--<![endif]-->").body) == "abc"
  @test Dom.attr(tagged(Dom.document("<a HREF='x?a=1&amp;b=2' Title=Go>x</a>"), "a"), "href") == "x?a=1&b=2"
end

@testset "reading CSS" begin
  rules = Css.sheet("""p.a > b, td { color: red; margin: 0 !important } /* note */
    @media (max-width: 600px) { .x { display: none } }
    a:hover { color: blue } @font-face { font-family: X } .bad:: { x: y } #id.k[href^="http"]:not(.q):first-child { width: calc(100% - 2px) }""")
  @test [r.selector.weight for r in rules] == [(0, 1, 2), (0, 0, 1), (0, 1, 0), (0, 1, 1), (1, 4, 0)]
  @test [(d.name, d.value, d.important) for d in rules[1].declarations] == [("color", "red", false), ("margin", "0", true)]
  @test rules[3].media == ["(max-width: 600px)"] && isempty(rules[1].media)
  doc = Dom.document("""<p class="a"><i>x</i><b id="b1">one</b><b>two</b></p><p><b id="b2">no</b></p><a id="id" class="k" href="http://x">l</a>""")
  b1, b2 = named(doc, "b1"), named(doc, "b2")
  @test Css.matches(rules[1].selector, b1) && !Css.matches(rules[1].selector, b2)
  @test !Css.matches(rules[4].selector, tagged(doc, "a"))   # nothing is under the mouse
  @test !Css.matches(rules[5].selector, named(doc, "id"))   # it isn't the first in its parent
  for (text, e, ok) in [("p b", b1, true), ("p > i + b", b1, true), ("i ~ b", b1, true), ("b:first-child", b1, false), ("b:nth-child(2)", b1, true),
                        ("b:last-child", b1, false), ("p:not(.a) b", b2, true), ("[class~=a] b", b2, false), ("*", b2, true), ("body p.a b#b1", b1, true),
                        ("a[href*='//']", named(doc, "id"), true), ("a:link", named(doc, "id"), true), ("b:only-child", b2, true)]
    @test Css.matches(Css.selector(text), e) == ok
  end
  @test Css.selector("a::") === nothing && Css.selector("") === nothing
  @test Css.media("screen and (max-width: 600px)", 500) && !Css.media("screen and (max-width: 600px)", 700)
  @test Css.media("print, (min-width: 30em)", 480) && !Css.media("print", 480) && Css.media("not print", 480)
  # A Mac's screen has two pixels to the px
  @test Css.media("(-webkit-min-device-pixel-ratio: 2)", 500) && !Css.media("only screen and (-webkit-min-device-pixel-ratio: 3)", 500)
end

@testset "the style of each element" begin
  doc = Dom.document("""<!DOCTYPE html><style>
    p { color: red; margin: 1em 2px } .a { color: green } p.a { color: blue !important } #x { color: black }
    .btn { background: #06c url(x.png) no-repeat center / cover; border: 1px solid rgba(0,0,0,.5); border-radius: 4px 8px;
           font: bold 14px/1.4 "Helvetica Neue", Arial, sans-serif; padding: 1em 20px; width: calc(100% - 2em) }
    @media (max-width: 300px) { p { display: none } }</style>
    <p id="x" class="a" style="color: orange; margin-top: 5px">Hi <b id="b">there</b></p>
    <table id="t" width="600" cellpadding="10" cellspacing="0" border="1" align="center"><tr><td id="d" bgcolor="ff0000" width="50%" align="center" valign="top">one<a id="l" class="btn" href="x">Go</a></td></tr></table>
    <h1 id="h"><font id="f" size="2" color="navy" face="Georgia">small</font></h1>""")
  look = Styles.styles(doc, 700)
  s(id) = look[named(doc, id)]
  # !important wins over the element's own style, which wins over an id
  @test s("x").color == 0xff0000ff && s("x").display == :block
  @test Styles.px(s("x").margin[1]) == 5 && Styles.px(s("x").margin[2]) == 2 && Styles.px(s("x").margin[3]) == 16
  @test s("b").color == 0xff0000ff && s("b").weight == 700 && s("b").display == :inline   # a child takes its parent's colour
  @test Styles.styles(doc, 300)[named(doc, "x")].display == :none
  # What a tag says: a table's width, its border round each cell, and its cells' padding
  t, d = s("t"), s("d")
  @test Styles.px(t.width) == 600 && all(Styles.isauto, (t.margin[2], t.margin[4])) && Styles.border(t, 1) == 1
  @test d.background == 0xffff0000 && d.width.pct == 0.5 && d.align == :wk_center && d.valign[1] == :top
  @test all(i -> Styles.px(d.padding[i]) == 10 && Styles.border(d, i) == 1, 1:4)
  # A property that stands for several
  l = s("l")
  @test l.background == 0xff0066cc && l.image == ["url(x.png)"] && l.repeat == [(:no_repeat, :no_repeat)] && l.bgsize == [:cover]
  @test l.weight == 700 && l.size == 14 && l.lineheight == (:number, 1.4) && l.family == ["Helvetica Neue", "Arial", "sans-serif"]
  @test map(x -> Styles.px(x), l.radius) == (4, 8, 4, 8) && Styles.border(l, 3) == 1 && l.bordercolor[1] == 0x80000000
  @test Styles.px(l.padding[1]) == 14 && l.width.pct == 1 && l.width.px == -28   # an em is 14 px here
  @test l.lines == 0x01 && l.color == 0xff0000ee                                  # a link is blue, with a line under it
  @test s("h").size == 32 && s("f").size == 13 && s("f").color == 0xff000080 && s("f").family == ["Georgia"]
  # Colours and lengths
  @test Styles.colour("#abc") == 0xffaabbcc && Styles.colour("rgb(255, 0, 0)") == 0xffff0000 && Styles.colour("hsl(120, 100%, 50%)") == 0xff00ff00
  @test Styles.colour("transparent") == 0x00000000 && Styles.colour("nonsense") === nothing && Styles.colour("fff"; loose=true) == 0xffffffff
  c = Styles.Context(700.0, 16.0, false)
  @test Styles.len("12pt", c).px == 16 && Styles.len("50%", c).pct == 0.5 && Styles.len("auto", c).auto && Styles.len("12", c) === nothing
  @test Styles.len("12", Styles.Context(700.0, 16.0, true)).px == 12   # a page with no doctype takes a bare number as px
  @test (l = Styles.len("calc((100% - 40px) / 2)", c); l.pct == 0.5 && l.px == -20)
  # A table takes no centring from a tag round it, but takes `text-align: center`
  doc = Dom.document("""<!DOCTYPE html><table><td align="center"><table id="in"><td id="c">x</table></table><div style="text-align:center"><table><td id="k">y</table></div>""")
  look = Styles.styles(doc, 700)
  @test look[named(doc, "c")].align == :start && look[named(doc, "k")].align == :center
end

@testset "blocks and margins" begin
  p = laid("""<!DOCTYPE html><body style="margin:0"><div id="a" style="height:10px;margin-bottom:20px"></div>
    <div id="b" style="margin-top:30px;padding:5px;border:2px solid;width:50%"><p id="p" style="margin:8px 0;height:4px"></p></div>
    <div id="c" style="width:100px;margin:0 auto;height:1px"></div><div id="d" style="max-width:150px;margin-left:auto;height:1px"></div></body>""")
  a, b, c, d = p.box("a"), p.box("b"), p.box("c"), p.box("d")
  @test (a.y, a.width, a.height) == (0, 400, 10)
  @test b.y == 40                                    # the bigger of the two margins, not their sum
  @test b.width == 214 && b.height == 4 + 2 * 8 + 14   # half the page, with the padding and the border round it
  @test p.box("p").y == 15 && p.box("p").x == 7      # the padding keeps the paragraph's margin inside
  @test place(p.root, c)[1] == 150 && place(p.root, d)[1] == 250
  # The margin of the first thing in a block is over the block when nothing is between them
  p = laid("""<!DOCTYPE html><body style="margin:0"><div id="o" style="background:red"><h1 id="h" style="margin:25px 0;font-size:10px;line-height:10px">x</h1></div><p id="n" style="margin:10px 0">y</p></body>""")
  @test place(p.root, p.box("o"))[2] == 25 && p.box("o").height == 10 && place(p.root, p.box("n"))[2] == 60
  @test p.tall == 60 + p.box("n").height + 10
  # In a page with no doctype, a paragraph that starts a cell has no margin over it, and one that ends it has none under it
  cell(doctype) = laid("""$doctype<table cellpadding="0" cellspacing="0"><td id="c"><p style="line-height:20px">a</p><p style="line-height:20px">b</p></table>""").box("c")
  @test cell("").height == 56 && cell("<!DOCTYPE html>").height == 88
end

@testset "lines of text" begin
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica"><p id="p" style="margin:0;width:120px">one two three four five six seven</p>
    <p id="c" style="margin:0;text-align:center;width:200px">mid</p><p id="n" style="margin:0;white-space:nowrap;width:50px">one two three four</p>
    <p id="b" style="margin:0">a<br>b<br><br>c</p><p id="w" style="margin:0;width:60px;overflow-wrap:break-word">aaaaaaaaaaaaaaaaaaaaaaaaaaaa</p></body>""")
  lines = p.box("p").lines
  words(line) = strip(join(String(q.chars) for q in line.pieces if q.kind == :text))
  @test length(lines) > 1 && join(words.(lines), " ") == "one two three four five six seven"
  @test all(l -> l.height == 20, lines) && p.box("p").height == 20 * length(lines)
  @test all(l -> sum(q.width for q in l.pieces) <= 120, lines)   # a space that ends a line takes no room
  mid = p.box("c").lines[1].pieces[1]
  @test isapprox(mid.x + mid.width / 2, 100; atol=0.01)
  @test length(p.box("n").lines) == 1 && length(p.box("b").lines) == 4 && p.box("b").lines[3].height == 20
  @test length(p.box("w").lines) > 2 && all(l -> sum(q.width for q in l.pieces) <= 60, p.box("w").lines)
  # A box in a line: an inline-block is as wide as its content, and stands on the line of the text
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica">a <span id="i" style="display:inline-block;padding:10px;border:1px solid">in</span> <img id="g" width="30" height="40"> z</body>""")
  i, g = p.box("i"), p.box("g")
  @test i.atomic && i.height == 42 && 22 < i.width < 60 && (g.width, g.height) == (30, 40)
  line = p.root.children[1].lines[1]
  @test line.height > 40 && isapprox(g.y + g.height, line.y + line.baseline; atol=0.01)   # a picture stands on the line
  # A cell that holds only a picture is as tall as the picture, unless the page is of today's kind
  gap(doctype) = laid("""$doctype<table cellpadding="0" cellspacing="0"><td id="c"><img width="30" height="40"></table>""").box("c").height
  @test gap("") == 40 && gap("<!DOCTYPE html>") > 40
  # A picture is as wide as its style says, and no wider than the box that it's in
  p = laid("""<!DOCTYPE html><body style="margin:0"><div style="width:100px"><img id="g" width="300" height="150" style="max-width:100%;height:auto;display:block"></div>""")
  @test (p.box("g").width, p.box("g").height) == (100, 50)
end

@testset "floats" begin
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica"><div id="l" style="float:left;width:100px;height:50px"></div>
    <div id="r" style="float:right;width:80px;height:30px"></div><p id="p" style="margin:0">one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen</p>
    <div id="c" style="clear:both;height:5px"></div></body>""")
  @test place(p.root, p.box("l")) == (0, 0) && place(p.root, p.box("r")) == (320, 0)
  lines = p.box("p").lines
  @test lines[1].pieces[1].x == 100 && lines[end].y >= 40      # text is beside the floats
  @test sum(q.width for q in lines[1].pieces) <= 220 && lines[1].y == 0
  @test place(p.root, p.box("c"))[2] >= 50                    # what clears them is under them
  # A table with `align` is a float, and the next one is beside it
  p = laid("""<!DOCTYPE html><body style="margin:0"><table id="a" align="left" width="150" cellspacing="0" cellpadding="0"><td height="20"></table><table id="b" align="left" width="150" cellspacing="0" cellpadding="0"><td height="20"></table></body>""")
  @test place(p.root, p.box("a")) == (0, 0) && place(p.root, p.box("b")) == (150, 0) && p.tall == 20
end

@testset "tables" begin
  p = laid("""<!DOCTYPE html><body style="margin:0"><table id="t" width="400" cellspacing="0" cellpadding="0"><tr>
    <td id="a" width="100" height="30"></td><td id="b" width="25%"></td><td id="c"></td></tr><tr><td id="d" colspan="2" height="10"></td><td id="e"></td></tr></table></body>""")
  a, b, c, d, e = (p.box(id) for id in ("a", "b", "c", "d", "e"))
  @test (a.width, b.width, c.width) == (100, 100, 200) && d.width == 200 && e.width == 200
  @test a.height == 30 && c.height == 30 && d.height == 10 && p.box("t").height == 40
  @test place(p.root, c) == (200, 0) && place(p.root, e) == (200, 30)
  # The room between cells, the padding in them, and a table that's centred
  p = laid("""<!DOCTYPE html><body style="margin:0"><table id="t" width="200" align="center" cellspacing="5" cellpadding="3"><tr><td id="a" height="10"></td><td id="b"></td></tr></table></body>""")
  @test place(p.root, p.box("t")) == (100, 0) && p.box("t").height == 26
  @test place(p.root, p.box("a")) == (105, 5) && p.box("a").width + p.box("b").width == 185
  # A table with no width is as wide as its content, and no wider than the page
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica"><table id="s" cellspacing="0" cellpadding="0"><td>short</td></table>
    <table id="w" cellspacing="0" cellpadding="0"><td>$(repeat("word ", 200))</td></table></body>""")
  @test 20 < p.box("s").width < 80 && p.box("w").width == 400
  # What's in a cell is in its middle, unless the cell says otherwise
  p = laid("""<!DOCTYPE html><body style="margin:0"><table cellspacing="0" cellpadding="0"><tr><td height="100"></td>
    <td><div id="m" style="height:20px;width:5px"></div></td><td valign="top"><div id="t" style="height:20px;width:5px"></div></td>
    <td valign="bottom"><div id="b" style="height:20px;width:5px"></div></td></tr></table></body>""")
  @test [place(p.root, p.box(id))[2] for id in ("m", "t", "b")] == [40, 0, 80]
  # A cell takes no greatest height, and a cell is at least as wide as its least width
  p = laid("""<!DOCTYPE html><body style="margin:0"><table width="300" cellspacing="0" cellpadding="0"><tr><td id="g" style="min-width:32px;width:32px"></td>
    <td id="h" height="58" style="width:100%;max-height:1px"></td></tr></table></body>""")
  @test p.box("g").width == 32 && p.box("h").width == 268 && p.box("h").height == 58
end

@testset "a page to draw" begin
  html = """<!DOCTYPE html><body style="margin:10px;font:16px/20px Helvetica;background:#eee">
    <p style="margin:0">Go to <a href="https://example.com/a">the site</a> or <a href="mailto:sam@example.com">write</a>.<br>Next line</p>
    <table cellspacing="0" cellpadding="0"><tr><td>one</td><td>two</td></tr></table>
    <a href="https://example.com/block" style="display:block;width:100px;height:30px;background:blue"></a><a href="javascript:x()">no</a></body>"""
  p = Web.page(html; wide=400)
  @test p.wide == 400 && p.tall == 10 + 40 + 20 + 30 + 20 + 10
  @test [l.url for l in p.links] == ["https://example.com/a", "mailto:sam@example.com", "https://example.com/block"]
  a = p.links[1]
  @test a.top == 11 && a.tall == 18 && a.left > 40 && Web.link(p, a.left + 1, 15) === a && Web.link(p, a.left - 2, 15) === nothing
  @test (p.links[3].left, p.links[3].top, p.links[3].wide, p.links[3].tall) == (10, 70, 100, 30)
  # The words, as they're copied: a new line between two lines of the page, and a tab between two cells of a row
  @test join(w.before * String(w.letters) for w in p.words) == "Go to the site or write.\nNext line\none\ttwo\nno"
  @test p.words[1].from == 0 && p.words[2].from == length(p.words[1].letters) && all(w -> length(w.edges) == length(w.letters) + 1, p.words)
  @test p.list.background == 0xffeeeeee
  # Twice as big: the page is as wide, and its words wrap sooner
  big = Web.page(html; wide=400, zoom=2.0)
  @test big.wide == 400 && big.tall > 2 * 150 - 60 && big.links[3].wide == 200
  # A picture of the page
  dir = mktempdir()
  @test filesize(Web.save(p, joinpath(dir, "page.png"))) > 1000
  # A picture that's written into the page is drawn at its own size. One from the web is asked for, and is an empty box without it.
  dot = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAE0lEQVR42mP8z8DAwMDAxIBMAQAUQAEFadK16wAAAABJRU5ErkJggg=="
  asked = String[]
  p = Web.page("""<!DOCTYPE html><body style="margin:0"><img src="$dot" style="display:block"><img src="https://example.com/x.png" width="20" height="10" style="display:block"></body>""";
               wide=100, load=src -> (push!(asked, src); nothing))
  @test p.tall == 13 && asked == ["https://example.com/x.png"]
  # A photo with the Display P3 colour profile, as an iPhone saves one, is read as sRGB: 2×2 pixels of #F38020.
  # Its own numbers are (228,134,59), and they'd look dull if they were kept as they are.
  _, _, made = Web.decode(base64decode("iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAABY2lDQ1BrQ0dDb2xvclNwYWNlRGlzcGxheVAzAAAokX2QsUvDUBDGv1aloHUQHRwcMolDlJIKuji0FURxCFXB6pS+pqmQxkeSIgU3/4GC/4EKzm4Whzo6OAiik+jm5KTgouV5L4mkInqP435877vjOCA5bnBu9wOoO75bXMorm6UtJfWMBL0gDObxnK6vSv6uP+P9PvTeTstZv///jcGK6TGqn5QZxl0fSKjE+p7PJe8Tj7m0FHFLshXyieRyyOeBZ71YIL4mVljNqBC/EKvlHt3q4brdYNEOcvu06WysyTmUE1jEDjxw2DDQhAId2T/8s4G/gF1yN+FSn4UafOrJkSInmMTLcMAwA5VYQ4ZSk3eO7ncX3U+NtYMnYKEjhLiItZUOcDZHJ2vH2tQ8MDIEXLW54RqB1EeZrFaB11NguASM3lDPtlfNauH26Tww8CjE2ySQOgS6LSE+joToHlPzA3DpfAEDp2ITpJYOWwAAAARjSUNQDA0AAW4D4+8AAAA4ZVhJZk1NACoAAAAIAAGHaQAEAAAAAQAAABoAAAAAAAKgAgAEAAAAAQAAAAKgAwAEAAAAAQAAAAIAAAAAztCekAAAABNJREFUCB1jfNJmzcDAwATEQAAAFI8Bqa3DfC0AAAAASUVORK5CYII="))
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_UNPREMUL, 1, 1))
  rgba = zeros(UInt8, 4)
  GC.@preserve info rgba Skia.sk_image_read_pixels(made, pointer_from_objref(info), pointer(rgba), Csize_t(4), Cint(0), Cint(0), Skia.sk_image_caching_hint_t(0))
  @test all(abs.(Int.(rgba[1:3]) .- [243, 128, 32]) .<= 1)
  # A page that's wider than its window is made to fit, when that's asked for
  wide = """<!DOCTYPE html><body style="margin:0"><table width="900" cellspacing="0" cellpadding="0"><td><img width="900" height="300" style="display:block"></td></table></body>"""
  @test Web.page(wide; wide=300).tall == 300 && Web.page(wide; wide=300, fit=true).tall == 100 && Web.page(wide; wide=300, fit=true).wide == 300
end

near(a, b; by=0.01) = abs(a - b) <= by
"The words of a page as they're copied"
copied(p) = join(w.before * String(w.letters) for w in p.words)

@testset "CSS of today" begin
  # A rule in a rule, with & and without. The parts of an element. What a rule can ask of the elements round it.
  css = Css.Stylesheet(supports=Styles.known)
  Css.read!(css, """.card { color: red; &:first-child { margin: 0 } .title { color: blue } @media (width >= 500px) { padding: 1px } }
    @layer base, top; @layer top { a { color: red } } @layer base { a { color: blue } }
    li:nth-child(2 of .pick), p:is(.a, .b):not(.c), div:has(> img), :where(.x) b, h1::before, q::after { top: 0 }
    @supports (display: grid) { .g { display: grid } } @supports (display: nonsense) { .n { top: 0 } } @supports not (color: light-dark(red, red)) { .o { top: 0 } }
    @container side (min-width: 300px) { .c { top: 0 } } .q { quotes: "\\"" "'" } .after { top: 1px }
    @font-face { font-family: F; src: url(f.woff2) } @keyframes show { from { opacity: 0 } to { opacity: 1 } } @property --p { syntax: "*"; inherits: false; initial-value: 4px }""")
  texts = [(length(r.selector.parts), r.selector.weight, r.selector.pseudo) for r in css.rules]
  @test count(r -> !isempty(r.media), css.rules) == 1 && css.layers == ["base", "top"] && length(css.faces) == 1 && haskey(css.frames, "show") && css.props["--p"] == "4px"
  @test (1, (0, 0, 2), :before) in texts && (1, (0, 0, 2), :after) in texts && (2, (0, 0, 1), :none) in texts   # h1::before, q::after, :where(.x) b
  @test any(r -> r.container == ["side (min-width: 300px)"], css.rules) && !any(r -> any(d -> d.name == "top" && r.selector.parts[1].classes == ["n"], r.declarations), css.rules)
  @test any(r -> r.selector.parts[1].classes == ["after"], css.rules)   # a quote after a backslash ends no string
  doc = Dom.document("""<div class="card" id="c1"><span class="title" id="t">x</span></div><div class="card" id="c2"><img></div>
    <ul><li id="l1">a<li class="pick" id="l2">b<li class="pick" id="l3">c</ul><p class="a c" id="p1">x</p><p class="b" id="p2">y</p>""")
  for (text, id, ok) in [(".card:first-child", "c1", true), (".card:first-child", "c2", false), (".card .title", "t", true), ("li:nth-child(2 of .pick)", "l3", true),
                         ("li:nth-child(2 of .pick)", "l2", false), ("p:is(.a, .b):not(.c)", "p2", true), ("p:is(.a, .b):not(.c)", "p1", false), ("div:has(> img)", "c2", true),
                         ("div:has(> img)", "c1", false), ("li:nth-last-of-type(1)", "l3", true), ("p:only-of-type", "p1", false), ("#c1:has(+ .card)", "c1", true)]
    @test Css.matches(Css.selector(text), named(doc, id)) == ok
  end
  # What a rule asks of the window, in each way to write it
  @test Css.media("(width >= 500px)", 600) && !Css.media("(width > 600px)", 600) && Css.media("(400px <= width < 700px)", 600) && Css.media("(width < calc(30rem + 200px))", 600)
  @test Css.media("(min-width: 500px) and (max-height: 900px)", 600, 800) && !Css.media("(orientation: portrait)", 600, 400) && Css.media("not (hover: none)", 600) &&
        Css.media("(prefers-reduced-motion: no-preference) or (width < 100px)", 600)
  @test Css.container("side (min-width: 300px)", 320, 100) && !Css.container("(min-width: 300px)", 200, 100) && Css.container_name("side (min-width: 300px)") == "side"
  @test Css.resolve("https://x.org/a/b.html", "../c/d.png?x=1") == "https://x.org/c/d.png?x=1" && Css.resolve("https://x.org/a/b.html", "//y.org/z") == "https://y.org/z" &&
        Css.resolve("https://x.org/a/b.html", "e.css") == "https://x.org/a/e.css" && Css.resolve("", "e.css") == "e.css" && Css.resolve("https://x.org/a/", "data:x") == "data:x"
end

@testset "variables, sums and colours" begin
  doc = Dom.document("""<!DOCTYPE html><style>:root { --gap: 8px; --brand: #06c; --twice: calc(var(--gap) * 2) } @layer low { p { color: red } } p { color: green }
    #a { padding: var(--twice) var(--none, 3px); width: min(100%, 300px); margin-left: clamp(10px, 5vw, 20px); color: var(--brand); height: max(1em, 30px); border: 1px solid }
    #b { --gap: 2px; margin: var(--gap); font-size: 20px; text-indent: calc(1em + 4px); color: color-mix(in srgb, red, blue) }
    #c { animation: show 1s forwards; opacity: 0 } @keyframes show { to { opacity: 0.5 } } #d { all: unset; color: revert }
    #e { inset: 1px 2px; margin-inline: 4px 6px; padding-block: 7px; inline-size: 50px; border-start-start-radius: 3px; overflow: hidden auto; flex: 2 1 10px; gap: 5px 9px }
    </style><p id="a"></p><p id="b"></p><p id="c"></p><p id="d" style="margin:9px"></p><div id="e"></div>""")
  look = Styles.styles(doc, 300; high=600)
  s(id) = look[named(doc, id)]
  a, b, e = s("a"), s("b"), s("e")
  @test map(Styles.px, a.padding) == (16, 3, 16, 3) && Styles.px(a.width, 1000) == 300 && Styles.px(a.width, 200) == 200 && Styles.px(a.margin[4]) == 15 && Styles.px(a.height) == 30
  @test a.color == 0xff0066cc && a.bordercolor[1] == 0xff0066cc    # the border takes the text's colour
  @test Styles.px(b.margin[1]) == 2 && Styles.px(b.indent) == 24 && b.color == 0xff800080 && s("c").opacity == 0.5   # an animation that ends and stays is shown as it ends
  @test s("d").display == :inline && Styles.px(s("d").margin[1]) == 9   # `all: unset` leaves the element's own style
  @test map(Styles.px, e.inset) == (1, 2, 1, 2) && Styles.px(e.margin[4]) == 4 && Styles.px(e.margin[2]) == 6 && Styles.px(e.padding[1]) == 7 && Styles.px(e.width) == 50
  @test Styles.px(e.radius[1]) == 3 && e.overflow == :hidden && (e.grow, e.shrink, Styles.px(e.basis)) == (2, 1, 10) && map(Styles.px, e.gap) == (5, 9)
  @test s("a").color != 0xffff0000 && look[tagged(doc, "p")].color == 0xff0066cc   # a rule in no layer wins over one in a layer, and the id over both
  for (text, want) in [("rgb(255 0 0 / 50%)", 0x80ff0000), ("hsl(120deg 100% 50%)", 0xff00ff00), ("hwb(0 0% 0%)", 0xffff0000), ("oklch(100% 0 0)", 0xffffffff),
                       ("lab(0 0 0)", 0xff000000), ("color(srgb 0 0 1)", 0xff0000ff), ("light-dark(red, blue)", 0xffff0000), ("rgb(from blue r g 0)", 0xff000000),
                       ("#0f08", 0x8800ff00), ("color-mix(in srgb, white 25%, black)", 0xff404040), ("canvastext", 0xff000000)]
    @test Styles.colour(text) == want
  end
  c = Styles.Context(1000.0, 16.0, false, 500.0)
  @test Styles.len("10vh", c).px == 50 && Styles.len("calc(2 * (1rem + 4px))", c).px == 40 && Styles.len("min(10px, 5px)", c).px == 5 && Styles.len("round(up, 13px, 5px)", c).px == 15
  @test Styles.px(Styles.len("max(50%, 100px)", c), 400) == 200 && Styles.ispercent(Styles.len("clamp(1px, 50%, 9px)", c)) && Styles.len("fit-content", c) === nothing
end

@testset "flex boxes" begin
  p = laid("""<!DOCTYPE html><body style="margin:0"><div id="f" style="display:flex;width:300px;gap:10px"><div id="a" style="width:50px;height:20px"></div>
    <div id="b" style="flex:1;height:40px"></div><div id="c" style="flex:2"></div></div>
    <div id="w" style="display:flex;flex-wrap:wrap;width:300px;gap:10px"><div style="width:120px;height:10px"></div><div style="width:120px;height:30px"></div><div id="w3" style="width:120px;height:10px"></div></div>
    <div id="j" style="display:flex;justify-content:space-between;width:300px"><div style="width:50px;height:5px"></div><div id="j2" style="width:50px"></div><div id="j3" style="width:50px"></div></div>
    <div id="m" style="display:flex;justify-content:center;align-items:center;width:300px;height:100px"><div id="m1" style="width:50px;height:20px"></div></div>
    <div id="k" style="display:flex;flex-direction:column;width:300px;gap:4px;align-items:flex-end"><div style="height:20px;width:10px"></div><div id="k2" style="height:30px;width:40px"></div></div>
    <div id="o" style="display:flex;width:300px"><div id="o1" style="width:40px;height:5px"></div><div id="o2" style="width:60px;order:-1"></div><div id="o3" style="width:20px;margin-left:auto"></div></div>
    <div id="s" style="display:flex;width:300px"><div id="s1" style="flex:0 1 200px;height:5px"></div><div id="s2" style="flex:0 1 200px;align-self:flex-end;height:2px"></div></div>
    <div id="r" style="display:flex;flex-direction:row-reverse;width:300px"><div id="r1" style="width:40px;height:5px"></div><div id="r2" style="width:60px"></div></div></body>""")
  at(id) = place(p.root, p.box(id))
  @test at("a") == (0, 0) && p.box("a").height == 20 && near(p.box("b").width, 230 / 3) && near(p.box("c").width, 460 / 3) && near(at("c")[1], 60 + 230 / 3 + 10)
  @test p.box("c").height == 40 && p.box("f").height == 40                    # a thing with no height is as tall as its line
  @test at("w3") == (0, at("w")[2] + 30 + 10) && p.box("w").height == 50        # what doesn't fit goes to the next line
  @test at("j2")[1] == 125 && at("j3")[1] == 250 && at("m1") == (125, at("m")[2] + 40)
  @test at("k2") == (260, at("k")[2] + 24) && p.box("k").height == 54
  @test at("o2")[1] == 0 && at("o1")[1] == 60 && at("o3")[1] == 280             # `order` and a margin that's `auto`
  @test p.box("s1").width == 150 && p.box("s2").width == 150 && at("s2")[2] == at("s")[2] + 3   # both shrink to fit
  @test at("r1")[1] == 260 && at("r2")[1] == 200
  # A flex box in a line of text is as wide as what's in it, and a box with a least height shares that height out
  p = laid("""<!DOCTYPE html><body style="margin:0"><span id="i" style="display:inline-flex;gap:5px"><span style="width:20px;height:10px"></span><span style="width:30px"></span></span>
    <div id="c" style="display:flex;flex-direction:column;min-height:200px"><div id="h" style="height:30px"></div><div id="g" style="flex:1"></div><div id="t" style="height:20px"></div></div></body>""")
  @test p.box("i").width == 55 && p.box("g").height == 150 && place(p.root, p.box("t"))[2] == place(p.root, p.box("c"))[2] + 180
  # A drawing is no narrower than its size, though its style cuts off what's outside it. So a button with an icon keeps its padding in a row
  # that's too full, and the box beside it, which has a width and nothing in it, gives up the room.
  p = laid("""<!DOCTYPE html><body style="margin:0"><div style="display:flex;width:100px"><div id="a" style="width:90px;height:5px"></div>
    <a id="n" style="display:inline-flex;gap:5px;padding:0 10px"><svg width="16" height="16"></svg><span style="width:30px"></span></a></div></body>""")
  @test p.box("n").width == 71 && p.box("a").width == 29
end

@testset "grids" begin
  p = laid("""<!DOCTYPE html><body style="margin:0"><div id="g" style="display:grid;width:300px;grid-template-columns:100px 1fr 2fr;gap:10px">
    <div id="a" style="height:20px"></div><div id="b"></div><div id="c"></div><div id="d" style="height:5px"></div></div>
    <div id="f" style="display:grid;width:300px;grid-template-columns:repeat(auto-fill, minmax(90px, 1fr));gap:10px"><div id="f1" style="height:1px"></div><div></div><div></div><div id="f4"></div></div>
    <div id="s" style="display:grid;width:300px;grid-template-columns:repeat(4, 1fr)"><div id="s1" style="grid-column:span 2;height:10px"></div><div id="s2" style="grid-column:2 / 5;grid-row:2;height:10px"></div>
      <div id="s3" style="grid-area:1 / 4;height:1px"></div></div>
    <div id="t" style="display:grid;width:300px;grid-template-columns:100px 1fr;grid-template-areas:'h h' 's m';gap:10px"><div id="tm" style="grid-area:m;height:30px"></div>
      <div id="th" style="grid-area:h;height:20px"></div><div id="ts" style="grid-area:s"></div></div>
    <div id="p" style="display:grid;width:300px;grid-template-columns:100px 100px;grid-auto-rows:50px;justify-content:center"><div id="p1" style="width:20px;height:10px;justify-self:end;align-self:center"></div></div>
    <div id="x" style="display:grid;grid-auto-flow:column;grid-template-rows:10px 10px;width:300px"><div></div><div id="x2"></div><div id="x3"></div></div></body>""")
  at(id) = place(p.root, p.box(id))
  @test p.box("a").width == 100 && near(p.box("b").width, 60) && near(p.box("c").width, 120) && near(at("b")[1], 110) && near(at("c")[1], 180)
  @test at("d") == (0, 30) && p.box("b").height == 20 && p.box("g").height == 35    # a thing fills its row, and the next row is under the gap
  @test near(p.box("f1").width, 280 / 3) && at("f4")[1] == 0 && at("f4")[2] == at("f")[2] + 11
  @test p.box("s1").width == 150 && at("s2")[1] == 75 && p.box("s2").width == 225 && at("s3")[1] == 225 && at("s2")[2] == at("s")[2] + 10
  @test p.box("th").width == 300 && at("tm") == (110, at("t")[2] + 30) && at("ts")[1] == 0 && p.box("ts").height == 30
  @test at("p1") == (50 + 80, at("p")[2] + 20)
  @test at("x2") == (0, at("x")[2] + 10) && at("x3") == (150, at("x")[2])            # down the columns
end

@testset "boxes with a place of their own" begin
  p = laid("""<!DOCTYPE html><body style="margin:0"><div id="r" style="position:relative;width:200px;height:100px">
    <div id="a" style="position:absolute;right:10px;bottom:5px;width:30px;height:20px"></div><div id="b" style="position:absolute;inset:0;margin:auto;width:50px;height:20px"></div>
    <div id="c" style="position:absolute;left:10px;right:10px;top:0;bottom:50%"></div><div id="d" style="position:absolute;left:50%;top:10px;width:10px;height:10px"></div></div>
    <p style="margin:0;height:20px"></p><div id="s" style="position:absolute;width:5px;height:5px"></div></body>""")
  at(id) = place(p.root, p.box(id))
  @test at("a") == (160, 75) && at("b") == (75, 40) && (p.box("c").width, p.box("c").height) == (180, 50) && at("d") == (100, 10)
  @test p.box("s").still == (true, true)                                         # with no side given, it stays where the text has it
  # In a flex box or a grid, it stays where it would be as the only thing there. Each place here is WebKit's.
  spot(box, kid="") = (q = Web.page("""<!DOCTYPE html><body style="margin:0"><div style="$box;position:relative;height:40px;width:200px;padding:3px;border:2px solid">
    <a href="https://a.test/" style="position:absolute;width:10px;height:10px;display:block;$kid"></a><span>x</span></div></body>"""; wide=400); (q.links[1].left, q.links[1].top))
  @test spot("display:flex;align-items:center", "left:10px") == (12, 20) && spot("display:flex;align-items:center", "margin:5px") == (10, 20)   # the icon of a search field
  @test spot("display:flex;justify-content:flex-end;align-items:flex-end") == (195, 35) && spot("display:flex;flex-direction:row-reverse") == (195, 5)
  @test spot("display:flex;flex-direction:column;justify-content:center") == (5, 20) && spot("display:flex;flex-wrap:wrap-reverse") == (5, 35)
  @test spot("display:flex;justify-content:space-around;align-items:end") == (100, 35) && spot("display:flex", "align-self:center") == (5, 20)
  @test spot("display:grid") == (2, 2) && spot("display:grid;place-items:end") == (198, 38) && spot("display:grid", "justify-self:center;align-self:end") == (100, 38)   # in a grid's padding
  @test spot("display:block") == (5, 5)
  # In a window, the page's height in percent is the window's, and a box that's fixed is placed in the window
  html = """<!DOCTYPE html><html style="height:100%"><body style="height:100%;margin:0"><div style="height:50%;background:#010203"></div>
    <div style="position:fixed;bottom:0;left:0;width:20px;height:10px;background:#040506"></div><div style="position:absolute;top:30px;width:1px;height:1px;background:#070809"></div></body></html>"""
  fills(q) = [(i.color, i.y, i.h) for i in q.list.items if i isa Paint.Fill]
  q = Web.page(html; wide=300, high=400)
  @test q.tall == 400 && (0xff010203, 0.0, 200.0) in fills(q) && (0xff040506, 390.0, 10.0) in fills(q)
  @test Web.page(html; wide=300).tall < 100                                        # with no window, the page is as tall as what's in it
  @test Web.page("""<!DOCTYPE html><body style="margin:0;min-height:100vh"><div style="height:10px"></div></body>"""; wide=300, high=250).tall == 250
  # What's drawn first: a z-index under 0, then the text's boxes, then the boxes with a place, by their z-index
  q = Web.page("""<!DOCTYPE html><body style="margin:0"><div style="position:relative;height:40px"><div style="position:absolute;z-index:2;inset:0;background:#000002"></div>
    <div style="position:absolute;z-index:-1;inset:0;background:#000001"></div><div style="height:10px;background:#000003"></div>
    <div style="position:absolute;inset:0;background:#000004"></div><div style="float:left;width:5px;height:5px;background:#000005"></div></div></body>"""; wide=100)
  @test [c & 0xff for (c, _, _) in fills(q)] == [1, 3, 5, 4, 2]
  # A box that's see-through, turned or blurred is one piece: the list says so
  q = Web.page("""<!DOCTYPE html><body style="margin:0"><div style="opacity:.5;transform:rotate(10deg);filter:blur(2px);width:50px;height:20px;background:red"><a href="https://x.org/">go</a></div>
    <div style="clip-path:circle(40%);mask-image:linear-gradient(black, transparent);width:50px;height:20px;background:linear-gradient(red, blue)"></div></body>"""; wide=200)
  kinds = [typeof(i).name.name for i in q.list.items]
  @test :Move in kinds && :Layer in kinds && :Clip in kinds && :Backing in kinds && count(==(:Layer), kinds) == count(==(:Unlayer), kinds)
  @test length(q.links) == 1 && q.links[1].wide > 5                              # a link that's turned is where it's drawn
  @test filesize(Web.save(q, joinpath(mktempdir(), "pieces.png"))) > 500
end

@testset "what CSS makes" begin
  p = Web.page("""<!DOCTYPE html><style>body { margin: 0; counter-reset: n } h2 { counter-increment: n; margin: 0 } h2::before { content: counter(n) ". " }
    q { quotes: "<" ">" } .x::after { content: " [" attr(data-k) "]" } .u { text-transform: uppercase } li::marker { color: red }</style>
    <h2>A</h2><h2 class="x" data-k="7">B</h2><p style="margin:0"><q>hi <q>in</q></q> <span class="u">up</span></p>
    <details><summary>S</summary><p>hidden</p></details><details open><summary>T</summary>shown</details>"""; wide=300)
  @test copied(p) == "1. A\n2. B [7]\n<hi <in>> UP\n▶ S\n▼ T\nshown"   # the last pair of quotes is for every level under it
  l = laid("""<!DOCTYPE html><ol reversed><li id="a">x<li id="b">y</ol><ol type="i" start="3"><li id="c">z<li id="d" value="9">w</ol><ul style="list-style:'- '"><li id="e">v</ul>
    <ol style="list-style-type:lower-greek"><li id="f">u</ol>""")
  @test [l.box(id).marker for id in ("a", "b", "c", "d", "e", "f")] == ["2.", "1.", "iii.", "ix.", "- ", "α."]
  # Small capitals are the big letters of a smaller size, and a picture can name a file for each kind of screen
  l = laid("""<!DOCTYPE html><p id="p" style="font-variant:small-caps;font-size:20px">Ab</p>""")
  @test [(k.text, k.style.size) for k in l.box("p").children] == [("A", 20.0), ("B", 14.0)]
  asked = String[]
  Web.page("""<!DOCTYPE html><picture><source srcset="big.webp" media="(min-width: 900px)"><img src="a.png" srcset="a.png 1x, b.png 2x"></picture>"""; wide=300,
           load=src -> (push!(asked, src); nothing), base="https://x.org/dir/page.html")
  @test asked == ["https://x.org/dir/b.png"]
end

@testset "fonts of several widths" begin
  # How `font-stretch` and the `font` shorthand say how wide the letters are
  doc = Dom.document("""<body><p id=a style="font-stretch:78%">x<b id=b>y</b></p><p id=c style="font-stretch:condensed"></p>
    <p id=d style="font: condensed bold 12px Helvetica"></p><p id=e style="font-stretch:75%;font: 12px Helvetica"></p></body>""")
  look = Styles.styles(doc, 400)
  @test look[named(doc, "a")].stretch == 78 && look[named(doc, "b")].stretch == 78 && look[named(doc, "c")].stretch == 75
  @test look[named(doc, "d")].stretch == 75 && look[named(doc, "e")].stretch == 100 && look[tagged(doc, "body")].stretch == 100
  # A variable font, with all of its weights and widths in one file, is drawn at the weight and the width asked for. The Mac's
  # own font is one, with axes of weight and width as CSS has them.
  sf = read("/System/Library/Fonts/SFNS.ttf")
  wide(css; face="font-weight: 100 900; font-stretch: 50% 150%") = begin
    d = Dom.document("""<!DOCTYPE html><style>@font-face { font-family: V; src: url(v.ttf); $face } span { font: 40px V; display: inline-block }</style>
      <body><span id=s style="$css">Handgloves</span></body>""")
    p = Web.page(d; wide=800, base="https://t.test/", load=src -> src == "https://t.test/v.ttf" ? sf : nothing)
    k = box(p.root, named(d, "s"))
    (k.style.family[1], k.width, [i for i in p.list.items if i isa Paint.Glyphs])
  end
  family, normal, drawn = wide("")
  @test startswith(family, "web:") && length(drawn) == 1
  @test wide("font-stretch: 75%")[2] < normal - 20 && wide("font-stretch: 125%")[2] > normal + 20 && wide("font-weight: 800")[2] > normal + 10
  # The letters are drawn where they're laid out, in Skia's face of that width
  skia(g) = sum(Paint.drawn(only(g).font, c)[3] for c in "Handgloves")
  _, narrow, glyphs = wide("font-stretch: 60%")
  @test only(glyphs).w ≈ narrow && skia(glyphs) < skia(drawn) - 20
  # A face whose @font-face says no width is only for the normal width, as in a browser
  @test wide("font-stretch: 75%"; face="font-weight: 100 900")[2] ≈ normal
  # A font of the Mac that has a face of another width uses it, like Helvetica Neue's bold condensed face. One that has none keeps its
  # normal face. The system font has an axis of width.
  text(css) = (d = Dom.document("""<body><span id=s style="display:inline-block;font: $css">Handgloves</span></body>"""); box(Web.page(d; wide=800).root, named(d, "s")).width)
  @test text("bold 40px 'Helvetica Neue'; font-stretch: condensed") < text("bold 40px 'Helvetica Neue'") - 20 && text("40px Times; font-stretch: condensed") ≈ text("40px Times")
  @test text("40px system-ui; font-stretch: 75%") < text("40px system-ui") - 20
  # A font can be written into the page as a `data:` address
  lycian = base64encode(read("/System/Library/Fonts/Supplemental/NotoSansLycian-Regular.ttf"))
  d = Dom.document("""<style>@font-face { font-family: L; src: url(data:font/ttf;base64,$lycian) }</style><body><span id=s style="font-family: L">x</span></body>""")
  @test startswith(box(Web.page(d; wide=400).root, named(d, "s")).style.family[1], "web:")
end

@testset "lines picked for the whole paragraph" begin
  # `text-wrap: pretty` picks the lines of a paragraph together, as WebKit does, so that the last line isn't left short. Each
  # paragraph here ends its lines where WebKit ends them, given as the last word of each line, and ordinary lines end elsewhere.
  rba = "On 3 November the RBA <a href='https://x.test/'>raised the cash rate to 4.85%</a>, its fifth hike this year and the highest since 2008. Trimmed mean inflation is 3.6% and unemployment is 4.9%, and both are going up."
  short = "A short paragraph that wraps onto just two lines here."
  ends(text, wide; css="", wrap="pretty") = begin
    p = Web.page("""<!DOCTYPE html><body style="margin:0"><p style="margin:0;width:$(wide)px;font:16px/20px Helvetica;$(css)text-wrap:$wrap">$text</p></body>"""; wide=700)
    tops = Dict{Float64,String}()
    for w in p.words
      tops[round(w.top, digits=1)] = get(tops, round(w.top, digits=1), "") * String(w.letters)
    end
    join([split(tops[k])[end] for k in sort(collect(keys(tops)))], " ")
  end
  @test ends(rba, 340) == "cash and mean unemployment up." && ends(rba, 340; wrap="wrap") == "to highest 3.6% going up."
  @test ends(short, 340) == "just here." && ends(short, 340; wrap="wrap") == "lines here."
  # The shorthand `text-wrap: wrap` puts the ordinary lines back
  @test ends(short, 340; css="text-wrap-style:pretty;", wrap="wrap") == "lines here." && ends(short, 340; css="text-wrap:pretty;", wrap="wrap") == "lines here."
  # The first line's indent counts, and the text on each side of a <br> is picked apart
  @test ends(rba, 260; css="text-indent:2em;") == "RBA its highest inflation is up."
  @test ends(rba * "<br>" * short, 300) == "cash and mean unemployment up. onto here."
end

@testset "text of today" begin
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica"><p id="j" style="margin:0;width:200px;text-align:justify">one two three four five six seven eight nine ten</p>
    <p id="e" style="margin:0;width:80px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">a line that is far too long</p>
    <p id="c" style="margin:0;width:100px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden">one two three four five six seven eight nine ten eleven</p>
    <p id="t" style="margin:0;white-space:pre;tab-size:4;font-family:Menlo">a\tb\nlon\tc</p><p id="r" style="margin:0;direction:rtl">right</p>
    <p id="b" style="margin:0;width:300px;text-wrap:balance">aaaa bbbb cccc dddd eeee ffff gggg hhhh i</p>
    <p id="u" style="margin:0;width:300px">aaaa bbbb cccc dddd eeee ffff gggg hhhh i</p></body>""")
  right(line) = (q = line.pieces[findlast(q -> q.kind == :text && !q.space, line.pieces)]; q.x + q.width)
  lines = p.box("j").lines
  @test length(lines) > 1 && all(l -> near(right(l), 200; by=0.5), lines[1:end-1]) && right(lines[end]) < 190
  e = p.box("e").lines[1]
  @test e.pieces[end].chars == ['…'] && right(e) <= 80.5
  c = p.box("c")
  @test length(c.lines) == 2 && c.height == 40 && c.lines[2].pieces[end].chars == ['…']
  tab(i) = (q = p.box("t").lines[i].pieces; q[end].x + sum(q[end].widths[1:findlast(==(' '), q[end].chars)]))
  @test near(tab(1), tab(2); by=0.1)                                              # the words after a tab start at one place
  @test p.box("r").lines[1].pieces[1].x > 300
  balanced, plain = p.box("b").lines, p.box("u").lines
  @test length(balanced) == length(plain) == 2 && right(balanced[1]) < right(plain[1]) && right(balanced[2]) > right(plain[2])
  # Text in columns: each column of the page is a piece of one tall column
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica"><div id="c" style="columns:2;column-gap:20px;width:320px">$(repeat("word ", 60))</div></body>""")
  cols = p.box("c").cols
  @test cols.wide == 150 && length(cols.starts) == 2 && near(p.box("c").height, cols.ends[end] / 2; by=20) && p.box("c").height < cols.ends[end]
end

@testset "forms and drawings" begin
  p = laid("""<!DOCTYPE html><body style="margin:0"><input id="t" value="v"><input id="c" type="checkbox" checked><select id="s"><option>one<option selected>two</select>
    <button id="b">Go</button><textarea id="a" rows="3" cols="30"></textarea><progress id="p" value="0.25"></progress><input id="h" type="hidden">
    <svg id="v" width="40" height="30"></svg><div style="width:200px"><svg id="w" viewBox="0 0 2 1"></svg></div><fieldset id="f"><legend id="l">L</legend>x</fieldset></body>""")
  @test (p.box("t").width, p.box("t").height) == (155, 21) && p.box("t").children[1].text == "v"    # as big as Safari draws them
  @test (p.box("c").width, p.box("c").height, p.box("c").widget, p.box("c").value) == (12, 12, :checkbox, 1.0)
  @test p.box("s").children[1].text == "two" && p.box("s").widget == :select && p.box("b").height == 18 && p.box("a").width == 222 && near(p.box("a").height, 45; by=0.1)
  @test p.box("p").value == 0.25 && p.box("p").width == 160 && p.box("h") === nothing
  @test (p.box("v").width, p.box("v").height) == (40, 30) && (p.box("w").width, p.box("w").height) == (200, 100)   # a drawing with a shape and no size fills its box
  @test p.box("l").y == 0 && p.box("f").notch[1] > 0                              # the legend is on the line of the fieldset's border
  # A drawing in a file is a picture. One in the page is drawn with the page's styles.
  found = Svg.image(Vector{UInt8}("""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 10" width="40"><defs><linearGradient id="g"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs>
    <rect width="20" height="10" fill="url(#g)"/><path d="M2 2 L8 8" stroke="#000"/><g transform="translate(5 5) rotate(45)"><circle r="2"/></g><text x="10" y="8" font-size="4" text-anchor="middle">Hi</text><use href="#g"/></svg>"""))
  @test found !== nothing && (found[1], found[2]) == (40, 20) && found[3] != C_NULL
  @test Svg.transform("translate(10 20) scale(2)") == (2.0, 0.0, 0.0, 2.0, 10.0, 20.0) && Svg.image(Vector{UInt8}("not a drawing")) === nothing
  # A drawing from a file keeps its shape in a box of another shape, where a photo is stretched: it's as big as fits, in the middle, unless its tag says otherwise
  shown(tag) = begin
    q = Web.page("""<!DOCTYPE html><body style="margin:0"><img style="width:100px;height:20px" src="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' $tag><rect width='20' height='10' fill='red'/></svg>"></body>"""; wide=300)
    i = only(filter(i -> i isa Paint.Picture, q.list.items))
    (i.dx, i.dy, i.dw, i.dh)
  end
  @test shown("viewBox='0 0 20 10'") == (30, 0, 40, 20) && shown("width='40' height='20' viewBox='0 0 20 10' preserveAspectRatio='xMinYMid slice'") == (0, -15, 100, 50)
  @test shown("viewBox='0 0 20 10' preserveAspectRatio='none'") == (0, 0, 100, 20) && shown("width='20' height='10'") == (0, 0, 100, 20)
  q = Web.page("""<!DOCTYPE html><style>.i { fill: none; stroke: currentColor }</style><p style="color:red"><svg class="i" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/></svg>
    <input type="range"><input type="radio"><meter value=".5"></meter><input type="color" value="#ff0000"><video width="80" height="40"></video><audio controls></audio><input type="file"></p>"""; wide=400)
  @test count(i -> i isa Paint.Drawing, q.list.items) == 1 && count(i -> i isa Paint.Widget, q.list.items) == 6
  @test filesize(Web.save(q, joinpath(mktempdir(), "forms.png"))) > 500
end

@testset "dark mode" begin
  # What each <div> and the page fill, on a screen in dark mode or not. Each colour here is WebKit's on a Mac.
  fills(html; dark=false) = [i.color for i in Web.page(html; wide=200, dark).list.items if i isa Paint.Fill]
  page(head) = """<!DOCTYPE html><html><head>$head<style>div { height: 10px } @media (prefers-color-scheme: dark) { #a { background: #102030 } }
    #b { background: light-dark(red, blue) } #c { background: canvas } #d { background: linktext }</style></head>
    <body style="margin:0"><div id="a"></div><div id="b"></div><div id="c"></div><div id="d"></div></body></html>"""
  light = [0xffff0000, 0xffffffff, 0xff0000ee]
  @test fills(page("")) == light
  # A page that says nothing of its colour scheme stays light, but what it says for a screen in dark mode is for it
  @test fills(page(""); dark=true) == [0xff102030; light]
  # One that can be light or dark is dark on a dark screen: its background where it gives none, the second colour of light-dark(), links
  either = page("""<meta name="color-scheme" content="light dark">""")
  @test fills(either) == light
  @test fills(either; dark=true) == [0xff1e1e1e, 0xff102030, 0xff0000ff, 0xff1e1e1e, 0xff9e9eff]
  # One that's only dark is dark on any screen
  @test fills(page("<style>:root { color-scheme: dark }</style>")) == [0xff1e1e1e, 0xff0000ff, 0xff1e1e1e, 0xff9e9eff]
  # So is one element of a light page, and what's in it
  @test fills("""<body style="margin:0"><div style="color-scheme:dark;height:10px;background:canvas"><p style="margin:0;background:light-dark(red, blue)">x</p></div></body>""") == [0xff1e1e1e, 0xff0000ff]
  # The text is white, and form fields have their dark colours
  doc = Dom.document("""<meta name="color-scheme" content="light dark"><body><p>x</p><input><button>go</button></body>""")
  look = Base.ScopedValues.with(() -> Styles.styles(doc, 400), Css.DARK => true)
  @test look[tagged(doc, "p")].color == 0xffffffff && look[tagged(doc, "input")].background == 0xff1e1e1e && look[tagged(doc, "button")].background == 0xff2f2f2f
  @test Styles.styles(doc, 400)[tagged(doc, "p")].color == 0xff000000 && Styles.styles(doc, 400)[tagged(doc, "input")].background == 0xffffffff
end

@testset "a page of the web" begin
  # A sheet and a picture that the page names are asked for by their whole address, and a link goes to its whole address
  asked = String[]
  load(src) = (push!(asked, src); endswith(src, "s.css") ? "@import 'more/t.css'; p { margin: 0 0 0 30px }" : endswith(src, "t.css") ? "p { color: red; background: url(bg.png) }" : nothing)
  p = Web.page("""<!DOCTYPE html><link rel="stylesheet" href="css/s.css"><link rel="stylesheet" media="print" href="print.css"><link rel="alternate stylesheet" title="Other" href="other.css">
    <body style="margin:0"><p><a href="../up">link</a> <img src="/i.png" width="5" height="5"></p></body>"""; wide=300, load, base="https://x.org/a/b.html")
  @test asked == ["https://x.org/a/css/s.css", "https://x.org/a/css/more/t.css", "https://x.org/i.png", "https://x.org/a/css/more/bg.png"]
  @test p.links[1].url == "https://x.org/up" && p.links[1].left == 30
  # A rule can ask how big the box that an element is in is
  html(wide) = """<!DOCTYPE html><style>p { margin: 0 } .box { container-type: inline-size; width: $(wide)px } @container (min-width: 250px) { p { margin: 0 0 0 40px } }</style><body style="margin:0"><div class="box"><p>x</p></div></body>"""
  @test Web.page(html(300); wide=400).words[1].edges[1] == 40 && Web.page(html(200); wide=400).words[1].edges[1] == 0
  # A font that the page brings is read from its file
  file = "/System/Library/Fonts/Supplemental/Arial.ttf"
  if isfile(file)
    page(family, css) = Web.page("""<!DOCTYPE html><style>$css p { font: 20px $family }</style><p>Some words to measure</p>"""; wide=400, load=src -> endswith(src, "mine.ttf") ? read(file) : nothing)
    mine = page("Mine, Courier", "@font-face { font-family: Mine; src: url(mine.ttf) }")
    @test near(mine.words[1].edges[end], page("Arial", "").words[1].edges[end]; by=0.5) && !near(mine.words[1].edges[end], page("Missing, Courier", "").words[1].edges[end]; by=5)
  end
end

"The colour of the pixel at `(x, y)` of the page as it's drawn on white: how red, how green and how blue"
pixel(p, x, y; at=p.at) = begin
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, Int(p.wide), Int(p.tall)))
  one = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, 1, 1))
  out = zeros(UInt8, 4)
  GC.@preserve info one begin
    surface = Skia.sk_surface_make_raster_n32_premul(pointer_from_objref(info), C_NULL)
    canvas = Skia.sk_surface_get_canvas(surface)
    Skia.sk_canvas_clear(canvas, 0xffffffff)
    Web.draw(canvas, p; at)
    image = Skia.sk_surface_make_image_snapshot(surface)
    Skia.sk_image_read_pixels(image, pointer_from_objref(one), out, Csize_t(4), Cint(x), Cint(y), Skia.sk_image_caching_hint_t(0))
    Skia.sk_image_unref(image)
    Skia.sk_surface_unref(surface)
  end
  (Int(out[1]), Int(out[2]), Int(out[3]))
end

@testset "a video of another site" begin
  # What the address of a frame says of a video of YouTube: one video, a list of videos, or a video of a list
  v = Embed.video("https://www.youtube.com/embed/kc9HwsxE1OY?start=10")
  @test v.watch == "https://www.youtube.com/watch?v=kc9HwsxE1OY" && v.picture == "https://i.ytimg.com/vi/kc9HwsxE1OY/hqdefault.jpg"
  @test v.about == "https://www.youtube.com/oembed?format=json&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dkc9HwsxE1OY"
  @test Embed.video("//www.youtube-nocookie.com/embed/videoseries?list=PL_1").watch == "https://www.youtube.com/playlist?list=PL_1"
  list = Embed.video("https://www.youtube.com/embed/?listType=playlist&list=PL_1&enablejsapi=1")
  @test list.watch == "https://www.youtube.com/playlist?list=PL_1" && list.picture == "" && Embed.video("https://www.youtube.com/embed/abc?list=PL_1").watch == "https://www.youtube.com/watch?v=abc&list=PL_1"
  @test Embed.video("https://example.com/embed/abc") === nothing && Embed.video("https://www.youtube.com/embed/") === nothing && Embed.video("https://www.youtube.com/embed/a%22b") === nothing
  # What YouTube's JSON says of a video, and the bigger pictures of it
  said = Vector{UInt8}("""{"title":"Caf\\u00e9 \\"one\\" \\ud83d\\ude00","height":113,"thumbnail_url":"https:\\/\\/i.ytimg.com\\/vi\\/abc\\/hqdefault.jpg"}""")
  @test Embed.facts(said) == ("Café \"one\" 😀", "https://i.ytimg.com/vi/abc/hqdefault.jpg") && Embed.facts(Vector{UInt8}("not JSON")) == ("", "")
  @test Embed.sharper("https://i.ytimg.com/vi/abc/hqdefault.jpg") == ["https://i.ytimg.com/vi/abc/maxresdefault.jpg", "https://i.ytimg.com/vi/abc/sddefault.jpg", "https://i.ytimg.com/vi/abc/hqdefault.jpg"]
  @test Embed.sharper("https://example.com/a.jpg") == ["https://example.com/a.jpg"]
  # The frame shows the biggest picture that there is of the video, cut to fill it, with the video's name and an arrow. It's a link to the video's page.
  asked = String[]
  green = Vector{UInt8}("<svg xmlns='http://www.w3.org/2000/svg' width='40' height='30'><rect width='40' height='30' fill='lime'/></svg>")
  load = src -> begin
    push!(asked, src)
    startswith(src, "https://www.youtube.com/oembed") ? Vector{UInt8}("""{"title":"A talk","thumbnail_url":"https://i.ytimg.com/vi/abc/hqdefault.jpg"}""") : endswith(src, "/sddefault.jpg") ? green : nothing
  end
  html = """<!DOCTYPE html><body style="margin:0"><iframe src="//www.youtube.com/embed/abc" width="320" height="180" frameborder="0"></iframe><iframe src="other.html"></iframe></body>"""
  p = Web.page(html; wide=400, load, base="https://example.com/")
  @test asked == ["https://www.youtube.com/oembed?format=json&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dabc", "https://i.ytimg.com/vi/abc/maxresdefault.jpg", "https://i.ytimg.com/vi/abc/sddefault.jpg"]
  shown = only(filter(i -> i isa Paint.Picture, p.list.items))
  @test (shown.dx, shown.dy, shown.dw, shown.dh) == (0, -30, 320, 240) && [i.kind for i in p.list.items if i isa Paint.Widget] == [:poster, :frame]
  @test Web.link(p, 100, 100).url == "https://www.youtube.com/watch?v=abc" && Web.link(p, 100, 190) === nothing
  # The picture, the dark band behind the name, and the white arrow in the middle
  @test pixel(p, 20, 150)[2] > 200 && pixel(p, 20, 150)[1] < 50 && pixel(p, 300, 5)[2] < 150 && all(>(200), pixel(p, 162, 90))
  # With no word from YouTube, the frame is black, with the arrow, and still a link
  bare = Web.page(html; wide=400, base="https://example.com/")
  @test count(i -> i isa Paint.Picture, bare.list.items) == 0 && all(<(20), pixel(bare, 20, 150)) && all(>(200), pixel(bare, 162, 90)) && Web.link(bare, 100, 100).url == "https://www.youtube.com/watch?v=abc"
end

@testset "what moves" begin
  # An animation is as far as it has got at the page's time
  doc = Dom.document("""<!DOCTYPE html><style>
    @keyframes spin { to { transform: rotate(360deg) } }
    @keyframes fade { from { opacity: 0; margin-left: 0 } 50% { opacity: 1 } to { margin-left: 100px; background: blue } }
    #a { animation: spin 2s linear infinite } #b { animation: fade 1s linear 0.5s 2 alternate both; background: red } #c { animation: fade 1s steps(4) forwards }
    #d { animation-name: fade; animation-duration: 2s; animation-play-state: paused }
    </style><body style="margin:0"><div id=a></div><div id=b></div><div id=c></div><div id=d></div></body>""")
  s(at, id) = Styles.styles(doc, 400; at)[named(doc, id)]
  @test s(0.5, "a").transform[1].kind == :spin && near(s(0.5, "a").transform[1].n[1], π / 2) && near(s(2.5, "a").transform[1].n[1], π / 2)   # it turns all the way round, again and again
  b = s(1.0, "b")
  @test b.opacity == 1 && near(Styles.px(b.margin[4]), 50) && b.background == 0xff800080   # half way through its first run: a step in the middle says nothing of the margin
  @test s(0.2, "b").opacity == 0 && near(Styles.px(s(2.0, "b").margin[4]), 50) && s(3.0, "b").opacity == 0 && s(3.0, "b").background == 0xffff0000   # before it starts, on its way back, and after
  @test s(0.25, "c").opacity == 0.5 && s(5.0, "c").opacity == 1 && Styles.px(s(5.0, "c").margin[4]) == 100   # in four steps, and it stays as it ends
  @test s(1.0, "d").opacity == 0 && Styles.px(s(1.0, "d").margin[4]) == 0   # one that's stopped stays at its start
  # With no time, the page is as it comes to rest
  @test isempty(s(nothing, "a").transform) && s(nothing, "c").opacity == 1 && s(nothing, "b").opacity == 0
  # The page says whether it still moves, and until when
  one(at) = Web.page("""<!DOCTYPE html><style>@keyframes go { to { margin-left: 100px } } p { margin: 0; animation: go 2s linear 0.5s forwards }</style><body style="margin:0"><p>x</p></body>"""; wide=300, at)
  @test one(1.5).until == 2.5 && Web.moving(one(1.5)) && one(1.5).words[1].edges[1] == 50 && !Web.moving(one(3.0)) && one(3.0).words[1].edges[1] == 100
  @test one(1.5).next == 1.5 && Web.due(one(1.5), 1.6) && !Web.due(one(3.0), 4.0) && one(nothing).next == Inf   # an animation changes all the time
  @test one(nothing).until == 2.5 && !Web.moving(one(nothing)) && one(nothing).words[1].edges[1] == 100
  @test Styles.styles(doc, 400; at=0.0).until == Inf && Web.page("<p>still</p>"; at=1.0).until == 0
  # An animation that an element gets later starts then, when the same clock is given each time
  later = Dom.document("""<!DOCTYPE html><style>@keyframes grow { from { width: 0 } to { width: 100px } } .on { animation: grow 1s linear }</style><div id=x></div>""")
  x, clock = named(later, "x"), Styles.Clock()
  wide(at) = Styles.styles(later, 400; at, clock)[x].width
  @test Styles.isauto(wide(5.0))
  x.attrs["class"] = "on"
  @test Styles.px(wide(7.0)) == 0 && Styles.px(wide(7.5)) == 50 && Styles.isauto(wide(9.0))
  delete!(x.attrs, "class")
  wide(9.5)
  x.attrs["class"] = "on"
  @test Styles.px(wide(10.0)) == 0 && Styles.px(wide(10.25)) == 25   # and one that comes back starts again
  # What's between two values, and how a change speeds up and slows down
  @test Styles.mix(0xffff0000, 0xff0000ff, 0.5) == 0xff800080 && Styles.mix(0x00000000, 0xff0000ff, 0.5) == 0x800000ff && Styles.mix(:block, :none, 0.4) == :block
  @test Styles.px(Styles.mix(Styles.Len(10), Styles.percent(1), 0.5), 200) == 105 && Styles.mix(Styles.AUTO, Styles.Len(10), 0.6) == Styles.Len(10)
  @test Styles.eased("linear", 0.3) == 0.3 && near(Styles.eased("ease-in-out", 0.5), 0.5) && Styles.eased("ease", 0.25) > 0.35 && near(Styles.eased("cubic-bezier(0.3, 0.3, 0.6, 0.6)", 0.4), 0.4)
  @test Styles.eased("steps(4, jump-start)", 0.1) == 0.25 && Styles.eased("step-end", 0.9) == 0 && Styles.eased("linear(0, 0.5 20%, 1)", 0.2) == 0.5
  c = Styles.Context(400.0, 16.0, false)
  turn(v) = (t = Styles.Style(); Styles.set!(t, "transform", v, c, Styles.Style()); t.transform)
  @test Styles.mix(turn("scale(2)"), turn("none"), 0.5)[1].n[1] == 1.5 && Styles.mix(turn("translateX(100px)"), turn("none"), 0.5)[1].x.px == 50
  mixed = only(Styles.mix(turn("translateX(100px) scale(2)"), turn("rotate(90deg)"), 0.5))   # two unlike lists meet as matrices
  @test mixed.kind == :matrix && near(mixed.n[5], 50) && near(hypot(mixed.n[1], mixed.n[2]), 1.5)

  # A video shows its picture of the page's time. The test's video is a second of red, then a second of blue, 64 by 48.
  clip = read(joinpath(@__DIR__, "web_clip.mp4"))
  load(src) = src == "clip.mp4" ? clip : nothing
  film = Dom.document("""<!DOCTYPE html><body style="margin:0"><video src="clip.mp4" autoplay style="display:block"></video><video controls style="display:block"><source src="no.webm"><source src="clip.mp4#t=1.5"></video>
    <video src="gone.mp4" style="display:block"></video></body>""")
  pictures = Web.Pictures(load)
  p = Web.page(film; wide=300, pictures, at=0.5)
  red((r, g, b)) = r > 200 && b < 60
  blue((r, g, b)) = b > 200 && r < 60
  @test p.tall == 48 + 48 + 150 && p.until == 2 && Web.moving(p) && red(pixel(p, 10, 10)) && blue(pixel(p, 10, 58))   # the first plays by itself, and the second waits where its address says to start
  @test count(i -> i isa Paint.Picture, p.list.items) == 2 && count(i -> i isa Paint.Widget, p.list.items) == 2     # the arrow over the one that waits, and the stand-in for the one that can't be read
  p = Web.page(film; wide=300, pictures, at=1.5)
  @test blue(pixel(p, 10, 10)) && !Web.moving(Web.page(film; wide=300, pictures, at=2.5)) && red(pixel(Web.page(film; wide=300, pictures), 10, 10))
  # A click on a video that shows its buttons starts it, and another stops it
  @test !Web.toggle!(p, 10, 10) && Web.toggle!(p, 10, 58) && !Web.toggle!(p, 10, 200)
  p = Web.page(film; wide=300, pictures, at=1.75)
  @test Web.moving(p) && count(i -> i isa Paint.Widget, p.list.items) == 1      # its arrow is gone while it plays
  @test Web.toggle!(p, 10, 58) && count(i -> i isa Paint.Widget, Web.page(film; wide=300, pictures, at=1.9).list.items) == 2
  # A video that waits with a poster shows the poster
  poster = Web.page("""<!DOCTYPE html><body style="margin:0"><video src="clip.mp4" poster="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' width='20' height='10'><rect width='20' height='10' fill='lime'/></svg>"></video></body>"""; wide=300, load)
  @test poster.tall >= 10 && poster.tall < 48 && pixel(poster, 5, 5)[2] > 200
end

@testset "changes that take time" begin
  # A style that changes from one layout to the next takes the time that its `transition` says
  doc = Dom.document("""<!DOCTYPE html><style>
    #a { width: 100px; opacity: 1; color: red; transition: width 1s linear, opacity 2s linear 0.5s } #a.on { width: 300px; opacity: 0; color: blue }
    #b { transition: all 1s linear; margin-left: 0; display: block } #b.on { margin-left: 40px; visibility: hidden; background: #000; display: flex }
    #c { color: black; border: 1px solid; transition: color 1s linear } #c.on { color: white } #k { transition: all 1s linear }
    </style><body style="margin:0"><div id=a></div><div id=b></div><div id=c><span id=k>x</span></div></body>""")
  clock = Styles.Clock()
  look(at) = Styles.styles(doc, 400; at, clock)
  s(at, id) = look(at)[named(doc, id)]
  switch(on) = foreach(id -> on ? (named(doc, id).attrs["class"] = "on") : delete!(named(doc, id).attrs, "class"), ("a", "b", "c"))
  told() = [(Dom.attr(e, "id"), type, name, long) for (e, type, name, long) in Styles.events!(clock)]
  @test Styles.px(s(0.0, "a").width) == 100 && look(1.0).until == 0   # nothing changes at the first layout, or while the style stays
  switch(true)
  @test Styles.px(s(2.0, "a").width) == 100 && look(2.0).until == 4.5 && s(2.0, "a").color == 0xff0000ff   # it starts from what it was, and a property with no transition changes at once
  a = s(2.25, "a")
  @test Styles.px(a.width) == 150 && a.opacity == 1 && isempty(told())   # the opacity waits half a second first
  # `all` is for every property with values between two. One with none changes at once.
  b = s(2.5, "b")
  @test b.display == :flex && Styles.px(b.margin[4]) == 20 && b.background == 0x80000000
  @test s(3.5, "a").opacity == 0.5 && Styles.px(s(3.5, "a").width) == 300
  # What ended is told once, with the property's name
  ended = [("a", "transitionend", "width", 1.0), ("b", "transitionend", "background-color", 1.0), ("b", "transitionend", "margin-left", 1.0),
           ("b", "transitionend", "visibility", 1.0), ("c", "transitionend", "color", 1.0)]
  @test sort(told()) == ended && isempty(told())
  # Back again, from where each has got to
  switch(false)
  b = s(4.0, "b")
  @test Styles.px(b.margin[4]) == 40 && b.background == 0xff000000 && Styles.px(s(4.5, "b").margin[4]) == 20
  @test s(4.5, "a").opacity == 0.25 && near(s(5.5, "a").opacity, 0.625) && Styles.px(s(5.5, "a").width) == 100
  look(8.0)
  @test sort(told()) == sort([ended; ("a", "transitionend", "opacity", 2.0)])   # the change of the opacity that never got to its end isn't told
  # Whether an element shows changes last when it hides, and first when it shows
  switch(true)
  @test s(9.0, "b").visible && s(9.5, "b").visible && !s(10.0, "b").visible
  switch(false)
  @test !s(11.0, "b").visible && s(11.1, "b").visible
  # What an element only has from its parent changes with the parent, and so does a border in the colour of the text
  look(13.0)
  told()
  switch(true)
  look(14.0)
  mid = look(14.5)
  @test mid[named(doc, "c")].color == 0xff808080 && mid[named(doc, "k")].color == 0xff808080 && mid[named(doc, "c")].bordercolor[1] == 0xff808080
  look(16.0)
  @test all(x -> x[1] != "k", told())
  # The styles of one layout can be worked out several times: the clock keeps what the last time noted, once it's committed
  switch(false)
  Styles.styles(doc, 400; at=20.0, clock, commit=false)
  @test Styles.px(Styles.styles(doc, 400; at=20.5, clock, commit=false)[named(doc, "a")].width) == 300
  Styles.commit!(clock)
  @test Styles.px(s(21.0, "a").width) == 200
  # An animation's end is told once, and what an animation changes is no change that takes time
  moves = Dom.document("""<!DOCTYPE html><style>@keyframes go { to { margin-left: 100px } } p { margin: 0; transition: all 1s linear; animation: go 1s linear forwards }</style><p id=p>x</p>""")
  clock = Styles.Clock()
  left(at) = Styles.px(Styles.styles(moves, 400; at, clock)[named(moves, "p")].margin[4])
  @test left(0.0) == 0 && left(0.5) == 50 && left(1.5) == 100 && left(2.0) == 100
  @test [(Dom.attr(e, "id"), type, name, long) for (e, type, name, long) in Styles.events!(clock)] == [("p", "animationend", "go", 1.0)] && isempty(Styles.events!(clock))
  # A page keeps time with a clock, and a page with none changes at once
  flip = Dom.document("""<!DOCTYPE html><style>p { margin: 0; transition: margin 1s linear } .on { margin-left: 80px }</style><body style="margin:0"><p id=p>x</p></body>""")
  clock = Styles.Clock()
  Web.page(flip; wide=300, at=0.0, clock)
  named(flip, "p").attrs["class"] = "on"
  p = Web.page(flip; wide=300, at=1.0, clock)
  @test p.words[1].edges[1] == 0 && p.until == 2 && Web.moving(p) && Web.page(flip; wide=300, at=1.5, clock).words[1].edges[1] == 40
  @test Web.page(flip; wide=300, at=1.5).words[1].edges[1] == 80 && Web.page(flip; wide=300).words[1].edges[1] == 80
  # How a transition is written
  found(css) = Styles.glides(Styles.Found[(false, 2, 0, (0, 0, 0), i, String(n), String(v)) for (i, (n, v)) in enumerate(css)], Dict{String,String}())
  g = found(["transition" => "opacity .3s ease-in-out 100ms, transform 1s cubic-bezier(0.1, 0.7, 1, 0.1)"])
  @test [(x.what, x.long, x.delay, x.ease) for x in g] == [("opacity", 0.3, 0.1, "ease-in-out"), ("transform", 1.0, 0.0, "cubic-bezier(0.1, 0.7, 1, 0.1)")]
  g = found(["transition-property" => "width, height", "-webkit-transition-duration" => "2s"])
  @test [(x.what, x.long) for x in g] == [("width", 2.0), ("height", 2.0)] && isempty(found(["transition" => "none"])) && found(["transition-duration" => "1s"])[1].what == "all"
  @test Styles.parts_of("margin-left") == [:margin] && :bordercolor in Styles.parts_of("border") && Styles.property(:margin, Styles.sides(Styles.ZERO), (Styles.ZERO, Styles.ZERO, Styles.ZERO, Styles.Len(4))) == "margin-left"
end

@testset "pictures that move" begin
  # The test's GIF is 40 by 20: a red square at the left, in the middle and at the right, for half a second each, again and again
  gif, png = read(joinpath(@__DIR__, "web_moving.gif")), read(joinpath(@__DIR__, "web_moving.png"))
  r = Film.reel(gif)
  @test (r.wide, r.high) == (40, 20) && r.starts == [0.0, 0.5, 1.0] && r.long == 1.5 && r.runs == Inf && Film.stops(r) == Inf
  @test Film.frame(r, 0.2) === r.first && Film.frame(r, 0.7) !== r.first && Film.frame(r, 0.7) === Film.frame(r, 0.9) && Film.frame(r, 1.7) === r.first
  # The PNG shows the same, twice, and then it stops at its last picture
  twice = Film.reel(png)
  @test twice.runs == 2 && Film.stops(twice) == 3 && Film.frame(twice, 2.7) === Film.frame(twice, 99.0) && Film.frame(twice, 1.6) === twice.first
  # A file with one picture is no such file, and neither is nonsense
  @test Film.moves(gif) && Film.moves(png) && !Film.moves(Vector{UInt8}("<svg xmlns='http://www.w3.org/2000/svg'/>")) && Film.reel(Vector{UInt8}("GIF89a and then nonsense")) === nothing
  # In a page, a picture that moves shows its picture of the page's time: as an <img>, and behind a box
  load(src) = src == "m.gif" ? gif : src == "m.png" ? png : nothing
  pictures = Web.Pictures(load)
  html = """<!DOCTYPE html><body style="margin:0"><img src="m.gif" style="display:block"><div style="width:40px;height:20px;background:url(m.png)"></div></body>"""
  red((r, g, b)) = r > 200 && g < 60
  p = Web.page(html; wide=100, pictures, at=0.7)
  @test p.tall == 40 && p.until == Inf && Web.moving(p) && red(pixel(p, 20, 10)) && !red(pixel(p, 5, 10)) && red(pixel(p, 20, 30)) && !red(pixel(p, 35, 30))
  later = Web.page(html; wide=100, pictures, at=1.2)
  @test red(pixel(later, 35, 10)) && red(pixel(later, 35, 30)) && red(pixel(p, 20, 10))   # the page of the earlier moment still draws its own pictures
  # The page is due again when a picture changes, and not before
  @test p.next == 1.0 && !Web.due(p, 0.9) && Web.due(p, 1.0) && Film.after(r, 1.2) == 1.5 && Film.after(twice, 2.7) == 3 && Film.after(twice, 3.5) == Inf
  # With no time, it shows its first picture, and the page says that it would move
  rest = Web.page(html; wide=100, pictures)
  @test red(pixel(rest, 5, 10)) && !Web.moving(rest) && rest.until == Inf
  # A page that's laid out once can be drawn at any moment: the picture in the <img> moves, and the one behind the box needs a new layout
  @test red(pixel(rest, 20, 10; at=0.7)) && red(pixel(rest, 35, 10; at=1.2)) && red(pixel(rest, 5, 30; at=0.7)) && red(pixel(rest, 5, 10))
  @test count(i -> i isa Paint.Moving, rest.list.items) == 1 && Web.changes(rest, 0.2) == 0.5 && Web.changes(rest, 1.2) == 1.5
  @test Web.changes(Web.page("<p>still</p>"), 1.0) == Inf && Web.changes(Web.page("""<img src="m.png">"""; pictures), 3.5) == Inf   # nothing moves, or what moved has stopped
  # One that stops lets the page come to rest
  once = Web.page("""<!DOCTYPE html><body style="margin:0"><img src="m.png"></body>"""; wide=100, pictures, at=5.0)
  @test once.until == 3 && !Web.moving(once) && red(pixel(once, 35, 10))
end
