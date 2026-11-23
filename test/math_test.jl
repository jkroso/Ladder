# Tests for math.jl, which sets formulas, and for the parts of markdown.jl and
# html.jl that read them. Run them with `julia -O0 --project=. test/math_test.jl`.
# They open no window.

@use Test: @test, @testset
@use "../math" => M
@use "../markdown" Kind classify spans MATH
@use "../html" html

const SIZE = 20.0
set(tex, display=false) = M.formula(tex, SIZE, display)
"The marks of a formula that are glyphs, and the ones that are lines"
glyphs(f) = filter(m -> m.glyph != 0, f.box.marks)
rules(f) = filter(m -> m.glyph == 0, f.box.marks)
"The mark of the character `c` in `f`"
mark(f, c) = first(m for m in f.box.marks if m.glyph == M.glyph(M.font(), c))

@testset "dollar signs in a line of text" begin
  parts(text) = [(s.text, s.math, s.markup) for s in spans(text)]
  @test parts("so \$x^2\$ is") == [("so ", false, false), ("\$", false, true), ("x^2", true, false), ("\$", false, true), (" is", false, false)]
  @test parts("\$\$a\$\$") == [("\$\$", false, true), ("a", true, false), ("\$\$", false, true)]
  # The * and _ of TeX aren't markup
  @test count(s -> s.math, spans("\$a_1 * b_2\$ and \$c_3\$")) == 2 && !any(s -> s.italic, spans("\$a_1 * b_2\$ and \$c_3\$"))
  # Dollars are dollars
  for money in ("from \$5 to \$10", "\$5-\$10", "it costs \$5 (was \$10)", "pay \$ 5 or \$ 6", "US\$ and A\$", "a \\\$x\\\$ b", "only \$5")
    @test !any(s -> s.math, spans(money))
  end
  @test any(s -> s.math && s.text == "5 + \\\$x", spans("\$5 + \\\$x\$"))
  # Code keeps its dollar signs, and bold text can hold a formula
  @test !any(s -> s.math, spans("`\$x\$`"))
  # A formula can't hold code, so the dollar sign before a sum is a dollar sign, whatever the sum's code holds
  sums = "costs \$!`string(\"\$\", x)` or \$!`y`"
  @test !any(s -> s.math, spans(sums)) && [s.text for s in spans(sums) if s.live] == ["string(\"\$\", x)", "y"]
  @test [s.text for s in spans("\$x\$ costs \$!`a`") if s.math] == ["x"]
  @test any(s -> s.math && s.text == "`a", spans("\$`a\$"))   # a ` by itself is TeX's
  @test any(s -> s.math && s.bold, spans("**so \$x\$**"))
  # The old way to make a span has no formula in it
  @test !spans("a")[1].math
end

@testset "lines of \$\$" begin
  kinds = classify(["text", "\$\$", "x = 1", "```", "\$\$", "more", "```math", "y", "```"])
  @test [k.kind for k in kinds] == [Kind.paragraph, Kind.fence, Kind.code, Kind.code, Kind.fence, Kind.paragraph, Kind.fence, Kind.code, Kind.fence]
  @test all(k -> k.lang == MATH, kinds[2:5]) && kinds[2].level == 0 && kinds[5].level == 1 && kinds[8].lang == MATH
  # One line of $$ with no other after it is a line of text
  @test [k.kind for k in classify(["\$\$", "x", "y"])] == [Kind.paragraph, Kind.paragraph, Kind.paragraph]
  # In a code block, a line of $$ is a line of code
  @test [k.kind for k in classify(["```sh", "\$\$", "echo", "\$\$", "```"])] == [Kind.fence, Kind.code, Kind.code, Kind.code, Kind.fence]
end

