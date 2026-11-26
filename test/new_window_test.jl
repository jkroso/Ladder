# Tests for ⌘N: it opens a new window on the folder that the window is in, with
# the folder in its page. See `new_window!` in main.jl. Run them with
# `julia -O0 --project=. test/new_window_test.jl`. They press keys in windows
# that aren't on the screen, so the new windows aren't on the screen either.

@use "../main" => K
@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" KeyPress Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame

const px = K.px
const cmd = Keys.cmd

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
K.SETTINGS_FILE[] = joinpath(dir, "settings")

const top = joinpath(dir, "Work")
const sub = joinpath(top, "Plans")
mkpath(sub)
write(joinpath(top, "aardvark.md"), "# Aardvark\n\nThe first page of the folder.\n")
write(joinpath(sub, "plan.md"), "# Plan\n\nThe plan.\n")
write(joinpath(sub, "notes.md"), "# Notes\n\nSome notes.\n")

"A window that isn't on the screen, on `path`"
window(path) = begin
  e = K.build_editor(path)
  w = K.window!(e, size=(900px, 700px), position=(100px, 80px))
  frames(w)
  e, w
end
frames(w, n=2) = foreach(_ -> frame(w), 1:n)
"Press the key `k` in window `w` with the keys `held` down"
press(w, k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames(w)
end
"Press ⌘N in `w`, and give the editor of the window that it opened"
new_window(w) = begin
  before = copy(K.editors)
  press(w, Keys.n, cmd)
  made = Base.filter(o -> !any(b -> b === o, before), K.editors)
  @test length(made) == 1
  frames(K.window_of(only(made)))
  only(made)
end
"Forget the windows that the tests opened"
forget!() = empty!(K.editors)

@testset "⌘N on a file opens a new window that shows the file's folder" begin
  e, w = window(joinpath(sub, "plan.md"))
  n = new_window(w)
  @test n !== e
  @test n.buf.path == sub
  @test n.buf.view == :file
  @test n.folder == sub
  # The window it came from still shows its file
  @test e.buf.path == joinpath(sub, "plan.md")
  # Only the person opens the sidebar
  @test !n.panel
  # A new window has no file to go back to
  @test isempty(n.back)
  forget!()
end

@testset "the new window is as big as the window it came from, a little lower and to the right" begin
  e, w = window(joinpath(sub, "plan.md"))
  n = new_window(w)
  nw = K.window_of(n)
  @test (nw.size[1], nw.size[2]) == (w.size[1], w.size[2])
  @test (nw.position[1], nw.position[2]) == (w.position[1] + 30px, w.position[2] + 30px)
  forget!()
end

@testset "the new window has the settings of the window it came from" begin
  e, w = window(joinpath(sub, "plan.md"))
  e.theme = :night
  e.zoom = 1.25
  n = new_window(w)
  @test n.theme == :night
  @test n.zoom == 1.25
  e.theme = :day
  e.zoom = 1.0
  forget!()
end

@testset "⌘N on a folder's page opens a new window on that folder, not on its first page" begin
  e, w = window(joinpath(top, "aardvark.md"))
  K.show_path!(e, sub)
  frames(w)
  @test e.buf.path == sub
  n = new_window(w)
  @test n.buf.path == sub
  forget!()
end

@testset "⌘N in a window with no file opens a new window on the sidebar's folder" begin
  e, w = window(joinpath(sub, "plan.md"))
  press(w, Keys.w, cmd)   # the window shows the file's folder
  press(w, Keys.w, cmd)   # and then no file
  @test isempty(e.buf.path)
  n = new_window(w)
  @test n.buf.path == e.folder
  @test isdir(n.buf.path)
  forget!()
end

@testset "a new window opens on a file in it as any window does" begin
  e, w = window(joinpath(sub, "plan.md"))
  n = new_window(w)
  K.open!(n, joinpath(sub, "notes.md"))
  frames(K.window_of(n))
  @test n.buf.path == joinpath(sub, "notes.md")
  # The window that it came from keeps its own file
  @test e.buf.path == joinpath(sub, "plan.md")
  forget!()
end
