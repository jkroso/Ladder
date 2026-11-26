# Tests for the browser folder, which keeps each page and file that Ladder gets
# from the web at its place on its site: see "the browser folder" in main.jl,
# and remote.jl. Run them with `julia -O0 --project=. test/browser_folder_test.jl`.
# A function of the tests stands in for `curl`, so they use no network. The
# window isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "../remote" => Remote
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const ran = joinpath(dir, "ran")   # a file that the code of a page would make, if it ran
const browser = joinpath(dir, "Browser")
K.BROWSER_FOLDER[] = browser

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
at(p) = joinpath(browser, p)

@testset "where each address goes, from the folder of its site" begin
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

@testset "the file of the browser folder that keeps each address" begin
  @test K.browser_path("https://example.com/docs/", page=true) == at("example.com/docs/index.md")
  @test K.browser_path("https://Example.COM/a/b.html", page=true) == at("example.com/a/b.md")
  @test K.browser_path("http://example.com/a/b.html", html=true) == at("example.com/a/b.html")
  @test K.browser_path("https://example.com/a/", html=true) == at("example.com/a/index.html")
  @test K.browser_path("https://example.com/i/air%20cost.png") == at("example.com/i/air cost.png")
  @test K.browser_path("https://example.com:8080/a.md", page=true) == at("example.com:8080/a.md")
  @test K.browser_path("https://example.com/.ladder") === nothing && K.browser_path("notes.md") === nothing
  # A file or a folder of the browser folder has a web address. Any other path has none.
  mkpath(at("example.com/x y"))
  write(at("example.com/x y/plain.md"), "# Plain\n")
  @test K.web_address(at("example.com/x y/plain.md")) == "https://example.com/x%20y/plain.md"
  @test K.web_address(at("example.com/x y")) == "https://example.com/x%20y/"
  @test K.web_address(at("example.com")) == "https://example.com/"
  write(at("example.com/x y/index.md"), "# Index\n")
  @test K.web_address(at("example.com/x y/index.md")) == "https://example.com/x%20y/"
  @test K.web_address(joinpath(dir, "settings")) == "" && K.web_address("https://example.com/a.md") == "https://example.com/a.md"
  @test K.in_browser(at("example.com/x y/plain.md")) && !K.in_browser(browser) && !K.in_browser(joinpath(dir, "mine.md"))
  # The fingerprint is the same in every run, so a file that you changed is known after Ladder quits
  @test K.fingerprint(UInt8[]) == "cbf29ce484222325" && K.fingerprint(Vector{UInt8}("a")) == "af63dc4c8601ec8c"
end

@testset "a page goes in the browser folder, marked with its address" begin
  K.navigate!(e, "example.com/docs/")
  frames()
  b = e.buf
  @test b.path == at("example.com/docs/index.md") && read(b.path, String) == join(b.lines, "\n")
  @test K.copied_from(b.path) == "https://example.com/docs/" && K.web_address(b.path) == "https://example.com/docs/"
  @test K.got_mark(b.path) == K.fingerprint(read(b.path)) && !K.changed_here(b.path)
  # It acts as a page of the web: a click on a link opens it, its path in the top bar starts with the site's name,
  # and the window's folder stays as it was
  @test K.follows_links(b) && K.trail_steps(b.path)[1] == ("example.com", "https://example.com/") && e.folder == ""
  @test K.name(b) == "example.com/docs/" && K.bar_name(e) == "docs"
  # The Save A Copy button is gone: the page is a file already, and ⌘S writes your changes to it
  @test K.writes(b) && !isdefined(K, :save_copy!)
  # A page that the server moved goes in the folder at the place that it moved to
  K.follow!(e, "guide.html#part"); frames()
  @test e.buf.path == at("example.com/docs/guide.md") && K.web_address(e.buf.path) == "https://example.com/docs/guide.html"
  # A page of HTML keeps its name
  K.follow!(e, "page.html"); frames()
  @test e.buf.path == at("example.com/docs/page.html") && K.html_shown(e)
end

@testset "a page of the browser folder runs no code" begin
  K.navigate!(e, "example.com/docs/"); frames()
  b = e.buf
  @test K.foreign(b.path) && !ispath(ran)
  @test K.kinds(b)[findfirst(==("```ui"), b.lines)].lang == "julia"
  @test !any(it -> it.content isa K.Live && it.content.node isa K.Shown, e.layout)
  out = K.run_code(e, "touch($(repr(ran)))")
  @test out[3] && occursin("runs no code", out[1].msg) && !ispath(ran)
  # A change that you save keeps the marks, so the page still runs no code, and Ladder knows that you changed it
  K.edit!(b, (length(b.lines), 0), (length(b.lines), 0), "More words.")
  K.save_page!(e); frames()
  empty!(K.COPY_ADDRESSES)
  @test occursin("More words.", read(b.path, String)) && K.foreign(b.path) && !ispath(ran) && K.changed_here(b.path)
  # A page of your own runs its code, as it did
  mine = joinpath(dir, "mine.md")
  write(mine, "# Mine\n")
  @test !K.foreign(mine)
