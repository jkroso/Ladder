# Tests for linkcard.jl. Run them with `julia -O0 --project=. test/linkcard_test.jl`.
# They use no network: a function of the test stands in for `curl`.

@use Test: @test, @testset
@use "../linkcard" => C

const SITE = "https://www.bunnings.com.au/paint/white-4l?colour=white#top"

@testset "a web address" begin
  # A web address and nothing else
  @test C.isaddress("HTTPS://Example.com/") && C.isaddress("https://example.com/plan.png") && C.isaddress("https://youtu.be/abc")
  @test !C.isaddress("https://") && !C.isaddress("ftp://example.com") && !C.isaddress("example.com") && !C.isaddress("")
  @test !C.isaddress("https://example.com and more") && !C.isaddress("See https://example.com") && !C.isaddress("<https://example.com>")
  @test !C.isaddress("[Bunnings](https://www.bunnings.com.au)") && !C.isaddress("![Bunnings](https://www.bunnings.com.au)")
end

@testset "the parts of an address" begin
  @test C.host(SITE) == "bunnings.com.au" && C.host("http://Example.com:8080/a") == "example.com"
  @test C.host("https://jake@host.local/x") == "host.local" && C.host("not an address") == ""
  @test C.origin(SITE) == "https://www.bunnings.com.au" && C.path(SITE) == "/paint/white-4l" && C.path("https://example.com") == ""
  @test C.absolute("https://cdn.example.com/a.png", SITE) == "https://cdn.example.com/a.png"
  @test C.absolute("//cdn.example.com/a.png", SITE) == "https://cdn.example.com/a.png"
  @test C.absolute("/img/a.png", SITE) == "https://www.bunnings.com.au/img/a.png"
  @test C.absolute("a.png", SITE) == "https://www.bunnings.com.au/paint/a.png"
  @test C.absolute("a.png", "https://example.com") == "https://example.com/a.png"
  @test C.absolute("../a.png", SITE) == "https://www.bunnings.com.au/a.png"
  @test C.absolute("./a.png", SITE) == "https://www.bunnings.com.au/paint/a.png"
  @test C.absolute("?page=2", SITE) == "https://www.bunnings.com.au/paint/white-4l?page=2"
  @test C.absolute("#bottom", SITE) == "https://www.bunnings.com.au/paint/white-4l?colour=white#bottom"
  # An address that isn't on the web names no picture
  @test C.absolute("data:image/png;base64,AAAA", SITE) == "" && C.absolute("javascript:alert(1)", SITE) == ""
  @test C.absolute("file:///etc/passwd", SITE) == "" && C.absolute("", SITE) == "" && C.absolute("a b.png", SITE) == ""
end

@testset "entities" begin
  @test C.entities("Fish &amp; chips &lt;now&gt; &quot;hot&quot; &#39;n&#x27; &apos;cold&apos;") == "Fish & chips <now> \"hot\" 'n' 'cold'"
  @test C.entities("caf&eacute; &ndash; 5&nbsp;km &hellip; &#8217;&#x2014;&#X2014; &#146; &sup2;") == "café – 5\u00a0km … ’—— ’ ²"
  # A name that isn't known stays; a number that names no character becomes \ufffd
  @test C.entities("&bogus; &#0; &#xD800; &#99999999; & alone &amp") == "&bogus; \ufffd \ufffd \ufffd & alone &amp"
  @test C.tidy("  Two\n  lines&nbsp;and\ta tab ") == "Two lines and a tab"
  @test C.tidy("abcdefgh", 5) == "abcde…"
end

const PAGE = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<!-- <meta property="og:title" content="In a comment"> -->
<script>var s = '<meta property="og:title" content="In a script">';</script>
<title>White paint 4L | Bunnings</title>
<meta name="description" content="Plain description">
<meta property="og:title" content="White paint &amp; primer, 4&nbsp;L">
<meta content='Covers 16 m&sup2; a litre. Dries in
   two hours &#8211; "touch dry" in one.' property='og:description'>
