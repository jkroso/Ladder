# Tests for wiki links, like [[Ideas]]: how markdown.jl reads them, how the
# page shows them, where `follow!` finds the page that one names, and the HTML
# that `html` writes for one. See "wiki links" in main.jl. Run them with
# `julia -O0 --project=. test/wiki_link_test.jl`. They use a window that isn't
# on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "../markdown" spans wikitarget
@use "../html" html
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use GeometryBasics: Vec2
const px = K.px

"The spans of `text` as (text, markup, link)"
parts(text) = [(s.text, s.markup, s.link) for s in spans(text)]

@testset "markdown.jl reads a wiki link" begin
  @test parts("See [[Ideas]] now") == [("See ", false, ""), ("[[", true, ""), ("Ideas", false, "[[Ideas]]"), ("]]", true, ""), (" now", false, "")]
  # The words after a | show, and the name before it is markup
  @test parts("[[Ideas|my ideas]]") == [("[[Ideas|", true, ""), ("my ideas", false, "[[Ideas]]"), ("]]", true, "")]
  @test parts("[[Ideas#Big step]]") == [("[[", true, ""), ("Ideas#Big step", false, "[[Ideas#Big step]]"), ("]]", true, "")]
  @test parts("[[#End]]")[2] == ("#End", false, "[[#End]]")
  # In a table, the | is written \|
  @test parts("[[Ideas\\|my ideas]]") == [("[[Ideas\\|", true, ""), ("my ideas", false, "[[Ideas]]"), ("]]", true, "")]
  # A | with nothing after it shows the name
  @test parts("[[Ideas|]]") == [("[[", true, ""), ("Ideas", false, "[[Ideas]]"), ("|]]", true, "")]
  # The spaces round the name aren't part of it
  @test parts("[[ Ideas ]]")[2] == (" Ideas ", false, "[[Ideas]]")
  # A wiki link inside bold is bold
  @test all(s -> s.bold, filter(s -> !isempty(s.link), spans("**[[Ideas]]**")))
  # These aren't wiki links
  for text in ("[[]]", "[[ ]]", "[[#]]", "[[|x]]", "[[a]", "[[a] b]]")
    @test all(s -> isempty(s.link), spans(text))
  end
  # A link in brackets is still a link
  @test any(s -> s.link == "url", spans("[[link](url)]"))
  @test wikitarget("[[Ideas#Plans]]") == "Ideas#Plans" && wikitarget("^1") === nothing && wikitarget("https://julialang.org") === nothing
end

@testset "the HTML of a wiki link" begin
  page = html(["[[Ideas|my ideas]], [[My plan#Big step]], [[plan.pdf]], [[Version 1.2]] and [[#End]]"])
  @test occursin("<a href=\"Ideas.md\">my ideas</a>", page)
  @test occursin("<a href=\"My%20plan.md#big-step\">My plan#Big step</a>", page)
  @test occursin("<a href=\"plan.pdf\">", page)
  @test occursin("<a href=\"Version%201.2.md\">", page)
  @test occursin("<a href=\"#end\">", page)
  # Other links are as they were
  @test occursin("<a href=\"https://julialang.org\">", html(["[Julia](https://julialang.org)"]))
end

# A project: its top folder has an .obsidian folder, as an Obsidian vault does
const dir = realpath(mktempdir())
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const top = joinpath(dir, "vault")
mkpath(joinpath(top, ".obsidian"))
mkpath(joinpath(top, "notes"))
mkpath(joinpath(top, "deep", "more"))
mkpath(joinpath(top, ".trash"))
mkpath(joinpath(top, "data"))
write(joinpath(top, "home.md"), "# Home\n\nSee [[Ideas]] and [[Plans|my plans]].\n\n## End\n\nThe end.\n")
write(joinpath(top, "notes", "Ideas.md"), "# Ideas\n\nSome text.\n\n## Big step\n\nA step.\n")
write(joinpath(top, "notes", "Plans.md"), "# Plans\n")
write(joinpath(top, "deep", "more", "Ideas.md"), "# Other ideas\n")
write(joinpath(top, "deep", "more", "page.md"), "# A deep page\n")
write(joinpath(top, ".trash", "Hidden.md"), "# Hidden\n")
write(joinpath(top, "data", "prices.csv"), "a,b\n1,2\n")

