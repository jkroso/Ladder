# Tests for the file picker of the `load` block of main.jl: a breadcrumb that
# lists the folders and the CSV, TSV and JSON files beside the page. See
# "rows loaded from a server or a file". Run them with
# `julia -O0 --project=. test/load_picker_test.jl`. They click in a window
# that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save
# pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); mkpath(dirname(path)); write(path, text); path)
file("rows.csv", "Item,Cost\nSand,120\nPipe,45\n")
file("notes.md", "# Notes\n")
file("data/orders.json", """{"data": {"orders": [{"id": "A1", "total": 250}, {"id": "A2", "total": 80}]}}""")
file("data/readme.txt", "hello")
file("data/more/people.tsv", "Name\tAge\nAnn\t30\n")

const page = joinpath(dir, "pick.md")
write(page, """
# Pick

```load
```

## Second

```load
from: rows.csv
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1100px))
const (; frames, at, press, release, click, shot) = drive(w)
frames()

view(n) = e.nodes[(:block, K.LOAD, page, n)]
block(n) = (s = K.block_lines(e.buf, K.LOAD, n); e.buf.lines[s[1]+1:s[2]-1])
"Scroll the page until the top of the `n`th load block is near the top of the window, and it has been laid out and drawn"
show_block(n) = begin
  s = K.block_lines(e.buf, K.LOAD, n)
  K.show_line!(e, s[2] + 1); frames(2)
  e.scroll.offset = max(0px, K.item(e, s[1]).top - 40px); frames(3)
  view(n)
end
picker(v) = v.parts[:picker]
"The names in the list of the picker of `v`"
names(v) = [basename(x.path) for x in K.contents(picker(v)) if x isa K.FileEntry]
"Click the line of the picker's list that has `name`"
pick(v, name) = click(middle(only(x for x in K.contents(picker(v)) if x isa K.FileEntry && basename(x.path) == name)))
shown(v) = (x = K.filter_shown!(v); x.subset === nothing ? [] : K.filter_table(x.data, x.subset))
"Open the list at the block's name, and take its row Choose a file…"
choose_file(v) = begin
  click(middle(v.parts[:source]))
  c = v.parts[:sources]
  click(middle(c.parts[(:choice_row, findfirst(r -> r.key == :file, c.rows))]))
end

@testset "a load block with no file shows a picker of the page's folder" begin
  v = show_block(1)
  @test K.picks_file(v) && picker(v).at == K.docdir(e)
  @test startswith(K.picker_words(v), "Choose a CSV, TSV or JSON file, or write a web address")
  # Folders first, then the files that it can load. The page and the text file aren't there.
  @test names(v) == ["data", "rows.csv"]
  # A picker has no button that opens a file in the window
  @test picker(v).button === nothing
  shot("load-picker.png")
  pick(v, "data")
  @test picker(v).at == joinpath(K.docdir(e), "data") && names(v) == ["more", "orders.json"]
  pick(v, "orders.json")
  # The file is the block's `from` now, from the page's folder, and the block shows its rows
  @test block(1) == ["from: data/orders.json"] && !K.picks_file(v)
  @test shown(v) == [["id", "total"], ["A1", "250"], ["A2", "80"]]
  shot("load-picked.png")
end

@testset "Choose a file… opens the picker in the folder of the block's file" begin
  v = show_block(2)
  @test !K.picks_file(v) && !haskey(v.parts, (:button, :choose))
  choose_file(v)
  @test K.picks_file(v) && v.choosing && picker(v).at == K.docdir(e)
  @test K.picker_words(v) == "Choose a CSV, TSV or JSON file to load in place of rows.csv."
  pick(v, "data"); pick(v, "more"); pick(v, "people.tsv")
  @test block(2) == ["from: data/more/people.tsv"] && !v.choosing
  @test shown(v) == [["Name", "Age"], ["Ann", "30"]]
  # The next time, it starts in the folder of that file. A name at the top goes back up to its folder.
  choose_file(v)
  @test picker(v).at == joinpath(K.docdir(e), "data", "more")
  click(middle(picker(v).crumbs[joinpath(K.docdir(e), "data")]))
  @test picker(v).at == joinpath(K.docdir(e), "data")
  shot("load-choose.png")
  # Close closes it, and the file stays
  click(middle(v.parts[(:button, :close_picker)].rect))
  @test !K.picks_file(v) && block(2) == ["from: data/more/people.tsv"]
end

@testset "Insert > Load adds a block that picks a file" begin
  i = findfirst(x -> x isa Tuple && x[1] == "Load", K.INSERTS)
  @test K.INSERTS[i][2] == ["```load", "```", "", ""] && K.INSERTS[i][3] == (4, 0)
  # A breadcrumb that isn't a picker lists every file
  @test K.Breadcrumb(at=dir).files === nothing
end
