# Tests for the pages of the Mac's Pictures folder and of a folder of
# screenshots: a grid of the pictures, the newest first, in groups of months or
# of days. See "the Mac's own folders: Pictures and the screenshots" in main.jl.
# Run them with `julia -O0 --project=. test/pictures_folder_test.jl`. They use a
# folder of their own, never the Mac's Pictures, and they click in a window
# that isn't on the screen. With `LADDER_SHOTS` set to a folder, they save
# pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

include(joinpath(@__DIR__, "png_fake.jl"))   # `write_png` writes a small picture
@use "./map_fake" => Fake                    # a pretend program for Apple's maps: no MapKit and no network

const px = K.px
@use "../macfolders" => M
@use "../picture_words" => W

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const trashed = String[]
K.trasher[] = path -> (push!(trashed, basename(path)); rm(path; recursive=true); true)

# The words of a picture come from a function of the test's own, and what's read is kept in the test's folder.
# One check further down asks macOS itself.
const said = Dict("Screenshot 2.png" => "Invoice 1042\nTotal  \$310.00", "Screenshot 3.png" => "A page about boats")
const asked = String[]
W.reader[] = path -> (push!(asked, basename(path)); get(said, basename(path), ""))
W.words_file[] = joinpath(dir, "words.tsv")
# The map's picture comes from the pretend program, and is kept in the test's folder
K.Maps.HELPER[] = Fake.helper
K.MEDIA_CACHE[] = joinpath(dir, "media")
# Where a photo was taken comes from a function of the test's own. No picture says it until the check of the map.
const taken_at = Dict{String,Any}()
K.MacPages.TILE_PLACER[] = path -> get(taken_at, basename(path), nothing)

const pics = mkpath(joinpath(dir, "Pictures"))
K.PLACE_KINDS[pics] = K.PicturesDirectory
write(joinpath(dir, "page.md"), "# A page\n")

const day = 86400
"Make the picture `name` in `folder`, as if it was taken `ago` seconds ago"
taken(folder, name, ago, colour, w=120, h=90) = begin
  path = write_png(joinpath(folder, name), w, h, colour isa Function ? colour : (x, y) -> colour)
  run(`touch -t $(Libc.strftime("%Y%m%d%H%M.%S", time() - ago)) $path`)
  path
end
taken(pics, "beach.png", 3600, BLUE)
# A tall picture and a wide one, each with its middle third in another colour: a square shows only that middle
taken(pics, "garden.png", 2 * 3600, (x, y) -> 40 < y <= 80 ? GREEN : RED, 40, 120)
taken(pics, "wall.png", 40day, (x, y) -> 100 < x <= 200 ? BLUE : RED, 300, 100)
taken(pics, "sand.png", 41day, SAND)
taken(pics, "old house.png", 400day, RED)
mkpath(joinpath(pics, "Holiday"))
taken(joinpath(pics, "Holiday"), "boat.png", 5day, BLUE)
mkpath(joinpath(pics, "Screenshots"))
taken(joinpath(pics, "Screenshots"), "Screenshot 1.png", 600, SAND)
taken(joinpath(pics, "Screenshots"), "Screenshot 2.png", day + 600, GREEN)
taken(joinpath(pics, "Screenshots"), "Screenshot 3.png", day + 1200, BLUE)
mkpath(joinpath(pics, "Photos Library.photoslibrary"))
write(joinpath(pics, "list.txt"), "not a picture\n")
write(joinpath(pics, ".hidden.png"), "hidden")

const e = K.build_editor(joinpath(dir, "page.md"))
e.panel = true   # the sidebar is open, with no slide
const w = Window(e, size=(1100px, 760px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "pictures-$name.png"), w)
view(folder=pics) = e.nodes[(:tiles, folder)]
again(folder=pics) = (view(folder).read = 0.0; frames())
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press() = (w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1); w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2))
# A click here is one click, however soon it comes after the last one. Two clicks are `click` and then `press`.
click(place, held...) = begin
  foreach(v -> v isa K.MacPages.TilesView && (v.clicked = (0.0, "")), values(e.nodes))
  at(place); foreach(h -> w.keys |= h, held); press(); foreach(h -> w.keys ⊻= h, held); frames(1)
