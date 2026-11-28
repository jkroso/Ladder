# Tests for mime.jl: how an email is read, how it becomes a Markdown page, and
# how an email to send is written. Run them with `julia -O0 --project=. test/mime_test.jl`.
# They use no network and no email account.

@use Test: @test, @testset, @test_throws
@use Base64: base64encode
@use Dates: Dates, DateTime
@use Random: Random
@use "../files/mime" => M

# A page shows a date in the Mac's time zone, so the tests choose one
ENV["TZ"] = "Australia/Sydney"
ccall(:tzset, Cvoid, ())

"`s` as an email has it: each line ends with a carriage return and a line feed"
crlf(s) = replace(s, "\n" => "\r\n")
bytes(s) = Vector{UInt8}(codeunits(s))
unix(args...) = Dates.datetime2unix(DateTime(args...))
md(html; kw...) = split(M.markdown(html; kw...), '\n')

# こんにちは in ISO-2022-JP, and 你好 in GB2312
const KONNICHIWA = UInt8[0x1b, 0x24, 0x42, 0x24, 0x33, 0x24, 0x73, 0x24, 0x4b, 0x24, 0x41, 0x24, 0x4f, 0x1b, 0x28, 0x42]
const NIHAO = UInt8[0xc4, 0xe3, 0xba, 0xc3]

@testset "headers" begin
  m = M.message(crlf("""
    Subject: This is
     a folded
    \tsubject
    From: =?ISO-8859-1?Q?J=F6rg_M=FCller?= <joerg@example.de>
    To: =?utf-8?Q?Lee=2C_Sam?= <sam@example.com>, "Brown, Kim" <kim@example.com>
    X-Base64: =?UTF-8?B?Q2Fmw6kg4oKsNQ==?=
    X-Two: =?UTF-8?Q?a_long_subject_that_is_?=
     =?UTF-8?Q?cut_in_two?= and plain words
    X-Cut: =?UTF-8?B?4oI=?= =?UTF-8?B?rA==?=
    X-Japanese: =?ISO-2022-JP?B?$(base64encode(KONNICHIWA))?=
    X-Chinese: =?GB2312?B?$(base64encode(NIHAO))?= =?UTF-8?Q?_and_more?=
    X-Language: =?utf-8*en?q?Hello?=
    X-Not: =?UTF-8?X?nothing?= stays
    content-TYPE: Text/Plain; Charset="utf-8"

    Body
    """))
  @test M.header(m, "subject") == "This is a folded subject" && M.header(m, "SUBJECT") == "This is a folded subject"
  @test M.field(m, "from") == "=?ISO-8859-1?Q?J=F6rg_M=FCller?= <joerg@example.de>"
  @test M.header(m, "from") == "Jörg Müller <joerg@example.de>"
  @test M.header(m, "x-base64") == "Café €5"
  @test M.header(m, "x-two") == "a long subject that is cut in two and plain words"
  # A character that's cut between two words comes back whole
  @test M.header(m, "x-cut") == "€"
  @test M.header(m, "x-japanese") == "こんにちは"
  @test M.header(m, "x-chinese") == "你好 and more"
  @test M.header(m, "x-language") == "Hello" && M.header(m, "x-not") == "=?UTF-8?X?nothing?= stays"
  @test M.header(m, "x-missing") == ""
  @test m.type == "text/plain" && m.params["charset"] == "utf-8" && M.text(m) == "Body\r\n"
  @test length(m.headers) == 11 && first(m.headers[1]) == "Subject"
  # A header that was sent as bytes of ISO-8859-1, with no words to say so
  raw = [bytes("Subject: Caf"); 0xe9; bytes("\r\n\r\nHi")]
  @test M.header(M.message(raw), "subject") == "Café"
end

@testset "character sets" begin
  @test M.decode(UInt8[0x63, 0x61, 0x66, 0xe9, 0x20, 0x93, 0x68, 0x69, 0x94, 0x20, 0x80], "windows-1252") == "café “hi” €"
  @test M.decode(UInt8[0x63, 0x61, 0x66, 0xe9], "ISO-8859-1") == "café" && M.decode(UInt8[0x63, 0x61, 0x66, 0xe9], "") == "café"
  @test M.decode(bytes("café"), "UTF-8") == "café" && M.decode(bytes("café"), "us-ascii") == "café"
  @test M.decode(UInt8[0x61, 0xff, 0x62], "utf-8") == "a\ufffdb"
  @test M.decode(NIHAO, "gb2312") == "你好" && M.decode(KONNICHIWA, "ISO-2022-JP") == "こんにちは"
  @test M.decode(UInt8[0x8d, 0xa1, 0x93, 0xfa, 0x82, 0xcd], "Shift_JIS") == "今日は"
  # A character set that nothing knows reads as UTF-8 when it is UTF-8, and a name that's no name does no harm
  @test M.decode(bytes("café"), "x-nope") == "café" && M.decode(bytes("abc"), "bad name\0") == "abc"
  page = M.message([bytes("Content-Type: text/html\r\n\r\n<html><head><meta charset=\"iso-8859-1\"></head>caf"); 0xe9])
  @test endswith(M.text(page), "café")
  @test M.text(M.message([bytes("Content-Type: text/plain; charset=utf-8\r\n\r\n"); 0xef; 0xbb; 0xbf; bytes("Hi")])) == "Hi"
end

