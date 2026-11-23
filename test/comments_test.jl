# Tests for comments in the margin, in markdown.jl and main.jl: {==words==}{>>a
# comment<<} shows the comment as a card at the right of the text, level with
# its words. Run them with `julia -O0 --project=. test/comments_test.jl`. Set
# `LADDER_SHOTS` to a folder, and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "../markdown" spans
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

@testset "the markup of a comment" begin
  ss = spans("A {==big **red** dog==}{>>Too loud?<<} ran. {>>Lone<<}")
  marks = [s.text for s in ss if s.markup]
  @test marks == ["{==", "**", "**", "==}", "{>>", "<<}", "{>>", "<<}"]
  # The words that a comment is about have a highlighter's colour, and keep their own markup
  @test all(s -> s.highlit, filter(s -> !s.markup && s.text in ("big ", "red", " dog"), ss))
  @test only(s for s in ss if s.text == "red").bold
  # The comment's words are one span, with no markup read in them
  @test [s.text for s in ss if s.comment] == ["Too loud?", "Lone"]
  @test [s.text for s in spans("{>>a **b** c<<}") if s.comment] == ["a **b** c"]
  # A {== or a {>> with no end is only text
  @test !any(s -> s.markup, spans("a {==b and {>>c"))
end

const dir = mktempdir()
const page = joinpath(dir, "notes.md")
write(page, """
# Notes

The first paragraph has {==some words==}{>>A comment about those words, long enough to wrap onto more than one line of its card.<<} and goes on after them.

A second paragraph has a comment at its end.{>>A comment with no words before it.<<}

- A list item with {==a note==}{>>Short.<<} in it.

A paragraph with no comment.
""")
const plain_page = joinpath(dir, "plain.md")
write(plain_page, "# Plain\n\nA page with no comment in it.\n")

line_of(e, words) = findfirst(l -> occursin(words, l), e.buf.lines)
cards(e) = [e.nodes[(:comment_card, k)] for k in eachindex(K.page_comments(e))]

"An editor of `path` in a window `wide` px across, drawn"
opened(path, wide) = begin
  e = K.build_editor(path)
  w = Window(e, size=(wide * px, 800px))
  foreach(_ -> frame(w), 1:3)
  e, w
end
frames(w) = foreach(_ -> frame(w), 1:3)
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
at(w, (x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(w))
click(w, place) = begin
  at(w, place)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frame(w)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(w)
end

@testset "comments in the margin" begin
  e, w = opened(page, 1500)
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "comments.png"), w)
  notes = K.page_comments(e)
  @test [n.text for n in notes] == ["A comment about those words, long enough to wrap onto more than one line of its card.",
                                    "A comment with no words before it.", "Short."]
  # Rich text shows the words that a comment is about, and hides the comment and its markup
  first_line = line_of(e, "first paragraph")
  f = K.item(e, first_line).content
  shown = join(seg.text for vl in f.lines for seg in vl.segs)
  @test occursin("some words", shown) && !occursin("A comment", shown) && !occursin("{", shown)
  # The words that a comment is about are those between {== and ==}
  text = e.buf.lines[first_line]
  @test text[nextind(text, 0, notes[1].lo + 1):nextind(text, 0, notes[1].hi)] == "some words"
  # On a wide window the text is as wide as ever, in the middle, and the cards are at its right
  @test e.width == K.PROSE_W
  @test K.num(K.text_left(e)) ≈ (1500 - K.num(e.width)) / 2
  @test K.num(e.origin[1]) ≈ K.num(K.text_left(e))
  boxes = [rect(c) for c in cards(e)]
  @test all(r -> K.num(r.left) > K.num(e.origin[1] + e.width), boxes)
  @test all(r -> K.num(r.left + r.width) <= 1500, boxes)
  # Each card is level with its words, unless the card above is in the way, and no card covers another
  @test all(((n, r),) -> K.num(r.top) >= K.num(e.origin[2] + n.at) - 20, zip(notes, boxes))
  @test abs(K.num(boxes[1].top) - K.num(e.origin[2] + notes[1].at)) < 20
  # The third card's words are close under the second card's, so the third card is just under the second
  @test K.num(boxes[3].top - (boxes[2].top + boxes[2].height)) ≈ K.num(K.COMMENT_SPACE)
  @test all(k -> K.num(boxes[k].top) >= K.num(boxes[k-1].top + boxes[k-1].height), 2:length(boxes))
  # A long comment wraps onto more than one line of its card
  @test length(cards(e)[1].lines) > 1 && cards(e)[3].lines == ["Short."]

  # The mouse over a card marks it, and the words that it's about
  at(w, middle(boxes[1]))
  @test K.ishovered(cards(e)[1]) && !K.ishovered(cards(e)[2])

  # A click on a card puts the caret at the start of its comment, and shows the comment as it's written
  click(w, middle(rect(cards(e)[2])))
  second = line_of(e, "second paragraph")
  @test e.buf.caret == (second, notes[2].col) && e.plain
  @test K.item(e, second).content.raw
  @test occursin("{>>A comment with no words before it.<<}", join(seg.text for vl in K.item(e, second).content.lines for seg in vl.segs))
  # That line shows its comment in the text, so the margin has no card for it
  @test [n.text for n in K.page_comments(e)] == ["A comment about those words, long enough to wrap onto more than one line of its card.", "Short."]
  # ⌘E takes the page up again, and the card comes back
  K.level!(e); frames(w)
  @test !e.plain && length(K.page_comments(e)) == 3
