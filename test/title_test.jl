# Tests for the menu of the file's name in the top bar. See "a right-click on
# the file's name" in main.jl. Run them with `julia -O0 --project=. test/title_test.jl`.
# They right-click, type and press keys in a window that isn't on the screen,
# so the menu is the one that Ladder draws, not the Mac's own.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

@use "../main" => K
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "notes.md")
write(page, "# Notes\n\nSome words.\n")
write(joinpath(dir, "other.md"), "# Other\n")
write(joinpath(dir, "taken.md"), "# Taken\n")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const (; frames, at, typed, key) = drive(w, moved=2)
frames()

right_click(place) = (at(place); onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames())
left_click(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); w.keys ⊻= Keys.mouse_left; frames())

title() = e.nodes[:title]
"The items of a menu, without the one that opens the file in the Mac's app for it, which this Mac chooses"
ours(items) = filter(i -> i == "Open in New Window" || !startswith(i, "Open in "), items)
"The menu that Ladder drew, or nothing"
menu() = (ps = [p for p in popups(w) if p.key == :menu]; isempty(ps) ? nothing : only(ps).content)
"Choose the item called `name` in the menu that Ladder drew, with ↓ and Return"
choose(name) = begin
  m = menu()
  foreach(_ -> key(Keys.down), 1:findfirst(==(name), m.items))
  key(Keys.enter)
end
renaming() = K.renaming(e, :title)

const shots = get(ENV, "TITLE_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "a right-click on the file's name shows the file's menu" begin
  r = rect(title())
  @test r !== nothing
  right_click(middle(r))
  @test menu() !== nothing
  @test ours(menu().items) == ["Open in New Window", "Rename", "Duplicate", "Copy Path", "Copy Link", "Show in Finder", "Ignore", "Move to Trash"]
  key(Keys.escape)
  @test menu() === nothing
end

@testset "a right-click on the top bar beside the name shows no menu" begin
  r = rect(title())
  # The mouse comes from the page. When it rests on the name, the file's path shows over this part of the bar,
  # and a right-click there is on a folder of the path.
  at((500, 400))
  right_click((K.num(r.left) - 40, K.num(r.top) + K.num(r.height) / 2))
  @test menu() === nothing
end

@testset "Rename puts a text field with the whole name where the name was" begin
  right_click(middle(rect(title())))
  choose("Rename")
  @test renaming() == page
  @test w.focus === K.renamer(e)
  i = K.renamer(e)
  @test i.text == "notes.md"
  # The part before the ending is selected, so what's typed takes its place
  @test (i.anchor, i.cursor) == (0, 5)
  # The sidebar's list shows no field of its own
  @test K.renaming(e, :sidebar) == ""
  typed("ideas")
  @test i.text == "ideas.md"
  shot("1-renaming")
  key(Keys.enter)
  @test renaming() == ""
  @test !isfile(page) && isfile(joinpath(dir, "ideas.md"))
  @test e.buf.path == joinpath(dir, "ideas.md")
  @test read(joinpath(dir, "ideas.md"), String) == "# Notes\n\nSome words.\n"
  # The keyboard goes back to the text
  @test w.focus === e
end

@testset "a name with no ending keeps the file's ending" begin
  right_click(middle(rect(title())))
  choose("Rename")
  i = K.renamer(e)
  i.anchor, i.cursor = 0, length(i.text)   # the whole name, ending and all
  typed("plans")
  key(Keys.enter)
  @test e.buf.path == joinpath(dir, "plans.md") && isfile(joinpath(dir, "plans.md"))
end

@testset "esc leaves the file with the name it has" begin
  right_click(middle(rect(title())))
  choose("Rename")
  typed("gone")
  key(Keys.escape)
  @test renaming() == ""
  @test e.buf.path == joinpath(dir, "plans.md") && isfile(joinpath(dir, "plans.md"))
  @test !isfile(joinpath(dir, "gone.md"))
  @test w.focus === e
end

@testset "a name that another file has changes nothing, and the field stays" begin
  right_click(middle(rect(title())))
  choose("Rename")
  typed("taken")
  key(Keys.enter)
  @test renaming() == joinpath(dir, "plans.md")
  @test read(joinpath(dir, "taken.md"), String) == "# Taken\n"
  key(Keys.escape)
  @test e.buf.path == joinpath(dir, "plans.md")
end

@testset "a click on the page gives the file the name that's typed" begin
  right_click(middle(rect(title())))
  choose("Rename")
  typed("draft")
  left_click(middle(rect(e.nodes[:document])))
  @test renaming() == ""
  @test e.buf.path == joinpath(dir, "draft.md") && isfile(joinpath(dir, "draft.md"))
end

@testset "Show in Finder is grey for a file that isn't on the disk yet" begin
  rm(joinpath(dir, "draft.md"))
  right_click(middle(rect(title())))
  # Nor is there a file to open in a new window or to copy
  @test menu().items == ["Rename", "Copy Path", "Copy Link", "Move to Trash"]
  key(Keys.escape)
  write(e.buf.path, join(e.buf.lines, "\n"))
end

@testset "Move to Trash takes the file away and shows another" begin
  trashed = String[]
  K.trasher[] = path -> (push!(trashed, path); rm(path); true)
  at_first = e.buf.path
  right_click(middle(rect(title())))
  choose("Move to Trash")
  @test trashed == [at_first]
  @test !isfile(at_first)
  @test e.buf.path != at_first && isfile(e.buf.path)
end

@testset "Rename in the sidebar's menu still puts the field in the sidebar" begin
  K.toggle_panel!(e)
  e.slid = 0.0   # the sidebar is all the way in at once. 30 quick frames take less time than the slide does.
  frames(3)
  other = joinpath(dir, "other.md")
  label = only(n for n in K.items(K.file_tree(e)) if n.firstchild isa K.FileLabel && n.firstchild.path == other).firstchild
  right_click(middle(rect(label)))
  @test ours(menu().items) == ["Open in New Window", "Rename", "Duplicate", "Copy Path", "Copy Link", "Show in Finder", "Ignore", "Move to Trash"]
  choose("Rename")
  @test K.renaming(e, :sidebar) == other && renaming() == ""
  @test K.renamer(e).text == "other.md"
  typed("second")
  key(Keys.enter)
  @test isfile(joinpath(dir, "second.md")) && !isfile(other)
  @test w.focus === K.file_tree(e)
end

@testset "⌘O lists each page with its ending, and finds a page by its whole name" begin
  write(joinpath(dir, "plan.md"), "# Plan\n")
  write(joinpath(dir, "plan.markdown"), "# Plan\n")
  K.open_finder!(e)
  typed("plan.md")   # the ending is part of the name that's matched
  @test basename.(K.matches(e)) == ["plan.markdown", "plan.md"]
  typed("x")   # "plan.mdx" is in no name
  @test isempty(K.matches(e))
  key(Keys.escape)
  @test e.popup == :none
end
