# Tests for a page that shows as slides: see "a page as slides" in main.jl.
# Run them with `julia -O0 --project=. test/slides_view_test.jl`. They press
# keys and click in windows that aren't on the screen. Set `LADDER_SHOTS` to
# a folder, and they save a picture of each slide there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys Typed onkey onmouse ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
const kept = joinpath(dir, "settings")
@eval K settings_file() = $kept

const LONG = join(["Paragraph $k of a slide that's too tall for the window, with enough words to fill a line or two of the page." for k in 1:16], "\n\n")
const TEXT = """
---
title: The bathroom
---

Some words before the first heading.

# The bathroom

A plan for the client.

## The work

- [ ] Strip the room
- [x] Order the tiles
- Look at [the costs](#the-costs), or at [another page](other.md)

### Notes

The tiles come on Monday.

---

## How it goes

```mermaid
flowchart LR
  A[Strip the room] --> B[Lay the tiles] --> C[Paint]
```

## The costs

| Item | Cost |
|---|---|
| Tiles | 900 |
| Paint | 120 |

\$\$
total = tiles + paint
\$\$

## Every step

$LONG

## The end
"""
const page = joinpath(dir, "bathroom.md")
write(page, TEXT)
write(joinpath(dir, "other.md"), "# Another page\n\nWith words.\n")

const e = K.build_editor(page)
const w = K.window!(e, size=(1000px, 800px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
e.panel = true   # the sidebar shows
frames(3)
shot(name, win=w) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), win)

"Press the key `k` with the keys `held` down"
key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = begin
  at(place)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames()
end
caret!(line, col=0) = (e.buf.caret = e.buf.anchor = (line, col); K.touch!(e); frames())
line_of(text) = findfirst(==(text), e.buf.lines)
show() = K.slideshow(e)
"The first line of each item that the window lays out"
shown() = [e.buf.lines[it.first] for it in e.layout]
"The words that `node` draws"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
"The number of the slide, as the window writes it at its bottom right"
counter() = only(texts(only(K.slides_over(e))))
"The kinds of node that the top bar draws"
bar_parts(node=K.describe(e.nodes[:topbar]), out=Any[]) = begin
  (node isa K.GeometricUI && !(node isa K.Text)) || return out
  hasproperty(node, :from) && node.from isa K.SemanticUI && push!(out, typeof(node.from))
  foreach(n -> bar_parts(n, out), node.children)
  out
end
"The first place on the page that `found` is true for, looking down the text and across it"
place(found) = begin
  x0, y0 = K.num(e.origin[1]), K.num(e.origin[2])
  for y in y0:3:y0+700, x in x0+4:8:x0+700
    found((px(x), px(y))) && return (x, y)
  end
  nothing
end
const cmd, ctrl, opt, shift = Keys.cmd, Keys.ctrl, Keys.opt, Keys.shft

@testset "⌃⌘⇧P shows the slide that the caret is in" begin
  @test K.caps(first(K.keys_now(e).of[:slides])) == "⌃⌘⇧P" && "Show as Slides" in K.PAGE_MENU
  @test !isempty(bar_parts()) && rect(e.nodes[:sidebar]) !== nothing
  caret!(line_of("- [x] Order the tiles"), 8)
  n = length(e.layout)
  key(Keys.p, cmd, ctrl, shift)
  s = show()
  @test s !== nothing && s.at == 3 && length(s.list) == 7 && counter() == "3 / 7"
  # The slide's lines are all that's laid out, down to the line before the line across the page
  @test length(e.layout) < n && first(shown()) == "## The work" && last(shown()) == "The tiles come on Monday."
  # The sidebar and everything in the top bar go, and the page has no caret
  @test isempty(bar_parts()) && !e.panel && K.text_left(e) == (1000px - e.width) / 2
  @test e.buf.reading && !K.selecting(e.buf) && K.cursor(e.nodes[:document]) == :arrow
  # The text is bigger, as much as fits the window's height, and the slide is in the middle of the room it has
  room = K.slide_room(e)
  @test 1.0 < s.scale <= 2.0 && e.zoom == s.scale && s.tall <= room && e.scroll.offset == 0px
  @test abs(e.layout[1].top - (room - s.tall) / 2) <= 1px
  @test e.scroll.content_height <= e.scroll.viewport
  shot("slide-list.png")
