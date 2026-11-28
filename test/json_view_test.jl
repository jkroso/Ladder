# Tests for a JSON file, which the page shows as a tree of its values. See "a
# JSON file as a tree" in main.jl. Run them with
# `julia -O0 --project=. test/json_view_test.jl`. They write JSON files into a
# temporary folder, and click in a window that isn't on the screen. Set
# `LADDER_SHOTS` to a folder, and they save pictures of the tree there.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./drive" drive
const px = K.px

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); write(path, text); path)

const small = file("job.json", """
{"job": "Kitchen", "rooms": 3, "price": 1.50, "paid": false, "note": null,
 "client": {"name": "Sam Lee", "phone": "0400 000 000"},
 "items": [{"name": "Paint", "count": 2}, {"name": "Timber", "count": 12}], "tags": [], "extra": {}}
""")
# A list of 300 pages, each with 20 people: about 6,000 objects
const big = file("pages.json", "[" * join(("""{"type": "GF", "page": $p, "response": {"message": "", "people": [""" *
  join(("""{"id": $(p * 100 + i), "name": "Person $i", "town": "PERTH", "phone": null}""" for i in 1:20), ", ") * "]}}" for p in 1:300), ",\n") * "]")
const broken = file("broken.json", """{"job": "Kitchen", """)

const page = file("index.md", "# Files\n")
const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const (; frames, press, release, key, shot) = drive(w)
frames()

"Click row `i` of the tree `t`"
click(t, i, held...) = (r = rect(t); press((r.left + 40px, r.top + K.json_row_h(e) * (i - 0.5)), held...); release(held...))
"The tree of the page"
tree() = only(n.viewer for n in values(e.nodes) if n isa K.FileView && n.path == e.buf.path)
"How many rows of `t` were made in the last frame, and the two spaces above and below them"
made(t) = (c = rect(t); while length(c.children) == 1; c = c.children[1]; end; length(c.children))
"The key and the text of row `i` of `t`, as the row shows them"
shown(t, i) = (t.rows[i].key, K.json_shown(t, i, 200)[1])

@testset "JSON is read with its keys in order, and its numbers as they're written" begin
  v = K.json_value(Vector{UInt8}("""﻿ {"b": 1, "a": [1.50, -2e3, 12345678901234567890], "c": "tab\\tquote\\" \\u00e9 \\ud83d\\ude00", "d": true, "e": null}"""))
  @test v isa K.JSONObject && v.keys == ["b", "a", "c", "d", "e"]
  @test [n.text for n in v.values[2]] == ["1.50", "-2e3", "12345678901234567890"]
  @test v.values[3] == "tab\tquote\" é 😀" && v.values[4] === true && v.values[5] === nothing
  @test K.json_value(Vector{UInt8}("[]")) == Any[] && K.json_value(Vector{UInt8}(" 42 ")).text == "42"
  for bad in ("", "{", "[1,]", "{\"a\" 1}", "[1] 2", "nope", "01", "\"open")
    @test_throws Exception K.json_value(Vector{UInt8}(bad))
  end
  # Copied as JSON, it reads back the same
  @test K.json_copy(v) == "{\n  \"b\": 1,\n  \"a\": [\n    1.50,\n    -2e3,\n    12345678901234567890\n  ],\n  \"c\": \"tab\\tquote\\\" é 😀\",\n  \"d\": true,\n  \"e\": null\n}"
  @test K.json_copy(K.json_value(Vector{UInt8}(K.json_copy(v)))) == K.json_copy(v)
  @test K.json_copy("Sam Lee") == "Sam Lee"
end

@testset "a JSON file shows as a tree, open as far as a window of rows goes" begin
  K.open!(e, small)
  frames(3)
  @test e.buf.view == :file && K.readonly(e.buf)
  t = tree()
  # The first row is the whole file, an object. Its keys are rows under it, and the objects and lists in it are open too.
  @test shown(t, 1) == (nothing, "{9 keys}") && t.rows[1].depth == 0
  @test [r.key for r in t.rows if r.depth == 1] == ["job", "rooms", "price", "paid", "note", "client", "items", "tags", "extra"]
  @test shown(t, 2) == ("job", "\"Kitchen\"") && shown(t, 4) == ("price", "1.50") && shown(t, 6) == ("note", "null")
  i = findfirst(r -> r.key == "items", t.rows)
  @test shown(t, i) == ("items", "[2 items]") && t.rows[i+1].key == 0 && t.rows[i+1].depth == 2
  # What's said about the file is in the top bar, as it is for a CSV file, and the tree starts just under the bar
  @test startswith(e.buf.about, "233 bytes  ·  Changed ") && endswith(e.buf.about, "  ·  9 keys")
  @test K.num(rect(t).top) < K.num(K.TOPBAR_H) + 30
  @test shown(t, findfirst(r -> r.key == "tags", t.rows))[2] == "[]"
  shot("json-small.png")
  # A click closes an open object, and its row shows what it holds
  c = findfirst(r -> r.key == "client", t.rows)
  click(t, c)
  @test t.chosen == c && !K.json_opened(t, c)
  @test shown(t, c)[2] == "{name: \"Sam Lee\", phone: \"0400 000 000\"}"
  @test t.rows[c+1].key == "items"
  click(t, c)
  @test K.json_opened(t, c) && t.rows[c+1].key == "name"
