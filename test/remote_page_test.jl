# Tests for a page of Markdown from a web server, which a window shows as a
# browser shows a page of HTML: see "a page from a web server" in main.jl and
# remote.jl. Run them with `julia -O0 --project=. test/remote_page_test.jl`.
# A function of the tests stands in for `curl`, so they use no network, and
# another stands in for the browser. The window isn't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "../remote" => Remote
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
const ran = joinpath(dir, "ran")   # a file that the code of a page would make, if it ran

# What the stand-in for a server has at each address: the kind of file, the number it answers with, the text, and where the address moved to
const SITE = Dict{String,Any}()
const asked = String[]    # each address that was asked for, in order
const browsed = String[]  # each address that went to the browser
page!(address, text; type="text/markdown; charset=utf-8", status=200, moved="") = SITE[address] = (; type, status, text, moved)

# The tests put these back when they end, for the tests that share their process
const was_getter, was_browser = K.PAGE_GETTER[], K.BROWSER[]
K.PAGE_GETTER[] = (address, file, about) -> begin
  push!(asked, address)
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

  ## Lower

  The end.
  """)
page!("https://example.com/prices.md", "# Prices\n\nTea is 4.\n", type="text/plain")
page!("https://example.com/top.md", "# Top\n\n" * "Words.\n\n"^60 * "## Second\n\n" * "More.\n\n"^60, type="application/octet-stream")
page!("https://example.com/docs/", "# Docs\n\nA page that the server keeps as Markdown and as HTML.\n")
page!("https://example.com/old.md", "# New home\n", moved="https://example.com/new/home.md")
page!("https://julialang.org/", "<!DOCTYPE html><title>Julia</title>", type="text/html; charset=utf-8")
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
end

@testset "a page of Markdown from a server shows in the window" begin
  K.open_address!(e, "example.com/notes.md")
  frames()
  b = e.buf
  @test asked == ["https://example.com/notes.md"]
  @test b.path == "https://example.com/notes.md" && b.view == :markdown
  @test b.lines[5] == "# Notes" && b.lines[end-1] == "The end."
  # It's read, and not changed: it has no caret and it's never written
  @test b.fixed && K.caretless(b) && !K.writes(b) && !K.dirty(b)
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
  @test e.buf.path == "https://example.com/prices.md" && e.buf.lines[1] == "# Prices"
  @test asked[end] == "https://example.com/prices.md" && e.back == ["https://example.com/notes.md"]
  # Going back shows the page as it was, and asks the server for nothing
  n = length(asked)
  @test K.go_back!(e) && e.buf.path == "https://example.com/notes.md" && length(asked) == n
  @test K.go_forward!(e) && e.buf.path == "https://example.com/prices.md" && length(asked) == n
  K.go_back!(e)
  # A link to a heading of another page, in the folder over the page's
  K.follow!(e, "../top.md#second")
  frames()
  @test e.buf.path == "https://example.com/top.md" && asked[end] == "https://example.com/top.md"
  i = findfirst(==("## Second"), e.buf.lines)
  @test e.scroll.offset > 0px && K.item(e, i).top - e.scroll.offset < 200px
  K.go_back!(e)
  frames()
  # A link to a heading of the page that shows goes there, and asks for nothing
  n = length(asked)
  K.follow!(e, "#lower")
  frames()
  @test e.buf.path == "https://example.com/notes.md" && length(asked) == n
  # A page of HTML opens in the browser, and the window keeps its page
  K.follow!(e, "https://julialang.org/")
  frames()
  @test browsed == ["https://julialang.org/"] && e.buf.path == "https://example.com/notes.md" && said() == ""
  # An address for email goes to the app for email
  K.follow!(e, "mailto:sam@example.com")
  @test browsed[end] == "mailto:sam@example.com"
  # A wiki link and a file of the Mac go nowhere
  n, m = length(asked), length(browsed)
  K.follow!(e, "[[Ideas]]"); K.follow!(e, "file:///etc/hosts"); K.follow!(e, "/etc/hosts")
  frames()
  # A path is from the top of the site, which has no such page. The browser shows what the site says of it.
  @test asked[n+1:end] == ["https://example.com/etc/hosts"] && browsed[m+1:end] == ["https://example.com/etc/hosts"]
  @test e.buf.path == "https://example.com/notes.md"
end

@testset "what a server can answer" begin
  # A server that keeps a page as Markdown and as HTML sends the Markdown, whatever the address ends in
  K.open_address!(e, "https://example.com/docs/")
  frames()
  @test e.buf.path == "https://example.com/docs/" && e.buf.lines[1] == "# Docs" && K.name(e.buf) == "example.com/docs/"
  # A page that moved shows under the address that it moved to
  K.open_address!(e, "example.com/old.md")
  frames()
  @test e.buf.path == "https://example.com/new/home.md" && e.buf.lines[1] == "# New home"
  at = e.buf.path
  # Plain text whose name doesn't say Markdown isn't a page: the browser gets it, and words say so
  empty!(browsed)
  K.open_address!(e, "example.com/plain.txt")
  frames()
  @test e.buf.path == at && browsed == ["https://example.com/plain.txt"] && occursin("sent no Markdown", said())
  # No such page, a page that Ladder may not read, and a server that doesn't answer
  empty!(browsed)
  K.open_address!(e, "example.com/none.md"); frames()
  @test e.buf.path == at && said() == "example.com has no page at that address." && isempty(browsed)
  K.open_address!(e, "example.com/secret.md"); frames()
  @test e.buf.path == at && said() == "example.com doesn't let Ladder read that page."
  K.open_address!(e, "down.example.com/a.md"); frames()
  @test e.buf.path == at && said() == "down.example.com didn't answer."
  # Words that aren't an address ask for nothing
  n = length(asked)
  K.open_address!(e, "notes"); frames()
  @test length(asked) == n && occursin("isn't a web address", said())
end

@testset "the page runs no code and shows no file of the Mac" begin
  errors = length(K.problems)
  K.open_address!(e, "example.com/code.md")
  K.fetches["https://example.com/pictures/plan.png"] = nothing   # the picture couldn't be had, so `curl` isn't run for it
  frames(5)
  b = e.buf
  @test b.path == "https://example.com/code.md"
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
  K.open_address!(e, "example.com/album/page.md")
  frames()
  @test any(it -> it.content isa K.Live && it.content.node isa K.Picture, e.layout)
  shot("remote_picture.png")
end

@testset "asking again, and the ways to ask" begin
  K.open_address!(e, "example.com/top.md"); frames()
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
  @test e.popup == :none && e.buf.path == "https://example.com/prices.md"
  # A window that's opened on an address shows its page
  e2 = K.build_editor("https://example.com/notes.md")
  w2 = Window(e2, size=(900px, 700px))
  foreach(_ -> frame(w2), 1:3)
  @test e2.buf.path == "https://example.com/notes.md" && isempty(e2.back)
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
  @test e.buf.path == "https://example.com/notes.md" && e.back[end] == mine
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

K.PAGE_GETTER[], K.BROWSER[] = was_getter, was_browser
foreach(url -> delete!(K.fetches, url), filter(startswith("https://example.com/"), collect(keys(K.fetches))))
