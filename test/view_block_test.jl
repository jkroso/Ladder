# Tests for the `view` block of main.jl: another file, a folder or a page of
# the web, shown as it is in a document, with a button that goes to it. Run
# them with `julia -O0 --project=. test/view_block_test.jl`. They draw in a
# window that isn't on the screen, and ask the web for nothing. Set
# `LADDER_SHOTS` to a folder, and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

# The files beside the document are on the Mac, so what stands in for `curl` gets nothing
K.WEB_GETTER[] = (address, file, about) -> () -> false

const dir = mktempdir()
const page = joinpath(dir, "views.md")
const html = joinpath(dir, "model.html")
const picture = joinpath(dir, "roof.png")
const table = joinpath(dir, "costs.csv")
const notes = joinpath(dir, "notes.md")
const folder = joinpath(dir, "parts")
cp(joinpath(K.pages_dir[], "photos", "3 roof.png"), picture)
write(html, """
<body style="margin:0"><p id=out style="margin:0;height:40px">no sums</p>
<script>
  window.clicks = 0
  addEventListener('click', () => clicks++)
  addEventListener('sums', () => { document.getElementById('out').textContent = ladder.shown.span + ' wide' })
</script></body>
""")
write(table, "Part,Cost\nWing,200\nBody,450\n")
write(notes, "# Notes\n\nA few words about the wing.\n")
mkpath(folder)
write(joinpath(folder, "wing.txt"), "The wing")
write(joinpath(folder, "body.txt"), "The body")
write(page, """
# Views

The wing spans !`span = 70m`.

```view
model.html
```

```view
roof.png
```

```view
costs.csv
```

```view
notes.md
```

```view
parts
```

```view
gone.pdf
```

```view
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 2600px))
const (; frames, at, press, release, shot) = drive(w, frames=3)
frames()
view(n) = e.nodes[(:block, K.VIEW_BLOCK, page, n)]

click(place) = (press(place); release())
"A click at `place` with the key `held` down"
click(place, held) = (was = w.keys; w.keys |= held; click(place); w.keys = was)
"The button beside the top right corner of the `n`th view, which shows while the mouse is over the view"
go_button(n) = (at(middle(rect(view(n)))); K.fills(e)[objectid(view(n))].button)
"Go back to the document, as ⌘⌥← does, and let it lay its blocks out again"
back!() = (K.go_back!(e); frames(); @test e.buf.path == page)
"Wait until the page of the browser `b` has come and its scripts have run"
settle(b) = for _ in 1:200
  frames(1)
  b.view.live !== nothing && !K.Browsers.loading(b) && break
  sleep(0.02)
end
live(b, code) = K.Browsers.Live.evaluate(b.view.live, code)

@testset "each kind of file shows as it is" begin
  @test [view(n).target for n in 1:7] == [html, picture, table, notes, folder, joinpath(dir, "gone.pdf"), ""]
  # An HTML file shows its page, and its scripts get the document's sums
  b = view(1).browser
  settle(b)
  frames()
  @test K.view_web(view(1)) && b.shown == "file://" * html && live(b, "ladder.sums.span") == 70
  @test live(b, "document.getElementById('out').textContent") == "70m wide"
  # A picture, a CSV file and a Markdown page show as they do under a path
  @test view(2).crumb.viewer === nothing && rect(view(2)) !== nothing && !K.view_web(view(2))
  @test view(3).crumb.text isa K.FileTable && length(view(3).crumb.text.rows) == 3
  @test view(4).crumb.text isa K.FilePage
  # A folder shows its files
  @test sort(collect(keys(view(5).crumb.entries))) == [joinpath(folder, "body.txt"), joinpath(folder, "wing.txt")]
  # Each view that shows a file has a button that goes to it. A file that isn't there, and an empty block, have none.
  @test [haskey(K.fills(e), objectid(view(n))) for n in 1:7] == [true, true, true, true, true, false, false]
  @test K.fills(e)[objectid(view(2))].what == (:go, picture)
  # A page from a web server shows it as code
  @test K.known_lang(K.VIEW_BLOCK)
  @test !K.dirty(e.buf)
  shot("view-block.png")
end

@testset "a CSV file's rows reach both sides of its view, with their words in the middle of each row" begin
  file = joinpath(dir, "window.png")
  save_png(file, w)
  ps = pixels(file)
  k = size(ps, 2) / K.num(K.window_size(e)[1])   # the picture's pixels to a px of the window
  rgb(x, y) = (p = ps[round(Int, y * k), round(Int, x * k)]; (Int(p >> 16 & 0xff), Int(p >> 8 & 0xff), Int(p & 0xff)))
  near(a, b) = all(abs.(a .- b) .<= 3)
  head = round.(Int, 255 .* Float64.((K.colours.head.r, K.colours.head.g, K.colours.head.b)))
  r = rect(view(3))
  left, right, top = K.num(r.left), K.num(r.left + r.width), K.num(r.top)
  # The row of names has the heading's colour near the right side of the view, past the last column's words
  band = [y for y in top:0.5:top+60 if near(rgb(right - 24, y), head)]
  @test length(band) >= 2(K.num(K.ROW_H) - 2)
  # Its word, "Part", is as far from the top of the row as from the bottom
  ink = [y for y in first(band):0.5:last(band) if any(x -> sum(rgb(x, y)) < 450, left+20:0.5:left+60)]
  @test !isempty(ink) && abs((first(ink) - first(band)) - (last(band) - last(ink))) <= 1.5
end

@testset "the button beside a view goes to its file" begin
  button = go_button(2)
  @test button !== nothing
  # The picture in the view has no button of its own: the view's button stands for it
  inner = get(K.fills(e), objectid(view(2).crumb), nothing)
  @test inner !== nothing && inner.button === nothing
  click(middle(rect(button)))
  @test e.buf.path == picture
  back!()
  # A click on a file of a folder goes to it
  click(middle(rect(view(5).crumb.entries[joinpath(folder, "wing.txt")])))
  @test e.buf.path == joinpath(folder, "wing.txt")
  back!()
  # A click with ⌘ held on a view goes to its file too
  click(middle(rect(view(4))), Keys.cmd)
  @test e.buf.path == notes
  back!()
end

@testset "an HTML file that the view goes to keeps the sums" begin
  b = view(1).browser
  settle(b)
  # A click on the page is the page's, and the document stays
  click(middle(rect(b)))
  @test live(b, "clicks") == 1 && e.buf.path == page
  click(middle(rect(go_button(1))))
  @test e.buf.path == html && K.html_shown(e)
  there = K.html_browser(K.html_part(e))
  settle(there)
  frames()
  @test live(there, "ladder.sums.span") == 70 && live(there, "document.getElementById('out').textContent") == "70m wide"
  back!()
  # The file opened another way gets no sums
  K.show_path!(e, html)
  frames()
  again = K.html_browser(K.html_part(e))
  settle(again)
  frames()
  @test again !== there && live(again, "typeof ladder") == "undefined"
  back!()
end

@testset "the first button makes what a view shows fill the window" begin
  # A picture and a page have something to fill the window with. A table, a page of Markdown and a folder have only
  # the button that goes to the file.
  @test K.fills(e)[objectid(view(1))].also == (:node, view(1).browser)
  @test K.fills(e)[objectid(view(2))].also[1] == :picture
  @test all(n -> K.fills(e)[objectid(view(n))].also === nothing, 3:5)
  go_button(2)
  click(middle(rect(K.fills(e)[objectid(view(2))].expand)))
  @test K.zooming(e) !== nothing && K.zooming(e).what[1] == :picture && e.buf.path == page
  onkey(w, KeyPress{Keys.escape}(0, w)); frames()
  @test K.zooming(e) === nothing
  # A page of the web has all of the window under the top bar, and the keyboard. The document stays where it is.
  b = view(1).browser
  go_button(1)
  click(middle(rect(K.fills(e)[objectid(view(1))].expand)))
  @test K.zooming(e) !== nothing && K.zooming(e).what == (:node, b) && e.buf.path == page && w.focus === b
  r = rect(b)
  @test (r.left, r.top, r.width, r.height) == (0px, K.TOPBAR_H, 1000px, 2600px - K.TOPBAR_H)
  @test K.page_takes(view(1), nothing)
  @test !any(b -> b isa K.PlanButton && rect(b) !== nothing, values(K.zooming(e).parts))
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "view-page-full.png"), w)
  # It still has the document's sums there, and Esc puts it back in the document
  @test live(b, "ladder.sums.span") == 70
  onkey(w, KeyPress{Keys.escape}(0, w)); frames()
  @test K.zooming(e) === nothing && rect(b).width < 1000px && rect(b).top > K.TOPBAR_H
end

@testset "an empty view shows the file that's written in it" begin
  K.write_block!(view(7), K.VIEW_BLOCK, ["costs.csv"])
  frames()
  @test view(7).target == table && haskey(K.fills(e), objectid(view(7))) && view(7).crumb.text isa K.FileTable
end

@testset "a line `aspect:` sets the shape of a page and of a model" begin
  @test K.aspect_of("16:9") ≈ 16 / 9 && K.aspect_of("16/9") ≈ 16 / 9 && K.aspect_of("2") == 2 && K.aspect_of("1.5") == 1.5
  @test K.aspect_of("wide") == 0 && K.aspect_of("0:1") == 0 && K.aspect_of("2:0") == 0
  # A setting is no name of a file, and a line of a page's HTML is no setting
  @test K.view_parts(["model.glb", "aspect: 2:1"]) == (source=["model.glb"], settings=["aspect: 2:1"])
  @test K.view_parts(["aspect: 3", "<p>", "aspect: 1", "</p>"]) == (source=["<p>", "aspect: 1", "</p>"], settings=["aspect: 3"])
  cp(joinpath(K.pages_dir[], "satellite.glb"), joinpath(dir, "model.glb"))
  write(joinpath(dir, "page.html"), "<p>A page</p>")
  shapes = joinpath(dir, "shapes.md")
  write(shapes, "```view\nmodel.glb\naspect: 2:1\n```\n\n```view\naspect: 16/9\nmodel.glb\n```\n\n```view\npage.html\naspect: 4\n```\n\n```view\nmodel.glb\n```\n")
  e3 = K.build_editor(shapes)
  w3 = Window(e3, size=(900px, 1600px))
  foreach(_ -> frame(w3), 1:3)
  v3(n) = e3.nodes[(:block, K.VIEW_BLOCK, shapes, n)]
  wide, tall, html, plain = v3(1), v3(2), v3(3), v3(4)
  @test wide.aspect == 2 && tall.aspect ≈ 16 / 9 && html.aspect == 4 && plain.aspect == 0
  # The viewer's frame and the rounding to a whole pixel take up to 3 pixels from the shape
  r = rect(wide.crumb.viewer)
  @test abs(r.height - r.width / 2) <= 3px
  r = rect(tall.crumb.viewer)
  @test abs(r.height - r.width * 9 / 16) <= 3px
  # A page is as tall as its shape says, whatever it shows
  b = html.browser
  @test b !== nothing && abs(b.high - b.wide / 4) <= 3px
  # With no such line, a model is as tall as it always was
  @test plain.crumb.viewer.height == K.MODEL_HEIGHT
  # Take the line away, and the model is that tall again
  i = findfirst(==("aspect: 2:1"), e3.buf.lines)
  K.edit!(e3.buf, (i, 0), (i, length(e3.buf.lines[i])), "", typing=true)
  # The caret leaves the block, so the page shows the view again and not its lines
  e3.buf.caret = e3.buf.anchor = (length(e3.buf.lines), 0)
  foreach(_ -> frame(w3), 1:3)
  @test wide.aspect == 0 && wide.crumb.viewer.height == K.MODEL_HEIGHT
end