@testset "quoted-printable and base64" begin
  m = M.message(crlf("""
    Content-Type: text/plain; charset=iso-8859-1
    Content-Transfer-Encoding: Quoted-Printable

    Caf=E9 is open and this line is long so it is cut =
    here.=20
    A soft break with spaces after it =  \nends here. 2+2=4 and =ZZ stays.
    Last line="""))
  @test M.text(m) == "Café is open and this line is long so it is cut here. \r\nA soft break with spaces after it ends here. 2+2=4 and =ZZ stays.\r\nLast line"
  @test M.unbase64(codeunits("SGVs\r\nbG8=")) == bytes("Hello") && M.unbase64(codeunits("SGVs*bG8")) == bytes("Hello")
  # Two pieces of base64, one after another, each with its own padding
  @test M.unbase64(codeunits("SGk=SGk=")) == bytes("HiHi") && isempty(M.unbase64(codeunits("!!!")))
  m = M.message("Content-Transfer-Encoding: base64\n\nSGVs*bG8=\n!!!\n")
  @test M.text(m) == "Hello"
end

const QUOTE = crlf("""
  From: Sam Lee <sam@example.com>
  To: you@example.com
  Cc: "Brown, Kim" <kim@example.com>
  Subject: Roof quote
  Date: Sat, 14 Nov 2026 09:32:00 +1100
  Message-ID: <1@example.com>
  MIME-Version: 1.0
  Content-Type: multipart/mixed; boundary="outer"

  This line is for an app that can't read the parts.
  --outer
  Content-Type: multipart/related; boundary="rel"

  --rel
  Content-Type: multipart/alternative; boundary=alt

  --alt
  Content-Type: text/plain; charset=utf-8

  Hi Jake,

  The quote is attached.
  --alt
  Content-Type: text/html; charset=utf-8
  Content-Transfer-Encoding: quoted-printable

  <html><body><p>Hi Jake,</p><p>The quote is <b>attached</b>.</p><img src=3D"cid:logo@x" alt=3D"Logo"></body></html>
  --alt--
  --rel
  Content-Type: image/png; name="logo.png"
  Content-ID: <logo@x>
  Content-Disposition: inline; filename="logo.png"
  Content-Transfer-Encoding: base64

  iVBORw0KGgo=
  --rel--
  --outer
  Content-Type: application/pdf; name="Roof quote.pdf"
  Content-Disposition: attachment; filename="Roof quote.pdf"
  Content-Transfer-Encoding: base64

  JVBERi0x
  LjcK
  --outer
  Content-Type: application/pdf
  Content-Disposition: attachment;
   filename*0*=UTF-8''Caf%C3%A9%20;
   filename*1="(final).pdf"
  Content-Transfer-Encoding: base64

  JVBERi0xLjcK
  --outer
  Content-Type: application/pdf; name="Roof quote.pdf"
  Content-Transfer-Encoding: base64

  AAEC
  --outer
  Content-Type: message/rfc822

  Subject: Inner
  From: x@example.com

  The email that was sent on.
  --outer
  Content-Type: application/pgp-signature; name="signature.asc"

  -----BEGIN PGP SIGNATURE-----
  --outer--
  After the parts.
  """)

@testset "the parts of an email" begin
  m = M.message(QUOTE)
  @test m.type == "multipart/mixed" && isempty(m.body) && length(m.parts) == 6
  related = m.parts[1]
  @test related.type == "multipart/related" && [p.type for p in related.parts] == ["multipart/alternative", "image/png"]
  plain, html = related.parts[1].parts
  @test plain.type == "text/plain" && M.text(plain) == "Hi Jake,\r\n\r\nThe quote is attached."
  @test html.type == "text/html" && occursin("<img src=\"cid:logo@x\" alt=\"Logo\">", M.text(html))
  logo = related.parts[2]
  @test logo.name == "logo.png" && logo.id == "logo@x" && logo.inline && logo.body == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
  @test m.parts[2].name == "Roof quote.pdf" && !m.parts[2].inline && m.parts[2].body == bytes("%PDF-1.7\n")
  # A name that was sent in pieces, the first of them as bytes of UTF-8
  @test m.parts[3].name == "Café (final).pdf" && m.parts[3].type == "application/pdf"
  @test m.parts[5].type == "message/rfc822" && isempty(m.parts[5].parts)
  @test String(copy(m.parts[5].body)) == "Subject: Inner\r\nFrom: x@example.com\r\n\r\nThe email that was sent on."
  # A name in a Content-Type in words, and one in a single piece with its character set
  named = M.message("Content-Type: application/pdf; name=\"=?UTF-8?B?$(base64encode("Café.pdf"))?=\"\n\nx")
  @test named.name == "Café.pdf"
  named = M.message("Content-Disposition: attachment; filename*=iso-8859-1'en'Caf%E9.pdf; filename=\"Cafe.pdf\"\n\nx")
  @test named.name == "Café.pdf"
  # The parts of a digest are emails
  digest = M.message("Content-Type: multipart/digest; boundary=d\n\n--d\n\nSubject: One\n\nText\n--d--\n")
  @test digest.parts[1].type == "message/rfc822"
end

