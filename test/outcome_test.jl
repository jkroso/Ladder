# Tests for the code that runs where it is. See "code that runs where it is" in
# main.jl. Run them with `julia -O0 --project=. test/outcome_test.jl`. They press keys
# and click in a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "sums.md")
const TEXT = """
# Sums

```julia
x = 1 + 2
y = x * 10

# doubles a number
double(n) = begin
  2n
end

m = [1 2; 3 4]
println("hi")
error("no")
nothing
```

Some words.

```python
print(1)
```
"""
write(page, TEXT)

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const b = e.buf
const (; frames, at, typed, key) = drive(w)
frames()

"Put the text back as it was, with no outcomes, and the caret at `line` and `col`"
fresh!(line, col=0) = begin
  b.lines = String.(split(TEXT, '\n'))
  b.version = (K.stamp[] += 1)   # a new version, as an edit gives
  b.reading = false
  empty!(K.outcomes(e))
  K.focus(e)   # as a click on the page does
  caret!(line, col)
end
caret!(line, col=0) = (b.caret = b.anchor = (line, col); frames())
run!() = key(Keys.enter, Keys.cmd)
step!() = key(Keys.enter, Keys.shft)
click(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); w.keys ⊻= Keys.mouse_left; frames())
"The outcome whose code ends on `line`, or nothing"
outcome(line) = (k = findfirst(o -> o.last == line, K.outcomes(e)); k === nothing ? nothing : K.outcomes(e)[k])

