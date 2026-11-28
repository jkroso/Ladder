# Tests for the names that a code block offers while you type. See "the names
# a code block offers" in main.jl. Run them with `julia -O0 --project=. test/names_test.jl`.
# They type and press keys in a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "walls.md")
const TEXT = """
# Walls

```julia
wall_length = 4.2
wall_height = 2.4
width = 0.09
# the area of one side
area = wall_length * wall_height

```

Some words about a wall.

```python
wall_colour = "white"

```

```
plain text with a wall

```
"""
write(page, TEXT)

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const b = e.buf
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()

"Put the text back as it was, with the caret at `line` and `col`"
fresh!(line, col=0) = begin
  b.lines = String.(split(TEXT, '\n'))
  b.version = (K.stamp[] += 1)   # a new version, as an edit gives
  b.reading = false
  K.focus(e)   # as a click on the page does
  caret!(line, col)
end
caret!(line, col=0) = (b.caret = b.anchor = (line, col); frames())
key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
"The names in the list that shows, or nothing when no list shows"
names() = (found = K.suggestion(e); found === nothing ? nothing : found[3])
"True when the window draws the list"
drawn() = !isempty(K.suggestbox(e))
"What the list says the name is, or nothing when the list doesn't have the name"
said(name) = begin
  found = K.suggestion(e)
  found === nothing && return nothing
  k = findfirst(==(name), found[3])
  k === nothing ? nothing : K.name_notes(e, found[1], found[3])[k]
end

