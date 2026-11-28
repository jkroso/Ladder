# Tests for board.jl. Run them with `julia -O0 --project=. test/board_test.jl`.

@use Test: @test, @testset
@use "../blocks/board" => B

const PAGE = ["# A job", "",
              "- [x] Dig the trench",
              "- [ ] Lay the **new** pipe",
              "  - [ ] Test the pipe",
              "- [ ] Fill the trench"]
items(page=PAGE) = B.todos(page)
names(column) = [t.name for t in column]

@testset "reading and writing" begin
  b = B.board(["columns: Later, Now, Waiting | for someone, Done", "colour: red", "", "Lay the new pipe | Now", "Wait | for it | Waiting | for someone"])
  @test b.columns == ["Later", "Now", "Waiting | for someone", "Done"] && b.other == ["colour: red"]
  @test b.placed == ["Lay the new pipe" => "Now", "Wait | for it | Waiting" => "for someone"]
  @test B.written(b) == ["columns: Later, Now, Waiting | for someone, Done", "colour: red", "", "Lay the new pipe | Now", "Wait | for it | Waiting | for someone"]
  # An empty block has the usual columns, and stays empty
  @test B.board(String[]).columns == B.COLUMNS && isempty(B.written(B.board(String[])))
  @test B.written(B.board(["Lay the new pipe | Doing"])) == ["Lay the new pipe | Doing"]
  # One column isn't a board, and a column that's named twice is one column
  @test B.board(["columns: Only"]).columns == B.COLUMNS && B.board(["columns: A, B, a"]).columns == ["A", "B"]
end

@testset "the column of each item" begin
  b = B.board(["Lay the new pipe | doing", "Fill the trench | Done", "Gone | Doing"])
  @test names.(B.arrange(b, items())) == [["Test the pipe", "Fill the trench"], ["Lay the new pipe"], ["Dig the trench"]]
  # An item whose text changed a little keeps its column
  renamed = replace(PAGE, "- [ ] Lay the **new** pipe" => "- [ ] Lay the new water pipe")
  @test names.(B.arrange(b, items(renamed)))[2] == ["Lay the new water pipe"]
  @test names.(B.arrange(B.Board(), items())) == [["Lay the new pipe", "Test the pipe", "Fill the trench"], [], ["Dig the trench"]]
end

@testset "moving a card" begin
  b = B.Board()
  ts = items()
  @test B.move!(b, ts[2], 2, ts) === nothing && b.placed == ["Lay the new pipe" => "Doing"]
  @test B.move!(b, ts[2], 3, ts) === true && isempty(b.placed)          # to the last column: its box is ticked
  @test B.move!(b, ts[1], 2, ts) === false && b.placed == ["Dig the trench" => "Doing"]   # out of the last column: its tick goes
  @test B.move!(b, ts[1], 1, ts) === false && isempty(b.placed)
  @test B.move!(b, ts[1], 3, ts) === nothing && B.move!(b, ts[3], 1, ts) === nothing && isempty(b.placed)
  b = B.board(["Lay the new pipe | Doing", "Gone | Doing", "Fill the trench | Doing"])
  renamed = items(replace(PAGE, "- [ ] Fill the trench" => "- [ ] Fill in the trench"))
  B.prune!(b, renamed)
  @test b.placed == ["Lay the new pipe" => "Doing", "Fill in the trench" => "Doing"]
end
