# Tests for the levels of a file of Julia code: what its code comes to shows as
# a value, as inferred code, as LLVM code or as assembly. See "what Julia code
# ran, down a level" in main.jl. test/julia_block_levels_test.jl has the
# levels of a `julia` code block of a page. Run them with
# `julia -O0 --project=. test/julia_levels_test.jl`. They write a file of code
# into a temporary folder, and press keys in a window that isn't on the
# screen. Set `LADDER_SHOTS` to a folder, and they save pictures there.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const sums = joinpath(dir, "sums.jl")
write(sums, """
# Sums for a wall
const RATE = 2

"The area of a wall"
area(w, h=2) = w * h + RATE

function total(xs)
  s = 0
  for x in xs
    s += area(x)
  end
  s
end

total([1, 2, 3])
missing_name + 1
""")

const e = K.build_editor(sums)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, click, shot) = drive(w, pressed=1)
K.focus(e)   # the keys go to the page
frames(3)
const b = e.buf

"Press ⌘E"
other() = (w.keys |= Keys.cmd; onkey(w, KeyPress{Keys.e}(0, w)); w.keys ⊻= Keys.cmd; frames())
"Run the expression on the lines `r`, as ⌘Return does, and give its box"
run(r) = (o = K.outcome!(e, r); frames(); o)
"The text of row `i` of what the box `o` shows a level down"
text(o, i) = join(first.(o.low.rows[i]))
"All the lines that the box `o` shows a level down, as one text"
all_text(o) = join((text(o, i) for i in eachindex(o.low.rows)), "\n")
"How many levels down the file's code shows what it comes to"
depth() = K.julia_part(e, 1).depth
"True when each line of the file shows as a line of code"
ascode() = all(it -> it.content isa K.Flow && it.first == it.last, e.layout)

@testset "a file of Julia code has four levels, of what its code comes to" begin
  @test b.view == :code && K.julia_file(b) && K.levels(e) == K.CODE_LEVELS && length(K.CODE_LEVELS) == 4
  # The file's code is the part that answers, wherever the caret is
  @test K.level_part(e) === K.julia_part(e, 1) && K.level_part(e) isa K.JuliaCode && K.level_part(e).n == 0
  @test K.level(e) == 4 && !K.low(e) && !isempty(K.mode_part(e))
  @test K.stop_tip(e, 4) == "The window shows the value of what you run. A click goes down a level  ⌘E"
  @test K.stop_tip(e, 3) == "Go down a level, to the inferred code of what you run  ⌘E"
  @test K.stop_tip(e, 2) == "Go down 2 levels, to the LLVM code of what you run"
  @test K.stop_tip(e, 1) == "Go down 3 levels, to the assembly of what you run"
  at(middle(rect(e.nodes[:mode]))); sleep(2K.OPENS_IN); frames()
  l = e.nodes[K.LEVELS_KEY]
  @test l.open
  @test length(l.stops) == 4
  at((400, 500)); frames()
end

run(2:2); run(4:5)
const defined = run(7:13)
const called = run(15:15)

@testset "at the highest level, a box shows the value" begin
  @test called.brief == "18" && called.low === nothing && !called.open
  @test defined.low === nothing && startswith(defined.brief, "total (generic function")
  @test defined.source isa K.Defined && length(defined.source.sigs) == 1 && called.source isa K.Thunk
end

@testset "a level down, a box shows the inferred code of what ran" begin
  other()
  @test depth() == 1 && K.level(e) == 3 && K.low(e)
  # The file's code shows as it's written, and the caret goes anywhere in it
  @test ascode()
  K.move!(e, (9, 4), false); frames()
  @test b.caret == (9, 4) && K.picked(b) === nothing && ascode()
  # The code that ran: its box shows the type that it gives, and under it each step with its type
  @test called.low isa K.Lowered && called.low.title == "::Int64" && called.shown == "::Int64" && called.more
  @test occursin("total", all_text(called)) && occursin("::Int64", all_text(called)) && occursin("return", all_text(called))
  # The definition of a function: the function's code, for the types that it was called with
  @test defined.low.title == "total(xs::Vector{Int64})::Int64" && defined.low.forms == 1
  @test text(defined, 1) == "Locals" && any(i -> occursin("s::Int64", text(defined, i)), 2:4)
  # An open box has the lines under it
  called.open = true; frames()
  @test called.body !== nothing && rect(called.body) !== nothing
  shot("julia-inferred.png")
  called.open = false; frames()
