# Tests for the `check` block, in main.jl: each line of the block is a line of
# Julia that must be true. The block shows a green or a red dot for each line,
# and opens to show each line with a tick or a cross. The lines run in the
# module of the page's code, and run again when the page's code runs. Run them
# with `julia -O0 --project=. test/check_view_test.jl`. They draw a window
# that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a
# picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "room.md")
write(page, """
# A room

```julia
walls = [4.0, 3.0, 4.0, 3.0]
ceiling = 2.4
area() = sum(walls) * ceiling
```

```check
# The room as it was measured
length(walls) == 4
area() ≈ 33.6
area() < 30
ceiling
no_such_name > 1
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()
view() = e.nodes[(:block, K.CHECK, page, 1)]
went() = [r.went for r in view().results]
"Click the window at `pos`, as the mouse does"
click(pos) = begin
  w.mouse = typeof(w.mouse)(pos...)
  onmouse(w, MouseMove(pos, w))
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames()
end
"Run the page's Julia block, as ⌘Return in it does"
run_page() = (i = findfirst(==("```julia"), e.buf.lines); t = findnext(==("```"), e.buf.lines, i); K.run_code(e, join(e.buf.lines[i+1:t-1], "\n")); frames())
"Every piece of text that a node shows"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.SemanticUI ? texts(K.describe(node), out) :
  node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end

@testset "the lines that are checks" begin
  @test K.checks(["# Words", "", "  a == 1  ", "b > 2"]) == ["a == 1", "b > 2"]
  @test K.check_words(K.Checked[]) == "No checks yet. Write one on each line, like total == 12."
  one(went) = K.Checked("x", went, "")
  @test K.check_words([one(:pass)]) == "The check passes" && K.check_words([one(:pass), one(:pass)]) == "All 2 checks pass"
  @test K.check_words([one(:pass), one(:fail), one(:stop)]) == "1 of 3 checks passes" && K.check_words([one(:fail)]) == "0 of 1 check pass"
end

@testset "before the page's code has run, each line stops at a name that nothing made" begin
  @test length(view().results) == 5 && all(==(:stop), went())
  @test occursin("walls", view().results[1].said)
end

@testset "each line shows how it went" begin
  run_page()
  rs = view().results
  @test went() == [:pass, :pass, :fail, :fail, :stop]
  # A line that compares two values and fails says what each was
  @test rs[3].said == "33.6 < 30" && isempty(rs[1].said)
  @test rs[4].said == "It came to 2.4, which is neither true nor false."
  @test occursin("no_such_name", rs[5].said)
end

@testset "the checks run again when the page's code runs, and when a line changes" begin
  i = findfirst(==("ceiling = 2.4"), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, length(e.buf.lines[i])), "ceiling = 2.0")
  frames()
  @test went()[3] == :fail   # the code hasn't run yet
  run_page()
  @test went() == [:pass, :fail, :pass, :fail, :stop] && view().results[2].said == "28.0 ≈ 33.6"
  # A line of the block that changes runs again, with the caret out of the block
  i = findfirst(==("area() ≈ 33.6"), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, length(e.buf.lines[i])), "area() ≈ 28")
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
  @test went() == [:pass, :pass, :pass, :fail, :stop]
end

@testset "at first the block is a row of dots, green for a check that passes and red for one that doesn't" begin
  v = view()
  @test !v.open
  dots = [v.parts[(:dot, i)] for i in 1:5]
  @test [K.check_colour(v.results[d.i]) for d in dots] == [K.CHECK_GOOD, K.CHECK_GOOD, K.CHECK_GOOD, K.CHECK_BAD, K.CHECK_BAD]
  # The dots were drawn in one row, at the left of the page, and the block is as tall as a line
  @test all(d -> d.rect[3] > 0px, dots) && allequal(d.rect[2] for d in dots) && issorted([d.rect[1] for d in dots])
  @test rect(v).height < 30px
  # How many pass shows after the dots, with the mouse away from the block
  @test !K.ishovered(v) && "3 of 5 checks pass" in texts(v)
  # The mouse over a dot shows its line, and what it found
  @test K.check_tip(v.results[4]) isa K.Box
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "check-dots.png"), w)
end

@testset "a click on the dots opens the block and runs the checks again, and a click on its top closes it" begin
  ran = Ref(0)
  @eval K.workspace(e) counted() = ($ran[] += 1; true)
  i = findfirst(==("ceiling"), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, length(e.buf.lines[i])), "counted()")
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
  @test went()[4] == :pass && ran[] == 1
  frames()
  @test ran[] == 1   # a frame alone runs nothing
  r = rect(view())
  click(Vec2{px}(r.left + 20px, r.top + r.height / 2))
  @test view().open && ran[] == 2
  @test rect(view()).height > 100px   # each check shows on a line of its own
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "check.png"), w)
  # A click on the rows of the open block does nothing
  r = rect(view())
  click(Vec2{px}(r.left + 60px, r.top + 60px))
  @test view().open && ran[] == 2
  # The button at the top runs them again
  b = view().parts[(:button, :again)]
  click(Vec2{px}(b.rect[1] + b.rect[3] / 2, b.rect[2] + b.rect[4] / 2))
  @test view().open && ran[] == 3
  click(Vec2{px}(r.left + 60px, r.top + 12px))
  @test !view().open && ran[] == 3
end

@testset "the ladder in the top bar goes up and down the block's three levels" begin
  v = view()
  s, t = K.block_lines(e.buf, K.CHECK, 1)
  # With the caret in the page's text, the page answers
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
  @test K.level_part(e) isa K.Document
  # With the caret on the block as a whole, the block answers, and it shows its dots
  e.buf.caret = e.buf.anchor = (s, 0)
  frames()
  @test K.picked(e.buf) == (s, t) && K.level_part(e) === v
  @test K.levels(e) == K.CHECK_LEVELS && K.level(e) == 3
  # ⌘E goes a level down: the block opens
  K.level!(e)
  frames()
  @test v.open && K.level(e) == 2 && K.picked(e.buf) == (s, t)
  # The lowest level shows the block's lines, with the caret in them, and the block still answers
  K.level!(e, 1)
  frames()
  @test e.buf.caret == (s + 1, 0) && K.picked(e.buf) === nothing
  @test K.level_part(e) === v && K.level(e) == 1
  # ⌘E from there goes to the highest level: the dots, with the caret on the block as a whole
  K.level!(e)
  frames()
  @test !v.open && K.level(e) == 3 && K.picked(e.buf) == (s, t)
  # In the page as plain text, the page answers
  e.buf.plain = true
  @test K.level_part(e) isa K.Document
  e.buf.plain = false
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
end

@testset "the block as HTML, and in the Insert menu" begin
  html = K.check_html(e, view())
  @test occursin("<strong>4 of 5 checks pass</strong>", html) && occursin("<li>✓ <code>length(walls) == 4</code></li>", html)
  @test occursin("<li>✗ <code>no_such_name &gt; 1</code>: ", html)
  @test any(x -> x isa Tuple && x[1] == "Check", K.INSERTS) && K.known_lang("check")
end

typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
key(k) = (onkey(w, KeyPress{k}(0, w)); onkey(w, KeyRelease{k}(0, w)); frames())
"Select all that the field holds, as ⌘A does"
select_all() = (w.keys |= Keys.cmd; key(Keys.a); w.keys ⊻= Keys.cmd)
block() = (span = K.block_lines(e.buf, K.CHECK, 1); e.buf.lines[span[1]+1:span[2]-1])
line(k) = view().parts[(:line, k)]
"Click the line of check `k`, `col` characters into its code"
click_line(k, col=0) = (r = rect(line(k)); click(Vec2{px}(r.left + K.CHECK_INSET + K.measure(K.check_face(), "0") * (col + 0.4), r.top + r.height / 2)))
field() = K.check_input(view())

@testset "each check of the open block is changed where it is, as a line of Julia" begin
  e.buf.caret = e.buf.anchor = (1, 0)
  K.open_checks!(view(), true)
  frames()
  @test block()[3] == "area() ≈ 28" && went()[2] == :pass
  # A click on a check's line puts a field there, with the line in it and the caret where the click was
  click_line(2, 4)
  v = view()
  @test v.editing == 2 && w.focus === field() && field().text == "area() ≈ 28" && field().cursor == 4
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "check-field.png"), w)
  # Return writes it into the block's line, and the check runs again
  select_all(); typed("area() ≈ 30"); key(Keys.enter)
  @test block()[3] == "area() ≈ 30" && v.editing == 0 && w.focus === e
  @test went()[2] == :fail && v.results[2].said == "28.0 ≈ 30"
  @test block()[1] == "# The room as it was measured"   # a comment isn't a check, and stays
  # ⌘Z takes the change back
  K.undo!(e.buf); frames()
  @test block()[3] == "area() ≈ 28" && went()[2] == :pass
  # Esc leaves the line as it was
  click_line(1)
  typed(" + 1"); key(Keys.escape)
  @test block()[2] == "length(walls) == 4" && v.editing == 0 && w.focus === e
  # A click somewhere else writes what the field holds
  click_line(3)
  select_all(); typed("area() < 40")
  r = rect(v)
  click(Vec2{px}(r.left + 20px, r.top + r.height + 30px))
  @test block()[4] == "area() < 40" && v.editing == 0 && went()[3] == :pass
  # A check that's left empty is taken away
  click_line(4)
  select_all(); key(Keys.backspace); key(Keys.enter)
  @test !("counted()" in block()) && length(v.results) == 4 && went() == [:pass, :pass, :pass, :stop]
  # The last line of the list adds a check, and stays open for another
  @test "Add a check" in texts(v)
  click_line(5)
  @test v.editing == 5 && field().text == ""
  typed("length(walls) > 3"); key(Keys.enter)
  @test block()[end] == "length(walls) > 3" && went() == [:pass, :pass, :pass, :stop, :pass]
  @test v.editing == 6 && w.focus === field() && field().text == ""
  # Return in it while it's empty, and the field goes
  key(Keys.enter)
  @test v.editing == 0 && w.focus === e && length(v.results) == 5
  # A click on another check while one is being changed writes the first, then opens the second
  click_line(1); select_all(); typed("length(walls) ≥ 4")
  click_line(2)
  @test block()[2] == "length(walls) ≥ 4" && v.editing == 2 && field().text == "area() ≈ 28"
  # Closing the block writes the check too
  select_all(); typed("area() ≈ 28.0")
  K.open_checks!(v, false); frames()
  @test block()[3] == "area() ≈ 28.0" && v.editing == 0 && !v.open
  # A click with ⌥ held on a check of the open block shows the block's lines, and puts no field there
  K.open_checks!(v, true); frames()
  w.keys |= Keys.opt
  click_line(2)
  w.keys ⊻= Keys.opt
  @test v.editing == 0 && K.in_lines(v)
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  # So does a click with ⌥ held on the dots, and the block stays closed
  K.open_checks!(v, false); frames()
  r = rect(v)
  w.keys |= Keys.opt
  click(Vec2{px}(r.left + 20px, r.top + r.height / 2))
  w.keys ⊻= Keys.opt
  @test K.in_lines(v) && !v.open
  e.buf.caret = e.buf.anchor = (1, 0); frames()
end

@testset "the lines of a check block are Julia, as a julia block's are" begin
  @test K.shared_lang(K.CHECK) == "julia" && !(K.CHECK in K.NO_NAMES)
  s, _ = K.block_lines(e.buf, K.CHECK, 1)
  ps = K.pieces(e, "area() ≈ 28", K.kinds(e.buf)[s+2], false)
  @test any(p -> p.face.color == K.colours.number, ps) && any(p -> p.face.color == K.colours.call, ps)
  # A name that the page's code made is offered as it's typed in a new line of the block
  _, t = K.block_lines(e.buf, K.CHECK, 1)
  e.buf.caret = e.buf.anchor = (t - 1, length(e.buf.lines[t-1]))
  K.focus(e)
  frames()
  key(Keys.enter); typed("are")
  found = K.code_offered(e)
  @test found !== nothing && "area" in found[3]
  foreach(_ -> K.undo!(e.buf), 1:2); e.buf.caret = e.buf.anchor = (1, 0); frames()
  @test !("are" in block())
end

@testset "a check of a page that can't be changed has no field" begin
  # A file that can't be written makes the page fixed
  K.save!(e.buf)
  chmod(page, 0o444)
  frames()
  @test e.buf.fixed
  K.open_checks!(view(), true)
  frames()
  @test !("Add a check" in texts(view()))   # no line adds a check
  click_line(1)
  @test view().editing == 0
  chmod(page, 0o644)
  frames()
end

close(w)
