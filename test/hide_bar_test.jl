# Tests for the top bar that hides: with its setting on, the page goes up to
# the top of the window, and the bar slides down over the page while the mouse
# rests at the window's top edge. See "a top bar that hides" in main.jl. Run
# them with `julia -O0 --project=. test/hide_bar_test.jl`. They move the mouse
# in a window that isn't on the screen. With `LADDER_SHOTS` set to a folder,
# they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

const px = K.px
const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
const page = joinpath(dir, "page.md")
write(page, "# A page\n\nSome words near the top of the window.\n")

const e = K.build_editor(page)
e.panel = false
const w = Window(e, size=(900px, 600px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "hide-bar-$name.png"), w)
wait_for(seconds) = (sleep(seconds + 0.05); frames())
"Wait until the bar has slid all the way in or out"
settle() = wait_for(K.SLIDE_TIME)
page_top() = K.num(rect(K.node!(K.Page, e, :page)).top)
bar() = rect(K.node!(K.TopBar, e, :topbar))
shown() = K.bar_shown(e)
const ON_PAGE = (450, 300)
const AT_EDGE = (450, 4)
const ON_BAR = (450, 30)

"Put the bar away: the mouse leaves it, and the bar goes after a moment"
put_away!() = (at(ON_PAGE); wait_for(K.BAR_STAYS); settle())

frames()

@testset "The bar keeps its room while the setting is off" begin
  @test !e.hide_bar
  @test page_top() == K.num(K.TOPBAR_H)
  @test K.num(bar().top) == 0
  at(ON_PAGE); wait_for(K.BAR_STAYS)
  @test shown() == 1   # it never hides
end

@testset "With the setting on, the page goes up to the top of the window" begin
  K.hide_bar!(e, true)
  frames()
  @test page_top() == 0
  # The bar goes a moment after the mouse leaves it
  put_away!()
  @test shown() == 0
  @test bar() === nothing   # the window doesn't show it at all
  shot("hidden")
end

@testset "Resting the mouse at the top edge brings the bar out over the page" begin
  at(AT_EDGE)
  @test shown() == 0   # not yet: the mouse has to rest there first
  wait_for(K.BAR_WAIT)
  @test K.bar_out(e)
  settle()
  @test shown() == 1
  @test K.num(bar().top) == 0
  @test page_top() == 0   # the bar lies over the page, and the page doesn't move
  shot("out")
  # It stays while the mouse is on it
  at(ON_BAR); wait_for(K.BAR_STAYS)
  @test K.bar_out(e)
  # ... and goes once the mouse has left it
  put_away!()
  @test shown() == 0
end

@testset "A mouse that only passes the top edge doesn't bring it out" begin
  at(AT_EDGE); at(ON_PAGE)
  wait_for(K.BAR_WAIT)
  @test !K.bar_out(e)
  # Nor does a drag that reaches the top, as a selection of lines does
  w.keys |= Keys.mouse_left
  at(AT_EDGE); wait_for(K.BAR_WAIT); frames()
  @test !K.bar_out(e)
  w.keys ⊻= Keys.mouse_left
  at(ON_PAGE)
end

@testset "Halfway through its slide the bar is halfway in" begin
  at(AT_EDGE); wait_for(K.BAR_WAIT)
  @test K.bar_out(e)
  sleep(K.SLIDE_TIME / 2); frames(1)
  @test -K.num(K.TOPBAR_H) < K.num(K.bar_top(e)) < 0
  @test abs(K.num(bar().top) - K.num(K.bar_top(e))) <= 2   # the bar's place is from the last frame, a moment ago
  settle()
  put_away!()
end

@testset "⌘F brings the bar out, with the search under the path" begin
  @test shown() == 0
  K.find!(e, w)
  frames(); settle(); frames()
  @test shown() == 1
  @test any(p -> p.key == K.TS_KEY, popups(w))
  # The search keeps the bar while it's open, with the mouse on the page
  wait_for(K.BAR_STAYS)
  @test K.bar_out(e)
  K.close_title_search!(e, w)
  frames()
  put_away!()
  @test shown() == 0
end

@testset "A pinned path shows only with the bar" begin
  e.pinned = true
  frames()
  @test !any(p -> p.key == :title_trail, popups(w))
  at(AT_EDGE); wait_for(K.BAR_WAIT); settle(); frames()
  @test any(p -> p.key == :title_trail, popups(w))
  shot("pinned")
  put_away!()
  @test !any(p -> p.key == :title_trail, popups(w))
  e.pinned = false
end

@testset "Turning the setting off gives the bar its room again" begin
  K.hide_bar!(e, false)
  frames()
  @test shown() == 1
  @test page_top() == K.num(K.TOPBAR_H)
  @test K.num(bar().top) == 0
end

@testset "The setting is kept in the settings file" begin
  write(K.settings_file(), "hidebar=true\n")
  o = K.load_settings!(K.Editor())
  @test o.hide_bar
  write(K.settings_file(), "hidebar=false\n")
  @test !K.load_settings!(K.Editor()).hide_bar
end
