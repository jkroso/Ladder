# Tests for the `contact` block of main.jl: a card for a person or a company.
# Run them with `julia -O0 --project=. test/contact_view_test.jl`. They click
# and type in windows that aren't on the screen. A function of the test takes
# the place of the browser, so nothing opens. Another takes the place of the
# web, and the Mac's clipboard is left as it is. Set `LADDER_SHOTS` to a
# folder, and they save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype onfiledrop
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups clipboard
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc sel nsstring
@use "github.com/jkroso/UI.jl/Interface/save" save_png save_scene
@use GeometryBasics: Vec2
const px = K.px
const C = K.Contacts

# What the block opens goes here, and nowhere else
const opened = String[]
K.BROWSER[] = to -> (push!(opened, to); nothing)
# ⌘V reads a clipboard that only this test uses
const board = K.Pasteboard.private_board()
K.Pasteboard.other[] = board

const dir = mktempdir()
const page = joinpath(dir, "people.md")
# The pretend web, for a photo that has a web address: what it has at each address, the addresses
# that were asked for, and whether it has answered yet. What comes from it is kept in the test's own folder.
K.MEDIA_CACHE[] = joinpath(dir, "cache")
const web = Dict{String,Vector{UInt8}}()
const asked = String[]
const arrived = Ref(false)
K.Cards.getter[] = (url, file, most) -> begin
  push!(asked, url)
  haskey(web, url) && write(file, first(web[url], most))
  () -> arrived[]
end
# A picture for the photo of a contact. It's wider than it's tall, and its middle is blue.
save_scene(joinpath(dir, "ada.png"), K.Row(K.width(120px), K.height(80px), K.Box(K.width(40px), K.height(80px), K.background(K.colorant"rgb(200,90,60)")),
                                           K.Box(K.width(40px), K.height(80px), K.background(K.colorant"rgb(60,120,200)")),
                                           K.Box(K.width(40px), K.height(80px), K.background(K.colorant"rgb(200,90,60)"))), (120px, 80px))