end
"Where the middle of the square of `name` is in the window"
square(name, folder=pics) = begin
  v = view(folder)
  i = findfirst(l -> l isa Vector && any(t -> t.name == name, l), v.lines)
  k = findfirst(t -> t.name == name, v.lines[i])
  r = rect(v)
  (K.num(r.left) + (k - 0.5) * v.side + (k - 1) * K.MacPages.TILE_GAP, K.num(r.top) + K.MacPages.TILES_HEAD_H + v.tops[i] + v.side / 2)
end
key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
"What the grid shows, from the top: the words over each group, and the names of each row"
shown(folder=pics) = [l isa Vector ? [t.name for t in l] : l for l in view(folder).lines]
chosen(folder=pics) = K.MacPages.tiles_chosen(view(folder))

@testset "a click on Pictures in the sidebar shows it in the page as a grid" begin
  @test K.object(e, pics) isa K.PicturesDirectory
  K.open!(e, K.object(e, pics))
  frames(8)   # a few small pictures are made in each frame
  @test e.buf.path == pics && e.folder == pics
  @test view() isa K.MacPages.TilesView && rect(view()) !== nothing
  @test K.page_fills(e, K.directory(e))
end

@testset "the folders come first, then the pictures by month, the newest first, then the other files" begin
  @test shown() == ["Folders", ["Holiday", "Screenshots"],
                    M.month_name(time()), ["beach.png", "garden.png"],
                    M.month_name(time() - 40day), ["wall.png", "sand.png"],
                    M.month_name(time() - 400day), ["old house.png"],
                    "Other files", ["list.txt", "Photos Library.photoslibrary"]]
  v = view()
  @test v.side >= K.MacPages.TILE_SIDE
  # Each picture has a small picture of its own, and a file that isn't a picture has the Finder's icon
  @test K.MacPages.TILE_PICTURES[joinpath(pics, "beach.png")][2] !== nothing
  shot("grid")
end

@testset "a click chooses a square, and ⌘ or ⇧ with a click chooses more" begin
  click(square("garden.png"))
  @test chosen() == ["garden.png"]
  click(square("sand.png"), Keys.cmd)
  @test chosen() == ["garden.png", "sand.png"]
  click(square("beach.png"))
  click(square("wall.png"), Keys.shft)
  @test chosen() == ["beach.png", "garden.png", "wall.png"]
  shot("chosen")
  # A click between the squares chooses nothing
  r = rect(view())
  click((K.num(r.left) + K.num(r.width) - 3, K.num(r.top) + K.MacPages.TILES_HEAD_H + 8))
  @test chosen() == []
end

@testset "the arrows go from square to square" begin
  click(square("beach.png"))
  key(Keys.right)
  @test chosen() == ["garden.png"]
  key(Keys.right)
  @test chosen() == ["wall.png"]
  key(Keys.left, Keys.shft)
  @test chosen() == ["garden.png", "wall.png"]
  key(Keys.a, Keys.cmd)
  @test length(chosen()) == 9
end

@testset "what's typed in the field leaves the names that have it" begin
  v = view()
  K.focus(v.field)
  typed("SAN")
  @test shown() == [M.month_name(time() - 41day), ["sand.png"]]
  shot("found")
  typed("zzz")
  @test shown() == []
  v.field.text = ""
  frames()
  @test length(shown()) == 10   # five groups, each with its words and one row
end