@testset "the page of an email" begin
  kept = Any[]
  keep(name, data, picture) = (push!(kept, (name, length(data), picture)); "files/x/$name")
  @test M.page(M.message(QUOTE); keep) == [
    "---",
    "from: Sam Lee <sam@example.com>",
    "to: you@example.com",
    "cc: \"Brown, Kim\" <kim@example.com>",
    "date: 14 Nov 2026, 9:32 am",
    "subject: Roof quote",
    "---",
    "",
    "Hi Jake,",
    "",
    "The quote is **attached**.",
    "",
    "![Logo](files/x/logo.png)",
    "",
    "[Roof quote.pdf](files/x/Roof%20quote.pdf)",
    "[Café (final).pdf](files/x/Café%20%28final%29.pdf)",
    "[Roof quote 2.pdf](files/x/Roof%20quote%202.pdf)",
    "[message.eml](files/x/message.eml)"]
  # The picture that the text shows is kept first, each file is kept once, and the signature isn't a file
  @test kept == [("logo.png", 8, true), ("Roof quote.pdf", 9, false), ("Café (final).pdf", 9, false), ("Roof quote 2.pdf", 3, false),
                 ("message.eml", 66, false)]
  # Without `keep`, the page has the text and no links
  @test M.page(M.message(QUOTE))[end] == "The quote is **attached**."
  # `keep` chooses which files the page links to
  lines = M.page(M.message(QUOTE), keep=(name, data, picture) -> picture ? nothing : "f/$name")
  @test !any(l -> occursin("logo", l), lines) && lines[end] == "[message.eml](f/message.eml)"

  # Plain text alone: the lines as they were sent, with no spaces at their ends and one empty line at the most
  m = M.message(crlf("""
    From: "Sam Lee" <sam@example.com>
    Subject: =?UTF-8?Q?Caf=C3=A9?=
    Date: 14 Nov 2026 09:32 GMT

    Hi Jake,  \n


    > What you wrote
    ``` not the start of code
    -- \nSam

    """))
  @test M.page(m) == ["---", "from: Sam Lee <sam@example.com>", "date: 14 Nov 2026, 8:32 pm", "subject: Café", "---", "",
                      "Hi Jake,", "", "> What you wrote", "\u200b``` not the start of code", "--", "Sam"]
  # Lines that the sender cut for narrow windows are joined again
  flowed = M.message(crlf("""
    Content-Type: text/plain; charset=utf-8; format=flowed

    This is a paragraph that the sender cut \nin two lines.

    > A line of a quote that is \n> cut too.
     From a line that had a space put before it
    """))
  @test M.page(flowed)[5:end] == ["", "This is a paragraph that the sender cut in two lines.", "", "> A line of a quote that is cut too.",
                                  "From a line that had a space put before it"]
  # An email with no date shows the time that the caller gives, and one with nothing at all is still a page
  @test M.page(M.message("Subject: Hi\n\nText"), at=unix(2026, 11, 13, 22, 32))[3] == "date: 14 Nov 2026, 9:32 am"
  @test M.page(M.message(UInt8[])) == ["---", "from:", "subject:", "---", ""]
  @test M.page(M.message("From: Mailer Daemon\nSubject: a\n  b\n\n")) == ["---", "from: Mailer Daemon", "subject: a b", "---", ""]
  # Text, a picture and more text, as Apple Mail sends them: both texts, then the picture
  mixed = M.message(crlf("""
    Content-Type: multipart/mixed; boundary=b

    --b
    Content-Type: text/plain

    Before
    --b
    Content-Type: image/jpeg
    Content-Disposition: inline

    /9j/
    --b
    Content-Type: text/plain

    After
    --b
    Content-Type: text/plain; name="notes.txt"
    Content-Disposition: attachment; filename="../../notes: <1>.txt"

    The notes
    --b--
    """))
  kept = Any[]
  lines = M.page(mixed, keep=(name, data, picture) -> (push!(kept, name => picture); name))
  @test lines[6:end] == ["Before", "", "After", "", "![attachment.jpg](attachment.jpg)", "[-..-notes- -1-.txt](-..-notes-%20-1-.txt)"]
  @test kept == ["attachment.jpg" => true, "-..-notes- -1-.txt" => false]
end

@testset "the HTML of an email, for a browser to draw" begin
  # The HTML as it was sent, with the picture that came inside the email written into it
  @test M.webpage(M.message(QUOTE)) ==
        "<html><body><p>Hi Jake,</p><p>The quote is <b>attached</b>.</p><img src=\"data:image/png;base64,iVBORw0KGgo=\" alt=\"Logo\"></body></html>"
  # An email with no HTML has none, whatever else it has
  @test M.webpage(M.message("Subject: Hi\r\n\r\nPlain text with <b>no</b> HTML.")) == ""
  @test M.webpage(M.message("Subject: Hi\r\nContent-Type: application/pdf\r\n\r\n%PDF")) == "" && M.webpage(M.message("")) == ""
  # A picture from a web site keeps its address, and so does a cid: that names no part of the email. The name of a part is read in any case.
  m = M.message(crlf("""
    Content-Type: multipart/related; boundary=r

    --r
    Content-Type: text/html; charset=iso-8859-1

    <p>Caf\xe9 <img src='CID:A@B'><img src=cid:gone><img src="https://example.com/logo.png?cid:a@b"></p>
    --r
    Content-Type: image/gif
    Content-ID: <a@b>
    Content-Transfer-Encoding: base64

    R0lGODlh
    --r--
    """))
  @test M.webpage(m) == "<p>Café <img src='data:image/gif;base64,R0lGODlh'><img src=cid:gone><img src=\"https://example.com/logo.png?cid:a@b\"></p>"
  # Text that came beside the HTML, and isn't another way to say it, is in the page as it was typed
  m = M.message(crlf("""
    Content-Type: multipart/mixed; boundary=m

    --m
    Content-Type: text/plain

    1 < 2 & 3 > 2
      kept as typed
    --m
    Content-Type: text/html

    <p>Then <b>HTML</b></p>
    --m--
    """))
  @test M.webpage(m) == "<pre style=\"white-space: pre-wrap; font: inherit\">1 &lt; 2 &amp; 3 &gt; 2\r\n  kept as typed</pre>\n<p>Then <b>HTML</b></p>"
