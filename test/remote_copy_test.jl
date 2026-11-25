# Tests for a copy of a page from a web server, which the Save button of the
# page makes on the Mac with the pages and files that it links to: see "a copy
# of a page from a web server" in main.jl, and remote.jl. Run them with
# `julia -O0 --project=. test/remote_copy_test.jl`. A function of the tests
# stands in for `curl`, so they use no network. The window isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "../remote" => Remote
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
const ran = joinpath(dir, "ran")   # a file that the code of a page would make, if it ran

# What the stand-in for a server has at each address: the kind of file, the number it answers with, and the text
const SITE = Dict{String,Any}()
const asked = String[]   # each address that was asked for, in order
page!(address, text; type="text/markdown; charset=utf-8", status=200, moved="") = SITE[address] = (; type, status, text, moved)

# The tests put these back when they end, for the tests that share their process
const was_getter, was_browser = K.PAGE_GETTER[], K.BROWSER[]
K.PAGE_GETTER[] = (address, file, about) -> begin
  push!(asked, address)
  at = get(SITE, address, nothing)
  if at === nothing
    write(file, "Not found"); write(about, "$address\ntext/plain\n404\n")
  else
    write(file, at.text); write(about, "$(isempty(at.moved) ? address : at.moved)\n$(at.type)\n$(at.status)\n")
  end
  () -> true
end
K.BROWSER[] = url -> nothing

page!("https://example.com/docs/", """
  +++
  site = "https://example.com"
  +++

  # Docs

  The [guide](guide.html#part), a [folder](Sub%20Part/) and [plain words](a.md) and [the same words](a.html).

  ![a plan](../images/air%20cost.png) and <img src="pic.png" style="width: 4em"> and [a sheet](files/prices.pdf).

  [Up](../other.md), [Julia](https://julialang.org/), [a page of HTML](page.html), [gone](gone.md),
  [here](#docs), [mail](mailto:sam@example.com), [hidden](.ladder) and [another site](https://elsewhere.com/x.md).

  [named]: notes.md

  ```ui
  touch($(repr(ran)))
  ```

  A sum: !`touch($(repr(ran)))` in a line.

  ```
  [in code](code.md)
  ```
  """)
page!("https://example.com/docs/guide.html", "# Guide\n\n## Part\n\nBack to [the docs](./), and [deeper](Sub%20Part/deep.md).\n")
page!("https://example.com/docs/Sub%20Part/", "# Sub part\n\n[The guide's part](../guide.html#part) and ![a plan](/images/air%20cost.png)\n")
page!("https://example.com/docs/Sub%20Part/deep.md", "# Deep\n\n[Top](../)\n", type="text/plain")
page!("https://example.com/docs/a.md", "# A as Markdown\n")
page!("https://example.com/docs/a.html", "# A from its HTML address\n")
page!("https://example.com/docs/notes.md", "# Notes\n")
page!("https://example.com/images/air%20cost.png", "PNG bytes", type="image/png")
page!("https://example.com/docs/pic.png", "more PNG bytes", type="image/png")
page!("https://example.com/docs/files/prices.pdf", "%PDF bytes", type="application/pdf")
page!("https://example.com/docs/page.html", "<!DOCTYPE html><title>HTML</title>", type="text/html; charset=utf-8")
page!("https://example.com/other.md", "# Other\n")

