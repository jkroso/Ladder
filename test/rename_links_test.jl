# Tests that the links to a file follow it when it gets a new name or moves,
# as in Obsidian. See "links that follow a rename" in main.jl. Run them with
# `julia -O0 --project=. test/rename_links_test.jl`. They use a window that
# isn't on the screen, and a project of their own in a folder for tests.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

@testset "the links in a page's lines that name a file" begin
  line = "See [[A]], [[B|words]], [[ C #Head]] and ![[d.png]], [e](e.md#x), ![f](f%20g.png) and [w](https://x.org)"
  found = K.named_links([line])
  @test [(n, wiki) for (_, _, _, n, wiki) in found] == [("A", true), ("B", true), ("C", true), ("d.png", true), ("e.md", false), ("f%20g.png", false)]
  # The columns are those of the name, so a new name goes in its place
  changes = [(i, from, to, uppercase(n) * "2") for (i, from, to, n, _) in found]
  @test only(K.with_names([line], changes)) == "See [[A2]], [[B2|words]], [[ C2 #Head]] and ![[D.PNG2]], [e](E.MD2#x), ![f](F%20G.PNG2) and [w](https://x.org)"
  # Code, a link to a heading of the same page, a footnote and a bracket after a \ aren't links to a file
  @test isempty(K.named_links(["`[[A]]` and [[#Head]] and [^1] and \\[[B]] and [x](#here)"]))
  @test isempty(K.named_links(["```", "[[A]] and [a](a.md)", "```"]))
  # A table writes the | of a wiki link as \|
  @test [n for (_, _, _, n, _) in K.named_links(["| [[A\\|words]] | x |"])] == ["A"]
  # A place after a name moves with the name's end, and a place inside it goes to the new name's end
  @test K.caret_after((1, 10), [(1, 2, 5, "abcdef")]) == (1, 13)
  @test K.caret_after((1, 4), [(1, 2, 5, "abcdef")]) == (1, 8)
  @test K.caret_after((1, 1), [(1, 2, 5, "abcdef")]) == (1, 1)
  @test K.caret_after((2, 10), [(1, 2, 5, "abcdef")]) == (2, 10)
end

const dir = realpath(mktempdir())
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const top = joinpath(dir, "project")
mkpath(joinpath(top, ".git"))
mkpath(joinpath(top, "notes", "sub"))
mkpath(joinpath(top, "other"))

const home_text = """
# Home

See [[Ideas]], [[Ideas|my ideas]], [[Ideas#Big step]] and ![[Ideas]].
A path: [the ideas](notes/Ideas.md) and [a step](notes/Ideas.md#big-step).
With folders: [[notes/Ideas]], and [[ideas]] in small letters.
In code: `[[Ideas]]` stays, and \\[[Ideas]] isn't a link.
A picture: ![a plan](notes/plan.png) and [[plan.png]].
Deep: [deep](notes/sub/deep.md) and [[sub/deep]].
A plan: [[My Plan]] and [plan](My%20Plan.md).
Not a page yet: [[Untitled]].

```
[[Ideas]] in a code block stays
```

| Link | Note |
|------|------|
| [[Ideas\\|in a table]] | x |
"""
write(joinpath(top, "home.md"), home_text)
write(joinpath(top, "notes", "Ideas.md"), "# Ideas\n\nSee [[#Big step]] and [[Ideas#Big step]].\n\n## Big step\n")
write(joinpath(top, "notes", "plan.png"), "not really a picture")
write(joinpath(top, "notes", "sub", "deep.md"), "# Deep\n\n[up](../Ideas.md) and [[Ideas]].\n")
write(joinpath(top, "other", "Ideas.md"), "# Other ideas\n")
const other_text = "# Other\n\n[[Ideas]] is the page beside this one.\n"
write(joinpath(top, "other", "page.md"), other_text)
write(joinpath(top, "My Plan.md"), "# My plan\n")
write(joinpath(top, "plain.md"), "# Plain\n")

