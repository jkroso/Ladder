# Tests for the link cards of main.jl: a line that holds only the address of a
# web page, written as a picture's is, shows a card with the page's title, its
# description and its picture. Run them with
# `julia -O0 --project=. test/linkcard_view_test.jl`. They use a window that
# isn't on the screen, and no network: a function of the test stands in for
# `curl`, and another for the browser. Set `LADDER_SHOTS` to a folder, and
# they save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive
const C, px = K.Cards, K.px

const dir = mktempdir()
K.MEDIA_CACHE[] = joinpath(dir, "cache")

# The pretend web: what it has at each address, the addresses that were asked for, and whether it has answered yet
const web = Dict{String,Any}()
const asked = String[]
const arrived = Ref(false)
C.getter[] = (url, file, most) -> begin
  push!(asked, url)
  haskey(web, url) && write(file, first(Vector{UInt8}(web[url]), most))
  () -> arrived[]
end
const opened = String[]   # the addresses that the pretend browser was sent to
K.BROWSER[] = url -> (push!(opened, url); nothing)

const PAINT = "https://www.bunnings.com.au/paint"
const SLOW = "https://docs.julialang.org/en/v1/manual/getting-started/"
const GONE = "https://gone.example.com/"
const LOGO = "https://julialang.org/logo.png"                    # a picture by the end of its name
const PHOTO = "https://images.example.com/photo-1?w=800"         # a picture whose address doesn't say so
const picture = read(joinpath(@__DIR__, "..", "app", "icon.png"))
web[PAINT] = """
<html><head><title>Paint | Bunnings</title>
<meta property="og:title" content="White paint &amp; primer, 4 L">
<meta property="og:description" content="A low-sheen acrylic for walls and ceilings in every room of the house. It covers 16 square metres with each litre, dries in two hours and washes off your brushes with water. This sentence is here to make the description longer than two lines of the card.">
<meta property="og:image" content="/images/paint.png">
<meta property="og:site_name" content="Bunnings Australia">
<link rel="icon" href="/icon.png">
</head><body></body></html>
"""
web["https://www.bunnings.com.au/images/paint.png"] = picture
web["https://www.bunnings.com.au/icon.png"] = picture
web[SLOW] = "<title>Getting Started · The Julia Language</title><meta name=\"description\" content=\"Documentation for The Julia Language.\">"
web[PHOTO] = picture

const page = joinpath(dir, "links.md")
cp(joinpath(@__DIR__, "..", "app", "icon.png"), joinpath(dir, "plan.png"))
write(page, """
# Links

![Paint for the hall]($PAINT)

Some words with $PAINT in the line.

![]($SLOW)

![Gone]($GONE)

$PAINT

![Julia]($LOGO)

![A photo]($PHOTO)

The end.
""")

# Ladder gets a picture from the web with `curl` itself. Here it knows that the logo can't be had, and that the photo
# is the file plan.png, so that it asks the web for nothing.
K.fetches[LOGO] = nothing
K.fetches[PHOTO] = joinpath(dir, "plan.png")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1000px))
const (; frames, at, click, key, shot) = drive(w)
frames()
K.focus(e)
line(text) = findfirst(startswith(text), e.buf.lines)
flows(i) = K.item(e, i).content isa K.Flow
"The card that line `i` shows, or nothing when it shows none"
card(i) = (c = K.item(e, i).content; c isa K.Live && c.node isa K.LinkCard ? c.node : nothing)
"The lines that show the cards: of the paint, of the slow page, and of the page that can't be had"
lines() = (line("![Paint"), line("![]("), line("![Gone"))
caret!(p) = (e.buf.caret = e.buf.anchor = p; K.touch!(e); frames())

@testset "what a line shows" begin
  paint, slow, gone = lines()
  @test all(i -> card(i) !== nothing, lines())
  @test card(paint).card.url == PAINT && card(slow).card.url == SLOW && card(gone).card.url == GONE
  @test card(paint).line == paint && card(paint).words == "Paint for the hall" && card(slow).words == ""
  tall = K.card_tall(K.body(e).size)
  @test 90 <= K.num(tall) <= 110 && rect(card(paint)).height ≈ tall && rect(card(paint)).width ≈ e.width
  @test rect(card(gone)).top > rect(card(slow)).top + tall
  # A card's line is a picture's: the caret goes onto it as a whole
  @test K.pictured(e.buf, paint) && K.solid(e.buf, paint) == (paint, paint)
  # The sidebar lists no card, as it lists no picture
  @test !any(en -> en.title == "Link card", K.outline(e.buf))
  # A window that isn't on the screen asks the web for nothing with `curl`. This test has its own function in place of it.
  mine = C.getter[]
  @test K.online(e)
  C.getter[] = C.curl
  @test !K.online(e)
  C.getter[] = mine
  # An email shows no card: in one, the line is a picture's
  was = e.buf.path
  e.buf.path = joinpath(dir, "letter.eml")
  @test !K.online(e) && !K.card_address(e, PAINT)
  e.buf.path = was
  @test K.card_address(e, PAINT) && K.card_address(e, PHOTO)
