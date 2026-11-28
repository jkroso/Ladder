# Tests for the two ways a page is written: as rich text, where a line keeps its
# look when the caret comes onto it, and as plain text, where the part of the
# page with the caret shows its markup. See "rich text and plain text" in rich.jl. Run them with
# `julia -O0 --project=. test/rich_test.jl`. They use windows that aren't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "./drive" drive
const px = K.px

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
const kept = joinpath(dir, "settings")
K.SETTINGS_FILE[] = kept

"A window that isn't on the screen, on a file with `text` in it"
window(text; name="page.md") = begin
  path = joinpath(dir, name)
  write(path, text)
  e = K.build_editor(path)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  K.focus(e)
  e, w
end

const (; click, key) = drive()
type(e, w, text) = (foreach(c -> ontype(e, Typed(c, w)), text); frame(w))
caret!(e, w, line, col=0) = (e.buf.caret = e.buf.anchor = (line, col); K.touch!(e); frame(w))
select!(e, w, lo, hi) = (e.buf.anchor = lo; e.buf.caret = hi; K.touch!(e); frame(w))
"True when all of line `i` shows its markup"
raw(e, i) = (c = K.item(e, i).content; c isa K.Flow && c.raw)
"The text that line `i` is drawn as"
drawn(e, i) = join(seg.text for vl in K.item(e, i).content.lines for seg in vl.segs)
const cmd, opt, shift = Keys.cmd, Keys.opt, Keys.shft

@testset "rich text and plain text" begin

PAGE = """
# Title

Some **bold** words and a [link](http://x.y) here.

- first item
- second **item**

---

```julia
x = 1
```

```mermaid
graph TD
  A --> B
```

| a | b |
|---|---|
| **c** | d |

last line
"""

@testset "a page opens as rich text, and the caret's line keeps its look" begin
  e, w = window(PAGE)
  @test !e.plain
  # The caret starts at the heading's text, after the # that doesn't show
  @test e.buf.caret == (1, 2)
  caret!(e, w, 3, 9)
  @test !raw(e, 3)
  caret!(e, w, 1, 4)
  @test !raw(e, 1)
  # A selection puts each of its ends where the caret can stop too
  caret!(e, w, 6, 4)
  @test !raw(e, 6)
end

@testset "the caret goes over characters that don't show" begin
  e, w = window(PAGE)
  # Some **bold** words: the ** are at columns 5 and 11
  caret!(e, w, 3, 4)
  key(w, Keys.right)
  @test e.buf.caret == (3, 5)   # before the bold text, and not in it
  key(w, Keys.right)
  @test e.buf.caret == (3, 8)   # past the ** and the b
  caret!(e, w, 3, 10)
  key(w, Keys.right)
  @test e.buf.caret == (3, 11)  # at the end of the bold text, and in it
  key(w, Keys.right)
  @test e.buf.caret == (3, 14)  # past the ** and the space
  key(w, Keys.left)
  @test e.buf.caret == (3, 13)  # after the bold text, and not in it
  key(w, Keys.left)
  @test e.buf.caret == (3, 10)
  # A caret that's put among the ** goes to the nearest place where it can stop
  caret!(e, w, 3, 6)
  @test e.buf.caret in ((3, 5), (3, 7))
  # ← at the start of a heading's text goes to the line above, and → comes back to the text
  caret!(e, w, 3, 0)
  key(w, Keys.left); key(w, Keys.left)
  @test e.buf.caret == (1, 7)
  caret!(e, w, 1, 2)
  key(w, Keys.left)
  @test e.buf.caret[1] == 1 || e.buf.caret == (1, 2)   # the first line has nowhere to go back to
  # The start of the line is the start of an item's text
  caret!(e, w, 5, 8)
  key(w, Keys.left, cmd)
  @test e.buf.caret == (5, 2)
  # A word to the left of an item's first word is on the line above
  key(w, Keys.left, opt)
  @test e.buf.caret[1] == 4 || e.buf.caret[1] == 3
end

@testset "what's typed beside bold text is bold on the side that the caret came from" begin
  e, w = window(PAGE)
  caret!(e, w, 3, 10)
  key(w, Keys.right)
  type(e, w, "er")
  @test startswith(e.buf.lines[3], "Some **bolder** words")
  caret!(e, w, 3, 16)
  key(w, Keys.left)
  @test e.buf.caret == (3, 15)
  type(e, w, "!")
  @test startswith(e.buf.lines[3], "Some **bolder**! words")
