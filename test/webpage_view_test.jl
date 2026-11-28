# Tests for how the window shows an email as it was sent: its HTML, laid out
# by web/, in place of its words, its links, its words that you select, and
# the button that gets its pictures from the web. See "an email as it was
# sent" in main.jl. Run them with
# `julia -O0 --project=. test/webpage_view_test.jl`. They click in a window
# that isn't on the screen. They ask the web for nothing, and they open no
# app: a function of webpage_fake.jl notes each link that would open. Set
# `LADDER_SHOTS` to a folder, and they save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "./webpage_fake" => Fake
@use "./map_fake" png
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups clipboard
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px
const W = K.Webpages

W.OPENER[] = Fake.opener
K.MEDIA_CACHE[] = mktempdir()                          # the pictures are kept here, and not in the Mac's caches
K.Eml.CACHE[] = mktempdir()                            # and the files that came with an email here

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")   # the senders whose pictures you asked for are listed beside it
"Write an email file whose body is `body`, of the kind `type`, and give its path. With `file`, a PDF comes with it."
email(name, body; type="text/html", file=false, from="Sam Lee <sam@example.com>") = begin
  head = "From: $from\r\nTo: you@example.com\r\nSubject: $name\r\nDate: Sat, 14 Nov 2026 09:32:00 +1100\r\nMIME-Version: 1.0\r\n"
  text = "Content-Type: $type; charset=utf-8\r\n\r\n$body\r\n"
  pdf = "Content-Type: application/pdf; name=\"Roof quote.pdf\"\r\nContent-Disposition: attachment; filename=\"Roof quote.pdf\"\r\n" *
        "Content-Transfer-Encoding: base64\r\n\r\nJVBERi0xLjcK\r\n"
  path = joinpath(dir, "$name.eml")
  write(path, file ? head * "Content-Type: multipart/mixed; boundary=m\r\n\r\n--m\r\n$text--m\r\n$pdf--m--\r\n" : head * text)
  path
end
const PAPER = (204, 255, 238)   # the colour of the page of the first email
const LINKS = """<body bgcolor="#ccffee"><p>Hi Jake, the <a href="https://example.com/quote?job=7&v=2">quote</a> is here. Write to <a href="mailto:sam@example.com">me</a>.</p></body>"""
const quote_email = email("The quote", LINKS, file=true)
const LOGO = "https://example.com/logo.png"
const logo_email = email("A logo", """<p>Our logo</p><img src="$LOGO" style="display:block">""")
const plain_email = email("Plain words", "Hi Jake,\r\n\r\nNo HTML here.", type="text/plain")
const tall_email = email("A long one", """<body style="margin:0"><div style="height:1500px;background:#cc0000"></div><div style="height:300px;background:#0000cc"></div></body>""")

const e = K.build_editor(quote_email)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, press, release, click, key, shot) = drive(w)
e.plain && K.level!(e)   # the page starts at the high level, whatever the test before this one left
frames(3)
K.focus(e)

"Draw frames until `done()` is true, for 10 seconds at most"
until(done) = (t = time(); while !done() && time() - t < 10; sleep(0.02); frames(1); end; done())
"Show the email at `path` in the window"
show(path, n=3) = (K.open!(e, path); frames(n))

