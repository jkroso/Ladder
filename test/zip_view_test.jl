# Tests for a zip file in the page: the list of what it holds, one file shown
# from inside it, and the button that unpacks it. See "a zip file" in zip_page.jl,
# and zip.jl. Run them with `julia -O0 --project=. test/zip_view_test.jl`. They
# make a zip file with the Mac's own `zip`, and click in a window that isn't on
# the screen. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

const px = K.px
const Z = K.Zips

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
K.ZipPages.ZIP_ROOM[] = joinpath(dir, "room")   # what's unpacked to be shown goes here, not beside the Mac's caches
const work = joinpath(dir, "work")
const src = joinpath(dir, "src", "plans")
mkpath(work)
mkpath(joinpath(src, "house", "old"))
write(joinpath(src, "Readme.md"), "# Plans\n\nWhat's here.\n")
write(joinpath(src, "house", "notes.md"), "# Notes\n\nOf the house.\n")
write(joinpath(src, "house", "old", "first.txt"), "first\n")
write(joinpath(work, "page.md"), "# A page\n")
const file = joinpath(work, "plans.zip")
cd(() -> run(pipeline(`zip -r -q $file plans`, stdout=devnull, stderr=devnull)), dirname(src))
# A zip file with two things at its top
const two = joinpath(work, "two things.zip")
cd(() -> run(pipeline(`zip -q $(two) Readme.md house/notes.md`, stdout=devnull, stderr=devnull)), src)

const e = K.build_editor(joinpath(work, "page.md"))
e.panel = true   # the sidebar is open, with no slide
const w = Window(e, size=(1100px, 760px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "zip-$name.png"), w)
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = begin
  at(place)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2)
end
middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
view(path=file) = e.nodes[(:zip, path)]
"The names of the lines that the list shows, from the top"
lines(path=file) = [en.name for en in K.ZipPages.zip_lines(view(path))]
"Draw until the program that unpacks a zip file is done"
unpacked(path) = begin
  started = time()
  while view(path).job !== nothing && time() - started < 20
    sleep(0.02)
    frames(1)
  end
  frames()
end

@testset "a zip file shows what it holds, with the one folder at its top open" begin
  K.open!(e, file)
  frames()
  @test e.buf.path == file
  @test lines() == ["plans/", "plans/house/", "plans/Readme.md"]
  shot("list")
end

@testset "a click on a folder opens it, and one more closes it" begin
  click(middle(view().rows["plans/house/"]))
  @test lines() == ["plans/", "plans/house/", "plans/house/old/", "plans/house/notes.md", "plans/Readme.md"]
  click(middle(view().rows["plans/house/old/"]))
  @test lines()[3:4] == ["plans/house/old/", "plans/house/old/first.txt"]
  shot("open")
  click(middle(view().rows["plans/house/"]))
  @test lines() == ["plans/", "plans/house/", "plans/Readme.md"]
  click(middle(view().rows["plans/house/"]))
  # A folder that was open in a folder that closed is open again
  @test "plans/house/old/first.txt" in lines()
end

@testset "a click on a file shows that file, and the zip file isn't unpacked" begin
  click(middle(view().rows["plans/house/notes.md"]))
  @test endswith(e.buf.path, joinpath("plans", "house", "notes.md"))
  @test startswith(e.buf.path, K.ZipPages.ZIP_ROOM[])
  @test e.buf.lines[1] == "# Notes"
  @test e.buf.fixed            # a change wouldn't go into the zip file
  @test e.folder == work       # the sidebar stays
  @test readdir(work) == ["page.md", "plans.zip", "two things.zip"]
  K.go_back!(e)
  frames()
  @test e.buf.path == file
end

@testset "the button unpacks one thing at the top as it is" begin
  click(middle(view().buttons[:unpack]))
  unpacked(file)
  @test view().said == ""
  @test isdir(joinpath(work, "plans"))
  @test read(joinpath(work, "plans", "house", "old", "first.txt"), String) == "first\n"
  @test e.folder == joinpath(work, "plans")   # the sidebar shows what came out
  @test !any(startswith(".unpacking"), readdir(work))
  # A second time, the folder gets a name that's free, as in the Finder
  click(middle(view().buttons[:unpack]))
  unpacked(file)
  @test isdir(joinpath(work, "plans 2"))
end

@testset "more than one thing at the top go into a folder with the zip file's name" begin
  K.open!(e, two)
  frames()
  @test lines(two) == ["house/", "Readme.md"]
  click(middle(view(two).buttons[:unpack]))
  unpacked(two)
  @test sort(readdir(joinpath(work, "two things"))) == ["Readme.md", "house"]
  @test e.folder == joinpath(work, "two things")
end

@testset "a file that isn't a zip file says so" begin
  bad = joinpath(work, "bad.zip")
  write(bad, "These are words, and not a zip file. " ^ 4)
  K.open!(e, bad)
  frames()
  @test view(bad).zip isa String
  @test rect(view(bad)) !== nothing
  shot("bad")
end

close(w)
