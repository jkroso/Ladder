# Tests for the `save` block of save_view.jl, which writes the rows of the
# table above it into a file, or sends them to a server. Run them with
# `julia -O0 --project=. test/save_view_test.jl`. They write files into a
# temporary folder and click in a window that isn't on the screen. A send
# goes to a server in this process, or to a function that stands in for one,
# and no key goes into the Keychain. Set `LADDER_SHOTS` to a
# folder, and they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use Sockets
@use "./drive" drive
const px = K.px

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); write(path, text); path)

file("orders.json", """
{"data": {"orders": [
  {"id": "A1", "status": "shipped", "total": 250, "customer": {"name": "Ann", "city": "Sydney"}},
  {"id": "A2", "status": "packed", "total": 80.5, "customer": {"name": "Bob", "city": "Perth"}},
  {"id": "A3", "status": "shipped", "total": 1200, "customer": {"name": "Cy", "city": "Sydney"}}
]}}
""")
file("notes.md", "# Notes\n")

const page = joinpath(dir, "costs.md")
write(page, """
# Costs

| Item | Supplier | Cost |
|---|---|---|
| Sand | The yard | 120 |
| Pipe | Plumbco | 45.50 |
| Gravel | The yard | 80 |

```save
to: costs out.csv
```

## Yard

```filter
where: Supplier is The yard
```

```save
to: yard.json
```

## Orders

```filter
from: orders.json
where: total > 100
```

```save
to: https://api.example.com/orders
key: shop
```

```save
to: big.json
```

## Ids

```filter
from: orders.json
show: id, total
```

```save
to: ids.txt
as: json
```

```save
to: orders.json
```

```save
to: costs.md
```

```save
to: nowhere/rows.csv
```

```save
from: Nothing here
to: a.csv
```

```save
to: notes.md
```

```save
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1100px))
const (; frames, at, press, release, click, shot) = drive(w)
frames()

middle(r) = (K.num(r[1] + r[3] / 2), K.num(r[2] + r[4] / 2))
view(n) = e.nodes[(:block, K.SAVE, page, n)]
"Scroll the page until the top of the `n`th save block is near the top of the window, and it has been laid out and drawn"
show_save(n) = begin
  s = K.block_lines(e.buf, K.SAVE, n)
  K.show_line!(e, s[2] + 1); frames(2)
  e.scroll.offset = max(0px, K.item(e, s[1]).top - 40px); frames(3)
  view(n)
end
button(v, key=:go) = v.parts[(:button, key)]
"What the line under the top of `v` says"
note(v) = (d = K.save_data(v); p = K.save_problem(v, d); !isempty(p) ? p : isempty(v.said) ? K.save_plan(v, d) : v.said)
json(path) = K.json_value(read(path))
field(o, name) = o.values[findfirst(==(name), o.keys)]

@testset "the table above is saved into a file" begin
  v = show_save(1)
  d = K.save_data(v)
  @test d.name == "Costs"
  @test d.rows == [["Item", "Supplier", "Cost"], ["Sand", "The yard", "120"], ["Pipe", "Plumbco", "45.50"], ["Gravel", "The yard", "80"]]
  @test note(v) == "A click writes the 3 rows into a new file, costs out.csv, as CSV."
  @test button(v).words == "Save" && !button(v).off
  shot("save-file.png")
  click(middle(button(v).rect))
  out = joinpath(dir, "costs out.csv")
  @test read(out, String) == "Item,Supplier,Cost\nSand,The yard,120\nPipe,Plumbco,45.50\nGravel,The yard,80\n"
  @test startswith(v.said, "Saved 3 rows to costs out.csv at ") && !v.failed
  @test !isfile(out * ".part")
  # The file is there now, so a click replaces it
  @test button(v).words == "Replace"
  shot("save-saved.png")
end

@testset "a filter's rows, as JSON" begin
  v = show_save(2)
  @test K.save_data(v).name == "Yard"
  click(middle(button(v).rect))
  rows = json(joinpath(dir, "yard.json"))
  # Each row is an object, and a column of numbers has numbers
  @test length(rows) == 2 && rows[1].keys == ["Item", "Supplier", "Cost"]
  @test field(rows[1], "Item") == "Sand" && field(rows[1], "Cost") isa K.JSONNumber && field(rows[1], "Cost").text == "120"
  # A filter of a JSON file that hides no column saves each thing whole
  v = show_save(4)
  @test K.save_data(v).name == "orders.json"
  click(middle(button(v).rect))
  big = json(joinpath(dir, "big.json"))
  @test [field(o, "id") for o in big] == ["A1", "A3"]
  @test field(field(big[2], "customer"), "city") == "Sydney"
  # When it hides some, only the columns that show go
  v = show_save(5)
  click(middle(button(v).rect))
  ids = json(joinpath(dir, "ids.txt"))
  @test length(ids) == 3 && ids[2].keys == ["id", "total"] && field(ids[2], "total").text == "80.5"
end

@testset "what the block won't do" begin
  # The file that the rows come from, this page, a folder that isn't there, and a heading that isn't there
  @test occursin("come from orders.json", note(show_save(6)))
  @test note(show_save(7)) == "costs.md is this page. Name another file."
  @test occursin("no folder called nowhere", note(show_save(8)))
  @test note(show_save(9)) == "This page has no table called “Nothing here”, and no file of that name beside it."
  v = show_save(10)
  @test occursin("Ladder replaces only a CSV, TSV, JSON or text file", note(v))
  @test button(v).off
  click(middle(button(v).rect))
  @test read(joinpath(dir, "notes.md"), String) == "# Notes\n"
  shot("save-problem.png")
  # Without `to`, the block lists folders and asks for a name: see save_picker_test.jl
  v = show_save(11)
  @test K.asks_where(v) && button(v).words == "Save" && K.save_name_field(v).text == "orders (saved).csv"
end

@testset "rows go to a server" begin
  sent = []
  answers = []
  # It stands in for curl: it notes what it was asked, and its send ends at the second look
  K.SAVE_SENDER[] = (url, method, type, body, key) -> begin
    push!(sent, (url=url, method=method, type=type, body=read(body, String), key=key))
    rm(body)
    looks = Ref(0)
    () -> (looks[] += 1) < 2 ? nothing : popfirst!(answers)
  end
  try
    v = show_save(3)
    @test note(v) == "A click sends the 2 rows to https://api.example.com/orders as JSON, with POST, and the key “shop” from your Keychain."
    @test button(v).words == "Send"
    push!(answers, (nokey=false, code=201, body="", error=""))
    click(middle(button(v).rect))
    @test length(sent) == 1 && sent[1].url == "https://api.example.com/orders" && sent[1].method == "POST"
    @test sent[1].type == "application/json" && sent[1].key == "shop"
    @test [field(o, "id") for o in K.json_value(Vector{UInt8}(sent[1].body))] == ["A1", "A3"]
    frames(3)
    @test v.job === nothing && startswith(v.said, "Sent 2 rows to api.example.com at ") && endswith(v.said, "The server said 201 Created.")
    # A server that says no, and what it said
    push!(answers, (nokey=false, code=401, body="{\"error\": {\"message\": \"That key has run out\"}}", error=""))
    click(middle(button(v).rect)); frames(3)
    @test v.said == "The server at api.example.com said 401 Unauthorized: That key has run out" && v.failed
    push!(answers, (nokey=false, code=0, body="", error="curl: (6) Could not resolve host: api.example.com\n"))
    click(middle(button(v).rect)); frames(3)
    @test v.said == "Ladder couldn't reach api.example.com: Could not resolve host: api.example.com"
    # No key in the Keychain: a button asks for it
    push!(answers, (nokey=true, code=0, body="", error=""))
    click(middle(button(v).rect)); frames(3)
    @test v.nokey && v.said == "Your Keychain has no key called “shop”. Add it, and click Send again."
    @test haskey(v.parts, (:button, :key)) && button(v, :key).words == "Add Key…"
    shot("save-no-key.png")
    kept = []
    K.KEY_KEEPER[] = (name, key) -> (push!(kept, (name, key)); true)
    K.key_given!(v, "s3cret")
    @test kept == [("shop", "s3cret")] && !v.nokey && !v.failed
    # A new `to` is a new block, so what was said about the old one goes
    K.write_block!(v, K.SAVE, ["to: https://api.example.com/v2/orders", "key: shop"])
    @test v.said == "" && occursin("v2/orders", note(v))
  finally
    K.SAVE_SENDER[] = K.send_rows
    K.KEY_KEEPER[] = K.keep_key
  end
end

@testset "curl sends the rows, and a key that the Keychain lacks stops the send" begin
  # A server in this process that keeps the request it gets, and says 201
  port, server = Sockets.listenany(Sockets.ip"127.0.0.1", 18_000)
  got = Ref("")
  task = @async begin
    sock = Sockets.accept(server)
    text = ""
    while !occursin("\r\n\r\n", text) || length(codeunits(text)) < findfirst("\r\n\r\n", text)[end] + parse(Int, match(r"Content-Length: (\d+)"i, text)[1])
      text *= String(readavailable(sock))
    end
    got[] = text
    write(sock, "HTTP/1.1 201 Created\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
    close(sock)
  end
  body = tempname(); write(body, "[1, 2]")
  job = K.send_rows("http://127.0.0.1:$port/rows", "PUT", "application/json", body, "")
  heard = nothing
  for _ in 1:300
    heard = job(); heard === nothing || break
    sleep(0.05)
  end
  close(server)
  @test heard !== nothing && heard.code == 201 && heard.body == "ok" && !heard.nokey
  @test startswith(got[], "PUT /rows HTTP/1.1") && occursin("Content-Type: application/json", got[]) && endswith(got[], "[1, 2]")
  @test !occursin("Authorization", got[]) && !isfile(body)
  # A key that the Keychain doesn't have: curl isn't run
  body = tempname(); write(body, "[]")
  job = K.send_rows("http://127.0.0.1:1/rows", "POST", "application/json", body, "ladder-test-no-such-key-$(rand(UInt32))")
  heard = nothing
  for _ in 1:300
    heard = job(); heard === nothing || break
    sleep(0.05)
  end
  @test heard !== nothing && heard.nokey
end

@testset "the block as HTML" begin
  @test K.save_html(e, view(1)) == "<p><em>Saves the 3 rows of Costs to costs out.csv.</em></p>"
end
