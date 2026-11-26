# Tests for a board of a folder, in main.jl: a `board` block with a line like
# `in: jobs` shows the to-do items of every page of a folder as cards, and a
# card that's dropped on the last column ticks its item in the item's own
# page. Run them with `julia -O0 --project=. test/board_folder_test.jl`. They
# drag cards in a window that isn't on the screen. Set `LADDER_SHOTS` to a
# folder, and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "../board" => Boards
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = realpath(mktempdir())
@eval K settings_file() = $(joinpath(dir, "settings"))
const jobs = joinpath(dir, "jobs")
mkpath(joinpath(jobs, "bath"))
const kitchen = joinpath(jobs, "kitchen.md")
const bath = joinpath(jobs, "bath", "tiles.md")
write(kitchen, "# Kitchen\n\n- [ ] Lay the pipe\n- [x] Order the sink\n- [ ] Call the plumber\n")
write(bath, "# Tiles\n\n- [ ] Lay the pipe\n- [ ] Grout\n")
write(joinpath(jobs, "notes.md"), "# Notes\n\nNo items here.\n")
const page = joinpath(dir, "all.md")
write(page, """
# Every job

- [ ] An item of this page, which the board of the folder leaves out

```board
in: jobs

kitchen: Call the plumber | Doing
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, press, release, shot) = drive(w)
frames()
const v = e.nodes[(:block, K.BOARD, page, 1)]

"Press the mouse at one place, move it to another by way of the place between, and let go"
drag(from, to) = (press(from); at(((from[1] + to[1]) / 2, (from[2] + to[2]) / 2)); at(to); release())
block() = (s = K.block_lines(e.buf, K.BOARD, 1); e.buf.lines[s[1]+1:s[2]-1])
card(key) = middle(rect(v.parts[(:card, key)]))
column(c) = (r = rect(v.parts[(:column, c)]); (K.num(r.left + r.width / 2), K.num(r.top + r.height - 12)))
keys_of(c) = [t.key for t in K.columns!(v)[c]]

@testset "the block names a folder" begin
  @test Boards.folder(Boards.board(["in: jobs", "", "a | Doing"])) == "jobs"
  @test Boards.folder(Boards.board(["columns: A, B, C", "In:  ."])) == "."
  @test Boards.folder(Boards.board(["in:"])) == "."
  @test Boards.folder(Boards.board(["a | Doing"])) === nothing
  # The line stays when the block is written again
  @test Boards.written(Boards.board(["in: jobs", "", "a | Doing"])) == ["in: jobs", "", "a | Doing"]
  @test K.board_folder(v) == jobs
end

@testset "the board shows the items of every page of the folder" begin
  # The pages of the folder come first, then those of the folders in it. Each item is called by its page and its text.
  @test keys_of(1) == ["kitchen: Lay the pipe", "bath/tiles: Lay the pipe", "bath/tiles: Grout"]
  @test keys_of(2) == ["kitchen: Call the plumber"] && keys_of(3) == ["kitchen: Order the sink"]
  @test [t.name for t in K.columns!(v)[1]] == ["Lay the pipe", "Lay the pipe", "Grout"]
  # A card says which page its item is in
  place = K.card_place(v, "bath/tiles: Grout")
  @test place.path == bath && K.card_page(v, place) == "bath/tiles"
  @test !K.planned(v) && !K.dirty(e.buf)
  shot("board-folder.png")
end

@testset "a card that's dropped on the last column ticks its item in its own page" begin
  drag(card("bath/tiles: Grout"), column(3))
  @test read(bath, String) == "# Tiles\n\n- [ ] Lay the pipe\n- [x] Grout\n"
  frames()
  @test "bath/tiles: Grout" in keys_of(3)
  # The page of the board has no change of its own for it
  @test block() == ["in: jobs", "", "kitchen: Call the plumber | Doing"]
  # A card between the first column and the last has a line in the block, and its item stays as it is
  drag(card("bath/tiles: Lay the pipe"), column(2))
  @test block() == ["in: jobs", "", "kitchen: Call the plumber | Doing", "bath/tiles: Lay the pipe | Doing"]
  @test keys_of(2) == ["kitchen: Call the plumber", "bath/tiles: Lay the pipe"] && startswith(readlines(bath)[3], "- [ ] ")
  # Out of the last column: the tick goes from the item's page
  drag(card("kitchen: Order the sink"), column(1))
  @test readlines(kitchen)[4] == "- [ ] Order the sink" && "kitchen: Order the sink" in keys_of(1)
  shot("board-folder-moved.png")
end

@testset "a page that changes on the disk changes the board" begin
  write(kitchen, read(kitchen, String) * "- [ ] Fit the tap\n")
  empty!(K.FOLDER_PAGES)   # the folder is read again every few seconds
  frames()
  @test "kitchen: Fit the tap" in keys_of(1)
end

@testset "two clicks on a card open its page at the item" begin
  place = card("bath/tiles: Lay the pipe")
  press(place); release(); press(place); release()
  @test e.buf.path == bath && e.buf.caret[1] == 3
  K.open!(e, page); frames()
end

@testset "a folder that isn't there, and a folder with no items" begin
  write(joinpath(dir, "none.md"), "```board\nin: nowhere\n```\n\n```board\nin: empty\n```\n")
  mkpath(joinpath(dir, "empty"))
  K.open!(e, joinpath(dir, "none.md")); frames()
  a, b = e.nodes[(:block, K.BOARD, e.buf.path, 1)], e.nodes[(:block, K.BOARD, e.buf.path, 2)]
  @test isempty(K.board_items(a)) && isempty(K.board_items(b))
  shot("board-folder-none.png")
end

close(w)
