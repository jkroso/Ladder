# Tests for the box that lists what a function takes. See "what a function
# takes" in main.jl. Run them with `julia -O0 --project=. test/call_test.jl`.
# They type and press keys in a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "walls.md")
const TEXT = """
# Walls

```julia
"A wall of a room"
struct Wall
  length::Float64
  height::Float64
end

area(w::Wall) = w.length * w.height
area(l, h=2.4; coats=1) = l * h * coats

```

```python

```
"""
const CODE = 12     # an empty line of the Julia code
const PYTHON = 16   # an empty line of the Python code
write(page, TEXT)

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const b = e.buf
const (; frames, typed, key, shot) = drive(w)
frames()

"Put the text back as it was, with the caret at `line` and `col`"
fresh!(line=CODE, col=0) = begin
  b.lines = String.(split(TEXT, '\n'))
  b.version = (K.stamp[] += 1)   # a new version, as an edit gives
  b.reading = false
  K.focus(e)   # as a click on the page does
  b.caret = b.anchor = (line, col)
  frames()
end
"The lines of the box that shows, as text, or nothing when no box shows"
lines() = begin
  found = K.call_shown(e)
  found === nothing ? nothing : [join(first.(K.call_pieces(found.name, line, found.call))) for line in found.lines]
end
"The part of each line of the box that the caret's value is for, or \"\" for a line with no such part"
lit() = begin
  found = K.call_shown(e)
  map(found.lines) do line
    at = filter(last, K.call_pieces(found.name, line, found.call))
    isempty(at) ? "" : first(only(at))
  end
end
"True when the window draws the box"
drawn() = !isempty(K.callbox(e))

@testset "the ( of a call shows what one of Julia's functions takes" begin
  fresh!()
  typed("length")
  @test lines() === nothing
  typed("(")
  found = K.call_shown(e)
  @test found.name == "length" && length(found.lines) == K.CALL_SHOWN && found.more > 0
  @test all(startswith("length("), lines())
  @test drawn()
  shot("length")
  # A function that the page's code hasn't made yet has no box
  fresh!()
  typed("area(")
  @test lines() === nothing && !drawn()
end

# The page's code runs, as ⌘Return runs it
K.run_code(e, join(b.lines[4:11], "\n"))

@testset "a function of the page shows its methods, and the value that the caret is at" begin
  fresh!()
  typed("area(")
  # The method with a value that can be left out is one line
  @test lines() == ["area(w::Wall)", "area(l, [h]; coats)"]
  @test lit() == ["w::Wall", "l"]
  shot("area")
  # The box goes when a value is started, and the call is still open
  typed("1")
  @test lines() === nothing && !drawn() && K.calling(e) !== nothing
  # ... and comes back for the next value, with only the method that takes a second one
  typed(",")
  @test lines() == ["area(l, [h]; coats)"] && lit() == ["[h]"]
  typed(" ")
  @test lines() == ["area(l, [h]; coats)"] && drawn()
  shot("second")
  typed("2")
  @test lines() === nothing
  # After a ; every value has a name, so no value with no name is marked
  typed("; ")
  @test lines() == ["area(l, [h]; coats)"] && lit() == [""]
  typed("coats=")
  @test lines() === nothing
  # ⌫ back to a value with nothing in it shows the box again
  fresh!()
  typed("area(1")
  key(Keys.backspace)
  @test length(lines()) == 2
  # A name that no method takes leaves every method in the box
  fresh!()
  typed("area(colour=1, ")
  @test length(lines()) == 2
end

@testset "a type shows what makes one" begin
  fresh!()
  typed("Wall(1, ")
  @test "Wall(length::Float64, height::Float64)" in lines()
  @test all(==("height"), first.(split.(lit(), "::")))
end

@testset "a call in a call has a box of its own" begin
  fresh!()
  typed("area(Wall(")
  @test all(startswith("Wall("), lines())
  # The inner call is some of the outer call's value, so the outer call has no box until its next value
  typed("1, 2)")
  @test lines() === nothing && K.calling(e) !== nothing
  typed(", ")
  @test lines() == ["area(l, [h]; coats)"] && lit() == ["[h]"]
  # Brackets that group, and the brackets of a list, are some of a value too
  typed("[1, (2")
  @test lines() === nothing
  typed(")])")
  @test lines() === nothing && K.calling(e) === nothing
end