@testset "two clicks show a picture, and ⌘⌫ moves what's chosen to the Trash" begin
  click(square("beach.png"))
  at(square("beach.png")); press()
  @test e.buf.path == joinpath(pics, "beach.png")
  K.go_back!(e)
  frames()
  @test e.buf.path == pics
  # The oldest picture is under the window's bottom edge, so the page scrolls to it first
  e.scroll.offset = 320px
  frames()
  click(square("old house.png"))
  @test chosen() == ["old house.png"]
  key(Keys.backspace, Keys.cmd)
  @test trashed == ["old house.png"]
  again()
  @test !any(l -> l isa Vector && any(t -> t.name == "old house.png", l), view().lines)
  e.scroll.offset = 0px
  frames()
end

@testset "two clicks on a folder show it as a grid of its own" begin
  click(square("Holiday"))
  at(square("Holiday")); press()
  frames(6)
  holiday = joinpath(pics, "Holiday")
  @test e.buf.path == holiday && e.folder == holiday
  @test K.directory(e) isa K.PicturesDirectory
  @test shown(holiday) == [M.month_name(time() - 5day), ["boat.png"]]
end

@testset "a folder called Screenshots shows its pictures by the day" begin
  shots = joinpath(pics, "Screenshots")
  K.open!(e, K.FS.get(K.FSPath(shots)))
  frames(6)
  @test K.directory(e) isa K.ScreenshotsDirectory
  @test view(shots).days
  @test shown(shots) == ["Today", ["Screenshot 1.png"], "Yesterday", ["Screenshot 2.png", "Screenshot 3.png"]]
  shot("screenshots")
end

"Draw until every picture that waits has been read"
read_all() = begin
  started = time()
  frames(2)
  while W.reading() > 0 && time() - started < 30
    sleep(0.01)
    frames(1)
  end
  frames()
end

@testset "what's typed finds the pictures that show those words" begin
  shots = joinpath(pics, "Screenshots")
  v = view(shots)
  K.focus(v.field)
  typed("invoice")
  read_all()
  @test shown(shots) == ["Yesterday", ["Screenshot 2.png"]]
  # Each picture of the folder was read once. The pictures of the Pictures folder were read by the check before.
  @test sort(filter(startswith("Screenshot"), asked)) == ["Screenshot 1.png", "Screenshot 2.png", "Screenshot 3.png"]
  shot("words")
  # The words are in small letters with one space between them, whatever the picture has
  @test W.words(joinpath(shots, "Screenshot 2.png")) == "invoice 1042 total \$310.00"
  v.field.text = "TOTAL \$310"
  read_all()
  @test shown(shots) == ["Yesterday", ["Screenshot 2.png"]]
  # A name counts too, beside the words
  v.field.text = "boats"
  read_all()
  @test shown(shots) == ["Yesterday", ["Screenshot 3.png"]]
  v.field.text = "screenshot 1"
  read_all()
  @test shown(shots) == ["Today", ["Screenshot 1.png"]]
  v.field.text = ""
  frames()
  @test length(K.MacPages.tiles_shown(v)) == 3
end

@testset "each picture is read once, and what was read is kept in a file" begin
  shots = joinpath(pics, "Screenshots")
  n = length(asked)
  @test isfile(W.words_file[])
  # A new start of Ladder reads the file, and asks about no picture again
  W.loaded[] = ""
  @test W.words(joinpath(shots, "Screenshot 3.png")) == "a page about boats"
  @test length(asked) == n && W.reading() == 0
  # A picture that changed is read again
  run(`touch $(joinpath(shots, "Screenshot 3.png"))`)
  @test W.words(joinpath(shots, "Screenshot 3.png")) === nothing
  started = time()
  while W.reading() > 0 && time() - started < 30; sleep(0.01); end
  @test length(asked) == n + 1
  @test W.words(joinpath(shots, "Screenshot 3.png")) == "a page about boats"
end

if Sys.isapple()
  @testset "macOS reads the words of a real picture" begin
    file = joinpath(dir, "window.png")
    K.open!(e, K.object(e, pics) === nothing ? pics : pics)
    frames()
    save_png(file, w)   # the window shows the page of the Pictures folder
    text = lowercase(W.read_words(file))
    @test occursin("pictures", text)
  end