const shots = get(ENV, "OUTCOME_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "the pieces of a block of code" begin
  @test K.statements(["x = 1 + 2", "y = x * 10", "", "# doubles a number", "double(n) = begin", "  2n", "end", "", "m = [1 2; 3 4]"]) ==
        [1:1, 2:2, 4:7, 9:9]
  @test K.statements(["a = 1; b = 2", "c = 3"]) == [1:1, 2:2]
  @test K.statements(["f(1,", "  2)", "", "# the end"]) == [1:2]
  @test K.statements(["x = (1,"]) == [1:1]   # code that isn't finished is still a piece, and running it says what's wrong
  @test K.statements(String[]) == []
  @test K.statements(["", "  "]) == []
end

@testset "⌘Return runs the line that the caret is in" begin
  fresh!(4, 3)
  run!()
  o = outcome(4)
  @test o.brief == "3" && !o.failed && !o.more
  @test b.caret == (4, 3)   # the caret stays
  @test b.lines[4] == "x = 1 + 2"   # and the text doesn't change
  # A name that one line makes is there for the next
  caret!(5)
  run!()
  @test outcome(5).brief == "30"
  @test length(K.outcomes(e)) == 2
  shot("two")
end

@testset "the box is after the end of the line of code" begin
  fresh!(4)
  run!()
  r = rect(outcome(4))
  it = K.item(e, 4)
  f = it.content
  line_end = K.num(e.origin[1]) + K.num(K.xcol(f.lines[1], f.lines[1].to))
  @test K.num(r.left) ≈ line_end + K.num(K.OUTCOME_GAP) atol=1
  top = K.num(e.origin[2]) + K.num(it.top)
  @test top <= K.num(r.top) && K.num(r.top) + K.num(r.height) <= top + K.num(it.tall) + 1
end

@testset "an expression of several lines runs whole" begin
  fresh!(9, 1)
  run!()
  o = outcome(10)
  @test o !== nothing && o.first == 7   # with the comment above it
  @test startswith(o.brief, "double")
  # The comment and the last line run it too
  for line in (7, 10)
    fresh!(line)
    run!()
    @test outcome(10) !== nothing
  end
  # A blank line runs the piece above it
  fresh!(11)
  run!()
  @test outcome(10) !== nothing && length(K.outcomes(e)) == 1
end

@testset "a value of several lines opens with a click" begin
  fresh!(12)
  run!()
  o = outcome(12)
  @test o.brief == "2×2 Matrix{Int64}:"
  @test o.more && !o.open
  click(middle(rect(o)))
  @test o.open
  @test o.rest == " 1  2\n 3  4"
  @test K.num(rect(o.body).top) > K.num(rect(o).top)
  @test b.caret == (12, 0)   # the click didn't move the caret
  shot("open")
  click(middle(rect(o)))
  @test !o.open
end

"The colour of the window at the point (x, y), as it draws now"
colour_at((x, y)) = begin
  file = joinpath(dir, "colour.png")
  save_png(file, w)
  p = pixels(file)
  s = size(p, 2) / 1000   # the picture can have more than one pixel for each point
  p[round(Int, y * s) + 1, round(Int, x * s) + 1]
end

@testset "an open box keeps its colour under the mouse" begin
  fresh!(12)
  run!()
  o = outcome(12)
  "A point in the box, left of its arrow, where only its colour shows"
  inside() = (r = rect(o); (K.num(r.left) + 3, K.num(r.top) + K.num(r.height) / 2))
  away = (900, 700)
  at(away); plain = colour_at(inside())
  at(inside()); @test colour_at(inside()) != plain   # a closed box shows that a click opens it
  click(inside())
  @test o.open
  at(away); plain = colour_at(inside())
  at(inside()); @test colour_at(inside()) == plain
  click(inside())
  @test !o.open
end

@testset "what the code printed, what went wrong, and nothing" begin
  fresh!(13)
  run!()
  @test outcome(13).brief == "hi" && !outcome(13).failed
  caret!(14)
  run!()
  @test outcome(14).failed && outcome(14).brief == "no"
  caret!(15)
  run!()
  @test outcome(15).full == "" && !outcome(15).failed && !outcome(15).more
  @test rect(outcome(15)) !== nothing
  shot("kinds")
  # Code that ends with a semicolon shows no value
  fresh!(4, 9)
  typed(";")
  run!()
  @test outcome(4).full == "" && !outcome(4).failed
  # Code that can't be read says so
  fresh!(4, 8)
  typed("]")
  @test b.lines[4] == "x = 1 + ]2"
  run!()
  @test outcome(4).failed
  @test length(K.outcomes(e)) == 1   # the lines after it are pieces of their own
end

@testset "⇧Return runs the code and goes to the next piece" begin
  fresh!(4, 2)
  step!()
  @test outcome(4).brief == "3"
  @test b.caret == (5, 0)
  step!()
  @test outcome(5).brief == "30"
  @test b.caret == (7, 0)
  step!()
  @test outcome(10) !== nothing
  @test b.caret == (12, 0)
  @test length(b.lines) == length(split(TEXT, '\n'))   # no new lines
  # At the last piece, the caret stays at the end of it
  fresh!(15)
  step!()
  @test b.caret == (15, 7)
end

@testset "the line that opens the block runs every piece, as far as one that fails" begin
  fresh!(3)
  run!()
  @test [o.last for o in K.outcomes(e)] == [4, 5, 10, 12, 13, 14]
  @test outcome(14).failed
  shot("all")
end

@testset "a selection runs the code that's selected" begin
  fresh!(4)
  b.anchor, b.caret = (4, 4), (4, 9)
  frames()
  run!()
  @test outcome(4).brief == "3"
  @test b.anchor == (4, 4) && b.caret == (4, 9)
  # Whole lines, as far as the start of the line after them
  fresh!(4)
  b.anchor, b.caret = (4, 0), (6, 0)
  frames()
  run!()
  @test outcome(5) !== nothing && outcome(5).first == 4 && outcome(5).brief == "30"
end

@testset "a box follows its code, and goes when the code changes" begin
  fresh!(5)
  run!()
  # A new line above the code
  caret!(1, 6)
  key(Keys.enter)
  @test length(K.outcomes(e)) == 1 && outcome(6) !== nothing
  # A change to the line after it
  caret!(8, 0)
  typed("#")
  @test outcome(6) !== nothing
  # A change to the code itself
  caret!(6, 1)
  typed("y")
  @test isempty(K.outcomes(e))
end

@testset "Escape takes the boxes away, and then hides the caret" begin
  fresh!(4)
  run!()
  caret!(5)
  run!()
  key(Keys.escape)
  @test isempty(K.outcomes(e))
  @test !b.reading
  key(Keys.escape)
  @test b.reading
end

@testset "the keys do what they did in other places" begin
  n = length(split(TEXT, '\n'))
  # ⇧Return in a paragraph, and in code that isn't Julia, makes a new line
  for line in (18, 21)
    fresh!(line)
    step!()
    @test length(b.lines) == n + 1
    @test isempty(K.outcomes(e))
  end
  # ⌘Return there runs nothing. With no agent that waits for the page, it makes a new line, as it did before.
  fresh!(21)
  run!()
  @test isempty(K.outcomes(e)) && length(b.lines) == n + 1
end

@testset "a value that's a UI node shows as the node" begin
  fresh!(4, 9)
  key(Keys.enter)
  typed("Checkbox()")
  run!()
  o = outcome(5)
  @test o !== nothing && !o.failed
  @test o.brief == "Checkbox" && o.node !== nothing && o.open
  frames()
  @test rect(o.body) !== nothing
  shot("node")
end

@testset "a value has the colours of Julia code" begin
  "Each Text in the layout `node`, in the order they read"
  texts(node, out=K.Text[]) = begin
    node isa K.Text ? push!(out, node) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
    out
  end
  words(node) = [t.content for t in texts(node)]
  colour(node, word) = only(t.color for t in texts(node) if t.content == word)
  fresh!(12)
  run!()
  o = outcome(12)
  box = K.describe(o)
  @test join(words(box)) == "2×2 Matrix{Int64}:"
  @test colour(box, "Matrix") == K.colours.type
  @test all(t.color == K.colours.number for t in texts(box) if t.content == "2")
  click(middle(rect(o)))
  body = K.describe(o.body)
  @test colour(body, "3") == K.colours.number
  # Text that the code printed has the colour of the page's text, and what went wrong is red
  fresh!(13)
  K.edit!(b, (13, 0), (13, length(b.lines[13])), "println(\"Matrix 3\")")
  caret!(13)
  run!()
  @test words(K.describe(outcome(13))) == ["Matrix 3"]
  @test colour(K.describe(outcome(13)), "Matrix 3") == K.colours.ink
  caret!(14)
  run!()
  @test colour(K.describe(outcome(14)), "no") == K.SPELL_RED
  # A character that the code font lacks is drawn in a font that has it
  fresh!(4)
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "collect(1:100)")
  caret!(4)
  run!()
  o = outcome(4)
  click(middle(rect(o)))
  @test occursin("⋮", o.rest)
  @test K.font_with('⋮') != K.CODE_FONT && !isempty(K.font_with('⋮'))
  @test [t.family for t in texts(K.describe(o.body)) if t.content == "⋮"] == [K.font_with('⋮')]
  # macOS finds a font for any character, like the star that starts the name of a module that Kip loaded
  @test !isempty(K.font_with('⭒')) && K.has(K.Face(K.font_with('⭒'), "", 12px, K.colours.ink, false), '⭒')
  @test [f.family for (_, f) in K.runs("Main.⭒Paint", K.outcome_face(12px))] == [K.CODE_FONT, K.font_with('⭒'), K.CODE_FONT]
  shot("colours")