const e = K.build_editor(joinpath(top, "home.md"))
const w = Window(e, size=(900px, 700px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
home!() = (K.open!(e, joinpath(top, "home.md")); frames())

@testset "the page shows a wiki link's words, in the colour of a link" begin
  segs = [s for vl in K.item(e, 3).content.lines for s in vl.segs]
  @test join(s.text for s in segs) == "See Ideas and my plans."
  ideas = filter(s -> s.link == "[[Ideas]]", segs)
  @test join(s.text for s in ideas) == "Ideas" && all(s -> s.face.color == K.colours.accent, ideas)
end

@testset "⌘-click on a wiki link shows its page" begin
  it = K.item(e, 3)
  f = it.content::K.Flow
  vl = first(f.lines)
  seg = first(s for s in vl.segs if s.link == "[[Plans]]")
  x, y = e.origin[1] + seg.x + seg.w / 2, e.origin[2] + it.top + f.above + vl.top + vl.high / 2
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  here = e.buf.path
  # With ⇧ or ⌃ held as well as ⌘, or a key that holds all four, the click opens nothing
  for others in (Keys.shft, Keys.ctrl, Keys.shft | Keys.ctrl | Keys.opt)
    w.keys |= Keys.cmd | others | Keys.mouse_left
    onkey(w, KeyPress{Keys.mouse_left}(0, w))
    w.keys = Keys(0)
    onkey(w, KeyRelease{Keys.mouse_left}(0, w))
    frames()
    @test e.buf.path == here
  end
  w.keys |= Keys.cmd | Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys = Keys(0)
  frames()
  @test e.buf.path == joinpath(top, "notes", "Plans.md")
end

@testset "where a wiki link finds its page" begin
  # A page in a folder near the top of the project comes before one deeper down
  home!(); K.follow!(e, "[[Ideas]]"); frames()
  @test e.buf.path == joinpath(top, "notes", "Ideas.md")
  # A page in the page's own folder comes first
  K.open!(e, joinpath(top, "deep", "more", "page.md")); frames()
  K.follow!(e, "[[Ideas]]"); frames()
  @test e.buf.path == joinpath(top, "deep", "more", "Ideas.md")
  # A name with folders in it starts from the top of the project
  K.open!(e, joinpath(top, "deep", "more", "page.md")); frames()
  K.follow!(e, "[[notes/Ideas]]"); frames()
  @test e.buf.path == joinpath(top, "notes", "Ideas.md")
  # The case of the name doesn't matter
  home!(); K.follow!(e, "[[plans]]"); frames()
  @test lowercase(e.buf.path) == lowercase(joinpath(top, "notes", "Plans.md"))
  # A name with a file's extension names that file
  home!(); K.follow!(e, "[[prices.csv]]"); frames()
  @test e.buf.path == joinpath(top, "data", "prices.csv")
end

@testset "a wiki link to a heading" begin
  home!(); K.follow!(e, "[[Ideas#Big step]]"); frames()
  @test e.buf.path == joinpath(top, "notes", "Ideas.md")
  @test e.buf.lines[e.buf.caret[1]] == "## Big step"
  # [[#End]] goes to a heading of the page that shows
  home!(); K.follow!(e, "[[#End]]"); frames()
  @test e.buf.path == joinpath(top, "home.md") && e.buf.lines[e.buf.caret[1]] == "## End"
end

@testset "a wiki link to a page that isn't there opens a new page" begin
  home!(); K.follow!(e, "[[New page]]"); frames()
  new = joinpath(top, "New page.md")
  @test e.buf.path == new && !isfile(new) && e.buf.lines == [""]
  # Its file is made when it's saved with text in it
  K.type!(e, "Hello"); K.save!(e.buf)
  @test read(new, String) == "Hello"
  # A page in a hidden folder isn't found, so its link opens a new page too
  home!(); K.follow!(e, "[[Hidden]]"); frames()
  @test e.buf.path == joinpath(top, "Hidden.md") && !isfile(e.buf.path)
  # A name with folders that aren't there makes the page in the page's own folder
  home!(); K.follow!(e, "[[nowhere/Thing]]"); frames()
  @test e.buf.path == joinpath(top, "Thing.md")
end

@testset "a page outside a project looks in the folders under it" begin
  loose = joinpath(dir, "loose")
  mkpath(joinpath(loose, "sub"))
  write(joinpath(loose, "page.md"), "# Loose\n")
  write(joinpath(loose, "sub", "Other.md"), "# Other\n")
  @test K.project_root(loose) == loose
  @test K.project_root(joinpath(top, "deep", "more")) == top
  K.open!(e, joinpath(loose, "page.md")); frames()
  K.follow!(e, "[[Other]]"); frames()
  @test e.buf.path == joinpath(loose, "sub", "Other.md")
end

@testset "the list of pages while you type a wiki link's name" begin
  type(text) = (foreach(c -> ontype(e, Typed(c, w)), text); frame(w))
  key(k) = (onkey(w, KeyPress{k}(0, w)); frame(w))
  names() = (found = K.suggestion(e); found === nothing ? nothing : found[3])
  K.open!(e, joinpath(top, "typing.md")); frames(); K.focus(e)
  type("See ")
  @test names() === nothing
  # Right after the [[, the list has the project's pages. Two pages called Ideas are told apart by their folders.
  type("[[")
  @test names() !== nothing && issubset(["Plans", "notes/Ideas", "deep/more/Ideas", "home"], names())
  # A page in a hidden folder isn't offered
  @test !("Hidden" in names())
  @test !isempty(K.suggestbox(e))
  # Each page's folder is at the right of its row
  @test e.nodes[:wiki_notes]["Plans"] == "notes" && e.nodes[:wiki_notes]["home"] == ""
  type("pl")
  @test first(names()) == "Plans"
  # Return types the rest of the name and the ]] that ends the link
  key(Keys.enter)
  @test e.buf.lines[end] == "See [[Plans]]" && e.buf.caret == (length(e.buf.lines), length("See [[Plans]]"))
  @test names() === nothing
  # A word of a name fits too, and the page nearer the top of the project comes first
  type(" and [[ide")
  @test names()[1:2] == ["notes/Ideas", "deep/more/Ideas"]
  # ↓ chooses the next one, and Tab types it
  key(Keys.down); key(Keys.tab)
  @test e.buf.lines[end] == "See [[Plans]] and [[deep/more/Ideas]]"
  # Esc hides the list, and a name that fits no page has no list
  type(" [[Pla")
  @test names() == ["Plans"]
  key(Keys.escape)
  @test names() === nothing
  type(" [[zzz")
  @test names() === nothing
  # In a link that has its end already, only the name changes
  b = e.buf
  # Make the last line `text`, with the caret at column `col`
  line!(text, col) = (n = length(b.lines); K.edit!(b, (n, 0), (n, length(b.lines[n])), text); b.caret = b.anchor = (n, col); K.touch!(e); frame(w))
  # Rich text hides the [[P| of such a link, so its name is typed as plain text
  K.plain!(e, true); frames()
  line!("[[P|my plans]]", 3)
  type("l")
  @test names() == ["Plans"]
  key(Keys.enter)
  @test b.lines[end] == "[[Plans|my plans]]"
  K.plain!(e, false); frames()
  # After a | or a #, there's no list: what's typed there is the words that show, or a heading
  line!("[[Plans|", 8); type("m")
  @test names() === nothing
  line!("[[Plans#", 8); type("E")
  @test names() === nothing
  # A code block offers no pages
  line!("```julia\n\n```", 0)
  b.caret = b.anchor = (length(b.lines) - 1, 0); K.touch!(e)
  type("x = [[")
  @test names() === nothing || !("Plans" in names())
end
