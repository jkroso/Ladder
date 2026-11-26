# Tests for webpage.jl: what it reads of the pictures that webpage.swift made
# of a page of HTML, the links of a page, and how the pictures are asked for
# and kept. Run them with `julia -O0 --project=. test/webpage_test.jl`. They
# use neither WebKit nor the web: webpage_fake.jl takes the place of the
# program.

@use Test: @test, @testset
@use "../webpage" => W
@use "../web/select" => S
@use "../map" => Maps
@use "./webpage_fake" => Fake

W.HELPER[] = Fake.helper
W.OPENER[] = Fake.opener
const HTML = """<p>Hi <a href="https://example.com/a">one</a> and <a href="mailto:sam@example.com">two</a></p>"""

@testset "what the program made" begin
  dir = mktempdir()
  out = joinpath(dir, "ab.txt")
  write(joinpath(dir, "ab-1.png"), "x")
  write(joinpath(dir, "ab-2.png"), "x")
  write(out, "page\t700\t1310\nstrip\t1024\tab-1.png\nstrip\t286\tab-2.png\n" *
             "link\t158.0\t493.0\t384.0\t33.0\thttps://example.com/session?id=5&key=e\nlink\t10\t20\t30\t40\tmailto:sam@example.com\nmore\tthat a later program says\n")
  s = W.shot(out)
  @test (s.wide, s.tall) == (700, 1310)
  @test s.strips == [joinpath(dir, "ab-1.png") => 1024, joinpath(dir, "ab-2.png") => 286]
  @test s.links == [(left=158.0, top=493.0, wide=384.0, tall=33.0, url="https://example.com/session?id=5&key=e"),
                    (left=10.0, top=20.0, wide=30.0, tall=40.0, url="mailto:sam@example.com")]
  # The link at a point, and none beside it
  @test W.link(s, 160, 500).url == "https://example.com/session?id=5&key=e" && W.link(s, 25, 40).url == "mailto:sam@example.com"
  @test W.link(s, 157, 500) === nothing && W.link(s, 160, 527) === nothing && W.link(s, 600, 900) === nothing
  # Where two links are at one point, it's the one that the page draws over the other
  write(out, "page\t100\t50\nstrip\t50\tab-1.png\nlink\t0\t0\t100\t50\thttps://under.example\nlink\t10\t10\t20\t20\thttps://over.example\n")
  s = W.shot(out)
  @test W.link(s, 15, 15).url == "https://over.example" && W.link(s, 50, 40).url == "https://under.example"
  # A file that says nothing to draw, strips that don't add up to the page, and a strip that's gone
  @test W.shot(joinpath(dir, "none.txt")) === nothing
  for text in ["", "page\t700\t1310\n", "strip\t50\tab-1.png\n", "page\tx\t50\nstrip\t50\tab-1.png\n", "page\t100\t60\nstrip\t50\tab-1.png\n",
               "page\t100\t50\nstrip\t50\tgone.png\n", "page\t100\t50\nstrip\t0\tab-1.png\nstrip\t50\tab-2.png\n"]
    write(out, text)
    @test W.shot(out) === nothing
  end
end

