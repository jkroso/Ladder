# Tests for where a `save` block of main.jl saves: with no `to`, or after a
# click on Choose, it lists folders as a breadcrumb, with a field for the name
# of the file. See "a save of a table's rows". Run them with
# `julia -O0 --project=. test/save_picker_test.jl`. They write files into a
# temporary folder and click in a window that isn't on the screen. Set
# `LADDER_SHOTS` to a folder, and they save pictures there.

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
mkpath(joinpath(dir, "out", "deeper"))
file("taken.csv", "old\n")
file("notes.md", "# Notes\n")

const page = joinpath(dir, "costs.md")
write(page, """
# Costs

| Item | Cost |
|---|---|
| Sand | 120 |
| Pipe | 45 |

```save
```

## Second

```save
to: costs.csv
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1100px))
const (; frames, at, press, shot) = drive(w)
frames()

release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(3))
click(place) = (press(place); release())
key(k) = (onkey(w, KeyPress{k}(0, w)); frames(3))
view(n) = e.nodes[(:block, K.SAVE, page, n)]
block(n) = (s = K.block_lines(e.buf, K.SAVE, n); e.buf.lines[s[1]+1:s[2]-1])
"Scroll the page until the top of the `n`th save block is near the top of the window, and it has been laid out and drawn"
show_save(n) = begin
  s = K.block_lines(e.buf, K.SAVE, n)
  K.show_line!(e, s[2] + 1); frames(2)
  e.scroll.offset = max(0px, K.item(e, s[1]).top - 40px); frames(3)
  view(n)
end
button(v, key=:go) = v.parts[(:button, key)]
picker(v) = v.parts[:picker]
field(v) = v.parts[:name]
"The names in the list of the picker of `v`"
names(v) = [basename(x.path) for x in K.contents(picker(v)) if x isa K.FileEntry]
"Click the line of the picker's list that has `name`"
pick(v, name) = click(middle(only(x for x in K.contents(picker(v)) if x isa K.FileEntry && basename(x.path) == name)))
"Put `text` in the name field of `v`"
name!(v, text) = (f = field(v); f.text = text; f.cursor = f.anchor = length(text); frames(2))
"What the line under the list says: what a click will do, or why it can't"
note(v) = (d = K.save_data(v); c = K.save_chosen(v, d); isempty(c) ? "Type a name for the file." :
           (p = K.save_problem(v, d; path=c); isempty(p) ? K.save_plan(v, d; to=c) : p))

@testset "a save block with no file lists folders and asks for a name" begin
  v = show_save(1)
  @test K.asks_where(v) && picker(v).at == K.docdir(e)
  # Only folders, and the name of the file that the rows will make
  @test names(v) == ["out"] && field(v).text == "Costs.csv"
  @test button(v).words == "Save" && note(v) == "A click writes the 2 rows into a new file, Costs.csv, as CSV."
  shot("save-picker.png")
  pick(v, "out")
  @test picker(v).at == joinpath(K.docdir(e), "out") && names(v) == ["deeper"]
  # A name with no end gets .csv
  name!(v, "costs")
  click(middle(button(v).rect))
  @test read(joinpath(dir, "out", "costs.csv"), String) == "Item,Cost\nSand,120\nPipe,45\n"
  @test block(1) == ["to: out/costs.csv"] && !K.asks_where(v) && startswith(v.said, "Saved 2 rows to costs.csv at ")
end

@testset "Choose picks another file, and a name that's there says Replace" begin
  v = show_save(2)
  @test !K.asks_where(v) && button(v, :choose).words == "Choose"
  click(middle(button(v, :choose).rect))
  @test K.asks_where(v) && picker(v).at == K.docdir(e) && field(v).text == "costs.csv" && button(v, :choose).on
  name!(v, "taken.csv")
  @test button(v).words == "Replace" && note(v) == "A click replaces taken.csv with the 2 rows, as CSV."
  name!(v, "notes.md")
  @test startswith(note(v), "Ladder replaces only a CSV, TSV, JSON or text file") && button(v).off
  name!(v, "")
  @test note(v) == "Type a name for the file." && button(v).off
  shot("save-choose.png")
  # Return in the field saves
  name!(v, "fresh.json")
  click(middle(field(v)))
  @test w.focus === field(v)
  key(Keys.enter)
  @test block(2) == ["to: fresh.json"] && !v.choosing
  @test K.json_value(read(joinpath(dir, "fresh.json")))[1].keys == ["Item", "Cost"]
  # Esc closes the list, and the file stays
  click(middle(button(v, :choose).rect))
  click(middle(field(v)))
  key(Keys.escape)
  @test !v.choosing && block(2) == ["to: fresh.json"] && w.focus === e
end