end

@testset "⌫ deletes what shows, and markup goes with the last of its text" begin
  e, w = window("Some **bold** words\n\na **b** c\n\n# Title\n\n- item\n  - inner\n\n> quote\n")
  # After the bold text, ⌫ takes the d and leaves the **
  caret!(e, w, 1, 13)
  key(w, Keys.backspace)
  @test e.buf.lines[1] == "Some **bol** words"
  @test e.buf.caret == (1, 10)   # in the bold text now, at its end
  # The last letter of bold text takes its ** with it
  caret!(e, w, 3, 7)
  key(w, Keys.backspace)
  @test e.buf.lines[3] == "a  c"
  @test e.buf.caret == (3, 2)
  # ⌦ does the same from the other side
  key(w, Keys.z, cmd)
  @test e.buf.lines[3] == "a **b** c"
  caret!(e, w, 3, 2)
  key(w, Keys.delete)
  @test e.buf.lines[3] == "a  c"
  # ⌫ at the start of a heading's text makes it a paragraph
  caret!(e, w, 5, 2)
  key(w, Keys.backspace)
  @test e.buf.lines[5] == "Title"
  @test e.buf.caret == (5, 0)
  # An item of a list inside a list goes out a step, then stops being an item
  caret!(e, w, 8, 4)
  key(w, Keys.backspace)
  @test e.buf.lines[8] == "- inner"
  key(w, Keys.backspace)
  @test e.buf.lines[8] == "inner"
  caret!(e, w, 10, 2)
  key(w, Keys.backspace)
  @test e.buf.lines[10] == "quote"
  # ⌥⌫ takes a whole bold word and its markup
  caret!(e, w, 1, 12)
  key(w, Keys.backspace, opt)
  @test e.buf.lines[1] == "Some  words"
end

@testset "text that's deleted or typed over leaves the markup of what's left" begin
  e, w = window("Some **bold** words\n\n# Title\n\n- one\n- two\n")
  # From the middle of the bold word to the middle of the next
  select!(e, w, (1, 9), (1, 16))
  type(e, w, "x")
  @test e.buf.lines[1] == "Some **box**rds"
  @test e.buf.caret == (1, 10)
  # ⌦ at the end of a line joins the next line's text to it, without what starts that line
  caret!(e, w, 5, 5)
  key(w, Keys.delete)
  @test e.buf.lines[5] == "- onetwo"
  @test e.buf.caret == (5, 5)
  # A selection from inside one line to inside another joins what's left, without what starts the second
  select!(e, w, (1, 2), (3, 4))
  key(w, Keys.backspace)
  @test e.buf.lines[1] == "Sotle"
  # A selection of all of a heading's text and the line after it leaves the next line as it was
  e, w = window("# Title\n- one\n- two\n")
  select!(e, w, (1, 2), (2, 2))
  key(w, Keys.backspace)
  @test e.buf.lines[1:2] == ["- one", "- two"]
  @test e.buf.caret == (1, 2)
  # Text that's typed over a selection like that is in the first line, with what starts it
  select!(e, w, (1, 2), (2, 4))
  type(e, w, "x")
  @test e.buf.lines[1] == "- xo"
  # Everything selected leaves an empty page
  key(w, Keys.a, cmd)
  key(w, Keys.backspace)
  @test e.buf.lines == [""]
end

@testset "Return keeps the look of each half of the text" begin
  e, w = window("Some **bold** words\n\n# Title\n\n- an *item* here\n")
  caret!(e, w, 1, 9)
  key(w, Keys.enter)
  @test e.buf.lines[1:2] == ["Some **bo**", "**ld** words"]
  @test e.buf.caret == (2, 2)
  # At the end of bold text, the new line has no bold text with nothing in it
  caret!(e, w, 1, 9)
  key(w, Keys.enter)
  @test e.buf.lines[1:2] == ["Some **bo**", ""]
  # At the start of a heading's text, the heading moves down
  i = findfirst(==("# Title"), e.buf.lines)
  caret!(e, w, i, 2)
  key(w, Keys.enter)
  @test e.buf.lines[i:i+1] == ["", "# Title"]
  @test e.buf.caret == (i + 1, 2)
  # A list item carries on, and so does its italic text
  j = findfirst(==("- an *item* here"), e.buf.lines)
  caret!(e, w, j, 8)
  key(w, Keys.enter)
  @test e.buf.lines[j:j+1] == ["- an *it*", "- *em* here"]
