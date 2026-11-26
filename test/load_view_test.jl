# Tests for the `load` block of main.jl, which shows the rows of a file or of
# a server as a table. See "rows loaded from a server or a file". Run them with
# `julia -O0 --project=. test/load_view_test.jl`. They write files into a
# temporary folder and click in a window that isn't on the screen. A function
# stands in for the server, and no key goes into the Keychain. Set
# `LADDER_SHOTS` to a folder, and they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive
const px = K.px

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); write(path, text); path)
const ORDERS = """
{"data": {"orders": [
  {"id": "A1", "status": "shipped", "total": 250, "customer": {"name": "Ann", "city": "Sydney"}},
  {"id": "A2", "status": "packed", "total": 80.5, "customer": {"name": "Bob", "city": "Perth"}},
  {"id": "A3", "status": "shipped", "total": 1200, "customer": {"name": "Cy", "city": "Sydney"}}%s
]}}
"""
const orders = file("orders.json", replace(ORDERS, "%s" => ""))

# The copies of what the server sent go in a folder of the test's own
K.LOAD_CACHE[] = mktempdir()
# What the server is asked, and what it sends back, in order. Each answer comes at the second look.
const asks = []
const answers = []
K.LOAD_GETTER[] = (url, key, out) -> begin
  push!(asks, (url=url, key=key))
  a = popfirst!(answers)
  write(out, a.body)
  looks = Ref(0)
  () -> (looks[] += 1) < 2 ? nothing : (nokey=a.nokey, code=a.code, type=a.type, body=out, error=a.error)
end
answer(code, type, body; nokey=false, error="") = push!(answers, (code=code, type=type, body=body, nokey=nokey, error=error))
answer(200, "application/json; charset=utf-8", """{"data": [{"id": "S1", "total": 10}, {"id": "S2", "total": 300}]}""")