end

@testset "the keys go from slide to slide" begin
  key(Keys.right)
  @test show().at == 4 && counter() == "4 / 7" && shown()[1] == "## How it goes"
  @test any(it -> it.content isa K.Live, e.layout)   # the diagram shows as a diagram
  shot("slide-diagram.png")
  for (k, to) in ((Keys.down, 5), (Keys.space, 6), (Keys.pagedown, 7), (Keys.left, 6), (Keys.up, 5), (Keys.pageup, 4), (Keys.enter, 5))
    key(k)
    @test show().at == to
  end
  shot("slide-table.png")
  key(Keys.space, shift)
  @test show().at == 4
  # A key turns the slides only by itself, and Space only with ⇧. With ⌃ or ⌥, ⇧ on another key, or all four held, it turns none.
  for held in ((Keys.opt,), (Keys.ctrl,), (shift,), (Keys.cmd, Keys.opt, Keys.ctrl, shift))
    key(Keys.right, held...)
    @test show().at == 4
  end
  key(Keys.space, Keys.opt)
  @test show().at == 4
  key(Keys.home)
  @test show().at == 1 && shown() == ["Some words before the first heading."]
  # The front matter is in no slide
  @test !any(it -> it.first <= 3, e.layout)
  key(Keys.left)
  @test show().at == 1
  key(Keys._end)
  @test show().at == 7 && shown() == ["## The end"] && counter() == "7 / 7"
  # A slide with only a heading has text twice as big as the page's
  @test show().scale == 2.0 && e.zoom == 2.0
  shot("slide-heading.png")
  # The last slide is the last
  key(Keys.right); key(Keys.enter)
  @test show().at == 7
end

@testset "a slide that's too tall scrolls" begin
  key(Keys.left)
  s = show()
  @test s.at == 6 && s.scale == 1.0 && e.zoom == 1.0 && s.tall > K.slide_room(e)
  @test e.layout[1].top == 0px && e.scroll.content_height > e.scroll.viewport
  shot("slide-tall.png")
  # Another slide starts at its top
  e.scroll.offset = 300px; frames()
  key(Keys.right); key(Keys.left)
  @test show().at == 6 && e.scroll.offset == 0px
  # Another slide gives the keyboard back to the page, from a part of the window that had it
  K.focus(e.nodes[:topbar])
  key(Keys.right)
  @test show().at == 7 && w.focus === e
  key(Keys.left)
end

@testset "nothing that's typed changes the text" begin
  before = copy(e.buf.lines)
  ontype(w, Typed('a', w)); frames()
  key(Keys.a); key(Keys.backspace); key(Keys.delete); key(Keys.tab)
  key(Keys.b, cmd); key(Keys.x, cmd); key(Keys.k, cmd, shift); key(Keys.z, cmd)
  @test e.buf.lines == before && !K.dirty(e.buf) && show().at == 6 && e.buf.reading
  # The keys that change the size of the page's text, and the one that shows the sidebar, do nothing
  key(Keys.equal, cmd); key(Keys.backslash, cmd); key(Keys.e, cmd)
  @test e.zoom == 1.0 && show().zoom == 1.0 && !e.panel && !e.plain
  # A file that's dropped on a slide doesn't go into the text, and a right-click shows no menu
  K.onfiledrop(e, w, [joinpath(dir, "other.md")]); frames()
  w.keys |= Keys.mouse_right; onkey(w, KeyPress{Keys.mouse_right}(0, w)); w.keys ⊻= Keys.mouse_right; frames()
  @test e.buf.lines == before && isempty(popups(w))
end