end

@testset "code is in the light font, and a character that the font lacks is in one that has it" begin
  fresh!(4)
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "3 ∈ [1, 2, 3]  # yes")
  caret!(5)
  segs = K.item(e, 4).content.lines[1].segs
  @test all(seg.face.family in (K.CODE_FONT, K.MONO) for seg in segs)
  @test join(seg.text for seg in segs) == b.lines[4]
  plain = first(seg for seg in segs if seg.text == "3")
  @test (plain.face.family, plain.face.style) == (K.CODE_FONT, K.CODE_STYLE)
  @test only(seg for seg in segs if occursin("yes", seg.text)).face.style == K.CODE_SLANT
  if K.CODE_FONT != K.MONO
    @test only(seg for seg in segs if occursin('∈', seg.text)).face.family == K.MONO
  end
  # The caret still lands where a click is: the columns of the line's parts run on from each other
  @test [seg.col for seg in segs] == cumsum([0; [seg.n for seg in segs[1:end-1]]])
  caret!(4)
  run!()
  @test outcome(4).brief == "true"
  shot("light")
end

@testset "code can use a name that a live block has, like width, for a thing of its own" begin
  fresh!(4)
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "width = 2.4")
  K.edit!(b, (5, 0), (5, length(b.lines[5])), "height = width * 2")
  K.edit!(b, (12, 0), (12, length(b.lines[12])), "Row(width(100px), height(20px))")
  caret!(4)
  step!()
  step!()
  @test outcome(4).brief == "2.4" && outcome(5).brief == "4.8"
  # A live block's module keeps the name's own meaning, and gives it to a page that hasn't changed it
  @test K.sandbox(e).width !== 2.4
  @test !isdefined(K.sandbox(e), :double)
  was, b.path = b.path, joinpath(dir, "other.md")
  caret!(12)
  run!()
  @test !outcome(12).failed && outcome(12).node !== nothing
  # The units of a sheet are there too, on a page that hasn't used `m` for a thing of its own
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "12m * 2.4m")
  b.path = joinpath(dir, "other.md")
  caret!(4)
  run!()
  @test !outcome(4).failed
  @test endswith(outcome(4).brief, "m²")   # square metres
  empty!(K.outcomes(e))
  b.path = was
end