const page = joinpath(dir, "loads.md")
write(page, """
# Loads

```load
from: orders.json
at: data.orders
```

```filter
where: total > 100
```

## Server

```load
from: https://api.example.com/orders
```

```save
to: server rows.csv
```

## Keyed

```load
from: http://api.example.com/rows
key: shop
```

```filter
from: https://api.example.com/orders
```

```load
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1100px))
const (; frames, at, press, release, click, shot) = drive(w)
frames()

middle(r) = (K.num(r[1] + r[3] / 2), K.num(r[2] + r[4] / 2))
view(lang, n) = e.nodes[(:block, lang, page, n)]
"Scroll the page until the top of the `n`th block in `lang` is near the top of the window, and it has been laid out and drawn"
show_block(lang, n) = begin
  s = K.block_lines(e.buf, lang, n)
  K.show_line!(e, s[2] + 1); frames(2)
  e.scroll.offset = max(0px, K.item(e, s[1]).top - 40px); frames(3)
  view(lang, n)
end
button(v, key) = v.parts[(:button, key)]
"The rows that a filter or a load block shows, with the names of its columns first"
shown(v) = (x = K.filter_shown!(v); x.subset === nothing ? [] : K.filter_table(x.data, x.subset))

try

@testset "a load block shows the rows of a file" begin
  v = show_block(K.LOAD, 1)
  @test K.block_lang(v) == K.LOAD && K.block_span(e.buf, v) == K.block_lines(e.buf, K.LOAD, 1)
  @test shown(v)[1] == ["id", "status", "total", "customer.name", "customer.city"] && length(shown(v)) == 4
  # It has no conditions, so it shows no field for them, and no line about a server
  @test !haskey(v.parts, :add) && K.load_note(v) == ""
  shot("load-file.png")
  # A filter under it narrows its rows
  f = show_block(K.FILTER, 1)
  @test [r[1] for r in shown(f)[2:end]] == ["A1", "A3"]
  # When the file changes, both show its new rows
  write(orders, replace(ORDERS, "%s" => """,\n  {"id": "A4", "status": "packed", "total": 640, "customer": {"name": "Di", "city": "Hobart"}}"""))
  frames(3)
  @test length(shown(view(K.LOAD, 1))) == 5 && [r[1] for r in shown(f)[2:end]] == ["A1", "A3", "A4"]
end

@testset "a load block asks its server when the page opens" begin
  v = show_block(K.LOAD, 2)
  frames(3)
  @test length(asks) == 1 && asks[1] == (url="https://api.example.com/orders", key="")
  @test shown(v) == [["id", "total"], ["S1", "10"], ["S2", "300"]]
  @test K.filter_shown!(v).data.name == "api.example.com"
  @test startswith(K.load_note(v), "Loaded from api.example.com at ") && !v.failed
  @test isfile(K.load_stem("https://api.example.com/orders") * ".json")
  # It asks once
  frames(3)
  @test length(asks) == 1
  @test button(v, :refresh).words == "Refresh" && !button(v, :refresh).off
  shot("load-server.png")
  # Refresh asks again. This time the server sends CSV, and that copy takes the place of the JSON one.
  answer(200, "text/csv", "id,total\nS9,5\n")
  click(middle(button(v, :refresh).rect)); frames(3)
  @test length(asks) == 2 && shown(v) == [["id", "total"], ["S9", "5"]]
  stem = K.load_stem("https://api.example.com/orders")
  @test isfile(stem * ".csv") && !isfile(stem * ".json")
  # A save block under it saves those rows, and names its file after the server
  s = show_block(K.SAVE, 1)
  d = K.save_data(s)
  @test d.name == "api.example.com" && d.rows == [["id", "total"], ["S9", "5"]] && K.save_start(d) == "api.example.com.csv"
  @test K.save_name(view(K.LOAD, 2)) == "api.example.com.csv"
end

@testset "when the server says no, the last rows stay" begin
  v = view(K.LOAD, 2)
  answer(503, "text/plain", "Down for a bit")
  click(middle(button(v, :refresh).rect)); frames(3)
  @test startswith(v.said, "The server at api.example.com said 503 Service Unavailable: Down for a bit. These are the rows that came at ")
  @test v.failed && shown(v) == [["id", "total"], ["S9", "5"]]
  answer(0, "", ""; error="curl: (6) Could not resolve host: api.example.com\n")
  click(middle(button(v, :refresh).rect)); frames(3)
  @test startswith(v.said, "Ladder couldn't reach api.example.com: Could not resolve host: api.example.com. These are the rows that came at ")
  shot("load-failed.png")
end

@testset "a key from the Keychain" begin
  v = view(K.LOAD, 2)
  # A new key line: the block asks again, once the lines have stayed the same for a moment
  answer(0, "", ""; nokey=true)
  K.write_block!(v, K.LOAD, ["from: https://api.example.com/orders", "key: shop"])
  frames(3)
  n = length(asks)
  v.changed = time() - 2K.LOAD_WAIT
  frames(3)
  @test length(asks) == n + 1 && asks[end].key == "shop"
  @test v.nokey && v.said == "Your Keychain has no key called “shop”. Add it, and Ladder loads the rows."
  @test button(v, :key).words == "Add Key…"
  shot("load-no-key.png")
  # A key that's given goes into the Keychain, and the block asks again
  kept = []
  K.KEY_KEEPER[] = (name, key) -> (push!(kept, (name, key)); true)
  answer(200, "application/json", """[{"id": "K1", "total": 1}]""")
  K.key_given!(v, "s3cret"); frames(3)
  @test kept == [("shop", "s3cret")] && !v.nokey && asks[end].key == "shop"
  @test shown(v) == [["id", "total"], ["K1", "1"]]
end

@testset "a new address is asked once it stays the same" begin
  v = view(K.LOAD, 2)
  n = length(asks)
  answer(200, "application/json", """[{"id": "V2"}]""")
  K.write_block!(v, K.LOAD, ["from: https://api.example.com/v2", "key: shop"])
  frames(3)
  @test length(asks) == n
  v.changed = time() - 2K.LOAD_WAIT
  frames(3)
  @test length(asks) == n + 1 && asks[end].url == "https://api.example.com/v2" && shown(v) == [["id"], ["V2"]]
end

@testset "what a load block won't do" begin
  n = length(asks)
  v = show_block(K.LOAD, 3)
  frames(3)
  # A key over http: the block says why, and asks nothing
  @test occursin("https://", K.load_note(v)) && button(v, :refresh).off && length(asks) == n
  # A filter doesn't ask servers
  @test occursin("write load in place of filter", K.filter_shown!(show_block(K.FILTER, 2)).data.problem)
  # A load block with no `from` says what to write
  @test startswith(K.filter_shown!(show_block(K.LOAD, 4)).data.problem, "Name a file or a web address")
  shot("load-problems.png")
end

@testset "a load block as HTML" begin
  @test startswith(K.filter_html(e, view(K.LOAD, 1)), "<table>\n<caption>orders.json: 4 rows")
end

finally
  K.LOAD_GETTER[] = K.get_rows
  K.KEY_KEEPER[] = K.keep_key
  K.LOAD_CACHE[] = ""
end