"The email as it was sent, as the window keeps it"
sent() = e.nodes[:sent_email]
"The part of the page that stands for the email's words, or nothing while the page shows the words"
item() = (i = findfirst(it -> it.content isa K.Live && it.content.node isa K.SentEmail, e.layout); i === nothing ? nothing : e.layout[i])
"True when the page shows the email as it was sent"
shows() = item() !== nothing && sent().shown !== nothing
"The email's page as it's laid out, with its links and its words"
laid() = sent().shown.page
"Where the email is in the window, with the line round it"
page() = rect(sent().parts[:page])
"The place in the window of a point of the email, in px from the email's top left corner, which is inside the line round it"
spot(x, y) = (r = page(); (K.num(r.left) + 1 + x, K.num(r.top) + 1 + y))
"The place in the window of the middle of link `i` of the email"
link(i) = (b = laid().links[i]; spot(b.left + b.wide / 2, b.top + b.tall / 2))
"How wide an email is laid out: as wide as the page's text, less the line on each side of the email"
wide() = round(Int, K.num(e.width)) - 2
"The red, the green and the blue of the window's pixel at a place, as the window was last drawn"
colour(place) = begin
  file = joinpath(dir, "window.png")
  save_png(file, w)
  dots = pixels(file)
  k = size(dots, 2) / K.num(K.window_size(e)[1])
  c = dots[round(Int, place[2] * k), round(Int, place[1] * k)]
  (Int((c >> 16) & 0xff), Int((c >> 8) & 0xff), Int(c & 0xff))
end
"The lines of the page that show as text"
texts() = [e.buf.lines[it.first] for it in e.layout if it.content isa K.Flow]
"The part of the page that shows the icons of the files that came with the email, or nothing"
files() = (i = findfirst(it -> it.content isa K.Live && it.content.node isa K.AttachedFiles, e.layout); i === nothing ? nothing : e.layout[i])

@testset "an email with HTML shows as it was sent" begin
  @test shows() && sent().shown.want == (wide(), round(Float64(e.zoom), digits=2), false, 0)
  it = item()
  # The email as it was sent stands for the email's words, and for nothing else of the page
  t = K.front_matter(e.buf.lines)
  @test it.first == t + 1 && e.buf.lines[it.last+1] == "[Roof quote.pdf]($(K.Eml.attachments(quote_email))/Roof%20quote.pdf)"
  @test !any(l -> occursin("quote", l) && occursin("Hi Jake", l), texts())
  # The link to the file shows as the file's icon
  @test !any(l -> occursin("Roof quote.pdf", l), texts()) && files().first == files().last == it.last + 1
  # It's as wide as the page's text, and as tall as its HTML is at that width: a line of words, with the room round it
  r = page()
  @test round(Int, laid().wide) == wide() && K.num(r.width) == wide() + 2 && K.num(r.height) == round(Int, laid().tall) + 2 && 30 < laid().tall < 80
  @test colour(spot(wide() - 20, 10)) == PAPER
  # Its words are text, not a picture of text
  @test [String(w.letters) for w in laid().words] == ["Hi Jake, the quote is here. Write to me."]
  # The card of the email is over it, and the link to the file under it
  @test e.layout[1].first == 1 && e.layout[1].top < it.top && e.layout[end].top >= it.top + it.tall - 1px
  # An email with nothing from the web has no button that fetches it
  @test !sent().remote && !haskey(sent().parts, (:button, :pictures))
  shot("sent-1-email.png")
end

@testset "a link of the email opens, and the mouse over it says where it goes" begin
  empty!(Fake.opened)
  area = sent().parts[:page]
  @test [l.url for l in laid().links] == ["https://example.com/quote?job=7&v=2", "mailto:sam@example.com"]
  at(link(1))
  @test K.cursor(area) == :hand && K.sent_link(area).url == "https://example.com/quote?job=7&v=2" && !isempty(popups(w))
  shot("sent-2-over-a-link.png")
  click(link(1))
  @test Fake.opened == ["https://example.com/quote?job=7&v=2"]
  click(link(2))
  @test Fake.opened[end] == "mailto:sam@example.com" && length(Fake.opened) == 2
  # Beside the words, a click opens nothing
  at(spot(wide() - 20, 10))
  @test K.cursor(area) == :arrow && K.sent_link(area) === nothing
  click(spot(wide() - 20, 10))
  @test length(Fake.opened) == 2 && shows()
  # What a tooltip says of an address
  @test K.sent_address("mailto:sam@example.com") == "sam@example.com" && K.sent_address("https://example.com/a") == "https://example.com/a"
  long = "https://example.com/" * "a"^200 * "/end"
  @test length(K.sent_address(long)) == 86 && startswith(K.sent_address(long), "https://example.com/aaa") && endswith(K.sent_address(long), "aaa/end")
