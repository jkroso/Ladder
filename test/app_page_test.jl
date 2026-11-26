# Tests for a page as an app, in main.jl: the command Show As App opens the
# page in a window that has only the page, with no sidebar, no caret and an
# empty top bar to drag. Its blocks still work, and what one changes is written
# to the file.
# Run them with `julia -O0 --project=. test/app_page_test.jl`. They draw
# windows that aren't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window Typed Keys ontype KeyPress
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "jobs.md")
write(page, "# Jobs\n\n- [ ] Dig the trench\n- [ ] Lay the pipe\n\n```board\n```\n")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
frames(win=w, n=3) = foreach(_ -> Base.invokelatest(frame, win), 1:n)
frames()

@testset "the window has only the page" begin
  @test haskey(e.nodes, :topbar) && !K.as_app(e)
  shown = K.show_as_app!(e)
  win = K.window_of(shown)
  frames(win)
  @test shown !== e && shown.buf.path == page && K.as_app(shown)
  # No sidebar and no caret
  @test !haskey(shown.nodes, :sidebar) && !shown.panel && K.caretless(shown.buf)
  # The top bar is there with nothing in it, so you can drag it to move the window
  bar = K.describe(shown.nodes[:topbar])
  @test isempty(bar.children) && !isempty(K.describe(e.nodes[:topbar]).children)
  @test hasmethod(K.onkey, Tuple{K.TopBar, KeyPress{Keys.mouse_left}})
  # The page's blocks are there
  @test haskey(shown.nodes, (:block, K.BOARD, page, 1))
  # The window that changes the page is as it was
  frames()
  @test haskey(e.nodes, :topbar) && !K.caretless(e.buf)
end

@testset "a block's change is written at once, and no key changes the text" begin
  shown = only(filter(K.as_app, K.editors))
  win = K.window_of(shown)
  i = findfirst(==("- [ ] Dig the trench"), shown.buf.lines)
  K.tick!(shown, i)
  frames(win)
  @test occursin("- [x] Dig the trench", read(page, String)) && !K.dirty(shown.buf)
  # A click that puts the caret in the text leaves no caret in the next frame, and a typed letter changes nothing
  shown.buf.reading = false
  shown.buf.caret = shown.buf.anchor = (1, 2)
  frames(win, 1)
  @test K.caretless(shown.buf)
  K.focus(shown)
  ontype(shown, Typed('x', win))
  frames(win)
  @test shown.buf.lines[1] == "# Jobs"
end

@testset "the command in that window gives the page back to change" begin
  shown = only(filter(K.as_app, K.editors))
  win = K.window_of(shown)
  @test K.show_as_app!(shown) === nothing
  frames(win)
  @test !K.as_app(shown) && !K.caretless(shown.buf) && haskey(shown.nodes, :topbar)
  # A file that isn't a page of Markdown has nothing to show as an app
  code = joinpath(dir, "code.jl")
  write(code, "x = 1\n")
  K.open!(e, code)
  frames()
  @test_throws ErrorException K.show_as_app!(e)
end

foreach(o -> (win = K.window_of(o); win === nothing || close(win)), copy(K.editors))
