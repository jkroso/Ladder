# Tests for the runs of a line's text that ⌘⌥ picks, in main.jl's "the code of
# a thing": a link, bold words, inline code and the like in a paragraph. Each is
# a run of text and not a part of the window, so the part under the mouse is
# the whole paragraph. ⌘⌥ picks the run under the mouse all the same, with the
# function that gives it its look. Run them with
# `julia -O0 --project=. test/text_run_test.jl`. They click in a window that
# isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a picture
# of the line round a link there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect scene draw draw_tool window_tool
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = joinpath(tempdir(), "ladder-text-run-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
@eval K settings_file() = $(joinpath(dir, "settings"))
const page = joinpath(dir, "runs.md")
write(page, """
# Runs

Words with a [link](https://example.com), `code`, **bold**, *slanted*, ~~struck~~, a [[wiki]], a note[^1] and a switch !`Checkbox()` here.

- [ ] A thing to do

The end.

[^1]: The note.
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
frames(n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames(4)
e.buf.anchor = e.buf.caret = (7, 0); K.touch!(e); frames(3)
# The picture has the line that the window's tool draws round what ⌘⌥ picks
shot(name) = haskey(ENV, "LADDER_SHOTS") &&
  save_png(joinpath(ENV["LADDER_SHOTS"], name), w.size) do ctx, size
    draw(ctx, size, scene(w))
    draw_tool(ctx, w, window_tool(w), scene(w))
  end

"The run of line `i` whose text starts with `text`, and the middle of it in the window"
spot(i, text) = begin
  it = K.item(e, i)
  f = it.content
  for vl in f.lines, seg in vl.segs
    startswith(seg.text, text) || continue
    return (e.origin[1] + seg.x + seg.w / 2, e.origin[2] + it.top + f.above + vl.top + vl.high / 2)
  end
  error("no run $text on line $i")
end
move(x, y) = (w.mouse = typeof(w.mouse)(x, y); nothing)
picked(i, text) = (move(spot(i, text)...); K.code_under(w))
const looks = which(K.face, Tuple{K.Face,K.Span})

@testset "⌘⌥ picks a run of a paragraph's text" begin
  for (text, kind, m) in (("link", "Link", looks), ("bold", "Bold", looks), ("slanted", "Italic", looks),
                          ("struck", "Struck", looks), ("wiki", "Wiki link", looks),
                          ("code", "Code", which(K.describe, Tuple{K.Seg})))
    found = picked(3, text)
    @test found !== nothing && found[1] isa K.TextRun && found[1].kind == kind && found[2] == m
    @test found !== nothing && K.pick_name(found[1]) == kind
  end
  # The number of a footnote, and the box of a to-do item
  found = picked(3, "1")
  @test found[1] isa K.TextRun && found[1].kind == "Footnote"
  found = picked(5, K.TODO_OPEN)
  @test found[1] isa K.TextRun && found[1].kind == "To-do box" && found[2] == which(K.todo_box, Tuple{K.Seg})
  # Plain words pick the whole paragraph, as before
  found = picked(3, "Words")
  @test found[1] isa K.Paragraph
  # A node in the line picks itself
  found = picked(3, "Checkbox")
  @test !(found[1] isa K.TextRun) && nameof(typeof(found[1])) == :Checkbox
  # Over the room beside the page's text there's no run
  @test K.run_on(e, (e.origin[1] - 20px, spot(3, "link")[2])) === nothing
end

@testset "the line goes round the run alone" begin
  x, y = spot(3, "link")
  r = rect(picked(3, "link")[1])
  @test r.left < x < r.left + r.width && r.top < y < r.top + r.height
  # It's as wide as the word, with a little room on each side
  it = K.item(e, 3)
  seg = only(s for vl in it.content.lines for s in vl.segs if s.text == "link")
  @test r.width == seg.w + 2K.RUN_ROOM
  # A link with bold words in it is one run
  write(page, replace(read(page, String), "[link](https://example.com)" => "[a **big** link](https://example.com)"))
  K.refresh!(e.buf); frames(3)
  found = picked(3, "big")
  @test found[1].kind == "Link"
  r = rect(found[1])
  @test r.left < spot(3, "a ")[1] && r.left + r.width > spot(3, " link")[1]
  w.keys |= Keys.cmd; w.keys |= Keys.opt
  frames()
  shot("text-run-line.png")
  w.keys ⊻= Keys.cmd; w.keys ⊻= Keys.opt
end

@testset "Ask For Change and Show Code can take a run" begin
  move(spot(3, "bold")...)
  c = K.chip_click(K.ToChange, e, w)
  @test c isa K.ToChange && c.words == "Bold" && c.node isa K.TextRun
  @test c.file == K.code_place(looks)[1] && c.first <= K.code_place(looks)[2] <= c.last
  @test occursin("a part of its window, a Bold.", K.thing_words(c)[1])
  # ⌥↑ goes from the run to the paragraph that holds it
  wider = K.chip_wider(c, e)
  @test wider isa K.ToChange && wider.node isa K.Paragraph
end

"Click with ⌘ and ⌥ down at the point `(x, y)` of the window, then draw some frames"
cmd_opt_click(x, y) = begin
  move(x, y)
  w.keys |= Keys.cmd; w.keys |= Keys.opt; frames(1)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.cmd; w.keys ⊻= Keys.opt
  frames(3)
end

@testset "a paragraph or a heading that a click with ⌘ and ⌥ down chose keeps its line" begin
  # Each frame makes its blocks again, so the block that the click chose isn't the one that the next frame shows
  t = K.code_picker(e)
  for (i, text, T) in ((3, "Words", K.Paragraph), (1, "Runs", K.Heading), (7, "The end", K.Paragraph))
    cmd_opt_click(spot(i, text)...)
    @test t.chosen !== nothing && t.chosen[1] isa T && t.chosen[1].first == i
    @test [a for (a, _) in t.buttons] == [:label, :show_code, :ask_for_change, :ask_about]
    # What it holds is the block that this frame drew, so the buttons act on the page as it is
    @test t.chosen !== nothing && rect(t.chosen[1]) !== nothing
    onkey(w, KeyPress{Keys.escape}(0, w)); frames(1)
    @test t.chosen === nothing
  end
  # A block is the same thing as the block from the same line that another frame made, and no other
  move(spot(3, "Words")...)
  a = K.code_under(w)[1]
  frames(1)
  b = K.code_under(w)[1]
  @test a !== b && K.same_thing(a, b)
  move(spot(7, "The end")...)
  @test !K.same_thing(a, K.code_under(w)[1])
end

@testset "a click with ⌘ and ⌥ down, then Show Code on its line, shows the run's code" begin
  cmd_opt_click(spot(3, "struck")...)
  # The run keeps its line, with its buttons. A run is made again each time, and it's still the same run.
  t = K.code_picker(e)
  @test t.chosen[1] isa K.TextRun && t.chosen[1].kind == "Struck" && [a for (a, _) in t.buttons] == [:label, :show_code, :ask_for_change, :ask_about]
  @test K.same_thing(K.code_under(w)[1], t.chosen[1]) && !K.same_thing(picked(3, "bold")[1], t.chosen[1])
  shot("text-run-buttons.png")
  left, top, wide, tall = last(only(b for b in t.buttons if b[1] == :show_code))
  move(px(left + wide / 2), px(top + tall / 2))
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames()
  @test t.chosen === nothing
  file, line = K.code_place(looks)
  shown = filter(o -> o !== e && o.buf.path == file, K.editors)
  @test length(shown) == 1 && shown[1].buf.caret[1] == line
  # The click didn't move the caret of the page
  @test e.buf.caret == (7, 0)
  foreach(o -> (x = K.window_of(o); x === nothing || close(x)), shown)
end
