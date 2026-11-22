# Tests for going back to the file that showed before, and forward again. See
# "the files that showed before" in main.jl. Run them with
# `julia -O0 --project=. test/back_test.jl`. They follow links and press keys
# in a window that isn't on the screen.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/window" swipe_button click_button!
@use GeometryBasics: Vec2

@use "../main" => K
const px = K.px
const cmd, ctrl, opt, shift = Keys.cmd, Keys.ctrl, Keys.opt, Keys.shft

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
@eval K settings_file() = $(joinpath(dir, "settings"))
# A file that goes to the Trash here is only removed
K.trasher[] = path -> (rm(path); true)

"A folder of its own with the pages `names` in it, and a window that isn't on the screen on the first of them"
window(names...) = begin
  folder = mktempdir(dir)
  for name in names
    write(joinpath(folder, name), "# $name\n\n" * join(("Line $i of $name." for i in 1:200), "\n\n") * "\n")
  end
  e = K.build_editor(joinpath(folder, first(names)))
  w = Window(e, size=(900px, 700px))
  frames(w)
  K.focus(e)
  e, w, folder
end
frames(w, n=2) = foreach(_ -> frame(w), 1:n)
"Press the key `k` in window `w` with the keys `held` down"
press(w, k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames(w)
end
"Click the middle of the part of the window that `node` is drawn in"
click(w, node) = begin
  r = rect(node)
  x, y = r.left + r.width / 2, r.top + r.height / 2
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  frames(w)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  frames(w)
end
"Show the sidebar, or hide it, and draw the window until the sidebar has finished its slide"
sidebar!(e, w) = begin
  K.toggle_panel!(e)
  to = e.panel ? 1 : 0
  while K.opened(e) != to
    frame(w)
  end
  frames(w)
end
"The name of the file that shows"
showing(e) = basename(e.buf.path)

@testset "⌘⌥← goes back to the file that showed before, and ⌘⌥→ goes forward again" begin
  e, w, _ = window("a.md", "b.md", "c.md")
  @test K.caps(first(K.bundle_keys("Ladder")[:back])) == "⌘⌥←"
  @test K.caps(first(K.bundle_keys("Ladder")[:forward])) == "⌘⌥→"
  K.follow!(e, "b.md"); frames(w)
  K.follow!(e, "c.md"); frames(w)
  @test showing(e) == "c.md"
  press(w, Keys.left, cmd, opt)
  @test showing(e) == "b.md"
  press(w, Keys.left, cmd, opt)
  @test showing(e) == "a.md"
  press(w, Keys.right, cmd, opt)
  @test showing(e) == "b.md"
  press(w, Keys.right, cmd, opt)
  @test showing(e) == "c.md"
  # The text has the keyboard again, as it has after any file opens
  @test w.focus === e
end

@testset "with no file to go to, the page stays" begin
  e, w, _ = window("a.md", "b.md")
  @test K.go_back!(e) == false
  @test K.go_forward!(e) == false
  press(w, Keys.left, cmd, opt)
  @test showing(e) == "a.md"
  K.follow!(e, "b.md"); frames(w)
  press(w, Keys.right, cmd, opt)      # nothing is ahead of the last file
  @test showing(e) == "b.md"
  press(w, Keys.left, cmd, opt)
  press(w, Keys.left, cmd, opt)       # and nothing is before the first
  @test showing(e) == "a.md"
end

@testset "a file comes back at the place that it was scrolled to" begin
  e, w, _ = window("a.md", "b.md")
  e.scroll.offset = 640px
  frames(w)
  K.follow!(e, "b.md"); frames(w)
  @test e.scroll.offset == 0px
  press(w, Keys.left, cmd, opt)
  @test showing(e) == "a.md" && e.scroll.offset == 640px
end

@testset "every way of showing a file counts" begin
  e, w, folder = window("a.md", "b.md", "c.md", "d.md")
  K.open!(e, joinpath(folder, "b.md")); frames(w)          # a click in the list of files
  K.visit!(e, joinpath(folder, "c.md")); frames(w)         # a line of a `find` block
  K.follow!(e, "d.md#d-md"); frames(w)                     # a link to a heading of another file
  @test showing(e) == "d.md"
  K.follow!(e, "#d-md"); frames(w)                         # a heading of the file that shows adds nothing
  @test basename.(e.back) == ["a.md", "b.md", "c.md"]
  for name in ("c.md", "b.md", "a.md")
    press(w, Keys.left, cmd, opt)
    @test showing(e) == name
  end
end

@testset "a new file after going back ends the way forward" begin
  e, w, _ = window("a.md", "b.md", "c.md")
  K.follow!(e, "b.md"); frames(w)
  press(w, Keys.left, cmd, opt)
  @test showing(e) == "a.md" && basename.(e.ahead) == ["b.md"]
  K.follow!(e, "c.md"); frames(w)
  @test isempty(e.ahead)
  press(w, Keys.right, cmd, opt)
  @test showing(e) == "c.md"
  press(w, Keys.left, cmd, opt)
  @test showing(e) == "a.md"
end

@testset "a file that was renamed is found, and one that went to the Trash is passed over" begin
  e, w, folder = window("a.md", "b.md", "c.md", "d.md")
  K.follow!(e, "b.md"); frames(w)
  K.follow!(e, "c.md"); frames(w)
  K.follow!(e, "d.md"); frames(w)
  K.move!(e, joinpath(folder, "c.md"), joinpath(folder, "sea.md")); frames(w)
  press(w, Keys.left, cmd, opt)
  @test showing(e) == "sea.md"
  K.trash!(e, joinpath(folder, "b.md")); frames(w)
  press(w, Keys.left, cmd, opt)
  @test showing(e) == "a.md"
  # The file that shows goes to the Trash, and another takes its place. Going back doesn't show the one that went.
  K.follow!(e, "d.md"); frames(w)
  K.trash!(e, joinpath(folder, "d.md")); frames(w)
  @test showing(e) != "d.md"
  K.go_back!(e); frames(w)
  @test showing(e) == "a.md"
  @test all(isfile, [e.back; e.ahead; e.buf.path])
end

@testset "a page that has no file yet is still there to go back to" begin
  e, w, folder = window("a.md", "b.md")
  new = joinpath(folder, "Untitled.md")
  K.open!(e, new); frames(w)
  K.type!(e, "words"); frames(w)
  K.follow!(e, "b.md"); frames(w)
  press(w, Keys.left, cmd, opt)
  @test e.buf.path == new && !isfile(new)
  @test e.buf.lines == ["words"]
end

@testset "each window has its own files to go back to" begin
  a, wa, _ = window("a.md", "b.md")
  b, wb, _ = window("c.md", "d.md")
  K.follow!(a, "b.md"); frames(wa)
  press(wb, Keys.left, cmd, opt)
  @test showing(b) == "c.md" && showing(a) == "b.md"
  press(wa, Keys.left, cmd, opt)
  @test showing(a) == "a.md"
end

@testset "⌃- goes back in the VS Code and Sublime Text bundles, and ⌃⇧- goes forward" begin
  for bundle in ("VS Code", "Sublime Text")
    e, w, _ = window("a.md", "b.md")
    K.bundle!(e, bundle)
    K.follow!(e, "b.md"); frames(w)
    press(w, Keys.minus, ctrl)
    @test showing(e) == "a.md"
    @test e.buf.lines[1] == "# a.md"          # the key typed nothing
    press(w, Keys.minus, ctrl, shift)
    @test showing(e) == "b.md"
  end
end

@testset "⌘[ and ⌘] aren't the keys that go back and forward" begin
  of = K.bundle_keys("Ladder")
  @test K.caps(first(of[:back])) == "⌘⌥←" && K.caps(first(of[:forward])) == "⌘⌥→"
  e, w, _ = window("a.md", "b.md")
  K.follow!(e, "b.md"); frames(w)
  press(w, Keys.left_bracket, cmd)
  @test showing(e) == "b.md"
end

@testset "the arrows at the top of the sidebar go back and forward, and show only while the sidebar is open" begin
  e, w, folder = window("a.md", "b.md")
  # The sidebar is closed, so the top bar has no arrows
  @test !e.panel && isempty(K.history_buttons(e)) && !haskey(e.nodes, :back) && !haskey(e.nodes, :forward)
  sidebar!(e, w)
  @test K.opened(e) == 1
  b, f = e.nodes[:back], e.nodes[:forward]
  @test K.history_buttons(e) == (b, f)
  @test b.icon == "arrow-left" && f.icon == "arrow-right"
  # They are in the top bar, at the right of the sidebar, with the one that goes back first
  rb, rf, eye = rect(b), rect(f), rect(e.nodes[:hidden])
  @test rb.top == rf.top == eye.top && rb.height == rf.height == eye.height
  @test K.panel_w(e) - (rf.left + rf.width) == 8px
  @test rf.left - (rb.left + rb.width) == 2px
  @test rb.left >= eye.left + eye.width
  # The window has shown one file, so both are faint and a click does nothing
  @test K.off(b) && K.tip(b) == "No file to go back to"
  @test K.off(f) && K.tip(f) == "No file to go forward to"
  click(w, b); click(w, f)
  @test showing(e) == "a.md"
  K.follow!(e, "b.md"); frames(w)
  @test !K.off(b) && K.tip(b) == "Back to a.md  ⌘⌥←"
  @test K.off(f)
  click(w, b)
  @test showing(e) == "a.md"
  @test K.off(b) && !K.off(f) && K.tip(f) == "Forward to b.md  ⌘⌥→"
  @test w.focus === e
  click(w, f)
  @test showing(e) == "b.md"
  @test !K.off(b) && K.off(f) && isempty(e.ahead)
  # The sidebar closes, and the arrows go with it. The keys still go back.
  sidebar!(e, w)
  @test isempty(K.history_buttons(e))
  press(w, Keys.left, cmd, opt)
  @test showing(e) == "a.md"
end

@testset "the arrows stay at the edge of a sidebar that's dragged wider" begin
  e, w, _ = window("a.md", "b.md")
  sidebar!(e, w)
  K.side!(e, 320px); frames(w, 3)   # the bar is drawn at its new width a frame after the sidebar is
  rb, rf = rect(e.nodes[:back]), rect(e.nodes[:forward])
  @test K.panel_w(e) == 320px && K.panel_w(e) - (rf.left + rf.width) == 8px
  @test rf.left - (rb.left + rb.width) == 2px
end

@testset "the narrowest sidebar still has room for its buttons" begin
  e, w, _ = window("a.md", "b.md")
  sidebar!(e, w)
  K.side!(e, 100px); frames(w, 3)              # dragged further than it goes
  @test K.panel_w(e) == K.PANEL_MIN
  rb, rf, eye, title = rect(e.nodes[:back]), rect(e.nodes[:forward]), rect(e.nodes[:hidden]), rect(e.nodes[:title])
  @test rb.left >= eye.left + eye.width         # no button is over another
  @test rf.left - (rb.left + rb.width) == 2px
  @test K.panel_w(e) - (rf.left + rf.width) == 8px   # the arrows are inside the sidebar's edge, as on a wider one
  @test rf.left + rf.width <= title.left
end

@testset "the two buttons at the side of a mouse go back and forward" begin
  e, w, _ = window("a.md", "b.md", "c.md")
  side(k) = (w.keys |= k; onkey(w, KeyPress{k}(0, w)); w.keys ⊻= k; frames(w))
  K.follow!(e, "b.md"); frames(w)
  K.follow!(e, "c.md"); frames(w)
  side(Keys.mouse_back)
  @test showing(e) == "b.md"
  side(Keys.mouse_back)
  @test showing(e) == "a.md"
  side(Keys.mouse_back)                      # no file showed before the first
  @test showing(e) == "a.md"
  side(Keys.mouse_forward)
  @test showing(e) == "b.md"
  # They aren't for the place that the mouse is over: over the sidebar's list, a press still goes forward
  sidebar!(e, w)
  w.mouse = typeof(w.mouse)(60px, 300px); frames(w)
  side(Keys.mouse_forward)
  @test showing(e) == "c.md"
  # While the field that finds text has the keyboard, they still work
  K.open_find!(e); frames(w)
  @test w.focus === K.find_input(e)
  side(Keys.mouse_back)
  @test showing(e) == "b.md"
  # While the file finder is open, the page under it stays
  K.focus(e)
  K.open_finder!(e); frames(w)
  side(Keys.mouse_back)
  @test showing(e) == "b.md" && e.popup == :finder
  press(w, Keys.escape)
  # No command can have one as its shortcut
  @test !haskey(K.KEY_NAMES, "mouse_back") && !haskey(K.KEY_NAMES, "mouse_forward")
  @test K.ismouse(Keys.mouse_back) && K.ismouse(Keys.mouse_forward)
end

@testset "a swipe goes back and forward, as from a mouse whose side buttons send swipes" begin
  # Logi Options+ makes the side buttons of an MX Master send macOS's swipe to the left or the right, and
  # a three-finger swipe on the trackpad sends the same. The window's view clicks the back or forward button for it.
  e, w, _ = window("a.md", "b.md")
  K.follow!(e, "b.md"); frames(w)
  swipe(dx) = (click_button!(w, swipe_button(dx)); frames(w))
  swipe(1.0)
  @test showing(e) == "a.md"
  swipe(-1.0)
  @test showing(e) == "b.md"
  # No button stays down after it
  @test !(Keys.mouse_back in w.keys) && !(Keys.mouse_forward in w.keys)
end