const shots = get(ENV, "NAMES_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "a list of the page's names shows as a name is typed" begin
  fresh!(9)
  typed("w")
  @test names() === nothing   # one character is too few
  typed("a")
  @test names()[1:2] == ["wall_height", "wall_length"]   # the nearest first
  @test drawn()
  shot("list")
  typed("ll_l")
  @test names() == ["wall_length"]
  # A name fits when one of its words starts with what's typed
  fresh!(9)
  typed("he")
  @test "wall_height" in names()
  @test all(startswith(n, "he") for n in names() if n != "wall_height")   # the names that start with it come first
end

@testset "Tab and Return type the rest of the name" begin
  fresh!(9)
  typed("wi")
  @test first(names()) == "width"
  key(Keys.tab)
  @test b.lines[9] == "width" && b.caret == (9, 5)
  @test names() === nothing
  fresh!(9)
  typed("x = wa")
  key(Keys.down)
  key(Keys.enter)
  @test b.lines[9] == "x = wall_length"
  @test length(b.lines) == length(split(TEXT, '\n'))   # Return didn't make a new line
  # ⌘Z takes the name away again
  key(Keys.z, Keys.cmd)
  @test b.lines[9] == "x = wa"
end

@testset "esc hides the list, and then the keys are the text's again" begin
  fresh!(9)
  typed("wa")
  key(Keys.escape)
  @test names() === nothing && !b.reading
  # The list stays hidden while the same name is typed
  typed("l")
  @test names() === nothing
  key(Keys.enter)
  @test length(b.lines) == length(split(TEXT, '\n')) + 1
  @test b.lines[9] == "wal"
  # A new name in the same place has its list
  fresh!(9)
  typed("wa")
  @test names()[1:2] == ["wall_height", "wall_length"]
end

@testset "no list shows where a name isn't being typed" begin
  n = length(split(TEXT, '\n'))
  shown = String[]
  for text in ("# wa", "\"wa", "area.wa", "wall_length", "length", "@show")
    fresh!(9)
    typed(text)
    names() === nothing || push!(shown, text)
  end
  @test shown == []
  # 2wa is two times wa, so the name starts after the digit
  fresh!(9)
  typed("2wa")
  @test names()[1:2] == ["wall_height", "wall_length"]
  # A word of the language, and the middle of a word
  fresh!(9)
  typed("end")
  @test names() === nothing
  fresh!(9)
  typed("wal")
  caret!(9, 2)
  typed("x")
  @test names() === nothing
  # The caret moves through code with no list in its way
  fresh!(9)
  typed("wa")
  caret!(8, 2)
  caret!(9, 2)
  frames()
  @test names() === nothing
  # Text, and a block with no language
  for line in (12, 20)
    fresh!(line, line == 12 ? 0 : 0)
    typed("wa")
    @test names() === nothing
  end
  @test length(b.lines) == n
end

@testset "each language has its own names" begin
  fresh!(16)
  typed("wa")
  @test names() == ["wall_colour"]
  fresh!(9)
  typed("wall_c")
  @test names() === nothing
end

@testset "Julia code gets Julia's own names, before any code has run" begin
  @test K.window_modules(e).sandbox === nothing
  fresh!(9)
  typed("len")
  @test first(names()) == "length"
  fresh!(9)
  typed("x = printl")
  @test names() == ["println"]
  key(Keys.tab)
  @test b.lines[9] == "x = println"
  fresh!(9)
  typed("@sh")
  @test first(names()) == "@show"
  key(Keys.enter)
  @test b.lines[9] == "@show"
  # The page's own names come first
  fresh!(9)
  typed("wi")
  @test first(names()) == "width" && "widen" in names()
  @test length(names()) <= K.NAMES_SHOWN
  @test K.window_modules(e).sandbox === nothing   # the list doesn't start the page's module
  # Code in another language doesn't get them
  fresh!(16)
  typed("len")
  @test names() === nothing
end

const MORE = """
struct Wall
  long::Float64
end
mutable struct Room
  walls::Vector{Wall}
  door::Wall
end
abstract type Shape end
gate = Wall(0.9)
hinge = Hinge(2)
planks = Vector{Wall}()
paint(area::Float64, coats=2) = area * coats
function trim(room::Room, edge)
  total = 0.0
  for plank in room.walls
    total += plank.long

  end

end
label = "north"  # which way it faces
count = 12
shade = tint(depth=2)
"""

@testset "the list has only the names that code at the caret can use" begin
  # Line 9 is empty. The lines of MORE go in before it, so the empty line is line 32.
  fresh!(9)
  K.edit!(b, (9, 0), (9, 0), chopprefix(MORE, "\n"))
  ask(text, line=32) = begin
    K.edit!(b, (line, 0), (line, length(b.lines[line])), "")
    caret!(line)
    typed(text)
  end
  has(name) = something(names(), String[]) |> list -> name in list
  # The fields of a struct aren't names that code can use
  ask("wal")
  @test has("wall_length") && !has("walls")
  ask("doo")
  @test !has("door")
  ask("lon")
  @test !has("long")
  # ... and nor is the name that a call gives a value
  ask("dep")
  @test !has("depth")
  # What a function takes, and the names that it makes, are in reach only inside it
  for (text, name) in (("roo", "room"), ("edg", "edge"), ("tot", "total"), ("coa", "coats"), ("plan", "plank"))
    ask(text)
    @test (name, has(name)) == (name, false)
  end
  ask("roo", 27)   # in the function, after its loop
  @test has("room") && said("room") == "Room"
  ask("edg", 27)
  @test said("edge") == ""
  ask("tot", 27)
  @test said("total") == "Float64"
  ask("plan", 27)
  @test has("planks") && !has("plank")   # the loop's name is in reach only in the loop
  ask("plan", 25)   # in the loop
  @test has("plank") && has("planks")
  ask("wall_l", 25)
  @test has("wall_length")   # a name of the whole page is in reach in a function too
  K.edit!(b, (25, 0), (25, length(b.lines[25])), "")
end

@testset "code that's half typed is read with no fault" begin
  # The reader keeps the names that it found when it meets a fault, so this reads with no such net
  read!(text) = begin
    lines = String.(split(text, '\n'))
    r = K.Scan(lines, 1, cumsum([1; [ncodeunits(l) + 1 for l in lines[1:end-1]]]), K.Bound[])
    K.scan!(r, K.Syntax.parseall(K.Syntax.SyntaxNode, text, ignore_errors=true), nothing, nothing)
    r.found
  end
  more = MORE * "for (i, w) in enumerate(walls), k in 1:2\n  x -> [w.long for w in walls if w.long > i]\nend\n" *
         "try\n  let half = long / 2\n    map(walls) do w\n      w\n    end\n  end\ncatch err\nend\nusing Dates: now\n"
  faults = count(1:ncodeunits(more)) do cut
    isvalid(more, cut) || return false
    try (read!(more[1:cut]); false) catch; true end
  end
  @test faults == 0
  # A column counts characters, where the parser counts bytes
  @test only(read!("αβγ = 1; wide = 2.0")[2:2]).at == (1, 9)
end

@testset "each name of Julia code says what it is, before any code has run" begin
  ask(text) = begin
    K.edit!(b, (32, 0), (32, length(b.lines[32])), "")
    caret!(32)
    typed(text)
  end
  ask("Wal")
  @test said("Wall") == "struct"
  @test drawn()
  shot("notes")
  for (text, name, words) in (("Roo", "Room", "mutable struct"), ("Sha", "Shape", "abstract type"),
                              ("pai", "paint", "function"), ("tri", "trim", "function"),
                              # A plain value has a type that the code shows. Nothing is known about any other value.
                              ("wall_l", "wall_length", "Float64"), ("lab", "label", "String"), ("cou", "count", string(Int)),
                              ("are", "area", ""),
                              # A call of a type makes a value of that type. Nothing is known about a call of any other name.
                              ("gat", "gate", "Wall"), ("plan", "planks", "Vector{Wall}"), ("hin", "hinge", ""), ("sha", "shade", ""),
                              # Julia's own names
                              ("len", "length", "function"), ("@sh", "@show", "macro"), ("AbstractF", "AbstractFloat", "abstract type"),
                              ("Int6", "Int64", "primitive type"), ("ARG", "ARGS", "Vector{String}"), ("Bas", "Base", "module"))
    ask(text)
    @test (name, said(name)) == (name, words)
  end
  @test K.window_modules(e).sandbox === nothing   # the words don't start the page's module
  # Code in another language has no words
  fresh!(16)
  typed("wa")
  @test K.name_notes(e, 16, names()) == [""]
  @test drawn()
end

@testset "Julia code gets the names that the page's code made when it ran" begin
  fresh!(9)
  typed("total_paint = 5")
  key(Keys.enter, Keys.cmd)   # runs the line
  @test !only(K.outcomes(e)).failed
  fresh!(9)   # the line is gone from the text
  typed("tot")
  @test first(names()) == "total_paint"
  # ... and the names that a live block has
  fresh!(9)
  typed("Sli")
  @test names() !== nothing && "Slider" in names()
  @test said("Slider") == "mutable struct"
  # A name that the code made says the type of its value
  fresh!(9)
  typed("tot")
  @test said("total_paint") == string(Int)
  shot("made")
end

@testset "⌘Return still runs the code while the list shows" begin
  fresh!(9)
  typed("wall_length * wa")
  @test names() !== nothing
  key(Keys.enter, Keys.cmd)
  @test b.lines[9] == "wall_length * wa"
  @test length(K.outcomes(e)) == 1
end
