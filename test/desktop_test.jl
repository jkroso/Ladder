# Tests for a folder that shows as a desktop: icons on a wallpaper. See "a
# folder that's a desktop" in main.jl, and desktop.jl. Run them with
# `julia -O0 --project=. test/desktop_test.jl`. They click, drag and press keys
# in a window that isn't on the screen, so each menu is one that Ladder draws.
# With `LADDER_SHOTS` set to a folder, they save pictures of the window there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

const px = K.px
const D = K.Desks

const dir = mktempdir()
# What these tests keep goes to files of their own, not to the ones that Ladder uses
K.SETTINGS_FILE[] = joinpath(dir, "settings")
# What goes to the Trash here is only removed
const trashed = String[]
K.trasher[] = path -> (push!(trashed, path); rm(path; recursive=true); true)

# The desktop looks the same on each Mac that runs the tests: the usual icons, sorted by kind, with no wallpaper
const finder = Ref(D.Look(order=:kind))
D.looker[] = () -> finder[]
D.papers[] = () -> ""
K.FINDER_LOOK[] = (0.0, D.Look())
K.WALLPAPER[] = (0.0, "", nothing)

const desk = joinpath(dir, "Desk")
mkpath(joinpath(desk, "Projects"))
mkpath(joinpath(desk, "Archive"))
write(joinpath(desk, "notes.md"), "# Notes\n\nSome words.\n")
write(joinpath(desk, "A very long name for a plan of the house.md"), "# Plan\n")
write(joinpath(desk, ".hidden.md"), "# Hidden\n")
write(joinpath(dir, "page.md"), "# A page\n\n[The desktop](Desk)\n")
# The folder's own page makes it a desktop
write(joinpath(desk, ".ladder"), "This folder is a desktop.\n\n```julia\nLadder.DesktopDirectory\n```\n")

const e = K.build_editor(joinpath(dir, "page.md"))
e.remember = true   # the places of the icons are written, to the folder of these tests
const w = Window(e, size=(1100px, 760px))
# Each frame is drawn with the newest code, as the window's loop draws it: the folder's page ran in an earlier frame
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "desktop-$name.png"), w)
view() = e.nodes[(:desktop, desk)]
"Where the middle of the icon `name` is in the window"
icon(name) = (r = rect(view()); s = view().spots[name]; (K.num(r.left) + s[1], K.num(r.top) + s[2]))
"A place on the wallpaper that no icon in a cell of the grid covers: it's between four cells"
empty_spot(x=245.0, y=325.0) = (r = rect(view()); (K.num(r.left) + x, K.num(r.top) + y))
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
# The window keeps the buttons that are down, as the real mouse makes it do
down(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1))
up() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(1))
click(place) = (down(place); up())
drag(from, to) = begin
  down(from)
  foreach(t -> at(from .+ (to .- from) .* t), (0.3, 0.6, 1.0))
  up()
end
right_click(place) = (at(place); onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames())
key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
"The menu that Ladder drew, or nothing"
menu() = (ps = [p for p in popups(w) if p.key == :menu]; isempty(ps) ? nothing : only(ps).content)
"Choose the item called `name` in the menu that Ladder drew, with ↓ and Return"
choose(name) = begin
  m = menu()
  foreach(_ -> key(Keys.down), 1:findfirst(==(name), m.items))
  key(Keys.enter)
end
chosen() = sort!(collect(view().chosen))
kept() = K.desktop_kept(desk)

@testset "the grid starts at the top right and goes down, then left" begin
  l = D.Look()
  g = D.grid((1000.0, 500.0), l)
  @test D.cell(l) == (124.0, 112.0)   # as the Finder's desktop, with icons of 64 and a space of 54
  @test g.rows == 4
  @test D.spot(g, 1) == (1000.0 - 5 - 62, 12.0 + 32)
  @test D.spot(g, 2) == D.spot(g, 1) .+ (0.0, 112.0)
  @test D.spot(g, 5) == D.spot(g, 1) .- (124.0, 0.0)
  @test D.nearest(g, D.spot(g, 6) .+ (20.0, -30.0)) == D.spot(g, 6)
  @test D.free(g, [D.spot(g, 1), D.spot(g, 2)]) == D.spot(g, 3)
