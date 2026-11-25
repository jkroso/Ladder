# Tests for the text that a sum in a line of text gives, in main.jl: its words
# wrap like the line's own words, so a long sentence doesn't jump to the next
# line whole. Run them with `julia -O0 --project=. test/inline_words_test.jl`.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "words.md")
const said = "the satellites cost more than their launches, so a cheaper rocket helps but cheaper satellites help more"
write(page, """
# Words

With these numbers, !`n = 3; n > 2 ? "$said" : "no"` and that is all.

| What | Says |
|---|---|
| A long one | !`"$said"` |

A number, !`l = 16m`, stays one piece.
""")

@testset "the words that a sum gives wrap" begin
  e = K.build_editor(page)
  w = Window(e, size=(600px, 800px))
  foreach(_ -> frame(w), 1:3)
  i = findfirst(l -> startswith(l, "With these"), e.buf.lines)
  f = K.item(e, i).content
  rows = [join(seg.text for seg in vl.segs) for vl in f.lines]
  # The sentence starts on the line of the words before it, and goes on over the lines under it
  @test length(rows) >= 2
  @test startswith(rows[1], "With these numbers, the satellites")
  @test occursin("and that is all.", rows[end])
  @test join(rows) == "With these numbers, $said and that is all."
  # The first word stands for all of the sum's code, and the others stand for none of the line
  segs = [seg for vl in f.lines for seg in vl.segs]
  code = findfirst("n = 3", e.buf.lines[i])[1] - 1
  first_word = only(seg for seg in segs if seg.text == "the ")
  @test first_word.col == code && first_word.n == length("n = 3; n > 2 ? \"$said\" : \"no\"") && first_word.atomic
  @test all(seg -> seg.n == 0 && seg.col == first_word.col + first_word.n, filter(seg -> seg.atomic && seg !== first_word, segs))
  # Each screen line still covers the columns of what's on it, so a click finds its place
  @test f.lines[1].from == 0 && f.lines[end].to == length(e.buf.lines[i])
  # In a table, the column is as wide as the longest word, and the sentence wraps in its cell
  g = K.item(e, findfirst(l -> startswith(l, "| A long one"), e.buf.lines)).content
  @test length(g.flows[2][2].lines) > 1
  # A number is still one piece that a drag can take hold of
  j = findfirst(l -> startswith(l, "A number"), e.buf.lines)
  @test any(seg -> seg.text == "16m" && seg.atomic && seg.n == length("l = 16m"), (seg for vl in K.item(e, j).content.lines for seg in vl.segs))
end

@testset "the end of a sum's code is after the last of its words" begin
  e = K.build_editor(page)
  w = Window(e, size=(600px, 800px))
  foreach(_ -> frame(w), 1:3)
  i = findfirst(l -> startswith(l, "With these"), e.buf.lines)
  f = K.item(e, i).content
  start = findfirst("n = 3", e.buf.lines[i])[1] - 1
  stop = start + length("n = 3; n > 2 ? \"$said\" : \"no\"")
  # The sum's last word is on a lower line of the screen than its first
  k = findlast(vl -> any(seg -> seg.atomic && seg.n == 0, vl.segs), f.lines)
  @test k > 1
  last_word = last(filter(seg -> seg.atomic && seg.n == 0, f.lines[k].segs))
  after = last_word.x + last_word.w
  # A caret at the end of the code shows after the last word, not after the first or before the line's first word
  @test K.spot(f, stop) == (k, after)
  # A selection of the whole sum covers all of its words, to the right edge of the last one
  boxes = K.marks(f, 0, 0, (start, stop, false), margin=false)
  @test length(boxes) == k
  @test last(boxes)[3] == K.num(after)
  # A selection from the end of the code starts after the sum's last words
  boxes = K.marks(f, 0, 0, (stop, length(e.buf.lines[i]), false), margin=false)
  @test only(r for r in boxes if r[2] == K.num(K.line_top(f, k)))[1] == K.num(after)
  # In a sentence that fits on one line, ⌘⇧→ from the sum's start selects every word of it
  one = findfirst(l -> startswith(l, "A number"), e.buf.lines)
  K.edit!(e.buf, (one, 0), K.line_end(e.buf, one), "Then !`\"too little to need a reboost\"`")
  K.touch!(e); foreach(_ -> frame(w), 1:2)
  f = K.item(e, one).content
  e.buf.caret = e.buf.anchor = (one, length("Then !`"))
  K.move!(e, K.screen_edge(e, 1), true; by=1)
  vl = only(f.lines)
  @test K.marks(f, 0, 0, K.selected(e.buf, one), margin=false) |> only |> (r -> r[3]) == K.num(last(vl.segs).x + last(vl.segs).w)
end

@testset "a character that the page's font lacks is drawn in a font that has it" begin
  minus = joinpath(dir, "minus.md")
  # A rate shows as 1%/yr now, so the sum gives the raised minus as text
  write(minus, "# Minus\n\nThey lose !`fade = \"0.01yr⁻¹\"` of it each year.\n")
  e = K.build_editor(minus)
  e.font = "Charter"
  K.restyle!(e)
  w = Window(e, size=(600px, 400px))
  foreach(_ -> frame(w), 1:3)
  i = findfirst(l -> startswith(l, "They lose"), e.buf.lines)
  value = only(seg for vl in K.item(e, i).content.lines for seg in vl.segs if seg.text == "0.01yr⁻¹")
  # Charter has no raised minus, so it's in the font that macOS gives Charter for it
  @test !K.has(value.face, '⁻')
  @test [f.family for (_, f) in K.runs(value.text, value.face)] == ["Charter", "Lucida Grande", "Charter"]
  # It's as wide as those fonts draw it, not as wide as the empty box that Charter would draw
  @test value.w == sum(K.width_in(f, t) for (t, f) in K.runs(value.text, value.face))
  texts(node, out=K.Text[]) = (node isa K.Text ? push!(out, node) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children); out)
  @test [(t.content, t.family) for t in texts(K.describe(value))] == [("0.01yr", "Charter"), ("⁻", "Lucida Grande"), ("¹", "Charter")]
  # Code still takes its signs from Menlo, and the symbols of keys do too
  @test K.stand_in_from(K.Face(K.CODE_FONT, K.CODE_STYLE, 13px, K.colours.ink, false)) == K.MONO
  @test K.stand_in_from(K.Face(K.SYMBOL_FONT, "", 13px, K.colours.ink, false)) == K.MONO
end

@testset "a label draws a character that its font lacks in a font that has it" begin
  texts(node, out=K.Text[]) = (node isa K.Text ? push!(out, node) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children); out)
  # An email's subject can end with an emoji, which the sans-serif font lacks
  l = K.label("This time tomorrow, you'll be at Airwallex Shift ⚡", 13px, weight="Semibold")
  @test !(l isa K.Text)
  parts = texts(l)
  @test [t.content for t in parts] == ["This time tomorrow, you'll be at Airwallex Shift ", "⚡"]
  @test parts[1].family == K.SANS && parts[1].subfamily == "Semibold"
  @test parts[2].family != K.SANS && K.has(K.Face(parts[2].family, "", 13px, K.colours.ink, false), '⚡')
  # Words that the font has stay one Text, accents and signs too
  @test K.label("Inbox", 13px) isa K.Text
  @test K.label("Café · 25 Nov – “now”", 12px) isa K.Text
end