end

"The place in the window a little into letter `k` of line `i` of the email's words. Letter 0 is the first."
letter(i, k) = (s = laid().words[i]; spot(s.edges[k+1] + 1, s.top + s.tall / 2))
"Press `key` with ⌘ held"
command(key) = (w.keys |= Keys.cmd; onkey(w, KeyPress{key}(0, w)); w.keys ⊻= Keys.cmd; frames(1))
"Drag from one place to another"
drag(from, to) = (press(from); at(to); release())
"The red, the green and the blue of an email's page where nothing is drawn on it"
const PAGE = (255, 255, 255)

@testset "the words of an email can be selected and copied" begin
  show(email("Some words", """<p>Hi Jake, the <a href="https://example.com/quote">quote</a> is here.</p><p>Write to me.</p>"""))
  area = sent().parts[:page]
  @test shows() && [String(s.letters) for s in laid().words] == ["Hi Jake, the quote is here.", "Write to me."] && K.WebSelect.letter_count(laid().words) == 39
  # Over the words, the mouse is a bar for text. Beside them, it's an arrow.
  at(letter(1, 3))
  @test K.cursor(area) == :ibeam
  at(spot(wide() - 20, laid().words[1].top + 5))
  @test K.cursor(area) == :arrow
  # A drag selects the words that it goes over. The email takes the keyboard, and ⌘C copies them.
  # The colours are looked at where a space is, so that no letter's ink is there.
  drag(letter(1, 9), letter(1, 18))
  @test w.focus === area && (area.anchor, area.caret) == (9, 18)
  @test colour(letter(1, 12)) != PAGE && colour(letter(1, 21)) == PAGE && colour(letter(2, 5)) == PAGE
  shot("sent-3-words-selected.png")
  command(Keys.c)
  @test clipboard(w) == "the quote"
  # From one line to the next, and back up the page
  drag(letter(1, 13), letter(2, 5))
  command(Keys.c)
  @test clipboard(w) == "quote is here.\nWrite" && colour(letter(1, 21)) != PAGE
  drag(letter(2, 2), letter(1, 22))
  command(Keys.c)
  @test clipboard(w) == "here.\nWr"
  # Two clicks select a word, and three the paragraph
  click(letter(1, 4)); click(letter(1, 4))
  command(Keys.c)
  @test clipboard(w) == "Jake"
  click(letter(1, 4))
  command(Keys.c)
  @test clipboard(w) == "Hi Jake, the quote is here."
  # A click with ⇧ held moves the end of the selection there
  sleep(0.5)
  click(letter(1, 3))
  w.keys |= Keys.shft
  click(letter(1, 7))
  w.keys ⊻= Keys.shft
  command(Keys.c)
  @test clipboard(w) == "Jake"
  # ⌘A selects all the words of the email
  command(Keys.a)
  command(Keys.c)
  @test clipboard(w) == "Hi Jake, the quote is here.\nWrite to me."
  # The right-click menu copies them too
  K.clipboard!(w, "")
  K.page_act!(e, findfirst(==("Copy"), K.PAGE_MENU))
  @test clipboard(w) == "Hi Jake, the quote is here.\nWrite to me."
  # Esc gives the keyboard back to the page, and the words aren't marked then
  key(Keys.escape)
  @test w.focus !== area && colour(letter(1, 12)) == PAGE
  # A key like Space gives the keyboard back too, and the page takes it
  drag(letter(1, 9), letter(1, 18))
  @test w.focus === area
  key(Keys.space)
  @test w.focus !== area
  # A click on a link opens it, and a drag from a link selects words and opens nothing
  empty!(Fake.opened)
  click(link(1))
  @test Fake.opened == ["https://example.com/quote"]
  sleep(0.5)   # so that the press isn't a second click on the link
  drag(link(1), letter(1, 5))
  @test Fake.opened == ["https://example.com/quote"] && area.caret == 5 && 13 <= area.anchor <= 18
  # Another email has nothing selected
  show(quote_email)
  @test sent().parts[:page] === area && area.anchor == area.caret == 0
  K.focus(e)