end

@testset "names sort as the Finder sorts them" begin
  @test sort(["Plan 10", "plan 2", "Alpha", "3D"], by=D.name_key) == ["3D", "Alpha", "plan 2", "Plan 10"]
  names = ["Projects", "notes.md", "Archive"]
  @test D.sorted(desk, names, :name) == ["Archive", "notes.md", "Projects"]
  # The Finder calls a folder a Folder, and a Markdown file by another word, so the folders are together
  byk = D.sorted(desk, names, :kind)
  @test abs(findfirst(==("Archive"), byk) - findfirst(==("Projects"), byk)) == 1
  @test D.sorted(desk, names, :size)[1] == "notes.md"   # the folders come after the files
end

@testset "what Ladder keeps of a desktop is read back from its file" begin
  k = D.Kept(order=:none, snap=true)
  k.places["My plan.md"] = (0.25, 0.5)
  file = joinpath(dir, "kept")
  @test D.save(file, k)
  back = D.load(file)
  @test back.order == :none && back.snap == true
  @test back.places == Dict("My plan.md" => (0.25, 0.5))
  @test D.load(joinpath(dir, "none")).order === nothing
end

@testset "a folder whose page says so shows as a desktop" begin
  K.follow!(e, "Desk")
  @test !e.panel   # a link never opens the sidebar
  K.toggle_panel!(e)   # these tests have the sidebar open
  sleep(K.SLIDE_TIME + 0.05)   # the sidebar slides open
  frames()
  @test e.buf.path == desk
  @test K.directory(e) isa K.DesktopDirectory
  @test K.page_covered(e)
  v = view()
  # An icon for each folder and file that the Finder shows, and none for a hidden one
  @test sort(v.names) == ["A very long name for a plan of the house.md", "Archive", "Projects", "notes.md"]
  # The desktop covers the page's space: from the sidebar to the right edge, and from the top bar to the bottom
  r = rect(v)
  @test K.num(r.left) ≈ K.num(K.panel_w(e))
  @test K.num(r.top) ≈ K.num(K.TOPBAR_H)
  @test K.num(r.left + r.width) ≈ 1100
  @test K.num(r.top + r.height) ≈ 760
  shot("sorted")
end

@testset "a sorted desktop fills the grid in its order" begin
  v = view()
  g = D.grid(v.area, D.Look())
  order = D.sorted(desk, v.names, :kind)
  @test [v.spots[n] for n in order] == [D.spot(g, i) for i in 1:4]
end

@testset "a long name takes two lines, and loses its middle when it's longer" begin
  l = D.Look()
  lines = K.name_lines("A very long name for a plan of the house.md", K.name_room(l), l)
  @test length(lines) == 2
  @test occursin('…', lines[2])
  @test endswith(lines[2], ".md")
  @test K.name_lines("notes.md", K.name_room(l), l) == ["notes.md"]
end

@testset "a click chooses an icon, and ⌘ with a click chooses one more" begin
  click(icon("notes.md"))
  @test chosen() == ["notes.md"]
  @test w.focus === view()
  w.keys |= Keys.cmd
  click(icon("Projects"))
  w.keys ⊻= Keys.cmd
  @test chosen() == ["Projects", "notes.md"]
  shot("chosen")
  # A click on one of the two, with no drag, chooses only that one
  click(icon("Projects"))
  @test chosen() == ["Projects"]
  click(empty_spot())
  @test isempty(chosen())
end

@testset "a drag from the wallpaper chooses the icons that its box touches" begin
  a, b = icon("Projects"), icon("Archive")
  from = (min(a[1], b[1]) - 60, min(a[2], b[2]) - 40)
  to = (max(a[1], b[1]) + 10, max(a[2], b[2]) + 10)
  down(from)
  at(from .+ (to .- from) .* 0.5)
  at(to)
  shot("band")
  up()
  @test "Projects" in chosen() && "Archive" in chosen()
  click(empty_spot())