end

@testset "a line that shows no card" begin
  # A web address alone on a line is a line of text, and so is one in a line of words
  bare = findlast(==(PAINT), e.buf.lines)
  @test flows(bare) && K.solid(e.buf, bare) === nothing && flows(line("Some words"))
  @test join(seg.text for vl in K.item(e, bare).content.lines for seg in vl.segs) == PAINT
  # An address that ends as a picture's does is a picture line. Ladder has no picture for this one, so it shows as
  # it's written. It's no card, and no card was asked for.
  logo = line("![Julia]")
  @test !K.card_address(e, LOGO) && !K.card_address(e, "https://example.com/talk.MP4?t=3") && !K.card_address(e, "https://example.com/plan.pdf")
  @test K.pictured(e.buf, logo) && flows(logo) && K.picture_item(e, logo) === nothing && card(logo) === nothing
  @test !(LOGO in asked)
  # So is an address that isn't on the web, and one that names no computer
  @test !K.card_address(e, "plan.png") && !K.card_address(e, "notes") && !K.card_address(e, "https://")
end

@testset "a card while its page is on its way" begin
  paint, slow, gone = lines()
  photo = line("![A photo]")
  # Each address was asked for once, and nothing else was
  @test sort(asked) == sort([PAINT, SLOW, GONE, PHOTO])
  c = card(paint)
  @test c.card == C.Card(PAINT) && c.picture == "" && c.icon == ""
  # Until Ladder knows what's at the photo's address, its line shows a card too
  @test card(photo) !== nothing && card(photo).card == C.Card(PHOTO)
  shot("cards-waiting.png")
  tops = [K.item(e, i).top for i in (paint, slow, gone)]
  arrived[] = true
  frames(4)
  # The page that can't be had was asked for twice. Here the second time comes at once.
  C.jobs[joinpath(K.cards_dir(), C.name(GONE) * ".html")] -= C.SOON
  frames(4)
  @test count(==(GONE), asked) == 2
  c = card(paint)
  @test c.card.title == "White paint & primer, 4 L" && c.card.site == "Bunnings Australia" && !isempty(c.picture) && !isempty(c.icon)
  @test card(slow).card.title == "Getting Started · The Julia Language" && card(slow).picture == ""
  # A page that can't be had keeps its address, and the page doesn't move when a card fills in
  @test card(gone).card == C.Card(GONE) && [K.item(e, i).top for i in (paint, slow, gone)] == tops
  # What's at the photo's address is a picture, so its line shows it as a picture
  @test card(photo) === nothing && (p = K.item(e, photo).content; p isa K.Live && p.node isa K.Picture)
  @test !K.dirty(e.buf)
  shot("cards.png")
  # The folder keeps each card and each picture, and nothing of the pages themselves. The photo's file says that it's no page.
  kept = readdir(K.cards_dir())
  @test dirname(K.cards_dir()) == joinpath(dir, "cache") && count(endswith(".card"), kept) == 3 && !any(endswith(".html"), kept)
  @test C.name("https://www.bunnings.com.au/images/paint.png") in kept
  @test readlines(joinpath(K.cards_dir(), C.name(PHOTO) * ".card")) == ["page: no"]
end

@testset "the caret and the line" begin
  paint = lines()[1]
  text = e.buf.lines[paint]
  # The caret goes onto the card's line as a whole, and the line still shows the card
  caret!((paint - 2, 0))
  key(Keys.down); key(Keys.down)
  @test e.buf.caret == (paint, 0) && K.picked(e.buf) == (paint, paint) && card(paint) !== nothing
  shot("cards-picked.png")
  key(Keys.down)
  @test e.buf.caret[1] == paint + 1 && card(paint) !== nothing
  # With the caret in the line, the line shows as it's written. What's typed there changes it, and ⌘Z takes it back.
  caret!((paint, length(text)))
  @test card(paint) === nothing && flows(paint) && K.item(e, paint).content.raw
  shot("cards-typing.png")
  ontype(e, Typed('s', w)); frames()
  @test e.buf.lines[paint] == text * "s"
  K.undo!(e.buf); frames()
  @test e.buf.lines[paint] == text
  caret!((1, 0))
  @test card(paint).card.title == "White paint & primer, 4 L"
  # ⌫ on the line as a whole takes it away, and ⌘Z puts it back
  caret!((paint, 0))
  key(Keys.backspace)
  @test line("![Paint") === nothing
  K.undo!(e.buf); frames()
  caret!((1, 0))
  @test line("![Paint") == paint && card(paint) !== nothing && !K.dirty(e.buf)
