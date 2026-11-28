# Tests for the files and folders that you ignore. Ladder leaves them out, as
# it leaves out the hidden ones, and remembers them. See "what you ignore" in
# folders.jl, and `ignore!` in main.jl. Run them with
# `julia -O0 --project=. test/ignore_test.jl`. They right-click and press keys
# in a window that isn't on the screen, so the menu is the one that Ladder
# draws. What they ignore goes to a page of their own, never to Ladder's.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use GeometryBasics: Vec2
@use "./drive" drive middle

const px = K.px
const H = K.Folders

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
H.FILE[] = joinpath(dir, "home-list")
const named = H.page()   # the page that Ladder names, before the tests name their own
H.PAGE[] = joinpath(dir, "settings-pages", "ignored-files.md")

# A folder with a page, two folders that Sam never looks at, a file and a hidden folder
const top = mkpath(joinpath(dir, "sam"))
made(rel, text="some text") = (path = joinpath(top, rel); mkpath(dirname(path)); write(path, text); path)
const page = made("notes.md", "# Notes\n\nSee [[Plan]].\n")
const movies = mkpath(joinpath(top, "Movies"))
const plan = made("Movies/Plan.md", "# Plan\n")
mkpath(joinpath(movies, "clip", ".git"))   # a git repository, which ⌘P would list
const music = made("Music/song.md", "# Song\n")
const junk = made("junk.txt")
made(".cache/x")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const (; frames, at, key) = drive(w, moved=2)
e.panel || K.toggle_panel!(e)
e.slid = 0.0   # the sidebar is open at once: the rows of a sidebar that still slides aren't where they come to rest
frames(3)

right_click(place) = (at(place); onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames())

"The names that the sidebar's tree lists, from the top"
listed() = [basename(i.firstchild.path) for i in K.file_tree(e).children]
"The row of the folder or file `name` in the sidebar"
row(name) = only(i for i in K.file_tree(e).children if basename(i.firstchild.path) == name).firstchild
"The menu that Ladder drew, or nothing"
menu() = (ps = [p for p in popups(w) if p.key == :menu]; isempty(ps) ? nothing : only(ps).content)
"Choose the item called `name` in the menu that Ladder drew, with ↓ and Return"
choose(name) = (foreach(_ -> key(Keys.down), 1:findfirst(==(name), menu().items)); key(Keys.enter))
"Right-click `name` in the sidebar and choose `item` from its menu"
row_menu(name, item) = (right_click(middle(rect(row(name)))); choose(item))

"The lines of the page that lists what you ignore"
page_lines() = readlines(H.page())

@testset "the list of what you ignore is a page of the settings" begin
  @test named == K.settings_page("ignored-files.md")
  @test isempty(H.ignored()) && !H.isignored(movies)
  @test !isfile(H.page())   # reading the list writes no page
  H.favourite!(dirname(music))
  H.ignore!(movies * "/"); H.ignore!(movies)
  @test H.ignored() == Set([movies]) && H.isignored(movies) && H.isignored(movies * "/")
  @test H.favourites() == [dirname(music)] && !H.isignored(dirname(music))
  # The page says what it's for, then has a line for each path
  @test page_lines()[1] == "# Ignored files"
  @test page_lines()[end-1:end] == ["", "- $movies"]
  @test read(H.file(), String) == "favourite\t$(dirname(music))\n"
  # A path in the home folder is written from ~
  @test H.item(joinpath(homedir(), "Movies")) == "- ~/Movies"
  @test H.listed("- ~/Movies") == joinpath(homedir(), "Movies") && H.listed("* `~/Movies`") == joinpath(homedir(), "Movies")
  @test H.listed("Ladder leaves out the files") === nothing && H.listed("- [Settings](settings.md)") === nothing
  # Another window of Ladder reads the same page
  H.LISTED[] = ("", -1.0, Set{String}())
  @test H.isignored(movies)
  # The new line goes under the last one, and the others stay as they were
  H.ignore!(junk)
  @test page_lines()[end-2:end] == ["", "- $movies", "- $junk"]
  H.unignore!(movies)
  @test page_lines()[end-1:end] == ["", "- $junk"] && page_lines()[1] == "# Ignored files"
  H.unignore!(junk); H.unfavourite!(dirname(music))
  @test isempty(H.ignored()) && read(H.file(), String) == ""
end

@testset "you change the list as you change any page" begin
  before = H.changed()
  sleep(0.01)
  open(io -> println(io, "- ", movies, "\n- `", junk, "`\nA line of words isn't a path."), H.page(), "a")
  @test H.ignored() == Set([movies, junk]) && H.changed() > before
  H.relist!(filter(l -> H.listed(l) === nothing, page_lines()))
  @test isempty(H.ignored()) && "A line of words isn't a path." in page_lines()
  H.relist!(filter(!=("A line of words isn't a path."), page_lines()))
end

