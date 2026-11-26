# Tests for the folder that holds the files a page makes, and for the hidden
# files in the sidebar. See `page_media` and `hidden!` in main.jl. Run them with
# `julia -O0 --project=. test/media_folder_test.jl`. They use a window that
# isn't on the screen, and a folder of their own.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
# The setting that these tests change goes to a file of their own, not to the one that Ladder uses
K.SETTINGS_FILE[] = joinpath(dir, "kept", "settings")

const folder = joinpath(dir, "notes")
mkpath(folder)
const page = joinpath(folder, "notes.md")
write(page, "# Notes\n\nSome words.\n")
write(joinpath(folder, "other.md"), "# Other\n")
write(joinpath(folder, ".secret.md"), "# Secret\n")
write(joinpath(folder, ".DS_Store"), "")
mkpath(joinpath(folder, ".git"))

const e = K.build_editor(page)
e.panel = true
const w = Window(e, size=(1000px, 700px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()

names() = basename.(e.listed)
click(node) = begin
  r = rect(node)
  x, y = r.left + r.width / 2, r.top + r.height / 2
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  frames()
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  frames()
end
press(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end

const shots = get(ENV, "MEDIA_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "a picture that's pasted goes in the .media folder beside the page" begin
  path = K.keep_pasted(e, "png", UInt8[1, 2, 3])
  @test dirname(path) == joinpath(folder, ".media")
  @test read(path) == UInt8[1, 2, 3]
  @test occursin(r"^pasted-\d{8}-\d{6}\.png$", basename(path))
  # The page names the file from its own folder
  @test K.markdown_for(e, path) == "![$(splitext(basename(path))[1])](.media/$(basename(path)))"
  # A second one in the same second gets a name of its own
  @test K.keep_pasted(e, "png", UInt8[4]) != path
  # The folder of the page has no new file in it
  @test sort(filter(n -> !startswith(n, '.'), readdir(folder))) == ["notes.md", "other.md"]
end

@testset "a copy of a temporary file goes there too, under its own name" begin
  from = joinpath(mktempdir(), "shot.png")
  write(from, "picture")
  copy = K.keep_copy(e, from)
  @test copy == joinpath(folder, ".media", "shot.png")
  @test read(copy, String) == "picture"
  @test K.keep_copy(e, from) == joinpath(folder, ".media", "shot-2.png")
end

@testset "a new recording goes there, and a recording that's there keeps its name" begin
  path = K.new_recording(e)
  @test dirname(path) == joinpath(folder, ".media")
  @test occursin(r"^recording-\d{4}-\d\d-\d\d-\d{4}\.m4a$", basename(path))
  write(path, "")
  @test K.new_recording(e) == replace(path, ".m4a" => "-2.m4a")
  rm(path)
  # A line that names the file from the page's folder is a line for that sound file
  @test K.sound_file(folder, "![Recording](.media/$(basename(path)))") == path
end

@testset "the sidebar leaves hidden files out until it's asked for them" begin
  @test names() == ["notes.md", "other.md"]
  K.hidden!(e, true)
  # The folders come first, and .DS_Store never shows
  @test names() == [".git", ".media", ".secret.md", "notes.md", "other.md"]
  @test ".secret.md" in basename.(e.files)
  K.hidden!(e, false)
  @test names() == ["notes.md", "other.md"]
end

@testset "the button beside the sidebar's own button shows them, and so does ⌘⇧." begin
  b = e.nodes[:hidden]
  @test rect(b) !== nothing
  # The button is in the top bar, just right of the button that shows the sidebar, and over the sidebar
  r, panel = rect(b), rect(e.nodes[:panel])
  @test r.top == panel.top && r.height == panel.height
  @test 0px <= r.left - (panel.left + panel.width) <= 4px
  @test r.left + r.width <= K.panel_w(e)
  @test b.icon == "eye-slash"
  shot("left-out")
  click(b)
  @test e.hidden && ".media" in names()
  @test b.icon == "eye"
  @test K.tip(b) == "Leave out hidden and ignored files  ⌘⇧."
  shot("shown")
  click(b)
  @test !e.hidden && !(".media" in names())
  @test K.tip(b) == "Show hidden and ignored files  ⌘⇧."
  press(Keys.period, Keys.cmd, Keys.shft)
  @test e.hidden
  press(Keys.period, Keys.cmd, Keys.shft)
  @test !e.hidden
end

@testset "a click on the media folder lists what a page made" begin
  K.hidden!(e, true)
  K.go_folder!(e, joinpath(folder, ".media"))
  @test "shot.png" in names() && any(startswith("pasted-"), names())
  # Without hidden files, the folder still lists them: their own names have no dot
  K.hidden!(e, false)
  @test "shot.png" in names()
  K.go_folder!(e, folder)
end

@testset "the button shows only while the sidebar does" begin
  b = e.nodes[:hidden]
  K.toggle_panel!(e)
  frames()
  @test !e.panel && isempty(K.hidden_button(e))
  K.toggle_panel!(e)
  frames()
  @test K.hidden_button(e) == (b,)
end

@testset "the settings file keeps the choice" begin
  e.remember = true
  K.hidden!(e, true)
  @test occursin("\nhidden=true\n", read(K.settings_file(), String))
  other = K.build_editor(page)
  @test basename.(other.listed) == ["notes.md", "other.md"]
  K.load_settings!(other)
  @test other.hidden && ".media" in basename.(other.listed)
  K.hidden!(e, false)
  @test occursin("\nhidden=false\n", read(K.settings_file(), String))
  e.remember = false
end

close(w)