end

@testset "broken emails" begin
  # No empty line between the headers and the text
  m = M.message("Subject: Hi\nFrom: a@example.com\nHello there\nSecond line")
  @test M.header(m, "subject") == "Hi" && M.text(m) == "Hello there\nSecond line"
  # The line that closes the last part is missing, and so is the one that closes the email
  m = M.message("Content-Type: multipart/mixed; boundary=b\n\n--b\nContent-Type: text/plain\n\nOne\n--b\nContent-Type: text/html\n\n<p>Two</p>")
  @test [p.type for p in m.parts] == ["text/plain", "text/html"] && M.text(m.parts[1]) == "One" && M.text(m.parts[2]) == "<p>Two</p>"
  @test M.page(m)[end] == "Two"
  # It says it has parts, and nothing divides it
  m = M.message("Content-Type: multipart/mixed; boundary=b\n\nJust text")
  @test m.type == "text/plain" && M.text(m) == "Just text"
  m = M.message("Content-Type: multipart/mixed\n\nNo boundary")
  @test m.type == "text/plain" && M.page(m)[end] == "No boundary"
  # A part with nothing in it, and a type that's no type
  m = M.message("Content-Type: multipart/mixed; boundary=b\n\n--b\n--b\nContent-Type: nonsense\n\nText\n--b--")
  @test length(m.parts) == 2 && isempty(m.parts[1].body) && m.parts[2].type == "text/plain"
  # Parts in parts without end
  deep = join("Content-Type: multipart/mixed; boundary=b$k\n\n--b$k\n" for k in 1:60) * "Content-Type: text/plain\n\nDeep"
  @test M.page(M.message(deep)) isa Vector{String}
  # Bytes that are no email at all
  Random.seed!(1)
  for n in (1, 10, 500)
    @test M.page(M.message(rand(UInt8, n))) isa Vector{String}
  end
  @test M.page(M.message("\n\n\n")) isa Vector{String} && M.sent(M.message("Date: soon\n\n")) === nothing
end

@testset "addresses" begin
  @test M.addresses("Sam Lee <sam@x.com>, b@y.com") == ["Sam Lee" => "sam@x.com", "" => "b@y.com"]
  @test M.addresses("\"Lee, Sam\" <sam@x.com>,\"Kim \\\"K\\\" Brown\"<kim@y.com>") == ["Lee, Sam" => "sam@x.com", "Kim \"K\" Brown" => "kim@y.com"]
  @test M.addresses("sam@x.com (Sam Lee), Kim Brown (the boss) <kim@y.com>") == ["Sam Lee" => "sam@x.com", "Kim Brown" => "kim@y.com"]
  @test M.addresses("Team: a@x.com, Bo <b@y.com>;, c@z.com") == ["" => "a@x.com", "Bo" => "b@y.com", "" => "c@z.com"]
  @test M.addresses("undisclosed-recipients:;") == [] && M.addresses("") == [] && M.addresses(" , ,") == []
  @test M.addresses("=?UTF-8?Q?Lee=2C_Sam?= <sam@x.com>") == ["Lee, Sam" => "sam@x.com"]
  @test M.addresses("=?ISO-8859-1?Q?J=F6rg?= <j@x.de>, <only@x.com>, sam@x.com <sam@x.com>") == ["Jörg" => "j@x.de", "" => "only@x.com", "" => "sam@x.com"]
  @test M.addresses("Sam Lee sam@x.com") == ["Sam Lee" => "sam@x.com"] && M.addresses("mailto:sam@x.com") == ["" => "sam@x.com"]
  @test M.listed(["Lee, Sam" => "sam@x.com", "" => "b@y.com", "Jörg" => "j@x.de"]) == "\"Lee, Sam\" <sam@x.com>, b@y.com, Jörg <j@x.de>"
  # What `listed` writes, `addresses` reads back
  people = ["Lee, Sam" => "sam@x.com", "Kim \"K\" Brown" => "kim@y.com", "" => "b@y.com", "Jörg (IT)" => "j@x.de"]
  @test M.addresses(M.listed(people)) == people && M.addresses(M.listed(people, worded=true)) == people
end

@testset "dates" begin
  @test M.moment("Sat, 14 Nov 2026 09:32:00 +1100") == unix(2026, 11, 13, 22, 32)
  @test M.moment("14 Nov 2026 09:32 GMT") == unix(2026, 11, 14, 9, 32) && M.moment("14 Nov 2026 09:32:05 UT") == unix(2026, 11, 14, 9, 32, 5)
  @test M.moment("Sat, 14 Nov 2026 09:32:00 -0500 (EST)") == unix(2026, 11, 14, 14, 32)
  @test M.moment("Sat (the weekend), 14 Nov 2026 (late) 09:32:00 +0000") == unix(2026, 11, 14, 9, 32)
  @test M.moment("14 Nov 26 09:32:00 PST") == unix(2026, 11, 14, 17, 32) && M.moment("1 Jan 99 00:00 +0000") == unix(1999, 1, 1)
  @test M.moment("Sat, 14 November 2026 9:32:60 +0530") == unix(2026, 11, 14, 4, 2, 59)
  @test M.moment("soon") === nothing && M.moment("31 Feb 2026 10:00:00 +0000") === nothing && M.moment("") === nothing
  @test M.stamp(unix(2026, 11, 13, 22, 32)) == "14 Nov 2026, 9:32 am" && M.stamp(unix(2026, 6, 1, 4, 5)) == "1 Jun 2026, 2:05 pm"