@testset "a click goes on or back, and a click on a box ticks it" begin
  key(Keys.home); key(Keys.right); key(Keys.right)
  @test show().at == 3
  click((900, 400))
  @test show().at == 4
  click((60, 400))
  @test show().at == 3
  # A click with ⌘, ⌥, ⌃ or ⇧ held turns no slide
  for held in (Keys.cmd, Keys.opt, Keys.ctrl, shift)
    w.keys |= held; click((900, 400)); w.keys ⊻= held
    @test show().at == 3
  end
  # The box of a to-do item
  box = place(p -> K.todo_at(e, p) == line_of("- [ ] Strip the room"))
  at(box)
  @test K.cursor(e.nodes[:document]) == :hand
  click(box)
  @test line_of("- [x] Strip the room") !== nothing && show().at == 3 && K.dirty(e.buf)
  click(box)
  @test line_of("- [ ] Strip the room") !== nothing && show().at == 3
  click(box)
  # A link to a heading of the page shows that heading's slide
  link = place(p -> K.link_on(e, p) == "#the-costs")
  # With a key of ⌃, ⌘, ⌥ or ⇧ held, a click on the link opens nothing, and the mouse isn't a hand there
  for held in (Keys.cmd, shift, Keys.cmd | Keys.opt | Keys.ctrl | shift)
    at(link); w.keys |= held; frames(1)
    @test K.cursor(e.nodes[:document]) != :hand
    click(link); w.keys = Keys(0); frames()
    @test show().at == 3
  end
  click(link)
  @test show() !== nothing && show().at == 5 && shown()[1] == "## The costs"
  @test e.buf.reading && e.scroll.offset == 0px
end

@testset "esc shows the page again" begin
  key(Keys.right)
  @test show().at == 6
  key(Keys.escape)
  @test show() === nothing && e.zoom == 1.0 && e.panel && !e.buf.reading
  @test !isempty(bar_parts()) && rect(e.nodes[:sidebar]) !== nothing
  # The caret is at the start of the slide that showed last, near the top of the window
  i = line_of("## Every step")
  @test e.buf.caret[1] == i && !K.selecting(e.buf) && length(e.layout) > 20
  it = K.item(e, i)
  @test e.scroll.offset <= it.top + K.PAGE_TOP < e.scroll.offset + 100px
  # ⌘Z takes back the tick that was made in the slides
  @test line_of("- [x] Strip the room") !== nothing
  key(Keys.z, cmd)
  @test line_of("- [ ] Strip the room") !== nothing
  # Typing works again
  caret!(line_of("## The end"), 10)
  ontype(w, Typed('!', w)); frames()
  @test line_of("## The end!") !== nothing
  key(Keys.z, cmd)
end

@testset "slides that end where they started leave the caret and the page where they were" begin
  caret!(line_of("- [x] Order the tiles"), 8)
  e.scroll.offset = 40px; frames()
  key(Keys.p, cmd, ctrl, shift)
  @test show().at == 3
  key(Keys.right); key(Keys.left)
  key(Keys.p, cmd, ctrl, shift)   # the command's own key ends them too
  frames()
  @test show() === nothing && e.buf.caret == (line_of("- [x] Order the tiles"), 8) && e.scroll.offset == 40px
  e.scroll.offset = 0px; frames()
end

@testset "the page's menu starts the slides, and a link to another page ends them" begin
  caret!(line_of("### Notes"), 6)
  K.page_act!(e, findfirst(==("Show as Slides"), K.PAGE_MENU)); frames()
  @test show() !== nothing && show().at == 3
  link = place(p -> K.link_on(e, p) == "other.md")
  click(link)
  @test show() === nothing && basename(e.buf.path) == "other.md" && e.zoom == 1.0 && e.panel
  # The page that the slides were of has its caret again, and is where it was
  @test !e.buffers[page].reading && e.buffers[page].offset == 0px
  K.open!(e, page); frames()
  # A page with nothing to show has no slides, and nor has a file of code
  empty = joinpath(dir, "empty.md")
  write(empty, "---\ntitle: Nothing\n---\n\n")
  K.open!(e, empty); frames()
  K.slides!(e); frames()
  @test show() === nothing
  code = joinpath(dir, "code.jl")
  write(code, "# A heading\nx = 1\n")
  K.open!(e, code); frames()
  K.slides!(e); frames()
  @test show() === nothing
  K.open!(e, page); frames()
end

