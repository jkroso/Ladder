# Tests for the pages of the Mac's Downloads folder and of its Trash: a list of
# what the folder holds, the newest first, in groups of days. See "the Mac's own
# folders: Downloads and the Trash" in main.jl, and macfolders.jl. Run them
# with `julia -O0 --project=. test/downloads_test.jl`. They use folders of their
# own, never the Mac's Downloads or its Trash, and they click in a window that
# isn't on the screen. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

include(joinpath(@__DIR__, "dsstore_fake.jl"))   # `store` makes the bytes of a .DS_Store file

const px = K.px
const M = K.Mac
const T = K.Trash

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
# What goes to the Trash here is only removed
const trashed = String[]
K.trasher[] = path -> (push!(trashed, basename(path)); rm(path; recursive=true); true)

const down = mkpath(joinpath(dir, "Downloads"))
const bin = mkpath(joinpath(dir, "Trash"))
const disk = mkpath(joinpath(dir, "disk"))
const desk = mkpath(joinpath(disk, "Users", "sam", "Desktop"))
K.PLACE_KINDS[down] = K.DownloadsDirectory
K.PLACE_KINDS[bin] = K.TrashDirectory
K.TRASH_DISK[] = disk
write(joinpath(dir, "page.md"), "# A page\n\n[Downloads](Downloads) and [the Trash](Trash)\n")

const day = 86400
"Make the file `name` in `folder`, as if it came `ago` seconds ago from `site`. macOS has no way to set when a file came, so the test says it."
came(folder, name, ago; site="", text="some bytes") = begin
  path = joinpath(folder, name)
  endswith(name, "/") ? mkpath(path) : write(path, text)
  path = String(rstrip(path, '/'))
  K.LIST_FACTS[path] = (stat(path).mtime, K.ListItem(name=basename(path), path=path, folder=isdir(path), size=isdir(path) ? 0 : filesize(path),
                                                     when=time() - ago, site=site))
  path
end
came(down, "form.pdf", 600, site="council.example.org", text="x"^48_000)
came(down, "photo.png", 2 * 3600)
came(down, "installer.dmg", day + 3600, site="example.com")
came(down, "old/", 3day)
came(down, "notes.md", 4day, text="# Notes\n")
came(down, "ancient.zip", 400day)
came(down, ".hidden", 60)

came(bin, "plan.pdf", 300)
came(bin, "notes 10.42.07 am.md", 3600, text="# Notes\n")
came(bin, "stray.txt", 2day)
write(joinpath(bin, ".DS_Store"), store([
  ("plan.pdf", "ptbL", "Users/sam/Desktop/"), ("plan.pdf", "ptbN", "plan.pdf"),
  ("notes 10.42.07 am.md", "ptbL", "Users/sam/Desktop/"), ("notes 10.42.07 am.md", "ptbN", "notes.md")]))

const e = K.build_editor(joinpath(dir, "page.md"))
e.panel = true   # the sidebar is open, with no slide
const w = Window(e, size=(1100px, 760px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "downloads-$name.png"), w)
view(folder=down) = e.nodes[(:filelist, folder)]
"Read the folder again now, as a second does"
again(folder=down) = (view(folder).read = 0.0; frames())
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press() = (w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1); w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2))
# A click here is one click, however soon it comes after the last one. Two clicks are `click` and then `press`.
click(place, held...) = begin
  foreach(v -> v isa K.FileList && (v.clicked = (0.0, "")), values(e.nodes))
  at(place); foreach(h -> w.keys |= h, held); press(); foreach(h -> w.keys ⊻= h, held); frames(1)
end
middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
"Where the middle of the line of `name` is in the window"
line(name, folder=down) = begin
  v = view(folder)
  i = findfirst(l -> l isa K.ListItem && l.name == name, v.lines)
  r = rect(v)
  (K.num(r.left) + 200, K.num(r.top) + K.filelist_head_h(v) + K.LIST_ROW_H * (i - 0.5))
end
key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
"What the list shows, from the top: the words over each group, and each name"
shown(folder=down) = [l isa K.ListItem ? l.name : "— " * l for l in view(folder).lines]
chosen(folder=down) = K.filelist_chosen(view(folder))
menu() = (ps = [p for p in popups(w) if p.key == :menu]; isempty(ps) ? nothing : only(ps).content)
choose(name) = (m = menu(); foreach(_ -> key(Keys.down), 1:findfirst(==(name), m.items)); key(Keys.enter))

