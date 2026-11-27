# Tests for the blocks that a file defines, in main.jl: a code block in a
# language that Ladder doesn't know shows what a function of a file makes of
# its lines, and the lines that the file's `written` gives go back into the
# block: when the component asks, at once when it says so, and before
# something reads the page's text. Run them with `julia -O0 --project=. test/file_block_test.jl`. They
# click and drag in a window that isn't on the screen, and use no network: a
# folder stands in for a repository on GitHub. Set `LADDER_SHOTS` to a
# folder, and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect changed!
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive
const px = K.px

# The folder has the same name each time, so that Kip compiles its files once
const dir = joinpath(tempdir(), "ladder-file-block-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
const page = joinpath(dir, "job.md")
const example = joinpath(K.pages_dir[], "progress.jl")

# A kind of block that shows as text, and one that can't be made
write(joinpath(dir, "shout.jl"), """
shout(lines) = uppercase(join(lines, " "))
""")
write(joinpath(dir, "broken.jl"), """
broken(lines) = error("This block can't be made")
""")
write(joinpath(dir, "kinds.jl"), """
mutable struct Count; n::Int end
count_up(lines) = Count(something(tryparse(Int, strip(get(lines, 1, ""))), 0))
written(c::Count) = [string(c.n)]
""")

write(page, """
# A job

```progress $example
done: 0.7
label: Framing
```

Between.

```shout
lay the pipe
```

```count_up ./kinds.jl
4
```

```broken
```

```python
print("not a block")
```

```nothing_here ./missing.jl
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, press, release, click, shot) = drive(w, pressed=1)
frames()

view(lang, n=1) = e.nodes[(:block, lang, page, n)]
block(lang, n=1) = (s = K.block_lines(e.buf, lang, n); e.buf.lines[s[1]+1:s[2]-1])
"A place in the bar of the progress block: `share` of the way along it"
along(share) = (r = rect(view("progress").value).children[1]; (K.num(r.left + r.width * share), K.num(r.top + r.height / 2)))
"The text that a block shows, when what its function made isn't a node"
said(v) = v.shown.value.firstchild.content

@testset "where a block's function comes from" begin
  @test K.block_source("```progress", "progress", dir) === nothing
  @test K.block_source("```shout", "shout", dir) == "./shout.jl"
  @test K.block_source("```shout", "shout", "") === nothing
  # A file with the language's name that doesn't define the function is some other code, and isn't run
  write(joinpath(dir, "json.jl"), "parse(text) = text\njson(a, b) = a\n# json(lines) = 1\n")
  @test K.block_source("```json", "json", dir) === nothing
  write(joinpath(dir, "toml.jl"), "function toml(lines::Vector{String}; strict=false)\n  lines\nend\n")
  @test K.block_source("```toml", "toml", dir) == "./toml.jl"
  rm(joinpath(dir, "json.jl")); rm(joinpath(dir, "toml.jl"))
  @test K.block_source("```progress ./kinds.jl", "progress", dir) == "./kinds.jl"
  @test K.block_source("~~~progress  github.com/sam/blocks@v2/bars ", "progress", "") == "github.com/sam/blocks@v2/bars"
  @test K.block_source("```progress /a/b.jl", "progress", "") == "/a/b.jl"
  @test K.block_source("```progress ~/b.jl", "progress", "") == "~/b.jl"
  # Words after the language that aren't a file or a repository are something else, like a title
  @test K.block_source("```python title=\"x\"", "python", dir) === nothing
  # Ladder's own kinds stay as they are, whatever follows them and whatever files are there
  write(joinpath(dir, "board.jl"), "board(lines) = 1\n")
  @test all(lang -> K.block_source("```$lang ./kinds.jl", lang, dir) === nothing, ["board", "ui", "julia", "sheet", "mermaid", "chart"])
  rm(joinpath(dir, "board.jl"))
  @test K.repository("github.com/sam/blocks@v2/bars") == "sam/blocks" && K.repository("./kinds.jl") === nothing
end

@testset "the block shows what the file's function makes" begin
  v = view("progress")
  @test v.state == :made && v.value.done == 0.7 && v.value.label == "Framing"
  # The bar is as wide as the page's text allows, and the part that's done is 70% of it
  bar = rect(v.value).children[1]
  @test bar.width > 400px && rect(v.value).children[1].children[1].width ≈ 0.7 * bar.width
  # A value that isn't a node shows as text
  @test view("shout").state == :made && said(view("shout")) == "LAY THE PIPE"
  # A language with no file is a code block like any other, and so is a file that isn't there
  @test !haskey(e.nodes, (:block, "python", page, 1))
  @test view("nothing_here").state == :fault && view("nothing_here").fault == "Ladder can't find the file ./missing.jl. The line that opens this block names it."
  # A function that fails says why in the block
  @test view("broken").state == :fault && occursin("This block can't be made", view("broken").fault)
  # The sidebar names each block by its language
  @test [en.title for en in K.outline(e.buf) if en.icon == "puzzle"] == ["Progress", "Shout", "Count up", "Broken", "Nothing here"]
  # Nothing is written into the page by showing it
  @test !K.dirty(e.buf)
  shot("file_block.png")
end

@testset "what you do to the block goes into its lines" begin
  v = view("progress")
  made = v.value
  click(along(0.25))
  @test v.value === made && made.done == 0.25 && block("progress") == ["done: 0.25", "label: Framing"]
  # Writes that are asked for less than a second apart are one step for ⌘Z, so this one comes after a pause
  e.buf.typed = 0.0
  # A drag is written when the mouse lets go, as one change
  press(along(0.3)); at(along(0.5)); at(along(0.9))
  @test made.done == 0.9 && block("progress") == ["done: 0.25", "label: Framing"]
  release()
  @test v.value === made && block("progress") == ["done: 0.9", "label: Framing"]
  # ⌘Z puts the lines back, and the function makes the block again from them
  K.undo!(e.buf); frames()
  @test block("progress") == ["done: 0.25", "label: Framing"] && v.value !== made && v.value.done == 0.25
  # Lines that you type are read the same way
  s = K.block_lines(e.buf, "progress", 1)
  K.edit!(e.buf, (s[1] + 1, 0), K.line_end(e.buf, s[1] + 1), "done: 40%"); frames()
  # While the caret is in the block, the page shows its lines. Out of it, the block is made again.
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  @test v.value.done == 0.4 && block("progress") == ["done: 40%", "label: Framing"]
end

@testset "when a block's lines are written" begin
  c = view("count_up")
  @test c.value.n == 4
  K.save_page!(e)
  # A change that nothing asked to be written waits, and the page has no changes
  c.value.n = 5; frames()
  @test block("count_up") == ["4"] && !K.dirty(e.buf)
  # ⌘S reads the page's text, so the block is written first, and the file has it
  K.save_page!(e)
  @test block("count_up") == ["5"] && occursin("```count_up ./kinds.jl\n5\n```", read(page, String)) && endswith(said(c), "Count(5)")
  # A component that says it can't wait is written in that call
  c.value.n = 6; changed!(c, now=true)
  @test block("count_up") == ["6"] && K.dirty(e.buf)
  # One that asks is written in the next frame
  c.value.n = 7; changed!(c)
  @test block("count_up") == ["6"]
  frames()
  @test block("count_up") == ["7"]
  # ... but not while the mouse is held, so that a drag is one change
  w.keys |= Keys.mouse_left
  c.value.n = 8; changed!(c); frames()
  @test block("count_up") == ["7"]
  w.keys ⊻= Keys.mouse_left; frames()
  @test block("count_up") == ["8"]
  # The caret going into the block shows its lines, so they're written as it goes in
  c.value.n = 9; frames()
  s = K.block_lines(e.buf, "count_up", 1)
  e.buf.caret = e.buf.anchor = (s[1] + 1, 0); frames()
  @test block("count_up") == ["9"]
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  @test c.value.n == 9
  # A copy, a page of HTML and another page taking the window read the text too
  c.value.n = 10; K.write_blocks!(e)
  @test block("count_up") == ["10"]
  c.value.n = 11
  @test occursin("11", K.page_html(e)) && block("count_up") == ["11"]
  # Lines that changed under the block aren't written over: the block is made again from them
  c.value.n = 12
  s = K.block_lines(e.buf, "count_up", 1)
  K.edit!(e.buf, (s[1] + 1, 0), K.line_end(e.buf, s[1] + 1), "40")
  K.write_blocks!(e)
  @test block("count_up") == ["40"]
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  @test c.value.n == 40
end

"Write `text` to the file `name` of the folder, as an editor saves it, at a time that's later than the file's last"
save(name, text) = (file = joinpath(dir, name); was = mtime(file); write(file, text); while mtime(file) == was; sleep(0.01); touch(file) end)

@testset "a file that's saved is loaded again" begin
  v = view("shout")
  save("shout.jl", "shout(lines) = lowercase(join(lines, \" \")) * \"!\"\n")
  frames()
  @test v.state == :made && said(v) == "lay the pipe!"
  # A struct can get a new field, and what was made is made again as the new struct
  c = view("count_up")
  save("kinds.jl", """
  mutable struct Count; n::Int; step::Int end
  count_up(lines) = Count(something(tryparse(Int, strip(get(lines, 1, ""))), 0), 10)
  written(c::Count) = [string(c.n)]
  """)
  frames()
  @test c.state == :made && c.value.step == 10 && c.value.n == 40
  c.value.n += c.value.step; changed!(c, now=true)
  @test block("count_up") == ["50"]
  # What a block holds and hasn't written is written before its file is loaded again
  c.value.n = 60
  save("kinds.jl", """
  mutable struct Count; n::Int; step::Int end
  count_up(lines) = Count(something(tryparse(Int, strip(get(lines, 1, ""))), 0), 5)
  written(c::Count) = [string(c.n)]
  """)
  frames()
  @test c.value.n == 60 && c.value.step == 5 && block("count_up") == ["60"]
  # A file that doesn't parse says so in its blocks, and a fix puts them back
  save("shout.jl", "shout(lines) = (")
  frames()
  @test v.state == :fault && !isempty(v.fault)
  save("shout.jl", "shout(lines) = \"fixed\"\n")
  frames()
  @test v.state == :made && said(v) == "fixed"
  # A file that failed when it was first loaded is tried again when it's saved
  b = view("broken")
  save("broken.jl", "broken(lines) = \"mended\"\n")
  frames()
  @test b.state == :made && said(b) == "mended"
end

@testset "a Markdown page defines a kind of block" begin
  # The page's `julia` blocks are its code, and the rest of it is words
  stars = joinpath(dir, "stars.md")
  write(stars, """
  # Stars

  A block in the language `stars` counts its stars.

  ```julia
  mutable struct Stars; n::Int end
  stars(lines) = Stars(count(==('*'), join(lines)))
  ```

  This isn't code that runs:

  ```python
  stars(lines) = error("not Julia")
  ```

  ```julia
  written(s::Stars) = ["*"^s.n]
  ```

  One to try:

  ```stars
  **
  ```
  """)
  @test K.block_source("```stars", "stars", dir) == "./stars.md"
  @test first.(K.page_code(stars)) == [6, 17] && K.defines(stars, "stars") && !K.defines(stars, "error")
  # A Julia file with the same name comes first
  write(joinpath(dir, "stars.jl"), "stars(lines) = 1\n")
  @test K.block_source("```stars", "stars", dir) == "./stars.jl"
  rm(joinpath(dir, "stars.jl"))
  # A page whose `julia` blocks don't define the function is a page like any other
  write(joinpath(dir, "notes.md"), "# Notes\n\n```julia\nx = 1\n```\n")
  @test K.block_source("```notes", "notes", dir) === nothing
  # A block of another page, with the page found by its name and with the page named
  i = findfirst(==("The end."), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, 0), "```stars\n***\n```\n\n```stars ./stars.md\n*\n```\n\n")
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  a, b = view("stars"), view("stars", 2)
  @test a.state == :made && a.value.n == 3 && b.state == :made && b.value.n == 1
  @test typeof(a.value) === typeof(b.value)   # one module for the page
  a.value.n = 5; changed!(a, now=true)
  @test block("stars") == ["*****"]
  # The page's own block is of the kind that the page defines
  o = K.build_editor(stars)
  win = Window(o, size=(1000px, 900px))
  foreach(_ -> frame(win), 1:2)
  own = o.nodes[(:block, "stars", stars, 1)]
  @test own.state == :made && own.value.n == 2 && typeof(own.value) === typeof(a.value)
  close(win)
  # The page is run again when it's saved
  save("stars.md", replace(read(stars, String), "count(==('*'), join(lines))" => "10 * count(==('*'), join(lines))"))
  frames()
  @test a.state == :made && a.value.n == 50
  # Code that fails names the line of the page that it's on
  save("stars.md", replace(read(stars, String), "written(s::Stars) = " => "nothing_called_this()\nwritten(s::Stars) = "))
  frames()
  @test a.state == :fault && startswith(a.fault, "Line 17 of stars.md: ")
  save("stars.md", replace(read(stars, String), "nothing_called_this()\n" => ""))
  frames()
  @test a.state == :made
end

@testset "the caret" begin
  s = K.block_lines(e.buf, "progress", 1)
  # The caret steps over the block as a whole, and a language with no file is lines of code
  @test K.solid(e.buf, s[1] + 1) == (s[1], s[2])
  p = findfirst(==("```python"), e.buf.lines)
  @test K.solid(e.buf, p + 1) === nothing
end

@testset "a repository on GitHub" begin
  # A folder stands in for the repository, as a repository that Kip has on this Mac
  repos, was = joinpath(dir, "repos"), K.Kip.repos
  mkpath(joinpath(repos, "sam", "blocks"))
  write(joinpath(repos, "sam", "blocks", "main.jl"), """
  stamp(lines) = "Stamped: " * join(lines, ", ")
  """)
  setglobal!(K.Kip, :repos, repos)
  try
    empty!(K.ALLOWED)
    i = findfirst(==("The end."), e.buf.lines)
    K.edit!(e.buf, (i, 0), (i, 0), "```stamp github.com/sam/blocks\none\ntwo\n```\n\n```stamp github.com/sam/blocks\nthree\n```\n\n```stamp github.com/sam/elsewhere\n```\n\n")
    frames()
    v, second, far = view("stamp"), view("stamp", 2), view("stamp", 3)
    # Ladder asks before it runs the code of a repository, and loads nothing until you say
    @test v.state == :ask && second.state == :ask && v.from === nothing
    shot("file_block_ask.png")
    click(let r = rect(v.parts[(:button, :allow)]); (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2)) end)
    frames()
    @test v.state == :made && said(v) == "Stamped: one, two"
    # The other block from that repository runs too, and a block from another repository still asks
    @test second.state == :made && said(second) == "Stamped: three" && far.state == :ask
    @test "sam/blocks" in K.ALLOWED && !("sam/elsewhere" in K.ALLOWED)
    # A window that a test makes keeps nothing in the user's own files
    @test !e.remember
    # A page of a repository defines a kind of block too
    write(joinpath(repos, "sam", "blocks", "seal.md"), "# Seal\n\n```julia\nseal(lines) = \"Sealed: \" * join(lines)\n```\n")
    i = findfirst(==("The end."), e.buf.lines)
    K.edit!(e.buf, (i, 0), (i, 0), "```seal github.com/sam/blocks/seal.md\nwax\n```\n\n")
    e.buf.caret = e.buf.anchor = (1, 0); frames()
    @test view("seal").state == :made && said(view("seal")) == "Sealed: wax"
    # A repository that isn't on this Mac says that it's coming before it comes
    K.allow!(e, "sam/elsewhere"); far.state = :new; K.make!(far)
    @test far.state == :wait
    delete!(K.ALLOWED, "sam/elsewhere"); far.state = :ask
  finally
    setglobal!(K.Kip, :repos, was)
  end
end

close(w)
rm(dir, recursive=true, force=true)

@testset "the page that comes with Ladder and defines a counter" begin
  counter = joinpath(K.pages_dir[], "counter.md")
  o = K.build_editor(counter)
  win = Window(o, size=(1000px, 900px))
  foreach(_ -> frame(win), 1:3)
  v = o.nodes[(:block, "counter", counter, 1)]
  @test v.source == "./counter.md" && v.state == :made && v.value.count == 3
  # A click adds one, and the block's line has it once the mouse lets go
  r = rect(v.value)
  x, y = K.num(r.left + r.width / 2), K.num(r.top + r.height / 2)
  win.mouse = typeof(win.mouse)(px(x), px(y)); onmouse(win, MouseMove(Vec2{px}(px(x), px(y)), win)); frame(win)
  win.keys |= Keys.mouse_left; onkey(win, KeyPress{Keys.mouse_left}(0, win)); frame(win)
  win.keys ⊻= Keys.mouse_left; onkey(win, KeyRelease{Keys.mouse_left}(0, win)); foreach(_ -> frame(win), 1:2)
  s = K.block_lines(o.buf, "counter", 1)
  @test v.value.count == 4 && o.buf.lines[s[1]+1:s[2]-1] == ["4"]
  K.undo!(o.buf); foreach(_ -> frame(win), 1:2)
  @test o.buf.lines[s[1]+1:s[2]-1] == ["3"] && v.value.count == 3 && !K.dirty(o.buf)
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "counter.png"), win)
  close(win)
end

@testset "the welcome page's own block" begin
  welcome = joinpath(K.pages_dir[], "welcome.md")
  o = K.build_editor(welcome)
  win = Window(o, size=(1000px, 900px))
  frame(win)
  # The page is drawn where the block is, since an editor only makes the blocks that are in the window
  s = K.block_lines(o.buf, "progress", 1)
  o.scroll.offset = K.item(o, s[1]).top - 200px
  foreach(_ -> frame(win), 1:3)
  v = o.nodes[(:block, "progress", welcome, 1)]
  # A block with no file named after its language is for the file with the language's name, beside the page
  @test v.source == "./progress.jl" && v.state == :made && v.value.done == 0.7 && v.value.label == "Framing"
  @test !K.dirty(o.buf)
  close(win)
end
