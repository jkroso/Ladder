# Tests for the buttons at the left of the top bar while the window fills a
# screen of its own. macOS hides the close, minimise and zoom buttons then, so
# the bar's buttons slide left into their room, and slide back after. Run them
# with `julia -O0 --project=. test/full_screen_bar_test.jl`. They draw in a
# window that isn't on the screen, which can't fill one, so they set the
# editor's `full_screen` themselves. Set `LADDER_SHOTS` to a folder, and they
# save a picture of each step there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "notes.md")
write(page, "# Notes\n\nSome words.\n")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 700px))
const (; frames, shot) = drive(w)
e.panel = true   # the sidebar shows
frames(3)

"How far the left edge of the button that shows the sidebar is from the left edge of the window"
panel_left() = K.num(rect(e.nodes[:panel]).left)

"Make the window fill its screen or not, as the check in each frame would see it on a real screen"
screen!(on) = (e.screened_from = K.cleared(e); e.screened = time(); e.full_screen = on)
"Wait for the slide to end"
settle() = (sleep(K.SLIDE_TIME + 0.05); frames())

@testset "the buttons slide into the room of the close, minimise and zoom buttons" begin
  @test panel_left() ≈ 84
  shot("screen-window.png")
  screen!(true); frames()
  @test K.clearing(e) && w.animating   # each frame of the slide is drawn
  @test 8 < panel_left() < 84 || K.cleared(e) == 1
  settle()
  @test !K.clearing(e) && !w.animating
  @test panel_left() ≈ 8
  shot("screen-full.png")
end

@testset "they slide back when the window leaves full screen" begin
  screen!(false); frames()
  @test K.clearing(e)
  settle()
  @test panel_left() ≈ 84
end

@testset "a slide that turns back starts from where the buttons are" begin
  screen!(true); sleep(K.SLIDE_TIME / 2); frames()
  half = panel_left()
  @test 8 < half < 84
  screen!(false); frames()
  @test abs(panel_left() - half) < 10   # no jump back to the start
  settle()
  @test panel_left() ≈ 84
end

@testset "a closed sidebar" begin
  K.toggle_panel!(e); e.slid = 0.0
  screen!(true); settle()
  @test panel_left() ≈ 8
  screen!(false); settle()
  @test panel_left() ≈ 84
end