const e = K.blank_editor()
const w = Window(e, size=(1000px, 800px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()
said() = get(e.nodes, :result, ("", 0.0))[1]
"Draw frames until the copy is done"
copied!() = (for _ in 1:100; K.copying(e) === nothing && break; frames(1) end; frames())

@testset "where a copy of each address goes" begin
  @test Remote.copy_path("https://example.com/a/b.html", page=true) == "a/b.md"
  @test Remote.copy_path("https://example.com/a/", page=true) == "a/index.md"
  @test Remote.copy_path("https://example.com/", page=true) == "index.md" && Remote.copy_path("https://example.com", page=true) == "index.md"
  @test Remote.copy_path("https://example.com/a/b.markdown", page=true) == "a/b.markdown"
  @test Remote.copy_path("https://example.com/a/b?x=1", page=true) == "a/b.md"
  # A file that isn't a page keeps its name, as the site writes it
  @test Remote.copy_path("https://example.com/i/air%20cost.png") == "i/air cost.png"
  @test Remote.copy_path("https://example.com/i/plans.html") == "i/plans.html"
  # No path goes out of the copy's folder, and no file is hidden
  @test Remote.copy_path("https://example.com/a/%2e%2e/b.md") === nothing
  @test Remote.copy_path("https://example.com/a%2Fb.md") === nothing
  @test Remote.copy_path("https://example.com/.ladder") === nothing && Remote.copy_path("https://example.com/.git/config") === nothing
  @test Remote.copy_path("https://example.com/a//b.md") === nothing
  # What comes with a page: the pages of its folder on its site
  @test Remote.inside("https://example.com/a/c.md", "https://example.com/a/b.md")
  @test Remote.inside("https://EXAMPLE.com/a/x/c.md", "https://example.com/a/")
  @test !Remote.inside("https://example.com/c.md", "https://example.com/a/b.md")
  @test !Remote.inside("https://other.com/a/c.md", "https://example.com/a/b.md")
  @test Remote.inside("https://example.com/z/y.md", "https://example.com")
end

@testset "the links and pictures of a page" begin
  lines = ["A [link](a.md) and ![a picture](p.png \"title\") and [one](<my file.md>).",
           "[![a picture in a link](in.png)](out.md) and `[code](no.md)` and \\[not](no.md)",
           "<img src=\"html.png\" alt=\"x\">  [b(1)](b(1).md)",
           "[named]: named.md",
           "[^1]: A footnote names no place, but [its link](foot.md) does.",
           "```",
           "[in code](no.md)",
           "```"]
  found = K.web_links(lines)
  @test [(f[4], f[5]) for f in found] ==
        [("a.md", false), ("p.png", true), ("my file.md", false), ("in.png", true), ("out.md", false), ("html.png", true), ("b(1).md", false), ("named.md", false), ("foot.md", false)]
  # The columns are round the place, as `with_names` takes them
  changed = K.with_names(lines, [(f[1], f[2], f[3], uppercase(f[4])) for f in found])
  @test changed[1] == "A [link](A.MD) and ![a picture](P.PNG \"title\") and [one](<MY FILE.MD>)."
  @test changed[2] == "[![a picture in a link](IN.PNG)](OUT.MD) and `[code](no.md)` and \\[not](no.md)"
  @test changed[3] == "<img src=\"HTML.PNG\" alt=\"x\">  [b(1)](B(1).MD)" && changed[4] == "[named]: NAMED.MD"
end

@testset "a page from a web server has a Save button" begin
  K.navigate!(e, "example.com/docs/")
  frames()
  @test e.buf.path == "https://example.com/docs/" && !K.writes(e.buf)
  @test length(K.copy_part(e)) == 1
  @test occursin("Save a copy", K.BUTTONS[:save_copy].tip(e))
  # A window that isn't on the screen has no panel to ask where the copy goes, so ⌘S does nothing there
  K.save_page!(e)
  frames()
  @test K.copying(e) === nothing && e.buf.path == "https://example.com/docs/"
end

const folder = joinpath(dir, "example.com")

@testset "saving a copy, with what the page links to" begin
  empty!(asked)
  K.copy_site!(e, folder)
  @test K.copying(e) !== nothing && K.BUTTONS[:save_copy].busy(e)
  copied!()
  @test K.copying(e) === nothing
  at(p) = joinpath(folder, p)
  # The pages and files of the site are in the folder at their places on the site
  @test isfile(at("docs/index.md")) && isfile(at("docs/guide.md")) && isfile(at("docs/Sub Part/index.md")) && isfile(at("docs/Sub Part/deep.md"))
  @test read(at("images/air cost.png"), String) == "PNG bytes" && read(at("docs/pic.png"), String) == "more PNG bytes"
  @test read(at("docs/files/prices.pdf"), String) == "%PDF bytes" && isfile(at("docs/notes.md"))
  # Two pages that would have one name: the second gets a number
  @test sort(filter(n -> startswith(n, "a"), readdir(at("docs")))) == ["a-2.md", "a.md"]
  # A page out of the page's folder, a page of HTML, a page of another site and a hidden file aren't saved
  @test !ispath(at("other.md")) && !ispath(at("docs/page.html")) && !ispath(at("docs/page.md")) && !ispath(at("docs/.ladder"))
  @test !("https://example.com/other.md" in asked) && !("https://elsewhere.com/x.md" in asked) && !("https://julialang.org/" in asked)
  @test !("https://example.com/docs/.ladder" in asked) && !("https://example.com/docs/code.md" in asked)
  # Each address was asked for once
  @test length(asked) == length(unique(asked))
  # Each link names the copy when there's one, and the web when there isn't
  index = read(at("docs/index.md"), String)
  @test occursin("The [guide](guide.md#part), a [folder](Sub%20Part/index.md) and [plain words](", index)
  # Each of the two links names the copy of its own page
  plain, same = match(r"\[plain words\]\(([^)]+)\) and \[the same words\]\(([^)]+)\)", index).captures
  @test sort([plain, same]) == ["a-2.md", "a.md"]
  @test read(at("docs/" * plain), String) == "# A as Markdown\n" && read(at("docs/" * same), String) == "# A from its HTML address\n"
  @test occursin("![a plan](../images/air%20cost.png) and <img src=\"pic.png\" style=\"width: 4em\"> and [a sheet](files/prices.pdf).", index)
  @test occursin("[Up](https://example.com/other.md), [Julia](https://julialang.org/), [a page of HTML](https://example.com/docs/page.html), [gone](https://example.com/docs/gone.md),", index)
  @test occursin("[here](#docs), [mail](mailto:sam@example.com), [hidden](https://example.com/docs/.ladder) and [another site](https://elsewhere.com/x.md).", index)
  @test occursin("[named]: notes.md", index) && occursin("[in code](code.md)", index)
  @test startswith(index, "+++\nsite = \"https://example.com\"\n+++\n")
  @test read(at("docs/guide.md"), String) == "# Guide\n\n## Part\n\nBack to [the docs](index.md), and [deeper](Sub%20Part/deep.md).\n"
  @test read(at("docs/Sub Part/index.md"), String) == "# Sub part\n\n[The guide's part](../guide.md#part) and ![a plan](../../images/air%20cost.png)\n"
  @test read(at("docs/Sub Part/deep.md"), String) == "# Deep\n\n[Top](../index.md)\n"
  # Each file knows the address that it came from
  @test K.copied_from(at("docs/index.md")) == "https://example.com/docs/" && K.copied_from(at("images/air cost.png")) == "https://example.com/images/air%20cost.png"
  if Sys.isapple()
    empty!(K.COPY_ADDRESSES)   # read again from the files themselves
    @test K.copied_from(at("docs/guide.md")) == "https://example.com/docs/guide.html" && K.copied_from(joinpath(dir, "settings")) == ""
  end
  # The window shows the copy of the page, which you can change
  @test e.buf.path == at("docs/index.md") && !e.buf.fixed && K.writes(e.buf) && !K.readonly(e.buf)
  @test isempty(K.copy_part(e))
  @test said() == "Saved 7 pages and 3 other files in $(K.tilde(folder)). 1 link had nothing to save."
  # ⌘⌥← goes back to the page from the web
  K.go_back!(e); frames()
  @test e.buf.path == "https://example.com/docs/"
  K.go_forward!(e); frames()
  @test e.buf.path == at("docs/index.md")
end

@testset "the copy runs no code" begin
  @test K.foreign(e.buf.path) && !ispath(ran)
  b = e.buf
  @test K.kinds(b)[findfirst(==("```ui"), b.lines)].lang == "julia"
  @test !any(it -> it.content isa K.Live && it.content.node isa K.Shown, e.layout)
  out = K.run_code(e, "touch($(repr(ran)))")
  @test out[3] && occursin("A copy of a page from a web server runs no code", out[1].msg) && !ispath(ran)
  # A change that you save keeps the mark, so the page still runs no code
  K.edit!(b, (length(b.lines), 0), (length(b.lines), 0), "More words.")
  K.save_page!(e); frames()
  empty!(K.COPY_ADDRESSES)
  @test occursin("More words.", read(b.path, String)) && K.foreign(b.path) && !ispath(ran)
  # A page of your own runs its code, as it did
  mine = joinpath(dir, "mine.md")
  write(mine, "# Mine\n")
  @test !K.foreign(mine)
end

# You can change a page from a web server in the window. A copy has your changes, in the page that you save and in
# each other page of the copy that you changed.
@testset "a copy has the changes that you made in the window" begin
  ending(b, words) = (n = length(b.lines); K.edit!(b, (n, length(b.lines[n])), (n, length(b.lines[n])), words))
  K.navigate!(e, "example.com/docs/guide.html"); frames()
  g = e.buf
  @test K.isremote(g.path) && occursin("# Guide", join(g.lines, "\n"))
  ending(g, "\nMine too.")
  K.navigate!(e, "example.com/docs/"); frames()
  b = e.buf
  @test b.path == "https://example.com/docs/" && b !== g
  ending(b, "\nA line of mine.")
  mine = joinpath(dir, "mine", "example.com")
  K.copy_site!(e, mine); copied!()
  @test occursin("A line of mine.", read(joinpath(mine, "docs/index.md"), String))
  @test occursin("Mine too.", read(joinpath(mine, "docs/guide.md"), String))
  @test isfile(joinpath(mine, "docs/Sub Part/deep.md"))   # a page that you didn't change comes from the server
end

@testset "a copy stops at $(K.COPY_MOST) pages and files" begin
  c = K.SiteCopy("https://example.com/", joinpath(dir, "big"))
  foreach(n -> K.want!(c, "https://example.com/$n.md", true), 1:K.COPY_MOST + 5)
  @test length(c.seen) == K.COPY_MOST && c.over
end

K.PAGE_GETTER[], K.BROWSER[] = was_getter, was_browser
