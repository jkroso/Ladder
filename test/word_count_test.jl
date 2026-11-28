# Tests for the command Word Count, which says how many words a page has. The
# top bar has no count of its own. See `word_count` in code_nav.jl. Run them with
# `julia -O0 --project=. test/word_count_test.jl`. They use windows that
# aren't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame popups
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")

window(text; name="page.md") = begin
  path = joinpath(dir, name)
  write(path, text)
  e = K.build_editor(path)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  K.focus(e)
  e, w
end
frames(w) = (e = w.ui; haskey(e.nodes, :palette) && (e.nodes[:palette].moved = 0.0); frame(w); frame(w))
press(w, k, held...) = (foreach(h -> w.keys |= h, held); onkey(w, KeyPress{k}(0, w)); foreach(h -> w.keys ⊻= h, held); frames(w))
typed(w, s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames(w))
names(e) = [row.name for row in K.palette_rows(e, K.palette(e))]

@testset "the top bar has no count" begin
  e, w = window("# Plans\n\nSome words here.\n")
  @test !haskey(e.nodes, :count)
end

@testset "Word Count says the words, the characters and the reading time" begin
  e, w = window("---\ntitle: A long title of many words\n---\n\n# Plans\n\nOne two three, it's four.\n")
  # The front matter is left out: "Plans" and "One two three it's four" are 6 words, in 7 + 25 characters
  @test K.word_count(e) == "6 words  ·  32 characters  ·  1 min read"
  e, w = window(join(fill("word", 1500), " "))
  @test K.word_count(e) == "1,500 words  ·  7,499 characters  ·  7 min read"
  e, w = window("Hi")
  @test K.word_count(e) == "1 word  ·  2 characters  ·  1 min read"
end

@testset "Word Count runs from the palette, and its answer shows under the top bar" begin
  e, w = window("# Plans\n\nSome words here.\n")
  press(w, Keys.p, Keys.cmd, Keys.shft)
  typed(w, "word count")
  @test "Word Count" in names(e)
  press(w, Keys.enter)
  @test first(K.said_result(e)) == "4 words  ·  23 characters  ·  1 min read"
  frames(w)
  @test any(pop -> pop.key == :result, popups(w))
end

@testset "Word Count works in a file of code, and not in a file that's only shown" begin
  e, w = window("x = 1  # one\n", name="code.jl")
  @test K.in_palette(e, K.COMMANDS[:word_count])
  e, w = window("a,b\n1,2\n", name="table.csv")
  K.readonly(e.buf) && @test !K.in_palette(e, K.COMMANDS[:word_count])
end
