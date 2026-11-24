# Tests for the levels of a `julia` code block of a page: each block has a
# level of its own, and the slider in the top bar is about the block that the
# caret is in. See "what Julia code ran, down a level" and "the slider of the
# levels" in main.jl. Run them with
# `julia -O0 --project=. test/julia_block_levels_test.jl`. They write a page
# into a temporary folder, and press keys in a window that isn't on the
# screen. Set `LADDER_SHOTS` to a folder, and they save pictures there.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "sums.md")
write(page, """
# Sums

Some **bold** words.

```julia
area(w, h=2) = w * h
area(3)
```

Words between.

```julia
total = 1 + 2
```
""")
const WORDS, FIRST, CALL, SECOND = 3, 6, 7, 13   # a line of the page's text, and lines of its two blocks of code

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
e.plain && K.plain!(e, false)   # the page starts at its high level, whatever the settings say
K.focus(e)   # the keys go to the page
frames(3)
const b = e.buf
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1);
                w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
"Press ⌘E"
other() = (w.keys |= Keys.cmd; onkey(w, KeyPress{Keys.e}(0, w)); w.keys ⊻= Keys.cmd; frames())
"Put the caret at the start of line `i`"
caret(i) = (K.move!(e, (i, 0), false); frames())
"Run the expression on the lines `r`, as ⌘Return does, and give its box"
run(r) = (o = K.outcome!(e, r); frames(); o)
"The slider, or nothing while it's closed"
slider() = (l = get(e.nodes, K.LEVELS_KEY, nothing); l !== nothing && l.open ? l : nothing)
"Put the mouse over the picture in the top bar, and wait until the slider has opened all the way"
hover() = (at(middle(rect(e.nodes[:mode]))); sleep(2K.OPENS_IN); frames(); slider())
"Take the mouse off the slider"
leave() = (at((500, 600)); frames())
"The block of Julia code that line `i` is in"
part(i) = K.julia_part(e, i)

@testset "with the caret in the page's text, the page answers" begin
  caret(WORDS)
  @test K.level_part(e) isa K.Document && K.levels(e) == K.PAGE_LEVELS && K.level(e) == 2 && !K.low(e)
  @test length(hover().stops) == 2
  leave()
end

@testset "with the caret in a block of Julia code, that block answers" begin
  caret(FIRST)
  @test b.caret == (FIRST, 0)
  @test K.level_part(e) === part(FIRST) && part(FIRST) isa K.JuliaCode && part(FIRST).n == 1
  # Every line of the block is in it, with the lines that open and close it
  @test all(i -> part(i) === part(FIRST), FIRST-1:CALL+1) && part(SECOND).n == 2 && part(WORDS) === nothing
  @test K.levels(e) == K.CODE_LEVELS && K.level(e) == 4 && !K.low(e)
  l = hover()
  @test length(l.stops) == 4
  shot("julia-block-slider.png")
  leave()
  # The nearest part up the tree answers: a part in the block gives the block's levels, and a part in the document gives the page's
  inside = K.Stop(); setfield!(inside, :parent, part(FIRST))
  beside = K.Stop(); setfield!(beside, :parent, e.nodes[:document])
  @test K.levels(inside) == K.CODE_LEVELS && K.level(inside) == 4
  @test K.levels(beside) == K.PAGE_LEVELS && K.level(beside) == 2
end

const defined = run(FIRST:FIRST)
const called = run(CALL:CALL)
const summed = run(SECOND:SECOND)

@testset "at the highest level, a box shows the value" begin
  @test called.brief == "6" && called.low === nothing && summed.brief == "3" && summed.low === nothing
end

@testset "⌘E takes the block with the caret down a level, and no other part of the page" begin
  caret(CALL)
  other()
  @test part(CALL).depth == 1 && K.level(e) == 3 && K.low(e)
  @test !e.plain   # the page is still at its own high level
  @test called.low isa K.Lowered && called.low.title == "::Int64" && called.shown == "::Int64"
  @test defined.low.title == "area(w::Int64, h::Int64)::Int64" && defined.low.forms == 2
  # The other block has its own level
  @test part(SECOND).depth == 0 && summed.low === nothing && summed.shown == "3"
  called.open = true; frames()
  @test called.body !== nothing && rect(called.body) !== nothing
  shot("julia-block-inferred.png")
  called.open = false; frames()
end

@testset "the slider is about the block that the caret is in" begin
  caret(SECOND)
  @test K.level_part(e) === part(SECOND) && K.level(e) == 4 && !K.low(e)
  l = hover()
  click(middle(rect(l.stops[1])))
  @test part(SECOND).depth == 3 && K.level(e) == 1 && occursin(r"^[\d,]+ bytes$", summed.low.title)
  leave()
  # The first block is where it was
  @test part(FIRST).depth == 1 && called.low.title == "::Int64"
  caret(CALL)
  @test K.level(e) == 3
  # Code that runs while its block is down a level has its box open
  again = run(CALL:CALL)
  @test again.open && again.low.title == "::Int64"
  again.open = false; frames()
end

@testset "with the caret in the text again, ⌘E is the page's" begin
  caret(WORDS)
  @test K.levels(e) == K.PAGE_LEVELS && K.level(e) == 2
  other()
  @test e.plain && K.level(e) == 1
  # Each block keeps its level
  @test part(FIRST).depth == 1 && part(SECOND).depth == 3
  # The page shows its symbols, and a block of code still answers for itself
  caret(CALL)
  @test K.levels(e) == K.CODE_LEVELS && K.level(e) == 3
  K.level!(e, 4); frames()
  @test part(CALL).depth == 0 && e.plain
  caret(WORDS)
  other()
  @test !e.plain
end

close(w)