end

@testset "Return on an empty list item ends the list" begin
  for lead in ("- ", "1. ", "- [ ] ", "- [x] ", "> ", "  - ")
    e, w = window("$(lead)one\n$(lead)\n\nA line after\n")
    caret!(e, w, 2, length(lead))
    key(w, Keys.enter)
    @test e.buf.lines[1:3] == ["$(lead)one", "", ""]
    @test e.buf.caret == e.buf.anchor == (2, 0)
    # One ⌘Z puts the item back
    key(w, Keys.z, cmd)
    @test e.buf.lines[2] == lead
    # It does the same as plain text
    K.plain!(e, true)
    caret!(e, w, 2, length(lead))
    key(w, Keys.enter)
    @test e.buf.lines[1:3] == ["$(lead)one", "", ""]
  end
end

@testset "⌘B takes the bold from text that's all selected" begin
  e, w = window("Some **bold** words\n")
  # Each end of the selection is outside the ** that don't show
  select!(e, w, (1, 5), (1, 13))
  key(w, Keys.b, cmd)
  @test e.buf.lines[1] == "Some bold words"
  key(w, Keys.b, cmd)
  @test e.buf.lines[1] == "Some **bold** words"
end

@testset "the caret goes onto a part of the page that shows as one thing, and not into it" begin
  e, w = window(PAGE)
  # The line across the page
  caret!(e, w, 9, 0)
  key(w, Keys.up)
  @test e.buf.caret == (8, 0) && K.picked(e.buf) == (8, 8)
  @test !raw(e, 8)
  key(w, Keys.up)
  @test e.buf.caret[1] == 7 && K.picked(e.buf) === nothing
  key(w, Keys.down); key(w, Keys.down)
  @test e.buf.caret[1] == 9
  # The caret steps over the ``` lines of a code block, which don't show. The code itself is text that it goes into.
  key(w, Keys.down)
  @test e.buf.caret[1] == 11
  @test !raw(e, 10) && !raw(e, 12)
  key(w, Keys.down)
  @test e.buf.caret[1] == 13
  # The diagram. The caret is on all of it, and it still shows as a diagram.
  key(w, Keys.down)
  @test e.buf.caret == (14, 0) && K.picked(e.buf) == (14, 17)
  @test !(K.item(e, 15).content isa K.Flow)
  # ↓ goes on to the line after it, and ↑ comes back onto it from there
  key(w, Keys.down)
  @test e.buf.caret[1] == 18 && K.picked(e.buf) === nothing
  key(w, Keys.up)
  @test K.picked(e.buf) == (14, 17)
  key(w, Keys.up)
  @test e.buf.caret[1] == 13
  # → at the end of a line goes onto it too, and → again goes past it. ← does the same the other way.
  caret!(e, w, 13, 0)
  key(w, Keys.right)
  @test K.picked(e.buf) == (14, 17)
  key(w, Keys.right)
  @test e.buf.caret == (18, 0)
  key(w, Keys.left)
  @test K.picked(e.buf) == (14, 17)
  key(w, Keys.left)
  @test e.buf.caret[1] == 13
  # The keys that go along a line leave the caret on it
  key(w, Keys.right)
  key(w, Keys.right, cmd)
  @test K.picked(e.buf) == (14, 17)
  key(w, Keys.left, opt)
  @test K.picked(e.buf) == (14, 17) || e.buf.caret[1] == 13
  # A key can't take the caret into the diagram's code, but something that puts it there shows the code
  caret!(e, w, 15, 3)
  @test e.buf.caret == (15, 3)
  @test K.item(e, 15).content isa K.Flow
  # From its code, ↓ goes onto the diagram as a whole, and then past it
  key(w, Keys.down); key(w, Keys.down)
  @test K.picked(e.buf) == (14, 17)
  @test !(K.item(e, 15).content isa K.Flow)
  key(w, Keys.down)
  @test e.buf.caret[1] == 18
  # In a table the ** of a cell don't show, with the caret in the cell or not
  caret!(e, w, 21, 4)
  key(w, Keys.right)
  @test e.buf.caret == (21, 5)
  key(w, Keys.right)
  @test e.buf.caret[1] == 21 && e.buf.caret[2] > 7
  @test K.item(e, 21).content isa K.Grid
