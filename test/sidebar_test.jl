# Tests for which files the sidebar opens to show their headings. See
# show_open_file! in main.jl. Run them with `julia -O0 --project=. test/sidebar_test.jl`.
# They open files and click in a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use GeometryBasics: Vec2
@use "./drive" drive
const px = K.px

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
K.SETTINGS_FILE[] = joinpath(dir, "settings")

for name in ("a.md", "b.md", "c.md")
  write(joinpath(dir, name), "# $name\n\nSome words.\n\n## Part of $name\n\nMore words.\n")
end
write(joinpath(dir, "tool.jl"), "f(x) = x + 1\n")

const e = K.build_editor(joinpath(dir, "a.md"))
const w = Window(e, size=(900px, 700px))
const (; frames, click) = drive(w, moved=2)
frames()

"Show the sidebar, or hide it, and draw the window until the sidebar has finished its slide"
sidebar!() = begin
  K.toggle_panel!(e)
  to = e.panel ? 1 : 0
  while K.opened(e) != to
    frame(w)
  end
  frames()
end
"The item of the file `name` in the sidebar"
file(name) = only(item for item in K.file_tree(e).children if basename(item.firstchild.path) == name)
"Is the group of the file `name` open, so the sidebar lists its headings?"
isopen(name) = !file(name).collapsed
"The headings that the sidebar lists, from the top"
headings() = [item.firstchild.title for item in K.items(K.file_tree(e)) if item.firstchild isa K.EntryLabel]
"Click the icon at the start of the row of the file `name`. It opens or closes the file's group."
click_icon(name) = (r = rect(file(name).firstchild); click((r.left + 8px, r.top + r.height / 2)))

@testset "the sidebar opens the file that shows the first time it opens" begin
  sidebar!()
  @test isopen("a.md") && !isopen("b.md") && !isopen("c.md")
  @test headings() == ["a.md", "Part of a.md"]
end

@testset "another file that shows opens, and the old one closes" begin
  K.open!(e, joinpath(dir, "b.md")); frames()
  @test !isopen("a.md") && isopen("b.md")
  @test headings() == ["b.md", "Part of b.md"]
  # A link opens a file too
  K.follow!(e, "c.md"); frames()
  @test !isopen("b.md") && isopen("c.md")
end

@testset "a click on a file's name in the sidebar opens it, and closes the old one" begin
  click(file("a.md").firstchild)
  @test basename(e.buf.path) == "a.md"
  @test isopen("a.md") && !isopen("c.md")
end

@testset "a group that's closed by hand stays closed until another file shows" begin
  click_icon("a.md")
  @test !isopen("a.md")
  frames(5)
  @test !isopen("a.md")
  # Another file that's opened by its icon stays open while the file that shows doesn't change
  click_icon("c.md")
  @test isopen("c.md")
  frames(5)
  @test isopen("c.md") && basename(e.buf.path) == "a.md"
end

@testset "a file that isn't Markdown has no headings, but the old file still closes" begin
  K.open!(e, joinpath(dir, "b.md")); frames()
  @test isopen("b.md")
  K.open!(e, joinpath(dir, "tool.jl")); frames()
  @test !isopen("b.md")
  @test !(file("tool.jl") isa K.Tree.ItemGroup)
end

@testset "a file that shows while the sidebar is hidden is open when the sidebar shows" begin
  K.open!(e, joinpath(dir, "a.md")); frames()
  sidebar!()
  @test !e.panel
  K.open!(e, joinpath(dir, "b.md")); frames()
  sidebar!()
  @test isopen("b.md") && !isopen("a.md")
end

@testset "a folder that the sidebar shows again opens the file that shows" begin
  inner = mkpath(joinpath(dir, "inner"))
  write(joinpath(inner, "d.md"), "# d\n")
  K.go_folder!(e, inner); frames()
  @test basename(e.buf.path) == "b.md"
  K.go_folder!(e, dir); frames()
  @test isopen("b.md")
end

