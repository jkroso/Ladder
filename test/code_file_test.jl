# Tests for a Julia file that the page changes. See "A Julia file is one block
# of code" in main.jl. Run them with `julia -O0 --project=. test/code_file_test.jl`.
# They type and press keys in a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const file = joinpath(dir, "walls.jl")
const TEXT = """
# The walls of a room
wall_length = 4.2
wall_height = 2.4

area(l, h) = begin
  l * h
end

area(wall_length, wall_height)
"""
write(file, TEXT)
const notes = joinpath(dir, "notes.md")
write(notes, "# Notes\n\n```jl\nwall_length = 4.2\n```\n")
write(joinpath(dir, "walls.py"), "wall_length = 4.2\n")
write(joinpath(dir, "bytes.jl"), UInt8[0x6a, 0x00, 0x01, 0x02, 0xff, 0x0a])

const e = K.build_editor(file)
const w = Window(e, size=(1000px, 800px))
const (; frames, typed, key, shot) = drive(w)
frames()
K.focus(e)

caret!(line, col=0) = (e.buf.caret = e.buf.anchor = (line, col); frames())
outcome(line) = (k = findfirst(o -> o.last == line, K.outcomes(e)); k === nothing ? nothing : K.outcomes(e)[k])

@testset "a Julia file opens as code that the page changes" begin
  b = e.buf
  @test b.view == :code && !K.readonly(b)
  @test b.lines == split(TEXT, '\n')
  @test length(e.layout) == length(b.lines)   # one line of the page for each line of the file
  @test all(k -> k.kind == K.Kind.code && k.lang == "jl", K.kinds(b))
  # The whole page is code, so its lines start at the edge of the page
  @test K.item(e, 2).content.lines[1].x == 0px
  @test K.julia_code(b, 5) == (1, length(b.lines))
end

@testset "a file of code has room for the numbers of its lines, and a page has none" begin
  @test K.numbered(e.buf)
  @test K.gutter(e) > K.NUMBER_GAP
  # The text starts at the left of the page, after the numbers' room
  @test K.num(e.origin[1]) ≈ K.num(K.PAGE_X) + K.num(K.gutter(e)) atol=1
  @test K.num(K.text_left(e)) ≈ K.num(e.origin[1]) atol=1
  shot("numbers")
  K.open!(e, joinpath(dir, "walls.py")); frames()
  @test K.numbered(e.buf)   # a file that's only shown has them too
  K.open!(e, notes); frames()
  @test !K.numbered(e.buf) && K.gutter(e) == 0px
  @test K.num(e.origin[1]) ≈ (1000 - K.num(e.width)) / 2 atol=1   # a page's text is in the middle
  @test K.num(K.text_left(e)) ≈ K.num(e.origin[1]) atol=1
  K.open!(e, file); frames()
  K.focus(e)
end

@testset "typing changes the text, and ⌘S writes the file" begin
  b = e.buf
  caret!(3, length(b.lines[3]))
  typed("5")
  @test b.lines[3] == "wall_height = 2.45"
  @test K.dirty(b)
  @test read(file, String) == TEXT   # nothing is written yet
  key(Keys.s, Keys.cmd)
  @test !K.dirty(b)
  @test read(file, String) == replace(TEXT, "2.4\n" => "2.45\n")
  # Return in a function's body starts the new line under the text of the line before
  caret!(6, length(b.lines[6]))
  key(Keys.enter)
  @test b.lines[7] == "  " && b.caret == (7, 2)
  key(Keys.z, Keys.cmd)
  @test b.lines == split(replace(TEXT, "2.4\n" => "2.45\n"), '\n')
  # ↑ and ↓ move the caret through the lines
  caret!(2, 4)
  key(Keys.down)
  @test e.buf.caret == (3, 4)
  key(Keys.up)
  @test e.buf.caret == (2, 4)
end

@testset "⌘Return runs the expression that the caret is in" begin
  b = e.buf
  caret!(6, 1)   # in the body of the function
  key(Keys.enter, Keys.cmd)
  o = outcome(7)
  @test o !== nothing && !o.failed && o.first == 5
  caret!(2)
  key(Keys.enter, Keys.shft)
  key(Keys.enter, Keys.shft)
  @test outcome(2).brief == "4.2" && outcome(3).brief == "2.45"
  caret!(9)
  key(Keys.enter, Keys.cmd)
  @test outcome(9).brief == string(4.2 * 2.45)
  # The box is after the end of its line of code
  vl = K.item(e, 9).content.lines[1]
  @test K.num(rect(outcome(9)).left) ≈ K.num(e.origin[1]) + K.num(K.xcol(vl, vl.to)) + K.num(K.OUTCOME_GAP) atol=1
  shot("file")
  key(Keys.escape)
  @test isempty(K.outcomes(e))