end

@testset "two levels down, a box shows LLVM code" begin
  K.level!(e, 2); frames()
  @test depth() == 2 && K.level(e) == 2
  @test called.low.title == "LLVM code" && defined.low.title == "total(xs::Vector{Int64})"
  rows = [text(defined, i) for i in eachindex(defined.low.rows)]
  @test any(startswith("define "), rows) && any(l -> occursin(r"^\s*ret ", l), rows) && last(rows) == "}"
  # The names of its values and its instructions have colours of their own
  kinds = Set(kind for row in defined.low.rows for (_, kind) in row)
  @test :keyword in kinds && :call in kinds && :ink in kinds
  defined.open = true; frames()
  # The lines are wider than the box, so they go on past its left. The inside corner where the two meet is drawn round.
  @test defined.steps[1] > 2K.OUTCOME_ROUND && defined.steps[2] >= 0px
  shot("julia-llvm.png")
  defined.open = false; frames()
end

@testset "three levels down, a box shows assembly with its machine code" begin
  K.level!(e, 1); frames()
  @test depth() == 3 && K.level(e) == 1
  @test occursin(r"^total\(xs::Vector\{Int64\}\)  [\d,]+ bytes$", defined.low.title) && occursin(r"^[\d,]+ bytes$", called.low.title)
  # An instruction has its place, its machine code, its name and what it works on
  steps = [r for r in defined.low.rows if length(r) == 4]
  @test length(steps) > 5 && all(r -> r[1][2] == :faint && r[3][2] == :keyword, steps)
  @test all(r -> occursin(r"^[0-9a-f]+ *$", r[1][1]) && occursin(r"^[0-9a-f ]+$", r[2][1]), steps)
  @test any(r -> startswith(r[3][1], "ret"), steps)
  # A long list of lines shows as much as the room under the box, and makes only the lines in sight
  defined.open = true; frames()
  @test defined.body.scroll.content_height > defined.body.scroll.viewport > 0px
  shot("julia-assembly.png")
  defined.open = false; frames()
end

@testset "code that runs while the file is down a level has its box open" begin
  K.level!(e, 3); frames()
  o = K.outcome!(e, 15:15, "area(2.5)"); frames()
  @test o.open && o.low.title == "::Float64"
  o.open = false; frames()
end

@testset "a function with more than one method, or called with more than one set of types" begin
  o = run(4:5)
  @test o.source isa K.Defined && length(o.source.sigs) == 2 && o.open
  # The definition ran again, so the function hasn't been called since: the code is for the types that it's written for
  @test o.low.forms == 2 && o.form == 1 && o.low.title == "area(w::Any, h::Any)::Any" && o.body.pick isa K.FormPick
  click(middle(rect(o.body.pick)))
  @test o.form == 2 && o.low.title == "area(w::Any)::Any"
  # Called with a whole number, it has that set of types to show in place of the types that it's written for
  K.outcome!(e, 15:15, "area(4, 5)"); frames()
  @test o.low.forms == 2 && o.form == 2
  click(middle(rect(o.body.pick)))
  @test o.form == 1 && o.low.title == "area(w::Int64, h::Int64)::Int64"
  o.open = false; frames()
end

@testset "code with no lower level shows what it shows at the highest level" begin
  # A constant can't be set in a function, and code that failed has no code to show
  constant = run(2:2)
  failed = run(16:16)
  @test constant.low === nothing && constant.shown == "2"
  @test failed.failed && failed.low === nothing && occursin("missing_name", failed.brief)
end

@testset "⌘E goes back up to the value" begin
  # The box of line 15 is the one that its code made when it last ran
  again = run(15:15)
  @test again.open && again.low.title == "::Int64"
  other()
  @test depth() == 0 && K.level(e) == 4
  @test again.low === nothing && again.shown == "18" && defined.low === nothing
  other()
  @test depth() == 1 && again.low.title == "::Int64"
  other()
  @test depth() == 0
end

close(w)