@testset "a function with the name of a unit is a function of the page" begin
  # A unit, like bar, is a type, so Julia would take `bar(x) = …` as a new way to make the unit
  pressure = joinpath(dir, "pressure.md")
  write(pressure, "# Pressure\n")
  ep = K.build_editor(pressure)
  value, _, failed = K.run_code(ep, "bar(x::String) = length(x)")
  @test !failed && value isa Function && nameof(value) == :bar
  @test K.run_code(ep, "bar(\"four\")")[1] == 4
  bar = Base.invokelatest(getglobal, K.units(), :bar)
  @test !hasmethod(bar, Tuple{String})
  # The other units are still there
  @test endswith(K.value_text(K.run_code(ep, "2kg")[1]), "kg")
  # With documentation, a macro, and in a begin block
  value, _, failed = K.run_code(ep, "begin\n  \"half of x\"\n  @inline ms(x) = x / 2\nend")
  @test !failed && value isa Function && K.run_code(ep, "ms(3)")[1] == 1.5
  # In a live block, and in the julia blocks of a page that defines a kind of block
  @test K.evaluate(ep, "day(x) = 2x; day(4)"; inline=true)[1] == "8"
  write(joinpath(dir, "yr.md"), "```julia\nyr(lines) = length(lines)\n```\n")
  from = K.source_module(e, "./yr.md")
  @test Base.invokelatest(getglobal, from, :yr) isa Function
  @test Base.invokelatest(Base.invokelatest(getglobal, from, :yr), ["a", "b"]) == 2
end

@testset "a line that ends near the edge of the window has its box under it" begin
  # A line of code that's as wide as the page, and comes to a value that's as long
  vl = K.item(e, 4).content.lines[1]
  wide = K.num(K.measure(first(vl.segs).face, "0"))
  n = floor(Int, (K.num(e.width) - K.num(vl.x)) / wide) - 1
  fresh!(4)
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "string(\"" * "a"^(n - 10) * "\")")
  caret!(4)
  run!()
  o = outcome(4)
  @test o !== nothing && !o.failed
  it = K.item(e, 4)
  @test length(it.content.lines) == 1   # the line doesn't wrap
  @test K.num(rect(o).top) >= K.num(e.origin[2]) + K.num(it.top) + K.num(it.tall) - 6
  @test K.num(rect(o).left) < K.num(e.origin[1]) + 60
  @test K.num(rect(o).left) + K.num(rect(o).width) <= 1000
  shot("under")
end

@testset "a page has one module, named by its path, for each window that shows it" begin
  fresh!(4)
  run!()
  @test outcome(4).brief == "3"
  m = K.workspace(e)
  @test nameof(m) == Symbol("⭒", Base.Filesystem.contractuser(realpath(page)))
  # A second window with the page has the same module, so what the first one ran is there
  e2 = K.build_editor(page)
  w2 = Window(e2, size=(800px, 600px))
  frame(w2); frame(w2)
  @test K.workspace(e2) === m
  value, _, failed = K.run_code(e2, "x * 2")
  @test !failed && value == 6
  # A name that acts on a window acts on the one whose code ran in the module last
  was = e.theme, e2.theme
  e.theme, e2.theme = :paper, :night
  @test K.run_code(e2, "page_theme()")[1] == "Night"
  @test K.run_code(e, "page_theme()")[1] == "Paper"
  e.theme, e2.theme = was
  # Another page has a module of its own
  third = joinpath(dir, "third.md")
  write(third, "# Third\n")
  @test K.workspace(K.build_editor(third)) !== m
  @test K.run_code(K.build_editor(third), "x")[3]
  # A page that defines a kind of block has one module too. Its blocks and the code that you run on it share it,
  # whichever of the two made the module first.
  write(joinpath(dir, "stars.md"), "```julia\nstars(lines) = length(lines)\n```\n")
  from = K.source_module(e, "./stars.md")
  @test isdefined(from, :stars) && K.workspace(K.build_editor(joinpath(dir, "stars.md"))) === from
  write(joinpath(dir, "moons.md"), "```julia\nmoons(lines) = 2\n```\n")
  mine = K.workspace(K.build_editor(joinpath(dir, "moons.md")))
  @test !isdefined(mine, :moons)
  @test K.source_module(e, "./moons.md") === mine && isdefined(mine, :moons)
end