end

@testset "⌫ after a part that shows as one thing" begin
  e, w = window("one\n\n---\ntwo\n\n```julia\nx = 1\n```\n\nthree\n")
  # After a line across the page, the caret goes onto the line, and ⌫ again takes the line away
  caret!(e, w, 4, 0)
  key(w, Keys.backspace)
  @test e.buf.lines[3:4] == ["---", "two"] && K.picked(e.buf) == (3, 3)
  key(w, Keys.backspace)
  @test e.buf.lines[1:3] == ["one", "", "two"]
  @test e.buf.caret == (3, 0)
  # A line with nothing on it after a code block goes, and the caret is at the end of the code
  i = findfirst(==("three"), e.buf.lines) - 1
  caret!(e, w, i, 0)
  key(w, Keys.backspace)
  @test e.buf.lines[i] == "three"
  @test e.buf.lines[e.buf.caret[1]] == "x = 1" && e.buf.caret[2] == 5
  # A line with text after a code block stays, and so does the block
  caret!(e, w, i, 0)
  n = length(e.buf.lines)
  key(w, Keys.backspace)
  @test length(e.buf.lines) == n
end

@testset "↓ on a block at the end of the page starts a line under it" begin
  e, w = window("text\n\n```mermaid\ngraph TD\n  A --> B\n```")
  caret!(e, w, 1, 2)
  key(w, Keys.down)
  @test e.buf.caret[1] == 2
  key(w, Keys.down)
  @test K.picked(e.buf) == (3, 6) && length(e.buf.lines) == 6
  key(w, Keys.down)
  @test e.buf.lines[end] == "" && e.buf.caret == (7, 0)
end

@testset "a selection that grows with ⇧↓ or ⇧↑ takes a block that shows as one thing as a whole" begin
  blocks = ["```contact\nPaul Saunderson\ncompany: Pa & Ks\nmobile: 0411 777 877\n```", "```chart\nbar\na, 1\nb, 2\n```",
            "```ui\nTextInput(placeholder=\"Name\")\n```", "```mermaid\ngraph TD\n  A --> B\n```"]
  for block in blocks
    e, w = window("one\n\n$block\n\ntwo\n")
    s, t = 3, 2 + length(split(block, '\n'))
    # From the line over the block, the selection's end goes to the line under it, and then on down the page
    caret!(e, w, 2, 0)
    key(w, Keys.down, shift)
    @test e.buf.caret == (t + 1, 0) && e.buf.anchor == (2, 0)
    key(w, Keys.down, shift)
    @test e.buf.caret[1] == t + 2
    # From the line under the block, it goes to the line over it
    caret!(e, w, t + 1, 0)
    key(w, Keys.up, shift)
    @test e.buf.caret == (s - 1, 0) && e.buf.anchor == (t + 1, 0)
    # ⇧→ at the end of the line before the block takes the block too, and so does ⇧← after it
    caret!(e, w, s - 1, 0)
    key(w, Keys.right, shift)
    @test e.buf.caret == (t + 1, 0)
    key(w, Keys.left, shift)
    @test e.buf.caret == (s - 1, 0)
  end
  # A block that ends the page has no line under it. The selection ends where the block does, and stays there.
  e, w = window("one\n\n```contact\nPaul Saunderson\n```")
  caret!(e, w, 2, 0)
  key(w, Keys.down, shift)
  @test e.buf.caret == (5, 3) && length(e.buf.lines) == 5
  key(w, Keys.down, shift)
  @test e.buf.caret == (5, 3)
  # The front matter starts the page, and ⇧↑ from under it takes all of it
  e, w = window("---\ntitle: x\n---\n\none\n")
  caret!(e, w, 4, 0)
  key(w, Keys.up, shift)
  @test e.buf.caret == (1, 0) && e.buf.anchor == (4, 0)
end