@testset "reading TeX" begin
  nodes(tex) = M.nodes(tex)[1]
  @test M.nodes("x")[2] == String[] && M.nodes("\\foo x")[2] == ["\\foo"]
  @test nodes("x")[1] == M.Sym('𝑥', :ord) && nodes("2")[1] == M.Sym('2', :ord) && nodes("\\Gamma")[1].char == 'Γ'
  @test nodes("\\alpha")[1].char == '𝛼' && nodes("\\epsilon")[1].char == '𝜖' && nodes("h")[1].char == 'ℎ'
  @test nodes("\\mathbb{R}")[1].char == 'ℝ' && nodes("\\mathbf{x}")[1].char == '𝐱' && nodes("\\mathrm{d}")[1].char == 'd'
  @test nodes("\\mathcal{L}")[1].char == 'ℒ' && nodes("\\mathbf{\\alpha}")[1].char == '𝛂'
  @test [n.class for n in nodes("a + b = c, (d)")] == [:ord, :bin, :ord, :rel, :ord, :punct, :open, :ord, :close]
  @test nodes("-")[1].char == '−' && nodes("\\le")[1] == M.Sym('≤', :rel) && nodes("\\sum")[1].class == :op && nodes("∑")[1].class == :op
  s = nodes("x_i^2")[1]
  @test s isa M.Scripts && s.base.char == '𝑥' && s.sub.char == '𝑖' && s.sup.char == '2' && s.primes == 0
  @test nodes("f''")[1].primes == 2 && nodes("f'^2")[1].sup.char == '2' && nodes("f'^2")[1].primes == 1
  f = nodes("\\frac{a}{b + c}")[1]
  @test f isa M.Frac && f.num.char == '𝑎' && f.den isa M.Group && f.rule && nodes("\\frac12")[1].den.char == '2'
  @test !nodes("\\binom{n}{k}")[1].rule && nodes("\\dfrac{a}{b}")[1].style == 1
  @test nodes("\\sqrt[3]{x}")[1].degree.items[1].char == '3' && nodes("\\sqrt x")[1].degree === nothing
  l = nodes("\\left( x \\middle| y \\right]")[1]
  @test l isa M.Fenced && l.delims == ['(', '|', ']'] && length(l.parts) == 2
  @test nodes("\\left( x")[1].delims == ['(', '.']
  @test nodes("\\not=")[1].char == '≠' && nodes("\\not\\in")[1].char == '∉'
  @test nodes("\\text{if } x")[1] == M.Words("if ", :ord, false, false) && nodes("\\sin")[1].class == :op
  @test nodes("\\lim")[1].limits && !nodes("\\sin")[1].limits && nodes("\\operatorname*{argmax}")[1].limits
  m = nodes("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix} + 1")
  @test m[1] isa M.Rows && length(m[1].rows) == 2 && length(m[1].rows[1]) == 2 && m[1].left == '(' && m[2].class == :bin
  @test nodes("\\begin{cases} 1 & x \\\\ 2 & y \\\\ \\end{cases}")[1].kind == :cases
  # Lines outside a block are rows, lined up at their & when they have one
  @test nodes("a &= b \\\\ &= c")[1].kind == :aligned && nodes("a \\\\ b")[1].kind == :gathered
  # Brackets that nothing opened or closed do no harm, and a comment is left out
  @test length(nodes("a } b")) == 2 && length(nodes("{a")) == 1 && length(nodes("a % b\nc")) == 2
  @test nodes("\\hat{x}")[1] isa M.Accent && nodes("\\overline{AB}")[1] isa M.Bar && nodes("\\underbrace{a}_{n}")[1].base isa M.Stretch
  @test nodes("\\Bigl(")[1] == M.Sized('(', 2, :open) && nodes("\\quad")[1] == M.Space(18.0)
  @test nodes("\\sum\\nolimits_i")[1].base == M.Limits(M.Sym('∑', :op), false)
end