@testset "a live block runs in the page's module, with the page's julia blocks" begin
  live = joinpath(dir, "live.md")
  write(live, """
    # Live

    ```ui
    from_live = 41
    ```

    ```julia
    from_live + 1
    ```

    ```ui
    nothing_called_this
    ```
    """)
  before = length(K.problems)
  e3 = K.build_editor(live)
  w3 = Window(e3, size=(800px, 600px))
  frame(w3); frame(w3)
  m = K.workspace(e3)
  @test nameof(m) == Symbol("⭒", Base.Filesystem.contractuser(realpath(live)))
  @test isdefined(m, :from_live)
  value, _, failed = K.run_code(e3, "from_live + 1")
  @test !failed && value == 42
  # What goes wrong in a live block names the page's module, so it says which page
  @test any(p -> occursin("nothing_called_this", p) && occursin(realpath(live), p), K.problems[before+1:end])
  # A name that acts on a window acts on the front window when it shows the page, as for a click on a button
  # that the page's code made, and on the window that runs code in the module while it runs
  e4 = K.build_editor(live)
  w4 = Window(e4, size=(800px, 600px))
  frame(w4); frame(w4)
  @test K.workspace(e4) === m
  was = e3.theme, e4.theme
  e3.theme, e4.theme = :paper, :night
  theme = Base.invokelatest(getglobal, m, :page_theme)
  K.FRONT_WINDOW[] = e4
  @test Base.invokelatest(theme) == "Night"
  @test K.run_code(e3, "page_theme()")[1] == "Paper"
  K.FRONT_WINDOW[] = e3
  @test Base.invokelatest(theme) == "Paper"
  # With no window in front, it's the window whose code ran in the module last
  K.FRONT_WINDOW[] = nothing
  K.run_code(e4, "1")
  @test Base.invokelatest(theme) == "Night"
  e3.theme, e4.theme = was
end

"The pixels of the box of `o`, as the window draws it now"
box_pixels(o) = begin
  file = joinpath(dir, "box.png")
  save_png(file, w)
  p = pixels(file)
  s = size(p, 2) / 1000   # the picture can have more than one pixel for each point
  r = rect(o)
  p[round(Int, K.num(r.top) * s) + 1:round(Int, K.num(r.top + r.height) * s), round(Int, K.num(r.left) * s) + 1:round(Int, K.num(r.left + r.width) * s)]
end

"Draw frames until the code that `o` waits for comes back, for no more than `most` seconds"
come_back!(o, most=10) = (t = time(); while o.since > 0 && time() - t < most; sleep(0.02); frames(1) end; o)

@testset "slow code shows a spinner in its box, and the window goes on drawing" begin
  K.RUN_WAIT[] = 0.1
  try
    fresh!(4)
    # The code runs in a thread of its own, so the window doesn't wait for it
    t = @elapsed o = K.outcome!(e, 4:4, "let t = time(); while time() - t < 1.5; rand(8) end; 42 end")
    @test t < 0.6
    @test o.since > 0 && o.brief == "" && !o.more
    frames()
    @test rect(o) !== nothing   # the box shows at once
    # The spinner in the box turns
    before = box_pixels(o)
    sleep(0.3); frames()
    @test box_pixels(o) != before
    shot("spinner")
    come_back!(o)
    @test o.since == 0 && o.brief == "42"
    frames()
    still = box_pixels(o)
    sleep(0.3); frames()
    @test box_pixels(o) == still   # no spinner once the result is there
    # Code that comes back within a tenth of a second shows at once, with no spinner
    o = K.outcome!(e, 5:5, "1 + 1")
    @test o.since == 0 && o.brief == "2"
    # A piece waits for the one before it, so it sees what that one made
    a = K.outcome!(e, 4:4, "(sleep(0.5); made_slowly = 5)")
    z = K.outcome!(e, 5:5, "made_slowly + 1")
    @test a.since > 0 && z.since > 0
    come_back!(z)
    @test a.brief == "5" && z.brief == "6"
    # A name that acts on the window gets there from the thread that runs the code
    was = e.theme
    e.theme = :night
    @test come_back!(K.outcome!(e, 4:4, "(sleep(0.2); page_theme())")).brief == "\"Night\""
    e.theme = was
    if Threads.nthreads(:interactive) > 0
      @test come_back!(K.outcome!(e, 4:4, "Threads.threadid()")).brief != string(Threads.threadid())
    end
    # Running a whole block stops at the first piece that fails, and the pieces after it have no box
    fresh!(3)
    K.run_pieces!(e, [4:4, 5:5, 6:6], ["sleep(0.3)", "error(\"no\")", "x = 99"], stop=true)
    @test length(K.outcomes(e)) == 3
    come_back!(K.outcomes(e)[2])
    frames()
    @test [o.first for o in K.outcomes(e)] == [4, 5] && K.outcomes(e)[2].failed
  finally
    K.RUN_WAIT[] = Inf
  end
end