end

@testset "a sorted desktop puts a dragged icon back" begin
  was = view().spots["notes.md"]
  drag(icon("notes.md"), empty_spot())
  @test view().spots["notes.md"] == was
  @test isempty(kept().places)
end

@testset "the menu of the wallpaper sorts the desktop" begin
  right_click(empty_spot())
  @test menu() !== nothing
  # A sorted desktop has nothing to clean up, so those two items aren't there
  @test menu().items == ["New Folder", "New Page", "Sort By  ›", "Change Wallpaper…", "Show in Finder"]
  choose("Sort By  ›")
  frames()
  @test menu().items == ["None", "Snap to Grid", "Name", "✓ Kind", "Date Modified", "Date Created", "Size"]
  shot("menu")
  choose("Name")
  @test kept().order == :name
  g = D.grid(view().area, D.Look())
  @test view().spots["A very long name for a plan of the house.md"] == D.spot(g, 1)
  @test view().spots["Projects"] == D.spot(g, 4)
  # The choice is in the file of this desktop, so the next window has it
  @test D.load(K.desktop_file(desk)).order == :name
end

@testset "with None, each icon stays where the order put it, and then where you drag it" begin
  before = copy(view().spots)
  right_click(empty_spot())
  choose("Sort By  ›")
  frames()
  choose("None")
  @test kept().order == :none && kept().snap == false
  frames()
  @test all(n -> all(isapprox.(view().spots[n], before[n], atol=0.01)), keys(before))
  to = empty_spot()
  drag(icon("notes.md"), to)
  r = rect(view())
  @test all(isapprox.(view().spots["notes.md"], (to[1] - K.num(r.left), to[2] - K.num(r.top)), atol=0.5))
  @test haskey(D.load(K.desktop_file(desk)).places, "notes.md")
  shot("moved")
  # Clean Up puts it in the nearest cell of the grid
  right_click(empty_spot(95.0, 475.0))
  @test "Clean Up" in menu().items
  choose("Clean Up")
  g = D.grid(view().area, D.Look())
  @test all(isapprox.(view().spots["notes.md"], D.nearest(g, (to[1] - K.num(r.left), to[2] - K.num(r.top))), atol=0.5))
end

@testset "with Snap to Grid, a dropped icon goes to the nearest cell" begin
  right_click(empty_spot())
  choose("Sort By  ›")
  frames()
  choose("Snap to Grid")
  @test kept().snap == true
  r = rect(view())
  to = (K.num(r.left) + 210.0, K.num(r.top) + 230.0)
  drag(icon("Archive"), to)
  g = D.grid(view().area, D.Look())
  @test all(isapprox.(view().spots["Archive"], D.nearest(g, (210.0, 230.0)), atol=0.5))
end

@testset "Clean Up By sorts the icons once, and they can still be moved" begin
  right_click(empty_spot())
  choose("Clean Up By  ›")
  frames()
  choose("Name")
  @test kept().order == :none
  g = D.grid(view().area, D.Look())
  @test all(isapprox.(view().spots["Archive"], D.spot(g, 2), atol=0.5))
end

@testset "an icon that's dropped on a folder goes into the folder" begin
  drag(icon("notes.md"), icon("Projects"))
  frames()
  @test isfile(joinpath(desk, "Projects", "notes.md"))
  @test !ispath(joinpath(desk, "notes.md"))
  view().read = 0.0
  frames()
  @test !("notes.md" in view().names)
  @test !haskey(kept().places, "notes.md")
  mv(joinpath(desk, "Projects", "notes.md"), joinpath(desk, "notes.md"))
  view().read = 0.0
  frames()
end