@testset "a click on Downloads in the sidebar shows it in the page, and the sidebar lists it" begin
  @test K.object(e, down) isa K.DownloadsDirectory
  @test K.entry_icon(K.object(e, down)) == "download"
  K.open!(e, K.object(e, down))
  frames()
  @test e.buf.path == down && e.folder == down
  @test view() isa K.FileList && rect(view()) !== nothing
end

@testset "the newest thing is first, under the words of its group of days" begin
  @test shown() == ["— Today", "form.pdf", "photo.png", "— Yesterday", "installer.dmg", "— Previous 7 Days", "old", "notes.md",
                    "— " * M.month_name(time() - 400day), "ancient.zip"]
  # The sidebar lists the folder the same way, and neither shows a hidden file
  @test basename.(e.listed) == ["form.pdf", "photo.png", "installer.dmg", "old", "notes.md", "ancient.zip"]
  shot("list")
  K.hidden!(e, true)
  again()
  @test shown()[2] == ".hidden"
  K.hidden!(e, false)
  again()
end

@testset "a click chooses a line, and ⌘ or ⇧ with a click chooses more" begin
  click(line("photo.png"))
  @test chosen() == ["photo.png"]
  click(line("notes.md"), Keys.cmd)
  @test chosen() == ["photo.png", "notes.md"]
  click(line("photo.png"), Keys.cmd)
  @test chosen() == ["notes.md"]
  click(line("form.pdf"))
  click(line("installer.dmg"), Keys.shft)
  @test chosen() == ["form.pdf", "photo.png", "installer.dmg"]
  shot("chosen")
  # A click on the words of a group chooses nothing
  r = rect(view())
  click((K.num(r.left) + 200, K.num(r.top) + K.filelist_head_h(view()) + K.LIST_ROW_H * 0.5))
  @test chosen() == []
end

@testset "the arrows go from line to line, past the words of a group" begin
  click(line("photo.png"))
  key(Keys.down)
  @test chosen() == ["installer.dmg"]
  key(Keys.down, Keys.shft)
  @test chosen() == ["installer.dmg", "old"]
  key(Keys.up)
  @test chosen() == ["installer.dmg"]
  key(Keys.a, Keys.cmd)
  @test length(chosen()) == 6
end

@testset "two clicks show a file, and Return does too" begin
  click(line("notes.md"))
  at(line("notes.md")); press()
  @test e.buf.path == joinpath(down, "notes.md")
  K.go_back!(e)
  frames()
  @test e.buf.path == down
  click(line("notes.md"))
  key(Keys.enter)
  @test e.buf.path == joinpath(down, "notes.md")
  K.go_back!(e)
  frames()
end

@testset "⌘⌫ moves what's chosen to the Trash, and the button does too" begin
  click(line("photo.png"))
  click(line("ancient.zip"), Keys.cmd)
  key(Keys.backspace, Keys.cmd)
  @test sort(trashed) == ["ancient.zip", "photo.png"]
  @test e.buf.path == down
  again()
  @test !("photo.png" in shown()) && !("ancient.zip" in shown())
  @test !any(startswith("— " * M.month_name(time() - 400day)), shown())   # a group with nothing in it has no words
  click(line("installer.dmg"))
  click(middle(view().buttons[:trash]))
  again()
  @test trashed[end] == "installer.dmg" && !("installer.dmg" in shown())
end

@testset "a right-click shows the file's menu" begin
  at(line("form.pdf"))
  onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames()
  @test chosen() == ["form.pdf"]
  @test menu() !== nothing && menu().items[1] == "Open" && "Move to Trash" in menu().items
  choose("Move to Trash")
  again()
  @test trashed[end] == "form.pdf"
end