end

@testset "HTML as Markdown" begin
  @test md("<p>Hello <b>bold</b> and <i>italic</i> and <a href=\"https://example.com/a b\">a link</a>.</p><p>Second</p>") ==
        ["Hello **bold** and *italic* and [a link](https://example.com/a%20b).", "", "Second"]
  @test md("one<br>two<br/><br>three<BR><br><br>four") == ["one", "two", "", "three", "", "four"]
  @test md("<h1>Title</h1><h3><b>Sub</b> part</h3>text<h2>Two<br>lines</h2>") == ["# Title", "", "### Sub part", "", "text", "", "## Two", "## lines"]
  # The spaces round bold text go outside its marks, and a run of white space is one space
  @test md("<b> spaced </b>word<i></i> <strong><em>both</em></strong>") == ["**spaced** word ***both***"]
  @test md("a&nbsp;&nbsp;  b\n\t c\u200b\u00ad d") == ["a b c d"]
  @test md("<span style=\"font-weight: 700\">heavy</span> <span style=\"font-style:italic\">slanted</span> <del>old</del> <u>new</u>") ==
        ["**heavy** *slanted* ~~old~~ new"]
  @test md("&amp; &lt;tag&gt; &copy; &#8217; &#x20AC; &#146; &unknown; &eacute;&Eacute; AT&T &#0; &#99999999;") ==
        ["& <tag> © ’ € ’ &unknown; éÉ AT&T \ufffd \ufffd"]
  # Links
  @test md("<a href=\"https://x.com\">https://x.com</a> <a href=\"mailto:sam@x.com\">sam@x.com</a>") ==
        ["[https://x.com](https://x.com) [sam@x.com](mailto:sam@x.com)"]
  @test md("<a href=\"\">none</a> <a href=\"#top\">Top</a> <a>bare</a> <a href=\"javascript:go()\">go</a>") == ["none Top bare go"]
  @test md("<a href=\"https://x.com/(a)\"><b>Read</b> [more] </a>now") == ["[**Read** (more)](https://x.com/%28a%29) now"]
  @test md("<a href='https://x.com\n/long'>cut</a>") == ["[cut](https://x.com/long)"]
  # Pictures: none on the web shows, so that a sender can't tell when you read the email. In a line of text, the
  # picture's words stand for it. A line of nothing but pictures is left out, like a logo or a drawing.
  @test md("<p>Paid with <img src=\"https://x.com/visa.png\" alt=\"Visa\"> - 6941</p><p><img src=\"https://x.com/logo.png\" alt=\"A logo\"></p><p>Thanks</p>") ==
        ["Paid with Visa - 6941", "", "Thanks"]
  # ... and so are a picture's words beside the same words as text
  @test md("<p><img src=\"https://x.com/link.png\" alt=\"Link\"> Link</p>") == ["Link"]
  # An email that's all pictures has their words, at least
  @test md("<img src=\"https://x.com/chart.png\" alt=\"A chart\"> <img src=\"https://x.com/logo.png\">") == ["A chart"]
  @test md("<a href=\"https://x.com\"><img src=\"https://x.com/i.png\"></a>after") == ["after"]
  @test md("<a href=\"https://x.com\"><img src=\"https://x.com/i.png\" alt=\"Shop now\"></a>") == ["[Shop now](https://x.com)"]
  @test md("x<img src=\"https://t.x.com/o.gif\" alt=\"pixel\" width=\"1\" height=\"1\"><img alt=\"p\" src=\"https://t.x.com/o\" style=\"width:1px\">") == ["x"]
  @test md("<img src=\"data:image/png;base64,AAAA\" alt=\"inside\">text") == ["text"]
  asked = String[]
  picture(name) = (push!(asked, name); name == "logo@x" ? "files/a b/logo.png" : nothing)
  @test md("<p>See <img src=\"cid:logo@x\" alt=\"The [logo]\"> here<img src=\"CID:gone\"><img src=\"cid:logo@x\"></p>"; picture) ==
        ["See", "![The (logo)](files/a%20b/logo.png)", "here", "![logo](files/a%20b/logo.png)"]
  @test asked == ["logo@x", "gone", "logo@x"]
  @test_throws ErrorException M.markdown("<img src=\"cid:a\">", picture=name -> error("The disk is full"))
  # Lists
  @test md("<ul><li>One</li><li>Two<ul><li>Sub</li><li>Sub two</ul></li></ul><ol start=\"3\"><li>Three<li><p>Four</p><p>more</p></ol>after") ==
        ["- One", "- Two", "  - Sub", "  - Sub two", "", "3. Three", "4. Four", "   more", "", "after"]
  @test md("<li>alone</li>") == ["- alone"]
  # Quotes
  @test md("<p>Reply</p><blockquote type=\"cite\"><p>First</p><p>Second</p><blockquote>Deep<br>er</blockquote><ul><li>item</li></ul></blockquote>") ==
        ["Reply", "", "> First", ">", "> Second", ">", "> > Deep", "> > er", ">", "> - item"]
  # Code
  @test md("<p>Use <code>x = 1</code></p><pre>line 1\n  line &lt;2&gt;\n\n``` end\n</pre>after") ==
        ["Use `x = 1`", "", "```", "line 1", "  line <2>", "", "''' end", "```", "", "after"]
  @test md("<p>``` not code</p>~~~ nor this") == ["\u200b``` not code", "", "\u200b~~~ nor this"]
  # Rules. One at the very top would read as the start of front matter, so it's left out.
  @test md("a<hr>b") == ["a", "", "---", "", "b"] && md("<hr><p>a</p><hr>") == ["a", "", "---"]
  # What isn't the email's text
  @test md("<html><head><title>T</title><style>p{color:red}</style></head><body><script>if (a < b) alert('<p>')</script>" *
           "<!-- a <b>comment</b> -->shown<div style=\"DISPLAY: none\">hidden <div>deep</div></div><span hidden>no</span>" *
           "<p style=\"max-height:0px;overflow:hidden\">no</p><span class=\"preheader\">no</span><![if !mso]> yes<![endif]></body></html>") == ["shown yes"]
  # Short comments, self-closing raw tags, fallback elements, raw iframes and CDATA
  @test md("<!-->shown<!---> too") == ["shown too"]
  @test md("<html><head><title/></head><body><p>Hello</p></body></html>") == ["Hello"]
  @test md("<script src=\"a.js\"/>Hello</script>") == ["Hello"]
  @test md("shown<noframes><p>no</p></noframes><noembed><p>no</p></noembed>") == ["shown"]
  @test md("<iframe><iframe src=\"x\"></iframe>after") == ["after"] && M.markdown("<iframe>fallback") == ""
  @test md("<p><![CDATA[a > b]]></p><svg><![CDATA[no]]></svg>") == ["a > b"]
  # Tables: one that puts things beside each other becomes its cells. The short cells of a row go on one line,
  # with a — between two of them, whether or not the row was closed and whatever boxes the cells' words are in.
  @test md("<table><tr><td>Total</td><td>\$45.00</td></tr><tr><td>Tax<td>\$4.50<tr><td><p>A</p></td><td><p>B</p></td></tr></table>") ==
        ["Total — \$45.00", "Tax — \$4.50", "", "A — B"]
  # A line of an invoice, as Stripe writes one: tables in the cells, and cells that only make room
  @test md("<table><tr><td></td><td><table><tr><td>Claude</td></tr></table><table><tr><td height=3></td></tr></table><table><tr><td>Qty 1</td></tr></table></td>" *
           "<td></td><td align=right><table><tr><td>A\$309.09</td></tr></table></td></tr></table>") == ["Claude, Qty 1 — A\$309.09"]
  # More than two cells have a · between them, however long their links are
  @test md("<table><tr><td><a href=\"https://example.com/$("a"^80)\">Privacy</a></td><td><a href=\"https://example.com/b\">Terms</a></td><td>Help</td></tr></table>") ==
        ["[Privacy](https://example.com/$("a"^80)) · [Terms](https://example.com/b) · Help"]
  # Cells that each hold a name over what it's set to: a line for each
  @test md("<table><tr><td><p>Amount paid</p><p>\$6.31</p></td><td><p>Date paid</p><p>9 Nov</p></td></tr></table>") ==
        ["Amount paid — \$6.31", "", "Date paid — 9 Nov"]
  # A dot in a cell of its own, then words: an item of a list
  @test md("<table><tr><td>•</td><td>Add a vehicle</td></tr><tr><td>•</td><td>Send an enquiry</td></tr></table>") == ["- Add a vehicle", "- Send an enquiry"]
  # A row with a long cell stays as it is: a line for each cell
  @test md("<table><tr><td>$("word "^30)</td><td>Side</td></tr></table>") == [strip("word "^30), "Side"]
  # A short line that ends with a colon takes the short line after it
  @test md("<div>Order ID:</div><p>MTZ57</p><p>Notes:</p><p>$("long "^20)</p>") == ["Order ID: MTZ57", "", "Notes:", "", strip("long "^20)]
  # ... and one with headings becomes a table
  @test md("<p>Prices</p><table><thead><tr><th>Item</th><th>Price</th></tr></thead><tr><td><b>Tiles</b> | grey</td><td>\$400</td></tr><tr><td>Grout</td></tr></table>") ==
        ["Prices", "", "| Item | Price |", "| --- | --- |", "| **Tiles** \\| grey | \$400 |", "| Grout |  |"]
  # The paragraphs that Outlook writes, one for each line
  @test md("<p class=\"MsoNormal\">Line one<o:p></o:p></p><p class=\"MsoNormal\">Line two</p><p class=\"MsoNormal\"><o:p>&nbsp;</o:p></p>" *
           "<p class=MsoNormal>Line three<o:p/></p>") == ["Line one", "Line two", "", "Line three"]
  @test md("<div>one</div><div>two</div><div><br></div><div>&nbsp;</div><div>three</div>") == ["one", "two", "", "three"]
  @test md("He said <q>yes</q>. <sup>1</sup>") == ["He said “yes”. 1"]
  @test M.markdown("") == "" && M.markdown("   \n ") == "" && M.markdown("just text") == "just text"
