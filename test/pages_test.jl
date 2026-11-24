# Tests for pages/welcome.md, the page that shows everything that Ladder does:
# each of its links goes to a page and a heading that are there, it links to
# every other page that comes with Ladder, every kind of block has an example
# in it or in a page that it links to, and a link that names a heading goes to
# that heading. Run them with `julia -O0 --project=. test/pages_test.jl`. Set
# `LADDER_SHOTS` to a folder, and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const pages = K.pages_dir[]
const hub = joinpath(pages, "welcome.md")
"The links of the page at `path` to its own folder, leaving out the code blocks and the code in a line, which only show how a link is written"
page_links(path) = begin
  text = replace(read(path, String), r"^```.*?^```"ms => "", r"`[^`\n]*`" => "")
  [String(m[1]) for m in eachmatch(r"\]\(([^)\s]+)\)", text) if !occursin("://", m[1])]
end
const links = page_links(hub)
"The file that a link names, and the heading after its #, or \"\". A link to a heading of the same page names that page."
parts(link) = begin
  file, heading = (String.(split(link, '#', limit=2))..., "")[1:2]
  (isempty(file) ? "welcome.md" : file, heading)
end
"The headings of the page at `path`, as a link names them"
headings(path) = (lines = K.text(path); [K.heading_slug(K.rest(lines[i], l.prefix)) for (i, l) in enumerate(K.classify(lines)) if l.kind == K.Kind.heading])

@testset "each link goes somewhere" begin
  @test length(links) > 10
  for link in links
    file, heading = parts(link)
    @test isfile(joinpath(pages, file))
    isempty(heading) || @test heading in headings(joinpath(pages, file))
  end
end

@testset "nothing is left out" begin
  linked = unique(first.(parts.(links)))
  # Every page that comes with Ladder, the settings too. Ladder makes the startup page the first time, so it's yours.
  for name in [readdir(pages); joinpath.("settings", readdir(joinpath(pages, "settings")))]
    (K.ismarkdown(name) && name ∉ ("welcome.md", joinpath("settings", "startup.md"))) || continue
    @test name in linked
  end
  # Every kind of block has an example in the welcome page or a page that it links to. `web` is the name that a `view`
  # block had before, which still works, and the pages use the new one.
  text = join((read(joinpath(pages, file), String) for file in unique([linked; "welcome.md"]) if K.ismarkdown(file)), "\n")
  @test !occursin("\n```$(K.WEBVIEW)\n", text)
  for lang in [K.LIVE, K.SHEET, K.SPREADSHEET, K.DIAGRAM, K.TAKEOFF, K.SCHEDULE, "julia", filter(!=(K.WEBVIEW), keys(K.BLOCKS))...]
    @test occursin("\n```$lang\n", text)
  end
  # The welcome page has the sums in a line of text, and they come to what it says
  @test "sums-in-a-line-of-text" in headings(hub)
  @test !isfile(joinpath(pages, "examples.md"))
end

@testset "a link that names a heading goes to it" begin
  e = K.build_editor(hub)
  w = Window(e, size=(1000px, 800px))
  frames() = foreach(_ -> frame(w), 1:3)
  frames()
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "welcome.png"), w)
  # A click on a link with ⌘ held follows it
  i = findfirst(l -> occursin("(#sums-in-a-line-of-text)", l), e.buf.lines)
  it = K.item(e, i)
  e.scroll.offset = it.top - 200px; frames()   # the line is brought into the window
  # Look for the link's words, a few points at a time, over the line's rows of text
  it = K.item(e, i)   # as the line is now, in the window
  ox, oy = K.num(e.origin[1]), K.num(e.origin[2] + it.top)
  spots = [(x, y) for y in oy:4:oy+K.num(it.tall), x in ox:8:ox+900]
  at = findfirst(((x, y),) -> K.link_at(e, (px(x), px(y))) == "#sums-in-a-line-of-text", spots)
  @test at !== nothing
  x, y = spots[at]
  w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames()
  w.keys |= Keys.cmd | Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.cmd | Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames()
  @test e.buf.path == hub && e.buf.lines[e.buf.caret[1]] == "## Sums in a line of text"
  # The sums under the heading come to what the page says, with no name of a sheet's row in their way
  frames()
  said(code) = K.made(e, code, 1)[1]
  @test said("wall_area = l * h") == "38.4m²" && said("wall_area * 2 / (per_litre / litre)") == "4.8litre"
  @test said("convert(m/s, 150km / 2hr)") == "20.8333m/s" && said("convert(cm, 5ft + 10inch)") == "177.8cm"
  K.open!(e, joinpath(pages, "components.md")); frames()
  K.follow!(e, "welcome.md#charts"); frames()
  @test e.buf.path == hub && e.buf.lines[e.buf.caret[1]] == "## Charts"
  # The heading is near the top of the window
  @test K.num(K.item(e, e.buf.caret[1]).top - e.scroll.offset) < 60
  # A heading of the page that shows, by its words or as a link writes them
  K.follow!(e, "#work-with-an-agent"); frames()
  @test e.buf.lines[e.buf.caret[1]] == "## Work with an agent"
  K.follow!(e, "#Live%20blocks"); frames()
  @test e.buf.lines[e.buf.caret[1]] == "## Live blocks"
  # A page with no such heading still opens
  K.follow!(e, "schedule.md#nothing"); frames()
  @test e.buf.path == joinpath(pages, "schedule.md")
  @test K.heading_slug("Sums in a **line** of text") == "sums-in-a-line-of-text" && K.heading_slug("3D models") == "3d-models"
  # A web address with a # in it is no page
  @test !K.follow_heading!(e, "https://example.com/page#part") && e.buf.path == joinpath(pages, "schedule.md")
end

@testset "the settings page links to each page of examples" begin
  settings = K.settings_page()
  linked = [String(m[1]) for m in eachmatch(r"\]\(\.\./([^)\s]+)\)", read(settings, String))]
  # Each Markdown page in the folder of pages, so a new page needs a link there too
  for name in readdir(pages)
    K.ismarkdown(name) && @test name in linked
  end
  @test all(name -> isfile(joinpath(pages, name)), linked)
  # A link opens its page in the settings window, and ⌘⌥← comes back
  e = K.build_editor(settings)
  K.follow!(e, "../welcome.md")
  @test e.buf.path == hub
  @test K.go_back!(e) && e.buf.path == settings
end