write(page, """
# People

```contact
Ada Lovelace
role: Engineer
company: Analytical Engines
email: ada@example.com
mobile: 0400 123 456
address: 12 Example St, Sydney NSW 2000
web: example.com
note: Met at the 2026 conference.
ABN: 12 345 678 901
```

Some words between.

```contact
Analytical Engines
kind: company
email: hello@example.com

Charles Babbage
photo: ada.png
phone: (02) 9000 0000
```

```contact
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1100px))
frames(n=2, w=w) = foreach(_ -> frame(w), 1:n)
frames()
view(n=1, e=e) = e.nodes[(:block, K.CONTACT, e.buf.path, n)]
shot(name, w=w) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

at((x, y), w=w) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1, w))
press(place, w=w) = (at(place, w); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release(w=w) = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2, w))
click(place, w=w) = (press(place, w); release(w))
"Two clicks in one place, one soon after the other"
twice(place, w=w) = (click(place, w); click(place, w))
"Wait until a click on a row is known to have no second click, and draw"
wait(w=w) = (sleep(K.CONTACT_WAIT + 0.1); frames(2, w))
key(k, held...; w=w) = (foreach(h -> w.keys |= h, held); onkey(w, KeyPress{k}(0, w)); foreach(h -> w.keys ⊻= h, held); frames(2, w))
typed(s, w=w) = (foreach(c -> ontype(w, Typed(c, w)), s); frames(2, w))
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
"The lines of the `n`th block of contacts of the page that `e` shows"
block(n=1, e=e) = (s = K.block_lines(e.buf, K.CONTACT, n); e.buf.lines[s[1]+1:s[2]-1])
"A part of a block, and where it was last drawn"
part(v, key...) = v.parts[key]
spot(v, key...) = middle(rect(part(v, key...)))
"True when a part of a block was drawn in the last frame"
shows(v, key...) = haskey(v.parts, key) && rect(v.parts[key]) !== nothing
"Every piece of text that a node shows"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.SemanticUI ? texts(K.describe(node), out) :
  node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
"Where the first words that were drawn in `r` are: the left, the top, how wide and how tall. With `words`, the first ones that say that."
words_at(r, words=nothing) = begin
  r isa K.ConcreteText && (words === nothing || r.from.content == words) && return round.(K.num.((r.left, r.top, r.width, r.height)), digits=1)
  r isa K.ConcreteRect || return nothing
  for child in r.children
    found = words_at(child, words)
    found === nothing || return found
  end
  nothing
end
"The line of the first contact of the block that starts with `words`"
line(v, words, k=1) = findfirst(d -> startswith(d.text, words), v.data[k].lines)
menu() = any(p -> p.key == :menu, popups(w))
tip() = any(p -> p.key == :tooltip, popups(w))

@testset "the block shows a card for each contact" begin
  v, u, n = view(1), view(2), view(3)
  @test length(v.data) == 1 && length(u.data) == 2 && isempty(n.data)
  said = texts(v)
  @test all(t -> t in said, ["Ada Lovelace", "Engineer", ",", "Analytical Engines", "ada@example.com", "mobile", "0400 123 456",
                             "12 Example St, Sydney NSW 2000", "example.com", "Met at the 2026 conference.", "ABN", "12 345 678 901", "AL"])
  # The card is 420 px wide at the usual size of the text, and each of its parts is inside it
  card = rect(part(v, :card, 1))
  @test card.width ≈ 420px && card.left ≈ rect(v).left
  for key in keys(v.parts)
    r = rect(v.parts[key])
    (r === nothing || key == :edit) && continue
    @test card.left <= r.left && r.left + r.width <= card.left + card.width + 0.5px
  end
  # The round picture is at the left, and the name is beside it
  face, name = rect(part(v, :face, 1)), rect(part(v, :words, 1, :name))
  @test face.width ≈ 44px && face.height ≈ 44px && name.left > face.left + face.width && name.top < face.top + face.height
  # A company has a building for its picture, and no line under its name. Its kind is no row.
  @test "Analytical Engines" in texts(u) && !("kind" in texts(u)) && !("company" in texts(u)) && C.iscompany(u.data[1])
  @test rect(part(u, :card, 2)).top > rect(part(u, :card, 1)).top + rect(part(u, :card, 1)).height
  # A contact with a photo shows it, and has no initials
  @test !isempty(part(u, :face, 2).key) && !("CB" in texts(u)) && isempty(part(u, :face, 1).key)
  # A block with nothing in it shows a card with a place for a name
  @test "Name" in texts(n) && shows(n, :card, 1)
  @test any(en -> en.title == "Contact", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Contact", K.INSERTS)
  @test K.Searches.block_kind(K.CONTACT) == :contact
  @test !K.dirty(e.buf) && isempty(opened)
  shot("contact.png")
end

@testset "a click on a row uses it" begin
  v = view()
  for (words, to) in [("email", "mailto:ada@example.com"), ("mobile", "tel:0400123456"),
                      ("address", "maps://?q=12%20Example%20St%2C%20Sydney%20NSW%202000"), ("web", "https://example.com")]
    row = part(v, :row, 1, line(v, words))
    at(middle(rect(row)))
    @test K.cursor(row) == :hand
    click(middle(rect(row)))
    # It waits to know that no second click comes
    @test isempty(opened)
    wait()
    @test opened == [to]
    empty!(opened)
  end
  # A note and a line with another label open nothing
  for words in ("note", "ABN")
    row = part(v, :row, 1, line(v, words))
    @test K.cursor(row) == :arrow
    click(middle(rect(row))); wait()
  end
  @test isempty(opened) && !K.dirty(e.buf) && w.focus === e
end

@testset "the button of a row copies its value" begin
  v = view()
  i = line(v, "email")
  @test !shows(v, :button, (:copy, 1, i))
  at(spot(v, :row, 1, i)); frames()
  @test shows(v, :button, (:copy, 1, i)) && !shows(v, :button, (:copy, 1, line(v, "mobile")))
  b = part(v, :button, (:copy, 1, i))
  # It's at the right end of the row
  @test rect(b).left > rect(part(v, :row, 1, i)).left + 300px
  at(middle(rect(b))); frames()
  @test tip() && b.tip == "Copy the email address"
  shot("contact-copy.png")
  click(middle(rect(b)))
  @test clipboard(w) == "ada@example.com" && isempty(opened) && b.icon == "check"
  wait()
  @test isempty(opened)   # the click on the button isn't a click on the row
  at(spot(v, :row, 1, line(v, "ABN"))); frames()
  click(spot(v, :button, (:copy, 1, line(v, "ABN"))))
  @test clipboard(w) == "12 345 678 901" && part(v, :button, (:copy, 1, line(v, "ABN"))).tip == "Copy this"
end

@testset "two clicks change words where they are" begin
  v = view()
  i = line(v, "email")
  row = part(v, :row, 1, i)
  before = rect(row)
  was = words_at(before, "ada@example.com")
  twice(middle(before))
  field = K.contact_input(v)
  @test v.editing == (1, i) && w.focus === field && field.text == "ada@example.com" && isempty(opened)
  # The row is where it was, and as tall. The words in the field are where the row's words were, and as big.
  @test rect(row).top == before.top && rect(row).height == before.height
  @test words_at(rect(field)) == was
  shot("contact-editing.png")
  # The value was selected, so what's typed takes its place. Return keeps it.
  typed("ada@example.org"); key(Keys.enter)
  @test block()[4] == "email: ada@example.org" && v.editing === nothing && w.focus === e && K.dirty(e.buf)
  wait()
  @test isempty(opened)   # two clicks don't open the row
  # Esc leaves the words as they were
  twice(spot(v, :row, 1, line(v, "mobile")))
  typed("nothing"); key(Keys.escape)
  @test block()[5] == "mobile: 0400 123 456" && v.editing === nothing && w.focus === e
  # A click somewhere else keeps the change
  twice(spot(v, :row, 1, line(v, "note")))
  typed("Met in Sydney.")
  click((900, 1000))
  @test block()[8] == "note: Met in Sydney." && v.editing === nothing
  # A click on another row keeps the change too, and opens nothing
  twice(spot(v, :row, 1, line(v, "note")))
  typed("Met in Perth.")
  click(spot(v, :row, 1, line(v, "email"))); wait()
  @test block()[8] == "note: Met in Perth." && v.editing === nothing && isempty(opened) && w.focus === e
  K.undo!(e.buf); frames()
  # The name, the role and the company
  named = words_at(rect(part(v, :words, 1, :name)))
  twice(spot(v, :words, 1, :name))
  @test v.editing == (1, :name) && field.text == "Ada Lovelace"
  # The name starts where it did, and is as tall. It's in the regular weight while it's changed, so it's narrower.
  @test words_at(rect(field))[[1, 2, 4]] == named[[1, 2, 4]]
  typed("Ada King"); key(Keys.enter)
  role = words_at(rect(part(v, :words, 1, 2)))
  twice(spot(v, :words, 1, 2))
  @test field.text == "Engineer" && words_at(rect(field)) == role
  shot("contact-editing-role.png")
  typed("Mathematician"); key(Keys.enter)
  twice(spot(v, :words, 1, 3)); typed("Engines Pty Ltd"); key(Keys.enter)
  @test block()[1:3] == ["Ada King", "role: Mathematician", "company: Engines Pty Ltd"]
  # An emptied value takes its line out of the block
  twice(spot(v, :row, 1, line(v, "ABN")))
  key(Keys.backspace); key(Keys.enter)
  @test length(block()) == 8 && !any(l -> startswith(l, "ABN"), block())
  # Each change is one step for ⌘Z
  K.undo!(e.buf); frames()
  @test block()[end] == "ABN: 12 345 678 901"
  K.undo!(e.buf); K.undo!(e.buf); K.undo!(e.buf); frames()
  @test block()[1:3] == ["Ada Lovelace", "role: Engineer", "company: Analytical Engines"] && block()[8] == "note: Met in Sydney."
  K.undo!(e.buf); K.undo!(e.buf); frames()
  @test block()[4] == "email: ada@example.com" && block()[8] == "note: Met at the 2026 conference." && !K.dirty(e.buf)
  # A click with ⌥ held shows the lines of the block, and opens nothing
  w.keys |= Keys.opt; click(spot(v, :row, 1, line(v, "email"))); w.keys ⊻= Keys.opt
  wait()
  @test v.first < e.buf.caret[1] <= v.last && isempty(opened) && v.editing === nothing
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  # When the lines change under words that are being changed, the field goes, and the page has the keyboard again
  twice(spot(v, :row, 1, line(v, "email"))); typed("x@example.com"); key(Keys.enter)
  twice(spot(v, :row, 1, line(v, "email")))
  K.undo!(e.buf); frames(3)
  @test v.editing === nothing && w.focus === e && block()[4] == "email: ada@example.com"
end

@testset "the + adds a detail" begin
  v = view()
  at((900, 1000)); frames()
  @test !shows(v, :button, (:more, 1)) && !shows(v, :button, (:keep, 1))
  at(spot(v, :face, 1)); frames()
  @test shows(v, :button, (:more, 1)) && shows(v, :button, (:keep, 1))
  at(spot(v, :button, (:more, 1))); frames()
  @test tip() && part(v, :button, (:more, 1)).tip == "Add a detail"
  click(spot(v, :button, (:more, 1)))
  @test menu() && v.menu == 1
  shot("contact-menu.png")
  # Phone is the second of Email, Phone, Address, Website and Note
  key(Keys.down); key(Keys.down); key(Keys.enter)
  field = K.contact_input(v)
  @test !menu() && v.editing == (1, :phone) && w.focus === field && field.placeholder == "Phone" && length(block()) == 9
  shot("contact-adding.png")
  typed("02 9000 1111"); key(Keys.enter)
  @test block()[end] == "phone: 02 9000 1111" && length(block()) == 10 && w.focus === e
  # One ⌘Z takes the new line back
  K.undo!(e.buf); frames()
  @test length(block()) == 9 && !K.dirty(e.buf)
  # A detail with nothing typed adds no line
  at(spot(v, :face, 1)); frames()
  click(spot(v, :button, (:more, 1)))
  key(Keys.down); key(Keys.enter)
  @test v.editing == (1, :email)
  key(Keys.enter)
  @test length(block()) == 9 && v.editing === nothing && !K.dirty(e.buf)
  # Esc closes the menu, and adds nothing
  at(spot(v, :face, 1)); frames()
  click(spot(v, :button, (:more, 1)))
  key(Keys.escape)
  @test !menu() && v.editing === nothing && v.menu == 0
end

@testset "a contact goes to the Contacts app as a vCard file" begin
  v = view()
  at(spot(v, :face, 1)); frames()
  at(spot(v, :button, (:keep, 1))); frames()
  @test tip() && part(v, :button, (:keep, 1)).tip == "Add to Contacts"
  click(spot(v, :button, (:keep, 1)))
  @test length(opened) == 1 && endswith(opened[1], "/Ada Lovelace.vcf") && isfile(opened[1])
  card = read(opened[1], String)
  @test startswith(card, "BEGIN:VCARD\r\nVERSION:3.0\r\nN:Lovelace;Ada;;;\r\nFN:Ada Lovelace\r\n") && occursin("EMAIL;TYPE=INTERNET:ada@example.com\r\n", card)
  @test !K.dirty(e.buf)
  empty!(opened)
  # A company's vCard says that it's a company, and only that contact is in the file
  u = view(2)
  at(spot(u, :face, 1)); frames()
  click(spot(u, :button, (:keep, 1)))
  card = read(only(opened), String)
  @test occursin("X-ABShowAs:COMPANY\r\n", card) && occursin("FN:Analytical Engines\r\n", card) && !occursin("Babbage", card)
  # The photo is left out
  at(spot(u, :face, 2)); frames()
  click(spot(u, :button, (:keep, 2)))
  @test occursin("FN:Charles Babbage", read(opened[2], String)) && !occursin("ada.png", read(opened[2], String))
  empty!(opened)
end

@testset "a block with several contacts" begin
  u = view(2)
  at((900, 1000)); frames()
  # A change writes only the lines of its own contact
  twice(spot(u, :row, 2, 3)); typed("(02) 9000 1234"); key(Keys.enter)
  @test block(2) == ["Analytical Engines", "kind: company", "email: hello@example.com", "", "Charles Babbage", "photo: ada.png", "phone: (02) 9000 1234"]
  click(spot(u, :row, 1, 3)); wait()
  @test opened == ["mailto:hello@example.com"]
  empty!(opened)
  # The button under the last card adds a contact, and starts on its name
  at((900, 1000)); frames()
  @test !shows(u, :button, (:new,))
  at(spot(u, :face, 2)); frames()
  @test shows(u, :button, (:new,)) && rect(part(u, :button, (:new,))).top >= rect(part(u, :card, 2)).top + rect(part(u, :card, 2)).height
  at(spot(u, :button, (:new,))); frames()
  @test tip() && part(u, :button, (:new,)).tip == "Add a contact"
  tall = rect(u).height
  click(spot(u, :button, (:new,)))
  field = K.contact_input(u)
  @test u.editing == (3, :name) && w.focus === field && field.placeholder == "Name" && shows(u, :card, 3) && length(block(2)) == 7
  shot("contact-new.png")
  typed("Grace Hopper"); key(Keys.enter)
  @test block(2)[end-1:end] == ["", "Grace Hopper"] && length(u.data) == 3 && w.focus === e
  # The new contact takes a detail
  at(spot(u, :face, 3)); frames()
  click(spot(u, :button, (:more, 3))); key(Keys.down); key(Keys.enter)
  typed("grace@example.com"); key(Keys.enter)
  @test block(2)[end-2:end] == ["", "Grace Hopper", "email: grace@example.com"]
  shot("contact-several.png")
  # A contact whose lines all go leaves the block, with the empty line before it
  twice(spot(u, :row, 3, 2)); key(Keys.backspace); key(Keys.enter)
  twice(spot(u, :words, 3, :name)); key(Keys.backspace); key(Keys.enter)
  @test length(u.data) == 2 && block(2)[end] == "phone: (02) 9000 1234" && length(block(2)) == 7
  # A new contact with no name typed adds nothing
  at(spot(u, :face, 2)); frames()
  click(spot(u, :button, (:new,))); key(Keys.escape)
  @test length(block(2)) == 7 && u.editing === nothing && !shows(u, :card, 3)
  # ⌘Z takes each change back
  foreach(_ -> K.undo!(e.buf), 1:5); frames()
  @test block(2)[end] == "phone: (02) 9000 0000" && length(u.data) == 2 && !K.dirty(e.buf)
end

@testset "a block with nothing in it takes a name" begin
  n = view(3)
  # One click on the place for the name starts on it
  click(spot(n, :words, 1, :name))
  field = K.contact_input(n)
  @test n.editing == (1, :name) && w.focus === field && field.placeholder == "Name"
  shot("contact-empty.png")
  typed("Jo Ng"); key(Keys.enter)
  @test block(3) == ["Jo Ng"] && "JN" in texts(n) && w.focus === e
  K.undo!(e.buf); frames()
  @test isempty(block(3)) && "Name" in texts(n)
  # A detail can come before the name
  at(spot(n, :face, 1)); frames()
  @test shows(n, :button, (:more, 1)) && !shows(n, :button, (:keep, 1)) && !shows(n, :button, (:new,))
  click(spot(n, :button, (:more, 1))); key(Keys.down); key(Keys.enter)
  typed("jo@example.com"); key(Keys.enter)
  @test block(3) == ["email: jo@example.com"] && "Name" in texts(n)
  K.undo!(e.buf); frames()
  # The keyboard alone: the caret on the block as a whole, then Return, starts on the name
  s = K.block_lines(e.buf, K.CONTACT, 3)
  e.buf.caret = e.buf.anchor = (s[1], 0); frames()
  @test K.picked(e.buf) !== nothing
  key(Keys.enter)
  @test w.focus === field && n.editing == (1, :name)
  typed("Sam Lee"); key(Keys.enter)
  @test block(3) == ["Sam Lee"] && w.focus === e
  K.undo!(e.buf); frames()
  @test isempty(block(3)) && !K.dirty(e.buf)
  e.buf.caret = e.buf.anchor = (1, 0); frames()
end

@testset "the page as HTML and on paper" begin
  html = K.page_html(e)
  @test count("class=\"h-card\"", html) == 3 && !occursin("```contact", html)
  # Printing draws the page for paper, with no buttons, and leaves the window as it was
  at(spot(view(), :face, 1)); frames()
  @test length(K.print_pdf(e)) > 1000
  frames()
  @test shows(view(), :button, (:more, 1))
end

@testset "the dark page" begin
  light = K.colours.block
  e.theme = :night; K.restyle!(e); frames()
  at(spot(view(), :row, 1, 4)); frames()
  # The card has the colours of the page
  @test K.dark_page() && K.colours.block != light && "Ada Lovelace" in texts(view())
  shot("contact-night.png")
  twice(spot(view(), :words, 1, :name))
  shot("contact-night-editing.png")
  key(Keys.escape)
  e.theme = :sepia; K.restyle!(e); frames()
  at((900, 1000))
end

@testset "a page whose text is bigger" begin
  v = view()
  K.text_size!(e, 26); frames(3)
  card, face = rect(part(v, :card, 1)), rect(part(v, :face, 1))
  @test e.zoom > 1.4 && card.width ≈ 420px * e.zoom && face.width ≈ 44px * e.zoom
  shot("contact-zoomed.png")
  K.text_size!(e, 17); frames(3)
  @test rect(part(v, :card, 1)).width ≈ 420px
end

@testset "a vCard file that's dropped, and a contact that's pasted" begin
  vcf = joinpath(dir, "two.vcf")
  write(vcf, "BEGIN:VCARD\r\nVERSION:3.0\r\nN:Hopper;Grace;;;\r\nFN:Grace Hopper\r\nTEL;type=CELL:0400 555 666\r\nEND:VCARD\r\n" *
             "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Example Pty Ltd\r\nORG:Example Pty Ltd;\r\nX-ABShowAs:COMPANY\r\nEND:VCARD\r\n")
  # On the page's text, the file becomes a block of its contacts under the line that it's dropped on
  i = findfirst(==("Some words between."), e.buf.lines)
  it = K.item(e, i)
  at((K.num(e.origin[1]) + 60, K.num(e.origin[2] + it.top + it.tall / 2)))
  onfiledrop(w, [vcf]); frames()
  @test e.buf.lines[i:i+9] == ["Some words between.", "", "```contact", "Grace Hopper", "mobile: 0400 555 666", "", "Example Pty Ltd", "kind: company", "```", ""]
  @test length(view(2).data) == 2 && C.iscompany(view(2).data[2]) && e.buf.caret == (i + 9, 0)
  shot("contact-dropped.png")
  # One ⌘Z takes the block back
  K.undo!(e.buf); frames()
  @test e.buf.lines[i:i+2] == ["Some words between.", "", "```contact"] && e.buf.lines[i+3] == "Analytical Engines" && !K.dirty(e.buf)
  # On a block of contacts, the contacts join the block
  v = view()
  at(spot(v, :face, 1)); frames()
  onfiledrop(w, [vcf]); frames()
  @test length(v.data) == 3 && block()[end-5:end] == ["", "Grace Hopper", "mobile: 0400 555 666", "", "Example Pty Ltd", "kind: company"]
  K.undo!(e.buf); frames()
  @test length(v.data) == 1 && !K.dirty(e.buf)
  # A file that isn't a vCard goes in as a file does, and a vCard file with no contact in it does too
  bad = joinpath(dir, "none.vcf")
  write(bad, "not a card")
  @test isempty(K.file_contacts(bad)) && isempty(K.file_contacts(joinpath(dir, "ada.png"))) && length(K.file_contacts(vcf)) == 2
  # ⌘V with a contact that was copied in the Contacts app
  put(kind, s) = ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), board, sel("setString:forType:"), nsstring(s), nsstring(kind))
  ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), board, sel("clearContents"))
  put("public.vcard", "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alan Kay\r\nEMAIL;type=INTERNET:alan@example.com\r\nEND:VCARD\r\n")
  put("public.utf8-plain-text", "Alan Kay")
  @test K.Pasteboard.vcard() == "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alan Kay\r\nEMAIL;type=INTERNET:alan@example.com\r\nEND:VCARD\r\n"
  j = findfirst(==("The end."), e.buf.lines)
  e.buf.caret = e.buf.anchor = K.line_end(e.buf, j); frames()
  K.paste!(e); frames()
  @test e.buf.lines[j:j+5] == ["The end.", "", "```contact", "Alan Kay", "email: alan@example.com", "```"] && e.buf.caret[1] == j + 6
  K.undo!(e.buf); frames()
  @test e.buf.lines[j] == "The end." && !any(==("Alan Kay"), e.buf.lines)
  # The text of a vCard is pasted the same way
  ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), board, sel("clearContents"))
  put("public.utf8-plain-text", "BEGIN:VCARD\nFN:Alan Kay\nEND:VCARD\n")
  e.buf.caret = e.buf.anchor = K.line_end(e.buf, j); frames()
  K.paste!(e); frames()
  @test e.buf.lines[j+2:j+4] == ["```contact", "Alan Kay", "```"]
  K.undo!(e.buf); frames()
  # Any other text is pasted as text
  ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), board, sel("clearContents"))
  put("public.utf8-plain-text", "plain words")
  K.paste!(e); frames()
  @test endswith(e.buf.lines[j], "plain words")
  K.undo!(e.buf); frames()
  # In a code block of another language, a vCard is pasted as its text
  code = joinpath(dir, "code.md")
  write(code, "# Code\n\n```julia\nx = 1\n```\n\n```contact\nAda\n```\n")
  e5 = K.build_editor(code)
  e5.buf.caret = e5.buf.anchor = (4, 0)
  @test isempty(K.copied_contacts(e5, "BEGIN:VCARD\nFN:Alan Kay\nEND:VCARD\n"))
  # With the caret in the lines of a block of contacts, the contact joins the block
  e5.buf.caret = e5.buf.anchor = (8, 0)
  list = K.copied_contacts(e5, "BEGIN:VCARD\nFN:Alan Kay\nEND:VCARD\n")
  @test length(list) == 1
  K.paste_contacts!(e5, list)
  @test e5.buf.lines[7:11] == ["```contact", "Ada", "", "Alan Kay", "```"]
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  @test !K.dirty(e.buf)
end

close(w)

@testset "a narrow window" begin
  e2 = K.build_editor(page)
  w2 = Window(e2, size=(300px, 1300px))
  frames(3, w2)
  v = view(1, e2)
  card = rect(part(v, :card, 1))
  # The card is as wide as the page's text, and nothing leaves it
  @test card.width ≈ e2.width && card.width < 300px && card.left + card.width <= 300px
  for key in keys(v.parts)
    r = rect(v.parts[key])
    (r === nothing || key == :edit) && continue
    @test card.left <= r.left && r.left + r.width <= card.left + card.width + 0.5px
  end
  # The address is on more lines than one, and a long email address ends in …
  @test rect(part(v, :row, 1, 6)).height > rect(part(v, :row, 1, 5)).height
  shot("contact-narrow.png", w2)
  close(w2)
end

@testset "a block whose lines are wrong still shows" begin
  wrong = joinpath(dir, "wrong.md")
  write(wrong, """
  # Wrong

  ```contact
  : :
  email:
  kind: nothing
  photo: missing.png
  https://example.com/a/very/long/address/that/has/no/spaces/in/it/and/goes/on/and/on/and/on
  a-very-long-name-with-no-spaces-in-it-that-is-wider-than-any-card-can-be-in-this-window@example.com
  note: $("word "^60)
  ```

  ```contact
  photo: https://example.com/nobody.png
  kind: company
  ```

  ```contact
  """)
  e3 = K.build_editor(wrong)
  w3 = Window(e3, size=(800px, 1000px))
  frames(3, w3)
  v = view(1, e3)
  card = rect(part(v, :card, 1))
  @test card.width ≈ 420px && length(v.data) == 1 && C.title(v.data[1]) == ": :"
  for key in keys(v.parts)
    r = rect(v.parts[key])
    (r === nothing || key == :edit) && continue
    @test card.left <= r.left && r.left + r.width <= card.left + card.width + 0.5px
  end
  # A photo that isn't there, and one that the web doesn't have, leave the head or the building
  arrived[] = true; frames(3, w3)
  @test isempty(part(v, :face, 1).key) && isempty(part(view(2, e3), :face, 1).key)
  shot("contact-wrong.png", w3)
  @test K.page_html(e3) isa String
  close(w3)
end

@testset "a photo from the web comes in the background" begin
  photo = "https://example.com/people/ada.png"
  web[photo] = read(joinpath(@__DIR__, "..", "app", "icon.png"))
  arrived[] = false
  empty!(asked)
  online = joinpath(dir, "online.md")
  write(online, "# Online\n\n```contact\nAda Lovelace\nphoto: $photo\n```\n")
  e6 = K.build_editor(online)
  w6 = Window(e6, size=(800px, 500px))
  frames(3, w6)
  v = view(1, e6)
  # Until the picture has come, the card shows the initials, and the window isn't held up
  @test asked == [photo] && isempty(part(v, :face, 1).key) && "AL" in texts(v)
  arrived[] = true
  for _ in 1:200
    frames(1, w6)
    isempty(part(v, :face, 1).key) || break
    sleep(0.01)
  end
  @test !isempty(part(v, :face, 1).key) && !("AL" in texts(v)) && asked == [photo]
  shot("contact-web-photo.png", w6)
  close(w6)
end

@testset "a page that can't be changed still opens and copies" begin
  fixed = joinpath(dir, "fixed.md")
  write(fixed, "# Fixed\n\n```contact\nAda Lovelace\nrole: Engineer\nemail: ada@example.com\n```\n\n```contact\n```\n")
  chmod(fixed, 0o444)
  e4 = K.build_editor(fixed)
  w4 = Window(e4, size=(800px, 700px))
  frames(3, w4)
  v, n = view(1, e4), view(2, e4)
  @test e4.buf.fixed && K.locked(v)
  # A click opens at once, since no second click can change anything
  empty!(opened)
  click(spot(v, :row, 1, 3), w4)
  @test opened == ["mailto:ada@example.com"]
  twice(spot(v, :words, 1, :name), w4)
  @test v.editing === nothing
  at(spot(v, :row, 1, 3), w4); frames(2, w4)
  # It has the buttons that copy and that add to Contacts, and none that changes the block
  @test shows(v, :button, (:copy, 1, 3)) && shows(v, :button, (:keep, 1)) && !shows(v, :button, (:more, 1)) && !shows(v, :button, (:new,))
  click(spot(v, :button, (:copy, 1, 3)), w4)
  @test clipboard(w4) == "ada@example.com"
  # An empty block says nothing, and takes no name
  @test !("Name" in texts(n))
  click(spot(n, :words, 1, :name), w4)
  @test n.editing === nothing && !K.dirty(e4.buf)
  shot("contact-fixed.png", w4)
  close(w4)
  chmod(fixed, 0o644)
end