@testset "New Folder makes a folder where you clicked, with its name to type" begin
  place = empty_spot(500.0, 550.0)
  right_click(place)
  choose("New Folder")
  path = joinpath(desk, "Untitled")
  @test isdir(path)
  @test K.renaming(e, :desktop) == path
  @test w.focus === K.renamer(e)
  shot("rename")
  key(Keys.a, Keys.cmd)
  typed("Plans")
  key(Keys.enter)
  @test isdir(joinpath(desk, "Plans")) && !ispath(path)
  frames()
  # The icon kept its place under its new name, it's still chosen, and the desktop has the keyboard again
  r = rect(view())
  @test all(isapprox.(view().spots["Plans"], D.nearest(D.grid(view().area, D.Look()), (place[1] - K.num(r.left), place[2] - K.num(r.top))), atol=0.5))
  @test chosen() == ["Plans"]
  @test w.focus === view()
end

@testset "the keys of a desktop" begin
  click(icon("Plans"))
  key(Keys.enter)
  @test K.renaming(e, :desktop) == joinpath(desk, "Plans")
  key(Keys.escape)
  @test K.renaming(e, :desktop) == ""
  click(icon("Archive"))
  key(Keys.a, Keys.cmd)
  @test length(chosen()) == length(view().names)
  click(empty_spot())
  click(icon("Plans"))
  key(Keys.backspace, Keys.cmd)
  @test trashed == [joinpath(desk, "Plans")]
  frames()
  @test !("Plans" in view().names)
end

@testset "a right-click on an icon shows the menu of its file" begin
  right_click(icon("notes.md"))
  @test chosen() == ["notes.md"]
  @test menu().items[1:2] == ["Open", "Open in New Window"]
  @test "Rename" in menu().items && "Move to Trash" in menu().items
  choose("Rename")
  @test K.renaming(e, :desktop) == joinpath(desk, "notes.md")
  key(Keys.escape)
end

@testset "two clicks open an icon in the page: a file, or a folder" begin
  click(icon("notes.md"))
  down(icon("notes.md"))
  up()
  frames()
  @test e.buf.path == joinpath(desk, "notes.md")
  @test !K.page_covered(e)
  # Back shows the desktop again
  @test K.go_back!(e)
  frames()
  @test e.buf.path == desk && K.page_covered(e)
  # A folder shows in the page, in place of the desktop, and a hidden sidebar stays hidden
  e.panel && K.toggle_panel!(e)
  sleep(K.SLIDE_TIME + 0.05)
  frames()
  click(icon("Projects"))
  down(icon("Projects"))
  up()
  frames()
  @test e.buf.path == joinpath(desk, "Projects")
  @test e.folder == joinpath(desk, "Projects")
  @test !e.panel
  @test K.go_back!(e)
  frames()
  @test e.buf.path == desk && K.page_covered(e)
  K.toggle_panel!(e)
  sleep(K.SLIDE_TIME + 0.05)
  frames()
end

@testset "the Mac's wallpaper covers the desktop" begin
  # A picture that's twice as wide as it's tall, for a desktop that's less wide: its sides are cut off
  file = joinpath(dir, "wall.png")
  run(pipeline(`sips -z 100 200 $(joinpath(@__DIR__, "..", "app", "icon.png")) --out $file`, stdout=devnull, stderr=devnull))
  D.papers[] = () -> file
  K.WALLPAPER[] = (0.0, "", nothing)
  part = K.wallpaper_part(900.0, 600.0)
  @test part isa K.Image
  @test K.num(part.width.preferred) ≈ 1200 && K.num(part.height.preferred) ≈ 600
  @test K.num(part.offset_x) ≈ -150 && K.num(part.offset_y) ≈ 0
  frames()
  shot("wallpaper")
  D.papers[] = () -> ""
  K.WALLPAPER[] = (0.0, "", nothing)
end

@testset "a window that's opened on a desktop's folder shows the desktop" begin
  e2 = K.build_editor(desk)
  w2 = Window(e2, size=(900px, 700px))
  foreach(_ -> Base.invokelatest(frame, w2), 1:4)
  @test e2.buf.path == desk
  @test Base.invokelatest(K.page_covered, e2)
  @test e2.folder == desk && !e2.panel
  close(w2)
end

close(w)