@testset "the box closes when the caret leaves the call, and esc hides it" begin
  fresh!()
  typed("area(1")
  key(Keys.left)
  @test lines() !== nothing   # between the bracket and the value
  key(Keys.left)
  @test lines() === nothing && K.calling(e) === nothing
  key(Keys.right)
  @test lines() === nothing   # the caret alone doesn't open a box
  fresh!()
  typed("area(")
  key(Keys.escape)
  @test lines() === nothing && !b.reading   # esc hid the box and left the caret
  typed("1, ")
  @test lines() === nothing
  # A call typed in it has a box of its own, which closes with that call
  typed("Wall(")
  @test all(startswith("Wall("), lines())
  typed("1, 2)")
  @test lines() === nothing
  # The list of names shows while a value is typed, so the box and the list never show together
  fresh!()
  typed("area(Wa")
  @test K.suggestion(e) !== nothing && lines() === nothing
  shot("with names")
  key(Keys.enter)
  @test b.lines[CODE] == "area(Wall)"
  typed("(")
  @test all(startswith("Wall("), lines())
end

@testset "a , or a ; typed in a call that the caret came back to opens the box" begin
  fresh!()
  typed("walkdir(\".\")")
  @test lines() === nothing && K.calling(e) === nothing
  key(Keys.left)
  typed(";")
  @test lines() == ["walkdir([path]; topdown, follow_symlinks, onerror)"] && drawn()
  typed(" ")
  @test lines() == ["walkdir([path]; topdown, follow_symlinks, onerror)"]
  shot("came back")
  typed("topdown=false")
  @test lines() === nothing
  typed(", ")
  @test lines() == ["walkdir([path]; topdown, follow_symlinks, onerror)"]
  fresh!()
  typed("area(1)")
  key(Keys.left)
  typed(",")
  @test lines() == ["area(l, [h]; coats)"] && lit() == ["[h]"]
  # A , that isn't in a call opens nothing
  fresh!()
  typed("x = [1, ")
  @test lines() === nothing && K.calling(e) === nothing
end

"The names in the list of names, or nothing when no list shows"
names() = (found = K.suggestion(e); found === nothing ? nothing : found[3])

@testset "the list of names offers the names that the function gives its values" begin
  # After the ; of a call they're the only names, from the first letter
  fresh!()
  typed("walkdir(\".\"; ")
  @test names() === nothing
  typed("t")
  @test names() == ["topdown="]
  typed("op")
  @test names() == ["topdown="] && lines() === nothing
  shot("names of values")
  key(Keys.enter)
  @test b.lines[CODE] == "walkdir(\".\"; topdown=)" && b.caret == (CODE, 21)
  # A name that the call gives already isn't offered again, and one of a name's words is enough
  typed("true, ")
  typed("o")
  @test names() == ["onerror="]
  fresh!()
  typed("walkdir(\".\"; s")
  @test names() == ["follow_symlinks="]
  # A name that fits none of them has no list, and a whole name has none
  fresh!()
  typed("walkdir(\".\"; wa")
  @test names() === nothing
  fresh!()
  typed("walkdir(\".\"; topdown")
  @test names() === nothing
  # Before the ; they come first, among the other names, from the second letter
  fresh!()
  typed("area(1, c")
  @test names() === nothing
  typed("o")
  @test first(names()) == "coats=" && length(names()) > 1
  # A name that has its = already gets no second one
  fresh!()
  typed("area(1; =2")
  foreach(_ -> key(Keys.left), 1:2)
  typed("c")
  @test names() == ["coats"]
  # In the middle of a value, and outside a call, a name of a value isn't offered
  fresh!()
  typed("area(1, 2 + co")
  @test !("coats=" in something(names(), String[]))
  fresh!()
  typed("co")
  @test !("coats=" in something(names(), String[]))
end

"What the list of names says at the right of each name"
notes() = K.name_notes(e, b.caret[1], names())

@testset "a name that a function gives a value says the type of the value" begin
  K.run_code(e, """
    paint(a; coats::Int=2, colour="white", trim::Union{Nothing,Float64}=nothing, sheen=nothing, finish, primer=a > 1) = 1
    Base.@kwdef struct Door; wide::Float64 = 0.9; name::String = string(1); end
    """)
  # A value with no type has the type of the plain value that it has when a call leaves it out
  fresh!()
  typed("walkdir(\".\"; t")
  @test names() == ["topdown="] && notes() == ["Bool = true"]
  @test drawn() == false && !isempty(K.suggestbox(e))
  shot("type of a value")
  fresh!()
  typed("walkdir(\".\"; o")
  @test notes() == ["= throw"]
  # The type that the method says, and the value
  said(text) = (fresh!(); typed(text); only(notes()))
  @test said("paint(1; coa") == "Int64 = 2"
  @test said("paint(1; col") == "String = \"white\""
  @test said("paint(1; t") == "Union{Nothing, Float64}"   # too long with its value
  @test said("paint(1; s") == "= nothing"
  # A value that a call must give, and one that the method works out
  @test said("paint(1; f") == "Any"
  @test said("paint(1; p") == "Any"
  # A name of a type's field has the type of the field
  @test said("Door(; w") == "Float64 = 0.9"
  @test said("Door(; n") == "String"
  # Before the ; the other names keep what they say
  fresh!()
  typed("paint(1, co")
  @test first(names()) == "coats=" && first(notes()) == "Int64 = 2"
  @test "function" in notes()
