# Tests for the path in the top bar: hold the mouse over the file's name, and
# it grows into the names of the folders on the way to the file. See "the path
# in the top bar" in main.jl. Run them with
# `julia -O0 --project=. test/title_path_test.jl`. They use folders of their
# own, and they click in a window that isn't on the screen, with the sidebar
# hidden. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

const px = K.px
const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))

# `top` has a page of its own, as Downloads has. `Plain` and `Sub` are plain folders.
const top = mkpath(joinpath(dir, "top"))
const plain = mkpath(joinpath(top, "Plain"))
const sub = mkpath(joinpath(plain, "Sub"))
made(path, text="# A page\n") = (write(path, text); path)
const a = made(joinpath(plain, "a.md"))
const b = made(joinpath(plain, "b.md"))
const c = made(joinpath(sub, "c.md"))
made(joinpath(plain, ".hidden"))
K.PLACE_KINDS[top] = K.DownloadsDirectory
K.HOME[] = dir   # the path starts with ~ for this folder

const e = K.build_editor(a)
e.panel = false   # the sidebar is hidden: the top bar is the way round
const w = Window(e, size=(1100px, 760px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "title-$name.png"), w)
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
showing() = any(p -> p.key == :title_trail, popups(w))
trail() = e.nodes[:title_trail]
crumb(path) = trail().crumbs[path]
arrow(path) = trail().arrows[path]
"Hold the mouse over the file's name until the path shows"
hover!() = (at(middle(e.nodes[:title])); sleep(K.TT_WAIT + 0.05); frames())
"Where a part is, and how big"
place(n) = (r = rect(n); (r.left, r.top, r.width, r.height))
"Where each button of the top bar is"
bar_places() = Dict(k => place(n) for (k, n) in e.nodes if n isa K.ToolButton && rect(n) !== nothing)

@testset "holding the mouse over the name shows the path, and nothing in the bar moves" begin
  title_at = place(e.nodes[:title])
  places = bar_places()
  @test !isempty(places)
  at(middle(e.nodes[:title]))
  @test !showing()   # it waits a moment, so a mouse that only passes over the bar shows nothing
  sleep(K.TT_WAIT + 0.05); frames()
  @test showing()
  @test trail().steps == [("~", dir), ("top", top), ("Plain", plain), ("a.md", a)]
  # The file's name stays where the bar had it, and the folders come in to its left
  @test abs(K.num(rect(crumb(a)).left) + K.num(K.TT_PAD) - K.num(title_at[1])) <= 2
  @test K.num(rect(crumb(plain)).left) < K.num(rect(crumb(a)).left)
  # The bar's own parts are where they were
  @test place(e.nodes[:title]) == title_at && bar_places() == places
  shot("path")
end

@testset "it goes when the mouse leaves it" begin
  at((550, 400))
  @test !showing()
  hover!()
  @test showing()
end

@testset "a click on a folder that has a page shows the page" begin
  click(middle(crumb(top)))
  @test e.buf.path == top && e.folder == top
  @test e.nodes[(:filelist, top)] isa K.FileList
  K.open!(e, a); frames()
end

@testset "a click on a plain folder opens it in the page, as the tree of what's in it" begin
  hover!()
  click(middle(crumb(plain)))
  @test e.buf.path == plain && e.folder == plain
  @test e.nodes[(:folder_page, plain)] isa K.FolderPage
  @test !e.panel   # the sidebar stays hidden
  shot("folder")
  K.open!(e, a); frames()
end

@testset "a › shows a menu of what's in the folder before it" begin
  hover!()
  click(middle(arrow(plain)))
  @test menu() !== nothing
  # Its folders first, then its files. The file that shows has a tick. Hidden files stay out.
  @test menu().items == ["Sub  ›", "✓ a.md", "b.md"]
  shot("menu")
  choose("b.md")
  @test e.buf.path == b
  # A folder in the menu opens a menu of what's in it
  hover!()
  click(middle(arrow(plain)))
  @test menu().items == ["Sub  ›", "a.md", "✓ b.md"]
  choose("Sub  ›")
  @test menu().items == ["Go to Sub", "c.md"]
  choose("c.md")
  @test e.buf.path == c
  # Go to Sub opens the folder in the page, as a click on a folder's name does
  hover!()
  click(middle(arrow(plain)))
  choose("Sub  ›")
  @test menu().items == ["Go to Sub", "✓ c.md"]
  choose("Go to Sub")
  @test menu() === nothing && e.buf.path == sub && !e.panel
  K.open!(e, a); frames()
end

@testset "a right-click on a folder shows its menu, with no Rename" begin
  hover!()
  at(middle(crumb(plain)))
  onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames()
  @test menu() !== nothing && "Show in Finder" in menu().items && !("Rename" in menu().items)
  key(Keys.escape)
end

@testset "in a narrow window the names shrink, and the path stays in the window" begin
  all = [("~", "/h"), ("Desktop", "/h/D"), ("JuliaLang", "/h/D/J"), ("Ladder", "/h/D/J/L"), ("main.jl", "/h/D/J/L/m")]
  @test K.title_steps(all, 10_000px) == all
  room = K.title_wide(all) - 20px
  short = K.title_steps(all, room)
  @test K.title_wide(short) <= room
  @test short[1] == ("~", "/h") && short[end] == ("main.jl", "/h/D/J/L/m") && short[2] == ("D", "/h/D")
  tiny = K.title_steps(all, 150px)
  @test K.title_wide(tiny) <= 150px && any(s -> s[1] == "…", tiny) && tiny[end][2] == "/h/D/J/L/m"
  # In the window, the path never covers the Mac's close, minimise and zoom buttons, and never runs off the right
  hover!()
  r = rect(only(p for p in popups(w) if p.key == :title_trail).content)
  @test K.num(r.left) >= K.num(K.mac_buttons_room(e)) && K.num(r.left + r.width) <= 1100
end

K.HOME[] = ""