end

@testset "a file of the browser folder that you open is its page" begin
  # Opened as a file, from the sidebar or the Finder, it acts as its page, and Ladder asks the server nothing
  n = length(asked)
  mkpath(at("example.com/docs/Sub Part"))
  write(at("example.com/docs/Sub Part/deep.md"), "# Deep\n\n[Top](../)\n")
  K.show_path!(e, at("example.com/docs/Sub Part/deep.md")); frames()
  @test K.web_address(e.buf.path) == "https://example.com/docs/Sub%20Part/deep.md" && K.follows_links(e.buf) && length(asked) == n
  # Its links are from its address: this one is the page of the folder over it, which the folder keeps already
  K.follow!(e, "../"); frames()
  @test e.buf.path == at("example.com/docs/index.md") && "https://example.com/docs/" in asked[n+1:end]
end

"The words of each Text in the geometry `node`"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end

@testset "the browser folder is a desktop of your favourite sites" begin
  # The desktop looks the same on each Mac that runs the tests. The Mac's desktop is sorted by kind, which a site hasn't.
  K.Desks.looker[] = () -> K.Desks.Look(order=:kind)
  K.Desks.papers[] = () -> ""
  K.FINDER_LOOK[] = (0.0, K.Desks.Look())
  K.WALLPAPER[] = (0.0, "", nothing)
  favourites = at("Favourites.md")
  # The folder has a globe for its icon. The folder of each site in it is a plain folder.
  @test K.found_kind(browser) == K.BrowserDirectory && K.entry_icon(K.FS.get(K.FSPath(browser))) == "globe"
  @test K.FS.get(K.FSPath(at("example.com"))) isa K.FS.Directory
  # The page of favourites at the top of the folder is a page of your own, not of a site
  @test !K.in_browser(favourites) && K.in_browser(at("example.com/docs/index.md")) && K.in_browser(at("example.com"))

  # A page from the web has an empty star in the top bar. A click on it makes the page a favourite, named by its heading.
  K.show_path!(e, at("example.com/docs/index.md")); frames()
  star() = only(K.favourite_bar(e))
  @test star().icon == "star" && K.works_here(e, Val(:add_to_favourites)) && !K.works_here(e, Val(:remove_from_favourites))
  K.BUTTONS[:favourite].run(e); frames()
  @test K.Sites.list(favourites) == [K.Sites.Site("Docs", "https://example.com/docs/")]
  @test star().icon == "star-fill" && !K.works_here(e, Val(:add_to_favourites)) && K.works_here(e, Val(:remove_from_favourites))
  # A page of your own has no star
  K.show_path!(e, favourites); frames()
  @test isempty(K.favourite_bar(e))

  # The folder's page is a desktop with an icon for the site. Without a picture of the site's icon, its tile has its first letter.
  write(favourites, read(favourites, String) * "- [Guide](https://example.com/docs/guide.html)\n")
  K.open_folder!(e, browser); frames()
  v = e.nodes[(:desktop, browser)]
  @test v isa K.SitesView && e.buf.path == browser
  @test v.names == ["Docs", "Guide"] && v.sites["Guide"] == "https://example.com/docs/guide.html"
  words = texts(K.describe(v))
  @test "Docs" in words && "D" in words && "Guide" in words && "G" in words
  # Sorted by name, as a site has no kind
  @test K.desktop_look(v).order == :name && v.spots["Docs"][2] < v.spots["Guide"][2]
  # An icon dropped on another one doesn't go into it, though the site's name is a folder's
  @test !K.takes_drops(v, "Docs")

  # Two clicks, or Return, go to the site
  K.desktop_enter!(v, "Guide"); frames()
  guide = e.buf.path
  @test K.web_address(guide) == "https://example.com/docs/guide.html"
  # ⌘⌫ takes a site off. The page of favourites keeps its other lines.
  K.open_folder!(e, browser); frames()
  v = e.nodes[(:desktop, browser)]
  K.desktop_remove!(v, ["Docs"]); frames()
  @test v.names == ["Guide"] && occursin("# Favourites", read(favourites, String))
  # Remove from Favourites on the page itself takes it off too
  K.show_path!(e, guide); frames()
  K.remove_from_favourites!(e); frames()
  @test isempty(K.Sites.list(favourites)) && only(K.favourite_bar(e)).icon == "star"
  # With no favourites, the desktop says how to add one
  K.open_folder!(e, browser); frames()
  @test "Your favourite sites show here." in texts(K.describe(e.nodes[(:desktop, browser)]))
end

K.PAGE_GETTER[], K.BROWSER[] = was_getter, was_browser
K.BROWSER_FOLDER[] = ""
