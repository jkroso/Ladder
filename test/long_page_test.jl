# Tests for a long page of Markdown, in main.jl: a line of plain text is kept
# from one frame to the next, so each frame lays out only the lines that
# changed and the parts of the page that aren't plain text. What's kept is
# never out of step with the page: these tests compare it with a layout that's
# made from nothing. Run them with `julia -O0 --project=. test/long_page_test.jl`.
# They draw a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "../markdown" Kind
@use "github.com/jkroso/MiniFB.jl" Window Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "./drive" drive
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
section(i) = """
## Section $i

A paragraph of the page, with **bold** words, a [link](https://example.com/$i) and `code` in it, long enough to wrap onto a second line of the window.

- A first item of a list, number $i
- [ ] A to-do item
1. A numbered item

| Name | Length |
|---|---|
| Wall $i | 4.2 |

```julia
area$i = 4.2 * 2.4
```

> A quote about section $i.

A line with a footnote[^n$i] and a sum !`1 + $i`.

[^n$i]: The note.

---
"""
const page = joinpath(dir, "long.md")
write(page, "---\ntitle: A long page\n---\n\n# A long page\n\n" * join(section.(1:300), "\n"))

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 700px))
const (; frames) = drive(w, latest=true)
frames(3)
const b = e.buf
kept() = e.flows[(:plain, b.path)]
"The first line, the last line, the top and the height of each part of the page"
shape() = [(it.first, it.last, it.top, it.tall) for it in e.layout]
"True when the layout is what a layout made from nothing gives"
fresh() = (now = shape(); empty!(e.flows); frames(); now == shape())
line(words) = findfirst(l -> occursin(words, l), b.lines)

@testset "the lines of plain text are kept" begin
  ks = K.kinds(b)
  @test length(kept()) == length(b.lines) > 6000
  plain = count(!isnothing, kept())
  @test plain > 0.5 * length(b.lines)
  # A line that isn't laid out from its own text alone is never kept
  left = Set(ks[i].kind for i in eachindex(ks) if kept()[i] === nothing)
  @test Kind.todo in left && Kind.table in left && Kind.fence in left
  @test kept()[line("A line with a footnote")] === nothing
  @test all(i -> ks[i].kind in K.PLAIN_KINDS, findall(!isnothing, kept()))
  # The next frame takes each kept line as it is
  before = [it.content for it in e.layout]
  frames(1)
  @test all(k -> e.layout[k].content === before[k], findall(it -> it.first == it.last && kept()[it.first] !== nothing, e.layout))
  @test fresh()
end

@testset "a change lays out the lines that changed, and the layout is right" begin
  K.focus(e)
  i = line("A paragraph of the page")
  b.caret = b.anchor = (i, 3)
  ontype(e, Typed('x', w))
  frames()
  @test startswith(b.lines[i], "A pxaragraph") && kept()[i].text === b.lines[i]
  @test fresh()
  # A new line moves every line under it down the page
  K.edit!(b, (i, 0), (i, 0), "# A new heading\n\nWith a paragraph under it.\n\n")
  frames()
  @test fresh()
  # Lines that go, a line that becomes a list item, and a line that becomes code
  K.edit!(b, (i + 8, 0), (i + 30, 0), "")
  frames()
  @test fresh()
  j = line("A quote about section 150")
  K.edit!(b, (j, 0), (j, 2), "- ")
  frames()
  @test K.kinds(b)[j].kind == Kind.bullet && fresh()
  j = line("A paragraph of the page, with **bold** words, a [link](https://example.com/200)")
  K.edit!(b, (j, 0), (j, 0), "```\n")
  frames()
  @test K.kinds(b)[j+1].kind == Kind.code && fresh()
  foreach(_ -> K.undo!(b), 1:5)
  frames()
  @test fresh()
end

@testset "the caret's line shows its markup as plain text, and the page is still right" begin
  e.plain = true
  i = line("## Section 20")
  drawn(i) = join(seg.text for vl in e.layout[findfirst(it -> it.first == i, e.layout)].content.lines for seg in vl.segs)
  # In what starts the heading, the heading shows its # marks. A line that shows the markup of a run of it isn't kept.
  b.caret = b.anchor = (i, 1)
  frames()
  @test kept()[i] === nothing && startswith(drawn(i), "## Section 20")
  @test fresh()
  # In the paragraph's bold words, their ** show, and the heading is kept again as it reads
  b.caret = b.anchor = (i + 2, first(findfirst("bold", b.lines[i+2])))
  frames()
  @test !kept()[i].raw && kept()[i+2] === nothing && occursin("**bold**", drawn(i + 2)) && !occursin("](", drawn(i + 2))
  @test fresh()
  # In plain words, the paragraph reads as rich text, and it's kept
  b.caret = b.anchor = (i + 2, 4)
  frames()
  @test kept()[i+2] !== nothing && !kept()[i+2].raw
  @test fresh()
  # A line across the page shows all its markup
  j = findnext(==("---"), b.lines, i)
  b.caret = b.anchor = (j, 1)
  frames()
  @test kept()[j].raw
  @test fresh()
  e.plain = false
  frames()
  @test fresh()
end

close(w)