M.available() && @testset "setting a formula" begin
  x = set("x")
  @test length(x.box.marks) == 1 && M.wide(x) > 8 && M.height(x) > 8 && M.depth(x) < 2 && isempty(x.problems)
  @test set("\\foo").problems == ["\\foo"] && all(m -> m.bad, set("\\foo").box.marks) && !any(m -> m.bad, set("x").box.marks)
  # A superscript is smaller and higher, and a subscript is lower
  f = set("x^2")
  @test mark(f, '2').w ≈ 0.7SIZE && mark(f, '2').y > 0.3SIZE && mark(f, '2').x >= M.wide(x)
  @test mark(set("x_2"), '2').y < -0.1SIZE
  both = set("x_1^2")
  @test mark(both, '2').y - M.depth(set("2")) > mark(both, '1').y + 0.7M.height(set("1"))   # the two don't meet
  @test mark(set("x^{y^2}"), '2').w ≈ 0.55SIZE
  # A prime is at the size of its letter
  @test mark(set("f'"), '′').w == SIZE && mark(set("f'"), '′').y == 0
  # There's room round = and +, and none round the − of −x
  gap(tex, a, b) = (f = set(tex); mark(f, b).x - mark(f, a).x)
  @test gap("a=2", '𝑎', '2') > gap("a2", '𝑎', '2') + 0.5SIZE
  @test gap("a+2", '𝑎', '2') > gap("a2", '𝑎', '2') + 0.4SIZE
  @test mark(set("-2"), '2').x ≈ M.wide(set("-")) && mark(set("(-2)"), '2').x ≈ M.wide(set("(")) + M.wide(set("-"))
  @test mark(set("1-2"), '2').x > M.wide(set("1")) + M.wide(set("-")) + 0.4SIZE
  # In a script there's no room round +
  @test M.wide(set("x^{a+b}")) < M.wide(set("x")) + 0.7M.wide(set("a+b"))
  # A fraction: the top is over the line and the bottom is under it, each in the middle
  f = set("\\frac{a}{b + c}", true)
  line = only(rules(f))
  @test mark(f, '𝑎').y > line.y + line.h && mark(f, '𝑏').y < line.y && line.h > 0.5
  @test mark(f, '𝑎').x > mark(f, '𝑏').x && line.w ≈ M.wide(set("b + c", true))
  # It's smaller in a line of text
  @test mark(set("\\frac{a}{b}"), '𝑎').w ≈ 0.7SIZE && mark(set("\\frac{a}{b}", true), '𝑎').w == SIZE
  @test mark(set("\\dfrac{a}{b}"), '𝑎').w == SIZE
  # A sum sign is bigger on a line of its own, with its limits over and under it
  small, big = set("\\sum_{i=1}^n x"), set("\\sum_{i=1}^n x", true)
  @test M.height(big) + M.depth(big) > 1.5(M.height(small) + M.depth(small))
  @test mark(big, '𝑛').x < mark(big, '𝑥').x - M.wide(x) && mark(small, '𝑛').x > mark(big, '𝑛').x
  @test mark(big, '𝑛').y > mark(big, '𝑖').y + SIZE
  # The limits of an integral stay beside it
  @test mark(set("\\int_0^1 x", true), '1').x > mark(set("\\int_0^1 x", true), '0').x
  # A root sign is as tall as what's under it, with a line over that
  short, tall = set("\\sqrt{x}"), set("\\sqrt{\\frac{a}{b}}", true)
  @test length(rules(short)) == 1 && M.height(tall) + M.depth(tall) > 1.5(M.height(short) + M.depth(short))
  @test rules(short)[1].y >= M.height(x) && rules(short)[1].w ≈ M.wide(x)
  # Brackets grow with what's in them, and plain ones don't
  grown, same = set("\\left( \\frac{a}{b} \\right)", true), set("( \\frac{a}{b} )", true)
  @test M.height(grown) ≈ M.height(same) && glyphs(grown)[1].glyph != glyphs(same)[1].glyph
  @test glyphs(set("\\left( x \\right)"))[1].glyph == glyphs(set("(x)"))[1].glyph
  # A bracket that's taller than the font's tallest one is made of pieces
  huge = set("\\left( \\begin{matrix} 1 \\\\ 2 \\\\ 3 \\\\ 4 \\\\ 5 \\\\ 6 \\\\ 7 \\\\ 8 \\end{matrix} \\right)", true)
  @test length(glyphs(huge)) >= 8 + 6 && M.height(huge) + M.depth(huge) > 8SIZE
  # The cells of a matrix are in columns
  m = set("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}", true)
  @test mark(m, '𝑎').x < mark(m, '𝑏').x && mark(m, '𝑎').y > mark(m, '𝑐').y && abs(mark(m, '𝑏').x - mark(m, '𝑑').x) < 2
  # Lines are lined up at their =
  lines = set("a &= b \\\\ x + y &= c", true)
  @test length(filter(g -> g.glyph == M.glyph(M.font(), '='), lines.box.marks)) == 2
  @test allequal(round(g.x, digits=3) for g in lines.box.marks if g.glyph == M.glyph(M.font(), '='))
  # A hat is over its letter
  h = set("\\hat{x}")
  @test M.height(h) > M.height(x) + 1 && M.wide(h) == M.wide(x)
  # The same formula isn't set twice
  @test set("x^2") === set("x^2")