const home = joinpath(top, "home.md")
const e = K.build_editor(home)
const w = Window(e, size=(900px, 700px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()

"The line of the page at `path` that starts with `start`, as the file has it"
file_line(path, start) = first(l for l in split(read(path, String), '\n') if startswith(l, start))
"The line of the open page that starts with `start`"
open_line(b, start) = first(l for l in b.lines if startswith(l, start))
said() = (r = get(e.nodes, :result, nothing); r === nothing ? "" : r[1])

"Give the file or the folder at `path` the name `name`, as the text field of the sidebar does"
rename_to!(path, name) = begin
  K.rename!(e, path)
  K.renamer(e).text = name
  @test K.finish_rename!(e)
  K.stop_rename!(e)
  frames()
end

@testset "a page's new name goes into each link to it, in files and in open pages" begin
  # The deep page is open but doesn't show, and has no changes
  K.open!(e, joinpath(top, "notes", "sub", "deep.md")); frames()
  K.open!(e, home); frames()
  b = e.buf
  # The page that shows has a change that isn't saved, with a link in it
  K.edit!(b, (length(b.lines), 0), (length(b.lines), 0), "Unsaved words, [[Ideas]].")
  at = length("See [[Ideas]], [[Ideas|my ideas]]")
  b.caret = b.anchor = (3, at)
  rename_to!(joinpath(top, "notes", "Ideas.md"), "Thoughts")
  @test isfile(joinpath(top, "notes", "Thoughts.md")) && !isfile(joinpath(top, "notes", "Ideas.md"))
  @test e.buf === b && b.path == home
  @test b.lines[3] == "See [[Thoughts]], [[Thoughts|my ideas]], [[Thoughts#Big step]] and ![[Thoughts]]."
  @test b.lines[4] == "A path: [the ideas](notes/Thoughts.md) and [a step](notes/Thoughts.md#big-step)."
  @test b.lines[5] == "With folders: [[notes/Thoughts]], and [[Thoughts]] in small letters."
  # Code, and a bracket after a \, stay as they are
  @test b.lines[6] == "In code: `[[Ideas]]` stays, and \\[[Ideas]] isn't a link."
  @test open_line(b, "[[Ideas]] in a code block") == "[[Ideas]] in a code block stays"
  @test open_line(b, "| [[") == "| [[Thoughts\\|in a table]] | x |"
  # The change that isn't saved gets the new name, and is still not saved
  @test b.lines[end] == "Unsaved words, [[Thoughts]]."
  @test K.dirty(b)
  # The caret stays after the same link
  @test b.caret == (3, length("See [[Thoughts]], [[Thoughts|my ideas]]")) && b.anchor == b.caret
  # The file has the new names, and not the change that isn't saved
  saved = read(home, String)
  @test occursin("See [[Thoughts]], [[Thoughts|my ideas]]", saved) && !occursin("Unsaved", saved)
  @test occursin("| [[Thoughts\\|in a table]] | x |", saved) && occursin("`[[Ideas]]` stays", saved)
  # The page knows the file's new text, so it doesn't take the file's change in again
  @test K.refresh!(b) === nothing && b.lines[end] == "Unsaved words, [[Thoughts]]."
  # ⌘Z in the page takes the change back there
  K.undo!(b)
  @test b.lines[3] == "See [[Ideas]], [[Ideas|my ideas]], [[Ideas#Big step]] and ![[Ideas]]."
  K.redo!(b)
  @test b.lines[3] == "See [[Thoughts]], [[Thoughts|my ideas]], [[Thoughts#Big step]] and ![[Thoughts]]."
  # The page that was renamed links to itself by its new name
  @test file_line(joinpath(top, "notes", "Thoughts.md"), "See") == "See [[#Big step]] and [[Thoughts#Big step]]."
  # A page that's open and has no changes changes in the window and in its file, and has nothing to save
  deep = e.buffers[joinpath(top, "notes", "sub", "deep.md")]
  @test deep.lines[3] == "[up](../Thoughts.md) and [[Thoughts]]."
  @test !K.dirty(deep) && file_line(deep.path, "[up]") == "[up](../Thoughts.md) and [[Thoughts]]."
  # A link to another page with the same name stays
  @test read(joinpath(top, "other", "page.md"), String) == other_text
  # Ten links of the page that shows, one of the page that was renamed and two of the deep page
  @test said() == "Changed 13 links in 3 pages to the new name"
end

@testset "a page that moves to another folder keeps its links, and the links to it follow" begin
  delete!(e.nodes, :result)
  K.move!(e, joinpath(top, "notes", "sub", "deep.md"), joinpath(top, "deep.md")); frames()
  deep = e.buffers[joinpath(top, "deep.md")]
  # Its own link to a file is from its new folder, and its wiki link still finds the page
  @test deep.lines[3] == "[up](notes/Thoughts.md) and [[Thoughts]]."
  @test file_line(joinpath(top, "deep.md"), "[up]") == "[up](notes/Thoughts.md) and [[Thoughts]]."
  @test e.buf.lines[8] == "Deep: [deep](deep.md) and [[deep]]."
  @test said() == "Changed 3 links in 2 pages to the new place"
  # A page that moves beside another page with the name that its link has gets the folder of the page that it meant
  mkpath(joinpath(top, "x")); mkpath(joinpath(top, "y"))
  write(joinpath(top, "x", "Plan.md"), "# The plan of x\n")
  write(joinpath(top, "y", "Plan.md"), "# The plan of y\n")
  write(joinpath(top, "x", "a.md"), "# A\n\nSee [[Plan]] and [[Missing]].\n")
  delete!(e.nodes, :result)
  K.move!(e, joinpath(top, "x", "a.md"), joinpath(top, "y", "a.md")); frames()
  @test file_line(joinpath(top, "y", "a.md"), "See") == "See [[x/Plan]] and [[Missing]]."
  @test said() == "Changed 1 link in 1 page to the new place"
end

@testset "a folder's new name goes into the paths and the names with folders that go through it" begin
  delete!(e.nodes, :result)
  rename_to!(joinpath(top, "notes"), "thinking")
  b = e.buf
  @test b.lines[3] == "See [[Thoughts]], [[Thoughts|my ideas]], [[Thoughts#Big step]] and ![[Thoughts]]."
  @test b.lines[4] == "A path: [the ideas](thinking/Thoughts.md) and [a step](thinking/Thoughts.md#big-step)."
  @test b.lines[5] == "With folders: [[thinking/Thoughts]], and [[Thoughts]] in small letters."
  @test b.lines[7] == "A picture: ![a plan](thinking/plan.png) and [[plan.png]]."
  @test file_line(joinpath(top, "deep.md"), "[up]") == "[up](thinking/Thoughts.md) and [[Thoughts]]."
  @test said() == "Changed 5 links in 2 pages to the new name"
end

@testset "a file that isn't a page, and a name with spaces" begin
  delete!(e.nodes, :result)
  # The field keeps the file's ending when the name is typed without it
  rename_to!(joinpath(top, "thinking", "plan.png"), "drawing")
  @test e.buf.lines[7] == "A picture: ![a plan](thinking/drawing.png) and [[drawing.png]]."
  @test said() == "Changed 2 links in 1 page to the new name"
  rename_to!(joinpath(top, "My Plan.md"), "Our Plan")
  @test e.buf.lines[9] == "A plan: [[Our Plan]] and [plan](Our%20Plan.md)."
end

@testset "a new name that's only other capitals" begin
  rename_to!(joinpath(top, "thinking", "Thoughts.md"), "thoughts")
  @test "thoughts.md" in readdir(joinpath(top, "thinking"))
  @test e.buf.lines[3] == "See [[thoughts]], [[thoughts|my ideas]], [[thoughts#Big step]] and ![[thoughts]]."
  @test e.buf.lines[4] == "A path: [the ideas](thinking/thoughts.md) and [a step](thinking/thoughts.md#big-step)."
end

@testset "no link changes, and no note, when nothing links to the file" begin
  delete!(e.nodes, :result)
  rename_to!(joinpath(top, "plain.md"), "flat")
  @test isfile(joinpath(top, "flat.md")) && said() == ""
  # A new page that's named as it's made takes no links: pages can link to the name Untitled before it's there
  K.new_page!(e, top); frames()
  K.renamer(e).text = "Garden"
  @test K.finish_rename!(e)
  K.stop_rename!(e)
  @test isfile(joinpath(top, "Garden.md"))
  @test file_line(home, "Not a page") == "Not a page yet: [[Untitled]]."
  @test said() == ""
end
