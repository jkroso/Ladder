# Tests for two marks that come from Obsidian: ==words== with a highlighter's
# colour behind them, and a comment, like %%note%%, that rich text hides. A
# comment can be on lines of its own, between a line that starts with %% and
# a line that ends with %%. Run them with
# `julia -O0 --project=. test/marks_test.jl`. They use a window that isn't on
# the screen. Set `LADDER_SHOTS` to a folder, and they save pictures of the
# page there.

@use Test: @test, @testset
@use "../markdown" Kind classify spans COMMENT
@use "../html" html
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

"The text of each span of `text` that is highlit, and of each that is a comment"
lit(text) = [s.text for s in spans(text) if s.highlit && !s.markup]
said(text) = [s.text for s in spans(text) if s.comment]
marks(text) = [s.text for s in spans(text) if s.markup]

@testset "highlighted words" begin
  @test lit("Some ==bright== words.") == ["bright"]
  @test marks("Some ==bright== words.") == ["==", "=="]
  # Bold words and a link can be highlit, and a highlight can be inside bold words
  ss = spans("==**bold** and [a link](https://example.com)==")
  @test only(s for s in ss if s.text == "bold").highlit && only(s for s in ss if s.text == "bold").bold
  @test only(s for s in ss if s.text == "a link").highlit && only(s for s in ss if s.text == "a link").link == "https://example.com"
  @test lit("**bold ==and lit==**") == ["and lit"] && only(s for s in spans("**bold ==and lit==**") if s.text == "and lit").bold
  # A comparison isn't a highlight: the words can't start or end with a space
  @test isempty(lit("if a == b and c == d")) && isempty(marks("if a == b"))
  @test isempty(lit("x ==y")) && isempty(lit("==y =="))
  # A row of = under a line is only text
  @test all(t -> isempty(lit(t)) && isempty(marks(t)), ("===", "=====", "======", "a ===b=== c"))
  # In code it's only code
  @test isempty(lit("`==code==`")) && only(s for s in spans("`==code==`") if !s.markup).code
  @test isempty(lit("!`==(1, 1)`"))
end

@testset "a comment in a line" begin
  @test said("Before %%a note%% after.") == ["a note"]
  @test marks("Before %%a note%% after.") == ["%%", "%%"]
  # Its words are one span: no markup is read inside them
  @test said("%%**not bold** [nor](a link)%%") == ["**not bold** [nor](a link)"]
  @test count(s -> s.markup, spans("%%**not bold**%%")) == 2
  # A comment in bold words, and an empty one
  @test said("**bold %%note%% words**") == ["note"]
  @test isempty(said("%%%%")) && marks("%%%%") == ["%%", "%%"]
  # A %% with no other is only text, and so is one in code
  @test isempty(said("50%% off")) && isempty(marks("50%% off"))
  @test isempty(said("`%%code%%`"))
end

@testset "a comment on lines of its own" begin
  ks = classify(["Text", "%%", "Hidden.", "# Not a heading", "- [ ] Not an item", "```", "%%", "After."])
  @test [k.kind for k in ks] == [Kind.paragraph, Kind.fence, Kind.code, Kind.code, Kind.code, Kind.code, Kind.fence, Kind.paragraph]
  @test all(k -> k.lang == COMMENT, ks[2:7]) && ks[2].level == 0 && ks[7].level == 1
  # As Obsidian writes one too: the first line starts with %%, and the last ends with it
  ks = classify(["%%This is a", "comment of two lines%%", "After."])
  @test [k.kind for k in ks] == [Kind.fence, Kind.fence, Kind.paragraph] && ks[1].lang == ks[2].lang == COMMENT
  # A line that has a whole comment is a line of text
  @test classify(["%% a note %%", "Text"])[1].kind == Kind.paragraph
  # A %% that no line under it closes is a line of text
  @test [k.kind for k in classify(["%%", "Text"])] == [Kind.paragraph, Kind.paragraph]
  # In a code block, and in a formula, a line of %% is a line of code
  ks = classify(["```mermaid", "%%", "graph TD", "%%", "```"])
  @test all(k -> k.kind == Kind.code && k.lang == "mermaid", ks[2:4])
  @test classify(["\$\$", "%%", "x", "%%", "\$\$"])[2].lang == "math"
end

@testset "a page of HTML" begin
  page = html(["Some ==bright== words.", "Before %%a note%% after.", "%%only a note%%", "%%", "Hidden.", "%%", "Last."])
  @test occursin("<p>Some <mark>bright</mark> words.</p>", page)
  @test occursin("<p>Before  after.</p>", page)
  @test !occursin("a note", page) && !occursin("only a note", page) && !occursin("Hidden", page) && !occursin("%%", page)
  # A line that holds only a comment makes no paragraph
  @test !occursin("<p></p>", page)
  @test occursin("<p>Last.</p>", page)
end