end

@testset "a narrow window" begin
  e, w = opened(page, 860)
  # The text gets narrower and goes to the left, so the cards fit at its right
  @test e.width < K.PROSE_W
  @test K.num(K.text_left(e)) ≈ K.num(K.PAGE_X) && K.num(e.origin[1]) ≈ K.num(K.PAGE_X)
  boxes = [rect(c) for c in cards(e)]
  @test all(r -> K.num(r.left) >= K.num(e.origin[1] + e.width) && K.num(r.left + r.width) <= 860, boxes)
end

@testset "Add Comment" begin
  e, w = opened(page, 1500)
  b = e.buf
  i = line_of(e, "with no comment")
  from = length("A paragraph with ")
  b.anchor, b.caret = (i, from), (i, from + length("no comment"))
  K.add_comment!(e); frames(w)
  @test b.lines[i] == "A paragraph with {==no comment==}{>><<}."
  # The caret is in the comment, which shows as it's written, to type
  @test b.caret == (i, length("A paragraph with {==no comment==}{>>")) && e.plain
  K.edit!(b, b.caret, b.caret, "Why not?", typing=true)
  K.level!(e); frames(w)
  @test [n.text for n in K.page_comments(e)][end] == "Why not?"
  # With nothing selected, the comment is about the place where the caret is
  j = line_of(e, "list item")
  b.anchor = b.caret = (j, length(b.lines[j]))
  K.add_comment!(e); frames(w)
  @test endswith(b.lines[j], "in it.{>><<}")
  @test haskey(K.COMMANDS, :add_comment)
end

@testset "a sum in the words of a comment" begin
  sums = joinpath(dir, "sums.md")
  write(sums, "# Sums\n\nA wall {==of !`l = 16m` long==}{>>Is that right?<<} and ==!`2l` highlit==.\n")
  e, w = opened(sums, 1500)
  segs = [seg for vl in K.item(e, 3).content.lines for seg in vl.segs]
  # What a sum shows has the highlighter's colour behind it, as the words round it do
  @test only(seg for seg in segs if seg.text == "16m").face.highlit
  @test only(seg for seg in segs if seg.text == "32m").face.highlit
  @test [n.text for n in K.page_comments(e)] == ["Is that right?"]
end

@testset "a page with no comments" begin
  e = K.build_editor(plain_page)
  w = Window(e, size=(1500px, 800px))
  foreach(_ -> frame(w), 1:3)
  @test K.comment_room(e) == 0px && isempty(K.page_comments(e))
  @test K.num(K.text_left(e)) ≈ (1500 - K.num(e.width)) / 2
  @test !haskey(e.nodes, :comments)
  # The markup of a comment in code is no comment, so it leaves no room for one
  code = joinpath(dir, "code.md")
  write(code, "# Code\n\nWrite `{==words==}{>>a comment<<}` for a comment.\n\n```julia\nx = \"{>>not one<<}\"\n```\n")
  e, w = opened(code, 1500)
  @test K.comment_room(e) == 0px && isempty(K.page_comments(e)) && e.width == K.PROSE_W
end