@testset "what the keys do while the caret is on a part as a whole" begin
  e, w = window("one\n\n```ui\nTextInput(placeholder=\"Name\")\n```\n\ntwo\n\n```mermaid\ngraph TD\n  A --> B\n```\n\nthree\n")
  caret!(e, w, 2, 0)
  key(w, Keys.down)
  @test K.picked(e.buf) == (3, 5)
  # A character changes nothing
  type(e, w, "x")
  @test e.buf.lines[3] == "```ui" && K.picked(e.buf) == (3, 5)
  # Return gives the keyboard to the field of the form, and what's typed goes into the field
  key(w, Keys.enter)
  @test w.focus !== e && K.tabstop(w.focus)
  @test e.buf.lines[3:5] == ["```ui", "TextInput(placeholder=\"Name\")", "```"]
  # esc gives the keyboard back to the page, with the caret still on the form
  key(w, Keys.escape)
  @test w.focus === e && K.picked(e.buf) == (3, 5)
  # ⌘E shows the form's code, with the caret in it, and ⌘E again puts the caret back on the form
  key(w, Keys.e, cmd)
  frame(w)
  @test raw(e, 3) && K.picked(e.buf) === nothing
  key(w, Keys.e, cmd)
  frame(w)
  @test K.picked(e.buf) == (3, 5)
  # What's pasted goes on a line of its own under the part
  K.type!(e, "pasted")
  frame(w)
  @test e.buf.lines[3:6] == ["```ui", "TextInput(placeholder=\"Name\")", "```", "pasted"]
  key(w, Keys.z, cmd)
  # The command that moves a line moves all the lines of the part
  caret!(e, w, 2, 0)
  key(w, Keys.down)
  K.move_lines!(e, 1)
  frame(w)
  @test e.buf.lines[3:6] == ["", "```ui", "TextInput(placeholder=\"Name\")", "```"]
  @test K.picked(e.buf) == (4, 6)
  key(w, Keys.z, cmd)
  # ⌫ takes the part away
  caret!(e, w, 2, 0)
  key(w, Keys.down)
  key(w, Keys.backspace)
  @test e.buf.lines[1:4] == ["one", "", "", "two"]
  # ⌦ at the end of the line before a part goes onto it, and ⌦ again takes it away
  i = findfirst(==("```mermaid"), e.buf.lines)
  caret!(e, w, i - 1, 0)
  key(w, Keys.delete)
  @test K.picked(e.buf) == (i, i + 3)
  key(w, Keys.delete)
  @test !any(==("```mermaid"), e.buf.lines)
end

@testset "a part that's being typed shows as text until the caret leaves it" begin
  e, w = window("text\n\n")
  caret!(e, w, 3, 0)
  type(e, w, "```")
  # The third ` closes the block as well, and the caret is on the line that opens it
  @test e.buf.lines[3:4] == ["```", "```"]
  @test e.buf.caret == (3, 3)
  @test raw(e, 3)
  type(e, w, "mermaid")
  key(w, Keys.enter)
  type(e, w, "graph TD")
  key(w, Keys.enter)
  type(e, w, "A --> B")
  frame(w)
  @test e.buf.lines[3:6] == ["```mermaid", "graph TD", "  A --> B", "```"] || e.buf.lines[3:6] == ["```mermaid", "graph TD", "A --> B", "```"]
  # Its code shows while the caret is in it
  @test K.item(e, 4).content isa K.Flow
  # ↑ leaves its code. The caret is then on the diagram as a whole, and it shows as a diagram.
  key(w, Keys.up); key(w, Keys.up)
  frame(w)
  @test K.picked(e.buf) == (3, 6)
  @test !(K.item(e, 4).content isa K.Flow)
  key(w, Keys.up)
  @test e.buf.caret[1] == 2
  # A line across the page shows its dashes while they're typed
  caret!(e, w, 2, 0)
  type(e, w, "---")
  @test raw(e, 2)
  key(w, Keys.up)
  @test !raw(e, 2)
end

