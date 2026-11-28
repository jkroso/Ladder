# Tests for a folder of notes: the pages that link to a page, under its text,
# the line over the sidebar's list, and the folder's own page. See "a folder of
# notes" in main.jl, and notes.jl. Run them with
# `julia -O0 --project=. test/notes_folder_test.jl`. They click in a window that
# isn't on the screen. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle

const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const root = joinpath(dir, "Notes")
mkpath(joinpath(root, "plans"))
mkpath(joinpath(root, ".obsidian"))   # what makes the folder a folder of notes
mkpath(joinpath(dir, "plain"))
page(rel, text) = (path = joinpath(root, rel); write(path, text); path)
const home = page("Home.md", "# Home\n\nSee [[Ideas]] and [[Garden]]. One day: [[A trip]].\n")
const ideas = page("Ideas.md", "# Ideas\n\nBack to [[Home]], and on to [[Garden]].\n")
const garden = page("plans/Garden.md", "# Garden\n\nBeds and paths.\n")
const alone = page("Alone.md", "# Alone\n")
write(joinpath(dir, "plain", "page.md"), "# A page\n\n[[Other]]\n")
write(joinpath(dir, "plain", "Other.md"), "# Other\n")

const e = K.build_editor(home)
e.panel = true   # the sidebar is open, with no slide
const w = Window(e, size=(1100px, 760px))
const (; frames, at, click, shot) = drive(w, frames=3, pressed=1, latest=true)
frames()

"The pages that the list under the text of the page that shows has, or nothing when the page has no list"
linked() = begin
  f = get(e.nodes, (:linked_from, e.buf.path), nothing)
  (f === nothing || K.page_foot(e) === nothing) && return nothing
  sort!([basename(k[2]) for k in keys(f.rows)])
end
"Forget what was read of the notes, as 2 seconds do"
again() = (empty!(K.NotesPages.NOTE_WEBS); frames())

@testset "a folder with an .obsidian in it is a folder of notes, and so is each folder in it" begin
  @test K.directory(e) isa K.NotesDirectory
  @test K.object(e, joinpath(root, "plans")) isa K.NotesDirectory
  @test K.FS.get(K.FSPath(joinpath(dir, "plain"))) isa K.FS.Directory
  @test K.NotesPages.notes_top(K.object(e, joinpath(root, "plans"))) == root
end

@testset "the pages that link to a page are listed under its text" begin
  @test linked() == ["Ideas.md"]
  f = e.nodes[(:linked_from, home)]
  r = rect(f)
  @test r !== nothing
  # The list is under the last line of the text, and as wide as the text
  @test K.num(r.width) == K.num(e.width)
  @test K.num(r.top) > 150
  shot("notes-page")
  # A click on a page of the list shows it
  click(middle(f.rows[(:from, ideas)]))
  @test e.buf.path == ideas
  @test linked() == ["Home.md"]
  K.open!(e, garden)
  frames()
  @test linked() == ["Home.md", "Ideas.md"]
end

@testset "a page that no page links to has no list, and neither has a page of a plain folder" begin
  K.open!(e, alone)
  frames()
  @test linked() === nothing
  K.open!(e, joinpath(dir, "plain", "Other.md"))
  frames()
  @test K.page_foot(e) === nothing
end

@testset "a link that's typed shows in the list of the page that it names" begin
  write(alone, "# Alone\n\nNow [[Home]] has one more.\n")
  K.open!(e, home)
  again()
  @test linked() == ["Alone.md", "Ideas.md"]
end

@testset "the line over the list says how many pages there are, and a click shows the folder's page" begin
  bar = e.nodes[:notes_bar]
  @test bar.root == root && rect(bar) !== nothing
  @test K.NotesPages.pages_words(length(K.NotesPages.notes_web(root).notes)) == "4 pages"
  click(middle(bar))
  @test e.buf.path == root && e.folder == root
  v = e.nodes[(:notes, root)]
  @test v isa K.NotesPages.NotesView && rect(v) !== nothing
  @test sort!([basename(k[2]) for k in keys(v.rows) if k[1] == :latest]) == ["Alone.md", "Garden.md", "Home.md", "Ideas.md"]
  @test [k[2] for k in keys(v.rows) if k[1] == :wanted] == ["A trip"]
  @test [basename(k[2]) for k in keys(v.rows) if k[1] == :loose] == ["Alone.md"]   # it links to a page, and no page links to it
  shot("notes-folder")
end

@testset "a click on a name with no page starts the page" begin
  v = e.nodes[(:notes, root)]
  click(middle(v.rows[(:wanted, "A trip")]))
  @test e.buf.path == joinpath(root, "A trip.md")
  @test !isfile(e.buf.path)   # its file is made when something is written in it
  K.go_back!(e)
  frames()
  click(middle(v.rows[(:latest, garden)]))
  @test e.buf.path == garden
end

@testset "a window that's opened on a folder of notes shows the folder's page" begin
  other = K.build_editor(root)
  @test other.buf.path == root
end

close(w)
