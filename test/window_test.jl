# Tests for Ladder's windows: the settings window that ⌘, opens, ⌘W, and the
# settings that every window shares. See "windows" and "settings" in main.jl.
# Run them with `julia -O0 --project=. test/window_test.jl`. They press keys in windows
# that aren't on the screen, and they don't write the settings file.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame

@use "../main" => K
const px, window_of, focus = K.px, K.window_of, K.focus

const dir = mktempdir()
const page = joinpath(dir, "notes.md")
write(page, "# Notes\n\n" * join(("Line $i of the notes." for i in 1:200), "\n\n") * "\n")
write(joinpath(dir, "other.md"), "# Other\n\nAnother page.\n")
const settings_page = K.settings_page()

"Press `key` in window `w` with `mods` held down, then draw the window"
press(w, key, mods...) = begin
  foreach(m -> (w.keys |= m), mods)
  onkey(w, KeyPress{key}(0, w)); onkey(w, KeyRelease{key}(0, w))
  foreach(m -> (w.keys ⊻= m), mods)
  frame(w)
end

"A window that shows `path`, made the way Ladder makes its first window"
window(path) = begin
  e = K.build_editor(path)
  w = K.window!(e, title="test", size=(1100px, 800px))
  frame(w)
  e, w
end

"Close every window that a test left open"
close_all() = foreach(e -> close(window_of(e)), copy(K.editors))

@testset "⌘, opens the settings in a window of their own" begin
  e, w = window(page)
  press(w, Keys.comma, Keys.cmd)
  @test e.buf.path == page                      # the page stays in its window
  @test length(K.editors) == 2
  s = K.settings_editor()
  @test s !== nothing && s !== e
  @test s.buf.path == settings_page
  @test !s.panel
  sw = window_of(s)
  @test sw !== w
  @test sw.title == "Settings"
  frame(sw)
  # A second ⌘, in the first window doesn't open another settings window
  press(w, Keys.comma, Keys.cmd)
  @test length(K.editors) == 2
  # In the settings window, ⌘, closes it
  press(sw, Keys.comma, Keys.cmd)
  @test K.settings_editor() === nothing
  @test K.editors == [e]
  close_all()
  @test isempty(K.editors)
end

@testset "the settings window has the settings of the window that opened it" begin
  e, w = window(page)
  e.theme, e.font, e.zoom, e.stat = :night, "Menlo", 1.5, :characters
  press(w, Keys.comma, Keys.cmd)
  s = K.settings_editor()
  @test (s.theme, s.font, s.zoom, s.stat) == (:night, "Menlo", 1.5, :characters)
  close_all()
end

@testset "a setting that changes in one window changes in the other" begin
  e, w = window(page)
  press(w, Keys.comma, Keys.cmd)
  s = K.settings_editor()
  sw = window_of(s)
  frame(sw)
  K.theme!(s, :night)
  @test e.theme == :night
  K.font!(s, "Georgia")
  @test e.font == "Georgia"
  K.text_size!(s, 24)
  @test e.zoom == s.zoom
  K.page_width!(s, 600)
  @test e.widest == 600px
  K.stat!(s, :characters)
  @test e.stat == :characters
  K.spelling!(s, false)
  @test !e.spelling
  frame(w); frame(sw)
  # And the other way: ⌘+ in the page's window makes the text of the settings window bigger too
  before = s.zoom
  press(w, Keys.equal, Keys.cmd)
  @test e.zoom > before
  @test s.zoom == e.zoom
  frame(sw)
  close_all()
end

@testset "the page keeps its place when a setting changes in the settings window" begin
  e, w = window(page)
  e.scroll.offset = 2000px
  frame(w)
  y = e.scroll.offset
  top = findfirst(it -> it.top + it.tall > y, e.layout)
  line, gap = e.layout[top].first, e.layout[top].top - y
  press(w, Keys.comma, Keys.cmd)
  s = K.settings_editor()
  K.text_size!(s, 30)
  frame(w)
  # The line that was at the top of the window is still there
  @test isapprox((K.item(e, line).top - e.scroll.offset).value, gap.value, atol=0.01)
  close_all()
end

