# Tests for the path in the top bar: hold the mouse over the file's name, and
# it grows into the names of the folders on the way to the file. See "the path
# in the top bar" in main.jl. Run them with
# `julia -O0 --project=. test/title_path_test.jl`. They use folders of their
# own, and they click in a window that isn't on the screen, with the sidebar
# hidden. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
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
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
"The lists of folders that show, from the one under the › on"
lists() = K.folder_lists(w)
"The list of a folder at `level`"
list(level=1) = only(l for l in lists() if l.level == level)
"The row of the list `l` that has `name`"
row(l, name) = l.parts[(:row, findfirst(==(name), l.names))]
"Rest the mouse on the row of `l` that has `name` until something happens"
rest!(l, name) = (at(middle(row(l, name))); sleep(K.TT_WAIT + 0.05); frames())
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
  # The file's name stays where the bar had it, and the folders come in to its left. The bar keeps room
  # before the name as wide as the heading after it, so the name stays in the middle.
  @test abs(K.num(rect(crumb(a)).left) + K.num(K.TT_PAD) - K.num(title_at[1]) - K.num(get(e.nodes, :title_lead, 0px))) <= 2
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

@testset "a › shows a list of what's in the folder before it, that Ladder draws" begin
  hover!()
  click(middle(arrow(plain)))
  l = list()
  @test menu() === nothing   # not the Mac's menu
  # Its folders first, then its files. Hidden files stay out. The file that shows is picked, and in bold.
  @test l.names == ["Sub", "a.md", "b.md"] && l.names[l.pick] == "a.md"
  # It hangs under the ›, and the keyboard is in its field
  r, ra = rect(l), rect(arrow(plain))
  @test r.top > ra.top + ra.height && r.left < ra.left && ra.left + ra.width < r.left + r.width
  @test w.focus === l.parts[:field]
  shot("list")
  # The path stays while the list shows, with the mouse somewhere else
  at((550, 400))
  @test showing() && list() === l
  # A click on a file shows it, and the list, the path and the keyboard go back
  click(middle(row(l, "b.md")))
  @test e.buf.path == b && isempty(lists()) && w.focus !== l.parts[:field]
end

@testset "rest the mouse on a folder of the list, and a list of what's in it opens beside it" begin
  hover!()
  click(middle(arrow(plain)))
  l = list()
  rest!(l, "Sub")
  inner = list(2)
  @test inner.names == ["c.md"] && inner.pick == 0
  # It's at the right of the list, with its first row in line with the folder's
  r, ri = rect(l), rect(inner)
  @test K.num(ri.left) >= K.num(r.left + r.width)
  @test abs(K.num(rect(row(inner, "c.md")).top) - K.num(rect(row(l, "Sub")).top)) <= 1
  shot("beside")
  # A rest on a file takes it away again
  rest!(l, "a.md")
  @test length(lists()) == 1
  rest!(l, "Sub")
  click(middle(row(list(2), "c.md")))
  @test e.buf.path == c && isempty(lists())
  # A click on a folder opens it in the page, as a click on its name in the path does
  hover!()
  click(middle(arrow(plain)))
  click(middle(row(list(), "Sub")))
  @test e.buf.path == sub && e.folder == sub && !e.panel
  K.open!(e, a); frames()
end

@testset "the keys work the list" begin
  hover!()
  click(middle(arrow(plain)))
  # Words typed in the field keep the names that have them, and pick the first that starts with them
  typed("b")
  @test list().names == ["Sub", "b.md"] && list().names[list().pick] == "b.md"
  typed("zz")
  @test isempty(list().names)
  shot("none")
  foreach(_ -> key(Keys.backspace), 1:3)
  @test list().names == ["Sub", "a.md", "b.md"]
  # → opens the picked folder beside, ← takes it away, and Return takes the picked row
  key(Keys.up)
  @test list().names[list().pick] == "Sub"
  key(Keys.right)
  @test length(lists()) == 2 && list(2).pick == 1
  key(Keys.left)
  @test length(lists()) == 1
  key(Keys.right)
  key(Keys.enter)
  @test e.buf.path == c && isempty(lists())
  # Esc takes every list away, and the keyboard goes back to the page
  hover!()
  click(middle(arrow(plain)))
  rest!(list(), "Sub")
  key(Keys.escape)
  @test isempty(lists()) && w.focus === e
  K.open!(e, a); frames()
end

@testset "a second click on the ›, or a click somewhere else, takes the list away" begin
  hover!()
  click(middle(arrow(plain)))
  @test length(lists()) == 1
  click(middle(arrow(plain)))
  @test isempty(lists())
  click(middle(arrow(plain)))
  # A click on the page takes it away and does nothing else
  caret = e.buf.caret
  click((550, 400))
  @test isempty(lists()) && e.buf.caret == caret && e.buf.path == a
  # A › of another folder shows that folder
  hover!()
  click(middle(arrow(top)))
  @test list().names == ["Plain"] && list().arrow === arrow(top)
  click(middle(arrow(plain)))
  @test length(lists()) == 1 && list().dir == plain
  key(Keys.escape)
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

"The path's box in the window"
path_box() = rect(only(p for p in popups(w) if p.key == :title_trail).content)
"How far the middle of the path is from the middle of the file's name in the bar"
off_middle() = (r = path_box(); t = rect(e.nodes[:title]); abs(K.num(r.left + r.width / 2) - K.num(t.left + t.width / 2)))
"The colour of the window just inside the left side of the name `c`, as the window draws it now"
shade(c) = begin
  file = joinpath(dir, "shade.png")
  save_png(file, w)
  p = pixels(file)
  s = size(p, 2) / 1100   # the picture can have more than one pixel for each point
  r = rect(c)
  p[round(Int, K.num(r.top + r.height / 2) * s), round(Int, (K.num(r.left) + 2) * s)]
end

@testset "a click on the file's name pins the path open, in the middle of the bar, and a second click lets it go" begin
  at((550, 400)); @test !showing()
  hover!()
  @test off_middle() > 20   # while it only shows under the mouse, the name stays where the bar has it, and the folders go to its left
  click(middle(crumb(a)))
  @test K.trail_pinned(e)
  @test shade(crumb(a)) != shade(crumb(plain))   # the name under the mouse is shaded
  at((550, 400))
  @test showing()   # it stays when the mouse leaves it
  @test off_middle() <= 2
  @test shade(crumb(a)) == shade(crumb(plain))   # and isn't when the mouse leaves it, so it doesn't look chosen
  shot("pinned")
  # It stays while you go from folder to folder with it
  click(middle(crumb(plain)))
  @test e.buf.path == plain
  at((550, 400))
  @test showing() && trail().steps[end] == ("Plain", plain) && off_middle() <= 2
  K.open!(e, a); frames()
  @test showing() && trail().steps[end] == ("a.md", a) && off_middle() <= 2
  # It follows the file's name when the sidebar opens, and when it closes again
  before = rect(e.nodes[:title])
  K.toggle_panel!(e); sleep(1); frames()
  @test abs(K.num(rect(e.nodes[:title]).left - before.left)) > 50   # the name moved over
  @test showing() && off_middle() <= 2
  K.toggle_panel!(e); sleep(1); frames()
  @test !e.panel && off_middle() <= 2
  # A second click on the name lets it go when the mouse leaves it. Until then it stays where it is, under the mouse.
  click(middle(crumb(a)))
  @test !K.trail_pinned(e) && showing() && off_middle() <= 2
  at((550, 400))
  @test !showing()
  hover!()
  @test off_middle() > 20
end

K.HOME[] = ""
