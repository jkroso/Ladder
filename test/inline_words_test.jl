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