@testset "⌘W closes a window" begin
  e, w = window(page)
  press(w, Keys.comma, Keys.cmd)
  s = K.settings_editor()
  sw = window_of(s)
  frame(sw)
  press(sw, Keys.w, Keys.cmd)
  @test K.editors == [e]                        # the settings window closed, and the page's window didn't
  # A setting no longer goes to the window that closed
  K.theme!(e, :paper)
  @test s.theme != :paper
  # ⌘, opens the settings window again
  press(w, Keys.comma, Keys.cmd)
  @test K.settings_editor() !== nothing
  @test K.settings_editor() !== s
  close_all()
  # In a window with a file, ⌘W closes the file and shows its folder, and the window stays.
  # ⌘W again closes the folder, and a third ⌘W closes the window.
  e, w = window(page)
  press(w, Keys.w, Keys.cmd)
  @test K.editors == [e] && e.buf.path == dirname(page)
  press(w, Keys.w, Keys.cmd)
  @test K.editors == [e] && K.nofile(e)
  press(w, Keys.w, Keys.cmd)
  @test isempty(K.editors)
  # A plain W doesn't close the window
  e, w = window(page)
  press(w, Keys.w)
  @test K.editors == [e]
  close_all()
end

@testset "⌘W and ⌘, work while something else has the keyboard" begin
  e, w = window(page)
  press(w, Keys.comma, Keys.cmd)
  s = K.settings_editor()
  sw = window_of(s)
  frame(sw)
  # The file finder's text field, as a stand-in for a slider that took the keyboard
  focus(K.input(s))
  @test sw.focus !== s
  press(sw, Keys.comma, Keys.cmd)
  @test K.settings_editor() === nothing
  # The find bar has the keyboard in the page's window
  press(w, Keys.f, Keys.cmd)
  @test w.focus !== e
  press(w, Keys.w, Keys.cmd)
  @test e.buf.path == dirname(page)
  press(w, Keys.w, Keys.cmd)
  @test K.nofile(e)
  press(w, Keys.w, Keys.cmd)
  @test isempty(K.editors)
end

@testset "a settings window that goes to another page is a window like any other" begin
  e, w = window(page)
  press(w, Keys.comma, Keys.cmd)
  s = K.settings_editor()
  K.open!(s, joinpath(dir, "other.md"))
  @test K.settings_editor() === nothing
  # So ⌘, there opens the settings window, and doesn't close this one
  press(window_of(s), Keys.comma, Keys.cmd)
  @test length(K.editors) == 3
  @test K.settings_editor() !== nothing
  close_all()
end

@testset "a file from the Finder opens in the page's window, not the settings window" begin
  e, w = window(page)
  press(w, Keys.comma, Keys.cmd)
  s = K.settings_editor()
  sw = window_of(s)
  other = joinpath(dir, "other.md")
  K.inbox[] = [other]
  frame(sw)
  @test s.buf.path == settings_page             # the settings window kept its page
  @test K.inbox[] == [other]                    # and left the file for the other window
  frame(w)
  @test e.buf.path == other
  @test isempty(K.inbox[])
  close_all()
end

@testset "with only the settings window open, a file from the Finder opens in a new window" begin
  e, w = window(page)
  press(w, Keys.comma, Keys.cmd)
  s = K.settings_editor()
  sw = window_of(s)
  K.theme!(s, :night)
  close(w)
  @test K.editors == [s]
  other = joinpath(dir, "other.md")
  K.inbox[] = [other]
  frame(sw)
  @test s.buf.path == settings_page             # the settings window kept its page
  @test isempty(K.inbox[])
  @test length(K.editors) == 2
  new = K.editors[2]
  @test new.buf.path == other
  @test !K.issettings(new)
  @test new.theme == :night                     # the new window has the settings that the settings window has
  frame(window_of(new))
  close_all()
end

@testset "a window that a test makes keeps its settings to itself" begin
  e, w = window(page)
  lone = K.build_editor(page)
  Window(lone, title="alone", size=(1100px, 800px))
  K.theme!(lone, :night)
  @test e.theme != :night
  K.theme!(e, :paper)
  @test lone.theme == :night
  close_all()
  @test isempty(K.editors)
end

rm(dir, recursive=true)
