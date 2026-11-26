# Tests for the kinds of diagram that a `mermaid` block draws and that can't be
# changed where they're drawn: a mind map, an entity relationship diagram, a
# Gantt chart and a timeline. See "diagrams" in main.jl. Run them with
# `julia -O0 --project=. test/diagram_kinds_test.jl`. They click and press
# keys in a window that isn't on the screen. Set `LADDER_SHOTS` to a folder,
# and they save a picture of each kind there.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle

@use "../main" => K
const px = K.px

# Each kind: the code of a diagram of it, and code of it with a line that can't be read
const KINDS = [
  "mindmap" => ("""
    mindmap
      root((A page))
        Words
          Headings
          Lists
        Blocks
          [A diagram]
          (A table)
        Sharing
          A page of HTML""",
    "mindmap\n  A page\n    Words\n  Another middle"),
  "erDiagram" => ("""
    erDiagram
      PAGE ||--o{ BLOCK : has
      BLOCK }o--|| KIND : "is of"
      PAGE {
        string path PK
        string title
      }
      BLOCK {
        int line PK
        string kind FK "The language of the block"
      }""",
    "erDiagram\n  PAGE ||--o{ BLOCK : has\n  PAGE has BLOCK"),
  "gantt" => ("""
    gantt
      title A new page
      dateFormat YYYY-MM-DD
      excludes weekends
      section Write
        A first draft   :done, draft, 2024-03-04, 3d
        Read it aloud   :active, read, after draft, 2d
      section Share
        Fix what's wrong :crit, fix, after read, 4d
        Send it          :milestone, after fix, 0d""",
    "gantt\n  A first draft :draft, 2024-03-04, 3d\n  Read it aloud :after nothing, 2d"),
  "timeline" => ("""
    timeline
      title How a page grows
      section The first day
        Morning : Notes : A list of tasks
        Afternoon : A first draft
      section Later
        Next week : Diagrams and tables
                  : A page of HTML to share""",
    "timeline\n  : An event with no period"),
]

const dir = mktempdir()
const page = joinpath(dir, "kinds.md")
write(page, "# Kinds of diagram\n\n" * join(("## $name\n\n```mermaid\n$good\n```\n\n```mermaid\n$bad\n```\n" for (name, (good, bad)) in KINDS), "\n"))

const e = K.build_editor(page)
e.remember = false
const w = Window(e, size=(900px, 3200px))
const (; frames, at, press, release, click, key, shot) = drive(w, moved=2)
frames()

"The diagrams that the page of `e` shows, by their code"
diagrams(e) = Dict(n.value.code => n for n in values(e.nodes) if n isa K.Shown && n.value isa K.Mermaid && rect(n.value) !== nothing)

@testset "a page shows a $name as a diagram" for (name, (good, bad)) in KINDS
  @test K.isdiagram(good)
  shown = diagrams(e)
  @test haskey(shown, good)
  m = shown[good].value
  @test K.num(rect(m).width) > 100 && K.num(rect(m).height) > 60
  @test K.num(rect(m).left) >= 0 && K.num(rect(m).left + rect(m).width) <= 900
  # Code with a line that can't be read shows as code
  @test !K.isdiagram(bad) && !haskey(shown, bad)
end
shot("kinds.png")

@testset "a click and a key on a $name change nothing" for (name, (good, bad)) in KINDS
  lines = copy(e.buf.lines)
  s = diagrams(e)[good]
  click(middle(rect(s.value)))
  @test s.value.picked === nothing && e.buf.lines == lines
  # It fills the window, where a diagram of another kind can be changed. This one can't.
  K.zoom_in!(e, (:diagram, good), s)
  frames()
  v = K.zooming(e)
  @test v !== nothing && v.what == (:diagram, good)
  @test v.zoom > 0 && K.subject_size(v)[1] * v.zoom > K.num(rect(s.value).width)
  m = v.parts[:diagram]
  @test isempty(K.Diagrams.tools(m))
  click((450, 700))
  click((450, 700))
  foreach(key, (Keys.enter, Keys.backspace, Keys.a))
  @test m.picked === nothing && m.typing === nothing && e.buf.lines == lines
  shot("$name-full.png")
  key(Keys.escape)
  @test K.zooming(e) === nothing
end

@testset "each kind is a picture in the page of HTML" begin
  out = K.page_html(e)
  @test count("<div class=\"diagram\">", out) == length(KINDS)
  @test count(r"<svg viewBox=\"0 0 \d+ \d+\"", out) == length(KINDS)
  for (name, (good, bad)) in KINDS
    svg = K.diagram_svg(good)
    # Its lines and its words are all shapes, so it looks the same where the font isn't
    @test svg !== nothing && count("<path", svg) > 10 && !occursin("<text", svg)
    @test K.diagram_svg(bad) === nothing
    @test occursin("<pre><code class=\"language-mermaid\">" * K.escape(bad) * "</code></pre>", out)
  end
end

@testset "each kind shows in the dark page and in a narrow window" begin
  was = e.theme
  K.theme!(e, :night)
  frames(3)
  @test K.dark_page() && length(diagrams(e)) == length(KINDS)
  shot("kinds-dark.png")
  K.theme!(e, was)
  frames()
  narrow = K.build_editor(page)
  narrow.remember = false
  small = Window(narrow, size=(380px, 3200px))
  foreach(_ -> frame(small), 1:2)
  for (code, s) in diagrams(narrow)
    @test K.num(rect(s.value).left) >= 0 && K.num(rect(s.value).left + rect(s.value).width) <= 380
  end
  @test length(diagrams(narrow)) == length(KINDS)
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "kinds-narrow.png"), small)
end

@testset "each diagram that the docs give as an example is drawn" begin
  root = joinpath(@__DIR__, "..")
  for file in ("pages/welcome.md", "plugin/skills/page/SKILL.md")
    blocks = [String(m[1]) for m in eachmatch(r"```mermaid\n(.*?)\n```"s, read(joinpath(root, file), String))]
    @test all(K.isdiagram, blocks)
    for word in ("mindmap", "erDiagram", "gantt", "timeline")
      @test any(code -> startswith(code, word), blocks)
    end
  end
end

exit()
