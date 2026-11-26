# Tests for the command palette: the bar that ⌘⇧P slides up from the bottom of
# the window, how it finds a command by the letters typed, and how it asks for
# what a command's function takes, each thing in a chip of its kind. It's a
# copy of Centient's omnibar. See "the command palette" and "commands that are
# functions" in main.jl. Run them with
# `julia -O0 --project=. test/command_palette_test.jl`. They use windows that
# aren't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype MouseMove onmouse onscroll
@use GeometryBasics: Vec2
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
const kept = joinpath(dir, "settings")
K.SETTINGS_FILE[] = kept

const PAGE = "# Plans\n\nSome words.\n\n## Costs\n\nMore words.\n\n## Dates\n\nThe end.\n"

"A window that isn't on the screen, on a file with `text` in it"
window(text=PAGE; name="page.md", size=(900px, 700px)) = begin
  path = joinpath(dir, name)
  write(path, text)
  e = K.build_editor(path)
  w = Window(e, size=size)
  frame(w); frame(w)
  K.focus(e)
  e, w
end

"Draw the window with the bar where it comes to rest, not part of the way there"
frames(w) = begin
  e = w.ui
  haskey(e.nodes, :palette) && (e.nodes[:palette].moved = 0.0)
  frame(w); frame(w)