end

@testset "the arrow keys go through the rows, and open and close them" begin
  t = tree()
  c = findfirst(r -> r.key == "client", t.rows)
  click(t, c)   # closed
  @test w.focus === t
  key(Keys.right)
  @test K.json_opened(t, c) && t.chosen == c
  key(Keys.right)
  @test t.chosen == c + 1 && t.rows[t.chosen].key == "name"
  key(Keys.down)
  @test t.rows[t.chosen].key == "phone"
  key(Keys.left)
  @test t.chosen == c
  key(Keys.left)
  @test !K.json_opened(t, c)
  key(Keys.enter)
  @test K.json_opened(t, c)
  # With ⌃, ⌥ or ⇧ held, the arrows and Return are the window's, and the tree stays as it is
  for (k, held) in ((Keys.left, Keys.opt), (Keys.left, Keys.ctrl), (Keys.down, Keys.shft), (Keys.enter, Keys.shft))
    key(k, held)
    @test K.json_opened(t, c) && t.chosen == c && w.focus === t
  end
  key(Keys.up)
  @test t.chosen == c - 1
  # Esc gives the keyboard back to the page
  key(Keys.escape)
  @test w.focus === e
end

@testset "⌘E shows the file's text, and the tree again as it was" begin
  t = tree()
  c = findfirst(r -> r.key == "client", t.rows)
  click(t, c)   # closed
  @test K.json_page(e.buf) && !K.low(e)
  @test any(n -> n isa K.Mode, values(e.nodes))
  K.level!(e); frames()
  @test e.buf.view == :text && K.low(e) && startswith(e.buf.lines[1], "{\"job\"")
  K.level!(e); frames()
  @test e.buf.view == :file && !K.low(e)
  @test tree() === t && !K.json_opened(t, c)
end

@testset "closed, the tree is one row that says what the file holds" begin
  K.open!(e, big)
  frames(3)
  t = tree()
  click(t, 1)
  @test length(t.rows) == 1 && !K.json_opened(t, 1)
  # It's a list: as many of its items as the row has room for, then how many more there are
  m = match(r"^\[((?:\{…\}, )+)… (\d+) more\]$", shown(t, 1)[2])
  @test m !== nothing && count("{…}", m[1]) + parse(Int, m[2]) == 300
  shot("json-closed.png")
  click(t, 1)
  @test length(t.rows) == 301
  # A file that holds one value is one row, with nothing to open
  K.open!(e, file("one.json", "42")); frames(3)
  @test tree().rows == [K.JSONRow(0, nothing, K.JSONNumber("42"))] || shown(tree(), 1) == (nothing, "42")
end

@testset "a file that isn't JSON shows its text" begin
  K.open!(e, broken)
  frames(3)
  @test e.buf.view == :text && !K.json_page(e.buf)
  @test e.buf.lines[1] == "{\"job\": \"Kitchen\", "
end

@testset "a big file makes only the rows in the window" begin
  took = @elapsed K.open!(e, big)
  frames(3)
  t = tree()
  # The list, and its 300 pages: the next level would be too many
  @test length(t.rows) == 301 && shown(t, 1)[2] == "[300 items]" && !K.json_opened(t, 2)
  @test shown(t, 2)[2] == "{type: \"GF\", page: 1, response: {…}}"
  @test took < 5
  shot("json-big.png")
  # ⌥-click opens all of a page
  click(t, 2, Keys.opt)
  @test length(t.rows) == 301 + 3 + 2 + 20 * 5
  # Everything opened is 6,000 objects or so, and a frame still makes only the rows in the window
  K.json_each(v -> t.open[v] = true, t.root)
  t.rows = K.json_rows(t)
  @test length(t.rows) > 30_000
  frames()
  @test made(t) < 80
  e.scroll.offset = 200_000px
  frames(2)
  @test made(t) < 80
  took = @elapsed frames(10)
  @test took < 2
  shot("json-big-open.png")
end