end

@testset "the file offers names as its code is typed" begin
  b = e.buf
  caret!(10)
  typed("wall_l")
  @test K.suggestion(e) !== nothing && K.suggestion(e)[3] == ["wall_length"]
  key(Keys.tab)
  @test b.lines[10] == "wall_length"
  key(Keys.z, Keys.cmd)
  key(Keys.z, Keys.cmd)
end

@testset "a bracket or a quote that's typed in code comes with the one that closes it" begin
  b = e.buf
  kept = copy(b.lines)
  # Line 10 is empty. Each check starts with `text` there, and the caret at `col` of it.
  line!(text="", col=length(text)) = begin
    K.edit!(b, (10, 0), (length(b.lines), length(b.lines[end])), text)
    caret!(10, col)
  end
  line!()
  typed("f(")
  @test b.lines[10] == "f()" && b.caret == (10, 2)
  typed("x")
  typed(")")   # the bracket that's there isn't typed again
  @test b.lines[10] == "f(x)" && b.caret == (10, 4)
  line!()
  typed("a[{")
  @test b.lines[10] == "a[{}]" && b.caret == (10, 3)
  line!()
  typed("s = \"")
  @test b.lines[10] == "s = \"\"" && b.caret == (10, 5)
  typed("hi\"")
  @test b.lines[10] == "s = \"hi\"" && b.caret == (10, 8)
  # A whole line that's typed one key after another is the line
  line!()
  typed("Text(c.count == 1 ? \"Clicked 1 time\" : \"Clicked \$(c.count) times\", size=[15px, 'a'])")
  @test b.lines[10] == "Text(c.count == 1 ? \"Clicked 1 time\" : \"Clicked \$(c.count) times\", size=[15px, 'a'])"
  # A string that has a name before it
  line!()
  typed("colorant\"")
  @test b.lines[10] == "colorant\"\""
  # Before a word, the bracket comes alone
  line!("name", 0)
  typed("(")
  @test b.lines[10] == "(name"
  line!("f(name)", 2)
  typed("\"")
  @test b.lines[10] == "f(\"name)"
  # A quote in a string ends the string
  line!("s = \"hi")
  typed("\"")
  @test b.lines[10] == "s = \"hi\""
  # ... and a bracket in a string still comes with its other one
  line!("s = \"n = \"", 9)
  typed("\$(")
  @test b.lines[10] == "s = \"n = \$()\"" && b.caret == (10, 11)
  # A ' after a name is a transpose. After a space it starts a character.
  line!()
  typed("x'")
  @test b.lines[10] == "x'"
  typed(" * f(x)'")
  @test b.lines[10] == "x' * f(x)'"
  line!()
  typed("c = '")
  @test b.lines[10] == "c = ''" && b.caret == (10, 5)
  # Three quotes start a string of several lines, and bring the three that end it
  line!()
  typed("\"\"\"")
  @test b.lines[10] == "\"\"\"\"\"\"" && b.caret == (10, 3)
  typed("doc\"\"\"")
  @test b.lines[10] == "\"\"\"doc\"\"\"" && b.caret == (10, 9)
  # ... but three quotes that end such a string come alone
  line!("\"\"\"\ndoc\n")
  caret!(12)
  typed("\"\"\"")
  @test b.lines[12] == "\"\"\""
  # A bracket goes round the text that's selected, and the text stays selected
  line!("a + b")
  b.anchor = (10, 0); frames()
  typed("(")
  @test b.lines[10] == "(a + b)" && (b.caret, b.anchor) == ((10, 6), (10, 1))
  typed("\"")
  @test b.lines[10] == "(\"a + b\")" && (b.caret, b.anchor) == ((10, 7), (10, 2))
  # ⌫ between the two of an empty pair takes both away
  line!()
  typed("f(")
  key(Keys.backspace)
  @test b.lines[10] == "f" && b.caret == (10, 1)
  typed("(x")
  key(Keys.backspace)
  @test b.lines[10] == "f()"
  # With two carets, each bracket gets its own closing bracket
  line!("a\nb", 1)
  b.caret = b.anchor = (10, 1)
  push!(b.others, ((11, 1), (11, 1))); K.keep_others!(b); frames()
  typed("(1)")
  @test b.lines[10:11] == ["a(1)", "b(1)"]
  line!()
  @test b.lines == kept
  # A code block of a page does the same, and the page's words don't
  K.open!(e, notes); frames()
  K.focus(e)
  b = e.buf
  caret!(4, length(b.lines[4]))
  typed(" + f(")
  @test b.lines[4] == "wall_length = 4.2 + f()"
  caret!(1, length(b.lines[1]))
  typed(" (")
  @test b.lines[1] == "# Notes ("
  foreach(_ -> key(Keys.z, Keys.cmd), 1:4)
  K.open!(e, file); frames()
  K.focus(e)
