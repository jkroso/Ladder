# Tests for a kind of folder in the sidebar: a type under `AbstractDirectory`
# that code gives to a folder, with methods that say how the sidebar shows
# that folder, and how the page shows it. See the comment over `list_files!` in windows.jl. Run them with
# `julia -O0 --project=. test/folder_kind_test.jl`. They draw a window that
# isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "./drive" drive
const px = K.px
const FS = K.FS

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const notes = joinpath(dir, "notes")
mkpath(joinpath(notes, "old"))
mkpath(joinpath(notes, "attic"))
mkpath(joinpath(dir, "plain"))
write(joinpath(notes, "one.md"), "# One\n")
write(joinpath(notes, "two.md"), "# Two\n")
write(joinpath(notes, "list.csv"), "a,b\n1,2\n")
write(joinpath(dir, "page.md"), "# A page\n")

# A kind of folder, as code from the startup page would make it. Its folders
# are of the kind too, and each of its Markdown files is a note.
@def struct NotesDirectory <: K.AbstractDirectory end
FS.kind(::NotesDirectory, path::FSPath) = NotesDirectory
FS.child(d::NotesDirectory, name::AbstractString) =
  endswith(name, ".md") ? FS.File{:note}(d.path * name, d) : invoke(FS.child, Tuple{K.AbstractDirectory,AbstractString}, d, name)
# How the sidebar shows it
K.entries(e, d::NotesDirectory) = filter(o -> o.path.name != "attic", invoke(K.entries, Tuple{Any,K.AbstractDirectory}, e, d))
K.folder_view(e, d::NotesDirectory) = (list=nothing, bar=K.Box(K.Text("My notes", size=12px)))
const asked = Ref(0)   # how many times a row asked for the icon of a folder of notes
K.entry_icon(::NotesDirectory) = (asked[] += 1; "box")
K.entry_marks(e, d::NotesDirectory) = (K.Box(K.Text("$(count(isfile, K.entries(e, d))) in here", size=11px)),)
K.entry_marks(e, f::FS.File{:note}) = (K.Box(K.Text("a note", size=11px)),)
const clicks = String[]
K.open!(e, d::NotesDirectory; record=true) = (push!(clicks, d.path.name); K.go_folder!(e, string(d.path)))

const e = K.build_editor(joinpath(dir, "page.md"))
const w = Window(e, size=(1000px, 700px))
const (; frames) = drive(w, frames=3)
e.panel || K.toggle_panel!(e)
frames()

"Each Text in the layout `node`, in the order they read"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
side() = texts(K.describe(e.nodes[:sidebar]))
"The item of the folder or file `name` in the sidebar's tree"
item(name) = only(i for i in K.file_tree(e).children if basename(i.firstchild.path) == name)
"The names that the sidebar's tree lists, from the top"
listed() = [basename(i.firstchild.path) for i in K.file_tree(e).children]
"The name of the icon of the folder or file `name` in the sidebar's folder"
icon(name) = K.entry_icon(K.object(e, joinpath(e.folder, name)))

@testset "a folder and a file are objects, which the folder at / made on the way down" begin
  @test listed() == ["notes", "plain", "page.md"] == basename.(e.listed)
  @test K.directory(e) isa FS.Directory && string(K.directory(e).path) == dir
  @test K.object(e, notes) isa FS.Directory && K.object(e, joinpath(dir, "page.md")) isa FS.File{:md}
  @test K.object(e, notes).parent === K.directory(e)
  top(o) = o.parent === nothing ? o : top(o.parent)
  @test top(K.object(e, notes)) == FS.root()
  # one that the sidebar doesn't list has an object too, and what isn't there has none
  @test K.object(e, joinpath(notes, "one.md")) isa FS.File{:md} && K.object(e, joinpath(dir, "nothing.md")) === nothing
  @test e.files == [joinpath(dir, "page.md")]
end

@testset "a folder with no kind shows as it did" begin
  @test icon("notes") == "folder" && icon("plain") == "folder" && icon("page.md") == "file-earmark-text"
  @test !any(t -> occursin("in here", t), side()) && !("My notes" in side())
  @test K.folder_view(e, K.directory(e)) == (list=nothing, bar=nothing) && K.hidden_button(e) != ()
end

