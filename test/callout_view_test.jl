# Tests for the callouts of main.jl: a quote whose first line names a kind of
# note, like `> [!NOTE]`. Run them with
# `julia -O0 --project=. test/callout_view_test.jl`. They use a window that
# isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save pictures
# of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "callouts.md")
write(page, """
# Callouts

Some text before.

> [!NOTE]
> The slab is poured on **Tuesday**. Keep the site clear, and keep the trucks off the new kerb until the council has looked at it.

> [!TIP]
> Order the steel a week early.

> [!IMPORTANT]
> The client signs before work starts.

> [!WARNING] Wet paint
> Keep off the stairs.

> [!CAUTION]
> Live wires in the east wall.

> A plain quote.

Last line.
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 820px))
const (; frames, key, shot) = drive(w)
frames()
K.focus(e)
line(text) = findfirst(startswith(text), e.buf.lines)
segs(i) = [seg for vl in K.item(e, i).content.lines for seg in vl.segs]
"The mark that shows in place of what starts line `i`, or nothing"
mark(i) = (found = [s.node.node for s in segs(i) if s.node !== nothing && s.node.node isa K.CalloutMark]; isempty(found) ? nothing : only(found))
type(s) = (foreach(c -> ontype(e, Typed(c, w)), s); frames())
caret!(p) = (e.buf.caret = e.buf.anchor = p; K.touch!(e); frames())

@testset "what a callout shows" begin
  shot("callouts.png")
  note, warning = line("> [!NOTE]"), line("> [!WARNING]")
  # The line that names the kind shows the kind's icon and name, and none of its own characters
  m = mark(note)
  @test m.kind == "note" && m.name == "Note" && m.face.color == K.callout_colour("note")
  @test all(s -> s.node !== nothing, segs(note))
  # A title of its own shows in place of the name, in the kind's colour
  m = mark(warning)
  @test m.kind == "warning" && m.name == ""
  title = only(s for s in segs(warning) if s.node === nothing)
  @test title.text == "Wet paint" && title.face.color == K.callout_colour("warning")
  # Each kind has its own colour and icon
  @test length(unique(K.callout_colour.(K.CALLOUTS))) == 5 && length(unique(values(K.CALLOUT_ICONS))) == 5
  # The text of a callout is the page's own, and a plain quote is still dim
  text = only(segs(warning + 1))
  @test text.face.color == K.colours.ink && !occursin("Italic", text.face.style)
  @test only(segs(line("> A plain quote"))).face.color == K.colours.dim
  @test mark(line("> A plain quote")) === nothing
  # The lines of a callout have the kind's colour down their left and behind them
  col = K.describe(e, K.item(e, note + 1))
  @test col.border.left.color == K.callout_colour("note") && col.background.color == K.callout_tint("note")
  plain = K.describe(e, K.item(e, line("> A plain quote")))
  @test plain.border.left.color == K.colours.line
end

@testset "the caret in a callout" begin
  note = line("> [!NOTE]")
  # The caret can't stop in what starts the line
  caret!((note, 3))
  @test e.buf.caret == (note, length("> [!NOTE]"))
  # Return on the line that names the kind starts a line of the callout
  key(Keys.enter)
  @test e.buf.lines[note+1] == "> " && e.buf.caret == (note + 1, 2)
  type("New line")
  @test e.buf.lines[note+1] == "> New line" && K.callout(K.kinds(e.buf)[note+1]) == "note"
  key(Keys.z, Keys.cmd); key(Keys.z, Keys.cmd)
  @test e.buf.lines[note+1] != "> New line"
  # Typing after the kind gives the callout a title
  caret!((note, length("> [!NOTE]")))
  type(" Read me")
  @test e.buf.lines[note] == "> [!NOTE] Read me" && mark(note).name == ""
  # ⌫ at the start of the title's line makes it a paragraph, and the lines under it a plain quote
  warning = line("> [!WARNING]")
  caret!((warning, length("> [!WARNING] ")))
  key(Keys.backspace)
  @test e.buf.lines[warning] == "Wet paint" && K.callout(K.kinds(e.buf)[warning+1]) == ""
  key(Keys.z, Keys.cmd)
  @test e.buf.lines[warning] == "> [!WARNING] Wet paint"
end

@testset "a callout as it's written" begin
  # As plain text, the line with the caret shows its own characters
  note = line("> [!NOTE]")
  K.plain!(e, true); caret!((note, 4))
  @test mark(note) === nothing && any(s -> occursin("[!NOTE]", s.text), segs(note))
  shot("callouts-plain.png")
  K.plain!(e, false); frames()
end

@testset "the dark page" begin
  K.theme!(e, :night); frames()
  shot("callouts-night.png")
  # The colours are the dark page's own
  @test mark(line("> [!TIP]")).face.color == K.callout_colour("tip") == K.NIGHT.string
  K.theme!(e, :sepia); frames()
end

close(w)
