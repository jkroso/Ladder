# Tests for a page of Markdown from a web server, which a window shows as a
# browser shows a page of HTML: see "a page from a web server" in main.jl and
# remote.jl. Run them with `julia -O0 --project=. test/remote_page_test.jl`.
# A function of the tests stands in for `curl`, so they use no network, and
# another stands in for the browser. The window isn't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "../remote" => Remote
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use GeometryBasics: Vec2
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
# Each page from the web goes in the browser folder, which is the test's own: see "the browser folder" in main.jl
K.BROWSER_FOLDER[] = joinpath(dir, "Browser")
"The web address of the page that the window shows, or of the file at `path` of the browser folder"
address(path=e.buf.path) = K.web_address(path)
const ran = joinpath(dir, "ran")   # a file that the code of a page would make, if it ran

# What the stand-in for a server has at each address: the kind of file, the number it answers with, the text, and where the address moved to
const SITE = Dict{String,Any}()
const asked = String[]    # each address that was asked for, in order
const browsed = String[]  # each address that went to the browser
page!(address, text; type="text/markdown; charset=utf-8", status=200, moved="") = SITE[address] = (; type, status, text, moved)

# The tests put these back when they end, for the tests that share their process
const was_getter, was_browser = K.PAGE_GETTER[], K.BROWSER[]
K.PAGE_GETTER[] = (address, file, about) -> begin
  # Ladder asks for the .ladder page of each folder of a page too: see test/web_folder_page_test.jl
  endswith(address, "/.ladder") || push!(asked, address)
  at = get(SITE, address, nothing)
  if at === nothing
    write(file, "Not found"); write(about, "$address\ntext/plain\n404\n")
  elseif at.status == 0
    write(about, "$address\n\n000\n")   # the server didn't answer, so nothing came
  else
    write(file, at.text); write(about, "$(isempty(at.moved) ? address : at.moved)\n$(at.type)\n$(at.status)\n")
  end
  () -> true
end
K.BROWSER[] = url -> push!(browsed, url)

page!("https://example.com/notes.md", """
  ---
  title: Notes
  ---

  # Notes

  Some **bold** words, and a [link beside](prices.md), a [link up](../top.md#second) and a [link here](#lower).

  [A site](https://julialang.org/) and [a letter](mailto:sam@example.com) and [[Ideas]] and [a file](file:///etc/hosts).

  | Item | Price |
  |------|-------|
  | Tea  | 4     |
  | [Milk](prices.md) | 2 |

  ## Lower

  The end.
  """)
page!("https://example.com/prices.md", "# Prices\n\nTea is 4.\n", type="text/plain")
page!("https://example.com/top.md", "# Top\n\n" * "Words.\n\n"^60 * "## Second\n\n" * "More.\n\n"^60, type="application/octet-stream")
page!("https://example.com/docs/", "# Docs\n\nA page that the server keeps as Markdown and as HTML.\n")
page!("https://example.com/old.md", "# New home\n", moved="https://example.com/new/home.md")
page!("https://julialang.org/", "<!DOCTYPE html><title>Julia</title>", type="text/html; charset=utf-8")
page!("https://example.com/site/", """
  <!DOCTYPE html><title>A site</title>
  <body style="margin:0;font:16px/20px Helvetica">
  <a href="../prices.md" style="display:block;height:40px">Prices</a>
  <a href="more.html" style="display:block;height:40px">More</a>
  <p style="margin:0">$("x" ^ 3000)</p>
  <a id=low>Lower</a></body>""", type="text/html; charset=utf-8")
page!("https://example.com/site/more.html", "<p>More of the site</p>", type="")
page!("https://example.com/site/gone.html", "<h1>Not here</h1>", type="text/html", status=404)
page!("https://example.com/site/report.pdf", "%PDF-1.4", type="application/pdf")
page!("https://example.com/plain.txt", "Only text.\n", type="text/plain")
page!("https://example.com/secret.md", "No", type="text/html", status=403)
page!("https://down.example.com/a.md", "", status=0)
page!("https://example.com/code.md", """
  # Code

  ```ui
  touch($(repr(ran)))
  ```

  A sum: !`touch($(repr(ran)))` in a line.

  ```check
  touch($(repr(ran)))
  ```

  ```sheet
  Area = 2 * 3
  ```

  ```web
  https://julialang.org/
  ```

  ```load
  from: /etc/hosts
  ```

  ```find
  hosts
  ```

  ```progress /tmp/progress.jl
  1
  ```

  ![[Ideas#Plans]]

  ![a picture](pictures/plan.png)

  ![of the Mac](file:///etc/hosts.png)

  ```python
  print(1)
  ```

  ```mermaid
  graph TD
    A --> B
  ```
  """)

