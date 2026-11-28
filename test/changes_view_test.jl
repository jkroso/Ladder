# Tests for the `changes` block of main.jl: the changes of a diff, with
# buttons that accept and reject each one. Accept makes a change in its
# file, and the tests check those files too. Run them with
# `julia -O0 --project=. test/changes_view_test.jl`. They click in a window
# that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a
# picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "review.md")
write(page, """
# A review

```changes
--- a/src/app.js
+++ b/src/app.js
@@ -10,4 +10,5 @@ function start() {
   const a = 1
-  const b = 2
+  const b = 3
+  const c = 4
   return a
@@ -30 +31 @@
-  stop()
+  stop(now)
--- a/Readme.md
+++ b/Readme.md
@@ -1,2 +1,2 @@
-# App
+# The app
 It starts with `start()`.
```

The end.

```changes
```

```changes
--- a/greet.jl
+++ b/greet.jl
@@ -1,3 +1,4 @@
 greet(name) = begin
-  println("Hello ", name)   # say hello to the person whose name it is, and end the line with a mark that shows how glad we are to see them
+  isempty(name) && return
+  println("Hello, ", name, "!")   # say hello to the person whose name it is, and end the line with a mark that shows how glad we are to see them
 end
```
""")

# The files that the diffs change, as they are before any change is made
const APP = ["// line $i" for i in 1:35]
APP[10:12] = ["  const a = 1", "  const b = 2", "  return a"]
APP[30] = "  stop()"
const README = "# App\nIt starts with `start()`.\n"
const GREET = "greet(name) = begin\n  println(\"Hello \", name)   # say hello to the person whose name it is, and end the line with a mark that shows how glad we are to see them\nend\n"
mkpath(joinpath(dir, "src"))
write(joinpath(dir, "src", "app.js"), join(APP, "\n") * "\n")
write(joinpath(dir, "Readme.md"), README)
write(joinpath(dir, "greet.jl"), GREET)
app() = readlines(joinpath(dir, "src", "app.js"))
readme() = read(joinpath(dir, "Readme.md"), String)

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, press, release, click, shot) = drive(w)
frames()
view(n) = e.nodes[(:block, K.CHANGES, page, n)]

button(key) = click(middle(rect(view(1).parts[(:button, key)])))
block(n=1) = (s = K.block_lines(e.buf, K.CHANGES, n); e.buf.lines[s[1]+1:s[2]-1])

@testset "the block shows each change" begin
  v = view(1)
  @test length(v.data.hunks) == 3 && K.Diffs.summary(v.data) == "3 changes"
  # The lines of a change are as tall as the change has lines
  @test rect(v.parts[(:hunk, 1)]).height == px(5 * K.DIFF_ROW + 8) && rect(v.parts[(:hunk, 2)]).height == px(2 * K.DIFF_ROW + 8)
  @test rect(v.parts[(:hunk, 3)]).top > rect(v.parts[(:hunk, 2)]).top > rect(v.parts[(:hunk, 1)]).top
  # The row over a change names its file, so a file has no row of its own
  @test K.change_words(v.data.hunks[1]) == ("src/app.js", "lines 10 to 13") && K.change_words(v.data.hunks[3]) == ("Readme.md", "lines 1 to 2")
  @test K.change_words(K.Diffs.changes(["@@ -3 +3 @@", "-a", "+b"]).hunks[1]) == ("", "Line 3")
  @test rect(v.parts[(:hunk, 3)]).top - (rect(v.parts[(:hunk, 2)]).top + rect(v.parts[(:hunk, 2)]).height) == 34px
  # A long path loses its first folders
  @test K.short_path("src/app.js") == "src/app.js"
  @test K.short_path("packages/editor/src/components/toolbar/buttons/Bold.jsx", 30) == "…/toolbar/buttons/Bold.jsx"
  @test isempty(view(2).data.hunks)
  @test any(en -> en.title == "Changes", K.outline(e.buf))
  @test !K.dirty(e.buf)
end