@testset "a heading or a component with changes that aren't saved has a dot" begin
  write(joinpath(dir, "parts.md"), """
  # Parts

  Words under the first heading.

  ## One

  Words under One.

  ```sheet
  Width = 3
  ```

  Words after the sheet.

  ### Inner

  Words under Inner.

  ## Two

  Words under Two.
  """)
  K.go_folder!(e, dir); K.open!(e, joinpath(dir, "parts.md")); frames()
  b = e.buf
  line(text) = findfirst(startswith(text), b.lines)
  type!(text, new) = (i = line(text); K.edit!(b, (i, 0), (i, length(b.lines[i])), new); K.touch!(e); frames())
  "The titles of the headings and the components that have a dot"
  dots() = [item.firstchild.title for item in K.items(file("parts.md"), hidden=true) if K.edited(item.firstchild)]
  @test isempty(dots())
  # A line under a heading marks that heading, and no other
  type!("Words under Two", "New words under Two.")
  @test dots() == ["Two"] && K.dirty(b)
  # A line in a component's block marks the component. A line after the block marks the heading over it.
  type!("Width = 3", "Width = 4")
  @test dots() == ["Sheet", "Two"]
  type!("Words after the sheet", "New words after the sheet.")
  @test dots() == ["One", "Sheet", "Two"]
  # A change in a group that's closed marks the heading of the group
  type!("Words under Inner", "New words under Inner.")
  @test dots() == ["One", "Sheet", "Inner", "Two"]
  K.undo!(b); K.undo!(b); K.undo!(b); frames()
  type!("Words under Inner", "New words under Inner.")
  @test dots() == ["Inner", "Two"]
  one = only(item for item in K.items(file("parts.md"), hidden=true) if item.firstchild.title == "One")
  one.collapsed = true; frames()
  @test K.edited(one.firstchild)
  one.collapsed = false; frames()
  @test !K.edited(one.firstchild)
  # A line that's taken away marks the heading that it was under
  K.undo!(b); K.undo!(b); frames()
  @test isempty(dots())
  i = line("Words under the first heading")
  K.edit!(b, (i - 1, 0), (i, length(b.lines[i])), ""); K.touch!(e); frames()
  @test dots() == ["Parts"]
  # The dots go when the page is saved
  K.save!(b); frames()
  @test isempty(dots()) && !K.dirty(b)
end

@testset "the dot beside the sidebar's button has room of its own, so the button keeps its size" begin
  e.panel && sidebar!()
  # The agents of this test are in a folder of its own. With none there, the button has no dot.
  K.Agent.place[] = mktempdir()
  K.forget_waiters!(e); frames()
  button = e.nodes[:panel]
  plain = rect(button)
  @test isempty(K.elsewhere(e)) && K.num(plain.width) == 30
  # This process stands in for an agent that waits for a page that isn't showing
  write(joinpath(dir, "waiting.md"), "# A page that an agent waits for\n")
  write(joinpath(K.Agent.folder(), "$(getpid()).wait"), realpath(joinpath(dir, "waiting.md")) * "\nClaude\n")
  K.forget_waiters!(e); frames()
  @test length(K.elsewhere(e)) == 1
  # The button is whole, and so is the dot: 30px, 4px between them, and 7px
  r = rect(button)
  @test K.num(r.width) == 41 && K.num(r.left) == K.num(plain.left)
  # The dot goes when the agent stops waiting
  rm(joinpath(K.Agent.folder(), "$(getpid()).wait"))
  K.forget_waiters!(e); frames()
  @test K.num(rect(button).width) == 30
  K.Agent.place[] = ""
end

@testset "a name too long for the sidebar stays where it is while its icon is an arrow" begin
  e.panel || sidebar!()
  long = "a-name-with-no-spaces-that-is-far-too-long-for-the-sidebar.md"
  write(joinpath(dir, long), "# Top\n\nWords.\n\n## Part\n\nMore words.\n")
  K.go_folder!(e, dir); frames()
  "Where the icon of the row of the file `name` starts, how wide it is, and where the name starts"
  parts(name) = begin
    r = rect(file(name).firstchild)
    while length(r.children) == 1; r = r.children[1]; end
    (r.children[1].left, r.children[1].width, r.children[2].left)
  end
  move(x, y) = (w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(Vec2{px}(x, y), w)); frames())
  move(890px, 690px)
  away = parts(long)
  r = rect(file(long).firstchild)
  move(r.left + 40px, r.top + r.height / 2)
  @test K.Tree.hovered(file(long))
  # The icon's box keeps its width, so the arrow doesn't pull the name to the left
  @test parts(long) == away
  # And the name starts where a short name starts
  @test away == parts("b.md")
end
