# Tests for ask.jl. Run them with `julia -O0 --project=. test/ask_test.jl`.

@use Test: @test, @testset
@use "../ask" => A

const BLOCK = ["Which database should the app use?", "It holds the orders.", "",
               "( ) SQLite. It's one file.", "(x) Postgres", "- [ ] Keep a copy in the cloud", "[x] Keep a copy on this Mac",
               "> We run Postgres already.", "> Ask Sam."]

@testset "reading and writing" begin
  q = A.question(BLOCK)
  @test q.words == ["Which database should the app use?", "It holds the orders."] && A.asked(q) == "Which database should the app use? It holds the orders."
  @test [o.text for o in q.options] == ["SQLite. It's one file.", "Postgres", "Keep a copy in the cloud", "Keep a copy on this Mac"]
  @test [o.chosen for o in q.options] == [false, true, false, true] && [o.many for o in q.options] == [false, false, true, true]
  @test q.note == "We run Postgres already. Ask Sam." && A.answered(q)
  @test A.written(q) == ["Which database should the app use?", "It holds the orders.", "( ) SQLite. It's one file.", "(x) Postgres",
                         "[ ] Keep a copy in the cloud", "[x] Keep a copy on this Mac", "> We run Postgres already. Ask Sam."]
  @test A.written(A.question(A.written(q))) == A.written(q)
  # Words in brackets aren't an answer
  odd = A.question(["(a) Which one?", "[See the plan](plan.md)", "() Yes", "(X) No"])
  @test odd.words == ["(a) Which one?", "[See the plan](plan.md)"] && [o.chosen for o in odd.options] == [false, true]
  open = A.question(["What should the button say?"])
  @test isempty(open.options) && open.note == "" && !A.answered(open) && A.written(open) == ["What should the button say?"]
  @test isempty(A.written(A.question(String[])))
end

@testset "choosing" begin
  q = A.question(BLOCK)
  A.choose!(q, 1)
  @test [o.chosen for o in q.options] == [true, false, false, true]   # one of the first two, and the boxes stay as they were
  A.choose!(q, 1)
  @test [o.chosen for o in q.options] == [false, false, false, true]
  A.choose!(q, 3); A.choose!(q, 4)
  @test [o.chosen for o in q.options] == [false, false, true, false]
  q.note = ""
  A.choose!(q, 3)
  @test !A.answered(q) && A.written(q)[end] == "[ ] Keep a copy on this Mac"
end

@testset "values to set: a slider and a colour" begin
  lines = ["How should the logo look?", "Size: 48px (16px to 96px)", "- Opacity: 0.50 (0 to 1)", "Gap: 12 mm (0 to 40 mm)", "Colour: #E8632B",
           "( ) Round", "(x) Square", "Note: see (a to b)", "Odd: 5 (9 to 2)"]
  q = A.question(lines)
  @test [(f.name, f.kind) for f in q.fields] == [("Size", :slider), ("Opacity", :slider), ("Gap", :slider), ("Colour", :colour)]
  size, opacity, gap, colour = q.fields
  @test (size.number, size.low, size.high, A.step(size), A.said(size)) == (48, 16, 96, 1, "48px")
  @test (opacity.number, A.step(opacity), A.shown(opacity)) == (0.5, 0.01, "0.50") && A.said(gap) == "12 mm" && colour.colour == "#E8632B"
  # Words that only look like a value are words of the question: a range with no number, and one that goes down
  @test q.words == ["How should the logo look?", "Note: see (a to b)", "Odd: 5 (9 to 2)"] && length(q.options) == 2
  # Each line stays where it was, as it was written, with its new value
  @test A.written(q) == ["How should the logo look?", "Size: 48px (16px to 96px)", "- Opacity: 0.50 (0 to 1)", "Gap: 12 mm (0 to 40 mm)", "Colour: #E8632B",
                         "( ) Round", "(x) Square", "Note: see (a to b)", "Odd: 5 (9 to 2)"]
  A.set!(size, 63.6); A.set!(opacity, 2); A.set!(gap, 7.2); colour.colour = "#2a6fdb"
  @test A.written(q)[2:5] == ["Size: 64px (16px to 96px)", "- Opacity: 1.00 (0 to 1)", "Gap: 7 mm (0 to 40 mm)", "Colour: #2a6fdb"]
  @test A.written(A.question(A.written(q))) == A.written(q)
  # What's typed goes where it was, or at the end
  q.note = "Keep it simple"
  @test A.written(q)[end] == "> Keep it simple"
  @test A.written(A.question(["Size: 3 (0 to 9)", "> Small", "( ) Yes"])) == ["Size: 3 (0 to 9)", "> Small", "( ) Yes"]
end