end

@testset "a call that runs over lines keeps its box" begin
  fresh!()
  typed("area(1,")
  key(Keys.enter)
  @test b.caret[1] == CODE + 1
  @test lines() == ["area(l, [h]; coats)"] && lit() == ["[h]"]
  # The box is under the line that the caret is on
  @test only(K.callbox(e)).padding.top > K.TOPBAR_H + K.PAGE_TOP + K.item(e, CODE + 1).top - e.scroll.offset
  shot("two lines")
  typed("2")
  @test lines() === nothing
end

@testset "no box shows where a call isn't being typed" begin
  shown = String[]
  for text in ("# area(", "\"area(", "(", "x = (", "@show(", "function area(", "nosuchname(", "Base(", "b.area(")
    fresh!()
    typed(text)
    lines() === nothing || push!(shown, text)
  end
  @test shown == []
  # Code in another language
  fresh!(PYTHON)
  typed("area(")
  @test lines() === nothing
  # ... and the names of a module, and a call for each of several values, are calls
  fresh!()
  typed("Base.length(")
  @test all(startswith("length("), lines())
  fresh!()
  typed("sqrt.(")
  @test all(startswith("sqrt("), lines())
  fresh!()
  typed("Vector{Int}(")
  @test all(startswith("Vector("), lines())
end

@testset "a type is written by its own name, and each method has one line" begin
  K.run_code(e, """
    module Far; struct Deep end; end
    module var"p/odd"; struct Odd end; end
    reach(d::Far.Deep, o::var"p/odd".Odd, xs::Base.Iterators.Flatten...) = 1
    """)
  fresh!()
  typed("reach(")
  @test lines() == ["reach(d::Deep, o::Odd, xs::Flatten...)"]
  # The values that a line has no room for are left out, with an … in their place
  cut(pieces, room) = join(first.(K.call_fit(pieces, text -> length(text) * 1px, room)))
  pieces = [("reach(", false), ("alpha", false), (", ", false), ("beta", false), ("; ", false), ("gamma", false), (")", false)]
  @test K.call_fit(pieces, text -> length(text) * 1px, 25px) == pieces
  @test cut(pieces, 24px) == "reach(alpha, beta; …)"
  @test cut(pieces, 20px) == "reach(alpha, …)"
  @test cut(pieces, 8px) == "reach(…)"
  # The value that the caret is at stays, with the value before it when that fits
  at(k) = [(text, j == k) for (j, (text, _)) in enumerate(pieces)]
  @test cut(at(4), 21px) == "reach(alpha, beta; …)"
  @test cut(at(4), 17px) == "reach(…, beta; …)"
  @test filter(last, K.call_fit(at(4), text -> length(text) * 1px, 17px)) == [("beta", true)]
  @test cut([("f(", false), ("; ", false), ("alpha", false), (", ", false), ("beta", false), (")", false)], 13px) == "f(; alpha, …)"
  # A method with many values has one row of the box
  K.run_code(e, "many(" * join(["value_number_$k::Union{Nothing,Float64}" for k in 1:20], ", ") * ") = 1")
  fresh!()
  typed("many(")
  @test length(lines()) == 1 && length(only(lines())) > 300
  shot("one line")
end

@testset "the box is under the caret's line, and over it when the window has no room under it" begin
  line_y(e) = K.TOPBAR_H + K.PAGE_TOP + K.item(e, CODE).top - e.scroll.offset
  fresh!()
  typed("area(")
  @test only(K.callbox(e)).padding.top > line_y(e)
  # A window that ends just under the line has no room for the box there
  e2 = K.build_editor(page)
  w2 = Window(e2, size=(1000px, 520px))
  foreach(_ -> frame(w2), 1:2)
  K.focus(e2)
  e2.buf.reading = false
  e2.buf.caret = e2.buf.anchor = (CODE, 0)
  foreach(c -> ontype(w2, Typed(c, w2)), "length(")
  foreach(_ -> frame(w2), 1:2)
  @test only(K.callbox(e2)).padding.top < line_y(e2)
  drive(w2).shot("no room")
  close(w2)
end

close(w)
