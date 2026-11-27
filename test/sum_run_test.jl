# Tests for ⌘Return in the code of a sum in a line of text, in main.jl ("code
# that runs where it is", `run_sum_here!`): it runs the sum, or the part of it
# that's selected, and shows what that comes to in a box under the code. Run
# them with `julia -O0 --project=. test/sum_run_test.jl`. They press keys in a
# window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window Keys
@use "github.com/jkroso/UI.jl/Interface/draw" rect
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "wall.md")
const TEXT = """
# Wall

A wall that is !`l = 16m` long and !`h = 2.4m` high has an area of !`wall_area = l * h`.

| Wall | Both sides |
| --- | --- |
| North | !`north = l * h * 2` |

The code \\!`l * 100` is written out, and not run.

Some words.
"""
write(page, TEXT)

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const b = e.buf
const (; frames, key, typed) = drive(w)
frames()

line(start) = findfirst(l -> startswith(l, start), b.lines)
const words = line("A wall")
const row = line("| North")
const written = line("The code")
const words_only = line("Some words")
"The column of line `i` where `text` starts, the `n`th time it's there"
col(i, text, n=1) = (r = findall(text, b.lines[i])[n]; length(b.lines[i], 1, first(r)) - 1)

"""
Put the text back as it was, with no outcomes, and select line `i` from column
`lo` to `hi`. The page is plain text, where a sum shows its code while the
caret is in it, as after ⌘E. With `plain=false` it's rich text.
"""
fresh!(i, lo, hi=lo; plain=true) = begin
  e.plain = plain
  b.lines = String.(split(TEXT, '\n'))
  b.version = (K.stamp[] += 1)   # a new version, as an edit gives
  b.reading = false
  empty!(K.outcomes(e))
  K.focus(e)   # as a click on the page does
  b.anchor, b.caret = (i, lo), (i, hi)
  frames()
end
run!() = key(Keys.enter, Keys.cmd)
"The outcome of line `i`, or nothing"
outcome(i) = (k = findfirst(o -> o.first == i, K.outcomes(e)); k === nothing ? nothing : K.outcomes(e)[k])

"Where column `c` of line `i` is in the window: the left of it, and the bottom of its screen line. A cell of a table is looked in too."
place(i, c) = begin
  it = K.item(e, i)
  g = it.content
  f, x, y = if g isa K.Grid
    at = K.gridcell(g, (i, c))
    cx, cy = K.cell_origin(g, at...)
    (g.flows[at[1]][at[2]], cx, cy)
  else
    (g, 0px, 0px)
  end
  k, cx = K.spot(f, c)
  (left=K.num(e.origin[1] + x + cx), bottom=K.num(e.origin[2] + it.top + y + K.line_top(f, k) + f.lines[k].high))
end

@testset "⌘Return in a sum runs the part of its code that's selected" begin
  at = col(words, "l * h")
  fresh!(words, at, at + 1)   # the l of wall_area = l * h
  run!()
  o = outcome(words)
  @test o !== nothing && !o.failed
  @test occursin("16", o.brief)
  @test o.cols == (at, at + 1)
  @test b.anchor == (words, at) && b.caret == (words, at + 1)   # the selection stays
  @test b.lines[words] == split(TEXT, '\n')[words]   # and the text doesn't change
  # The box is under the code, from the left of what's selected
  r, p = rect(o), place(words, at)
  @test K.num(r.top) >= p.bottom
  @test K.num(r.left) ≈ p.left atol=1
end

@testset "⌘Return with the caret in a sum runs all of it" begin
  at = col(words, "wall_area")
  fresh!(words, at + 3)
  run!()
  o = outcome(words)
  @test o !== nothing && !o.failed
  @test occursin("38.4", o.brief)
  @test o.cols == (at, at + length("wall_area = l * h"))
  @test rect(o) !== nothing
  # ⇧Return does the same, and doesn't start a new line in the sum
  fresh!(words, at + 3)
  key(Keys.enter, Keys.shft)
  @test outcome(words) !== nothing && length(b.lines) == length(split(TEXT, '\n'))
end

@testset "a sum in a cell of a table" begin
  at = col(row, "h * 2")
  fresh!(row, at, at + 1)   # the h
  run!()
  o = outcome(row)
  @test o !== nothing && !o.failed && occursin("2.4", o.brief)
  r, p = rect(o), place(row, at)
  @test K.num(r.top) >= p.bottom
  @test K.num(r.left) ≈ p.left atol=1
end

@testset "the box goes when the caret leaves the sum, or the code changes" begin
  at = col(words, "l * h")
  fresh!(words, at, at + 1)
  run!()
  @test outcome(words) !== nothing
  # The caret moves about in the sum, and the box stays
  b.anchor = b.caret = (words, at + 3)
  frames()
  @test outcome(words) !== nothing
  # It leaves the sum
  b.anchor = b.caret = (words, 0)
  frames()
  @test outcome(words) === nothing
  # A change to the code
  fresh!(words, at, at + 1)
  run!()
  b.anchor = b.caret = (words, at + 5)
  typed("2")
  @test outcome(words) === nothing
  # Escape takes it away
  fresh!(words, at, at + 1)
  run!()
  key(Keys.escape)
  @test isempty(K.outcomes(e))
end

@testset "as rich text, the ends of what a sum shows aren't in its code" begin
  n = length(split(TEXT, '\n'))
  from = col(words, "wall_area")
  to = from + length("wall_area = l * h")
  # The caret stops before and after the value, and ⌘Return there makes a new line when no agent waits
  for c in (from, to)
    fresh!(words, c, plain=false)
    run!()
    @test isempty(K.outcomes(e)) && length(b.lines) == n + 1
  end
  # A box from the plain level goes when the page is rich text again, as the sum then shows its value
  at = col(words, "l * h")
  fresh!(words, at, at + 1)
  run!()
  b.anchor = b.caret = (words, at + 3)
  frames()
  @test outcome(words) !== nothing
  e.plain = false
  frames()
  @test outcome(words) === nothing
end

@testset "⌘Return outside a sum does what it did" begin
  n = length(split(TEXT, '\n'))
  # In the words of a line with sums, and in a line with none, it makes a new line when no agent waits
  for (i, c) in ((words, 2), (words_only, 4))
    fresh!(i, c)
    run!()
    @test isempty(K.outcomes(e)) && length(b.lines) == n + 1
  end
  # Code that's written out with a \ in front of its ! isn't a sum
  fresh!(written, col(written, "l * 100") + 1)
  run!()
  @test isempty(K.outcomes(e))
end