@testset "the slides show what the file has when it changes on the disk" begin
  caret!(line_of("## The costs"), 4)
  K.slides!(e); frames()
  @test show().at == 5 && counter() == "5 / 7"
  save(text) = (was = mtime(page); write(page, text); while mtime(page) == was; sleep(0.01); touch(page) end; frames(3))
  # A new slide before this one: the slide with the same number shows
  save(replace(TEXT, "## The work" => "## Before the work\n\nMeasure the room.\n\n## The work"))
  @test show().at == 5 && counter() == "5 / 8" && shown()[1] == "## How it goes"
  # New words in the slide show
  save(replace(TEXT, "## How it goes" => "## How it all goes"))
  @test show().at == 5 && counter() == "5 / 7" && shown()[1] == "## The costs"
  key(Keys.left)
  @test shown()[1] == "## How it all goes"
  key(Keys._end)
  @test show().at == 7
  # Fewer slides than the number of this one: the last one shows
  save("# One\n\nWords.\n\n## Two\n\nMore words.\n")
  @test show() !== nothing && show().at == 2 && counter() == "2 / 2" && shown()[1] == "## Two"
  # A page with nothing left to show ends the slides
  save("\n")
  @test show() === nothing && e.zoom == 1.0
  save(TEXT)
end

@testset "the slides belong to one window" begin
  other = K.build_editor(page)
  w2 = K.window!(other, size=(900px, 700px))
  frame(w2); frame(w2)
  n = length(other.layout)
  caret!(line_of("## The end"), 4)
  K.slides!(e); frames()
  @test show().scale == 2.0 && e.zoom == 2.0
  frame(w2)
  @test K.slideshow(other) === nothing && other.zoom == 1.0 && length(other.layout) == n
  # A setting that's kept while the slides show keeps the page's own zoom, and gives the other window that one
  K.stat!(e, :chars); frame(w2); frames()
  @test other.stat == :chars && other.zoom == 1.0 && e.zoom == 2.0 && show().zoom == 1.0
  # A zoom that the other window sets is the page's zoom when the slides end
  K.zoom!(other, K.zoom_for(20)); frames(); frame(w2)
  @test show().zoom == other.zoom && e.zoom == other.zoom * show().scale
  key(Keys.escape)
  @test e.zoom == other.zoom == K.zoom_for(20)
  K.zoom!(e, 1.0); K.stat!(e, :words); frames(); frame(w2)
  close(w2)
end

@testset "the slides have the same key in every bundle, and no other command has it" begin
  for (bundle, _) in K.BUNDLES
    of = K.bundle_keys(bundle)
    @test K.caps(first(of[:slides])) == "⌃⌘⇧P"
    @test [name for (name, strokes) in of if any(s -> K.caps(s) == "⌃⌘⇧P", strokes)] == [:slides]
  end
  # Printing has the key that the slides first had, since ⌘P finds a project
  @test K.caps(first(K.bundle_keys("VS Code")[:print])) == "⌘⌥P"
end

@testset "the dark page and a narrow window" begin
  caret!(line_of("- [x] Order the tiles"), 8)
  K.slides!(e); frames()
  wide = show().scale
  K.theme!(e, :night); frames()
  @test show() !== nothing && show().at == 3 && show().scale == wide
  shot("slide-list-night.png")
  key(Keys.right); shot("slide-diagram-night.png")
  key(Keys.right); key(Keys.right); shot("slide-tall-night.png")
  key(Keys.escape)
  K.theme!(e, :sepia); frames()
  # A narrow window wraps the words, so the text is smaller there, and the slide still fits
  narrow = K.build_editor(page)
  w3 = Window(narrow, size=(520px, 700px))
  frame(w3); frame(w3)
  narrow.buf.caret = narrow.buf.anchor = (line_of("- [x] Order the tiles"), 8)
  K.slides!(narrow); frame(w3); frame(w3)
  s = K.slideshow(narrow)
  @test s.at == 3 && 1.0 <= s.scale < wide && s.tall <= K.slide_room(narrow) && narrow.width <= 520px - 2K.PAGE_X
  shot("slide-list-narrow.png", w3)
  K.go_slide!(narrow, 4); frame(w3); frame(w3)
  shot("slide-diagram-narrow.png", w3)
  K.end_slides!(narrow)
  close(w)
  @test isempty(K.editors)
end