end

@testset "the two brackets that the caret is between glow" begin
  b = e.buf
  kept = copy(b.lines)
  line!(text) = (K.edit!(b, (10, 0), (length(b.lines), length(b.lines[end])), text); frames())
  pair(i, col) = (caret!(i, col); K.caret_pair(e))
  line!("f(a, [b, c], \"x)\") # (d")
  @test pair(10, 2) == ((10, 1), (10, 17))
  @test pair(10, 6) == ((10, 5), (10, 10))
  @test pair(10, 10) == ((10, 5), (10, 10))   # just before the ] the caret is still between the two
  @test pair(10, 11) == ((10, 1), (10, 17))   # ... and after it, the caret is between the outer two
  @test pair(10, 12) == ((10, 1), (10, 17))   # the ) in the string doesn't close the (
  @test pair(10, 1) === nothing && pair(10, 18) === nothing   # outside every bracket
  @test pair(10, 15) === nothing   # in the string, whose ) has no ( in a string
  @test pair(10, 23) === nothing   # in the comment, whose ( has no )
  @test pair(9, 5) == ((9, 4), (9, 29))
  # The brackets of a string are a pair for a caret that's in the string
  line!("colorant\"rgb(1,2)\"")
  @test pair(10, 13) == ((10, 12), (10, 16))
  # ... and code in a string has the code's brackets
  line!("\"n = \$(f(x))\"")
  @test pair(10, 7) == ((10, 6), (10, 11))
  @test pair(10, 9) == ((10, 8), (10, 10))
  # The two can be on different lines
  line!("f(a,\n  g[1],\n  b)")
  @test pair(11, 2) == ((10, 1), (12, 3))
  @test pair(11, 4) == ((11, 3), (11, 5))
  @test pair(12, 3) == ((10, 1), (12, 3))
  shot("brackets")
  # A bracket that another kind of bracket closes doesn't glow, and nothing glows while text is selected
  line!("f(a]")
  @test pair(10, 2) === nothing
  line!("f(a)")
  @test pair(10, 2) == ((10, 1), (10, 3))
  b.anchor = (10, 3); frames()
  @test K.caret_pair(e) === nothing
  # The bracket that typing brings is found as soon as it's there
  line!("")
  caret!(10)
  typed("g(")
  @test K.caret_pair(e) == ((10, 1), (10, 2))
  # Two brackets that touch glow as one run of text, and two that don't are a run each
  @test K.bracket_runs(((10, 1), (10, 2))) == [(10, 1, 3)]
  @test K.bracket_runs(((10, 1), (10, 3))) == [(10, 1, 2), (10, 3, 4)]
  @test K.bracket_runs(((10, 1), (11, 2))) == [(10, 1, 2), (11, 2, 3)]
  shot("brackets-typed")
  line!("")
  @test b.lines == kept
  # In a page, the brackets are those of the code block that the caret is in
  K.open!(e, notes); frames()
  K.focus(e)
  b = e.buf
  caret!(4, length(b.lines[4]))
  typed(" + f(")
  @test K.caret_pair(e) == ((4, 21), (4, 22))
  caret!(1, length(b.lines[1]))
  typed(" (x)")
  @test pair(1, 10) === nothing   # the brackets in the page's words don't glow
  foreach(_ -> key(Keys.z, Keys.cmd), 1:4)
  K.open!(e, file); frames()
  K.focus(e)
end

@testset "a file that isn't Julia, and one that isn't text, are only shown" begin
  K.open!(e, joinpath(dir, "walls.py")); frames()
  @test e.buf.view == :text && K.readonly(e.buf)
  typed("x")
  @test e.buf.lines[1] == "wall_length = 4.2"
  K.open!(e, joinpath(dir, "bytes.jl")); frames()
  @test K.readonly(e.buf)