const e = K.blank_editor()
const w = Window(e, size=(1000px, 800px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
press(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
said() = get(e.nodes, :result, ("", 0.0))[1]

@testset "addresses" begin
  @test Remote.typed("example.com/notes.md") == "https://example.com/notes.md"
  @test Remote.typed(" https://example.com ") == "https://example.com/"
  @test Remote.typed("localhost:8000/a.md") == "http://localhost:8000/a.md"
  # What follows the computer's name can have spaces, which are written as a browser writes them
  @test Remote.typed("example.com/my notes.md") == "https://example.com/my%20notes.md" && Remote.typed("https://exa mple.com/a.md") === nothing
  @test Remote.against("https://example.com/a/b.md", "../images/air cost.png") == "https://example.com/images/air%20cost.png"
  # The name of a file isn't an address, and neither are words
  @test Remote.typed("notes.md") === nothing && Remote.typed("some words/here") === nothing && Remote.typed("") === nothing
  @test Remote.against("https://example.com/a/b.md", "../c.md#top") == "https://example.com/c.md#top"
  @test Remote.against("https://example.com/a/b.md#x", "d.md") == "https://example.com/a/d.md"
  @test Remote.against("https://example.com/a/b.md", "/e.md") == "https://example.com/e.md"
  @test Remote.against("https://example.com/a/b.md", "mailto:sam@example.com") == "mailto:sam@example.com"
  @test Remote.label("https://example.com/a/my%20notes.md?x=1#top") == "example.com/a/my notes.md"
  @test Remote.label("https://example.com/") == "example.com"
  @test Remote.place("https://example.com/a.md#my%20place") == "my place" && Remote.place("https://example.com/a.md") == ""
  # What a server sends is Markdown when it says so, or when it doesn't say and the name ends as Markdown's does
  @test Remote.ismarkdown("text/markdown", "https://example.com/docs/")
  @test Remote.ismarkdown("text/plain", "https://example.com/a.md") && Remote.ismarkdown("", "https://example.com/a.MD?x=1")
  @test !Remote.ismarkdown("text/plain", "https://example.com/a.txt") && !Remote.ismarkdown("text/html", "https://example.com/a.md")
  @test K.isremote("https://example.com/a.md") && !K.isremote("/Users/sam/a.md") && !K.isremote("")
  # What a server sends is a page of HTML when it says so, or when it doesn't say and the name or the text says HTML
  answer(type, address, text="") = Remote.Answer(address, address, type, "", 200, Vector{UInt8}(text))
  @test Remote.ishtml(answer("text/html", "https://example.com/")) && Remote.ishtml(answer("", "https://example.com/a.html"))
  @test Remote.ishtml(answer("", "https://example.com/", "  <!doctype HTML><p>é")) && Remote.ishtml(answer("application/octet-stream", "https://example.com/", "<html>"))
  @test !Remote.ishtml(answer("text/plain", "https://example.com/a.txt", "words")) && !Remote.ishtml(answer("application/pdf", "https://example.com/a.html"))
end

@testset "a page of Markdown from a server shows in the window" begin
  K.navigate!(e, "example.com/notes.md")
  frames()
  b = e.buf
  @test asked == ["https://example.com/notes.md"]
  @test address(b.path) == "https://example.com/notes.md" && b.view == :markdown
  @test b.lines[5] == "# Notes" && b.lines[end-1] == "The end."
  # It's a file of the browser folder, at its place on its site, marked with its address and what the server sent
  @test b.path == joinpath(dir, "Browser", "example.com", "notes.md") && read(b.path, String) == join(b.lines, "\n")
  @test K.copied_from(b.path) == "https://example.com/notes.md" && !K.changed_here(b.path)
  # It has no caret until a click puts one in it. ⌘S writes it to its file, and never to the server.
  @test !b.fixed && K.caretless(b) && K.writes(b) && !K.dirty(b)
  # The top bar calls it by its address, and the sidebar's folder is as it was
  @test K.name(b) == "example.com/notes.md" && e.folder == ""
  # The front matter shows as a card, and the table as a table
  @test any(it -> it.content isa K.Grid, e.layout)
  @test said() == ""
  shot("remote_notes.png")
end

@testset "links are from the page's address" begin
  # A link to a page beside it: the server sends it as plain text, and its name says that it's Markdown
  K.follow!(e, "prices.md")
  frames()
  @test address() == "https://example.com/prices.md" && e.buf.lines[1] == "# Prices"
  @test asked[end] == "https://example.com/prices.md" && address.(e.back) == ["https://example.com/notes.md"]
  # Going back shows the page as it was, and asks the server for nothing
  n = length(asked)
  @test K.go_back!(e) && address() == "https://example.com/notes.md" && length(asked) == n
  @test K.go_forward!(e) && address() == "https://example.com/prices.md" && length(asked) == n
  K.go_back!(e)
  # A link to a heading of another page, in the folder over the page's
  K.follow!(e, "../top.md#second")
  frames()
  @test address() == "https://example.com/top.md" && asked[end] == "https://example.com/top.md"
  i = findfirst(==("## Second"), e.buf.lines)
  @test e.scroll.offset > 0px && K.item(e, i).top - e.scroll.offset < 200px
  K.go_back!(e)
  frames()
  # A link to a heading of the page that shows goes there, and asks for nothing
  n = length(asked)
  K.follow!(e, "#lower")
  frames()
  @test address() == "https://example.com/notes.md" && length(asked) == n
  # A page of HTML shows the page that it makes, in the window, and ⌘⌥← comes back
  K.follow!(e, "https://julialang.org/")
  frames()
  @test isempty(browsed) && address() == "https://julialang.org/" && K.html_shown(e) && said() == ""
  K.go_back!(e); frames()
  @test address() == "https://example.com/notes.md"
  # An address for email goes to the app for email
  K.follow!(e, "mailto:sam@example.com")
  @test browsed[end] == "mailto:sam@example.com"
  # A wiki link and a file of the Mac go nowhere
  n, m = length(asked), length(browsed)
  K.follow!(e, "[[Ideas]]"); K.follow!(e, "file:///etc/hosts"); K.follow!(e, "/etc/hosts")
  frames()
  # A path is from the top of the site, which has no such page, and words say so
  @test asked[n+1:end] == ["https://example.com/etc/hosts"] && browsed[m+1:end] == [] && said() == "example.com has no page at that address."
  @test address() == "https://example.com/notes.md"
end

@testset "a click on a link opens it, in a paragraph and in a table" begin
  K.navigate!(e, "example.com/notes.md")
  frames()
  @test address() == "https://example.com/notes.md"
  # The page has no caret, so a click with no key held opens the link that it's on
  i = findfirst(l -> occursin("[link beside]", l), e.buf.lines)
  it = K.item(e, i)
  line = it.content.lines[1]
  seg = line.segs[findfirst(s -> s.link == "prices.md", line.segs)]
  y = e.origin[2] + it.top + it.content.above + line.top + line.high / 2
  @test K.link_on(e, (e.origin[1] + seg.x + seg.w / 2, y)) == "prices.md"
  K.press!(e, (e.origin[1] + seg.x + seg.w / 2, y)); frames()
  @test address() == "https://example.com/prices.md"
  K.go_back!(e); frames()
  # A link in a cell of a table has its own lines of text, and opens as one in a paragraph does
  t = only(it for it in e.layout if it.content isa K.Grid)
  g = t.content
  r = findfirst(==(findfirst(l -> occursin("[Milk]", l), e.buf.lines)), g.rows)
  f = g.flows[r][1]
  seg = f.lines[1].segs[findfirst(s -> !isempty(s.link), f.lines[1].segs)]
  cx, cy = K.cell_origin(g, r, 1)
  x = e.origin[1] + cx + seg.x + seg.w / 2
  y = e.origin[2] + t.top + cy + f.above + f.lines[1].top + f.lines[1].high / 2
  @test K.link_on(e, (x, y)) == "prices.md" && K.link_at(e, (x, y)) == "prices.md"
  # The cell's other words, and the cell beside it, are on no link
  @test K.link_on(e, (x + seg.w, y)) === nothing && K.link_on(e, (e.origin[1] + K.cell_origin(g, r, 2)[1] + 20px, y)) === nothing
  K.press!(e, (x, y)); frames()
  @test address() == "https://example.com/prices.md"
  K.go_back!(e); frames()
end

@testset "a page of HTML shows the page that it makes" begin
  empty!(browsed)
  K.navigate!(e, "example.com/site/")
  frames()
  b = e.buf
  # It's an HTML file of the browser folder: the page of the folder's address is its index.html
  @test b.path == joinpath(dir, "Browser", "example.com", "site", "index.html") && read(b.path, String) == SITE["https://example.com/site/"].text
  @test address(b.path) == "https://example.com/site/" && K.html_shown(e) && K.name(b) == "example.com/site/"
  # Ladder's own engine shows it, from the HTML of the file, with its links and pictures from its address, and no second request
  v = e.nodes[(:html, b.path)]
  @test v.browser.html == SITE["https://example.com/site/"].text && v.browser.base == "https://example.com/site/" && asked[end] == "https://example.com/site/"
  @test K.Browsers.title_of(v.browser.html) == "A site"
  # It has the levels of an HTML file, the page at the top. ⌘E goes to its HTML and back.
  @test K.levels(e)[end] == "the page that the HTML makes" && K.level(e) == length(K.levels(e))
  press(Keys.e, Keys.cmd)
  @test e.buf.view == :text && e.buf.lines[1] == "<!DOCTYPE html><title>A site</title>" && !K.html_shown(e)
  press(Keys.e, Keys.cmd)
  b = e.buf
  @test b.view == :file && K.html_shown(e)
  # A click on a link of the page goes where Ladder goes: a page of Markdown shows, and ⌘⌥← comes back
  frames(); v = e.nodes[(:html, b.path)]
  r = rect(v.browser)
  x, y = K.num(r.left) + 20, K.num(r.top) + 20
  w.mouse = typeof(w.mouse)(px(x), px(y))
  onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames()
  @test address() == "https://example.com/prices.md" && address(e.back[end]) == "https://example.com/site/"
  @test K.go_back!(e) && address() == "https://example.com/site/" && K.html_shown(e)
  frames()
  # A page that the server doesn't name, whose name says HTML, shows too
  K.Browsers.follow!(e.nodes[(:html, e.buf.path)].browser, "https://example.com/site/more.html")
  frames()
  @test address() == "https://example.com/site/more.html" && K.html_shown(e)
  # A link to a place of the page scrolls there, and asks for nothing
  K.go_back!(e); frames()
  n = length(asked)
  K.Browsers.follow!(e.nodes[(:html, e.buf.path)].browser, "https://example.com/site/#low")
  frames()
  @test address() == "https://example.com/site/" && length(asked) == n
  # A link that the server has nothing for says so, and the window keeps its page. The browser folder keeps no page of it.
  K.Browsers.follow!(e.nodes[(:html, e.buf.path)].browser, "https://example.com/site/gone.html")
  frames()
  @test address() == "https://example.com/site/" && said() == "example.com has no page at that address." && isempty(browsed)
  @test !ispath(joinpath(dir, "Browser", "example.com", "site", "gone.html"))
  # So does a typed address
  K.navigate!(e, "example.com/site/gone.html"); frames()
  @test said() == "example.com has no page at that address." && address() == "https://example.com/site/"
  # A PDF file opens in the browser, and the window keeps its page
  K.Browsers.follow!(e.nodes[(:html, e.buf.path)].browser, "https://example.com/site/report.pdf")
  frames()
  @test browsed == ["https://example.com/site/report.pdf"] && address() == "https://example.com/site/"
  empty!(browsed)
  # Reload Page asks again, and the page shows what came, at the level that showed
  press(Keys.e, Keys.cmd)
  page!("https://example.com/site/", "<!DOCTYPE html><title>Again</title><p>New words</p>", type="text/html")
  K.reload_page!(e); frames()
  @test e.buf.view == :text && e.buf.lines[1] == "<!DOCTYPE html><title>Again</title><p>New words</p>"
  press(Keys.e, Keys.cmd)
  @test K.html_shown(e) && e.nodes[(:html, e.buf.path)].browser.html == "<!DOCTYPE html><title>Again</title><p>New words</p>"
end

@testset "what a server can answer" begin
  # A server that keeps a page as Markdown and as HTML sends the Markdown, whatever the address ends in
  K.navigate!(e, "https://example.com/docs/")
  frames()
  @test address() == "https://example.com/docs/" && e.buf.lines[1] == "# Docs" && K.name(e.buf) == "example.com/docs/"
  # A page that moved shows under the address that it moved to
  K.navigate!(e, "example.com/old.md")
  frames()
  @test address() == "https://example.com/new/home.md" && e.buf.lines[1] == "# New home"
  at = e.buf.path
  # Plain text whose name doesn't say Markdown isn't a page: the browser gets it, and words say so
  empty!(browsed)
  K.navigate!(e, "example.com/plain.txt")
  frames()
  @test e.buf.path == at && browsed == ["https://example.com/plain.txt"] && occursin("sent no page that Ladder shows", said())
  # No such page, a page that Ladder may not read, and a server that doesn't answer
  empty!(browsed)
  K.navigate!(e, "example.com/none.md"); frames()
  @test e.buf.path == at && said() == "example.com has no page at that address." && isempty(browsed)
  K.navigate!(e, "example.com/secret.md"); frames()
  @test e.buf.path == at && said() == "example.com doesn't let Ladder read that page."
  K.navigate!(e, "down.example.com/a.md"); frames()
  @test e.buf.path == at && said() == "down.example.com didn't answer."
  # Words that aren't an address ask for nothing
  n = length(asked)
  K.navigate!(e, "notes"); frames()
  @test length(asked) == n && occursin("isn't a file, a folder or a web address", said())
end

@testset "the page runs no code and shows no file of the Mac" begin
  errors = length(K.problems)
  K.navigate!(e, "example.com/code.md")
  K.fetches["https://example.com/pictures/plan.png"] = nothing   # the picture couldn't be had, so `curl` isn't run for it
  frames(5)
  b = e.buf
  @test address(b.path) == "https://example.com/code.md"
  @test !ispath(ran) && length(K.problems) == errors
  ks = K.kinds(b)
  lang(open) = ks[findfirst(==(open), b.lines)].lang
  # Julia code keeps its colours, and a block that Ladder would do more with shows as plain code
  @test lang("```ui") == "julia" && lang("```check") == "julia"
  @test all(l -> lang(l) == "", ("```sheet", "```web", "```load", "```find"))
  @test lang("```python") == "python" && lang("```mermaid") == K.DIAGRAM
  # Each of them shows as lines of code: nothing that the page shows is made by code, a browser, or a file of the Mac
  made = [b.lines[it.first] for it in e.layout if it.content isa K.Live]
  @test made == ["```mermaid"]   # the diagram is the one block that shows as more than its code
  @test !any(it -> it.content isa K.Sheet, e.layout)
  @test !any(k -> k isa Tuple && !isempty(k) && k[1] in (:live, :inline, :block), keys(e.nodes))
  # A line that would show a part of another page shows as its text, and a block that names a file of code is only code
  i = findfirst(==("![[Ideas#Plans]]"), b.lines)
  @test !K.transcludes(b, i) && K.item(e, i).content isa K.Flow
  @test K.block_source(b, findfirst(startswith("```progress"), b.lines)) === nothing
  # A picture is from the page's address, and one that names a file of the Mac shows nothing
  @test K.remote_src(e, "pictures/plan.png") == "https://example.com/pictures/plan.png"
  @test K.remote_src(e, "file:///etc/hosts.png") === nothing
  @test haskey(K.fetches, "https://example.com/pictures/plan.png") && !any(startswith("file:"), keys(K.fetches))
  # Code that's run by hand doesn't run either
  out = K.run_code(e, "touch($(repr(ran)))")
  @test out[3] && out[1] isa ErrorException && occursin("runs no code", out[1].msg)
  @test K.made(e, "1 + 1", 1) == ("1 + 1", false)
  @test !ispath(ran)
  shot("remote_code.png")
end

@testset "a picture of the page" begin
  photo = first(filter(f -> endswith(lowercase(f), r"\.(jpe?g|png)"), readdir(joinpath(@__DIR__, "..", "pages", "photos"), join=true)))
  page!("https://example.com/album/page.md", "# Album\n\n![A photo](photo.jpg)\n")
  K.fetches["https://example.com/album/photo.jpg"] = photo   # as if `curl` had fetched it
  K.navigate!(e, "example.com/album/page.md")
  frames()
  @test any(it -> it.content isa K.Live && it.content.node isa K.Picture, e.layout)
  shot("remote_picture.png")
end

@testset "asking again, and the ways to ask" begin
  K.navigate!(e, "example.com/top.md"); frames()
  e.scroll.offset = 300px
  page!("https://example.com/top.md", "# Top, changed\n\n" * "Words.\n\n"^60, type="text/markdown")
  n = length(e.back)
  K.reload_page!(e); frames()
  @test e.buf.lines[1] == "# Top, changed" && e.scroll.offset == 300px && length(e.back) == n
  # The commands for a page from the web are in the palette only while one shows
  @test K.works_here(e, Val(:reload_page)) && K.works_here(e, Val(:open_in_browser))
  empty!(browsed); K.open_in_browser!(e)
  @test browsed == ["https://example.com/top.md"]
  # ⌘O takes an address: the list says what Return does, and Return asks for the page
  press(Keys.o, Keys.cmd)
  @test e.popup == :finder
  typed("example.com/prices.md")
  @test K.finder_address(e) == "https://example.com/prices.md" && K.picker_none(e) == "Press Return to open example.com/prices.md"
  press(Keys.enter)
  @test e.popup == :none && address() == "https://example.com/prices.md"
  # A window that's opened on an address shows its page
  e2 = K.build_editor("https://example.com/notes.md")
  w2 = Window(e2, size=(900px, 700px))
  foreach(_ -> frame(w2), 1:3)
  @test address(e2.buf.path) == "https://example.com/notes.md" && isempty(e2.back)
end

@testset "Navigate, in the command palette" begin
  rows() = K.palette_rows(e, K.palette(e))
  K.navigate!(e, "example.com/notes.md"); frames()
  # An address that's typed in the list of commands has Navigate first, with where Return goes
  press(Keys.p, Keys.cmd, Keys.shft)
  @test e.popup == :commands && "Navigate" in [r.name for r in rows()]
  typed("example.com/prices.md")
  @test K.palette_address(e, K.palette(e)) == "https://example.com/prices.md"
  @test first(rows()).name == "Navigate" && first(rows()).note == "Go to example.com/prices.md"
  @test count(r -> r.name == "Navigate", rows()) == 1
  shot("remote_navigate.png")
  # Return goes there at once, and the palette closes
  press(Keys.enter)
  @test e.popup == :none && address() == "https://example.com/prices.md"
  # Navigate by its name asks for the address, and goes when Return gives it one, with no press of Run
  press(Keys.p, Keys.cmd, Keys.shft)
  typed("navig")
  @test first(rows()).name == "Navigate" && K.palette_address(e, K.palette(e)) === nothing
  press(Keys.enter)
  p = K.palette(e)
  @test e.popup == :commands && p.command.name == :navigate && [K.chip_name(c) for c in K.palette_chips(p)] == ["Address"]
  typed("example.com/top.md")
  shot("remote_navigate_chip.png")
  press(Keys.enter)
  @test e.popup == :none && address() == "https://example.com/top.md"
  # ⌘L is Navigate's key: it asks for the address, as taking Navigate from the list does
  K.navigate!(e, "example.com/notes.md"); frames()
  press(Keys.l, Keys.cmd)
  p = K.palette(e)
  @test e.popup == :commands && p.command !== nothing && p.command.name == :navigate
  typed("example.com/prices.md")
  press(Keys.enter)
  @test e.popup == :none && address() == "https://example.com/prices.md"
  # ... and the line is selected with ⌘⇧L now
  keys = K.keys_now(e).of
  @test K.caps(first(keys[:navigate])) == "⌘L" && K.caps(first(keys[:select_line])) == "⌘⇧L"
  # Letters that are no address list the commands as they always do
  press(Keys.p, Keys.cmd, Keys.shft)
  typed("theme")
  @test first(rows()).name == "Theme" && K.palette_address(e, K.palette(e)) === nothing
  press(Keys.escape); press(Keys.escape)
  @test e.popup == :none
  # The command is there for a page that only shows a file or a folder, too
  K.open!(e, dir); frames()
  @test e.buf.view == :file && any(c -> c.name == :navigate, K.palette_commands(e))
end

@testset "the path in the top bar starts at the server's name" begin
  page!("https://example.com/docs/my%20guide/start.md", "# Start\n\nWords.\n")
  @test Remote.trail("https://example.com/docs/my%20guide/start.md") ==
        [("example.com", "https://example.com/"), ("docs", "https://example.com/docs/"),
         ("my guide", "https://example.com/docs/my%20guide/"), ("start.md", "https://example.com/docs/my%20guide/start.md")]
  @test Remote.trail("https://example.com/docs/") == [("example.com", "https://example.com/"), ("docs", "https://example.com/docs/")]
  @test Remote.trail("https://example.com/") == [("example.com", "https://example.com/")]
  @test Remote.trail("https://example.com") == [("example.com", "https://example.com")]
  K.navigate!(e, "example.com/docs/my guide/start.md"); frames()
  @test address() == "https://example.com/docs/my%20guide/start.md"
  # The bar shows the page's own name, as it shows a file's name, and the path has the rest
  @test K.bar_name(e) == "start.md"
  at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
  middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
  showing() = any(p -> p.key == :title_trail, popups(w))
  at(middle(e.nodes[:title])); sleep(K.TT_WAIT + 0.05); frames()
  @test showing()
  v = e.nodes[:title_trail]
  @test v.steps == [("example.com", "https://example.com/"), ("docs", "https://example.com/docs/"),
                    ("my guide", "https://example.com/docs/my%20guide/"), ("start.md", e.buf.path)]
  # A server doesn't say what's in a folder, so a › there lists nothing
  @test isempty(v.arrows)
  shot("remote_path.png")
  # A right-click on a folder shows no file menu
  c = v.crumbs["https://example.com/docs/"]
  at(middle(c))
  onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames()
  @test !any(p -> p.key == :menu, popups(w))
  # A click on a folder asks the server for its page
  n = length(asked)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(3)
  @test asked[n+1:end] == ["https://example.com/docs/"]
  @test address() == "https://example.com/docs/" && K.bar_name(e) == "docs"
  @test address(e.back[end]) == "https://example.com/docs/my%20guide/start.md"
  at((5, 400))
end

@testset "the › after a server's page searches the page" begin
  page!("https://example.com/guide.md", "# Guide\n\nIntro.\n\n## Tea\n\n" * "Words.\n\n"^60 * "## Milk\n\nThe milk is cold.\n\n- [ ] Buy milk\n")
  K.navigate!(e, "example.com/guide.md"); frames()
  @test address() == "https://example.com/guide.md" && K.searchable(e)
  at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
  middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
  mouse_click() = (w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1); w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2))
  at(middle(e.nodes[:title])); sleep(K.TT_WAIT + 0.05); frames()
  v = e.nodes[:title_trail]
  @test haskey(v.drops, 0)   # a › follows the page's name
  at(middle(v.drops[0])); mouse_click()
  @test any(p -> p.key == K.TS_KEY, popups(w))
  s = e.nodes[:title_search]
  # With nothing asked, it lists the page's headings
  @test [r.x.title for r in s.rows if r.kind == :entry] == ["Guide", "Tea", "Milk"]
  @test K.search_place(s) == "guide.md" && K.search_field(s).placeholder == "Search guide.md"
  shot("remote_search.png")
  # Words find the lines that have them, and Return goes to the line
  typed("cold")
  @test [r.m.text for r in s.rows if r.kind == :thing] == ["The milk is cold."]
  press(Keys.enter)
  @test !any(p -> p.key == K.TS_KEY, popups(w))
  @test address() == "https://example.com/guide.md" && e.buf.caret[1] == findfirst(==("The milk is cold."), e.buf.lines)
  shot("remote_search_found.png")
  # The page has no caret to show, so it scrolls to bring the line in sight
  @test e.scroll.offset > 0px
  # A kind with no words finds every thing of that kind
  at(middle(e.nodes[:title])); sleep(K.TT_WAIT + 0.05); frames()
  at(middle(e.nodes[:title_trail].drops[0])); mouse_click()
  s = e.nodes[:title_search]
  s.wants = [:todo]; frames()
  @test [r.m.text for r in s.rows if r.kind == :thing] == ["Buy milk"]
  press(Keys.escape)
  at((5, 400))
end

@testset "a link in a page of your own" begin
  mine = joinpath(dir, "mine.md")
  write(mine, "# Mine\n\n[Notes](https://example.com/notes.md)\n\n```ui\n1 + 1\n```\n")
  K.open!(e, mine); frames()
  @test !e.buf.fixed && e.folder == dir
  # A page of your own still runs its code
  @test any(it -> it.content isa K.Live && it.content.node isa K.Shown, e.layout)
  # An address that ends as Markdown's does is asked for, and shows in the window
  @test K.reads_here(e, "https://example.com/notes.md") && !K.reads_here(e, "https://julialang.org/") && !K.reads_here(e, "notes.md")
  K.follow!(e, "https://example.com/notes.md"); frames()
  @test address() == "https://example.com/notes.md" && e.back[end] == mine
  # The sidebar goes on listing your folder, and going back shows your page
  @test e.folder == dir
  @test K.go_back!(e) && e.buf.path == mine
end

# Somebody else wrote an email too, so the same rule holds for it: see `foreign` in main.jl
@testset "an email runs no code either" begin
  ran1, ran2 = joinpath(dir, "ran-sum"), joinpath(dir, "ran-block")
  eml = joinpath(dir, "note.eml")
  write(eml, replace("""
    From: Sam Lee <sam@example.com>
    To: you@example.com
    Subject: A note
    Date: Sat, 14 Nov 2026 09:32:00 +1100
    Content-Type: text/plain; charset=utf-8

    The total is !`touch($(repr(ran1)))` today.

    ```ui
    touch($(repr(ran2)))
    ```

    Bye.
    """, "\n" => "\r\n"))
  cache = K.Eml.CACHE[]
  K.Eml.CACHE[] = joinpath(dir, "email")
  try
    @test K.foreign(eml) && K.foreign("https://example.com/a.md") && !K.foreign(joinpath(dir, "mine.md"))
    K.open!(e, eml); frames(4)
    b = e.buf
    @test b.path == eml && b.fixed && "```ui" in b.lines
    @test !ispath(ran1) && !ispath(ran2)
    @test K.kinds(b)[findfirst(==("```ui"), b.lines)].lang == "julia"
    @test !any(it -> it.content isa K.Live && it.content.node isa K.Shown, e.layout)
    out = K.run_code(e, "touch($(repr(ran2)))")
    @test out[3] && occursin("An email runs no code", out[1].msg) && !ispath(ran2)
  finally
    K.Eml.CACHE[] = cache
  end
end

# A site that you let run code runs the code of its pages, as a page of the Mac does: see `foreign` in main.jl
@testset "a site that you let run code runs its pages' code" begin
  site = "https://sums.example.com"
  page!("$site/page.md", """
    # Sums

    Say !`n = 6` and so !`twice = 2n`.

    ```sheet
    A = 1 to 3
    B = A * n
    ```
    """)
  asks = String[]
  was_asker = K.SITE_ASKER[]
  K.SITE_ASKER[] = s -> (push!(asks, s); false)
  sheets() = count(it -> it.content isa K.Sheet, e.layout)
  try
    # You haven't said whether the site may run code, so the page shows its code, and Ladder asks you once
    K.navigate!(e, "sums.example.com/page.md"); frames(5)
    b = e.buf
    @test address(b.path) == "$site/page.md"
    @test asks == [site] && K.site_runs(site) === false
    @test K.foreign(b.path) && sheets() == 0 && K.made(e, "twice", 3) == ("twice", false)
    out = K.run_code(e, "1 + 1")
    @test out[3] && occursin("until you let its site run code", out[1].msg)
    shot("remote_site_code_no.png")
    # Run Site Code: the sums run and the sheet shows
    K.run_site_code!(e); frames(5)
    @test K.site_runs(site) === true && !K.foreign(b.path) && length(asks) == 1
    @test K.kinds(b)[findfirst(==("```sheet"), b.lines)].lang == "sheet" && sheets() == 1
    @test any(k -> k isa Tuple && k[1] == :inline && k[2] == b.path, keys(e.nodes))
    @test K.made(e, "twice", 3) == ("12", false)
    shot("remote_site_code_yes.png")
    # Stop Site Code: the page shows its code again
    K.stop_site_code!(e); frames(5)
    @test K.foreign(b.path) && sheets() == 0
    # A copy of a page follows the answer for the site that it came from. Other sites and emails don't.
    copy = joinpath(dir, "copy.md")
    write(copy, "Say !`1 + 1`.\n")
    K.mark_copy!(copy, "$site/page.md")
    @test K.page_site(copy) == site && K.foreign(copy)
    K.site_runs!(site, true)
    @test !K.foreign(copy) && !K.foreign("$site/other.md") && K.foreign("https://example.com/a.md")
    @test K.foreign(joinpath(dir, "note.eml")) && K.page_site(joinpath(dir, "mine.md")) == ""
  finally
    K.SITE_ASKER[] = was_asker
    K.site_runs!(site, false)
  end
end

# A `view` block of a page from a site that runs code names a file beside the page's address. Ladder gets the file,
# and the block shows a copy of it on the Mac: see `view_copy` in main.jl
@testset "a view of a page from a site that runs code shows the file beside the page" begin
  site = "https://views.example.com"
  page!("$site/a/page.md", """
    # Views

    Say !`n = 6`.

    ```view
    model.jl
    ```

    ```view
    gone.jl
    ```
    """)
  url = "$site/a/model.jl"
  page!(url, "twice(n) = 2n\n"; type="text/plain")
  views() = [it.content.node for it in e.layout if it.content isa K.Live && it.content.node isa K.ViewBlock]
  K.site_runs!(site, true)
  try
    K.navigate!(e, "views.example.com/a/page.md"); frames(8)
    @test address() == "$site/a/page.md" && length(views()) == 2
    v, gone = views()
    # The copy has the file's own name, and it's marked as a copy of the file at its address
    @test v.target == K.VIEW_COPIES[url] && v.target == joinpath(dir, "Browser", "views.example.com", "a", "model.jl")
    @test read(v.target, String) == SITE[url].text && K.copied_from(v.target) == url
    # A Julia file in a view shows its code
    @test v.crumb !== nothing && v.crumb.at == v.target
    # A file that the server hasn't got says so in its block
    @test K.view_coming(e, "$site/a/gone.jl", gone.target) == "views.example.com has no gone.jl."
    shot("remote_view.png")
    # The block's button goes to the copy, which shows as part of the site: its path in the top bar starts with the
    # server's name, and the window's folder stays as it was
    folder = e.folder
    K.go_view!(v); frames()
    @test e.buf.path == v.target && K.web_address(e.buf.path) == url && e.folder == folder
    @test K.trail_steps(e.buf.path) == [("views.example.com", "$site/"), ("a", "$site/a/"), ("model.jl", url)]
    @test K.web_address(joinpath(dir, "mine.md")) == "" && K.trail_steps("$site/a/page.md")[end] == ("page.md", "$site/a/page.md")
    @test K.go_back!(e) && address() == "$site/a/page.md"
    frames()
    # Reload Page asks for the file again
    n = count(==(url), asked)
    K.reload_page!(e); frames(8)
    @test count(==(url), asked) == n + 1 && isfile(views()[1].target)
    # A path of the Mac names nothing, and a page of HTML or a folder shows as a page of the web
    @test K.view_copy(e, "file:///etc/hosts") == ""
    @test K.view_copy(e, "other.html") == "$site/a/other.html" && K.view_copy(e, "b/") == "$site/a/b/"
    # A page whose site may not run code shows the block as its code, and asks for no file
    K.stop_site_code!(e); frames(4)
    @test isempty(views()) && K.view_copy(e, "model.jl") == ""
  finally
    K.site_runs!(site, false)
    K.forget_view_copies!(site)
  end
end

# You can change a page from a web server, as a page of your own: it's a file of the browser folder. ⌘S writes your
# changes there, and never to the server. A click on a link still opens it. See "the browser folder" in main.jl.
@testset "you can change a page from a server, and it stays as you changed it" begin
  url = "https://example.com/notes.md"
  first = SITE[url].text
  asks = Tuple{String,String}[]
  answer = Ref(false)
  was_asker = K.RELOAD_ASKER[]
  K.RELOAD_ASKER[] = (path, address) -> (push!(asks, (path, address)); answer[])
  try
    K.navigate!(e, "example.com/notes.md"); frames()
    b = e.buf
    path = b.path
    @test address() == url && !K.changed_here(path)
    was = copy(b.lines)
    # A click on words that aren't a link puts the caret there, and the keys type
    b.reading = true
    i = findfirst(l -> occursin("[link beside]", l), b.lines)
    it = K.item(e, i)
    line = it.content.lines[1]
    seg = line.segs[1]
    K.press!(e, (e.origin[1] + seg.x + 1px, e.origin[2] + it.top + it.content.above + line.top + line.high / 2)); frames()
    @test !K.caretless(b) && b.caret[1] == i && e.buf === b
    b.caret = b.anchor = (i, 0)
    typed("Mine. ")
    mine = "Mine. " * was[i]
    @test b.lines[i] == mine && K.dirty(b)
    # ⌘S writes it to its file, and asks the server nothing
    n = length(asked)
    K.save_page!(e); frames()
    @test !K.dirty(b) && read(path, String) == join(b.lines, "\n") && K.changed_here(path) && length(asked) == n
    # Another page and back: the page shows as you changed it. The server has nothing new, so Ladder asks you nothing.
    K.follow!(e, "prices.md"); frames()
    K.get_page!(e, url); frames()
    @test e.buf.path == path && e.buf.lines[i] == mine && length(asked) == n + 2 && isempty(asks)
    # The server has something new: Ladder asks you whether to show it. No keeps your changes, and the same new
    # page isn't asked about again.
    page!(url, replace(first, "The end." => "The new end."))
    K.get_page!(e, url); frames()
    @test asks == [(path, url)] && e.buf.lines[i] == mine && K.changed_here(path)
    K.get_page!(e, url); frames()
    @test length(asks) == 1 && e.buf.lines[i] == mine
    # Reload Page asks whenever you changed it. Yes shows what the site has, in the file and in the window.
    answer[] = true
    K.reload_page!(e); frames()
    @test length(asks) == 2 && e.buf.path == path && e.buf.lines[i] == was[i] && "The new end." in e.buf.lines
    @test !K.dirty(e.buf) && !K.changed_here(path)
    # A page that you didn't change takes what the server sends, and nothing asks
    page!(url, first)
    K.get_page!(e, url); frames()
    @test e.buf.lines == was && length(asks) == 2 && !K.changed_here(path)
  finally
    K.RELOAD_ASKER[] = was_asker
    page!(url, first)
  end
end

# This test set is last. Once the palette has been used over a page of the Mac, the next hover on the
# page's name starts its wait a frame late, and "the path in the top bar starts at the server's name" doesn't allow for that.
@testset "Navigate goes to a file or a folder of the Mac" begin
  top = realpath(dir)
  folder = joinpath(top, "Local Notes")
  mkpath(folder)
  plan, other = joinpath(folder, "plan.md"), joinpath(folder, "other.md")
  write(plan, "# Plan\n\nWords.\n")
  write(other, "# Other\n")
  K.navigate!(e, "example.com/notes.md"); frames()
  # A path shows its file, and the page from the server is the one that ⌘⌥← goes back to
  n = length(asked)
  K.navigate!(e, plan); frames()
  @test e.buf.path == plan && e.buf.lines[1] == "# Plan" && address(e.back[end]) == "https://example.com/notes.md" && length(asked) == n
  # A path from the page's folder, and one with other capitals, which goes to the file as the Finder names it
  K.navigate!(e, "other.md"); frames()
  @test e.buf.path == other
  K.navigate!(e, replace(plan, "Local Notes" => "local notes")); frames()
  @test e.buf.path == plan
  # A folder shows as a link to it shows it
  K.navigate!(e, "../"); frames()
  @test e.folder == top || e.buf.path == top
  # ~ is the home folder, and a file:// address is a path with %20 for each space
  @test K.typed_path(e, "~") == homedir() && K.typed_path(e, " ~/no such file.md ") == joinpath(homedir(), "no such file.md")
  @test K.typed_path(e, "file://" * replace(plan, " " => "%20")) == plan
  @test K.typed_path(e, "file://localhost" * replace(plan, " " => "%20")) == plan
  # A web address isn't a path, even when the page's folder has a folder of its name
  @test K.typed_path(e, "example.com/notes.md") === nothing && K.typed_path(e, "notes") === nothing
  # A path where nothing is says so, and the page stays
  K.open!(e, plan); frames()
  K.navigate!(e, joinpath(folder, "none.md")); frames()
  @test e.buf.path == plan && said() == "There's no file or folder at $(K.tilde(joinpath(folder, "none.md")))."
  # From a page of the web, a name that isn't an address is no path
  K.navigate!(e, "example.com/notes.md"); frames()
  K.navigate!(e, "plan.md"); frames()
  @test address() == "https://example.com/notes.md" && occursin("isn't a file, a folder or a web address", said())
  # A path that's typed in the list of commands has Navigate first, and Return goes there
  rows() = K.palette_rows(e, K.palette(e))
  press(Keys.p, Keys.cmd, Keys.shft)
  typed(plan)
  @test first(rows()).name == "Navigate" && first(rows()).note == "Go to " * K.tilde(plan)
  press(Keys.enter)
  @test e.popup == :none && e.buf.path == plan
  # A name from the page's folder there is no path, so the commands list as they always do
  press(Keys.p, Keys.cmd, Keys.shft)
  typed("other.md")
  @test K.palette_address(e, K.palette(e)) === nothing
  press(Keys.escape); press(Keys.escape)
  # ⌘L takes a path, as it takes a web address
  press(Keys.l, Keys.cmd)
  typed(folder * "/other.md")
  press(Keys.enter)
  @test e.popup == :none && e.buf.path == other
end

K.PAGE_GETTER[], K.BROWSER[] = was_getter, was_browser
K.BROWSER_FOLDER[] = ""
foreach(url -> delete!(K.fetches, url), filter(startswith("https://example.com/"), collect(keys(K.fetches))))
