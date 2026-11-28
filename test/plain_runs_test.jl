# Tests for how a line of text shows as plain text: only the run that the caret
# is in shows its markup, like bold words, a link or inline code, and the rest
# of the line reads as rich text. See "rich text and plain text" in rich.jl. Run
# them with `julia -O0 --project=. test/plain_runs_test.jl`. They use windows
# that aren't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")

"A window that isn't on the screen, on a file with `text` in it, written as plain text"
window(text) = begin
  path = joinpath(dir, "page.md")
  write(path, text)
  e = K.build_editor(path)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  K.focus(e)
  K.plain!(e, true)
  frame(w); frame(w)
  e, w
end

press(w, k) = (onkey(w, KeyPress{k}(0, w)); frame(w))
caret!(e, w, line, col) = (e.buf.caret = e.buf.anchor = (line, col); K.touch!(e); frame(w))
select!(e, w, lo, hi) = (e.buf.anchor = lo; e.buf.caret = hi; K.touch!(e); frame(w))
segs(f) = [seg for vl in f.lines for seg in vl.segs]
"The text that line `i` is drawn as"
drawn(e, i) = join(seg.text for seg in segs(K.item(e, i).content))
"True when all of line `i` shows its markup"
raw(e, i) = (c = K.item(e, i).content; c isa K.Flow && c.raw)
"The column of the line where `s` starts"
at(line, s) = first(findfirst(s, line)) - 1

PAGE = """
# Title

Some **bold** words, a [link](http://x.y) and !`1 + 1` here.
Then more words, long enough to sit under the line above it.

- an item with *slanted* words

| a | b |
|---|---|
| **c** | d |

A note[^1] here.

[^1]: The note.
"""

@testset "as plain text, only the run that the caret is in shows its markup" begin
  e, w = window(PAGE)
  text = e.buf.lines[3]
  @test e.buf.plain

  # With the caret in plain words, the line reads as it does as rich text
  caret!(e, w, 3, 1)
  rich = drawn(e, 3)
  @test !raw(e, 3) && occursin("Some bold words, a link and ", rich) && !occursin("**", rich) && !occursin("1 + 1", rich)

  # In bold words, their ** show, and nothing else's markup does
  caret!(e, w, 3, at(text, "bold") + 2)
  d = drawn(e, 3)
  @test occursin("Some **bold** words, a link and ", d) && !occursin("1 + 1", d) && !raw(e, 3)

  # In inline code, the code shows in place of what it makes, and the rest of the line keeps its look
  caret!(e, w, 3, at(text, "1 + 1") + 1)
  d = drawn(e, 3)
  @test occursin("Some bold words, a link and !`1 + 1` here.", d)
  # ... so the words before the code don't move
  f = K.item(e, 3).content
  caret!(e, w, 3, 1)
  @test K.spot(K.item(e, 3).content, at(text, "and")) == K.spot(f, at(text, "and"))

  # At the edge of a run, the run's markup shows which side of it the caret is on
  caret!(e, w, 3, at(text, "[link]"))
  @test occursin("a [link](http://x.y) and", drawn(e, 3)) && !occursin("**", drawn(e, 3))
  caret!(e, w, 3, at(text, " and"))
  @test occursin("a [link](http://x.y) and", drawn(e, 3))

  # Wherever the caret is, the characters beside it show, so it never stops among characters that don't
  for c in 0:length(text)
    caret!(e, w, 3, c)
    @test any(seg -> !seg.atomic && seg.col <= c <= seg.col + seg.n, segs(K.item(e, 3).content))
  end
  # → goes one character at a time, into each run and out of it
  caret!(e, w, 3, 0)
  for c in 1:length(text)
    press(w, Keys.right)
    @test e.buf.caret == (3, c)
  end

  # A selection shows the markup of the run at each end of it, and of none between
  select!(e, w, (3, at(text, "bold") + 1), (3, at(text, "1 + 1") + 2))
  d = drawn(e, 3)
  @test occursin("**bold**", d) && occursin("!`1 + 1`", d) && !occursin("[link]", d)
end

@testset "what starts a line shows while the caret is in it" begin
  e, w = window(PAGE)
  caret!(e, w, 1, 4)
  @test drawn(e, 1) == "Title"
  caret!(e, w, 1, 0)
  @test drawn(e, 1) == "# Title"
  # A list item's bullet stays while the caret is in its words, and in a run of them
  item = e.buf.lines[6]
  caret!(e, w, 6, at(item, "item"))
  @test startswith(drawn(e, 6), "•") && !occursin("*", drawn(e, 6))
  caret!(e, w, 6, at(item, "slanted"))
  @test startswith(drawn(e, 6), "•") && occursin("*slanted*", drawn(e, 6))
  caret!(e, w, 6, 1)
  @test startswith(drawn(e, 6), "- an item")
  # A footnote's number shows as its name only while the caret is in it, and so does the start of the footnote's text
  note = e.buf.lines[12]
  caret!(e, w, 12, 1)
  @test !occursin("[^1]", drawn(e, 12))
  caret!(e, w, 12, at(note, "^1"))
  @test occursin("note[^1] here", drawn(e, 12))
  caret!(e, w, 14, 9)
  @test !occursin("[^1]", drawn(e, 14))
  caret!(e, w, 14, 1)
  @test startswith(drawn(e, 14), "[^1]: The note.")
end

@testset "a cell of a table shows the markup of the run that the caret is in" begin
  e, w = window(PAGE)
  row = e.buf.lines[10]
  cell(e) = join(seg.text for seg in segs(K.item(e, 10).content.flows[2][1]))
  caret!(e, w, 10, at(row, "c"))
  @test K.item(e, 10).content isa K.Grid && cell(e) == "**c**"
  caret!(e, w, 10, at(row, "d"))
  @test cell(e) == "c"
end

@testset "↑ and ↓ go to the place under the caret in the line as it reads" begin
  e, w = window(PAGE)
  text = e.buf.lines[3]
  # Where the words after the bold ones are in line 3, which reads as rich text with the caret on line 4
  caret!(e, w, 4, 0)
  above = K.item(e, 3).content
  _, x = K.spot(above, at(text, "words"))
  caret!(e, w, 4, K.colat(K.item(e, 4).content, 1, x))
  press(w, Keys.up)
  @test e.buf.caret[1] == 3 && abs(e.buf.caret[2] - at(text, "words")) <= 1
end

@testset "a line that shows as one thing still shows all its markup" begin
  e, w = window("Words.\n\n![a picture](missing.png)\n\n\$\$x^2\$\$\n")
  caret!(e, w, 3, 4)
  @test raw(e, 3) && drawn(e, 3) == "![a picture](missing.png)"
  # A formula on a line of its own shows as one thing when the Mac has the font for maths
  if K.Maths.available()
    caret!(e, w, 5, 3)
    @test raw(e, 5) && drawn(e, 5) == "\$\$x^2\$\$"
  end
end