const dir = mktempdir()
const page = joinpath(dir, "marks.md")
write(page, """
# Marks

Some ==bright== words, and ==**bold bright**== ones.

Before %%a note%% after.

%%
Hidden line one.
Hidden line two.
%%

Zorblatixen here %%Zorblatixen there%%.

%% A line that holds only a comment %%

Last line, with `==code==` and `%%code%%`.
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
line(text) = findfirst(startswith(text), e.buf.lines)
segs(i) = [seg for vl in K.item(e, i).content.lines for seg in vl.segs]
key(k, held=Keys(0)) = (w.keys = held; onkey(w, KeyPress{k}(0, w)); w.keys = Keys(0); frames())
caret!(p) = (e.buf.caret = e.buf.anchor = p; K.touch!(e); frames())
const bright, before, opens, closes, after, lone, last_line =
  line("Some"), line("Before"), line("%%"), line("Hidden line two") + 1, line("Zorblatixen"), line("%% A line"), line("Last")

@testset "what the page shows" begin
  shot("marks.png")
  # The highlit words have a highlighter's colour behind them, and their == don't show
  ss = segs(bright)
  @test !any(s -> occursin("==", s.text), ss)
  lit_segs = [s for s in ss if s.face.highlit]
  @test join(s.text for s in lit_segs) == "brightbold bright"
  @test all(s -> K.describe(s).background.color == K.highlighter(), lit_segs)
  @test !any(s -> s.face.highlit, [s for s in ss if !(s in lit_segs)])
  # A comment in a line doesn't show, nor do its %%
  @test join(s.text for s in segs(before)) == "Before  after."
  # A comment on lines of its own takes no room, and nor does the empty line after it: the next
  # line is where the comment would start, one empty line under the line before it
  it = K.item(e, opens)
  @test it.first == opens && it.last == closes + 1 && it.tall == 0px
  @test K.item(e, after).top == it.top && K.item(e, opens - 1).tall > 0px
  # A line that holds only a comment takes no room, and nor does the empty line after it
  it = K.item(e, lone)
  @test it.first == lone && it.last == lone + 1 && it.tall == 0px && K.item(e, last_line).top == it.top
  @test K.comment_only(e.buf.lines[lone]) && !K.comment_only(e.buf.lines[before]) && !K.comment_only("%% text") && !K.comment_only("`%%a%%`")
  # In code the marks are only code
  @test any(s -> s.text == "==code==" && s.face.chip && !s.face.highlit, segs(last_line))
  @test any(s -> s.text == "%%code%%" && s.face.chip, segs(last_line))
end

@testset "the caret in rich text" begin
  # The caret can't stop in a comment in a line
  at = length("Before %%a ")
  caret!((before, at))
  @test e.buf.caret[2] in (length("Before "), length("Before %%a note%%"))
  # ↑ and ↓ step over a comment on lines of its own, and the empty line after it
  caret!((after, 0)); key(Keys.up)
  @test e.buf.caret[1] == opens - 1
  key(Keys.down)
  @test e.buf.caret[1] == after
  # ... and over a line that holds only a comment, after the empty line before it
  key(Keys.down); key(Keys.down)
  @test e.buf.caret[1] == last_line
  key(Keys.up)
  @test e.buf.caret[1] == lone - 1
  # Selecting the line deletes its comment with its words
  e.buf.anchor = (before, 0); e.buf.caret = (before, length(e.buf.lines[before])); K.touch!(e); frames()
  key(Keys.backspace)
  @test e.buf.lines[before] == ""
  key(Keys.z, Keys.cmd)
  @test e.buf.lines[before] == "Before %%a note%% after."
end

@testset "the marks as they're written" begin
  K.plain!(e, true)
  # The line with the caret shows its ==, and its comment in dim words
  caret!((bright, 2))
  @test any(s -> s.text == "==", segs(bright))
  caret!((before, 2))
  note = only(s for s in segs(before) if s.text == "a note")
  @test note.face.color == K.colours.dim
  @test count(s -> s.text == "%%" && s.face.color == K.colours.faint, segs(before)) == 2
  # The caret goes into a comment on lines of its own, and then the comment shows
  caret!((opens - 1, 0)); key(Keys.down)
  @test e.buf.caret[1] == opens
  @test K.item(e, opens + 1).tall > 0px
  hidden = only(segs(opens + 1))
  @test hidden.text == "Hidden line one." && hidden.face.color == K.colours.dim && hidden.face.family == K.body(e).family
  @test only(segs(opens)).text == "%%" && only(segs(opens)).face.color == K.colours.faint
  # Its lines have no background of a code block
  @test K.describe(e, K.item(e, opens + 1)).background === nothing || K.describe(e, K.item(e, opens + 1)).background.color != K.colours.block
  shot("marks-plain.png")
  # A line that holds only a comment shows while the caret is on it
  caret!((lone, 0))
  @test K.item(e, lone).tall > 0px && any(s -> s.text == " A line that holds only a comment " && s.face.color == K.colours.dim, segs(lone))
  # On the empty line after it, the comment takes no room, and the empty line shows
  caret!((closes + 1, 0))
  @test K.item(e, opens).last == closes && K.item(e, opens).tall == 0px && K.item(e, closes + 1).tall > 0px
  # Out of it, neither takes room again
  caret!((last_line, 0))
  @test K.item(e, opens).last == closes + 1 && K.item(e, opens).tall == 0px
  K.plain!(e, false); frames()
end

@testset "word count and spelling" begin
  # Marks 1, Some bright words and bold bright ones 7, Before after 2, Zorblatixen here 2, and the
  # last line 6: the %% in its code is code, and counts
  @test startswith(K.word_count(e), "18 words")
  # The word that shows is spelt wrong, and the same word in the comment isn't checked
  @test e.spelling
  @test K.misspellings(e, after) == [(0, length("Zorblatixen"))]
end

@testset "the dark page" begin
  K.theme!(e, :night); frames()
  shot("marks-night.png")
  @test K.highlighter() != K.RGBA(1.0, 0.85, 0.2, 0.45)
  K.theme!(e, :sepia); frames()
end

close(w)
