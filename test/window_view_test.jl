# Tests for the window of a kind of folder: `window_view` makes all that the
# window shows, `side_menu` a side menu in the sidebar's place, and `bread_crumb` the
# middle of the top bar. Each asks the object of the file or the folder that
# the window shows. See "the whole window" in windows.jl. Run them with
# `julia -O0 --project=. test/window_view_test.jl`. They draw a window that
# isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/URI.jl/FSPath" FSPath
const px = K.px
const FS = K.FS

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const shop = joinpath(dir, "shop")
const kiosk = joinpath(dir, "kiosk")
mkpath(joinpath(shop, "sales"))
mkpath(kiosk)
const depot = joinpath(dir, "depot")
mkpath(depot)
mkpath(joinpath(dir, "plain"))   # a folder with no kind
write(joinpath(shop, "bank.md"), "# Bank\n")
write(joinpath(shop, "sales", "june.md"), "# June\n")
write(joinpath(dir, "page.md"), "# A page\n")

# A kind of folder with a side menu of its own in the sidebar's place, as code from the
# startup page would make it. Its folders are of the kind too. While the
# window shows a thing that the folder holds, the top bar has the kind's own path.
@def struct ShopDirectory <: K.AbstractDirectory end
FS.kind(::ShopDirectory, path::FSPath) = ShopDirectory
FS.kinds[FSPath(shop)] = ShopDirectory
word(text) = K.Box(K.Text(text, size=12px))
shop_menu() = K.Column(K.width(grow=K.grow), K.height(grow=K.grow), name="Shop menu",
  word("Sales"), word("Bank"), K.Box(K.height(grow=K.grow)), word("Shop settings"))
K.side_menu(e, d::ShopDirectory) = shop_menu()
K.side_menu(e, d::ShopDirectory, o) = shop_menu()
K.bread_crumb(e, d::ShopDirectory, o) = word("Shop › $(o.path.name)")

# A kind of folder whose side menu has a compact form: a rail 60px wide, which stays while the sidebar is closed
@def struct DepotDirectory <: K.AbstractDirectory end
FS.kinds[FSPath(depot)] = DepotDirectory
@def mutable struct RailMenu <: K.SemanticUI end
K.describe(m::RailMenu) = K.Column(K.width(grow=K.grow), K.height(grow=K.grow), name="Rail menu", word(K.editor(m).panel ? "Depot menu" : "D"))
"Every rectangle in `r`, as it was last drawn"
flat(r, out=Any[]) = (push!(out, r); hasproperty(r, :children) && foreach(c -> flat(c, out), r.children); out)
"The buttons of the top bar that are drawn, by what each does"
bar_buttons(r=K.rect(e.nodes[:topbar]), out=Symbol[]) = begin
  # a rectangle is from a box, and the box of a button is from the button
  hasproperty(r.from, :from) && r.from.from isa K.ToolButton && push!(out, r.from.from.action)
  hasproperty(r, :children) && foreach(c -> bar_buttons(c, out), r.children)
  out
end
K.compact_width(::RailMenu) = 60px
K.side_button(m::RailMenu) = K.editor(m).panel ? word("fold") : nothing   # the rail has no button in the bar
K.shows_lock(e, ::DepotDirectory) = false   # its page is no file that's only shown
const LOADS_W = Ref(0px)   # how wide the first of its page's parts in the top bar is
# what its page is for, at the right end of the top bar
K.page_actions(e, ::DepotDirectory) = (K.Box(K.fixed(LOADS_W[]), K.height(10px), name="Loads"), word("New load"))
K.page_top(e, ::DepotDirectory) = 2px     # its page starts nearer the top bar than a page of text does,
K.page_margin(e, ::DepotDirectory) = 10px   # and has less room at its sides
K.side_menu(e, d::DepotDirectory) = K.node!(RailMenu, e, :rail_menu)

# A kind of folder that makes the whole window: one line of words, under the top bar and the file finder
@def struct KioskDirectory <: K.AbstractDirectory end
FS.kinds[FSPath(kiosk)] = KioskDirectory
K.window_view(e, d::KioskDirectory) = K.Stack(K.width(grow=K.grow), K.height(grow=K.grow), name="Kiosk",
  word("Only the kiosk"), K.window_over(e)...)

