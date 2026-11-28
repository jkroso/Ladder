# Tests for a docstring of several lines: each line inside it is the colour of a
# string, though it has words like for and end. In a Julia file, in a code block
# of a page, in the card of a name and in the preview of a file. See "strings in
# three quotes" in main.jl, and highlight.jl. Run them with
# `julia -O0 --project=. test/docstring_colour_test.jl`. They draw a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const file = joinpath(dir, "share.jl")
write(file, """
\"\"\"
How much is done, for words like 0.7 or 70%.

It's nothing for other words → like "about half".
A line for the end of it.
More words for the end.
And more, so that a card starts in the middle.
\"\"\"
share(words) = begin
  n = tryparse(Float64, rstrip(words, '%'))
  n === nothing ? nothing : n
end

done = share("70%")
""")

const e = K.build_editor(file)
const w = Window(e, size=(900px, 600px))
const (; frames) = drive(w, latest=true)
frames()
const b = e.buf

"The colours of the parts of line `i`, as the page draws it"
drawn(i) = (it = K.item(e, i); Set(s.face.color for vl in K.in_colour(e, it, it.content).lines for s in vl.segs if !all(isspace, s.text)))

"Each Text in the layout `x`"
texts(x) = begin
  hasfield(typeof(x), :content) && getfield(x, :content) isa AbstractString && return Any[x]
  out, c = Any[], hasfield(typeof(x), :firstchild) ? x.firstchild : nothing
  while c !== nothing
    append!(out, texts(c))
    c = c.nextsibling
  end
  out
end

@testset "the lines inside a docstring of a Julia file are the colour of a string" begin
  @test K.string_opens(b)[1:9] == ['\0', '"', '"', '"', '"', '"', '"', '"', '\0']
  # Words like for and nothing, and a number, are string there. The line with → is laid out in full, as it isn't all typed characters.
  @test drawn(2) == Set([K.colours.string]) && drawn(4) == Set([K.colours.string]) && drawn(7) == Set([K.colours.string])
  @test drawn(9) ⊇ Set([K.colours.call, K.colours.keyword]) && drawn(14) ⊇ Set([K.colours.call, K.colours.string])
end

@testset "a change that opens or closes a docstring above a line changes its colours" begin
  # The docstring's first line no longer opens it, so its lines are code. The line with → was kept from before, and changes too.
  K.edit!(b, (1, 0), (1, 3), "# a note", typing=true)
  frames()
  @test K.string_opens(b)[2] == '\0' && K.colours.keyword in drawn(2) && K.colours.number in drawn(2)
  @test K.colours.keyword in drawn(4)
  # The three quotes at its end open a string that's never closed, so the code after them is string
  @test drawn(9) == Set([K.colours.string])
  K.undo!(b)
  frames()
  @test drawn(2) == Set([K.colours.string]) && drawn(4) == Set([K.colours.string]) && K.colours.keyword in drawn(9)
  # A change far below the docstring leaves it as it was
  K.edit!(b, (14, 0), (14, 4), "half", typing=true)
  frames()
  @test K.string_opens(b)[1:9] == ['\0', '"', '"', '"', '"', '"', '"', '"', '\0'] && drawn(4) == Set([K.colours.string])
  K.undo!(b)
  frames()
end

@testset "the card of a name that starts in the middle of its docstring" begin
  # Long documentation shows its last lines, so the first line of the card is inside the docstring
  c = K.peek_card(e, (14, 7, 12))
  rows = (out = Any[]; r = c.firstchild.firstchild; while r !== nothing; push!(out, texts(r)); r = r.nextsibling end; out)
  line = findfirst(r -> any(x -> startswith(x.content, "It's nothing"), r), rows)
  @test line !== nothing && all(x -> x.color == K.TIP_CODE.string, rows[line])
  @test K.TIP_CODE.call in [x.color for r in rows for x in r]
end

@testset "a docstring in a code block of a page" begin
  page = joinpath(dir, "notes.md")
  write(page, "# Notes\n\n```julia\n\"\"\"\nWords for the end\n\"\"\"\nf(x) = 1\n```\n\nWords for the end\n")
  e2 = K.build_editor(page)
  w2 = Window(e2, size=(900px, 600px))
  foreach(_ -> Base.invokelatest(frame, w2), 1:2)
  colours(i) = Set(s.face.color for vl in K.flow(e2, i).lines for s in vl.segs if !all(isspace, s.text))
  @test colours(5) == Set([K.colours.string]) && K.colours.call in colours(7)
  # The words after the block are words of the page, and nothing is open there
  @test !(K.colours.string in colours(10)) && K.string_opens(e2.buf)[10] == '\0'
  close(w2)
end

@testset "the preview of a file colours its docstrings" begin
  t = K.FileText(["\"\"\"", "Words for the end", "\"\"\"", "f(x) = 1"], false, K.Scroll())
  shown = Set(x.color for x in texts(K.textview(t, "jl")))
  @test K.colours.string in shown && K.colours.call in shown && !(K.colours.keyword in shown)
end

close(w)