end

@testset "a page's code block still has its own look" begin
  K.open!(e, notes); frames()
  @test e.buf.view == :markdown
  # The same line of code as the file has, in a block with a background and room on its left
  @test K.item(e, 4).content.lines[1].x == K.BLOCK_X
  K.open!(e, file); frames()
  @test e.buf.view == :code
  @test K.item(e, 2).content.lines[1].x == 0px
  @test e.buf.lines[3] == "wall_height = 2.45"   # the file is as it was left
end

@testset "a code file scrolls on until its last line is near the top of the window, and a page doesn't" begin
  K.open!(e, file); frames()
  K.scroll_page!(e, px(Inf)); frames()
  last = K.item(e, length(e.buf.lines))
  @test K.PAGE_TOP + last.top - e.scroll.offset < K.CODE_END
  K.open!(e, notes); frames()
  K.scroll_page!(e, px(Inf)); frames()
  @test e.scroll.offset == 0px   # a short page fits in the window
end

@testset "a file that the Mac marks as read-only is shown as it is, and isn't changed" begin
  locked = joinpath(dir, "locked.md")
  write(locked, "# Locked\n\nSome words.\n\nSee [the notes](notes.md) for more.\n")
  chmod(locked, 0o444)
  K.open!(e, locked); frames()
  b = e.buf
  @test b.view == :markdown && b.fixed && !K.readonly(b)   # it's a page like any other, with its heading as a heading
  # The top bar has a lock, which says "Read only" while the mouse is over it
  lock_in(node) = (hasproperty(node, :from) && node.from isa K.ReadOnly) || (node isa K.GeometricUI && any(lock_in, node.children))
  @test lock_in(K.describe(e.nodes[:topbar])) && K.tip(e.nodes[:read_only]) == "Read only"
  b.caret = b.anchor = (3, 0); frames()
  typed("x")
  key(Keys.s, Keys.cmd)
  @test b.lines[3] == "Some words." && !K.dirty(b) && read(locked, String) == "# Locked\n\nSome words.\n\nSee [the notes](notes.md) for more.\n"
  # A click on a link opens it with no key held, since the page has no caret for a click to place. A click
  # beside the link's line, or on the line's other words, opens nothing.
  it = K.item(e, 5)
  line = it.content.lines[1]
  seg = line.segs[findfirst(s -> !isempty(s.link), line.segs)]
  y = e.origin[2] + it.top + it.content.above + line.top + line.high / 2
  @test K.link_on(e, (e.origin[1] + seg.x + seg.w / 2, y)) == "notes.md"
  @test K.link_on(e, (e.origin[1] - 20px, y)) === nothing && K.link_on(e, (e.origin[1] + seg.x - 6px, y)) === nothing
  K.press!(e, (e.origin[1] + seg.x - 6px, y)); frames()
  @test e.buf.path == locked
  # With ⌥ or ⌃ held, or ⌘ with ⇧, a click on the link opens nothing
  for others in (Keys.opt, Keys.ctrl, Keys.cmd | Keys.shft)
    w.keys |= others
    K.press!(e, (e.origin[1] + seg.x + seg.w / 2, y))
    w.keys = Keys(0)
    frames()
    @test e.buf.path == locked
  end
  K.press!(e, (e.origin[1] + seg.x + seg.w / 2, y)); frames()
  @test e.buf.path == notes
  K.open!(e, locked); frames()
  b = e.buf
  # With the mark taken off, the page is written like any other
  chmod(locked, 0o644)
  frames()
  @test !e.buf.fixed
  caret!(3, 0)
  typed("x")
  key(Keys.s, Keys.cmd)
  @test read(locked, String) == "# Locked\n\nxSome words.\n\nSee [the notes](notes.md) for more.\n"
  # In a page that's written, a click on a link places the caret, and the link opens with ⌘ held
  K.press!(e, (e.origin[1] + seg.x + seg.w / 2, y)); frames()
  @test e.buf.path == locked && e.buf.caret[1] == 5
  # A mark that's put on the file while it's open stops the typing too
  chmod(locked, 0o444)
  frames()
  typed("y")
  @test e.buf.fixed && e.buf.lines[3] == "xSome words."
  chmod(locked, 0o644)
end