end

const NEWSLETTER = """
  <!DOCTYPE html><html><head><title>Deals</title><style>.x{color:red}</style></head>
  <body style="margin:0">
  <div style="display:none;max-height:0;overflow:hidden">Save 20% this week only &zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;</div>
  <!--[if mso]><table><tr><td>For Outlook only</td></tr></table><![endif]-->
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
    <table role="presentation" width="600">
      <tr><td><a href="https://shop.example.com/?utm=1"><img src="https://cdn.example.com/logo.png" alt="Acme Tools" width="200"></a></td></tr>
      <tr><td><h1 style="margin:0">Spring sale</h1><p>Everything is <strong>20% off</strong> until Sunday.</p></td></tr>
      <tr><td>
        <table role="presentation"><tr>
          <td width="50%"><img src="https://cdn.example.com/drill.jpg" alt=""><p>Cordless drill</p><p>\$129</p></td>
          <td width="50%"><img src="https://cdn.example.com/saw.jpg" alt=""><p>Circular saw</p><p>\$99</p></td>
        </tr></table>
      </td></tr>
      <tr><td align="center"><a href="https://shop.example.com/sale" style="background:#c00;color:#fff">Shop the sale</a></td></tr>
      <tr><td style="font-size:12px">You get this email because you signed up.<br>
        <a href="https://shop.example.com/unsubscribe">Unsubscribe</a> &middot; <a href="https://shop.example.com/prefs">Preferences</a></td></tr>
    </table>
  </td></tr></table>
  <img src="https://track.example.com/open.gif?id=1" width="1" height="1" alt="">
  </body></html>
  """

