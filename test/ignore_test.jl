# Tests for the files and folders that you ignore. Ladder leaves them out, as
# it leaves out the hidden ones, and remembers them. See "what you ignore" in
# folders.jl, and `ignore!` in main.jl. Run them with
# `julia -O0 --project=. test/ignore_test.jl`. They right-click and press keys
# in a window that isn't on the screen, so the menu is the one that Ladder
# draws. What they ignore goes to a file of their own, never to Ladder's.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use GeometryBasics: Vec2

const px = K.px
const H = K.Folders

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
H.FILE[] = joinpath(dir, "home-list")

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
frames(n=2) = foreach(_ -> frame(w), 1:n)
e.panel || K.toggle_panel!(e)
frames(3)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames())
middle(r) = (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2)
right_click(place) = (at(place); onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames())
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())

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

@testset "the list of what you ignore is kept in its file, beside the favourites" begin
  @test isempty(H.ignored()) && !H.isignored(movies)
  H.favourite!(dirname(music))
  H.ignore!(movies * "/"); H.ignore!(movies)
  @test H.ignored() == Set([movies]) && H.isignored(movies) && H.isignored(movies * "/")
  @test H.favourites() == [dirname(music)] && !H.isignored(dirname(music))
  @test read(H.file(), String) == "favourite\t$(dirname(music))\nignored\t$movies\n"
  # Another window of Ladder reads the same file
  H.READ[] = (-1.0, H.Kept())
  @test H.isignored(movies) && H.favourites() == [dirname(music)]
  # Another window writes it
  before = H.changed()
  sleep(0.01)
  write(H.file(), "favourite\t$(dirname(music))\nignored\t$junk\n")
  @test H.ignored() == Set([junk]) && H.changed() > before
  H.unignore!(junk); H.unfavourite!(dirname(music))
  @test isempty(H.ignored()) && read(H.file(), String) == ""
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

@testset "the code of the settings page reads what you ignore, and shows it again" begin
  m = K.sandbox(e)
  @test Base.invokelatest(m.ignored_files) == [junk]
  H.ignore!(movies)
  @test Base.invokelatest(m.ignored_files) == [junk, movies]   # in the order of their names
  Base.invokelatest(m.stop_ignoring!, junk)
  frames()
  @test !H.isignored(junk) && "junk.txt" in listed()
end

"The first node of type `T` in `node`, or in the nodes it holds"
find(T, node, seen=IdDict()) = begin
  node isa T && return node
  (isbits(node) || node isa Union{AbstractString,Module,Function,Type} || haskey(seen, node)) && return nothing
  seen[node] = true
  if node isa Union{AbstractArray,Tuple,AbstractDict}
    for x in values(node)
      (f = find(T, x, seen)) === nothing || return f
    end
    return nothing
  end
  for name in fieldnames(typeof(node))
    isdefined(node, name) || continue
    (f = find(T, getfield(node, name), seen)) === nothing || return f
  end
  nothing
end

@testset "the part of the settings page that lists what you ignore" begin
  page = K.settings_page()
  code = String(only(m[1] for m in eachmatch(r"## Ignored files\n\n```ui\n(.*?)```"s, read(page, String))))
  s = K.build_editor(page)
  sw = Window(s, size=(720px, 2600px))
  empty!(K.problems)
  foreach(_ -> frame(sw), 1:3)
  @test isempty(K.problems)
  @test H.ignored() == Set([movies])
  node = K.evaluate(s, code)
  @test find(K.Text, node).content == Base.Filesystem.contractuser(movies)
  b = find(include_string(K.sandbox(s), "Button"), node)
  @test b.label == "Stop Ignoring"
  b.onclick(b)
  @test !H.isignored(movies)
  @test find(K.Text, K.evaluate(s, code)).content == "You don't ignore any files or folders."
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