end

@testset "down a level, the email shows its words, and up again as it was sent" begin
  was = sent().shown.page
  # Each stop's tip is of its own level
  @test K.stop_tip(e, 2) == "The window shows the HTML email. A click goes down a level  ⌘E"
  @test K.stop_tip(e, 1) == "Show plain text email  ⌘E" == K.tip(e.nodes[:mode])
  K.level!(e); frames()
  @test e.plain && item() === nothing && any(l -> occursin("Hi Jake, the [quote]", l), texts())
  @test K.stop_tip(e, 2) == "Show HTML email  ⌘E" == K.tip(e.nodes[:mode])
  @test K.stop_tip(e, 1) == "The window shows the plain text email"
  shot("sent-3-words.png")
  K.level!(e); frames()
  # The page is kept, so the email isn't laid out again
  @test !e.plain && shows() && sent().shown.page === was
end

@testset "while the find bar is open, the email shows its words" begin
  K.open_find!(e); frames()
  @test item() === nothing && any(l -> occursin("Hi Jake", l), texts())
  K.close_find!(e); frames()
  @test shows()
end

@testset "the files that came with an email show as icons, and a click opens one" begin
  it = files()
  f = it.content.node.files[1]
  path = joinpath(K.Eml.attachments(quote_email), "Roof quote.pdf")
  @test f.name == "Roof quote.pdf" && f.path == path && f.lines == ["Roof quote.pdf"] && !f.cut && f.bytes == "9 bytes"
  @test K.file_icon(f.path) == "file-earmark-pdf"
  # The icon is under the email, at the left of the page's text
  r = rect(f)
  @test r.top >= page().top + page().height && abs(K.num(r.left - page().left)) <= 1
  at(middle(r))
  @test K.cursor(f) == :hand && K.ishovered(f)
  shot("sent-7-files.png")
  click(middle(r))
  @test e.buf.path == path
  # Down a level, where the email shows its words, the file shows as its icon too
  show(quote_email)
  K.level!(e); frames()
  @test e.plain && item() === nothing && files() !== nothing && !any(l -> occursin("Roof quote.pdf", l), texts())
  shot("sent-10-files-down-a-level.png")
  K.level!(e); frames()
  @test !e.plain && files() !== nothing
end

@testset "many files go on in the next row, and a long name on two lines" begin
  pdf(name) = "--m\r\nContent-Type: application/pdf; name=\"$name\"\r\nContent-Disposition: attachment; filename=\"$name\"\r\n" *
              "Content-Transfer-Encoding: base64\r\n\r\nJVBERi0xLjcK\r\n"
  names = ["Invoice-VQHURGAU-0001.pdf", "Receipt-2443-7647-3599.pdf", "A very long name of a file that goes on and on and on.pdf", "Plan.zip"]
  path = joinpath(dir, "Files.eml")
  write(path, "From: Sam Lee <sam@example.com>\r\nTo: you@example.com\r\nSubject: Files\r\nDate: Sat, 14 Nov 2026 09:32:00 +1100\r\n" *
              "MIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=m\r\n\r\n--m\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>Four files</p>\r\n" *
              join(pdf.(names)) * "--m--\r\n")
  show(path)
  it = files()
  v = it.content.node
  @test [f.name for f in v.files] == names && it.last == length(e.buf.lines)
  shot("sent-8-four-files.png")
  # A name that's too wide goes on two lines. One that's too long for two loses letters from its middle, and keeps its end.
  @test length(v.files[1].lines) == 2 && join(v.files[1].lines) == names[1] && !v.files[1].cut
  long = v.files[3]
  @test long.cut && length(long.lines) == 2 && occursin("…", long.lines[2]) && endswith(long.lines[2], ".pdf")
  @test K.file_icon(v.files[4].path) == "file-earmark-zip"
  # Each file is in the same row while they fit across, and they go on in the next row when they don't
  tops() = [rect(f).top for f in v.files]
  @test length(unique(tops())) == 1
  was = e.widest
  K.page_width!(e, 300); frames()
  @test length(unique(tops())) == 2 && files().tall > it.tall
  shot("sent-9-two-rows.png")
  e.widest = was; K.rewrap!(e); frames()
  show(quote_email)