@testset "the buttons accept and reject a change" begin
  # Accept makes the change in its file
  button((:accept, 1))
  @test block()[3] == "@@ -10,4 +10,5 @@ function start() { [accepted]" && view(1).data.hunks[1].state == :accepted && K.dirty(e.buf)
  @test app()[10:13] == ["  const a = 1", "  const b = 3", "  const c = 4", "  return a"] && length(app()) == 36
  # Reject changes no file
  button((:reject, 2))
  @test block()[9] == "@@ -30 +31 @@ [rejected]" && K.Diffs.summary(view(1).data) == "3 changes  ·  1 accepted  ·  1 rejected"
  @test app()[31] == "  stop()"
  shot("changes.png")
  # A click on the choice that a change has takes it away
  button((:reject, 2))
  @test block()[9] == "@@ -30 +31 @@"
  # Rejecting a change that was accepted takes it out of the file again
  button((:reject, 1))
  @test endswith(block()[3], "{ [rejected]") && app() == APP
  # ⌘Z changes only the page, so the file doesn't have the change that the page says is accepted
  K.undo!(e.buf); frames()
  @test endswith(block()[3], "{ [accepted]") && view(1).data.hunks[1].state == :accepted && app() == APP
  button(:reject_all)
  @test all(h -> h.state == :rejected, view(1).data.hunks) && count(l -> endswith(l, "[rejected]"), block()) == 3
  @test app() == APP && readme() == README && isempty(view(1).failed)
  button(:accept_all)
  @test count(l -> endswith(l, "[accepted]"), block()) == 3 && length(block()) == 17
  # The first change added a line, so the second is a line lower than its @@ line says
  @test app()[11:12] == ["  const b = 3", "  const c = 4"] && app()[31] == "  stop(now)" && readme() == "# The app\nIt starts with `start()`.\n"
  @test e.buf.lines[findfirst(==("The end."), e.buf.lines)] == "The end."
  html = K.page_html(e)
  @test occursin("<strong>src/app.js · Lines 10 to 13 · Accepted</strong>", html) && occursin("+   const c = 4</span>", html)
end

@testset "a change that doesn't fit its file" begin
  v = view(1)
  # A click on Accepted takes the change out of its file
  button((:accept, 3))
  @test v.data.hunks[3].state == :open && readme() == README
  top = rect(v.parts[(:hunk, 3)]).top
  # The file changed after the diff was written, so the change keeps the choice that it had, and a line says why
  write(joinpath(dir, "Readme.md"), "# Something else\n")
  button((:accept, 3))
  @test v.data.hunks[3].state == :open && block()[14] == "@@ -1,2 +1,2 @@" && readme() == "# Something else\n"
  @test v.failed[3] == "The lines that this change takes away aren't in Readme.md now, so Ladder didn't change the file."
  @test rect(v.parts[(:hunk, 3)]).top > top
  shot("changes-failed.png")
  # A change can be rejected whatever is in its file. The next click forgets what went wrong.
  button((:reject, 3))
  @test v.data.hunks[3].state == :rejected && isempty(v.failed) && rect(v.parts[(:hunk, 3)]).top == top && readme() == "# Something else\n"
  # A file that isn't there
  rm(joinpath(dir, "Readme.md"))
  button((:accept, 3))
  @test v.data.hunks[3].state == :rejected && v.failed[3] == "There's no file at $(joinpath(dir, "Readme.md")), so Ladder didn't make this change."
  write(joinpath(dir, "Readme.md"), README)
  button((:accept, 3))
  @test v.data.hunks[3].state == :accepted && isempty(v.failed) && readme() == "# The app\nIt starts with `start()`.\n"
end

@testset "the lines of a change" begin
  v = view(3)
  wide = K.diff_wide(v)
  l = K.laid(v, 1, wide)
  @test rect(v.parts[(:hunk, 1)]).width == px(wide) && !l.beside
  # A line that's too long goes on under itself, as far in as the line's first word
  @test length(l.bands) == 5 && length(l.bands[4].lines[1]) > 1 && l.bands[4].tall == K.DIFF_ROW * length(l.bands[4].lines[1])
  @test rect(v.parts[(:hunk, 1)]).height == px(l.tall + 8) && l.tall > 5 * K.DIFF_ROW
  @test K.hang(l.texts[4], l.room) == l.texts[4].xs[3] && all(span -> last(span) - first(span) + 1 <= l.room / l.texts[4].xs[2], l.bands[4].lines[1])
  @test join(String(l.texts[4].chars[span]) for span in l.bands[4].lines[1]) == v.data.hunks[1].rows[4].text
  # The lines have the colours of Julia code, because the file is greet.jl
  @test (3:9, :call) in l.texts[2].parts && (11:18, :string) in l.texts[2].parts && any(p -> p[2] == :comment, l.texts[2].parts)
  # The lines of Readme.md have the colours of Markdown: its heading has a colour, and isn't the comment that Julia would read
  heading = K.laid(view(1), 3, wide).texts[2]
  @test String(heading.chars) == "# The app" && !isempty(heading.parts) && all(p -> p[2] ∉ (:plain, :comment), heading.parts)
  # The old line is beside its new version, and the new line's other words are marked
  @test l.texts[4].marks[1] == 17:17 && isempty(l.texts[3].marks)
  shot("changes-under.png")
end

@testset "the old lines beside the new" begin
  v = view(3)
  wide = K.diff_wide(v)
  before = rect(view(1).parts[(:hunk, 1)]).height
  button(:beside)
  @test e.beside && v.parts[(:button, :beside)].on && !v.parts[(:button, :under)].on
  l = K.laid(v, 1, wide)
  @test l.beside && [b.rows for b in l.bands] == [(1, 1), (0, 3), (2, 4), (5, 5)]
  @test rect(v.parts[(:hunk, 1)]).height == px(l.tall + 8)
  # The first change of the first block has a line less across: the line that goes is beside the first line that comes
  @test rect(view(1).parts[(:hunk, 1)]).height == before - px(K.DIFF_ROW)
  shot("changes-beside.png")
  button(:under)
  @test !e.beside && rect(view(1).parts[(:hunk, 1)]).height == before
  # A block that's too narrow shows the new lines under the old, whatever the setting
  @test !K.beside(v, K.BESIDE_LEAST - 1) && (e.beside = true; K.beside(v, K.BESIDE_LEAST)) && (e.beside = false; true)