@testset "a kind of folder has its own icon and its own words after its name" begin
  FS.kinds[FSPath(notes)] = NotesDirectory
  K.list_files!(e); frames()
  @test K.object(e, notes) isa NotesDirectory
  @test icon("notes") == "box" && icon("plain") == "folder"
  # the row of the folder asks for that icon when it's drawn
  asked[] = 0; frames(1)
  @test asked[] > 0
  # the folder lists what its own `entries` gives: not the attic
  @test "2 in here" ∉ side() && "3 in here" in side()
end

@testset "a click on it does what its `open!` says, and it lists itself its own way" begin
  K.choose!(e, item("notes")); frames()
  @test clicks == ["notes"] && e.folder == notes
  @test K.directory(e) isa NotesDirectory
  @test listed() == ["old", "list.csv", "one.md", "two.md"]
  @test "My notes" in side()
  # a folder in it is of the kind too, because the kind says so
  @test K.object(e, joinpath(notes, "old")) isa NotesDirectory && icon("old") == "box"
  # the kind chose the type of its Markdown files, and a function has a method for that type
  @test K.object(e, joinpath(notes, "one.md")) isa FS.File{:note} && K.object(e, joinpath(notes, "list.csv")) isa FS.File{:csv}
  @test count(==("a note"), side()) == 2
  @test e.files == [joinpath(notes, "one.md"), joinpath(notes, "two.md")]
end

@testset "a click on a file in it shows the file in the page" begin
  K.choose!(e, item("two.md")); frames()
  @test e.buf.path == joinpath(notes, "two.md") && e.folder == notes
  K.choose!(e, item("old")); frames()
  @test clicks == ["notes", "old"] && e.folder == joinpath(notes, "old") && isempty(listed())
end

@testset "a kind of folder shows itself, and a file that it holds, in the page" begin
  K.go_folder!(e, dir); K.open!(e, joinpath(dir, "page.md")); frames()
  # Without a method of `page_view`, a file shows as it did, and the page is as wide as a page's text
  @test K.page_view(e, K.object(e, notes)) === nothing && !K.own_page(e)
  narrow = e.width
  # The kind shows its folder as a line of words, as wide as the window, and its CSV files as words too
  K.page_view(e, d::NotesDirectory) = K.Box(K.Text("The notes of $(d.path.name)", size=14px))
  K.page_view(e, f::FS.File{:csv}) = f.parent isa NotesDirectory ? K.Box(K.Text("A list of notes", size=14px)) : nothing
  K.page_fills(e, ::NotesDirectory) = true
  page() = texts(K.describe(e.nodes[(:fileview, e.buf.path)]))
  K.open!(e, notes); frames()
  # The folder is what the page shows, and the sidebar lists the folder itself, so its path ends where the top bar's does
  @test e.buf.path == notes && e.buf.view == :file && e.folder == notes
  @test page() == ["The notes of notes"]
  @test K.page_object(e) isa NotesDirectory
  @test K.own_page(e)
  @test e.width >= narrow && e.width == K.text_width(e)
  @test K.file_views(e.buf) == ()
  # A file of the kind shows the kind's way, and the same kind of file in a plain folder shows as it did
  K.open!(e, joinpath(notes, "list.csv")); frames()
  @test page() == ["A list of notes"] && !K.own_page(e)
  write(joinpath(dir, "plain", "list.csv"), "a,b\n1,2\n")
  K.open!(e, joinpath(dir, "plain", "list.csv")); frames()
  @test page() != ["A list of notes"]
  # Going back shows the folder again
  K.go_back!(e); K.go_back!(e); frames()
  @test e.buf.path == notes && page() == ["The notes of notes"]
  # A link to a folder does what a click on the folder does. This kind's `open!` only lists it in the
  # sidebar, so the page shows the folder too.
  empty!(clicks)
  K.open!(e, joinpath(dir, "page.md")); K.follow!(e, notes); frames()
  @test clicks == ["notes"] && e.folder == notes && e.buf.path == notes
  # A folder with no kind that's opened as a page shows what's in it
  K.open!(e, joinpath(dir, "plain")); frames()
  @test page()[1] == "plain" && "list.csv" in page()
  K.go_folder!(e, dir); K.open!(e, joinpath(dir, "page.md")); frames()
end

@testset "a folder that loses its kind is plain again" begin
  K.go_folder!(e, dir); frames()
  @test "3 in here" in side()
  delete!(FS.kinds, FSPath(notes))
  K.list_files!(e); frames()
  @test K.object(e, notes) isa FS.Directory && icon("notes") == "folder" && !any(t -> occursin("in here", t), side())
end