@testset "the Trash lists each thing with the folder that it was in" begin
  K.open!(e, K.object(e, bin) === nothing ? bin : bin)
  K.go_folder!(e, bin)
  frames()
  @test e.buf.path == bin
  v = view(bin)
  @test v.trash
  @test shown(bin) == ["— Today", "plan.pdf", "notes 10.42.07 am.md", "— Previous 7 Days", "stray.txt"]
  @test v.origins["plan.pdf"] == T.Origin(folder=desk, name="plan.pdf")
  @test v.origins["notes 10.42.07 am.md"].name == "notes.md"
  @test !haskey(v.origins, "stray.txt")
  shot("trash")
end

@testset "the Trash's page has no buttons, and its first line is right under its name" begin
  v = view(bin)
  @test !haskey(v.buttons, :back) && !haskey(v.buttons, :finder)
  @test K.filelist_head_h(v) < K.LIST_HEAD_H == K.filelist_head_h(view(down))
  # A click on the first line chooses that line, at the height that it shows
  click(line("plan.pdf", bin))
  @test chosen(bin) == ["plan.pdf"]
  empty!(v.chosen)
end

"Right-click the line of `name` in the Trash"
right_click(name) = (at(line(name, bin)); onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames())

@testset "Put Back moves a thing to where it was, under the name that it had" begin
  v = view(bin)
  right_click("notes 10.42.07 am.md")
  @test chosen(bin) == ["notes 10.42.07 am.md"]
  @test menu() !== nothing && menu().items[1] == "Put Back"
  choose("Put Back")
  again(bin)
  @test isfile(joinpath(desk, "notes.md")) && !ispath(joinpath(bin, "notes 10.42.07 am.md"))
  @test v.said == ""
  # ⌘⌫ puts back too, as in the Finder
  click(line("plan.pdf", bin))
  key(Keys.backspace, Keys.cmd)
  again(bin)
  @test isfile(joinpath(desk, "plan.pdf"))
  @test shown(bin) == ["— Previous 7 Days", "stray.txt"]
  @test isempty(trashed[findall(==("plan.pdf"), trashed)])   # nothing was moved to the Trash by that key here
end

@testset "a thing that the Finder wrote nothing about stays, and the page says why" begin
  v = view(bin)
  right_click("stray.txt")
  @test menu() !== nothing && !("Put Back" in menu().items)   # the menu has it grey
  key(Keys.escape)
  K.filelist_put_back!(v, ["stray.txt"])
  frames()
  @test isfile(joinpath(bin, "stray.txt"))
  @test occursin("stray.txt", v.said)
  # The words go in a row over the list, and the list moves down for them
  @test K.filelist_head_h(v) == K.LIST_HEAD_H
  click(line("stray.txt", bin))
  @test chosen(bin) == ["stray.txt"]
end

@testset "a Trash that macOS doesn't let Ladder read shows a note, and the window goes on" begin
  # Until the Mac's owner gives Ladder Full Disk Access, macOS refuses each read of
  # the Trash. A folder that nobody may read acts the same, and so does a plain one.
  locked = mkpath(joinpath(dir, "Locked Trash"))
  plain = mkpath(joinpath(dir, "Locked"))
  write(joinpath(locked, "plan.pdf"), "x")
  write(joinpath(plain, "a.md"), "# A\n")
  K.PLACE_KINDS[locked] = K.TrashDirectory
  chmod(locked, 0o000); chmod(plain, 0o000)
  try
    K.open!(e, K.object(e, locked))
    frames()
    @test e.buf.path == locked
    @test e.folder == locked && isempty(e.listed)
    v = view(locked)
    @test occursin("Full Disk Access", v.problem)
    @test haskey(v.buttons, :access)
    K.open!(e, K.object(e, plain))
    frames()
    @test e.folder == plain && isempty(e.listed)
  finally
    chmod(locked, 0o755); chmod(plain, 0o755)
    delete!(K.PLACE_KINDS, locked)
  end
end

@testset "a folder's own page makes it show as Downloads does" begin
  own = joinpath(dir, "Inbox")
  mkpath(own)
  write(joinpath(own, ".ladder"), "```julia\nLadder.DownloadsDirectory\n```\n")
  K.folder_pages!(own)
  @test Base.invokelatest(K.FS.get, K.FSPath(own)) isa K.DownloadsDirectory
end

close(w)
delete!(K.PLACE_KINDS, down); delete!(K.PLACE_KINDS, bin)
K.TRASH_DISK[] = "/"
