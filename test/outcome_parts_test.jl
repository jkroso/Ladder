# Tests for the parts of a value that the open box of an outcome lists. See
# "code that runs where it is" in main.jl. Run them with
# `julia -O0 --project=. test/outcome_parts_test.jl`. They press keys and click
# in a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse onscroll
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const CODE = """
struct Wall
  long::Float64
  name::String
end

struct Room
  walls::Vector{Wall}
  door::Wall
end

Wall(4.2, "north")
Room([Wall(4.2, "north"), Wall(3.0, "east")], Wall(0.9, "door"))
Checkbox()
Row(Box(Box()), Box())
[1, 2, 3]
[Wall(1.0, "a")]
(many=collect(1:150), wall=Wall(1.0, "a"))
(println("one"); println("two"); Wall(2.0, "b"))
"""
const file = joinpath(dir, "walls.jl")
write(file, CODE)
const page = joinpath(dir, "walls.md")
write(page, "# Walls\n\n```julia\n" * CODE * "```\n")

const shots = get(ENV, "PARTS_SHOTS", "")

"Open `path` in a window that isn't on the screen, and run every piece of its code"
opened(path) = begin
  e = K.build_editor(path)
  w = Window(e, size=(1000px, 800px))
  frames(n=2) = foreach(_ -> frame(w), 1:n)
  frames()
  K.focus(e)
  from, to = K.julia_code(e.buf, 5)
  for r in K.statements(e.buf.lines[from:to])
    K.outcome!(e, r .+ (from - 1))
  end
  frames()
  (; e, w, frames, from)
end

at(v, (x, y)) = (v.w.mouse = typeof(v.w.mouse)(px(x), px(y)); onmouse(v.w, MouseMove(Vec2{px}(px(x), px(y)), v.w)); v.frames(1))
click(v, place) = (at(v, place); v.w.keys |= Keys.mouse_left; onkey(v.w, KeyPress{Keys.mouse_left}(0, v.w)); v.w.keys ⊻= Keys.mouse_left; v.frames())
middle(r) = (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2)
"The outcome of the code on line `line` of the code, which starts at line 1"
outcome(v, line) = (k = findfirst(o -> o.last == line + v.from - 1, K.outcomes(v.e)); K.outcomes(v.e)[k])
"The lines that the open box of `o` shows now, as their names"
names(o) = [m.name for m in K.unfolded(o.body.members)]
"The line of the open box of `o` that has the name `name`"
line(o, name) = (rows = K.unfolded(o.body.members); rows[findfirst(m -> m.name == name, rows)])
"Show only the box of `o`, so that no other box is over it"
only!(v, o) = (foreach(p -> p.open = p === o, K.outcomes(v.e)); v.frames())
shot(v, name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), v.w)

