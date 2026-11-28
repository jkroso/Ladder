# Tests for the top bar that hides: while it hides, the page goes up to
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
@use "./drive" drive

const px = K.px
const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "page.md")
write(page, "# A page\n\nSome words near the top of the window.\n")

const e = K.build_editor(page)
e.panel = false
const w = Window(e, size=(900px, 600px))
const (; frames, at, shot) = drive(w, frames=3, latest=true)
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

@testset "The bar keeps its room while the setting is Never" begin
  @test e.hide_bar == :never
  @test page_top() == K.num(K.TOPBAR_H)
  @test K.num(bar().top) == 0
  at(ON_PAGE); wait_for(K.BAR_STAYS)
  @test shown() == 1   # it never hides
end

@testset "With Always, the page goes up to the top of the window" begin
  K.hide_bar!(e, :always)
  frames()
  @test page_top() == 0
  # The bar goes a moment after the mouse leaves it
  put_away!()
  @test shown() == 0
  @test bar() === nothing   # the window doesn't show it at all
  shot("hide-bar-hidden")
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
  shot("hide-bar-out")
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
  sleep(K.SLIDE_TIME / 2)
  # Where the bar is just before a frame and just after it. The frame drew it at a place between the two,
  # however long the frame took.
  before = K.num(K.bar_top(e)); frames(1); after = K.num(K.bar_top(e))
  @test -K.num(K.TOPBAR_H) < before < 0
  @test min(before, after) - 1 <= K.num(bar().top) <= max(before, after) + 1
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
  shot("hide-bar-pinned")
  put_away!()
  @test !any(p -> p.key == :title_trail, popups(w))
  e.pinned = false
end

@testset "With In full screen only, the bar hides only while the window fills the screen" begin
  K.hide_bar!(e, :full_screen)
  frames()
  @test !e.full_screen   # a window that isn't on the screen keeps what a test sets
  @test page_top() == K.num(K.TOPBAR_H)
  @test shown() == 1
  wait_for(K.BAR_STAYS); settle()
  @test shown() == 1   # it never hides in a window that doesn't fill the screen
  e.full_screen = true
  frames()
  @test page_top() == 0
  put_away!()
  @test shown() == 0
  at(AT_EDGE); wait_for(K.BAR_WAIT); settle()
  @test shown() == 1
  put_away!()
  # Out of full screen, the bar shows again, with its room
  e.full_screen = false
  frames()
  @test shown() == 1
  @test page_top() == K.num(K.TOPBAR_H)
  @test K.num(bar().top) == 0
end

@testset "Never gives the bar its room again" begin
  K.hide_bar!(e, :always)
  frames()
  @test page_top() == 0
  K.hide_bar!(e, :never)
  frames()
  @test shown() == 1
  @test page_top() == K.num(K.TOPBAR_H)
  @test K.num(bar().top) == 0
end

@testset "The setting is kept in the settings file" begin
  loads(line) = (write(K.settings_file(), line * "\n"); K.load_settings!(K.Editor()).hide_bar)
  @test loads("hidebar=full_screen") == :full_screen
  @test loads("hidebar=always") == :always
  @test loads("hidebar=never") == :never
  @test loads("hidebar=sometimes") == :never   # a value it doesn't know leaves the bar as it is
  # It was true or false before it could hide in full screen only
  @test loads("hidebar=true") == :always
  @test loads("hidebar=false") == :never
end

@testset "The settings page names each choice as a Mac does" begin
  @test [K.hiding_name(how) for how in (:always, :full_screen, :never)] == ["Always", "In full screen only", "Never"]
  @test K.hiding_named("In full screen only") == :full_screen
  @test K.hiding_named("Never") == :never
end


"The first node of type `T` in the tree of `node`, as weight_test.jl finds one"
find(T, node, seen=IdDict()) = begin
  node isa T && return node
  (isbits(node) || node isa Union{AbstractString,Symbol,Module,Function,Type} || haskey(seen, node)) && return nothing
  seen[node] = true
  if node isa Union{AbstractVector,Tuple,AbstractDict}
    for x in values(node)
      (f = find(T, x, seen)) === nothing || return f
    end
    return nothing
  end
  for name in fieldnames(typeof(node))
    isdefined(node, name) || continue
    (f = find(T, getfield(node, name), seen)) === nothing || return f
  end
  nothing
end

@testset "The settings page has a list of the three choices" begin
  page = K.settings_page()
  code = String(only(m[1] for m in eachmatch(r"## Top bar\n\n```ui\n(.*?)```"s, read(page, String))))
  s = K.build_editor(page)
  sw = Window(s, size=(720px, 2600px))
  empty!(K.problems)
  foreach(_ -> frame(sw), 1:3)
  @test isempty(K.problems)
  run(code) = include_string(K.sandbox(s), code)
  Dropdown = run("Dropdown")
  d = find(Dropdown, K.evaluate(s, code))
  @test d.options == ["Always", "In full screen only", "Never"] && d.selected == 3
  run("page_bar_hides!(\"In full screen only\")")
  @test s.hide_bar == :full_screen
  @test find(Dropdown, K.evaluate(s, code)).selected == 2
  foreach(_ -> frame(sw), 1:3)
  @test isempty(K.problems)
end
