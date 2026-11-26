# Tests for web/source.jl, which finds where the words of a page are in its
# HTML. Run them with `julia -O0 --project=. test/web_source_test.jl`. The
# page's words here are made by hand, one piece for each line, as a page's
# words are pieces with their places.

@use Test: @test, @testset
@use "../web/source" => S

"The words of a page that shows `lines`, one piece of words for each"
words(lines...) = begin
  out, from = Any[], 0
  for l in lines
    push!(out, (letters=collect(l), from=from))
    from += length(l)
  end
  out
end
"The place before the `n`th `what` in the page's words `ws`"
place(ws, what, n=1) = (t = String(reduce(vcat, [w.letters for w in ws])); r = findall(what, t)[n]; length(SubString(t, 1, prevind(t, first(r)))))
"The line and the column of the HTML where the `n`th `what` starts"
spot(html, what, n=1) = S.line_column(html, first(findall(what, html)[n]))

@testset "a place of the page's words is a line and a column of its HTML" begin
  html = "<!DOCTYPE html>\n<title>Tom's hat</title>\n<p>Tom &amp; <b>Sam</b>’s\n   <span>hat</span>, in   red.</p>"
  ws = words("Tom & Sam’s hat, in red.")
  s, p = S.seen(html), S.shown(ws)
  # A word in a tag of its own, after an entity
  @test S.line_column(html, S.start(s, p, place(ws, "Sam"))) == spot(html, "Sam")
  # A word on the next line of the file, after the spaces that the page shows as one
  @test S.line_column(html, S.start(s, p, place(ws, "hat"))) == spot(html, "hat</span>")
  @test S.line_column(html, S.finish(s, p, place(ws, "hat") + 3)) == (4, 13)
  # An entity is the letter that it's written as, from its & to after its ;
  @test S.start(s, p, place(ws, "&")) == first(findfirst("&amp;", html))
  @test S.finish(s, p, place(ws, "&") + 1) == last(findfirst("&amp;", html)) + 1
  # A column counts characters, not bytes: ’ is 3 bytes
  @test S.line_column(html, S.start(s, p, place(ws, "s hat"))) == (3, 25)
  # Capitals that CSS made, and a space that it took away, still match
  @test S.line_column(html, S.start(S.seen(html), S.shown(words("TOM & SAM’S HAT, IN RED.")), 6)) == spot(html, "Sam")
end

@testset "what a page doesn't show as words isn't matched" begin
  html = "<script>var Sam = 'Sam'</script><style>p::after { content: 'Sam' }</style><svg><title>Sam and Tom</title></svg>\n<p>Sam and Tom</p>"
  ws = words("Sam and Tom")
  @test S.line_column(html, S.start(S.seen(html), S.shown(ws), 0)) == (2, 4)
end

@testset "words that the HTML has more times than the page shows them have no place, and the same words twice go in order" begin
  hidden = "<p>Paint the walls</p><p style='display:none'>Paint the walls</p>"
  @test S.start(S.seen(hidden), S.shown(words("Paint the walls")), 0) === nothing
  twice = "<p>Paint the walls</p>\n<p>Paint the walls</p>"
  ws = words("Paint the walls", "Paint the walls")
  @test S.line_column(twice, S.start(S.seen(twice), S.shown(ws), place(ws, "Paint", 2))) == (2, 4)
  # Words that a script wrote aren't in the HTML
  @test S.start(S.seen(twice), S.shown(words("Bought by a script")), 0) === nothing
end