const GMAIL_REPLY = """
  <div dir="ltr">Thanks Sam, that works.<div><br></div><div>Jake</div></div><br><div class="gmail_quote gmail_quote_container">\
  <div dir="ltr" class="gmail_attr">On Sat, 14 Nov 2026 at 09:32, Sam Lee &lt;<a href="mailto:sam@example.com">sam@example.com</a>&gt; wrote:<br></div>\
  <blockquote class="gmail_quote" style="margin:0px 0px 0px 0.8ex;border-left:1px solid rgb(204,204,204);padding-left:1ex">\
  <div dir="ltr">Hi Jake,<div><br></div><div>The quote is attached.</div></div></blockquote></div>
  """

@testset "real emails" begin
  @test md(NEWSLETTER) == [
    "[Acme Tools](https://shop.example.com/?utm=1)",
    "",
    "# Spring sale",
    "",
    "Everything is **20% off** until Sunday.",
    "",
    "Cordless drill — \$129",
    "",
    "Circular saw — \$99",
    "",
    "[Shop the sale](https://shop.example.com/sale)",
    "You get this email because you signed up.",
    "[Unsubscribe](https://shop.example.com/unsubscribe) · [Preferences](https://shop.example.com/prefs)"]
  @test md(GMAIL_REPLY) == [
    "Thanks Sam, that works.",
    "",
    "Jake",
    "",
    "On Sat, 14 Nov 2026 at 09:32, Sam Lee <[sam@example.com](mailto:sam@example.com)> wrote:",
    "",
    "> Hi Jake,",
    ">",
    "> The quote is attached."]
  # The reply that Apple Mail writes
  @test md("<html><body style=\"overflow-wrap: break-word;\">Sounds good.<br><div><br><blockquote type=\"cite\"><div>On 14 Nov 2026, at 9:32 am, " *
           "Sam Lee &lt;sam@example.com&gt; wrote:</div><br class=\"Apple-interchange-newline\"><div><div>Hi Jake,</div></div></blockquote></div><br></body></html>") ==
        ["Sounds good.", "", "> On 14 Nov 2026, at 9:32 am, Sam Lee <sam@example.com> wrote:", ">", "> Hi Jake,"]
end

@testset "HTML that breaks the rules" begin
  for html in ("<", "<<<>>>", "<p", "<a href=", "<a href=\"x", "</", "</p", "<!--", "<!-- x", "<![CDATA[", "<!doctype é", "<script>x</script é",
               "&", "&#;", "&#x;", "<b><i>cross</b></i>",
               "</div></div>text", "<table><td>no row", "<ul><ul><ul>", "<pre>open", "<pre><b>x</pre></b>", "<style>never closed", "<script>x",
               "<td>a</table></td>", "<img>", "<img src=cid:>", "<a><a><a>", "<p =x>", "<p a=b=c 'q'>t", "<blockquote><li><pre><h1>x", "\0<b>\0</b>",
               "<o:p/><v:shape/>text", "<h9>big</h9>", "<table><th>only", "<table><tr><th>a<th>b<tr><td><table><tr><td>in</table>")
    @test M.markdown(html) isa String
  end
  @test md("<b><i>cross</b></i> after") == ["***cross*** after"] && md("<pre>open\n text") == ["```", "open", " text", "```"]
  @test md("<p>one<p>two<div>three<p>four</div>five") == ["one", "", "two", "", "three", "", "four", "", "five"]
  # Any text at all gives text
  Random.seed!(2)
  bits = ["<", ">", "</", "/>", "p", "div", "table", "tr", "td", "th", "li", "ul", "ol", "a", "b", "pre", "blockquote", "img", "br", "h2", " ", "=",
          "\"", "'", "href", "src", "cid:x", "style", "display:none", "&", "amp;", "#", ";", "text", "é", "\n", "!--", "-->", "```", "|", "\u00a0"]
  @test all(M.markdown(join(rand(bits, 60))) isa String for _ in 1:400)
  @test all(M.markdown(String(rand(UInt8, 200))) isa String for _ in 1:50)
  # No two empty lines in a row, and none at the start or the end
  for _ in 1:200
    lines = md(join(rand(bits, 80)))
    lines == [""] && continue
    @test !isempty(lines[1]) && !isempty(lines[end]) && !any(k -> isempty(lines[k]) && isempty(lines[k+1]), 1:length(lines)-1)
  end
