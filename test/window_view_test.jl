# Tests for the window of a kind of folder: `window_view` makes all that the
# window shows, `side_menu` what the sidebar holds, and `bread_crumb` the
# middle of the top bar. Each asks the object of the file or the folder that
# the window shows. See "the whole window" in main.jl. Run them with
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
@eval K settings_file() = $(joinpath(dir, "settings"))
const shop = joinpath(dir, "shop")
const kiosk = joinpath(dir, "kiosk")
mkpath(joinpath(shop, "sales"))
mkpath(kiosk)
write(joinpath(shop, "bank.md"), "# Bank\n")
write(joinpath(shop, "sales", "june.md"), "# June\n")
write(joinpath(dir, "page.md"), "# A page\n")

# A kind of folder with a menu of its own in the sidebar, as code from the
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
side() = K.describe(e.nodes[:sidebar])
bar() = texts(K.describe(e.nodes[:topbar]))
whole() = K.window_view(e, K.window_object(e))

@testset "the window of a plain file is Ladder's own" begin
  @test K.window_object(e) isa FS.File{:md} && string(K.window_object(e).path) == joinpath(dir, "page.md")
  @test K.side_menu(e, K.window_object(e)) isa K.FileMenu
  @test K.bread_crumb(e, K.window_object(e)) === e.nodes[:title]
  # the sidebar holds the tab of the file, the path of its folder and the folder's list
  @test "File menu" in names(side()) && "Folder" in names(side()) && "Tabs" in names(side())
  @test "page.md" in texts(side()) && "shop" in texts(side())
  @test K.files_listed(e) && K.hidden_button(e) != ()
  @test K.bar_name(e) in bar()
  @test names(whole())[1] == "Editor" && "Files" in names(whole()) && "TopBar" in names(whole())
end

@testset "a kind of folder fills the sidebar with a menu of its own" begin
  K.open!(e, shop); frames()
  @test K.window_object(e) isa ShopDirectory
  @test texts(side()) == ["Sales", "Bank", "Shop settings"]
  # the tabs, the folder's path and the tree of files are Ladder's own menu, so they aren't there
  @test "Shop menu" in names(side()) && !("File menu" in names(side())) && !("Folder" in names(side())) && !("Tabs" in names(side()))
  # the sidebar is still the sidebar: as wide as it was, and the menu starts under the top bar
  @test "Files" in names(side())
  r = K.rect(e.nodes[:sidebar])
  @test r.width == K.panel_w(e)
  # the button that shows the hidden files is for Ladder's tree of files, so it goes
  @test !K.files_listed(e) && K.hidden_button(e) == ()
  # the kind said nothing of the top bar for the folder itself, so the bar has the folder's name
  @test K.bread_crumb(e, K.window_object(e)) === e.nodes[:title] && K.bar_name(e) in bar()
end

@testset "it fills the sidebar for each thing that it holds, and names it in the top bar" begin
  K.open!(e, joinpath(shop, "bank.md")); frames()
  @test K.window_object(e) isa FS.File{:md} && K.window_object(e).parent isa ShopDirectory
  @test texts(side()) == ["Sales", "Bank", "Shop settings"]
  @test "Shop › bank.md" in bar() && !(K.bar_name(e) in bar())
  # a folder in it is of the kind, so a file in that folder has the menu and the path too
  K.open!(e, joinpath(shop, "sales", "june.md")); frames()
  @test K.window_object(e).parent isa ShopDirectory && string(K.window_object(e).parent.path) == joinpath(shop, "sales")
  @test texts(side()) == ["Sales", "Bank", "Shop settings"] && "Shop › june.md" in bar()
end

@testset "a file of a plain folder gets Ladder's sidebar and top bar back" begin
  K.open!(e, joinpath(dir, "page.md")); frames()
  @test "File menu" in names(side()) && "page.md" in texts(side()) && !("Sales" in texts(side()))
  @test K.files_listed(e) && K.hidden_button(e) != ()
  @test K.bar_name(e) in bar() && !any(t -> startswith(t, "Shop ›"), bar())
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
