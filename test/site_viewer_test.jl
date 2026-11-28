# Tests for a site with a viewer of its own: a kind of folder for the site's
# folder in the browser folder, whose method of `open_address!` shows the
# site's pages. See "a site with a viewer of its own" in remote_page.jl. Run
# them with `julia -O0 --project=. test/site_viewer_test.jl`. A function of the
# tests stands in for `curl`, so they use no network. The window isn't on the
# screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/URI.jl/FSPath" FSPath
const px = K.px
const FS = K.FS

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const browser = joinpath(dir, "Browser")
const was_folder, was_getter, was_browser = K.BROWSER_FOLDER[], K.PAGE_GETTER[], K.BROWSER[]
K.BROWSER_FOLDER[] = browser
at(p) = joinpath(browser, p)

const asked = String[]    # each address that a server was asked for
const outside = String[]  # each address that went to your browser
K.PAGE_GETTER[] = (address, file, about) -> begin
  push!(asked, address)
  write(file, "# From the server\n"); write(about, "$address\ntext/markdown\n200\n")
  () -> true
end
K.BROWSER[] = url -> (push!(outside, url); nothing)

# A shop's site with a viewer: each address of the site is a folder of the site's folder, and the page shows
# the folder's name. The site has a second name, whose folder isn't there.
@def struct ShopSite <: K.AbstractDirectory end
@def struct ShopItem <: K.AbstractDirectory end
FS.kind(::ShopSite, path::FSPath) = ShopItem
FS.kind(::ShopItem, path::FSPath) = ShopItem
FS.kinds[FSPath(at("shop.test"))] = ShopSite
FS.kinds[FSPath(at("www.shop.test"))] = ShopSite
const opened = Any[]   # what each call of the kind's method was given
K.open_address!(e, d::ShopSite, address; record=true, reload=false) = begin
  push!(opened, (string(d.path), address, record, reload))
  occursin("/server/", address) && return false   # a page that the kind leaves to Ladder
  rest = strip(replace(address, r"^https?://[^/]*" => "", r"[?#].*$" => ""), '/')
  path = joinpath(at("shop.test"), rest)
  mkpath(path)
  K.open!(e, path; record)
  true
end
K.page_view(e, d::Union{ShopSite,ShopItem}) = K.Box(K.Text("The shop's $(d.path.name)", size=14px), name="Shop page")

write(joinpath(dir, "mine.md"), "# Mine\n\nAn [item](https://shop.test/items/4) and a card:\n\n![An item](https://www.shop.test/items/5)\n")
const e = K.build_editor(joinpath(dir, "mine.md"))
const w = Window(e, size=(1000px, 700px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()

"Each Text in the layout `node`, in the order they read"
texts(node, out=String[]) = begin
  node isa K.Text && push!(out, node.text)
  hasproperty(node, :children) && foreach(c -> texts(c, out), node.children)
  out
end
flat(r, out=Any[]) = (push!(out, r); hasproperty(r, :children) && foreach(c -> flat(c, out), r.children); out)
"True when the window draws the part called `name`"
drawn(name) = any(r -> hasproperty(r.from, :name) && r.from.name == name, flat(K.rect(e)))

@testset "the folder of a site, when it has a kind" begin
  @test !isdir(at("shop.test"))
  d = K.site_folder("https://shop.test/items/3")
  @test d isa ShopSite && string(d.path) == at("shop.test")   # the folder needn't be there
  @test K.site_folder("https://SHOP.test") isa ShopSite
  @test K.site_folder("https://www.shop.test/a") isa ShopSite
  @test K.site_folder("https://plain.test/a") === nothing   # a site with no viewer
  @test K.site_folder("notes.md") === nothing && K.site_folder("https://") === nothing && K.site_folder("mailto:sam@shop.test") === nothing
  # A site's folder that's there, and plain, has no viewer either
  mkpath(at("plain.test"))
  @test K.site_folder("https://plain.test/a") === nothing
end

@testset "an address of the site shows as its kind shows it, and no server is asked" begin
  K.get_page!(e, "https://shop.test/items/3")
  frames()
  @test opened == [(at("shop.test"), "https://shop.test/items/3", true, false)]
  @test e.buf.path == at("shop.test/items/3") && isempty(asked) && !haskey(e.nodes, :page_asked)
  @test drawn("Shop page")
  @test K.web_address(e.buf.path) == "https://shop.test/items/3/"
  # Navigate goes the same way, and so does the site's other name
  empty!(opened)
  K.navigate!(e, "www.shop.test/items/7")
  frames()
  @test opened == [(at("www.shop.test"), "https://www.shop.test/items/7", true, false)]
  @test e.buf.path == at("shop.test/items/7") && isempty(asked) && !isdir(at("www.shop.test"))
  # Back shows the page that left
  K.go_back!(e)
  frames()
  @test e.buf.path == at("shop.test/items/3")
end

@testset "Reload Page asks the kind again" begin
  empty!(opened)
  K.reload_page!(e)
  frames()
  @test opened == [(at("shop.test"), "https://shop.test/items/3/", false, true)]
  @test e.buf.path == at("shop.test/items/3") && isempty(asked)
end

@testset "a page that the kind leaves to Ladder comes from the server" begin
  empty!(opened)
  @test !K.site_shows!(e, "https://shop.test/server/terms.md")
  K.get_page!(e, "https://shop.test/server/terms.md")
  frames(6)
  # Ladder asks for the page, and for the `.ladder` page of each web folder that it's in
  @test asked[1] == "https://shop.test/server/terms.md" && all(a -> a == asked[1] || endswith(a, "/.ladder"), asked)
  @test e.buf.path == at("shop.test/server/terms.md") && e.buf.lines[1] == "# From the server"
  empty!(asked)
end

@testset "a link and a link card of a page of your own" begin
  K.open!(e, joinpath(dir, "mine.md"))
  frames()
  empty!(opened)
  K.follow!(e, "https://shop.test/items/4")
  frames()
  @test e.buf.path == at("shop.test/items/4") && isempty(asked) && isempty(outside)
  @test only(opened)[2] == "https://shop.test/items/4"
  # A site with no viewer has nothing to show here
  @test !K.site_shows!(e, "https://plain.test/a") && e.buf.path == at("shop.test/items/4")
end

K.BROWSER_FOLDER[], K.PAGE_GETTER[], K.BROWSER[] = was_folder, was_getter, was_browser
delete!(FS.kinds, FSPath(at("shop.test")))
delete!(FS.kinds, FSPath(at("www.shop.test")))