@testset "the words of a page" begin
  dir = mktempdir()
  out = joinpath(dir, "ab.txt")
  write(joinpath(dir, "ab-1.png"), "x")
  # Two lines of a paragraph that wraps, a word in bold in the second, a new line, two cells of a row, and a line of one space that can't break
  write(out, "page\t300\t200\nstrip\t200\tab-1.png\n" *
             "text\t-\t10\t20\t10,20,30,40,50\tHi J\n" *
             "text\t-\t30\t20\t10,20,30,40\tak \n" *
             "text\t-\t28\t24\t40,52,64\tes\n" *
             "text\tline\t60\t20\t10,20,30,40\tOne\n" *
             "text\ttab\t60\t20\t100,110,120,130\tTwo\n" *
             "text\tline\t90\t20\t10,14\t \n" *
             "text\tline\t120\t20\t10,20,30,40\tEnd\n" *
             "text\t-\t150\t20\t10,20\ttwo letters, one edge\n")
  s = W.shot(out)
  # A line that doesn't add up is left out
  @test length(s.words) == 7 && [w.from for w in s.words] == [0, 4, 7, 9, 12, 15, 16] && S.letter_count(s.words) == 19
  @test s.words[1].before == "" && s.words[4].before == "\n" && s.words[5].before == "\t" && s.words[1].letters == collect("Hi J")
  # What's copied: no line ends with a space, and the space that can't break is a space
  @test S.copied(s.words, 0, 19) == "Hi Jak es\nOne\tTwo\n\nEnd" == S.copied(s.words, 19, 0)
  @test S.copied(s.words, 1, 6) == "i Jak" && S.copied(s.words, 10, 14) == "ne\tTw" && S.copied(s.words, 3, 3) == ""
  # The place nearest a point: the letter's left half is before it, and its right half after it
  @test S.place(s.words, 24, 15) == 1 && S.place(s.words, 26, 15) == 2 && S.place(s.words, 0, 15) == 0 && S.place(s.words, 290, 15) == 4
  # A word in bold that's taller than the line is still in it, and a point between the cells of a row is in the nearer cell
  @test S.place(s.words, 50, 45) == 8 && S.place(s.words, 60, 65) == 12 && S.place(s.words, 90, 65) == 12 && S.place(s.words, 127, 65) == 15
  # Between two lines, the point is in the nearer one. Over the words it's their start, and under them their end.
  @test S.place(s.words, 12, 55) == 4 && S.place(s.words, 12, 58) == 9 && S.place(s.words, 50, -5) == 0 && S.place(s.words, 50, 500) == 19
  @test S.over_words(s.words, 15, 15) && !S.over_words(s.words, 70, 15) && !S.over_words(s.words, 15, 52)
  # A rectangle for each line: the word in bold goes on the line it's in, and makes it taller. Each cell of a row has its own.
  @test S.marks(s.words, 1, 9) == [(20.0, 10.0, 30.0, 20.0), (10.0, 28.0, 54.0, 24.0)]
  @test S.marks(s.words, 10, 14) == [(20.0, 60.0, 20.0, 20.0), (100.0, 60.0, 20.0, 20.0)] && S.marks(s.words, 4, 4) == []
  # Two clicks select a word, and three a paragraph
  @test S.word(s.words, 4) == (4, 6) && S.word(s.words, 7) == (7, 9) && S.word(s.words, 2) == (2, 3) && S.word(s.words, 19) == (16, 19) && S.word(s.words, 1) == (0, 2)
  @test S.paragraph(s.words, 5) == (0, 9) && S.paragraph(s.words, 13) == (12, 15) && S.paragraph(s.words, 19) == (16, 19)
  # A page with no words
  write(out, "page\t300\t200\nstrip\t200\tab-1.png\n")
  s = W.shot(out)
  @test isempty(s.words) && S.letter_count(s.words) == 0 && S.place(s.words, 10, 10) == 0 && S.copied(s.words, 0, 5) == "" && S.marks(s.words, 0, 5) == []
  @test S.word(s.words, 0) == (0, 0) && S.paragraph(s.words, 0) == (0, 0)
end

@testset "what a page has from the web" begin
  @test W.remote("""<img src="https://example.com/logo.png">""") && W.remote("""<IMG alt="x" SRC = 'http://example.com/a.gif'>""")
  @test W.remote("""<td background="https://example.com/b.png">""") && W.remote("""<div style="background: url( 'https://example.com/c.png')">""")
  @test W.remote("""<link rel="stylesheet" href="https://fonts.example/css">""")
  # A link to a web page fetches nothing, and nor does a picture that's inside the page
  @test !W.remote("""<a href="https://example.com">a</a> <img src="data:image/png;base64,AAAA"> <img src="cid:logo">""")
  @test !W.remote("") && !W.remote("<p>See https://example.com</p>")
end