end

@testset "an email asks the web for nothing until you click Load pictures" begin
  show(logo_email)
  @test shows() && sent().remote && !sent().pictures && !haskey(K.fetches, LOGO) && isempty(sent().waiting)
  @test !isfile(K.sent_mark(logo_email))
  button = sent().parts[(:button, :pictures)]
  top, tall = page().top, laid().tall
  @test button.words == "Load pictures" && rect(button).top < top
  shot("sent-4-no-pictures.png")
  # The picture is kept already, as it is once Ladder has fetched it, so that the test asks the web for nothing
  file = joinpath(dir, "logo.png")
  write(file, png((x, y) -> (40, 120, 220), 60, 30))
  K.fetches[LOGO] = file
  click(middle(rect(button)))
  frames()
  @test sent().pictures && sent().shown.want[3] && laid().tall == tall + 30
  @test colour(spot(8 + 30, laid().tall - 8 - 15)) == (40, 120, 220)
  # The button has gone, so the email is where the button was
  @test page().top < top && isfile(K.sent_mark(logo_email))
  shot("sent-5-pictures.png")
  # The email shows its pictures from then on, in a new window too
  other = K.build_editor(logo_email)
  second = Window(other, size=(1000px, 900px))
  foreach(_ -> frame(second), 1:3)
  v = other.nodes[:sent_email]
  @test v.pictures && v.shown !== nothing && v.shown.want[3] && v.shown.page.tall == tall + 30
end

@testset "each email from a sender whose pictures you asked for gets its pictures" begin
  # The click on Load pictures in the test before this one noted the sender, once
  @test readlines(K.picture_senders_file()) == ["sam@example.com"]
  url = "https://example.com/footer.png"
  file = joinpath(dir, "footer.png")
  write(file, png((x, y) -> (220, 120, 40), 40, 20))
  K.fetches[url] = file
  path = email("More news", """<p>More news</p><img src="$url" style="display:block">""", from="\"Lee, Sam\" <Sam@Example.com>")
  show(path)
  @test shows() && sent().sender == "sam@example.com" && sent().pictures && sent().shown.want[3]
  @test !isfile(K.sent_mark(path))
  # It has no button, so the email is at the top of where the button would be
  @test until(() -> colour(spot(8 + 20, laid().tall - 8 - 10)) == (220, 120, 40))
  # An email from someone else still asks first
  other = email("Hello", """<p>Hello</p><img src="$url" style="display:block">""", from="Kim Ng <kim@example.org>")
  show(other)
  @test shows() && sent().sender == "kim@example.org" && !sent().pictures && !sent().shown.want[3]
  button = sent().parts[(:button, :pictures)]
  @test occursin("kim@example.org", button.tip)
  click(middle(rect(button)))
  frames()
  @test sent().pictures && readlines(K.picture_senders_file()) == ["sam@example.com", "kim@example.org"]
  # An address is listed once
  K.picture_sender!("sam@example.com")
  @test readlines(K.picture_senders_file()) == ["sam@example.com", "kim@example.org"]
end

@testset "a window that isn't on the screen asks the web for nothing" begin
  url = "https://example.com/banner.png"
  path = email("A banner", """<p>News</p><img src="$url" width="40" height="20">""")
  mkpath(K.sent_dir(path))
  touch(K.sent_mark(path))   # you asked for this email's pictures once
  show(path)
  @test shows() && sent().pictures && !haskey(K.fetches, url) && isempty(sent().waiting)
