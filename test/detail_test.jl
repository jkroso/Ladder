# Tests for what the box of a function and of a module shows when it's open.
# See "what a function and a module have to show" in main.jl. Run them with
# `julia -O0 --project=. test/detail_test.jl`. They press keys, click and type in a
# window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse onscroll Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
# A module in a folder that has a readme
write(joinpath(dir, "Readme.md"), "# Paint\n\nWorks out the paint for a wall.\n\n- one coat\n- two coats\n")
write(joinpath(dir, "paint.jl"), "const COATS = 2\nlitres(area) = COATS * area / 12\nstruct Tin; size::Float64 end\n")
const page = joinpath(dir, "notes.md")
write(page, """
# Notes

```julia
length
"Doubles a number"
double(n) = 2n
Base.Iterators
@use "./paint.jl"
x -> x + 1
abstract type Gauge end
"A bar that shows how much is done"
struct Meter <: Gauge
  done::Float64
  label::String
end
Meter
```

Some words.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const b = e.buf
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)

caret!(line, col=0) = (b.caret = b.anchor = (line, col); frames())
key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); w.keys ⊻= Keys.mouse_left; frames())
middle(r) = (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2)
outcome(line) = (k = findfirst(o -> o.last == line, K.outcomes(e)); k === nothing ? nothing : K.outcomes(e)[k])
"Run the code on `line`, and open the box of what it comes to. Returns what the open box shows."
opened!(line) = begin
  key(Keys.escape)
  K.focus(e)
  b.reading = false
  caret!(line)
  key(Keys.enter, Keys.cmd)
  o = outcome(line)
  click(middle(rect(o)))
  frames()
  o.body.detail
end
"Each Text in the layout `node`, in the order they read"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end

const shots = get(ENV, "DETAIL_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "the box of a function opens to its documentation and its methods" begin
  caret!(4)
  key(Keys.enter, Keys.cmd)
  o = outcome(4)
  @test o.more && !o.open && o.subject === length
  t = opened!(4)   # runs the line again, so the box is a new one
  o = outcome(4)
  @test o.open && t !== nothing
  @test any(line -> occursin("length(", line), t.lines)
  @test "```julia" in t.lines   # what the function takes is a block of code
  @test t.what == "method" && length(t.rows) == length(methods(length))
  @test all(row -> !occursin(" @ ", row[1]) && occursin(":", row[3]), t.rows)
  @test t.search === nothing
  r = rect(o.body)
  @test r !== nothing && K.num(r.height) <= K.num(K.DETAIL_H) + 2
  @test K.num(r.left) + K.num(r.width) <= 1000
  @test "$(length(t.rows)) methods" in texts(K.describe(o.body))
  shot("function")
end

@testset "the wheel moves through the box, not through the page" begin
  o = outcome(4)
  t = o.body.detail
  was = e.scroll.offset
  at(middle(rect(o.body)))
  onscroll(w, Vec2{px}(0px, -5px)); frames()
  @test t.scroll.offset > 0px
  @test e.scroll.offset == was
  far = t.scroll.offset
  foreach(_ -> onscroll(w, Vec2{px}(0px, -400px)), 1:20); frames()
  @test t.scroll.offset > far
  @test rect(o.body) !== nothing
  shot("methods")
end

@testset "a function that the page wrote shows what the page wrote of it" begin
  t = opened!(6)
  @test outcome(6).first == 5   # the words above it are its documentation, and run with it
  @test t.lines == ["Doubles a number"]
  @test length(t.rows) == 1 && startswith(t.rows[1][1], "double(n)")
  @test "1 method" in texts(K.describe(outcome(6).body))
  # A function with no name has methods and no documentation
  t = opened!(9)
  @test isempty(t.lines) && length(t.rows) == 1
end

@testset "the box of a module opens to its documentation and its names" begin
  t = opened!(7)
  o = outcome(7)
  @test o.subject === Base.Iterators
  @test !isempty(t.lines)   # Julia's words about the module, which has no readme
  @test t.what == "name"
  names = first.(t.rows)
  @test "zip" in names && "Enumerate" in names
  @test !any(startswith("#"), names)
  @test t.rows[findfirst(==("zip"), names)][2] == "function"
  # About has the first sentence of what Julia says of each name
  about = Dict(row[1] => row[3] for row in t.rows)
  @test startswith(about["zip"], "Run multiple iterators at the same time")
  @test endswith(about["zip"], ".") && !occursin('\n', about["zip"])
  @test about["Base"] == "The base library of Julia."
  @test count(!isempty, values(about)) > length(about) / 2
  @test t.rows[findfirst(==("Enumerate"), names)][2] == "type"
  @test "$(length(t.rows)) names" in texts(K.describe(o.body))
  shot("module")
end

@testset "the field over a module's names searches them" begin
  o = outcome(7)
  t = o.body.detail
  r = rect(t.search)
  @test r !== nothing
  click(middle(r))
  @test w.focus === t.search
  typed("enum")
  @test t.search.text == "enum"
  found = [t.rows[i][1] for i in K.sought!(t)]
  @test !isempty(found) && all(name -> occursin("enum", lowercase(name)), found)
  @test startswith(lowercase(first(found)), "enum")   # the names that start with the words come first
  @test "$(length(found)) of $(length(t.rows)) names" in texts(K.describe(o.body))
  @test b.lines[7] == "Base.Iterators"   # the typing went to the field, not to the page
  shot("search")
  # esc gives the keyboard back to the page
  key(Keys.escape)
  @test w.focus === e
end

@testset "the headings of a module's table sort it and show fewer of its rows" begin
  t = opened!(7)
  o = outcome(7)
  shown() = [t.rows[i] for i in K.sought!(t)]
  menu() = any(p -> p.key == K.NAMES_KEY, popups(w))
  head(column) = t.heads[(:head, column)]
  press(node) = (onkey(node, KeyPress{Keys.mouse_left}(0, w)); frames())
  @test all(column -> rect(head(column)) !== nothing, 1:3)
  @test "Name" in texts(K.describe(o.body)) && "Kind" in texts(K.describe(o.body))
  all_rows = length(t.rows)
  # The Kind heading: its menu lists the kinds, and a click on one shows only that kind
  click(middle(rect(head(2))))
  @test menu() && t.asking == 2
  @test K.kinds_of(t) == sort(unique(row[2] for row in t.rows))
  press(t.heads[(:kind, "type")])
  @test !isempty(shown()) && all(row -> row[2] == "type", shown())
  @test length(shown()) < all_rows
  @test "$(length(shown())) of $all_rows names" in texts(K.describe(o.body))
  # ... and its two orders put the kinds in order
  press(t.heads[(:kind, "type")])
  @test length(shown()) == all_rows
  press(t.heads[(:sort, :desc)])
  @test t.sort == (2, :desc) && issorted([row[2] for row in shown()], rev=true)
  press(t.heads[(:sort, :desc)])   # a second click takes the order away
  @test t.sort === nothing
  key(Keys.enter)
  @test !menu() && w.focus === e
  # The Name heading: Z–A, and a field that keeps the names that have its words
  click(middle(rect(head(1))))
  @test menu() && t.asking == 1 && w.focus === t.field
  press(t.heads[(:sort, :desc)])
  names = [K.sort_words(row[1]) for row in shown()]
  @test issorted(names, rev=true) && length(names) == all_rows
  typed("zi")
  @test !isempty(shown()) && all(row -> occursin("zi", lowercase(row[1])), shown())
  shot("heading")
  key(Keys.enter)   # Return keeps it
  @test !menu() && t.filters == Dict(1 => "zi")
  # esc puts back what the field held before
  click(middle(rect(head(1))))
  typed("p")
  @test t.filters == Dict(1 => "zip")
  key(Keys.escape)
  @test !menu() && t.filters == Dict(1 => "zi")
  @test b.lines[7] == "Base.Iterators"   # none of it went to the page
end

@testset "a module with a readme shows the readme" begin
  t = opened!(8)
  o = outcome(8)
  @test o.subject isa Module && !o.failed
  @test t.lines[1] == "# Paint" && "- two coats" in t.lines
  rows = Dict(row[1] => row for row in t.rows)
  @test rows["litres"][2] == "function"
  @test rows["Tin"][2] == "type"
  @test rows["COATS"][2:3] == ("value", "2")
  @test rows["litres"][3] == "1 method"   # a name with no documentation says what it can
  shot("readme")
end

@testset "a click on a name shows its value under its row" begin
  o = outcome(8)
  t = o.body.detail
  place(name) = findfirst(row -> row[1] == name, t.rows)
  row(name) = t.parts[place(name)]
  tall() = K.num(rect(o.body).height)
  closed = tall()
  # A function: what the module wrote of it, and its methods
  click(middle(rect(row("litres"))))
  @test t.open == place("litres") && t.inner.what == "method"
  @test length(t.inner.rows) == 1 && startswith(t.inner.rows[1][1], "litres(area)")
  @test "1 method" in texts(K.describe(o.body))
  @test tall() > closed   # the box makes room for it
  shot("row")
  # A type: as code declares it, with its fields inside
  click(middle(rect(row("Tin"))))
  @test t.open == place("Tin")   # one name shows at a time
  @test t.inner.lines == ["```julia", "struct Tin", "  size::Float64", "end", "```"]
  @test isempty(t.inner.rows)
  @test K.declaration(Base.Iterators.Enumerate) == ["struct Enumerate{I}", "  itr::I", "end"]
  @test K.declaration(AbstractFloat) == ["abstract type AbstractFloat <: Real end"]
  @test K.declaration(Float64) == ["primitive type Float64 <: AbstractFloat 64 end"]
  @test K.declaration(Base.RefValue)[1] == "mutable struct RefValue{T} <: Ref{T}"
  # Any other value, as Julia writes it
  click(middle(rect(row("COATS"))))
  @test t.inner.lines == ["`Int64`", "", "```julia", "2", "```"] && isempty(t.inner.rows)
  @test !("0 s" in texts(K.describe(o.body)))   # no table, so no words over one
  shot("value")
  # A second click hides it
  click(middle(rect(row("COATS"))))
  @test t.open == 0 && t.inner === nothing
  @test tall() ≈ closed atol=1
  @test b.caret == (8, 0)   # none of the clicks moved the caret
end

@testset "a click on a method shows its code" begin
  o = outcome(8)
  t = o.body.detail
  litres = findfirst(row -> row[1] == "litres", t.rows)
  click(middle(rect(t.parts[litres])))
  @test t.open == litres && t.inner.what == "method"
  # A method of another file: the file shows in a window beside this one, with the caret on the method's first line
  r = t.inner.parts[1]
  @test r isa K.MethodRow && K.cursor(r) == :hand
  click(middle(rect(r)))
  shown = filter(o -> o !== e && o.buf.path == realpath(joinpath(dir, "paint.jl")), K.editors)
  @test length(shown) == 1 && only(shown).buf.caret[1] == 2
  @test b.path == page && b.caret == (8, 0)   # this window still shows the page
  # A second click brings that window to the front, and opens no other
  click(middle(rect(r)))
  @test count(o -> o.buf.path == realpath(joinpath(dir, "paint.jl")), K.editors) == 1
  foreach(o -> (win = K.window_of(o); win === nothing || close(win)), shown)
  click(middle(rect(t.parts[litres])))   # hides the method again
  K.focus(e)
  # A method that the page makes is a line of this page, so the caret goes there and no window opens
  n = length(K.editors)
  t = opened!(6)
  caret!(9)
  @test outcome(6).open
  click(middle(rect(t.parts[1])))
  @test b.caret == (6, 0) && length(K.editors) == n
  # A method of Julia's own shows the file of Julia's code that has it
  t = opened!(4)
  k = findfirst(m -> m.module === Base && String(m.file) == "essentials.jl", t.methods)
  r = K.method_row!(outcome(4).body, t, k)
  @test K.cursor(r) == :hand
  onkey(r, KeyPress{Keys.mouse_left}(0, w))
  base = realpath(Base.find_source_file("essentials.jl"))
  shown = filter(o -> o.buf.path == base, K.editors)
  @test length(shown) == 1 && startswith(only(shown).buf.lines[only(shown).buf.caret[1]], r"\s*(function )?length\(")
  @test b.caret == (4, 0)
  # Ladder never changes a file of Julia's own: it has the lock, a key typed in it changes nothing, and nothing writes it
  o = only(shown)
  @test o.buf.fixed && K.caretless(o.buf) && !K.writes(o.buf)
  was = copy(o.buf.lines)
  win = K.window_of(o)
  ontype(win, Typed('x', win)); frame(win)
  K.edit!(o.buf, (1, 0), (1, 0), "x")
  @test o.buf.lines == was
  # The top bar has the lock, which says "Read only" while the mouse is over it
  lock_in(node) = (hasproperty(node, :from) && node.from isa K.ReadOnly) || (node isa K.GeometricUI && any(lock_in, node.children))
  @test lock_in(K.describe(o.nodes[:topbar])) && K.tip(o.nodes[:read_only]) == "Read only"
  foreach(o -> (win = K.window_of(o); win === nothing || close(win)), shown)
  # A method that code made with no file has no code to show, so a click on it does nothing
  nofile = Core.eval(Module(), Base.remove_linenums!(:(nofile(x) = x)))
  t = K.Detail(nofile)
  r = K.method_row!(outcome(4).body, t, 1)
  @test K.cursor(r) == :arrow
  onkey(r, KeyPress{Keys.mouse_left}(0, w))
  @test length(K.editors) == n && b.caret == (4, 0)
  opened!(8)   # the next test closes the box of the module
end

@testset "a box closes with a click, and the page is as it was" begin
  o = outcome(8)
  click(middle(rect(o)))
  @test !o.open
  key(Keys.escape)
  @test isempty(K.outcomes(e))
  @test b.lines[4] == "length"
end

@testset "the box of a type says what it's a kind of, and opens to its fields" begin
  # The types that line 16 names
  for line in (10, 15)
    caret!(line)
    key(Keys.enter, Keys.cmd)
  end
  caret!(16)
  key(Keys.enter, Keys.cmd)
  o = outcome(16)
  @test o.brief == "Meter <: Gauge" && !o.failed
  @test o.more && !o.open && o.subject isa Type
  t = opened!(16)
  o = outcome(16)
  @test o.open && t !== nothing
  @test t.lines[1:6] == ["```julia", "struct Meter <: Gauge", "  done::Float64", "  label::String", "end", "```"]
  @test "A bar that shows how much is done" in t.lines
  @test isempty(t.rows) && t.what == ""
  r = rect(o.body)
  @test r !== nothing && K.num(r.left) + K.num(r.width) <= 1000
  words = texts(K.describe(o.body))
  @test !any(startswith("0 "), words)   # no table, so no words over one
  shot("type")
  click(middle(rect(o)))
  @test !o.open
  key(Keys.escape)
end

@testset "a type's box and declaration" begin
  # A UI node's type has no fields that join it to the nodes around it, and its kind is written as the code names it
  decl = K.declaration(K.Member; home=K)
  @test decl[1] == "mutable struct Member <: SemanticUI"
  @test "  name::String" in decl && "  depth::Int64" in decl
  @test !any(l -> occursin(r"^  (parent|firstchild|nextsibling|state)::", l), decl)
  @test K.declared(Int) && K.declared(Vector) && !K.declared(Union{Int,String}) && !K.declared(1)
  @test K.type_brief(Int) == "Int64 <: Signed"
  @test K.type_brief(Vector) == "Vector <: DenseVector"
  @test K.type_brief(Any) == "Any"
end

@testset "a module whose documentation can't be read doesn't stop a box" begin
  # The built app leaves out the documentation of the code built into it, like Base's, and Julia
  # throws when it's asked for that. A module whose table of documentation isn't a table throws here.
  stripped = Module(:Stripped)
  Core.eval(stripped, :(const $(Base.Docs.META) = 1))
  push!(Base.Docs.modules, stripped)
  try
    t = opened!(4)
    @test any(line -> occursin("length(", line), t.lines)
    @test length(t.rows) == length(methods(length))
    t = opened!(7)
    @test !isempty(t.rows)
  finally
    filter!(m -> m !== stripped, Base.Docs.modules)
  end
end

@testset "a type that its package can't write doesn't stop a box" begin
  # Prospects.jl writes an enum type with its values, and it throws for a kind of enum, like ScopedEnum{UInt8}, that has none.
  # UI.jl's Geometric module has types of that kind, so its box closed Ladder.
  odd = Module(:Odd)
  Core.eval(odd, quote
    abstract type Kind{T} end
    Base.show(io::IO, T::Type{<:Kind}) = error("a kind has no values")
    struct Plain <: Kind{UInt8} end
    take(x::Plain) = x
  end)
  rows = Dict(r[1] => r for r in K.name_rows(odd))
  @test rows["Plain"][3] == "a kind of Kind"
  @test only(K.method_rows(Base.invokelatest(getglobal, odd, :take)))[1] == "take(x)"
  Plain = Base.invokelatest(getglobal, odd, :Plain)
  @test K.type_brief(Plain, odd) == "Plain <: Kind"
  @test K.declaration(Plain; home=odd) == ["struct Plain <: Kind", "end"]
end