end

@testset "the photos that say where they were taken have a dot on a map over the grid" begin
  K.open!(e, pics)
  K.go_folder!(e, pics)
  frames()
  v = view()
  empty!(Fake.calls)
  @test !(:map in v.lines) && isempty(v.spots)   # no photo says where it was taken
  taken_at["beach.png"] = (-33.8908, 151.2743)    # a beach in Sydney
  taken_at["garden.png"] = (-37.8304, 144.9796)   # a garden in Melbourne
  empty!(K.MacPages.TILE_PLACES)
  frames()
  @test v.lines[1] == "Where 2 photos were taken" && v.lines[2] === :map
  @test v.lines[3] == "Folders"   # the rest of the grid is under the map
  @test sort!(collect(keys(v.spots))) == ["beach.png", "garden.png"]
  # The map's picture is asked for when its width has stayed for half a second
  started = time()
  while (isempty(Fake.calls) || !any(isfile, readdir(K.MEDIA_CACHE[], join=true))) && time() - started < 20
    sleep(0.05)
    frames(1)
  end
  frames()
  @test length(Fake.calls) == 1
  call = Fake.calls[1]
  @test call.wide == 100 * floor(Int, v.wide / 100) && call.tall == K.Maps.TALL
  @test -37.9 < call.centre[1] < -33.8 && 144.9 < call.centre[2] < 151.3   # between the two places
  # Each photo has a dot, and Sydney is to the right of Melbourne and above it
  pins = Dict(name => (x, y) for (name, x, y) in v.pins)
  @test length(pins) == 2
  @test pins["beach.png"][1] > pins["garden.png"][1] && pins["beach.png"][2] < pins["garden.png"][2]
  shot("map")
  # A click on a dot chooses its photo
  i = findfirst(==(:map), v.lines)
  # The grid scrolls to a photo that's chosen, so the map is looked for again before each click
  spot(name) = (r = rect(v); (K.num(r.left) + pins[name][1], K.num(r.top) + K.MacPages.TILES_HEAD_H + v.tops[i] + pins[name][2]))
  click(spot("garden.png"))
  @test chosen() == ["garden.png"]
  e.scroll.offset = 0px
  frames()
  click(spot("beach.png"))
  @test chosen() == ["beach.png"]
  # What's typed leaves the dots of the photos that it leaves
  K.focus(v.field)
  typed("garden")
  @test collect(keys(v.spots)) == ["garden.png"]
  v.field.text = ""
  frames()
  # A folder of screenshots has no map
  taken_at["Screenshot 1.png"] = (-33.8908, 151.2743)
  shots = joinpath(pics, "Screenshots")
  K.open!(e, K.FS.get(K.FSPath(shots)))
  frames()
  @test !(:map in view(shots).lines)
end

@testset "the small pictures that haven't shown for the longest are forgotten" begin
  n = length(K.MacPages.TILE_PICTURES)
  for i in 1:K.MacPages.TILES_KEPT
    K.MacPages.TILE_PICTURES["/nowhere/$i.png"] = (0.0, nothing, time() - 1000 - i)
  end
  budget = Ref(1)
  t = K.MacPages.Tile(name="wall.png", path=joinpath(pics, "wall.png"), kind=:picture, when=0.0)
  K.MacPages.tile_picture(e, t, budget)
  @test length(K.MacPages.TILE_PICTURES) < K.MacPages.TILES_KEPT + n
  @test haskey(K.MacPages.TILE_PICTURES, t.path)
  filter!(p -> !startswith(p[1], "/nowhere/"), K.MacPages.TILE_PICTURES)
end

close(w)
delete!(K.PLACE_KINDS, pics)
W.reader[] = W.read_words
W.words_file[] = W.usual_words_file()
W.loaded[] = ""
K.MacPages.TILE_PLACER[] = K.photo_place
K.Maps.HELPER[] = K.Maps.run_program
K.MEDIA_CACHE[] = ""