@testset "as plain text the part with the caret shows its markup, and the caret goes anywhere" begin
  e, w = window(PAGE)
  caret!(e, w, 3, 8)
  K.plain!(e, true)
  frame(w); frame(w)
  @test e.buf.plain
  # No line shows all its markup, and every other part of the page still shows as it reads. test/plain_runs_test.jl
  # has the run that the caret is in, and the caret that stops at each character of it.
  @test !any(i -> raw(e, i), (1, 3, 5, 6, 8, 10, 12))
  @test !(K.item(e, 15).content isa K.Flow)
  @test K.item(e, 21).content isa K.Grid
  # The caret takes the markup with it to the line that it goes to. In what starts a list item, the - shows.
  caret!(e, w, 5, 1)
  @test e.buf.caret == (5, 1)
  @test startswith(drawn(e, 5), "- first item") && !occursin("**", drawn(e, 3))
  # A code block shows its ``` lines while the caret is in it
  caret!(e, w, 11, 2)
  @test raw(e, 10) && raw(e, 12)
  # The caret goes into a diagram, which shows as its code
  caret!(e, w, 13, 0)
  key(w, Keys.down)
  @test e.buf.caret[1] == 14
  @test all(i -> K.item(e, i).content isa K.Flow && K.item(e, i).first == i, 14:17)
  caret!(e, w, 15, 3)
  @test e.buf.caret == (15, 3)
  key(w, Keys.up)
  @test e.buf.caret[1] == 14
  # ⌫ deletes one character of the file
  caret!(e, w, 3, 13)
  key(w, Keys.backspace)
  @test startswith(e.buf.lines[3], "Some **bold* words")
  key(w, Keys.z, cmd)
  # Back to rich text with the caret in the diagram's code: the diagram shows, and the caret is on it as a whole
  caret!(e, w, 15, 3)
  K.plain!(e, false)
  frame(w); frame(w)
  @test !e.buf.plain
  @test !(K.item(e, 15).content isa K.Flow)
  @test K.picked(e.buf) == (14, 17)
  @test !raw(e, 3)
end

@testset "the snake and the ladder in the top bar, and ⌘E" begin
  e, w = window(PAGE)
  caret!(e, w, 3, 8)
  key(w, Keys.e, cmd)
  @test e.plain
  frame(w)
  @test occursin("**bold**", drawn(e, 3)) && !raw(e, 1)
  key(w, Keys.e, cmd)
  @test !e.plain
  frame(w)
  # The bar shows one picture, of the level that the page is at now: a ladder while it's up. Its tip says what a click does.
  # An icon is in the button as the box that it draws in, and the box knows the icon that it came from
  icons(node, out=String[]) = begin
    (node isa K.GeometricUI && !(node isa K.Text)) || return out
    hasproperty(node, :from) && node.from isa K.Icon && push!(out, node.from.name)
    foreach(n -> icons(n, out), node.children)
    out
  end
  icon() = only(icons(K.level_picture(e.nodes[:mode])))   # the picture that shows while the slider is closed
  @test icon() == "ladder"
  @test K.tip(e.nodes[:mode]) == "Go down a level, to the symbols of the part with the caret  ⌘E"
  click(w, e.nodes[:mode])
  @test e.plain
  frame(w)
  # A snake while it's down
  @test icon() == "snake"
  @test !isempty(K.icon_cache["snake"].paths)   # UI.jl has no snake among its icons, so Ladder gives it the shape
  @test K.tip(e.nodes[:mode]) == "Go up a level, to the graphics that the symbols make  ⌘E"
  # The mouse is still over the picture, so the slider has opened out from it. Its ladder is where the picture was.
  click(w, e.nodes[K.LEVELS_KEY].stops[end])
  @test !e.plain
end

@testset "the settings file keeps how the page shows" begin
  e, w = window(PAGE)
  e.remember = true
  K.plain!(e, true)
  @test occursin("plain=true", read(kept, String))
  o = K.Editor()
  K.load_settings!(o)
  @test o.plain
  K.plain!(e, false)
  @test occursin("plain=false", read(kept, String))
  K.load_settings!(o)
  @test !o.plain
end

@testset "the caret's line stays where it is when the page changes to plain text and back" begin
  e, w = window(PAGE * join(["Line $i of the page, with some **bold** words." for i in 1:80], "\n\n") * "\n")
  n = length(e.buf.lines)
  caret!(e, w, n - 20, 3)
  frame(w); frame(w)
  @test e.scroll.offset > 0px
  y = K.item(e, n - 20).top - e.scroll.offset
  K.plain!(e, true)
  frame(w); frame(w)
  @test abs(K.num(K.item(e, n - 20).top - e.scroll.offset - y)) < 1
  K.plain!(e, false)
  frame(w); frame(w)
  @test abs(K.num(K.item(e, n - 20).top - e.scroll.offset - y)) < 1
end

@testset "the symbol of a key is drawn in a font that has it, and not as a square" begin
  for family in (K.SERIF, K.SANS), c in "⌘⌥⇧⌃⏎⇥⌫⌦⎋←→↑↓"
    ps = K.symbols!(K.Piece[], "Press $c now", 0, K.Face(family, "", 16px, K.colours.ink, false))
    @test all(p -> all(ch -> isascii(ch) || K.has(p.face, ch), p.text), ps)
  end
end

end
