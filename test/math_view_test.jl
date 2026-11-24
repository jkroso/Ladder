# Tests for the formulas of main.jl: maths written in TeX between dollar signs.
# Run them with `julia -O0 --project=. test/math_view_test.jl`. They use a
# window that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they
# save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const M, px = K.Maths, K.px

const dir = mktempdir()
const page = joinpath(dir, "maths.md")
write(page, """
# Maths with \$E = mc^2\$ in it

The roots of \$ax^2 + bx + c = 0\$ are \$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\$, and it costs \$5.

\$\$
\\sum_{n=1}^{\\infty} \\frac{1}{n^2} = \\frac{\\pi^2}{6}
\$\$

\$\$\\int_0^\\infty e^{-x^2}\\,dx = \\frac{\\sqrt{\\pi}}{2}\$\$

```math
\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}
\\begin{pmatrix} x \\\\ y \\end{pmatrix}
```

| Shape | Area |
|---|---|
| Circle | \$\\pi r^2\$ |

- An item with \$\\alpha + \\beta\$ and a \$\\foo\$ that isn't known

The roots of \$ax^2 + bx + c = 0\$ are \$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\$, and it costs \$5.

\$\$

Last line.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
line(text) = findfirst(startswith(text), e.buf.lines)
"The formulas in line `i`, as the pieces of its line that show them"
formulas(i) = [seg for vl in K.item(e, i).content.lines for seg in vl.segs if seg.node !== nothing && seg.node.node isa K.Equation]
key(k, held=Keys(0)) = (w.keys = held; onkey(w, KeyPress{k}(0, w)); w.keys = Keys(0); frames())
caret!(p) = (e.buf.caret = e.buf.anchor = p; K.touch!(e); frames())

const roots = line("The roots")

@testset "a formula in a line of text" begin
  found = formulas(roots)
  @test [seg.node.node.tex for seg in found] == ["ax^2 + bx + c = 0", "x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}"]
  # Each stands for the characters of its TeX, and the dollar signs don't show
  text = e.buf.lines[roots]
  @test all(seg -> K.rest(K.head(text, seg.col + seg.n), seg.col) == seg.node.node.tex && seg.atomic, found)
  @test !any(seg -> occursin("ax^2", seg.text) && seg.node === nothing, [s for vl in K.item(e, roots).content.lines for s in vl.segs])
  # The $ of $5 is a dollar sign
  @test any(seg -> occursin("\$5", seg.text), [s for vl in K.item(e, roots).content.lines for s in vl.segs])
  # It's as wide as the formula, and it's drawn there
  m = found[1].node.node
  @test found[1].w == px(M.wide(K.typeset(m))) && !m.display && m.size == K.body(e).size
  # Two lines with the same text are laid out once, and both show their formulas
  @test K.item(e, roots).content === K.item(e, findlast(startswith("The roots"), e.buf.lines)).content
  # The fraction makes its line of the screen taller than a line of words
  f = K.item(e, roots).content
  @test maximum(vl -> vl.high, f.lines) > f.lh
  # The formula of a heading is as big as the heading's letters, and a done line is set once
  @test only(formulas(1)).node.node.size == K.face(e, K.kinds(e.buf)[1]).size > m.size
  @test K.item(e, roots).content === K.flow(e, roots)
  # A table and a list item hold formulas too
  circle = line("| Circle")
  cell = K.item(e, circle).content.flows[2][2]
  @test any(seg -> seg.node !== nothing && seg.node.node.tex == "\\pi r^2", [s for vl in cell.lines for s in vl.segs])
  @test [seg.node.node.tex for seg in formulas(line("- An item"))] == ["\\alpha + \\beta", "\\foo"]
  # The mouse over a formula says which of its commands Ladder doesn't know
  known, unknown = [seg.node.node for seg in formulas(line("- An item"))]
  @test K.tip(known) == "" && K.tip(unknown) == "Ladder doesn't know \\foo"
  box = rect(unknown)
  spot = Vec2{px}(box.left + box.width / 2, box.top + box.height / 2)
  @test onmouse(unknown, MouseMove(spot, w)) === nothing && onmouse(known, MouseMove(spot, w)) === nothing
  shot("maths.png")
end

@testset "the letters of a formula stand on the line of the words beside it" begin
  item = line("- An item")
  seg = formulas(item)[1]
  m = seg.node.node
  f = K.typeset(m)
  # The box is as far over the middle of the line as it is under it, and the middle is half of a capital letter over the line
  @test m.mid ≈ K.capital(K.body(e)) / 2
  box = rect(m)
  @test box.width == seg.w && box.height ≈ 2K.half_height(m) && K.num(K.half_height(m)) >= M.height(f) - K.num(m.mid) - 0.01
  # A line of the page puts the middle of each thing in it at the same height, so the formula's middle is the middle of its line
  it, flow = K.item(e, item), K.item(e, item).content
  middle = e.origin[2] + it.top + K.line_top(flow, 1) + flow.lines[1].high / 2
  @test abs(K.num(box.top + box.height / 2 - middle)) < 0.01 && box.left ≈ e.origin[1] + seg.x
end

@testset "the caret goes over a formula in one step" begin
  text = e.buf.lines[roots]
  open = findfirst("\$", text).start - 1          # the column before the first $
  close = open + 1 + length("ax^2 + bx + c = 0")   # the column before the $ that closes it
  @test (open + 1, close) in K.wholes(e.buf, roots)
  caret!((roots, open))
  key(Keys.right)
  @test e.buf.caret == (roots, close)
  caret!((roots, close + 1))
  key(Keys.left)
  @test e.buf.caret == (roots, open + 1)
  # As plain text, the formula with the caret shows its TeX and its dollar signs, and the line's other formula still shows as a formula
  K.plain!(e, true); frames()
  caret!((roots, 3))
  @test length(formulas(roots)) == 2
  caret!((roots, open + 2))
  @test length(formulas(roots)) == 1 && any(seg -> occursin("ax^2", seg.text), [s for vl in K.item(e, roots).content.lines for s in vl.segs])
  @test length(formulas(line("- An item"))) == 2   # the other lines still show their formulas
  K.plain!(e, false); frames()
  @test length(formulas(roots)) == 2
end

@testset "a formula on lines of its own" begin
  s = line("\$\$")
  it = K.item(e, s)
  @test it.first == s && it.last == s + 2 && it.content isa K.Live && it.content.node isa K.Equation
  m = it.content.node
  @test m.display && m.tex == "\\sum_{n=1}^{\\infty} \\frac{1}{n^2} = \\frac{\\pi^2}{6}"
  # It's in the middle of the page
  f = K.typeset(m)
  @test rect(m).width ≈ e.width && it.tall ≈ px(M.height(f) + M.depth(f)) + 2K.LIVE_GAP
  # The caret goes onto it as a whole, and Return shows its TeX
  @test K.solid(e.buf, s + 1) == (s, s + 2) && K.part(e.buf, s) == (s, s + 2)
  caret!((s - 1, 0))
  key(Keys.down)
  @test e.buf.caret == (s, 0) && K.picked(e.buf) == (s, s + 2) && K.item(e, s).content isa K.Live
  key(Keys.enter)
  @test e.buf.caret == (s + 1, length(e.buf.lines[s+1])) && K.item(e, s + 1).content isa K.Flow
  @test K.item(e, s + 1).content.kind == K.Kind.code
  caret!((1, 0))
  @test K.item(e, s).content isa K.Live
  # $$ and $$ on one line, and a ```math block
  one = line("\$\$\\int")
  @test K.maths_line(e.buf, one) && K.item(e, one).content.node.tex == "\\int_0^\\infty e^{-x^2}\\,dx = \\frac{\\sqrt{\\pi}}{2}"
  @test K.item(e, one).content.node.display && K.solid(e.buf, one) == (one, one)
  caret!((one, 0))
  @test K.picked(e.buf) == (one, one)
  key(Keys.enter)
  @test e.buf.caret == (one, length(e.buf.lines[one]) - 2) && K.item(e, one).content isa K.Flow
  caret!((1, 0))
  block = line("```math")
  @test K.item(e, block).content.node.tex == "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}\n\\begin{pmatrix} x \\\\ y \\end{pmatrix}"
  # A line of $$ that nothing closes is a line of text
  alone = findlast(==("\$\$"), e.buf.lines)
  @test K.kinds(e.buf)[alone].kind == K.Kind.paragraph && K.item(e, alone).content isa K.Flow
end

@testset "typing a formula" begin
  last = line("Last line.")
  caret!(K.line_end(e.buf, last))
  for c in " \$a^2\$"
    ontype(e, Typed(c, w))
  end
  frames()
  @test endswith(e.buf.lines[last], "Last line. \$a^2\$") && only(formulas(last)).node.node.tex == "a^2"
  # ⌫ takes the whole formula away
  key(Keys.backspace)
  @test e.buf.lines[last] == "Last line. " && isempty(formulas(last))
  K.undo!(e.buf); frames()
end

@testset "a wide formula, the menu and the page as HTML" begin
  @test any(x -> x isa Tuple && x[1] == "Formula", K.INSERTS)
  long = join(("x_{$k}" for k in 1:30), " + ")
  wide = K.equation_item(e, long)
  @test M.wide(K.typeset(wide.node)) <= K.num(e.width) + 0.01 && wide.node.size < K.body(e).size
  # It's never less than half the size of the text
  @test K.equation_item(e, long^8).node.size ≈ K.body(e).size * K.MATHS_SMALLEST
  @test K.equation_item(e, "  ") === nothing
  page = K.page_html(e)
  @test occursin("<math xmlns=\"http://www.w3.org/1998/Math/MathML\"><mi>E</mi><mo>=</mo><mi>m</mi><msup><mi>c</mi><mn>2</mn></msup></math>", page)
  # Words in a formula aren't checked for spelling
  @test isempty(K.misspellings(e, line("- An item")))
end