const e = K.build_editor(joinpath(dir, "page.md"))
const w = Window(e, size=(1000px, 700px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
e.panel || K.toggle_panel!(e)
frames(30)   # the sidebar slides open

"Each Text in the layout `node`, in the order they read"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
"The name of each box in the layout `node` that has one"
names(node, out=String[]) = begin
  node isa K.GeometricUI || return out
  hasproperty(node, :name) && node.name isa AbstractString && !isempty(node.name) && push!(out, node.name)
  foreach(n -> names(n, out), node.children)
  out
end
"What's at the left of the window: Ladder's sidebar, or the side menu that a kind of folder has in its place"
side() = (part = K.side_part(e); part isa K.Sidebar ? K.describe(part) : part)
"The rectangle of the box called `name` in the window as it was last drawn, or nothing"
drawn(name, r=K.rect(e)) = begin
  hasproperty(r.from, :name) && r.from.name == name && return r
  hasproperty(r, :children) || return nothing
  for child in r.children
    found = drawn(name, child)
    found === nothing || return found
  end
  nothing
end
const room = Ref(0px)   # how wide the room of a kind's own path in the top bar was
bar() = texts(K.describe(e.nodes[:topbar]))
whole() = K.window_view(e, K.window_object(e))

@testset "the window of a plain file is Ladder's own" begin
  @test K.window_object(e) isa FS.File{:md} && string(K.window_object(e).path) == joinpath(dir, "page.md")
  @test K.side_menu(e, K.window_object(e)) === e.nodes[:sidebar] && !K.own_side_menu(e)
  @test K.bread_crumb(e, K.window_object(e)) === e.nodes[:title]
  # the sidebar holds the tab of the file, the path of its folder and the folder's list
  @test "Files" in names(side()) && "Folder" in names(side()) && "Tabs" in names(side())
  @test "page.md" in texts(side()) && "shop" in texts(side())
  @test K.files_listed(e) && K.hidden_button(e) != ()
  @test K.bar_name(e) in bar()
  @test names(whole())[1] == "Editor" && "Files" in names(whole()) && "TopBar" in names(whole())
end

@testset "a kind of folder has a side menu of its own in the sidebar's place" begin
  K.open!(e, shop); frames()
  @test K.window_object(e) isa ShopDirectory && K.own_side_menu(e)
  @test texts(side()) == ["Sales", "Bank", "Shop settings"]
  # nothing of Ladder's sidebar is there: not its box with its colour and its line, its tabs, the folder's path or the tree of files
  @test "Shop menu" in names(side()) && !any(n -> n in names(side()), ["Files", "Folder", "Tabs"])
  @test drawn("Files") === nothing
  # the menu has the sidebar's room: from the window's top left corner to its bottom, as wide as the sidebar
  r = drawn("Shop menu")
  @test r.left == 0px && r.top == 0px && r.width == K.panel_w(e) && r.height == 700px
  # it goes and comes with the sidebar's own command
  K.toggle_panel!(e); sleep(0.3); frames()
  @test drawn("Shop menu") === nothing
  K.toggle_panel!(e); sleep(0.3); frames()
  @test drawn("Shop menu").left == 0px && drawn("Shop menu").width == K.panel_w(e)
  # the button that shows the hidden files is for Ladder's tree of files, so it goes
  @test !K.files_listed(e) && K.hidden_button(e) == ()
  # the kind said nothing of the top bar for the folder itself, so the bar has the folder's name
  @test K.bread_crumb(e, K.window_object(e)) === e.nodes[:title] && K.bar_name(e) in bar()
end

@testset "the side menu is there for each thing that the folder holds, which the kind names in the top bar" begin
  K.open!(e, joinpath(shop, "bank.md")); frames()
  @test K.window_object(e) isa FS.File{:md} && K.window_object(e).parent isa ShopDirectory
  @test texts(side()) == ["Sales", "Bank", "Shop settings"]
  @test "Shop › bank.md" in bar() && !(K.bar_name(e) in bar())
  # a folder in it is of the kind, so a file in that folder has the menu and the path too
  K.open!(e, joinpath(shop, "sales", "june.md")); frames()
  @test K.window_object(e).parent isa ShopDirectory && string(K.window_object(e).parent.path) == joinpath(shop, "sales")
  @test texts(side()) == ["Sales", "Bank", "Shop settings"] && "Shop › june.md" in bar()
  # the kind's path has all the room from the sidebar's edge to the buttons at the bar's right end
  room[] = K.bar_space(e).title
  @test room[] > 400px
end

@testset "a file of a plain folder gets Ladder's sidebar and top bar back" begin
  K.open!(e, joinpath(dir, "page.md")); frames()
  @test "Files" in names(side()) && "page.md" in texts(side()) && !("Sales" in texts(side())) && drawn("Files") !== nothing
  @test K.files_listed(e) && K.hidden_button(e) != ()
  @test K.bar_name(e) in bar() && !any(t -> startswith(t, "Shop ›"), bar())
  # Ladder's own name is in the middle of the bar, so the bar's left end takes as much room as its right end
  @test K.bar_space(e).title < room[] - 100px
end

@testset "a kind of folder makes the whole window" begin
  K.open!(e, kiosk); frames()
  @test K.window_object(e) isa KioskDirectory
  @test names(whole())[1] == "Kiosk" && "Only the kiosk" in texts(whole())
  # it left the sidebar and the page out, and kept the top bar with `window_over`
  @test !("Files" in names(whole())) && !("Editor" in names(whole())) && "TopBar" in names(whole())
  # the window that's drawn is that one
  @test names(K.describe_window(e))[1] == "Kiosk"
  K.open!(e, joinpath(dir, "page.md")); frames()
  @test names(K.describe_window(e))[1] == "Editor"
end

@testset "a window with no file is about the folder that its sidebar lists" begin
  K.go_folder!(e, shop)
  K.show_no_file!(e); frames()
  @test K.nofile(e)
  @test K.window_object(e) === K.directory(e) && K.window_object(e) isa ShopDirectory
  @test texts(side()) == ["Sales", "Bank", "Shop settings"]
end

@testset "a side menu with a compact form stays, narrower, while the sidebar is closed" begin
  rail() = texts(K.describe(e.nodes[:rail_menu]))
  K.open!(e, depot); frames()
  @test e.panel && K.side_least(e) == 60px && K.side_w(e) == K.panel_w(e)
  @test drawn("Rail menu").width == K.panel_w(e) && rail() == ["Depot menu"]
  # the menu is always there, and opens and closes itself, so the top bar's own button for the sidebar goes
  @test !(:panel in bar_buttons()) && :back in bar_buttons()
  # the menu's own button is in that place
  @test "fold" in bar()
  # the kind says that its page has no lock in the top bar. A plain folder's page has one.
  locked() = any(r -> r.from isa K.ReadOnly, (c.from for c in flat(K.rect(e.nodes[:topbar])) if hasproperty(c.from, :from)))
  @test !locked() && "New load" in bar()
  # what its page has there gets the room that it needs, so none of it lies over the middle of the bar
  ends() = drawn("TopBar").children[end]
  @test ends().width == 250px
  LOADS_W[] = 400px; frames()
  @test ends().width > 400px && drawn("Loads").width == 400px && drawn("Loads").left >= ends().left
  @test "New load" in bar()
  LOADS_W[] = 0px; frames()
  @test ends().width == 250px
  # and how much room its page has over it and at its sides
  @test K.page_top(e) == 2px && K.page_x(e) == 10px
  K.open!(e, joinpath(dir, "plain")); frames()
  @test locked() && !("New load" in bar())
  @test K.page_top(e) == K.PAGE_TOP && K.page_x(e) == K.PAGE_X
  K.open!(e, depot); frames()
  # closed, the menu is its compact form: as wide as the kind says, from the top of the window to the bottom
  K.toggle_panel!(e); sleep(0.3); frames()
  @test !e.panel && K.side_w(e) == 60px
  r = drawn("Rail menu")
  @test r !== nothing && r.left == 0px && r.top == 0px && r.width == 60px && r.height == 700px
  @test rail() == ["D"] && !(:panel in bar_buttons()) && !("fold" in bar())
  # the page has the room beside it
  @test K.page_room(e)[1] == 1000px - 60px
  @test K.text_width(e) <= 1000px - 60px - 2K.PAGE_X
  # Ladder's own sidebar has no compact form: closed, it's gone, and the page has the window's width
  K.open!(e, joinpath(dir, "page.md")); frames()
  @test K.side_least(e) == 0px && K.side_w(e) == 0px && drawn("Files") === nothing && :panel in bar_buttons()
  @test K.page_room(e)[1] == 1000px
  K.toggle_panel!(e); sleep(0.3); frames()
  @test drawn("Files") !== nothing && K.side_w(e) == K.panel_w(e)
end
