# Tests for opening the file or the folder that a file path shows. See "files
# in a live block" in main.jl. Run them with
# `julia -O0 --project=. test/file_path_open_test.jl`. They click in a window
# that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = realpath(mktempdir())
mkdir(joinpath(dir, "sub"))
const notes = joinpath(dir, "notes.md")
const other = joinpath(dir, "other.md")
const sub = joinpath(dir, "sub")
const inner = joinpath(sub, "inner.md")
write(notes, "# Notes\n\nSome notes.\n")
write(other, "# Other\n")
write(inner, "# Inner\n")
const page = joinpath(dir, "paths.md")
write(page, """
# Paths

```ui
fs"$notes"
```

```ui
fs"$sub"
```

A path in a line: !`fs"$other"`.

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1400px))
const (; frames, at, press, release, click) = drive(w, moved=2)
frames()

"A click with ⌘ held"
cmd_click(place) = (w.keys |= Keys.cmd; click(place); w.keys ⊻= Keys.cmd; frames())
right(r) = K.num(r.left) + K.num(r.width)

"The breadcrumb of the path `at` on the page that shows"
crumb(at) = only(n.value for n in values(e.nodes) if n isa K.Shown && n.value isa K.Breadcrumb && n.value.at == at)
"Where the Open button of the breadcrumb `l` is, once the mouse is over the breadcrumb so that the button shows"
button_at(l) = (at(middle(rect(l))); middle(rect(l.button)))
"Go back to the page with the paths on it"
back!() = (K.go_back!(e); frames(3); @test e.buf.path == page)

@testset "a path to a file has an Open button at the right end of its names" begin
  l = crumb(notes)
  b = l.button
  @test b isa K.OpenButton
  at(middle(rect(l)))
  r = rect(b)
  @test r !== nothing
  # It's after the last name, at the right end of the row
  @test K.num(r.left) > right(rect(l.crumbs[notes]))
  @test right(r) ≈ right(rect(l)) atol=2
end

@testset "the Open button shows only while the mouse is over the path, and the names stay where they are" begin
  l, s = crumb(notes), crumb(sub)
  at(middle(rect(l)))
  @test rect(l.button) !== nothing
  @test rect(s.button) === nothing
  name = rect(l.crumbs[notes])
  at(middle(rect(s)))
  @test rect(l.button) === nothing
  @test rect(s.button) !== nothing
  @test rect(l.crumbs[notes]).left == name.left
end

@testset "the Open button shows the file in the window" begin
  click(button_at(crumb(notes)))
  @test e.buf.path == notes
  back!()
end

@testset "a click on the last name still lists what's in the folder, and shows no file" begin
  l = crumb(notes)
  click(middle(rect(l.crumbs[notes])))
  @test l.open
  @test e.buf.path == page
  click(middle(rect(l.crumbs[notes])))
  @test !l.open
end

@testset "a click with ⌘ held on a name shows that file or folder in the window" begin
  l = crumb(notes)
  cmd_click(middle(rect(l.crumbs[notes])))
  @test e.buf.path == notes
  back!()
  K.go_folder!(e, homedir())
  cmd_click(middle(rect(crumb(notes).crumbs[dir])))
  @test e.folder == dir
  @test e.buf.path == dir
  back!()
end

@testset "a click with ⌘ held on a line of the list shows that file" begin
  l = crumb(sub)
  l.open = true
  frames(3)
  line = l.entries[inner]
  @test rect(line) !== nothing
  cmd_click(middle(rect(line)))
  @test e.buf.path == inner
  back!()
  # A click with no ⌘ makes the file the path, as before
  l = crumb(sub)
  l.open = true
  frames(3)
  click(middle(rect(l.entries[inner])))
  @test l.at == inner
  @test e.buf.path == page
end

@testset "the Open button of a folder shows the folder's page in the window" begin
  K.go_folder!(e, homedir())
  # The path in the last test went to the file in the folder. A click on the folder's name takes it back.
  l = crumb(inner)
  click(middle(rect(l.crumbs[sub])))
  @test l.at == sub
  click(button_at(l))
  @test e.folder == sub
  @test e.buf.path == sub
  back!()
end

@testset "a path in a line of text has no Open button, and a click with ⌘ held on its name shows the file" begin
  l = crumb(other)
  @test l.inline
  @test l.button === nothing
  cmd_click(middle(rect(l.crumbs[other])))
  @test e.buf.path == other
  back!()
end