@testset "the pictures of a page are asked for once, and kept" begin
  empty!(Fake.calls)
  dir = mktempdir()
  p = W.picture!(dir, HTML, 700)
  @test p.state == :there && isfile(p.file) && dirname(p.file) == dir
  @test Fake.calls == [(html=HTML, wide=700, zoom=1.0, pictures=false)]
  s = W.shot(p.file)
  @test (s.wide, s.tall) == (700, 400) && length(s.strips) == 1 && isfile(first(s.strips[1]))
  @test [l.url for l in s.links] == ["https://example.com/a", "mailto:sam@example.com"] && W.link(s, 30, 110).url == "mailto:sam@example.com"
  # The same page again runs no program
  @test W.picture!(dir, HTML, 700) == p && length(Fake.calls) == 1
  # Another width, another zoom, and the pictures from the web are each another set of pictures
  wider = W.picture!(dir, HTML, 800)
  bigger = W.picture!(dir, HTML, 700, zoom=1.25)
  fetched = W.picture!(dir, HTML, 700, pictures=true)
  @test length(unique([p.file, wider.file, bigger.file, fetched.file])) == 4 && all(q -> q.state == :there, (wider, bigger, fetched))
  @test Fake.calls[2:4] == [(html=HTML, wide=800, zoom=1.0, pictures=false), (html=HTML, wide=700, zoom=1.25, pictures=false),
                            (html=HTML, wide=700, zoom=1.0, pictures=true)]
  # A tall page is in strips of 1024 px or less
  tall = W.shot(W.picture!(dir, HTML * "<!-- tall 2500 -->", 700).file)
  @test tall.tall == 2500 && last.(tall.strips) == [1024, 1024, 452] && all(isfile ∘ first, tall.strips)
  # The folder keeps the pictures of one page when the others are taken away
  W.tidy!(dir, wider.file)
  @test W.shot(wider.file) !== nothing && !isfile(p.file) && !isfile(fetched.file)
  @test all(f -> startswith(f, chopsuffix(basename(wider.file), ".txt")), readdir(dir))
  # A file whose name starts with a dot stays, like the one that says you asked for an email's pictures
  touch(joinpath(dir, ".pictures"))
  W.tidy!(dir, wider.file)
  @test isfile(joinpath(dir, ".pictures"))
  # Without `start`, pictures that aren't kept aren't made
  n = length(Fake.calls)
  @test W.picture!(dir, HTML, 700, start=false).state == :none && length(Fake.calls) == n
end

@testset "pictures that can't be made, and ones that take a while" begin
  empty!(Fake.calls)
  dir = mktempdir()
  Fake.offline[] = true
  p = W.picture!(dir, HTML, 700)
  @test p.state == :failed && p.problem == W.FAILED && !isfile(p.file)
  # It isn't tried again at once
  @test W.picture!(dir, HTML, 700).state == :failed && length(Fake.calls) == 1
  Fake.offline[] = false
  # A Mac with no Swift says what's missing, in words about an email
  swiftless(args...) = 127
  W.HELPER[] = swiftless
  @test W.picture!(dir, HTML, 710).problem == W.NO_SWIFT
  W.HELPER[] = Fake.helper
  # A slow program is `:coming` until it's done
  Fake.slow[] = true
  p = W.picture!(dir, HTML, 720)
  @test p.state == :coming && p.wait > 0
  started = time()
  while (p = W.picture!(dir, HTML, 720)).state == :coming && time() - started < 10; sleep(0.05) end
  @test p.state == :there && W.shot(p.file).wide == 720
  Fake.slow[] = false
end

