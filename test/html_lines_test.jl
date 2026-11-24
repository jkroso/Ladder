# Tests for HTML on lines of its own in a page: which lines are HTML, and how
# web/ draws them. See "HTML in a page" in main.jl. Run them with
# `julia -O0 --project=. test/html_lines_test.jl`. They use a window that
# isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a
# picture there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))

"A window that isn't on the screen, on a file with `text` in it"
window(text; name="page.md") = begin
  path = joinpath(dir, name)
  write(path, text)
  e = K.build_editor(path)
  w = Window(e, size=(900px, 700px))
  frames(w)
  e, w
end
frames(w, n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
shot(name, w) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

"The HTML that a page shows from line `i`, or nothing"
shown_html(e, i) = (it = K.item(e, i); it.content isa K.Live && it.content.node isa K.HTMLBlock ? it.content.node : nothing)

"The words of the HTML, as web/ laid them out"
html_words(v) = join((join(w.letters) for w in v.page.words), " ")

@testset "which lines of a page are HTML" begin
  e, _ = window("""
    +++
    description = "Lines of HTML"
    +++

    <h2 style="text-align: center">Politics and Economics</h2>

    A paragraph with <b>bold</b> words in it.
    <span>straight after a line of text</span>

    <img src="dot.png" width="40"/>

    <div>
    A div that goes on

    to an empty line.
    </div>

    <pre>
    A pre that goes on

    over an empty line.
    </pre>

    ```html
    <div>Code that's HTML</div>
    ```

    <span>after an empty line</span>

    <span>
    Words that come after a lone tag.
    """)
  b = e.buf
  runs = K.html_runs(b)
  at(text) = findfirst(==(text), b.lines)
  h2 = at("<h2 style=\"text-align: center\">Politics and Economics</h2>")
  @test runs[h2] == (h2, h2)
  # HTML in a line of text is part of the text, and so is a lone tag straight after a line of text
  @test runs[at("A paragraph with <b>bold</b> words in it.")] == (0, 0)
  @test runs[at("<span>straight after a line of text</span>")] == (0, 0)
  # A tag on its own after an empty line is HTML
  img = at("<img src=\"dot.png\" width=\"40\"/>")
  @test runs[img] == (img, img)
  # The HTML of a div goes on to the line before the next empty line
  div = at("<div>")
  @test runs[div] == (div, div + 1) && runs[div + 2] == (0, 0) && runs[at("to an empty line.")] == (0, 0)
  # The HTML of a pre goes on to the line that closes it, over the empty line
  pre = at("<pre>")
  @test runs[pre] == (pre, at("</pre>")) && runs[pre + 2] == (pre, at("</pre>"))
  # HTML in a code block is code
  @test runs[at("<div>Code that's HTML</div>")] == (0, 0)
  # A tag with words after it isn't on its own, so the line is text. The lines after a lone tag are part of its HTML.
  @test runs[at("<span>after an empty line</span>")] == (0, 0)
  span = at("<span>")
  @test runs[span] == (span, span + 1)
  # A pre with nothing that closes it is no HTML
  e2, _ = window("<pre>\nNever closed\n", name="open.md")
  @test K.html_runs(e2.buf) == [(0, 0), (0, 0), (0, 0)]
end

@testset "a heading written in HTML shows as a heading, in the middle of the page" begin
  e, w = window("""
    Text before it.

    <h2 style="text-align: center">Politics and Economics</h2>

    Politics regards the way we allocate resources.

    <p>Words of HTML.</p>
    """)
  v = shown_html(e, 3)
  @test v !== nothing
  @test K.item(e, 3).first == 3 && K.item(e, 3).last == 3
  # web/ laid the words out, with no tag to be seen
  @test html_words(v) == "Politics and Economics"
  @test !occursin("<h2", html_words(v))
  # In the middle of the page: as much room on its left as on its right
  word = v.page.words[1]
  left, right = first(word.edges), last(word.edges)
  wide = K.num(e.width)
  @test left > 50 && isapprox(left, wide - right, atol=2)
  # It's as much bigger than the page's text as the page's headings of its level are
  p = shown_html(e, 7)
  @test html_words(p) == "Words of HTML."
  @test isapprox(word.tall / p.page.words[1].tall, K.HEADINGS[2], rtol=0.05)
  # The lines round it show as text
  @test K.item(e, 1).content isa K.Flow && K.item(e, 5).content isa K.Flow
  shot("html_heading.png", w)
end

@testset "a picture that HTML names from the page's folder shows" begin
  # A picture 40 px by 20 px, red
  png = joinpath(dir, "dot.png")
  K.Web.save(K.Web.page("<div style=\"width:40px;height:20px;background:red\"></div>"; wide=40), png, scale=1.0)
  e, w = window("""
    <img src="dot.png" width="80" style="border: 1px solid black"/>

    After it.
    """, name="picture.md")
  v = shown_html(e, 1)
  @test v !== nothing
  @test v.page.tall >= 40
  @test any(p -> p.second !== nothing, v.store.found)
  shot("html_picture.png", w)
end

@testset "a click on a link of the HTML follows it as a link of the text does" begin
  write(joinpath(dir, "other.md"), "# Other page\n")
  e, w = window("""
    <p style="text-align: right"><a href="other.md">The other page</a></p>
    """, name="link.md")
  v = shown_html(e, 1)
  @test v !== nothing && length(v.page.links) == 1
  url = v.page.links[1].url
  @test startswith(url, "file://") && endswith(url, "/other.md")
  K.html_follow!(e, url)
  frames(w)
  @test basename(e.buf.path) == "other.md"
end

@testset "the lines of the HTML show as they're written while the caret is in them" begin
  e, w = window("""
    First line.

    <div style="color: red">
    Red words.
    </div>
    """, name="typed.md")
  @test shown_html(e, 3) !== nothing
  # As plain text, the caret on one of its lines shows each of them as it's written
  e.plain = true
  e.buf.caret = e.buf.anchor = (4, 2)
  frames(w)
  @test shown_html(e, 3) === nothing
  @test K.item(e, 4).content isa K.Flow
  # And they show as HTML again when the caret leaves
  e.buf.caret = e.buf.anchor = (1, 0)
  frames(w)
  @test shown_html(e, 3) !== nothing
end

@testset "a page from a web server reads no file of the Mac" begin
  far = (buf=(path="https://example.com/notes/page.md",),)
  near = (buf=(path=joinpath(dir, "page.md"),),)
  @test K.html_file(far, "file:///etc/hosts") === nothing
  @test K.html_file(near, "file:///etc/hosts") == "/etc/hosts"
  # Ladder's own fonts are no file of the Mac's
  K.font_faces("Literata")
  font = first(K.LADDER_FONT_FILES)
  @test K.html_file(far, "file://" * replace(font, ' ' => "%20")) == font
end

@testset "an email's lines are never HTML" begin
  e, _ = window("""
    From: sam@example.com
    Subject: Hello

    <div>Typed as text</div>
    """, name="note.eml")
  @test all(==((0, 0)), K.html_runs(e.buf))
end
