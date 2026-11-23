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