end

@testset "a formula as MathML" begin
  ml(tex) = replace(M.mathml(tex), r"^<math[^>]*>|</math>$" => "")
  @test startswith(M.mathml("x"), "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">") && occursin("display=\"block\"", M.mathml("x", display=true))
  @test ml("x") == "<mi>x</mi>" && ml("12.5") == "<mn>12.5</mn>" && ml("a + 1") == "<mi>a</mi><mo>+</mo><mn>1</mn>"
  @test ml("x^2") == "<msup><mi>x</mi><mn>2</mn></msup>" && ml("x_i^2") == "<msubsup><mi>x</mi><mi>i</mi><mn>2</mn></msubsup>"
  @test ml("\\frac{a}{b}") == "<mfrac><mi>a</mi><mi>b</mi></mfrac>" && ml("\\sqrt{x}") == "<msqrt><mi>x</mi></msqrt>"
  @test ml("\\sqrt[3]{x}") == "<mroot><mi>x</mi><mrow><mn>3</mn></mrow></mroot>"
  @test ml("\\sum_{i}^{n}") == "<munderover><mo>∑</mo><mi>i</mi><mi>n</mi></munderover>"
  @test ml("\\alpha \\le \\mathbb{R}") == "<mi>α</mi><mo>≤</mo><mi>ℝ</mi>" && ml("f'") == "<msup><mi>f</mi><mo>′</mo></msup>"
  @test ml("a < b") == "<mi>a</mi><mo>&lt;</mo><mi>b</mi>" && ml("\\text{if }") == "<mtext>if </mtext>" && ml("\\sin x") == "<mi>sin</mi><mi>x</mi>"
  @test occursin("<mtable><mtr><mtd", ml("\\begin{matrix} a & b \\end{matrix}")) && occursin("<mo fence=\"true\">(</mo>", ml("\\left( x \\right)"))
end

@testset "a page of HTML with formulas" begin
  page = html(["so \$x^2\$ is", "", "\$\$", "\\frac{a}{b}", "\$\$", "", "\$\$y\$\$", "", "```math", "z", "```", "", "costs \$5"])
  @test occursin("<p>so <math xmlns=\"http://www.w3.org/1998/Math/MathML\"><msup><mi>x</mi><mn>2</mn></msup></math> is</p>", page)
  @test occursin("display=\"block\"><mfrac><mi>a</mi><mi>b</mi></mfrac></math>", page)
  @test occursin("<p><math xmlns=\"http://www.w3.org/1998/Math/MathML\" display=\"block\"><mi>y</mi></math></p>", page)
  @test occursin("display=\"block\"><mi>z</mi></math>", page) && occursin("<p>costs \$5</p>", page) && !occursin("<pre>", page)
end
