# Tests for the work that names a contact, in main.jl: under the details of a
# contact, its card lists the to-do items that name the contact, in this page
# and in the other pages of its folder. Run them with
# `julia -O0 --project=. test/contact_work_test.jl`. They click in a window
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

@testset "the words that name a contact" begin
  person = K.Contacts.contacts(["Mei Tanaka", "role: Site manager"])[1]
  firm = K.Contacts.contacts(["Harbour Builders", "kind: company"])[1]
  @test K.contact_names(person) == ["Mei Tanaka", "Mei"] && K.contact_names(firm) == ["Harbour Builders"]
  @test K.contact_names(K.Contacts.contacts(["Al Wu"])[1]) == ["Al Wu"] && isempty(K.contact_names(K.Contacts.Contact()))
  @test K.names_one("Ring Mei about the tiles", ["Mei Tanaka", "Mei"]) && K.names_one("ask MEI.", ["Mei"]) && K.names_one("Mei", ["Mei"])
  # Part of another word names nobody
  @test !K.names_one("Do it sometime in May", ["Mei"]) && !K.names_one("the same again", ["Sam"]) && !K.names_one("Meier's quote", ["Mei"])
  @test K.names_one("Pay Harbour Builders", ["Harbour Builders"]) && !K.names_one("Pay the builders at the harbour", ["Harbour Builders"])
end

const dir = mktempdir()
const page = joinpath(dir, "job.md")
mkdir(joinpath(dir, "jobs"))
write(joinpath(dir, "jobs", "shed.md"), "# The shed\n\n- [ ] Send Mei the plan of the shed\n- [x] Ring Mei about the slab\n- [ ] Order the door\n")
write(page, """
# A job

- [ ] Ring Mei about the tiles
- [x] Meet Mei Tanaka on site
- [ ] Pay Harbour Builders
- [ ] Do the same again
- Mei has the key

```contact
Mei Tanaka
role: Site manager

Harbour Builders
kind: company

Sam Okoro
```

```board
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, press, release, shot) = drive(w, moved=2, pressed=1)
frames()
const v = e.nodes[(:block, K.CONTACT, page, 1)]
const board = e.nodes[(:block, K.BOARD, page, 1)]
work(k) = [(m.text, relpath(m.path, dir)) for m in K.contact_work(v, k)]

@testset "a card lists the to-do items that name its contact" begin
  # The items of this page and of the pages under its folder that aren't ticked. A line that's no to-do item isn't one.
  @test work(1) == [("Ring Mei about the tiles", "job.md"), ("Send Mei the plan of the shed", "jobs/shed.md")]
  @test work(2) == [("Pay Harbour Builders", "job.md")] && work(3) == []
  rows = [v.parts[(:work_row, 1, i)] for i in 1:2]
  @test all(r -> rect(r) !== nothing, rows) && rect(rows[1]).top < rect(rows[2]).top
  # The card of a contact with items is taller than the card of a contact with none
  card(k) = rect(v.parts[(:card, k)])
  @test card(1).height > card(3).height + 30px
  shot("contact-work.png")
end

@testset "the page changes, and the card with it" begin
  K.tick!(e, findfirst(==("- [ ] Ring Mei about the tiles"), e.buf.lines)); frames()
  @test work(1) == [("Send Mei the plan of the shed", "jobs/shed.md")]
  K.undo!(e.buf); frames()
  i = findfirst(==("- [ ] Do the same again"), e.buf.lines)
  K.edit!(e.buf, (i, 0), K.line_end(e.buf, i), "- [ ] Ask Sam Okoro for the keys"); frames()
  @test work(3) == [("Ask Sam Okoro for the keys", "job.md")]
end

@testset "the mouse on an item marks it, and a click goes to it" begin
  at(middle(rect(v.parts[(:work_row, 1, 1)])))
  @test K.pointed(v) == "Ring Mei about the tiles" && K.marked(board, "Ring Mei about the tiles")
  press(middle(rect(v.parts[(:work_row, 1, 1)]))); release()
  @test e.buf.path == page && e.buf.caret[1] == findfirst(==("- [ ] Ring Mei about the tiles"), e.buf.lines)
  # An item of another page opens that page at the item
  press(middle(rect(v.parts[(:work_row, 1, 2)]))); release()
  @test e.buf.path == joinpath(dir, "jobs", "shed.md") && e.buf.lines[e.buf.caret[1]] == "- [ ] Send Mei the plan of the shed"
end

close(w)
