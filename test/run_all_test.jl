# Tests for the command Run All, in main.jl: in a Julia file it runs every
# expression of the file from the top, and shows what each one comes to. One
# that fails doesn't stop the ones under it. Run them with
# `julia -O0 --project=. test/run_all_test.jl`. They draw a window that isn't
# on the screen.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const padding = join(("a$i = $i" for i in 1:40), "\n")
const source = joinpath(dir, "sums.jl")
write(source, """
# Sums for a wall
const RATE = 2

"The area of a wall"
area(w, h=2) = w * h + RATE

area(3)
$padding
missing_name + 1
area(4)
println("done")
""")
const page = joinpath(dir, "notes.md")
write(page, "# Notes\n\n```julia\n1 + 1\n```\n")

const e = K.build_editor(source)
const w = Window(e, size=(900px, 400px))
frames(n=2) = (haskey(e.nodes, :palette) && (e.nodes[:palette].moved = 0.0); foreach(_ -> Base.invokelatest(frame, w), 1:n))
frames(3)
K.focus(e)
press(k, held...) = (foreach(h -> w.keys |= h, held); onkey(w, KeyPress{k}(0, w)); foreach(h -> w.keys ⊻= h, held); frames())
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
names() = [String(c.name) for c in K.palette_commands(e)]
const b = e.buf
"The line that `text` starts on"
line(text) = findfirst(l -> startswith(l, text), b.lines)
"What the code that ends on line `i` came to"
outcome(i) = (found = filter(o -> o.last == i, K.outcomes(e)); length(found) == 1 ? only(found) : nothing)

@testset "it's a command of a Julia file, and not of a page" begin
  @test K.julia_file(b) && "run_all" in names()
  other = K.build_editor(page)
  @test !K.works_here(other, Val(:run_all))
end

@testset "it runs each expression and shows what each comes to, past one that fails" begin
  @test isempty(K.outcomes(e))
  caret = b.caret
  # The line that fails is out of sight at first
  r = K.line_rect(e, line("missing_name"))
  @test r.top > K.window_size(e)[2]
  K.run_all!(e)
  frames()
  # Every expression has its result, the comments and the blank lines none
  @test length(K.outcomes(e)) == length(K.statements(b.lines)) == 46
  @test outcome(line("area(3)")).brief == "8" && !outcome(line("area(3)")).failed
  @test outcome(line("a40")).brief == "40"
  bad = outcome(line("missing_name"))
  @test bad.failed && occursin("missing_name", bad.brief)
  # The ones under it still ran
  @test outcome(line("area(4)")).brief == "10" && !outcome(line("area(4)")).failed
  @test outcome(line("println")).brief == "done"
  # The caret stays where it was, and the window goes to the first that failed, which was out of sight
  @test b.caret == caret
  r = K.line_rect(e, line("missing_name"))
  @test r.top >= K.TOPBAR_H && r.top + r.height <= K.window_size(e)[2]
end

@testset "the palette runs it at once" begin
  empty!(K.outcomes(e))
  write(source, replace(read(source, String), "missing_name + 1" => "RATE + 1"))
  K.open!(e, source)
  frames()
  press(Keys.p, Keys.cmd, Keys.shft)
  typed("run all")
  @test first(K.palette_rows(e, K.palette(e))).value.name == :run_all
  press(Keys.enter)
  @test e.popup == :none
  @test length(K.outcomes(e)) == 46 && !any(o -> o.failed, K.outcomes(e))
  @test outcome(line("RATE + 1")).brief == "3"
end