@testset "the parts that a value has" begin
  parts(v) = [name => K.brief_text(value) for (name, value) in K.members(v)]
  @test isempty(K.members(1.5)) && isempty(K.members("words")) && isempty(K.members(:name)) && isempty(K.members(nothing))
  @test isempty(K.members(1:3)) && isempty(K.members(sin)) && isempty(K.members(Base)) && isempty(K.members(Int))
  @test parts((a=1, b="two")) == ["a" => "1", "b" => "\"two\""]
  @test parts([1.5, 2.5]) == ["1" => "1.5", "2" => "2.5"]
  @test parts((1, :a)) == ["1" => "1", "2" => ":a"]
  @test parts(Dict("k" => 1)) == ["\"k\"" => "1"]
  # A struct that has a way of its own to show is one value
  @test isempty(K.members(1 => 2)) && isempty(K.members(r"a+")) && isempty(K.members(1 // 2))
  # A field with no value yet
  @test parts(Vector{Any}(undef, 1)) == ["1" => "#undef"]
  @test parts(Ref{Any}()) == ["x" => "#undef"]
  # A long list has its first hundred, and says how many more there are
  long = K.members(collect(1:150))
  @test length(long) == K.MEMBERS + 1 && K.brief_text(long[end].second) == "50 more"
  # A list shows its parts only when one of them has parts
  @test !K.has_members([1, 2, 3]) && !K.has_members((a=1, b="two")) && !K.has_members(Dict("k" => 1))
  @test K.has_members([(a=1,)]) && K.has_members(Ref(1))
  @test length(K.brief_text("a"^500)) == K.MEMBER_COLS
  @test K.brief_text([1 2; 3 4]) == "[1 2; 3 4]"
end

@testset "in a file of code, the box of a struct opens to its fields" begin
  v = opened(file)
  o = outcome(v, 11)
  @test o.brief == "Wall(4.2, \"north\")" && !o.failed
  @test o.whole !== nothing && o.more && !o.open   # what Julia writes says enough, so the box starts closed
  click(v, middle(rect(o)))
  @test o.open && rect(o.body) !== nothing
  @test names(o) == ["long", "name"]
  @test [m.text for m in o.body.members] == ["4.2", "\"north\""]
  @test all(m -> rect(m) !== nothing && !m.more, o.body.members)
  # The lines are under the box, one under the other
  @test K.num(rect(o).top) < K.num(rect(line(o, "long")).top) < K.num(rect(line(o, "name")).top)
  shot(v, "fields")
  click(v, middle(rect(o)))
  @test !o.open
  close(v.w)
end

@testset "an open box and the rest under it are one piece" begin
  v = opened(file)
  o = outcome(v, 11)
  closed = rect(o)
  cell = K.measure(K.outcome_face(o.size), "0")
  @test K.num(closed.width) ≈ K.num(K.outcome_wide(o, cell)) atol=0.5
  click(v, middle(rect(o)))
  r, b = rect(o), rect(o.body)
  # No space between them: the rest starts on the bottom line of the box
  @test K.num(b.top) ≈ K.num(r.top) + K.num(r.height) - 1 atol=0.5
  # They start at the same place and are as wide as each other
  @test K.num(b.left) ≈ K.num(r.left) atol=0.5
  @test K.num(b.width) ≈ K.num(r.width) atol=0.5
  @test K.num(r.width) >= K.num(closed.width) - 0.5
  @test o.body.corners == K.radius(0px, 0px, K.OUTCOME_ROUND, K.OUTCOME_ROUND)
  # The fields start under the arrow of the box, with no empty room on their left
  m = line(o, "long")
  @test !m.room
  @test 6 <= K.num(rect(m).left) - K.num(r.left) <= 9
  shot(v, "joined")
  click(v, middle(rect(o)))
  @test K.num(rect(o).width) ≈ K.num(closed.width) atol=0.5   # closed, the box is as wide as what it shows
  # A list that has a line with an arrow gives each of its lines room for one
  o = outcome(v, 12)
  only!(v, o)
  @test all(m -> m.room, o.body.members)
  # This box is near the right edge of the window, so the rest starts further left, and the box stands on it
  r, b = rect(o), rect(o.body)
  @test K.num(b.left) < K.num(r.left)
  @test K.num(b.top) ≈ K.num(r.top) + K.num(r.height) - 1 atol=0.5
  @test K.num(b.left) + K.num(b.width) <= 1000
  @test o.body.corners.tl == K.OUTCOME_ROUND
  # The box ends where the rest ends, with no small step between their right edges
  @test K.num(r.left) + K.num(r.width) ≈ K.num(b.left) + K.num(b.width) atol=0.5
  @test o.body.corners.tr == 0px
  shot(v, "tab")
  # A box of text is one piece with its lines too
  o = outcome(v, 15)
  only!(v, o)
  r, b = rect(o), rect(o.body)
  @test K.num(b.top) ≈ K.num(r.top) + K.num(r.height) - 1 atol=0.5
  @test K.num(b.left) ≈ K.num(r.left) atol=0.5
  @test K.num(b.width) ≈ K.num(r.width) atol=0.5
  shot(v, "text")
  # And so is the box of a function, with its documentation and its methods
  K.outcome!(v.e, (v.from + 16):(v.from + 16), "length")
  o = outcome(v, 17)
  only!(v, o)
  r, b = rect(o), rect(o.body)
  @test K.num(b.top) ≈ K.num(r.top) + K.num(r.height) - 1 atol=0.5
  @test K.num(b.left) < K.num(r.left) && K.num(b.left) + K.num(b.width) <= 1000
  # This box ends far from the right edge of the rest, so it's as wide as what it shows, and the corner of the rest there is round
  @test K.num(r.width) ≈ K.num(K.outcome_wide(o, cell)) atol=0.5
  @test o.body.corners.tr == K.OUTCOME_ROUND
  shot(v, "function")
  close(v.w)
end

@testset "a line whose value has parts opens to show them" begin
  v = opened(file)
  o = outcome(v, 12)
  only!(v, o)
  @test names(o) == ["walls", "door"] && all(m -> m.more, o.body.members)
  @test line(o, "door").text == "Wall(0.9, \"door\")"
  click(v, middle(rect(line(o, "walls"))))
  @test names(o) == ["walls", "1", "2", "door"]
  @test line(o, "1").text == "Wall(4.2, \"north\")" && line(o, "1").depth == 1
  # A part's own parts start further in
  @test K.num(rect(line(o, "1")).top) > K.num(rect(line(o, "walls")).top)
  click(v, middle(rect(line(o, "2"))))
  @test names(o) == ["walls", "1", "2", "long", "name", "door"]
  @test line(o, "long").text == "3.0" && line(o, "long").depth == 2
  shot(v, "nested")
  # A second click hides them, and the lines under them
  click(v, middle(rect(line(o, "walls"))))
  @test names(o) == ["walls", "door"]
  # A click on a line that has no parts does nothing
  click(v, middle(rect(line(o, "door"))))
  click(v, middle(rect(line(o, "long"))))
  @test names(o) == ["walls", "door", "long", "name"]
  close(v.w)
end

@testset "in a file of code, a UI node lists its fields and its children" begin
  v = opened(file)
  o = outcome(v, 13)
  @test o.brief == "Checkbox" && !o.failed
  @test o.node === nothing && o.whole !== nothing && o.open   # its name alone says little, so the box starts open
  only!(v, o)
  @test "checked" in names(o)
  # The fields that join the node to the tree aren't the node's own
  @test isempty(intersect(names(o), ["parent", "firstchild", "nextsibling", "prevsibling", "memo", "stale", "from"]))
  shot(v, "node")
  o = outcome(v, 14)
  only!(v, o)
  @test o.brief == "Row with 2 children"
  @test names(o)[end-1:end] == ["1", "2"] && "child_gap" in names(o)
  @test line(o, "1").text == "Box with 1 child" && line(o, "1").more
  @test line(o, "2").text == "Box" && line(o, "2").more   # a node with no children still has its fields
  shot(v, "children")
  close(v.w)
end

@testset "a list shows its items when one of them has parts" begin
  v = opened(file)
  o = outcome(v, 15)
  @test o.whole === nothing && o.brief == "3-element Vector{Int64}:" && o.rest == " 1\n 2\n 3"
  o = outcome(v, 16)
  @test o.whole !== nothing
  only!(v, o)
  @test names(o) == ["1"] && line(o, "1").text == "Wall(1.0, \"a\")"
  close(v.w)
end

@testset "a long list shows part of itself, and the wheel moves through the rest" begin
  v = opened(file)
  o = outcome(v, 17)
  only!(v, o)
  @test names(o) == ["many", "wall"]
  click(v, middle(rect(line(o, "many"))))
  @test length(names(o)) == K.MEMBERS + 3 && names(o)[end-1] == "…"
  @test line(o, "…").text == "50 more"
  r = rect(o.body)
  @test K.num(r.height) <= K.num(K.MEMBERS_H) + 24
  @test K.num(r.top) + K.num(r.height) <= 800
  at(v, middle(r))
  was = o.body.scroll.offset
  onscroll(v.w, Vec2{px}(px(0), px(-5)))
  v.frames()
  @test o.body.scroll.offset > was
  shot(v, "long")
  close(v.w)
end

@testset "text that the code printed is over the list, and what Julia writes for the value isn't" begin
  v = opened(file)
  o = outcome(v, 18)
  @test o.brief == "one" && o.printed == 2 && o.whole !== nothing
  only!(v, o)
  @test K.printed_rest(o) == ["two"]
  @test names(o) == ["long", "name"]
  # A box that shows all of what Julia writes has no text over its list
  @test isempty(K.printed_rest(outcome(v, 11)))
  # And one that has no room for it leaves it out too
  o = outcome(v, 12)
  only!(v, o)
  @test o.shown != o.brief && isempty(K.printed_rest(o))
  close(v.w)
end

@testset "on a page, a struct lists its fields and a UI node shows as the node" begin
  v = opened(page)
  o = outcome(v, 11)
  @test o.whole !== nothing && !o.open
  click(v, middle(rect(o)))
  @test names(o) == ["long", "name"]
  o = outcome(v, 13)
  @test o.brief == "Checkbox" && o.node !== nothing && o.whole === nothing && o.open
  close(v.w)
end