@testset "the first page has what the file of the favourites kept before" begin
  was = H.PAGE[]
  H.PAGE[] = joinpath(dir, "first", "ignored-files.md")
  write(H.file(), "ignored\t$music\nignored\t$junk\nfavourite\t$top\n")
  H.READ[] = (-1.0, H.Kept())
  @test H.ignored() == Set([junk, music])
  @test page_lines()[1] == "# Ignored files" && page_lines()[end-1:end] == ["- $junk", "- $music"]
  # The file keeps them, so another copy of Ladder can start its own page from them
  @test occursin("ignored\t$junk", read(H.file(), String))
  # With no page and nothing kept, Ladder writes a page only when it starts
  H.PAGE[] = joinpath(dir, "empty", "ignored-files.md")
  write(H.file(), "")
  @test isempty(H.ignored()) && !isfile(H.page())
  @test H.page!() == H.PAGE[] && page_lines()[1] == "# Ignored files" && isempty(H.ignored())
  H.PAGE[] = was
  H.READ[] = (-1.0, H.Kept())
end

@testset "Ignore in the menu of a folder leaves it out of the sidebar" begin
  @test listed() == ["Movies", "Music", "junk.txt", "notes.md"]
  right_click(middle(rect(row("Movies"))))
  @test "Ignore" in menu().items && !("Stop Ignoring" in menu().items)
  choose("Ignore")
  @test H.isignored(movies)
  @test listed() == ["Music", "junk.txt", "notes.md"]
end

@testset "a file is ignored the same way" begin
  row_menu("junk.txt", "Ignore")
  @test H.isignored(junk)
  @test listed() == ["Music", "notes.md"]
end

@testset "the eye shows what you ignore, faint, and its menu shows it again" begin
  K.hidden!(e, true); frames()
  @test listed() == [".cache", "Movies", "Music", "junk.txt", "notes.md"]
  @test K.ignored_shown(e, movies) && !K.ignored_shown(e, dirname(music))
  right_click(middle(rect(row("Movies"))))
  @test "Stop Ignoring" in menu().items && !("Ignore" in menu().items)
  choose("Stop Ignoring")
  @test !H.isignored(movies) && !K.ignored_shown(e, movies)
  K.hidden!(e, false); frames()
  @test listed() == ["Movies", "Music", "notes.md"]
  @test !K.ignored_shown(e, junk)   # with the eye shut, a row's colour needs no look at the list
end

@testset "the other lists of a folder leave it out too" begin
  H.ignore!(movies)
  # The list of a › in the top bar's path, and the path's own list of the folder
  names, _ = K.title_listing(e, top)
  @test names == ["Music", "notes.md"]
  @test K.listing(top) == ["Music", "notes.md"]
  # The table of the folder's page lists what the sidebar lists
  @test [o.path.name for o in K.entries(e, K.directory(e))] == ["Music", "notes.md"]
  e.hidden = true
  @test first(K.title_listing(e, top)) == [".cache", "Movies", "Music", "junk.txt", "notes.md"]
  e.hidden = false
end

@testset "the searches don't look in it" begin
  @test H.repositories(top) == []
  @test K.find_named(top, ["Plan.md"]) === nothing
  @test K.pages_under(top)[1] == [page, music]
  @test K.Notes.pages(top) == [page, music]
  H.unignore!(movies)
  @test H.repositories(top) == [joinpath(movies, "clip")]
  @test K.find_named(top, ["Plan.md"]) == plan
  @test K.pages_under(top)[1] == [page, plan, music]
end

@testset "a line deleted from the page shows its file again in every window" begin
  @test H.ignored() == Set([junk]) && !("junk.txt" in listed())
  # The page is open in a window, where you delete the line and save the page
  s = K.build_editor(H.page())
  sw = Window(s, size=(720px, 600px))
  frame(sw)
  i = findfirst(==("- $junk"), s.buf.lines)
  s.buf.lines = [s.buf.lines[1:i-1]; s.buf.lines[i+1:end]]
  K.save!(s.buf)
  frame(sw)
  @test isempty(H.ignored())
  frames()
  @test "junk.txt" in listed()
  close(sw)
end

@testset "the Settings page links to the list" begin
  text = read(K.settings_page(), String)
  section = only(m[1] for m in eachmatch(r"## Ignored files\n\n(.*?)\n## "s, text))
  @test !occursin("```", section) && occursin("[Ignored files](ignored-files.md)", section)
  @test occursin("- [Ignored files](ignored-files.md)", text)
  s = K.build_editor(K.settings_page())
  sw = Window(s, size=(720px, 2600px))
  empty!(K.problems)
  foreach(_ -> frame(sw), 1:3)
  @test isempty(K.problems)
  close(sw)
end

@testset "a page that isn't on the disk yet can't be ignored" begin
  ghost = joinpath(top, "ghost.md")
  K.file_menu!(e, w, ghost)
  frames()
  # Ladder's drawn menu leaves out the items that are off
  @test !("Ignore" in menu().items)
  key(Keys.escape)
end