end

@testset "an email to send" begin
  dir = mktempdir()
  file = joinpath(dir, "Café plan (v2).pdf")
  other = joinpath(dir, "notes.xyz")
  data = (Random.seed!(3); rand(UInt8, 3000))
  write(file, data)
  write(other, "plain")
  words = "Hi Sam,\n\nThe café costs €500 = 2 × €250. " * "A long line of words that goes on and on. "^4 * "\n\ttabbed \nline with a space at its end \n.\nFrom here"
  html = "<p>Hi Sam,</p><p>The <b>café</b> costs €500.</p>"
  subject = "Angebot für das Café — €500 and a subject that is long enough to need more than one line of words"
  at = unix(2026, 11, 13, 22, 32, 7)
  raw = M.compose(from="Jörg Müller <joerg@example.de>", to="\"Lee, Sam\" <sam@example.com>, kim@example.com", cc="Zoë <zoe@example.com>",
                  bcc="secret@example.com", subject=subject, text=words, html=html, files=[file, other], reply="<1@example.com>",
                  references="<0@example.com>", id="<2@ladder.example>", at=at)
  sent = String(copy(raw))
  # Only ASCII, lines that end the way an email's do, and none that's too long. The people it's copied to in secret aren't in it.
  @test isascii(sent) && !occursin(r"(?<!\r)\n", sent) && !occursin(r"\r(?!\n)", sent) && all(l -> length(l) <= 78, split(sent, "\r\n"))
  @test !occursin("secret", sent) && !occursin(r"^bcc:"im, sent)
  @test occursin("\r\nDate: Sat, 14 Nov 2026 09:32:07 +1100\r\n", sent) && occursin("\r\nMIME-Version: 1.0\r\n", sent)
  m = M.message(raw)
  @test M.header(m, "subject") == subject && M.sent(m) == at
  @test M.addresses(m, "from") == ["Jörg Müller" => "joerg@example.de"]
  @test M.addresses(m, "to") == ["Lee, Sam" => "sam@example.com", "" => "kim@example.com"] && M.addresses(m, "cc") == ["Zoë" => "zoe@example.com"]
  @test M.header(m, "message-id") == "<2@ladder.example>" && M.header(m, "in-reply-to") == "<1@example.com>"
  @test M.header(m, "references") == "<0@example.com> <1@example.com>"
  @test m.type == "multipart/mixed" && [p.type for p in m.parts] == ["multipart/alternative", "application/pdf", "application/octet-stream"]
  plain, rich = m.parts[1].parts
  @test plain.type == "text/plain" && M.text(plain) == crlf(words) && rich.type == "text/html" && M.text(rich) == html
  @test m.parts[2].name == "Café plan (v2).pdf" && m.parts[2].body == data && !m.parts[2].inline
  @test m.parts[3].name == "notes.xyz" && m.parts[3].body == bytes("plain")
  # The page of the email that was written
  lines = M.page(m, keep=(name, _, _) -> "files/$name")
  @test lines[1:7] == ["---", "from: Jörg Müller <joerg@example.de>", "to: \"Lee, Sam\" <sam@example.com>, kim@example.com",
                       "cc: Zoë <zoe@example.com>", "date: 14 Nov 2026, 9:32 am", "subject: $subject", "---"]
  @test lines[8:end] == ["", "Hi Sam,", "", "The **café** costs €500.", "", "[Café plan (v2).pdf](files/Café%20plan%20%28v2%29.pdf)", "[notes.xyz](files/notes.xyz)"]

  # Plain text alone, to one person, in answer to nothing
  raw = M.compose(from="me@example.com", to="sam@example.com", subject="Hi", text="One line", id="<3@ladder.example>", at=at)
  m = M.message(raw)
  @test m.type == "text/plain" && m.params["charset"] == "UTF-8" && M.text(m) == "One line\r\n" && isempty(m.parts)
  @test M.header(m, "in-reply-to") == "" && M.header(m, "references") == "" && M.header(m, "cc") == "" && M.header(m, "to") == "sam@example.com"
  # An answer to an email that answered nothing, and one whose references name it already
  m = M.message(M.compose(from="me@example.com", to="sam@example.com", subject="Re: Hi", text="", reply="<1@x>", id="<4@x>"))
  @test M.header(m, "references") == "<1@x>" && M.text(m) == "\r\n"
  m = M.message(M.compose(from="me@example.com", to="", cc="sam@example.com", subject="", text="x", reply="<1@x>", references="<0@x> <1@x>", id="<5@x>"))
  @test M.header(m, "references") == "<0@x> <1@x>" && M.header(m, "to") == "" && M.header(m, "subject") == ""
  # Text with HTML and no files
  m = M.message(M.compose(from="me@example.com", to="sam@example.com", subject="Hi", text="a", html="<p>a</p>", id="<6@x>"))
  @test m.type == "multipart/alternative" && M.page(m)[end] == "a"
  # Every character of a long line of text that isn't ASCII comes back
  long = "日本語のテキスト。"^40
  @test M.text(M.message(M.compose(from="a@x.com", to="b@x.com", subject=long, text=long, id="<7@x>"))) == long * "\r\n"
  @test M.header(M.message(M.compose(from="a@x.com", to="b@x.com", subject=long, text=long, id="<7@x>")), "subject") == long
end
