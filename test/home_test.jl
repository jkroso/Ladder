# Tests for the home folder's page: the favourite folders, and the work of the
# last 7 days by project. See "the home folder" in main.jl, and home.jl. Run
# them with `julia -O0 --project=. test/home_test.jl`. They use a home folder
# of their own and a list of changed files of their own, never the Mac's home
# folder or Spotlight, and they click in a window that isn't on the screen.
# With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

const px = K.px
const H = K.Home

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
H.FILE[] = joinpath(dir, "home-list")

# A home folder with a repository, a folder on its Desktop, a folder that a program fills, and
# places that aren't work: its Library, a hidden folder, and what a build made
const home = mkpath(joinpath(dir, "sam"))
made(rel, text="some text") = (path = joinpath(home, rel); mkpath(dirname(path)); write(path, text); path)
const app = mkpath(joinpath(home, "Code", "app"))
run(pipeline(`git -C $app init -q`, stdout=devnull, stderr=devnull))
made("Code/app/.gitignore", "build/\n")
const main_file = made("Code/app/main.jl", "f(x) = x\n")
const notes = made("Code/app/notes.md", "# Notes\n")
const built = made("Code/app/build/out.bin")
const plan = mkpath(joinpath(home, "Desktop", "Plan"))
run(pipeline(`git -C $plan init -q`, stdout=devnull, stderr=devnull))
const report = made("Desktop/Plan/2026/report.md", "# Report\n")
const mail = made("Mail/Inbox/1.eml", "Subject: hi\n\nhi\n")
const loose = made("list.csv", "a,b\n1,2\n")
const prefs = made("Library/Preferences/x.plist")
const config = made(".config/tool/settings")
const page = made("page.md", "# Sam's page\n")
const favs = [mkpath(joinpath(home, name)) for name in ("Alpha", "Beta", "Gamma")]

const hour = 3600.0
const touched = [H.Touched(main_file, time() - 0.1hour), H.Touched(notes, time() - 2hour), H.Touched(built, time() - 0.05hour),
                 H.Touched(report, time() - 5hour), H.Touched(mail, time() - 1hour), H.Touched(loose, time() - 30hour),
                 H.Touched(prefs, time() - 0.01hour), H.Touched(config, time() - 0.01hour)]
H.finder[] = (folder, since) -> folder == home ? touched : H.Touched[]

@testset "Spotlight's answer is read as paths and times" begin
  @test H.spotlight_time("2026-11-22 03:04:49 +0000") == 1.795316689e9
  @test H.spotlight_time("2026-11-22 13:04:49 +1000") == 1.795316689e9
  @test H.spotlight_time("(null)") === nothing
  key = "kMDItemFSContentChangeDate"
  text = "/Users/sam/a b.md   $key = 2026-11-22 03:04:49 +0000\0/Users/sam/old.md   $key = 2020-01-01 00:00:00 +0000\0/Users/sam/none   $key = (null)\0"
  @test H.read_found(text, key, 1.7e9) == [H.Touched("/Users/sam/a b.md", 1.795316689e9)]
end

@testset "the work goes in a project for each git repository, the newest first" begin
  ps = H.projects(touched, home)
  # The email and the list in the home folder are in no repository, so they aren't work
  @test [p.path for p in ps] == [app, plan]
  # What the build made isn't work, since git ignores it
  @test [f.path for f in ps[1].files] == [main_file, notes] && ps[1].count == 2
  @test ps[2].files[1].path == report
  # Nothing in the Library or in a hidden folder is work
  @test !any(p -> occursin("Library", p.path) || occursin(".config", p.path), ps)
  @test H.projects(touched, home, most=1)[1].files == [H.Touched(main_file, touched[1].when)]
end

@testset "the list of favourites is kept in its file" begin
  @test H.favourites() == []
  H.favourite!(favs[1]); H.favourite!(favs[2] * "/"); H.favourite!(favs[1])
  @test H.favourites() == favs[1:2]
  H.move_favourite!(favs[2], 1)
  @test H.favourites() == [favs[2], favs[1]]
  H.unfavourite!(favs[2])
  @test H.favourites() == [favs[1]]
  # Another window of Ladder reads the same file
  H.READ[] = (-1.0, H.Kept())
  @test H.favourites() == [favs[1]] && H.isfavourite(favs[1]) && !H.isfavourite(favs[2])
  H.unfavourite!(favs[1])
  @test H.favourites() == []
end