end

@testset "a picture of an email that moves, moves" begin
  # The test's GIF is 40 by 20: a red square at the left, in the middle and at the right, for half a second each, again and again
  url = "https://example.com/moving.gif"
  path = email("A GIF", """<body style="margin:0" bgcolor="#ffffff"><img src="$url" style="display:block"></body>""")
  mkpath(K.sent_dir(path))
  touch(K.sent_mark(path))   # you asked for this email's pictures once
  K.fetches[url] = joinpath(@__DIR__, "web_moving.gif")   # and the picture is kept already, as it is once Ladder has fetched it
  show(path)
  @test shows() && sent().pictures && laid().tall == 20 && time() - sent().since < 5
  laid_out = sent().shown.page
  red((r, g, b)) = r > 200 && g < 60
  # The email is drawn as it is now, this long after it first showed: the test says how long that is
  sent().since = time() - 0.1
  frames(1)
  @test red(colour(spot(5, 10))) && !red(colour(spot(20, 10)))
  sent().since = time() - 0.6
  frames(1)
  @test red(colour(spot(20, 10))) && !red(colour(spot(5, 10)))
  sent().since = time() - 1.1
  frames(1)
  @test red(colour(spot(35, 10))) && !red(colour(spot(20, 10)))
  shot("sent-11-gif.png")
  # The email is laid out once: only the window is drawn again
  @test sent().shown.page === laid_out
end

@testset "an email with no HTML shows its words" begin
  show(plain_email)
  @test item() === nothing && any(==("No HTML here."), texts())
  @test K.sent_html(e) === nothing && K.level_names(e) == K.PAGE_LEVELS
  # A page that isn't an email has nothing to do with any of this
  note = joinpath(dir, "note.md")
  write(note, "# A note\n\nSome words.\n")
  show(note)
  @test item() === nothing && K.level_names(e) == K.PAGE_LEVELS
end

@testset "a tall email goes on down the page" begin
  show(tall_email)
  @test shows() && laid().tall == 1800 && K.num(page().height) == 1802 && item().tall >= 1800px
  @test colour(spot(300, 200)) == (204, 0, 0)
  e.scroll.offset = item().top + 1400px; frames()
  @test colour(spot(300, 1600)) == (0, 0, 204)
  shot("sent-6-tall.png")
end

@testset "another width or text size lays the email out again" begin
  show(quote_email)
  was, page_was = wide(), sent().shown.page
  K.page_width!(e, 500); frames(1)
  @test wide() != was && shows() && sent().shown.want[1] == wide() == laid().wide && K.num(page().width) == wide() + 2
  # A bigger text size makes everything in the email bigger
  z, tall = e.zoom, laid().tall
  K.zoom!(e, 1.25); frames(1)
  @test sent().shown.want[2] == 1.25 && laid().tall > tall
  K.zoom!(e, z); frames()
  # An email that takes long to lay out waits until the width has stayed a moment. Until then the page that
  # was laid out for the width before shows, as wide as the page is now.
  v = sent()
  v.shown = merge(v.shown, (took=1.0,))
  narrow = wide()
  K.page_width!(e, was); frames(1)
  @test wide() == was && v.shown.want[1] == narrow && K.num(page().width) == was + 2
  @test until(() -> v.shown.want[1] == was) && laid().wide == was
end

@testset "an email that can't be laid out shows its words, and the ladder says why" begin
  K.SENT_PAGE[] = (html; kw...) -> error("no page")
  show(email("No luck", "<p>These words show all the same.</p>"))
  @test item() === nothing && any(==("These words show all the same."), texts())
  @test K.stop_tip(e, 2) == K.SENT_FAILED
  K.SENT_PAGE[] = K.Web.page
  show(quote_email)
  @test shows() && K.stop_tip(e, 2) != K.SENT_FAILED
end