end
"Press the key `k` in window `w` with the keys `held` down"
press(w, k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames(w)
end
typed(w, s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames(w))
"Move the mouse to the middle of the part of the window that `node` is drawn in"
over(w, node) = begin
  r = rect(node)
  x, y = r.left + r.width / 2, r.top + r.height / 2
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  frames(w)
end
click(w, node) = begin
  over(w, node)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  frames(w)
end
shot(w, name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
const cmd, shift = Keys.cmd, Keys.shft

open_palette(w) = press(w, Keys.p, cmd, shift)
"Open the palette and take the command whose name is `name`"
take(w, name) = (open_palette(w); typed(w, name); press(w, Keys.enter))
names(e) = [row.name for row in K.palette_rows(e, K.palette(e))]
field(e) = K.input(e).text
"The chips that show, and the kind of each"
chips(e) = K.palette_chips(K.palette(e))
kinds(e) = [K.chip_kind(e, c) for c in chips(e)]
"What's said for chip `k`"
said(e, k) = K.chip_value(K.palette(e), chips(e), k)

# Functions for the palette to call. Each notes what it was called with.
const calls = Any[]
struct Page end
struct Folder end
"Make a page or a folder"
make(e, ::Type{Page}, name::String) = push!(calls, (:page, name))
make(e, ::Type{Folder}, name::String, count::Int, hidden::Bool) = push!(calls, (:folder, name, count, hidden))
"Count up to a number, in steps"
count_to(e, n::Int, step::Int=1) = push!(calls, (:count, n, step))
"Say when"
due(e, day::K.Date) = push!(calls, (:due, day))
"Send words to a person, or a number of them to everyone"
send(e, to::String, subject::String) = push!(calls, (:send, to, subject))
send(e, to::Int) = push!(calls, (:send, to))
"Say words, loud or not, some times"
shout(e, words::String; loud::Bool=false, times::Int=1) = push!(calls, (:shout, words, loud, times))
"Takes what can't be asked for"
opaque(e, x::Dict) = nothing
"Takes nothing"
ping(e::K.Editor, w::Window) = push!(calls, (:ping, e, w))
# Functions that take what's in focus, by its type
"Stamp a file, or a page of Markdown with words"
stamp(e, f::K.FS.File) = push!(calls, (:stamp, f))
stamp(e, f::K.FS.File{:md}, words::String) = push!(calls, (:stamp, f, words))
"Fetch what's new in a git folder"
fetch_new(d::K.GitDirectory) = push!(calls, (:fetch_new, d))
"Count the text of the page"
count_text(e, d::K.Document) = push!(calls, (:count_text, d))
"True when the file or the folder `o` is the one at `path`, whichever way the Mac writes its temporary folder"
at(o, path) = realpath(K.path_of(o)) == realpath(path)
"A part of a page that holds files, one of them chosen"
K.@def mutable struct Shelf <: K.SemanticUI
  path::String = ""
  chosen::Set{String} = Set{String}()
end

@testset "how well text fits the letters typed" begin
  @test K.palette_fit("save", "sa") == 150           # at its start
  @test K.palette_fit("unsaved", "sa") == 98         # further in, so a little less
  @test K.palette_fit("select all", "sla") > 0       # in order, with others between
  @test K.palette_fit("select all", "sla") < K.palette_fit("unsaved", "sa")
  @test K.palette_fit("save", "x") == 0
  @test K.palette_fit("save", "vas") == 0            # not in that order
  @test K.match_parts("Select All", "all") == ("Select ", "All", "")
  @test K.match_parts("Save", "av") == ("S", "av", "e")
  @test K.match_parts("Save", "x") == ("Save", "", "")
  @test K.match_parts("Save", "") == ("Save", "", "")
end

@testset "the methods of a function make its chips" begin
  sigs = K.callable_methods(make)
  @test length(sigs) == 2
  # Methods that take a type itself part there, and the chips after it wait for it
  found = K.palette_chips(sigs, Any[])
  @test length(found) == 1 && found[1].names == [:kind] && Set(found[1].types) == Set([Type{Page}, Type{Folder}])
  # What's said chooses the methods that go on
  @test [c.names[1] for c in K.palette_chips(sigs, Any[Page])] == [:kind, :name]
  @test [c.names[1] for c in K.palette_chips(sigs, Any[Folder])] == [:kind, :name, :count, :hidden]
  @test K.ready_method(sigs, Any[Page, K.UNSAID]) === nothing
  @test K.ready_method(sigs, Any[Page, "notes"]) !== nothing
  @test K.ready_method(sigs, Any[Folder, "notes", K.UNSAID, K.UNSAID]) === nothing

  # Methods that take values of different types show the chips of the one that's written first
  sigs = K.callable_methods(send)
  found = K.palette_chips(sigs, Any[])
  @test [c.names[1] for c in found] == [:to, :subject] && Set(found[1].types) == Set([String, Int])
  @test [c.names[1] for c in K.palette_chips(sigs, Any[5])] == [:to]
  @test [c.names[1] for c in K.palette_chips(sigs, Any["Ann"])] == [:to, :subject]

  # A default makes a shorter method, so the last chip can be left out
  sigs = K.callable_methods(count_to)
  found = K.palette_chips(sigs, Any[])
  @test [c.names[1] for c in found] == [:n, :step] && [c.optional for c in found] == [false, true]
  @test K.ready_method(sigs, Any[3, K.UNSAID]) !== nothing
  @test K.ready_method(sigs, Any[3, 2]) !== nothing
  @test K.ready_method(sigs, Any[K.UNSAID, 2]) === nothing

  # Keyword arguments come last, and can be left out
  found = K.palette_chips(K.callable_methods(shout), Any[])
  @test [c.names[1] for c in found] == [:words, :loud, :times] && [c.keyword for c in found] == [false, true, true]
  @test found[2].types == Any[Bool] && found[3].types == Any[Int]
end

@testset "how a type is asked for, and the kind of its chip" begin
  @test K.askable(Int) && K.askable(String) && K.askable(Bool) && K.askable(K.Date) && K.askable(Type{Page})
  @test K.askable(Union{Nothing,Int}) && !K.askable(Dict) && !K.askable(Any) && !K.askable(Symbol)
  chip(T...) = K.Wanted([:x], Any[T...], false)
  @test K.chip_typed(chip(Int), "12") === 12 && K.chip_typed(chip(Int), "twelve") === nothing
  @test K.chip_typed(chip(Integer), "12") === 12
  @test K.chip_typed(chip(Float64), "1.5") === 1.5
  @test K.chip_typed(chip(Real), "20") === 20 && K.chip_typed(chip(Real), "1.5") === 1.5 && K.chip_typed(chip(Real), "big") === nothing
  @test K.chip_typed(chip(String), "hello") == "hello" && K.chip_typed(chip(String), "") === nothing
  @test K.chip_typed(chip(K.Date), "2026-11-25") == K.Date(2026, 11, 25)
  @test K.chip_typed(chip(K.Date), "today") == K.Dates.today()
  @test K.worded(true) == "On" && K.worded(false) == "Off" && K.worded(Page) == "Page" && K.worded(K.HeadingLine) == "Heading Line"
  # The kinds are Centient's: a switch, a choice of two, a list of three or four, a list that's searched, a number, words
  @test K.chip_kind(nothing, chip(Bool)) == :switch
  @test K.chip_kind(nothing, chip(Type{Page}, Type{Folder})) == :segment
  @test K.chip_kind(nothing, chip(K.Colours)) == :pick && K.chip_kind(nothing, chip(K.Bundle)) == :pick
  @test K.chip_kind(nothing, chip(K.InsertKind)) == :search
  @test K.chip_kind(nothing, chip(Int)) == :number && K.chip_kind(nothing, chip(Real)) == :number
  @test K.chip_kind(nothing, chip(String)) == :text && K.chip_kind(nothing, chip(K.Date)) == :text
  # A chip's name is its argument's, as words, and its tooltip has the type too
  @test K.chip_name(K.Wanted([:due_date], Any[K.Date], false)) == "Due date"
  @test K.chip_name(K.Wanted([:heading, :line], Any[K.HeadingLine, Integer], false)) == "Heading or line"
  @test K.chip_tip(K.Wanted([:heading, :line], Any[K.HeadingLine, Integer], false)) == "heading or line (HeadingLine | Integer)"
  @test K.chip_tip(chip(Type{Page})) == "x (Type{Page})"
  @test K.key_signs(only(K.read_shortcuts("cmd+shift+p"))) == ["⌘", "⇧", "P"]
end

@testset "⌘⇧P slides the bar up from the bottom, and it slides down again" begin
  e, w = window()
  @test e.popup == :none && !K.palette_shows(e)
  lines = copy(e.buf.lines)
  w.keys |= cmd | shift; onkey(w, KeyPress{Keys.p}(0, w)); w.keys ⊻= cmd | shift
  p = K.palette(e)
  # It starts below the window, and comes up in a moment
  @test e.popup == :commands && K.palette_risen(e, p) < 0.5 && K.palette_moving(e)
  frames(w)
  @test K.palette_risen(e, p) == 1 && !K.palette_moving(e) && w.focus === K.input(e)
  plan = p.plan
  # The bar is along the bottom of the window, with the list over it
  @test plan.band.y + plan.band.h == 700 && plan.band.x == 0 && plan.band.w == 900
  @test plan.bar.x == 14 && plan.bar.w == 900 - 14 - 16 && plan.bar.h == 46 && plan.bar.y + plan.bar.h == 700 - 16
  list = plan.list
  # The card of rows is 6px over the bar's top line, as it is 6px inside the list's other sides
  @test list.kind == :attach && list.frame.y + list.frame.h == plan.bar.y && list.frame.y + 7 + list.tall + 2 == plan.bar.y - 6
  # The list is narrower than the bar by a tenth of it at each side, and in the middle of it
  @test list.frame.w == plan.bar.w - 2 * 87 && list.frame.x - plan.bar.x == plan.bar.x + plan.bar.w - (list.frame.x + list.frame.w)
  shot(w, "omni-open.png")
  # It lists every command that makes sense here, in the order of their names
  @test names(e) == sort(names(e)) && first(names(e)) == "Add To Favourites" && "Ask Agent" in names(e) && !("Ask About" in names(e))
  @test "Save" in names(e) && "Theme" in names(e) && "Insert" in names(e) && "Go To" in names(e)
  @test !("Left" in names(e)) && !("Commands" in names(e)) && !("Erase Back" in names(e))
  # ⌘⇧P again closes it. It stays in the window while it slides down.
  w.keys |= cmd | shift; onkey(w, KeyPress{Keys.p}(0, w)); w.keys ⊻= cmd | shift
  @test e.popup == :none && w.focus === e && K.palette_shows(e)
  frames(w)
  @test !K.palette_shows(e)
  # Esc in an empty bar closes it. With text, it empties the bar first.
  open_palette(w)
  typed(w, "sav")
  press(w, Keys.escape)
  @test e.popup == :commands && field(e) == ""
  press(w, Keys.escape)
  @test e.popup == :none && w.focus === e
  # The page under it is as it was
  @test e.buf.lines == lines
  # The bar is beside the sidebar when that shows
  K.toggle_panel!(e); e.slid = 0.0
  open_palette(w)
  @test p.plan.band.x == K.num(K.panel_w(e)) && p.plan.bar.x == K.num(K.panel_w(e)) + 14
  press(w, Keys.escape)
  close(w)
end

@testset "the letters typed find a command, and Return runs it" begin
  e, w = window()
  open_palette(w)
  typed(w, "sideb")
  @test names(e)[1] == "Sidebar"
  # The rest of the first name shows after the text, and Tab types it
  @test K.palette_ghost(e, K.palette(e)) == "ar"
  shot(w, "omni-typed.png")
  press(w, Keys.tab)
  @test field(e) == "Sidebar" && e.popup == :commands
  shown = e.panel
  press(w, Keys.enter)
  @test e.popup == :none && e.panel != shown && w.focus === e

  # Words of what a command does find it too
  open_palette(w)
  typed(w, "hidden files")
  @test names(e)[1] == "Hidden Files"
  press(w, Keys.escape); press(w, Keys.escape)
  open_palette(w)
  typed(w, "zzzz")
  @test isempty(names(e)) && K.palette(e).plan.list.words == "No command has that name"
  press(w, Keys.enter)          # with nothing in the list, Return does nothing
  @test e.popup == :commands
  press(w, Keys.escape); press(w, Keys.escape)
  close(w)
end

@testset "the arrows and the mouse choose a row" begin
  e, w = window()
  open_palette(w)
  p = K.palette(e)
  @test p.pick == 1
  press(w, Keys.down); press(w, Keys.down)
  @test p.pick == 3
  press(w, Keys.up)
  @test p.pick == 2
  press(w, Keys.up); press(w, Keys.up)
  @test p.pick == 1                                  # it stops at the first row
  over(w, e.nodes[(:palette_row, 3)])
  @test p.pick == 3
  # Many presses of ↓ bring a row that was out of sight into it
  foreach(_ -> press(w, Keys.down), 1:12)
  @test p.pick == 15 && p.scroll.offset > 0px
  # What's typed puts the first row back
  typed(w, "s")
  @test p.pick == 1
  # A click on a row takes it
  typed(w, "ideb")
  shown = e.panel
  click(w, e.nodes[(:palette_row, 1)])
  @test e.popup == :none && e.panel != shown
  # A click outside the list closes the palette. The list is tall, so the click is near the top of the window.
  open_palette(w)
  w.mouse = typeof(w.mouse)(450px, 60px)
  onmouse(w, MouseMove(Vec2{px}(450px, 60px), w))
  frames(w)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); w.keys ⊻= Keys.mouse_left
  frames(w)
  @test e.popup == :none
  close(w)
end

@testset "the wheel over the list scrolls the list, never the page under it" begin
  # A long page, scrolled part way, so it could move up or down
  e, w = window(join(("Line $n.\n" for n in 1:300), "\n"))
  e.scroll.offset = 400px; frames(w)
  open_palette(w)
  p = K.palette(e)
  over(w, e.nodes[(:palette_row, 2)])
  wheel(dy) = (onscroll(w, Vec2{px}(0px, dy)); frames(w))
  wheel(-1px)
  @test p.scroll.offset > 0px && e.scroll.offset == 400px
  sleep(0.25)                                         # a new run of the wheel
  foreach(_ -> wheel(5px), 1:3)                      # up past the top of the list
  @test p.scroll.offset == 0px && e.scroll.offset == 400px
  close(w)
end

@testset "a list of a few fixed things hangs over its chip" begin
  e, w = window()
  @test e.theme == :sepia
  take(w, "theme")
  p = K.palette(e)
  # The command's name is a tag, and its one chip has the colours in a list over it
  @test e.popup == :commands && p.command.name == :theme && p.at == 1 && kinds(e) == [:pick]
  @test names(e) == ["Sepia", "Paper", "Night"] && w.focus === p
  list, chip = p.plan.list, only(pl for pl in p.plan.places if pl.what == :chip)
  @test list.kind == :envelope && list.target == chip && list.frame.y + list.frame.h == chip.y - 10
  @test list.frame.w >= 200 && list.frame.x >= p.plan.bar.x
  shot(w, "omni-pick.png")
  # The mouse over the chip for a moment shows the argument's name and its type
  node = e.nodes[(:palette_chip, 1)]
  over(w, node)
  @test node.over > 0 && !any(pop -> pop.key == :tooltip, popups(w))
  node.over = time() - 0.45
  frame(w); frame(w)
  @test any(pop -> pop.key == :tooltip, popups(w))
  # It takes no text: the arrows choose, and say the row at once. The window shows each colours as the arrow reaches it.
  typed(w, "ni")
  @test names(e) == ["Sepia", "Paper", "Night"] && field(e) == ""
  press(w, Keys.down)
  @test e.theme == :paper && p.before == :sepia
  press(w, Keys.down)
  @test said(e, 1) == K.Colours(:night) && p.at == 1 && e.theme == :night
  # Return takes the row, and Theme runs at once: it changes nothing that you'd want to look at first
  @test K.runs_at_once(Val(:theme)) && !K.runs_at_once(Val(:rename)) && !K.runs_at_once(Val(:ask_agent))
  press(w, Keys.enter)
  @test e.theme == :night && e.popup == :none && w.focus === e && p.before === nothing
  take(w, "go to")
  shot(w, "omni-night.png")
  press(w, Keys.escape); press(w, Keys.escape)
  K.theme!(e, :sepia)
  # The mouse does the same: a click on a row
  take(w, "theme")
  click(w, e.nodes[(:palette_row, 2)])
  @test e.theme == :paper && e.popup == :none
  K.theme!(e, :sepia)

  # A command that waits for Run: Return takes the row and goes on to the Run button. Theme waits here, for a moment.
  @eval K runs_at_once(::Val{:theme}) = false
  take(w, "theme")
  press(w, Keys.down); press(w, Keys.enter)
  @test p.at == 2 && p.plan.list === nothing && e.theme == :paper
  shot(w, "omni-run.png")
  press(w, Keys.enter)
  @test e.theme == :paper && e.popup == :none
  K.theme!(e, :sepia)
  # The mouse does the same: a row, then the Run button
  take(w, "theme")
  click(w, e.nodes[(:palette_row, 2)])
  @test said(e, 1) == K.Colours(:paper) && p.at == 2
  # A click on the chip puts the keyboard back in it, at the row that it has
  click(w, e.nodes[(:palette_chip, 1)])
  @test p.at == 1 && p.pick == 2
  press(w, Keys.up)
  @test said(e, 1) == K.Colours(:sepia)
  # A click on the Run button under an open list runs the command with the row that the arrow said
  click(w, e.nodes[:palette_run])
  @test e.theme == :sepia && e.popup == :none
  # Tab takes the row that's chosen, as Return does
  take(w, "theme")
  press(w, Keys.down); press(w, Keys.tab)
  @test p.at == 2 && said(e, 1) == K.Colours(:paper) && e.theme == :paper
  # Esc puts back the colours that the page had before the arrows showed another
  press(w, Keys.escape); press(w, Keys.escape)
  @test e.theme == :sepia && e.popup == :none
  @eval K runs_at_once(::Val{:theme}) = true
  # So does a click outside the palette
  take(w, "theme")
  press(w, Keys.down)
  @test e.theme == :paper
  K.close_palette!(e)
  @test e.theme == :sepia
  close(w)
end

@testset "a list that's searched, and the type of what's said" begin
  e, w = window()
  take(w, "go to")
  p = K.palette(e)
  @test p.command.name == :go_to && kinds(e) == [:search] && w.focus === K.input(e)
  # The chip takes a heading of the page, or a line's number
  @test K.chip_name(only(chips(e))) == "Heading or line"
  @test names(e) == ["Plans", "Costs", "Dates"] && field(e) == ""
  shot(w, "omni-search.png")
  # The letters keep the rows that have them, and the rest of the row's name shows after them
  typed(w, "cos")
  @test names(e) == ["Costs"] && K.palette_ghost(e, p) == "ts" && said(e, 1) === K.UNSAID
  # Return takes the row, and Go To runs at once
  press(w, Keys.enter)
  @test e.popup == :none && e.buf.caret[1] == 5

  # Letters that write a number make a row of it, after the headings that have them
  take(w, "go to")
  typed(w, "9")
  @test names(e) == ["9"]
  press(w, Keys.enter)
  @test e.popup == :none && e.buf.caret[1] == 9

  # An arrow says its row at once. The field has the row's words then, and the rows stay.
  take(w, "go to")
  press(w, Keys.down)
  @test said(e, 1) == K.HeadingLine(5, "Costs") && field(e) == "Costs" && names(e) == ["Plans", "Costs", "Dates"]
  # Typing takes its place, and takes away what the chip had
  typed(w, "d")
  @test field(e) == "d" && said(e, 1) === K.UNSAID && names(e) == ["Dates"]
  # Tab takes the row, as Return does. ⇧Tab comes back, with the chip's row chosen and nothing in the field.
  press(w, Keys.tab)
  @test p.at == 2 && said(e, 1) == K.HeadingLine(9, "Dates")
  press(w, Keys.tab, shift)
  @test p.at == 1 && field(e) == "" && p.pick == 3
  # ⌫ in the empty field takes away what the chip has
  press(w, Keys.backspace)
  @test said(e, 1) === K.UNSAID
  # Letters that no row has
  typed(w, "zzz")
  @test isempty(names(e)) && p.plan.list.words == "No matches found"
  press(w, Keys.escape); press(w, Keys.escape)

  # What the function throws shows over the bar, and the palette stays
  take(w, "go to")
  typed(w, "999"); press(w, Keys.enter)
  @test e.popup == :commands && p.fault == "Command failed: The page has $(length(e.buf.lines)) lines." && e.buf.caret[1] == 9
  shot(w, "omni-fault.png")
  press(w, Keys.escape); press(w, Keys.escape)
  @test e.popup == :none
  close(w)
end

@testset "a choice of two, words, a number and a switch" begin
  K.add_command!(make, group="Tests")
  K.add_command!(count_to, group="Tests")
  K.add_command!(due, group="Tests")
  K.add_command!(ping, group="Tests")
  K.add_command!(opaque, group="Tests")
  K.add_command!(shout, group="Tests")
  e, w = window()
  p = K.palette(e)
  @test K.COMMANDS[:make].title == "Make a page or a folder"

  # The first chip chooses between the methods. Both show in it, and the chips after it wait.
  take(w, "make")
  @test kinds(e) == [:segment] && said(e, 1) === K.UNSAID && w.focus === p
  shot(w, "omni-segment.png")
  # → chooses the next, and the chips of its method show at once
  press(w, Keys.right)
  @test said(e, 1) === Page && kinds(e) == [:segment, :text]
  press(w, Keys.right)
  @test said(e, 1) === Folder && kinds(e) == [:segment, :text, :number, :switch]
  # Return chooses the next too, and stays in the chip. ← chooses the one before.
  press(w, Keys.enter)
  @test said(e, 1) === Page && p.at == 1
  press(w, Keys.left)
  @test said(e, 1) === Folder
  press(w, Keys.space)
  @test said(e, 1) === Page
  press(w, Keys.left)
  # Words are the chip's as they're typed
  press(w, Keys.tab)
  @test p.at == 2 && w.focus === K.input(e)
  typed(w, "plans")
  @test said(e, 2) == "plans"
  press(w, Keys.enter)
  # A number too. Text that writes no number leaves the chip as it was, and Return puts the field back.
  @test p.at == 3
  typed(w, "x")
  @test said(e, 3) === K.UNSAID
  press(w, Keys.enter)
  @test p.at == 3 && field(e) == ""
  typed(w, "3")
  @test said(e, 3) === 3
  # ↑ and ↓ add one and take one away
  press(w, Keys.up)
  @test said(e, 3) === 4 && field(e) == "4"
  press(w, Keys.down)
  @test said(e, 3) === 3
  press(w, Keys.enter)
  # A switch: Space turns it, and Return turns it and goes on
  @test p.at == 4 && w.focus === p
  press(w, Keys.space)
  @test said(e, 4) === true
  press(w, Keys.space)
  @test said(e, 4) === false
  press(w, Keys.enter)
  @test said(e, 4) === true && p.at == 5
  shot(w, "omni-chips.png")
  # ⇧Tab goes back a chip, and Tab on to the Run button and round to the first chip
  press(w, Keys.tab, shift)
  @test p.at == 4
  press(w, Keys.tab); press(w, Keys.tab)
  @test p.at == 1
  # The other kind has the chips of its own method, and keeps the name, which that method takes too
  press(w, Keys.left)
  @test said(e, 1) === Page && length(chips(e)) == 2 && said(e, 2) == "plans"
  press(w, Keys.tab)
  @test p.at == 2 && field(e) == "plans"
  press(w, Keys.tab)
  @test p.at == 3
  press(w, Keys.enter)
  @test calls[end] == (:page, "plans") && e.popup == :none

  # Tab in a choice of two that has nothing gives it its first thing
  take(w, "make")
  press(w, Keys.tab)
  @test said(e, 1) === Page && p.at == 2
  # A click on the chip chooses the other
  click(w, e.nodes[(:palette_chip, 1)])
  @test said(e, 1) === Folder && p.at == 1
  # A click on a switch turns it
  click(w, e.nodes[(:palette_chip, 4)])
  @test said(e, 4) === true && p.at == 4
  # Esc empties the bar, and the list of commands is back
  press(w, Keys.escape)
  @test e.popup == :commands && p.command === nothing && field(e) == "" && length(names(e)) > 10
  press(w, Keys.escape)

  # A chip that can be left out. Return goes on from a chip whatever it has.
  take(w, "count to")
  @test kinds(e) == [:number, :number]
  press(w, Keys.enter); press(w, Keys.enter)
  @test p.at == 3
  # The Run button with a chip that's needed still empty sends the keyboard to that chip
  n = length(calls)
  press(w, Keys.enter)
  @test p.at == 1 && length(calls) == n && e.popup == :commands && p.fault == "N has nothing yet"
  typed(w, "5")
  @test p.fault == ""
  press(w, Keys.tab); press(w, Keys.tab); press(w, Keys.enter)
  @test calls[end] == (:count, 5, 1)
  take(w, "count to")
  typed(w, "5"); press(w, Keys.enter); typed(w, "2"); press(w, Keys.enter); press(w, Keys.enter)
  @test calls[end] == (:count, 5, 2)

  # A day is typed
  take(w, "due")
  @test kinds(e) == [:text]
  typed(w, "2026-11-25")
  @test said(e, 1) == K.Date(2026, 11, 25)
  press(w, Keys.enter); press(w, Keys.enter)
  @test calls[end] == (:due, K.Date(2026, 11, 25))

  # A function that takes only the editor and the window runs when it's taken
  take(w, "ping")
  @test calls[end] == (:ping, e, w) && e.popup == :none

  # One that the palette can't ask the arguments of isn't in the list. Its keys say that it has nothing to work on.
  open_palette(w); typed(w, "opaque")
  @test !("Opaque" in names(e))
  press(w, Keys.escape); press(w, Keys.escape)
  K.open_palette!(e, K.COMMANDS[:opaque]); frames(w)
  @test e.popup == :commands && p.command === nothing && occursin("nothing to work on", p.fault)
  press(w, Keys.escape); press(w, Keys.escape)
  close(w)
end

@testset "⌥ shows the chips of the keyword arguments" begin
  e, w = window()
  p = K.palette(e)
  take(w, "shout")
  @test kinds(e) == [:text]
  typed(w, "hey")
  press(w, Keys.opt)
  @test kinds(e) == [:text, :switch, :number] && p.advanced
  press(w, Keys.opt)
  @test kinds(e) == [:text] && !p.advanced
  # Without them, the function has what it gives them itself
  press(w, Keys.tab); press(w, Keys.enter)
  @test calls[end] == (:shout, "hey", false, 1)
  take(w, "shout")
  typed(w, "hey"); press(w, Keys.opt); press(w, Keys.tab)
  @test p.at == 2
  press(w, Keys.space); press(w, Keys.tab)
  typed(w, "3")
  @test said(e, 2) === true && said(e, 3) === 3
  shot(w, "omni-advanced.png")
  # Hiding them from the last one puts the keyboard on the Run button
  press(w, Keys.opt)
  @test p.at == 2 && length(chips(e)) == 1
  press(w, Keys.enter)
  @test calls[end] == (:shout, "hey", true, 3)
  close(w)
end

@testset "chips that don't fit end in …, and then go on more lines" begin
  e, w = window(size=(420px, 600px))
  p = K.palette(e)
  take(w, "make")
  press(w, Keys.right); press(w, Keys.right)       # a folder, which has four chips
  press(w, Keys.tab)
  typed(w, "a long name for a folder of plans")
  @test p.plan.more && !p.wrap
  @test !any(pl -> pl.what == :run, p.plan.places) && p.plan.bar.h == 54
  shot(w, "omni-more.png")
  # Tab to a chip that doesn't show puts them all on as many lines as they need
  press(w, Keys.tab)
  @test p.at == 3 && p.wrap && !p.plan.more
  @test any(pl -> pl.what == :run, p.plan.places) && length(unique(pl.y for pl in p.plan.places)) > 1 && p.plan.bar.h > 54
  shot(w, "omni-wrap.png")
  press(w, Keys.escape); press(w, Keys.escape)
  # A click on the … does the same
  take(w, "make")
  press(w, Keys.right); press(w, Keys.right); press(w, Keys.tab)
  typed(w, "a long name for a folder of plans")
  click(w, e.nodes[:palette_more])
  @test p.wrap && p.at == 2
  press(w, Keys.escape); press(w, Keys.escape)
  close(w)
end

@testset "the keys of a command that asks open the palette with it taken" begin
  e, w = window()
  p = K.palette(e)
  K.rebind!(e, :theme, only(K.read_shortcuts("ctrl+opt+t")))
  press(w, Keys.t, Keys.ctrl, Keys.opt)
  @test e.popup == :commands && p.command.name == :theme && names(e) == ["Sepia", "Paper", "Night"]
  # The palette's own row shows the keys of a command, one key in each box
  press(w, Keys.escape)
  typed(w, "theme")
  @test K.key_signs(K.palette_rows(e, p)[1].keys) == ["⌃", "⌥", "T"]
  press(w, Keys.escape); press(w, Keys.escape)
  K.put_back!(e, :theme)
  # With the keys of Emacs, ⌥X opens the palette too, as M-x does there
  K.bundle!(e, "Emacs")
  press(w, Keys.x, Keys.opt)
  @test e.popup == :commands && p.command === nothing
  press(w, Keys.escape)
  K.bundle!(e, "Ladder")
  close(w)
end

@testset "the other commands that ask" begin
  e, w = window()
  p = K.palette(e)
  take(w, "text size")
  @test kinds(e) == [:number]
  # These run as soon as their chip has something: Return after the number runs it
  typed(w, "20"); press(w, Keys.enter)
  @test K.text_size(e) == 20 && e.popup == :none
  take(w, "text size"); typed(w, "17"); press(w, Keys.enter)
  # ↑ counts from the size that the text is now, and the page shows each size at once. Esc puts back the size that it had.
  take(w, "text size"); press(w, Keys.up); press(w, Keys.up)
  @test K.text_size(e) == 19 && e.popup == :commands
  press(w, Keys.escape); press(w, Keys.escape)
  @test K.text_size(e) == 17 && e.popup == :none
  # A switch that isn't touched is off, and doesn't run the command by itself: Tab goes on to the Run button
  take(w, "spelling")
  @test kinds(e) == [:switch] && e.popup == :commands
  press(w, Keys.tab); press(w, Keys.enter)
  @test !e.spelling
  take(w, "spelling"); press(w, Keys.enter)
  @test e.spelling && e.popup == :none
  take(w, "key bindings")
  @test kinds(e) == [:pick] && names(e) == ["Ladder", "VS Code", "Sublime Text", "Emacs"]
  foreach(_ -> press(w, Keys.down), 1:3); press(w, Keys.enter)
  @test e.bundle == "Emacs"
  take(w, "key bindings"); press(w, Keys.enter)
  @test e.bundle == "Ladder"
  # A new block goes where the caret is
  e.buf.caret = e.buf.anchor = (3, 0); K.touch!(e); frame(w)
  take(w, "insert")
  @test kinds(e) == [:search]
  typed(w, "divider"); press(w, Keys.enter)
  @test "---" in e.buf.lines && e.popup == :none
  close(w)
end

@testset "a file that's only shown has only the commands that it can take" begin
  path = joinpath(dir, "data.bin")
  write(path, UInt8[0x00, 0x01, 0xff, 0xfe])
  e = K.build_editor(path)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  K.focus(e)
  @test K.readonly(e.buf)
  open_palette(w)
  @test e.popup == :commands
  @test "Sidebar" in names(e) && "Theme" in names(e)
  @test !("Insert" in names(e)) && !("Undo" in names(e)) && !("Bold" in names(e))
  press(w, Keys.escape)
  close(w)
end

@testset "what's in focus gives an argument that isn't asked for" begin
  e, w = window()
  file = K.object(e, e.buf.path)
  focus = K.in_focus(e)
  # The file that shows is in focus, then the folder that holds it, with the text of the page before them
  @test file isa K.FS.File{:md} && any(x -> x === file, focus) && any(x -> x isa K.AbstractDirectory && at(x, dir), focus)
  @test findfirst(x -> x isa K.Document, focus) < findfirst(x -> x === file, focus)
  @test !any(x -> x === e || x === w, focus)
  # The window's own, a thing in focus by its type, and what's asked for
  @test K.given(:e, Any, focus) == :editor && K.given(:editor, K.Editor, focus) == :editor && K.given(:w, Any, focus) == :window
  @test K.given(:f, K.FSObject, focus) === file && K.given(:d, K.AbstractDirectory, focus) isa K.AbstractDirectory
  @test K.given(:words, String, focus) === nothing      # asked for
  @test K.given(:x, Any, focus) === nothing             # no type, so nothing in focus is it
  @test K.given(:d, K.GitDirectory, focus) === nothing  # no such thing is in focus
  # A method is one that the palette can call when something gives each argument
  sigs = K.callable_methods(stamp, focus)
  @test length(sigs) == 2 && all(sig -> K.focus_taken(sig) == Any[file], sigs)
  @test length(K.asks(sigs[1])) == 0 && [a.name for a in K.asks(sigs[2])] == [:words]
  @test isempty(K.callable_methods(stamp)) && isempty(K.callable_methods(fetch_new, focus))
  close(w)
end

@testset "the palette lists the commands that what's in focus takes" begin
  K.add_command!(stamp, group="Tests")
  K.add_command!(fetch_new, group="Tests")
  K.add_command!(count_text, group="Tests")
  e, w = window()
  p = K.palette(e)
  file = K.object(e, e.buf.path)
  open_palette(w)
  @test all(in(names(e)), ["Rename", "Duplicate", "Move To Trash", "Show In Finder", "Copy Path", "New Page", "New Folder", "Stamp", "Count Text"])
  @test !("Fetch New" in names(e))
  # A row says which thing its command works on
  on(name) = only(row.on for row in K.palette_rows(e, p) if row.name == name)
  @test on("Rename") == "page.md" && on("Move To Trash") == "page.md" && on("New Page") == basename(dir) && on("Theme") == "" && on("Save") == ""
  shot(w, "omni-focus.png")
  press(w, Keys.escape)
  # The function gets the thing in focus, and the palette asks for the rest
  take(w, "stamp")
  @test p.command.name == :stamp && kinds(e) == [:text]
  typed(w, "paid"); press(w, Keys.enter); press(w, Keys.enter)
  @test calls[end] == (:stamp, file, "paid")
  take(w, "count text")
  @test calls[end][1] == :count_text && calls[end][2] isa K.Document && e.popup == :none
  # A part of the window has no name to show in a row
  @test K.palette_target(K.COMMANDS[:count_text], K.in_focus(e)) == ""
  # Rename puts the name in the top bar, since the sidebar is closed
  take(w, "rename")
  @test e.popup == :none && K.renaming(e, :title) == e.buf.path
  K.stop_rename!(e)
  take(w, "duplicate")
  @test isfile(joinpath(dir, "page copy.md"))
  rm(joinpath(dir, "page copy.md"))
  close(w)

  # A file in a git folder has the commands of a git folder too
  repo = joinpath(dir, "repo")
  mkpath(joinpath(repo, "notes"))
  K.PLACE_KINDS[realpath(repo)] = K.GitDirectory
  K.PLACE_KINDS[repo] = K.GitDirectory
  e, w = window(name="repo/todo.md")
  open_palette(w)
  @test "Fetch New" in names(e)
  press(w, Keys.escape)
  take(w, "fetch new")
  @test calls[end][1] == :fetch_new && calls[end][2] isa K.GitDirectory
  close(w)
  # A folder inside a git folder is of that kind too, so a file there has the same commands
  e, w = window(name="repo/notes/idea.md")
  open_palette(w)
  @test "Fetch New" in names(e) && "Rename" in names(e)
  press(w, Keys.escape)
  close(w)
  # A file in a plain folder has none of them
  e, w = window(name="plain.md")
  open_palette(w)
  @test !("Fetch New" in names(e)) && "Rename" in names(e)
  press(w, Keys.escape)
  close(w)
end

@testset "the kind of page says which commands have a use" begin
  e, w = window("# Plans\n\nSome words.\n\n```julia\nx = 1\n```\n")
  open_palette(w)
  @test all(in(names(e)), ["Bold", "Italic", "Insert", "Export", "Print", "Slides", "Save"]) && !("Comment" in names(e))
  # Nothing showed before this page, so there's nothing to go back to. Nothing is found, so there's no next place.
  @test !("Back" in names(e)) && !("Forward" in names(e)) && !("Find Next" in names(e)) && "Find" in names(e)
  press(w, Keys.escape)
  # With the caret in a line of code, a comment can be made
  e.buf.caret = e.buf.anchor = (6, 0); K.touch!(e); frame(w)
  open_palette(w)
  @test "Comment" in names(e)
  press(w, Keys.escape)
  close(w)
  # A file of code is no page of Markdown
  e, w = window("x = 1\ny = 2\n", name="sums.jl")
  open_palette(w)
  @test all(in(names(e)), ["Comment", "Save", "Rename", "Go To"])
  @test !any(in(names(e)), ["Bold", "Italic", "Insert", "Export", "Print", "Slides"])
  press(w, Keys.escape)
  close(w)
end

@testset "the part that has the keyboard is in focus, and gets the keyboard back" begin
  e, w = window()
  p = K.palette(e)
  write(joinpath(dir, "other.md"), "# Other\n")
  # A part of the window with one file chosen in it puts that file in focus, before the file that shows
  shelf = K.own!(e, Shelf(path=dir, chosen=Set(["other.md"])))
  @test K.chosen_path(shelf) == joinpath(dir, "other.md")
  push!(shelf.chosen, "page.md")
  @test K.chosen_path(shelf) === nothing      # two are chosen, so no one file is
  pop!(shelf.chosen, "page.md")
  K.focus(shelf)
  focus = K.in_focus(e)
  @test focus[1] isa K.FS.File && at(focus[1], joinpath(dir, "other.md")) && focus[2] === shelf
  @test K.palette_target(K.COMMANDS[:rename], focus) == "other.md"
  # The page's own text has the keyboard, the palette takes it, and gives it back
  K.focus(e)
  open_palette(w)
  @test w.focus === K.input(e) && p.had === e
  press(w, Keys.escape)
  @test w.focus === e && p.had === nothing
  close(w)
end