K.PLACE_KINDS[home] = K.HomeDirectory
K.HOME[] = home
const e = K.build_editor(page)
e.panel = true   # the sidebar is open
const w = Window(e, size=(1100px, 760px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "home-$name.png"), w)
view() = e.nodes[(:home, home)]
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press() = (w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1); w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2))
click(place) = (at(place); press())
middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
menu() = (ps = [p for p in popups(w) if p.key == :menu]; isempty(ps) ? nothing : only(ps).content)
choose(name) = (m = menu(); foreach(_ -> key(Keys.down), 1:findfirst(==(name), m.items)); key(Keys.enter))
right_click(place) = (at(place); onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames())
"Find the work again now, and wait for it"
fresh!() = (H.forget!(); frames(1); H.wait!(); frames())

"The name in the trail at the top of the sidebar of the folder at `path`"
trail_name(path) = only(n for n in values(e.nodes) if n isa K.TrailName && n.path == path && rect(n) !== nothing)

@testset "the home folder is a kind of folder, and its name in the trail shows its page" begin
  @test e.folder == home
  d = K.object(e, home)
  @test d isa K.HomeDirectory && K.entry_icon(d) == "house"
  # The sidebar lists the home folder as it lists any folder, with no line of its own over the list
  @test K.folder_view(e, d).bar === nothing
  frames()
  # The sidebar's own folder is the last name of the trail. A click on it shows the folder's page.
  t = trail_name(home)
  @test t.last && K.goes(t)
  click(middle(t))
  @test e.buf.path == home && e.folder == home
  @test view() isa K.HomeView && rect(view()) !== nothing
  # While its page shows, the name goes nowhere
  @test !K.goes(trail_name(home))
  K.open!(e, page)
  frames()
  # A plain folder's own name opens it too, as a list of what's in it
  K.go_folder!(e, favs[1]); frames()
  @test K.goes(trail_name(favs[1]))
  click(middle(trail_name(favs[1])))
  @test e.buf.path == favs[1] && !K.goes(trail_name(favs[1]))
  K.open!(e, page); K.go_folder!(e, home); frames()
end

@testset "⌘⇧H shows the home folder's page" begin
  @test e.buf.path == page
  key(Keys.h, Keys.cmd, Keys.shft)
  @test e.buf.path == home
  fresh!()
  # The newest project first, with no Library, no hidden folder and nothing that git ignores
  @test view().shown == [app, plan]
  @test isempty(view().buttons)   # the page has no buttons while no project is hidden
  # A project is one line, with no line for each of its files
  @test all(k -> k[1] != :file, keys(view().rows))
  shot("work")
end

@testset "a folder's menu makes it a favourite, and the page shows it as a card" begin
  @test "Add to Favourites" in K.file_menu(favs[1])
  foreach(f -> K.file_act!(e, f, "Add to Favourites"), favs)
  @test H.favourites() == favs
  @test "Remove from Favourites" in K.file_menu(favs[1]) && !("Add to Favourites" in K.file_menu(favs[1]))
  # A file's menu has neither
  @test !any(i -> occursin("Favourites", i), K.file_menu(page))
  frames()
  v = view()
  @test v.order == favs
  @test all(f -> rect(v.cards[f]) !== nothing, favs)
  # The three cards are in one row, from the left
  @test K.num(rect(v.cards[favs[1]]).left) < K.num(rect(v.cards[favs[2]]).left) < K.num(rect(v.cards[favs[3]]).left)
  shot("favourites")
end

@testset "a click on a favourite opens its folder in the page, and the sidebar stays hidden" begin
  e.panel = false; frames()
  click(middle(view().cards[favs[2]]))
  # A plain folder shows as the tree of what's in it
  @test e.buf.path == favs[2] && e.folder == favs[2]
  @test e.nodes[(:folder_page, favs[2])] isa K.FolderPage
  @test !e.panel
  # ⌘⇧H shows the home folder's page again, and leaves the sidebar hidden too
  key(Keys.h, Keys.cmd, Keys.shft)
  @test e.buf.path == home && e.folder == home && !e.panel
  e.panel = true; frames()
end

@testset "a drag puts a favourite in another place" begin
  v = view()
  from, to = middle(v.cards[favs[1]]), middle(v.cards[favs[3]])
  at(from)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  for k in 1:5
    x, y = from .+ (to .- from) .* (k / 5)
    w.mouse = typeof(w.mouse)(px(x), px(y))
    onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1)
  end
  # While it's dragged, the cards show in the order that a drop would make
  @test v.drag == (favs[1], 3)
  @test v.order == [favs[2], favs[3], favs[1]]
  shot("drag")
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames()
  @test H.favourites() == [favs[2], favs[3], favs[1]]
  @test v.drag === nothing && e.folder == home   # a drag isn't a click