<meta property="og:image" content="/images/paint.jpg?w=600&amp;h=400">
<meta property="og:image" content="/images/second.jpg">
<meta property=og:site_name content=Bunnings>
<link rel="stylesheet" href="/site.css">
<link rel="shortcut icon" href="/static/icon.png">
</head>
<body><h1>White paint</h1><title>Not this</title></body>
</html>
"""

@testset "reading a page" begin
  c = C.card(PAGE, SITE)
  @test c.url == SITE && c.title == "White paint & primer, 4 L"
  @test c.description == "Covers 16 m² a litre. Dries in two hours – \"touch dry\" in one."
  @test c.image == "https://www.bunnings.com.au/images/paint.jpg?w=600&h=400"
  @test c.site == "Bunnings" && c.icon == "https://www.bunnings.com.au/static/icon.png"
  @test C.heading(c) == "White paint & primer, 4 L" && C.source(c) == "Bunnings · bunnings.com.au"
  @test C.blurb(c) == c.description
  # Without the og: lines, the <title> and the description of the page count
  plain = C.card("<html><head><TITLE lang=en>\n  A plain   page\n</TITLE><META NAME=\"Description\" CONTENT=\"What it is > what it was\"></head></html>",
                 "http://example.com/a/b.html")
  @test plain.title == "A plain page" && plain.description == "What it is > what it was" && plain.image == "" && plain.site == ""
  @test plain.icon == "http://example.com/favicon.ico" && C.source(plain) == "example.com"
  # Twitter's lines count where the og: ones are missing, and a <base> says where the page's addresses start
  other = C.card("""<head><base href="https://cdn.example.org/assets/"><meta name="twitter:title" content="A tweet">
                    <meta name="twitter:image" content="card.png"><meta property="og:image" content=""></head>""", "https://example.com/x")
  @test other.title == "A tweet" && other.image == "https://cdn.example.org/assets/card.png"
  # A page that says nothing, and one that isn't HTML, give a card with only the address
  empty = C.card("{\"json\": true}", "https://example.com/api")
  @test empty.title == "" && empty.description == "" && empty.image == "" && C.heading(empty) == "https://example.com/api"
  @test C.blurb(empty) == ""   # the address is the title, so it isn't under the title too
  # A page with a title and no description has its address under the title
  @test C.blurb(C.card("<title>Only a title</title>", SITE)) == SITE
  @test C.card("", "https://example.com").title == ""
  # A picture that isn't on the web is no picture
  @test C.card("<meta property=\"og:image\" content=\"data:image/png;base64,AAAA\">", SITE).image == ""
  # A page that was cut in a tag, in a script or in its title still reads
  @test C.card("<title>Cut", SITE).title == "Cut" && C.card("<title>Whole</title><script>if (a <", SITE).title == "Whole"
  @test C.card("<title>Whole</title><meta property=\"og:title\" content=\"Cu", SITE).title == "Whole"
  # A long title and a long description are cut
  long = C.card("<title>" * "word "^200 * "</title><meta name=description content=\"" * "more "^300 * "\">", SITE)
  @test length(long.title) <= 201 && endswith(long.title, "…") && length(long.description) <= 401
end

@testset "the bytes of a page" begin
  @test C.card(Vector{UInt8}("<title>Café</title>"), SITE).title == "Café"
  # A page that was cut in the middle of a character
  @test C.card(Vector{UInt8}("<title>Caf</title><p>é")[1:end-1], SITE).title == "Caf"
  # A page in Latin-1, and one in Windows-1252 with its own quote marks
  latin = UInt8[Vector{UInt8}("<meta charset=\"iso-8859-1\"><title>Caf")..., 0xe9, Vector{UInt8}("</title>")...]
  @test C.card(latin, SITE).title == "Café"
  windows = UInt8[Vector{UInt8}("<meta http-equiv=Content-Type content=\"text/html; charset=windows-1252\"><title>It")..., 0x92, Vector{UInt8}("s</title>")...]
  @test C.card(windows, SITE).title == "It’s"
  # Every Windows-1252 character in 0x80 to 0x9f, including the 17 outside the common quotes and dashes
  extra = UInt8[0x82, 0x83, 0x84, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8e, 0x98, 0x9a, 0x9b, 0x9c, 0x9e, 0x9f]
  full = UInt8[Vector{UInt8}("<meta charset=windows-1252><title>")..., extra..., Vector{UInt8}("</title>")...]
  @test C.card(full, SITE).title == "‚ƒ„†‡ˆ‰Š‹ŒŽ˜š›œžŸ"
  # A page in UTF-8 with a wrong byte, and a page in letters that this file can't read
  @test C.card(UInt8[Vector{UInt8}("<title>A")..., 0xff, Vector{UInt8}("B</title>")...], SITE).title == "AB"
  @test C.card(UInt8[Vector{UInt8}("<meta charset=shift_jis><title>")..., 0x93, 0xfa, Vector{UInt8}("</title>")...], SITE).title == ""
  @test C.card(rand(UInt8, 5000), SITE).url == SITE   # bytes that aren't a page never throw
end

@testset "bytes that are a picture" begin
  # A card's address can be a picture's. Its card says that it's no page, and has only the address.
  png = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, rand(UInt8, 300)...]
  @test C.card(png, SITE) == C.Card(SITE, page=false) && C.card(PAGE, SITE).page && C.Card(SITE).page
  @test !C.ispage(png) && !C.ispage(UInt8[0xff, 0xd8, 0xff, 0xe0]) && !C.ispage(Vector{UInt8}("GIF89a")) && !C.ispage(UInt8[])
  # A picture whose bytes say <title> near their start is still no page
  @test !C.ispage(Vector{UInt8}("%PDF-1.7 <title>A</title>")) && !C.ispage(Vector{UInt8}("RIFF\0\0\0\0WEBPVP8 <html>"))
  @test !C.ispage(Vector{UInt8}("<?xml version=\"1.0\"?>\n<svg xmlns=\"http://www.w3.org/2000/svg\"><title>A badge</title></svg>"))
  # A page is one with a tag that only a page has, and an <svg> in a page doesn't change that
  @test C.ispage(Vector{UInt8}(PAGE)) && C.ispage(Vector{UInt8}("\n  <!doctype html><svg></svg>")) && C.ispage(Vector{UInt8}("<TITLE>A</TITLE>"))
  @test C.ispage(Vector{UInt8}("<html><body><svg><title>An icon</title></svg>")) && C.ispage(UInt8[0xef, 0xbb, 0xbf, Vector{UInt8}("<html>")...])
  # Text that has none of those tags is no page
  @test !C.ispage(Vector{UInt8}("{\"json\": true}")) && !C.ispage(Vector{UInt8}("Just some words, and <b>bold</b> ones"))
  @test !C.ispage(Vector{UInt8}("<metadata>")) && !C.ispage(Vector{UInt8}("<titles>"))
end

@testset "what a card keeps" begin
  c = C.card(PAGE, SITE)
  lines = C.written(c)
  @test lines[1] == "title: White paint & primer, 4 L" && length(lines) == 5
  @test C.card(lines, SITE) == c
  @test C.card(String[], SITE) == C.Card(SITE) && isempty(C.written(C.Card(SITE)))
  @test C.card(["title: A: B", "more: unknown", "not a line"], SITE).title == "A: B"
  # What it keeps of an address that isn't a page says so
  @test C.written(C.Card(SITE, page=false)) == ["page: no"] && C.card(["page: no"], SITE) == C.Card(SITE, page=false)
  @test C.card(["title: A", "page: yes"], SITE).page
  @test C.name(SITE) == C.name(SITE) && C.name(SITE) != C.name(SITE * "x")
end

@testset "the card as HTML" begin
  made = C.markup(C.card(PAGE, SITE))
  @test startswith(made, "<a class=\"card\" href=\"https://www.bunnings.com.au/paint/white-4l?colour=white#top\">")
  @test occursin("<strong>White paint &amp; primer, 4 L</strong>", made) && occursin("&quot;touch dry&quot;", made)
  @test occursin("<span class=\"card-site\">Bunnings · bunnings.com.au</span>", made)
  @test occursin("<img class=\"card-picture\" src=\"https://www.bunnings.com.au/images/paint.jpg?w=600&amp;h=400\" alt=\"\">", made)
  # A card with only its address
  bare = C.markup(C.Card("https://example.com/a?b=<1>"))
  @test occursin("<strong>https://example.com/a?b=&lt;1&gt;</strong>", bare) && !occursin("<img", bare) && !occursin("card-description", bare)
  # A page with a title and no description has its address under the title
  titled = C.markup(C.Card("https://example.com/a", title="A <page>"))
  @test occursin("<strong>A &lt;page&gt;</strong><span class=\"card-description\">https://example.com/a</span>", titled)
  # The line's words for the card are its title while it has none, and the address goes under them
  named = C.markup(C.Card("https://example.com/a"), "A <name>")
  @test occursin("<strong>A &lt;name&gt;</strong><span class=\"card-description\">https://example.com/a</span>", named)
  @test C.heading(C.Card("https://example.com/a", title="Title"), "Words") == "Title" && C.heading(C.Card("https://example.com/a"), "") == "https://example.com/a"
  @test C.blurb(C.Card("https://example.com/a", description="What it is"), "Words") == "What it is"
  # Words of the page are never tags of the card
  @test !occursin("<script", C.markup(C.card("<title>&lt;script&gt;alert(1)&lt;/script&gt;</title>", SITE)))
end

# --- getting a page, with a function in place of `curl` ----------------------------------------

const web = Dict{String,Any}()   # what the pretend web has at each address
const asked = String[]           # the addresses that were asked for
const arrived = Ref(true)        # false while the pretend web is slow
C.getter[] = (url, file, most) -> begin
  push!(asked, url)
  haskey(web, url) && write(file, first(Vector{UInt8}(web[url]), most))
  () -> arrived[]
end

@testset "getting a page and keeping it" begin
  dir = joinpath(mktempdir(), "cards")
  web[SITE] = PAGE
  arrived[] = false
  card, waiting = C.lookup!(SITE, dir)
  @test card == C.Card(SITE) && waiting && asked == [SITE]
  @test C.lookup!(SITE, dir) == (C.Card(SITE), true) && asked == [SITE]   # it's asked for once
  arrived[] = true
  card, waiting = C.lookup!(SITE, dir)
  @test card.title == "White paint & primer, 4 L" && !waiting
  # The folder keeps what the card shows, and not the page
  @test readdir(dir) == [C.name(SITE) * ".card"] && readlines(joinpath(dir, C.name(SITE) * ".card")) == C.written(card)
  # The next run of the app reads the card from the folder, with no network
  empty!(C.cards); empty!(C.jobs); empty!(C.tries); empty!(web); empty!(asked)
  @test C.lookup!(SITE, dir) == (card, false) && isempty(asked)
  # A picture whose address doesn't say that it's one: its card says that it isn't a page, and the folder keeps that
  photo = "https://images.example.com/photo-1?w=800"
  web[photo] = UInt8[0xff, 0xd8, 0xff, 0xe0, rand(UInt8, 100)...]
  @test C.lookup!(photo, dir) == (C.Card(photo), true)
  @test C.lookup!(photo, dir) == (C.Card(photo, page=false), false)
  empty!(C.cards); empty!(C.jobs); empty!(C.tries); empty!(web); empty!(asked)
  @test C.lookup!(photo, dir) == (C.Card(photo, page=false), false) && isempty(asked)
end

@testset "a page that can't be had" begin
  dir = joinpath(mktempdir(), "cards")
  empty!(asked)
  gone = "https://example.com/gone"
  @test C.lookup!(gone, dir) == (C.Card(gone), true)    # it's on its way
  # The site said no. Ladder isn't done with it: it asks once more a little later, and not straight away.
  @test C.lookup!(gone, dir) == (C.Card(gone), true) && C.lookup!(gone, dir) == (C.Card(gone), true) && asked == [gone]
  @test !any(endswith(".card"), readdir(dir)) && !any(endswith(".part"), readdir(dir))
  raw = joinpath(dir, C.name(gone) * ".html")
  C.jobs[raw] = time() - C.SOON - 1
  @test C.lookup!(gone, dir) == (C.Card(gone), true) && asked == [gone, gone]
  # The site said no again. Now the card stays as it is, and Ladder waits longer before it asks.
  @test C.lookup!(gone, dir) == (C.Card(gone), false)
  C.jobs[raw] = time() - C.SOON - 1
  @test C.lookup!(gone, dir) == (C.Card(gone), false) && asked == [gone, gone]
  C.jobs[raw] = time() - C.RETRY - 1
  web[gone] = "<title>Back</title>"
  @test C.lookup!(gone, dir)[2] && C.lookup!(gone, dir)[1].title == "Back" && asked == [gone, gone, gone]
  # A function that throws in place of `curl` leaves the card with its address
  was = C.getter[]
  C.getter[] = (url, file, most) -> error("no curl")
  @test C.lookup!("https://example.com/throws", dir)[1] == C.Card("https://example.com/throws")
  C.getter[] = was
  # Without `ask`, a page that the folder doesn't keep is asked for from no one
  empty!(asked)
  @test C.lookup!("https://example.com/quiet", dir, ask=false) == (C.Card("https://example.com/quiet"), false)
  @test C.picture!("https://example.com/quiet.jpg", dir, ask=false) == (nothing, false) && isempty(asked)
  @test C.lookup!(gone, dir, ask=false)[1].title == "Back"   # a page that it keeps still shows
  # Only the start of a page is read
  web["https://example.com/long"] = "<title>Start</title>" * " "^(2C.PAGE_BYTES) * "<meta property=\"og:title\" content=\"End\">"
  @test C.lookup!("https://example.com/long", dir)[2] && C.lookup!("https://example.com/long", dir)[1].title == "Start"
end

@testset "getting a picture" begin
  dir = joinpath(mktempdir(), "cards")
  empty!(asked)
  @test C.picture!("", dir) == (nothing, false) && isempty(asked)
  web["https://example.com/a.jpg"] = UInt8[0xff, 0xd8, 0xff]
  arrived[] = false
  @test C.picture!("https://example.com/a.jpg", dir) == (nothing, true)
  arrived[] = true
  file, waiting = C.picture!("https://example.com/a.jpg", dir)
  @test file == joinpath(dir, C.name("https://example.com/a.jpg")) && !waiting && read(file) == UInt8[0xff, 0xd8, 0xff]
  none = "https://example.com/none.jpg"
  @test C.picture!(none, dir) == (nothing, true) && C.picture!(none, dir) == (nothing, true)
  C.tries[joinpath(dir, C.name(none))] = 2   # it couldn't be had twice
  @test C.picture!(none, dir) == (nothing, false)
  @test asked == ["https://example.com/a.jpg", none]
end