# This one runs webpage.swift with WebKit, so it needs a Mac with Swift. The
# first run compiles the program, which takes a while.
if Sys.isapple() && Sys.which("swiftc") !== nothing
  dir = mktempdir()
  runs = Ref(0)
  "What the program makes of `html` on a page 700 px wide"
  drawn(html) = begin
    n = runs[] += 1
    source, out = joinpath(dir, "$n.html"), joinpath(dir, "$n.txt")
    write(source, html)
    wait(W.run_program(source, 700, 1.0, false, joinpath(dir, "$n"), out, joinpath(dir, "$n.err")))
    W.shot(out)
  end

  @testset "the program lets content with a width of its own be as narrow as the page" begin
    # Outlook gives the table round an email the width of its sender's window. The words wrap at the page all the same.
    words = "Hi Jake, these words go on and on, as words in an email do, so that they need more than one line. " ^ 10
    outlook = """<table width="1938" style="width:1453.8pt"><tr><td width="1938" style="width:1453.8pt"><p>$words</p>
                 <table width="600"><tr><td width="300">Left</td><td width="300"><a href="https://example.com/right">Right</a></td></tr></table>
                 </td></tr></table>"""
    s = drawn(outlook)
    @test s.wide == 700 && s.tall > 100
    # A cell whose width fits the page keeps it
    @test only(s.links).left > 300 && only(s.links).left + only(s.links).wide < 700
    # A picture that's wider than the page shrinks to it, and keeps its shape. A link round it says how big it is.
    s = drawn("""<p><a href="https://example.com/p" style="display:inline-block"><img width="1500" height="300" alt="A wide picture"></a></p>""")
    @test s.wide == 700 && only(s.links).wide <= 692 && only(s.links).tall < 200
    # A long word, like a key, goes on in the next line
    @test drawn("<p>" * "abcdefghij" ^ 200 * "</p>").wide == 700
    # Content that can't be as narrow as the page makes the page wider
    s = drawn("""<div style="display:flex"><div style="flex:none;width:500px">One</div><div style="flex:none;width:500px">Two</div></div>""")
    @test s.wide >= 1000
    # Content that fits is drawn as it is
    @test drawn("""<table width="600"><tr><td>Short</td></tr></table>""").wide == 700
  end

  @testset "the program makes a page as tall as its content" begin
    # A page is never shorter than its window, and the program's window was 600 px tall
    @test drawn("<p>One line.</p>").tall < 100
    @test 1000 < drawn("<p>A line.</p>" ^ 60).tall < 3000
  end

  @testset "the program says where the page's words are" begin
    dir = mktempdir()
    "What the program makes of `html` at the zoom `zoom`"
    drawn(html, zoom) = begin
      source, out = joinpath(dir, "$zoom.html"), joinpath(dir, "$zoom.txt")
      write(source, html)
      wait(W.run_program(source, 700, zoom, false, joinpath(dir, "$zoom"), out, joinpath(dir, "$zoom.err")))
      W.shot(out)
    end
    # Text that doesn't show isn't there: hidden, cut off by a box of no height, or see-through, as the line
    # of an email that only shows in a list of emails often is. Spaces that HTML draws as one are one.
    html = """<p>Hi <b>Jake</b>,   the
              quote</p><table><tr><td>One</td><td>Two</td></tr></table>
              <div style="display:none">Hidden</div><div style="max-height:0;overflow:hidden">Cut off</div>
              <span style="opacity:0">Clear</span><pre>a\n  b</pre><p>Line<br>break</p>"""
    s = drawn(html, 1.0)
    @test S.copied(s.words, 0, S.letter_count(s.words)) == "Hi Jake, the quote\nOne\tTwo\na\n  b\nLine\nbreak"
    # The first line starts at the page's margin, and its letters go left to right
    line1 = s.words[1]
    @test String(line1.letters) == "Hi Jake, the quote" && isapprox(line1.edges[1], 8, atol=1) && issorted(line1.edges)
    @test 10 < line1.tall < 30 && line1.top > 0 && all(w -> w.top >= line1.top + line1.tall - 1, s.words[2:end])
    # With a zoom, the words are where the page draws them, in its px after the zoom. A letter of a bigger
    # font isn't quite as much wider as the zoom says, so the letters can be a px or so from that.
    big = drawn(html, 2.0)
    @test isapprox(big.words[1].edges ./ 2, line1.edges, atol=2) && isapprox(big.words[1].top / 2, line1.top, atol=1)
  end
end

@testset "a link opens with the Mac's app for it" begin
  empty!(Fake.opened)
  W.open_link("https://example.com/a?b=c&d=e")
  @test Fake.opened == ["https://example.com/a?b=c&d=e"]
  # An opener that fails stops nothing
  W.OPENER[] = url -> error("no browser")
  @test W.open_link("https://example.com") === nothing
  W.OPENER[] = Fake.opener
end
