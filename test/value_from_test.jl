# Tests for a click on the value of a name, in main.jl ("where the value of a
# name comes from"): a sum in a line of text that is only a name, like
# !`area`, goes to the part of the page that gives the name its value. Run them
# with `julia -O0 --project=. test/value_from_test.jl`. They click in a window
# that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window Keys
@use "github.com/jkroso/UI.jl/Interface/draw" cursor
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "paint.md")
const filler = join(("Line $k of words that push the rest of the page down." for k in 1:40), "\n\n")
write(page, """
# Paint

A wall that is !`l = 16m` long and !`h = 2.4m` high has an area of !`area = l * h`. Its name is !`label = "the long north wall"`.

```sheet
Wall length = 12m
Wall height = 2.4m
```

```julia
paint = 3
```

$filler

The area is !`area`, and twice that is !`2area`. The length is !`l`. The wall is !`label`. The sheet's wall is !`wall_length`. The paint is !`paint`. This is !`nowhere`.

| Part | Area |
| --- | --- |
| Wall | !`area` |

Now !`l = 2m`, so the length is !`l`.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 700px))
const (; frames, at, press, release, click) = drive(w, pressed=1)
frames()
const doc = K.node!(K.Document, e, :document)
line(start) = findfirst(l -> startswith(l, start), e.buf.lines)
const top_sums = line("A wall")
const uses = line("The area is")
const row = line("| Wall")
const redone = line("Now ")
"The column of line `i` where the code of the `n`th sum `code` on it starts"
code_col(i, code, n=1) = (r = findall("!`" * code * "`", e.buf.lines[i])[n]; length(e.buf.lines[i], 1, first(r)) + 1)
"The place of the sum `code` on line `i`, from its ! to after its last `"
sum_place(i, code, n=1) = (c = code_col(i, code, n); ((i, c - 2), (i, c + length(code) + 1)))

"""
The middle of the `k`th word of what the sum `code` on line `i` shows, in the
window. The line must be on screen. A cell of a table is looked in too.
"""
value_at(i, code; k=1, n=1) = begin
  col = code_col(i, code, n)
  it = K.item(e, i)
  c = it.content
  flows = c isa K.Grid ? [(f, K.cell_origin(c, findfirst(==(i), c.rows), j)) for (j, f) in enumerate(c.flows[findfirst(==(i), c.rows)])] : [(c, (0px, 0px))]
  for (f, (cx, cy)) in flows
    words = [(seg, vl) for vl in f.lines for seg in vl.segs if seg.atomic && seg.node === nothing &&
             (seg.col == col && seg.n == length(code) || K.later_word(seg) && seg.col == col + length(code))]
    length(words) >= k || continue
    seg, vl = words[k]
    return (K.num(e.origin[1] + cx + seg.x + seg.w / 2), K.num(e.origin[2] + it.top + cy + f.above + vl.top + vl.high / 2))
  end
  error("No word $k of !`$code` on line $i")
end

"Scroll so that line `i` is near the top of the window"
show_line(i) = (e.nodes[:hold] = (i, 40px); frames())

@testset "the places that give a name its value" begin
  @test K.givers(e, "area") == [sum_place(top_sums, "area = l * h")]
  @test K.givers(e, "l") == [sum_place(top_sums, "l = 16m"), sum_place(redone, "l = 2m")]
  sheet = findfirst(==("```sheet"), e.buf.lines)
  @test K.givers(e, "wall_length") == [((sheet + 1, 0), (sheet + 1, 0))] && K.givers(e, "wall_height") == [((sheet + 2, 0), (sheet + 2, 0))]
  @test K.givers(e, "paint") == [((line("paint ="), 0), (line("paint ="), 5))]
  @test isempty(K.givers(e, "nowhere"))
  # The last place over the value, or else the first under it
  @test K.giver(e, "l", uses, 0) == sum_place(top_sums, "l = 16m")
  @test K.giver(e, "l", redone, length(e.buf.lines[redone])) == sum_place(redone, "l = 2m")
  @test K.giver(e, "l", 1, 0) == sum_place(top_sums, "l = 16m")
end

@testset "the mouse is a hand over the value of a name" begin
  show_line(uses)
  at(value_at(uses, "area"))
  @test K.giver_at(e, px.(value_at(uses, "area"))) == sum_place(top_sums, "area = l * h")
  @test cursor(doc) == :hand
  # Over each word of a value that has several
  at(value_at(uses, "label", k=3))
  @test cursor(doc) == :hand && K.giver_at(e, w.mouse) == sum_place(top_sums, "label = \"the long north wall\"")
  # Not over code that works something out, nor over a name that nothing on the page gives a value
  at(value_at(uses, "2area"))
  @test cursor(doc) == :ibeam && K.giver_at(e, w.mouse) === nothing
  at(value_at(uses, "nowhere"))
  @test cursor(doc) == :ibeam
  # Not with a key held: ⌥ and a click puts the caret in the code
  at(value_at(uses, "area"))
  w.keys |= Keys.opt
  @test cursor(doc) != :hand
  w.keys ⊻= Keys.opt
end

@testset "a click goes to the sum that gives the name its value, and selects it" begin
  show_line(uses)
  text = copy(e.buf.lines)
  offset = e.scroll.offset
  where_from = value_at(uses, "area")
  press(where_from)
  # The mouse moves a little before it lets go, and the selection stays
  at(where_from .+ (3, 1)); release()
  from, to = sum_place(top_sums, "area = l * h")
  @test e.buf.anchor == from && e.buf.caret == to
  @test e.buf.lines == text
  # The sum was off the screen, so the page scrolled up to it
  @test e.scroll.offset < offset
  it = K.item(e, top_sums)
  @test e.scroll.offset <= K.PAGE_TOP + it.top <= e.scroll.offset + e.scroll.viewport
  # ⌘⌥← comes back
  K.go_back!(e); frames()
  @test e.buf.caret[1] != top_sums && abs(e.scroll.offset - offset) < 1px
end

@testset "a row of a sheet, a julia block, and a cell of a table" begin
  show_line(uses)
  click(value_at(uses, "wall_length"))
  sheet = findfirst(==("```sheet"), e.buf.lines)
  @test e.buf.caret == e.buf.anchor == (sheet + 1, 0)
  show_line(uses)
  click(value_at(uses, "paint"))
  @test e.buf.anchor == (line("paint ="), 0) && e.buf.caret == (line("paint ="), 5)
  show_line(row)
  click(value_at(row, "area"))
  @test (e.buf.anchor, e.buf.caret) == sum_place(top_sums, "area = l * h")
end

@testset "a place that's on screen stays where it is" begin
  show_line(redone - 2)
  offset = e.scroll.offset
  click(value_at(redone, "l"))
  @test (e.buf.anchor, e.buf.caret) == sum_place(redone, "l = 2m")
  @test abs(e.scroll.offset - offset) < 1px
end