end

@testset "a comment on a line" begin
  v = view(3)
  # The block is near the bottom of the window, so the page goes up to show all of it
  e.scroll.offset += rect(v).top - 120px; frames()
  area = v.parts[(:hunk, 1)]
  l = K.laid(v, 1)
  tall = rect(area).height
  row(j) = (r = rect(area); b = K.laid(v, 1).bands[findfirst(b -> b.note == 0 && j in b.rows, K.laid(v, 1).bands)];
            (K.num(r.left) + 200, K.num(r.top) + 4 + b.top + 6))
  input = K.note_input(v)
  type(words) = (input.text *= words; input.anchor = input.cursor = length(input.text); frames())
  # The mouse on a line shows that a click does something, and the click opens a field under the line
  at(row(3))
  @test area.over == 3 && K.cursor(area) == :hand
  shot("changes-hover.png")
  click(row(3))
  @test v.noting == (1, 3) && w.focus === input && rect(area).height == tall + px(K.NOTE_FIELD + 8)
  @test rect(input) !== nothing && rect(input).top > rect(area).top + px(K.laid(v, 1).bands[3].top)
  shot("changes-field.png")
  # What's typed is written at the end of the block as it's typed
  type("Throw an error ")
  @test block(3)[end-1:end] == ["# Comment on change 1, line 3: +  isempty(name) && return", "# Throw an error "]
  @test v.noting == (1, 3) && input.text == "Throw an error " && K.Diffs.summary(v.data) == "1 change  ·  1 comment"
  # Return closes the field, and the comment shows under its line
  onkey(w, KeyPress{Keys.enter}(0, w)); frames()
  @test v.noting === nothing && block(3)[end] == "# Throw an error" && w.focus !== input
  bands = K.laid(v, 1).bands
  @test bands[4].note == 3 && bands[4].said == ["Throw an error"] && rect(area).height == tall + px(K.NOTE_ROW + 18)
  shot("changes-comment.png")
  # A click on the comment opens it again. Esc puts back what it said.
  r = rect(area)
  click((K.num(r.left) + 200, K.num(r.top) + 4 + bands[4].top + 10))
  @test v.noting == (1, 3) && input.text == "Throw an error"
  type(", and say why")
  @test block(3)[end] == "# Throw an error, and say why"
  onkey(w, KeyPress{Keys.escape}(0, w)); frames()
  @test v.noting === nothing && block(3)[end] == "# Throw an error"
  # A choice keeps the comment, and the page as HTML has it
  button3(key) = click(middle(rect(v.parts[(:button, key)])))
  button3((:accept, 1))
  @test block(3)[3] == "@@ -1,3 +1,4 @@ [accepted]" && block(3)[end] == "# Throw an error"
  @test readlines(joinpath(dir, "greet.jl"))[2:3] == ["  isempty(name) && return", "  println(\"Hello, \", name, \"!\")   # say hello to the person whose name it is, and end the line with a mark that shows how glad we are to see them"]
  @test occursin("<blockquote><code>+  isempty(name) &amp;&amp; return</code><br>Throw an error</blockquote>", K.page_html(e))
  # A long comment goes on under itself
  click(row(2)); type("This line said hello to the person whose name it is, and that was all that it did, so say why it has to say more now than it did")
  click(row(1))
  @test v.noting == (1, 1) && length(K.laid(v, 1).bands[findfirst(b -> b.note == 2, K.laid(v, 1).bands)].said) == 2
  # A click somewhere else closes the field, and a field with no words leaves no comment
  click((300, 60))
  @test v.noting === nothing && !haskey(v.data.notes, (1, 1)) && length(v.data.notes) == 2
  # The button beside the field takes the comment away
  click(row(3)); button3(:unsay)
  @test v.noting === nothing && collect(keys(v.data.notes)) == [(1, 2)] && count(startswith("# Comment"), block(3)) == 1
  # With the old lines beside the new, the comment on a line that goes is under the old lines
  button3(:beside)
  l = K.laid(v, 1)
  @test l.beside && K.note_box(true, l.gutter, '-', 778.0)[1] < 389 < K.note_box(true, l.gutter, '+', 778.0)[1]
  shot("changes-comment-beside.png")
  button3(:under)
  # A click with ⌥ held is the page's. It opens no field, and the caret goes into the block to show its lines.
  w.keys |= Keys.opt; click(row(3)); w.keys ⊻= Keys.opt
  span = K.block_lines(e.buf, K.CHANGES, 3)
  @test v.noting === nothing && span[1] < e.buf.caret[1] <= span[2]
end