end

@testset "a new card from the Insert menu" begin
  web["https://example.org/new"] = "<title>A new page</title>"
  item = K.INSERTS[findfirst(x -> x isa Tuple && x[1] == "Link Card", K.INSERTS)]
  caret!(K.line_end(e.buf, line("The end.")))
  K.add_block!(e, item[2], item[3]); frames()
  i = line("![](https://)")
  # The caret is after the https://, and the line shows as it's written while the caret is there
  @test e.buf.caret == (i, 12) && flows(i)
  for c in "example.org/new"
    ontype(e, Typed(c, w))
  end
  frames()
  # Ladder asks for no page until the caret leaves the line
  @test e.buf.lines[i] == "![](https://example.org/new)" && !any(startswith("https://example.org"), asked)
  caret!((1, 0)); frames(4)
  @test card(i) !== nothing && card(i).card.title == "A new page" && "https://example.org/new" in asked
  foreach(_ -> K.undo!(e.buf), 1:40); frames()
  @test !any(startswith("![](https://example.org"), e.buf.lines) && !K.dirty(e.buf)
end

@testset "a click on a card" begin
  paint, _, gone = lines()
  caret!((1, 0))
  was = e.buf.caret
  c = card(paint)
  @test K.cursor(c) == :arrow && !K.opening(c)
  # With ⌘ held, the mouse shows a hand, and a click opens the address
  w.keys = Keys.cmd
  @test K.cursor(c) == :hand
  w.keys = Keys(0)
  click(c, Keys.cmd)
  @test opened == [PAINT] && e.buf.caret == was && card(paint) !== nothing
  click(card(gone), Keys.cmd)
  @test opened == [PAINT, GONE]
  # A click with no key held opens nothing, and puts the caret on the card as a whole
  click(c)
  @test opened == [PAINT, GONE] && e.buf.caret == (paint, 0) && K.picked(e.buf) == (paint, paint) && card(paint) !== nothing
  # With ⌥ held, a click shows the card's line as it's written, with the caret at its end
  click(card(paint), Keys.opt)
  @test opened == [PAINT, GONE] && e.buf.caret == (paint, length(e.buf.lines[paint])) && card(paint) === nothing && flows(paint)
  caret!((1, 0))
  # In a page that's never changed, a click opens the address with no key held
  chmod(page, 0o444)
  frames()
  @test e.buf.fixed && K.cursor(card(paint)) == :hand
  click(card(paint))
  @test opened == [PAINT, GONE, PAINT] && e.buf.caret == was
  chmod(page, 0o644)
  frames()
  @test !e.buf.fixed
end

@testset "the page as HTML and the page on paper" begin
  made = K.page_html(e)
  @test occursin("<a class=\"card\" href=\"$PAINT\"><span class=\"card-words\"><strong>White paint &amp; primer, 4 L</strong>", made)
  @test occursin("<img class=\"card-picture\" src=\"https://www.bunnings.com.au/images/paint.png\" alt=\"\">", made)
  @test occursin("<strong>Getting Started · The Julia Language</strong>", made)
  # A page that can't be had has the line's words as its title
  @test occursin("<a class=\"card\" href=\"$GONE\"><span class=\"card-words\"><strong>Gone</strong><span class=\"card-description\">$GONE</span>", made)
  # The rules for a card's look come once, with the first card. A card is no paragraph.
  @test count("class=\"card\"", made) == 3 && count("a.card {", made) == 1 && findfirst("a.card {", made)[1] < findfirst("class=\"card\"", made)[1]
  @test !occursin("<p><a class=\"card\"", made)
  # An address by itself is a line of text, and the pictures are pictures
  @test occursin("<p>$PAINT</p>", made) && occursin("<p><img src=\"$LOGO\" alt=\"Julia\"></p>", made) && occursin("<img src=\"$PHOTO\" alt=\"A photo\">", made)
  # A page with no card has none of those rules
  @test !occursin("card", K.html(["# A page", "", PAINT, "", "![Julia]($LOGO)"]))
  @test length(K.print_pdf(e)) > 1000
  frames()
end

@testset "the look of a card" begin
  caret!((1, 0))
  K.theme!(e, :night); frames()
  shot("cards-night.png")
  K.theme!(e, :sepia); frames()
  # In a narrow window the card is as wide as the text, and its words end in …
  narrow = Window(e, size=(420px, 1000px))
  foreach(_ -> frame(narrow), 1:3)
  @test rect(card(lines()[1])).width ≈ e.width && K.num(e.width) < 400
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "cards-narrow.png"), narrow)
  close(narrow)
end
