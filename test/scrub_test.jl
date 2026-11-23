# Tests for a number that a drag changes, in main.jl and sheet.jl: a sum in a
# line of text and a row of a sheet. Run them with
# `julia -O0 --project=. test/scrub_test.jl`. They drag in a window that isn't
# on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "../sheet" number_at nudged
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame cursor
@use GeometryBasics: Vec2
const px = K.px

@testset "the one number of a piece of code" begin
  @test number_at("16") == (0, 2) && number_at("16m") == (0, 2) && number_at(" 2.4m ") == (1, 4)
  @test number_at("l = 16m") == (4, 6) && number_at("coverage=16m^2 / litre") == (9, 11) && number_at("x = -3.50") == (4, 9)
  @test number_at("16m²") == (0, 2) && number_at("150km / hr") == (0, 3)
  # Code that works something out has no one number to drag
  @test number_at("l * h") === nothing && number_at("12 * 2.4") === nothing && number_at("area = l * 2") === nothing
  # A name after a number isn't a unit
  @test number_at("2area") === nothing && number_at("x = 3wall") === nothing && number_at("16m * litre") == (0, 2)
  @test number_at("x == 3") === nothing && number_at("1e5") === nothing && number_at("ceil(3)") === nothing && number_at("") === nothing
end

@testset "a number after some steps" begin
  @test nudged("16", 1) == "17" && nudged("16", -20) == "0" && nudged("-3", -2) == "-5" && nudged("-3", 5) == "2"
  @test nudged("2.4", 3) == "2.7" && nudged("2.40", 1) == "2.41" && nudged("0.5", -9) == "0.0" && nudged("9.9", 1) == "10.0"
end

const dir = mktempdir()
const page = joinpath(dir, "paint.md")
write(page, """
# Paint

A wall that is !`l = 16m` long and !`h = 2.4m` high has an area of !`area = l * h`. Twice that is !`2area`.

```sheet
Wall length = 12m
Wall height = 2.4m
Area = wall length * wall height
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 700px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
const prose = findfirst(l -> startswith(l, "A wall"), e.buf.lines)
text() = e.buf.lines[prose]
said(code) = K.made(e, code, 1)[1]
"The middle of the `k`th sum of the line of prose, in the window"
sum_at(k) = begin
  it = K.item(e, prose)
  found = [(seg, vl) for vl in it.content.lines for seg in vl.segs if seg.atomic && seg.node === nothing]
  seg, vl = found[k]
  (K.num(e.origin[1] + seg.x + seg.w / 2), K.num(e.origin[2] + it.top + it.content.above + vl.top + vl.high / 2))
end
"The middle of what row `r` of the sheet comes to"
chip_at(r) = begin
  it = K.item(e, findfirst(==("```sheet"), e.buf.lines) + 1)
  s = it.content
  wide = K.chip_w(K.Face(K.SHEET_FONT, K.SHEET_WEIGHT, s.size, K.colours.ink, false), s.results[r])
  (K.num(e.origin[1] + e.width - K.SHEET_X - wide / 2), K.num(e.origin[2] + it.top + K.row_top(s, r) + s.heights[r] / 2))
end
row(r) = e.buf.lines[findfirst(==("```sheet"), e.buf.lines) + r]
results() = [r.text for r in K.item(e, findfirst(==("```sheet"), e.buf.lines) + 1).content.results]

@testset "a sum in a line of text" begin
  @test said("area = l * h") == "38.4m²" && said("2area") == "76.8m²"
  first_sum, second_sum = sum_at(1), sum_at(2)   # where they are before a drag makes one wider
  @test K.scrub_at(e, px.(first_sum)) == (prose, 21, 23) && K.scrub_at(e, px.(sum_at(3))) === nothing
  at(first_sum)
  @test cursor(K.node!(K.Document, e, :document)) == :resize_x
  caret = e.buf.caret
  press(first_sum)
  @test haskey(e.nodes, :scrub) && e.buf.caret == caret
  at(first_sum .+ (10, 0))
  @test occursin("!`l = 18m`", text())
  at(first_sum .+ (20, 3)); frames()
  @test occursin("!`l = 20m`", text()) && e.buf.caret == caret
  # The sums that use the name follow while the mouse moves
  @test said("l = 20m") == "20m" && said("area = l * h") == "48m²" && said("2area") == "96m²"
  at(first_sum .- (500, 0)); frames()
  @test occursin("!`l = 0m`", text()) && said("area = l * h") == "0m²"
  at(first_sum .+ (20, 0))
  release()
  @test !haskey(e.nodes, :scrub) && occursin("!`l = 20m`", text())
  # The mouse has let go, so a move changes nothing more
  at(first_sum .+ (60, 0))
  @test occursin("!`l = 20m`", text())
  # One ⌘Z takes the whole drag back, and the sums follow it back
  K.undo!(e.buf); frames()
  @test occursin("!`l = 16m`", text()) && said("area = l * h") == "38.4m²" && said("2area") == "76.8m²"
  # A number with a digit after its point moves by that digit, and ⇧ makes each step ten times as big
  second_sum = sum_at(2)
  press(second_sum); at(second_sum .+ (15, 0))
  @test occursin("!`h = 2.7m`", text())
  w.keys |= Keys.shft
  at(second_sum .+ (20, 0))
  w.keys ⊻= Keys.shft
  @test occursin("!`h = 6.4m`", text())
  release()
  @test said("area = l * h") == "102.4m²"
end

@testset "a click that doesn't move puts the caret" begin
  press(sum_at(1)); release()
  @test e.buf.caret[1] == prose && occursin("!`l = 16m`", text())
end

@testset "a row of a sheet" begin
  @test results() == ["12m", "2.4m", "28.8m²"]
  @test K.scrub_at(e, px.(chip_at(1))) == (findfirst(==("```sheet"), e.buf.lines) + 1, 14, 16) && K.scrub_at(e, px.(chip_at(3))) === nothing
  chip = chip_at(1)
  press(chip)
  at(chip .- (10, 0)); frames()
  @test row(1) == "Wall length = 10m" && results() == ["10m", "2.4m", "24m²"]
  release()
  chip = chip_at(2)
  press(chip); at(chip .+ (30, 0)); release()
  @test row(2) == "Wall height = 3.0m" && results()[3] == "30m²"
  K.undo!(e.buf); K.undo!(e.buf); frames()
  @test row(1) == "Wall length = 12m" && row(2) == "Wall height = 2.4m"
  @test e.buf.lines[end-1] == "The end."
end

@testset "a long drag speeds up" begin
  # Near where the drag starts, a step is 5px. Further away, the steps come faster and faster.
  @test K.scrub_steps(5) == 1 && K.scrub_steps(20) == 4 && K.scrub_steps(-20) == -4 && K.scrub_steps(0) == 0
  @test K.scrub_steps(1000) > 10 * K.scrub_steps(100) > 0
  @test K.scrub_steps(-1000) == -K.scrub_steps(1000)
  first_sum = sum_at(1)
  press(first_sum); at(first_sum .+ (400, 0))
  @test occursin("!`l = $(16 + K.scrub_steps(400))m`", text()) && K.scrub_steps(400) > 200
  release(); K.undo!(e.buf); frames()
  @test occursin("!`l = 16m`", text())
end

close(w)
