# Tests for the lines round the other places that have the word that's
# selected. See `same_word` in page_extras.jl. Run them with
# `julia -O0 --project=. test/same_word_test.jl`. They select text in a window
# that isn't on the screen. With a folder as the first argument, they save
# pictures of the window there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const shots = isempty(ARGS) ? "" : ARGS[1]
const dir = mktempdir()
const file = joinpath(dir, "progress.jl")
write(file, """
progress(lines) = begin
  for line in lines
    m = match(r"done", line)
    isempty(strip(line)) || push!(other, line)
  end
  outline = lines
end
""")
const page = joinpath(dir, "notes.md")
write(page, """
# Notes on a line

Each line of the page has a **line** under it, and [a line](https://line.example) to read.

```julia
line = 1
other = line + 2
```

| Part | Size |
| ---- | ---- |
| line | 2 |
| a line, and lines | 3 |
""")

open!(path) = begin
  e = K.build_editor(path)
  w = Window(e, size=(1000px, 600px))
  foreach(_ -> frame(w), 1:2)
  (e, w)
end
select!(e, w, lo, hi) = (e.buf.anchor = lo; e.buf.caret = hi; foreach(_ -> frame(w), 1:2))
"The line and the columns of each place that has a line round it"
outlined(e) = [(i, from, to) for (i, from, to) in K.same_word(e)]
shot(w, name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "a word that's selected in a file of code" begin
  e, w = open!(file)
  @test isempty(outlined(e))                    # nothing is selected
  select!(e, w, (2, 6), (2, 10))                # `line` in `for line in lines`
  @test K.selected_word(e.buf) == "line"
  # Each other `line` that's a word by itself. Not `lines`, not `outline`, and not the one that's selected.
  @test outlined(e) == [(3, 23, 27), (4, 18, 22), (4, 41, 45)]
  shot(w, "word")
  # A word that's selected from its end to its start
  select!(e, w, (2, 10), (2, 6))
  @test length(outlined(e)) == 3
  # Part of a word is only found where it's a word by itself, as ⌘D finds it
  select!(e, w, (2, 6), (2, 9))
  @test isempty(outlined(e))
  # More than a word, and more than a line
  select!(e, w, (2, 2), (2, 10))
  @test isempty(outlined(e))
  select!(e, w, (2, 6), (3, 3))
  @test isempty(outlined(e))
end

@testset "a place that ⌘D selected has no line round it" begin
  e, w = open!(file)
  select!(e, w, (2, 6), (2, 10))
  K.select_word!(e)
  frame(w)
  @test e.buf.caret == (3, 27)
  @test outlined(e) == [(4, 18, 22), (4, 41, 45)]
  shot(w, "two-selected")
end

@testset "in a page, every kind of line has them" begin
  e, w = open!(page)
  # `line` in the first line of the code block. The heading, the paragraph, the code and the table each have it.
  select!(e, w, (6, 0), (6, 4))
  @test outlined(e) == [(1, 13, 17), (3, 5, 9), (3, 30, 34), (3, 54, 58), (3, 68, 72), (7, 8, 12), (12, 2, 6), (13, 4, 8)]
  shot(w, "page")
  # A word that's selected in the paragraph
  select!(e, w, (3, 5), (3, 9))
  @test K.selected_word(e.buf) == "line"
  @test (6, 0, 4) in outlined(e) && !((3, 5, 9) in outlined(e))
  shot(w, "paragraph")
  # A word that's selected in a cell of the table
  select!(e, w, (12, 2), (12, 6))
  @test length(outlined(e)) == 8 && (13, 4, 8) in outlined(e) && !((12, 2, 6) in outlined(e))
  shot(w, "cell")
  # The line round a word of the table is inside the table
  table = K.item(e, 13)
  inside = [y for (i, _, _, _, _, y) in K.same_word(e) if i == 13]
  @test length(inside) == 1 && table.top < inside[1] < table.top + table.tall
end