end

@testset "a favourite's menu takes it off the list" begin
  right_click(middle(view().cards[favs[3]]))
  @test menu() !== nothing && menu().items[end] == "Remove from Favourites"
  choose("Remove from Favourites")
  @test H.favourites() == [favs[2], favs[1]]
  frames()
  @test view().order == [favs[2], favs[1]]
end

@testset "a click on a project opens the page of its repository" begin
  click(middle(view().rows[(:project, plan)]))
  @test e.folder == plan && e.buf.path == plan
  @test e.nodes[(:repo, plan)] isa K.RepoView
  K.go_home!(e)
  frames()
end

@testset "under the projects is the tree of the home folder, as the sidebar shows it" begin
  t = e.nodes[(:folder_tree, home)]
  @test t isa K.Tree.ListTree && rect(t) !== nothing
  # The sidebar's rows, in its order: the folders, then the files, each by name. Hidden folders stay out.
  @test [basename(c.firstchild.path) for c in t.children] == ["Alpha", "Beta", "Code", "Desktop", "Gamma", "Library", "Mail", "list.csv", "page.md"]
  @test all(c -> c isa K.Tree.Item && c.firstchild isa K.FileLabel, t.children)
  shot("tree")
  # A right-click shows the row's menu, with no Rename
  row(name) = only(c.firstchild for c in t.children if basename(c.firstchild.path) == name)
  right_click(middle(row("Code")))
  @test menu() !== nothing && "Show in Finder" in menu().items && !("Rename" in menu().items)
  key(Keys.escape)
  # A click on a folder opens it in the page, as its tree
  click(middle(row("Code")))
  code = joinpath(home, "Code")
  @test e.buf.path == code && e.nodes[(:folder_page, code)] isa K.FolderPage
  @test [basename(c.firstchild.path) for c in e.nodes[(:folder_tree, code)].children] == ["app"]
  # A click on a file shows it
  K.go_home!(e); frames()
  click(middle(row("page.md")))
  @test e.buf.path == page
  K.go_home!(e); frames()
end

@testset "a project's menu hides it, and the page shows it again" begin
  right_click(middle(view().rows[(:project, plan)]))
  @test menu() !== nothing && menu().items[end] == "Hide from This Page"
  choose("Hide from This Page")
  frames()
  @test view().shown == [app] && H.hidden() == [plan]
  click(middle(view().buttons[:hidden]))
  @test view().hidden
  shot("hidden")
  click(middle(view().rows[(:hidden, plan)]))
  frames()
  @test view().shown == [app, plan] && H.hidden() == []
end

@testset "the palette's Go To Favourite goes to a favourite" begin
  @test [f.path for f in K.choices_for(K.Favourite, e)] == [favs[2], favs[1]]
  @test K.worded(K.Favourite(favs[2])) == "Beta"
  K.go_to_favourite!(e, K.Favourite(favs[1]))
  frames()
  @test e.folder == favs[1] && e.buf.path == favs[1]
  K.add_to_favourites!(K.object(e, favs[3]))
  @test H.favourites() == [favs[2], favs[1], favs[3]]
  K.remove_from_favourites!(K.object(e, favs[3]))
  @test H.favourites() == [favs[2], favs[1]]
end

@testset "a folder of no work says so" begin
  H.finder[] = (folder, since) -> H.Touched[]
  K.go_home!(e)
  fresh!()
  @test view().shown == []
  H.finder[] = (folder, since) -> folder == home ? touched : H.Touched[]
end

@testset "a click on a folder in the trail opens it in the page at once" begin
  K.open!(e, notes)
  frames()
  @test e.folder == app && e.buf.path == notes
  # Code is a plain folder: it shows as the tree of what's in it
  code = joinpath(home, "Code")
  click(middle(trail_name(code)))
  @test e.folder == code && e.buf.path == code && e.nodes[(:folder_page, code)] isa K.FolderPage
  # The home folder has a page of its own, and it shows
  click(middle(trail_name(home)))
  @test e.folder == home && e.buf.path == home
  @test view() isa K.HomeView
  # ⌘⌥← goes back to the page that showed before
  K.go_back!(e)
  frames()
  @test e.buf.path == code
end
