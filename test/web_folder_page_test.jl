# Tests for a web folder's own page: the page `.ladder` in a folder on a web
# server, which gives the folder a kind as a folder's page does on the Mac.
# Ladder runs its code only for a site that you allow. See "a web folder's
# own page" in main.jl. Run them with
# `julia -O0 --project=. test/web_folder_page_test.jl`. A function of the
# tests stands in for `curl`, and another for the panel that asks you. The
# window isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "../remote" => Remote
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
K.BROWSER_FOLDER[] = joinpath(dir, "Browser")   # each page from the web goes in the test's own browser folder
const ran = joinpath(dir, "ran")   # each run of a site's page adds a line to this file

# What the stand-in for a server has at each address: the kind of file, the number it answers with, and the text
const SITE = Dict{String,Any}()
const asked = String[]   # each address that was asked for, in order
page!(address, text; type="text/markdown; charset=utf-8", status=200) = SITE[address] = (; type, status, text)

const asks = String[]    # each site that the panel asked about
const answer = Ref(false)

# The tests put these back when they end, for the tests that share their process
const was_getter, was_asker = K.PAGE_GETTER[], K.SITE_ASKER[]
K.PAGE_GETTER[] = (address, file, about) -> begin
  push!(asked, address)
  at = get(SITE, address, nothing)
  if at === nothing
    write(file, "Not found"); write(about, "$address\ntext/plain\n404\n")
  else
    write(file, at.text); write(about, "$address\n$(at.type)\n$(at.status)\n")
  end
  () -> true
end
K.SITE_ASKER[] = site -> (push!(asks, site); answer[])

"A .ladder page whose code notes that it ran, and gives the folder the kind `kind`"
ladder_page(kind) = """
  This site is a blog.

  ```julia
  open(io -> println(io, "ran"), $(repr(ran)), "a")
  $kind
  ```
  """
runs() = isfile(ran) ? length(readlines(ran)) : 0

page!("https://blog.test/", "# The blog\n\n[A post](essays/post.md)\n")
page!("https://blog.test/.ladder", ladder_page("Ladder.BlogDirectory"); type="")
page!("https://blog.test/essays/post.md", "# A post\n\nSome words.\n")
page!("https://blog.test/essays/other.md", "# Another post\n")
page!("https://blog.test/reviews/book.html", """
  +++
  title = "A book"
  rating = 4
  pubDate = 2012-01-14
  +++

  What I thought of it.
  """)
# A site whose server sends a page of HTML for any address, so it has no .ladder page
page!("https://html.test/a.md", "# A\n")
page!("https://html.test/.ladder", "<html><body>Home</body></html>"; type="text/html")
# A site whose .ladder page has no code
page!("https://words.test/a.md", "# A\n")
page!("https://words.test/.ladder", "Only words.\n"; type="text/plain")
# A site whose .ladder page fails
page!("https://broken.test/a.md", "# A\n")
page!("https://broken.test/.ladder", "```julia\nerror(\"no such kind\")\n```\n"; type="text/plain")
page!("https://plain.test/a/b.md", "# B\n")

const e = K.blank_editor()
const w = Window(e, size=(1000px, 800px))
# A page's code runs after a frame, and the next frame must see what it made, as MiniFB's own loop does
frames(n=4) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()
ladders() = filter(endswith("/.ladder"), asked)

@testset "the folders of an address" begin
  @test Remote.folders("https://example.com/a/b/c.md") == ["https://example.com/", "https://example.com/a/", "https://example.com/a/b/"]
  @test Remote.folders("https://example.com/a/") == ["https://example.com/", "https://example.com/a/"]
  @test Remote.folders("https://example.com") == ["https://example.com/"]
  @test Remote.folders("https://example.com/c.md?x=1#top") == ["https://example.com/"]
  @test Remote.folders("https://example.com/a%20b/c.md") == ["https://example.com/", "https://example.com/a%20b/"]
  @test Remote.folders("notes.md") == String[]
end

@testset "a site that you haven't answered for shows plain, and asks once" begin
  K.navigate!(e, "https://blog.test/essays/post.md")
  frames()
  @test K.web_address(e.buf.path) == "https://blog.test/essays/post.md"
  # The page of each folder that the page is in was asked for, from the top down
  @test ladders() == ["https://blog.test/.ladder", "https://blog.test/essays/.ladder"]
  # The panel asked about the site, once, and you said no
  @test asks == ["https://blog.test"]
  @test runs() == 0 && e.look == :own
  @test K.site_runs("https://blog.test") === false
  @test occursin("no\thttps://blog.test", read(K.sites_file(), String))
  # Another page of the same folder asks for no folder again, and the panel doesn't ask again
  K.navigate!(e, "https://blog.test/essays/other.md")
  frames()
  @test K.web_address(e.buf.path) == "https://blog.test/essays/other.md"
  @test length(ladders()) == 2 && length(asks) == 1 && runs() == 0 && e.look == :own
  o = K.text_object(e)
  @test o isa K.WebPage && o.parent isa K.WebFolder{K.FS.Directory} && o.parent.address == "https://blog.test/essays/"
  @test o.parent.parent isa K.WebFolder{K.FS.Directory} && o.parent.parent.parent === nothing
end

@testset "Run Site Code runs the page, and the blog looks as its site does" begin
  @test K.works_here(e, Val(:run_site_code)) && !K.works_here(e, Val(:stop_site_code))
  K.run_site_code!(e)
  frames()
  @test K.site_runs("https://blog.test") === true
  @test runs() == 1 && e.look == :site
  o = K.text_object(e)
  # The top of the site is the blog, and a folder in it is a section of it, as on the Mac
  @test o.parent isa K.WebFolder{K.BlogSection} && o.parent.parent isa K.WebFolder{K.BlogDirectory}
  # The blog's page itself looks as the site does
  K.navigate!(e, "https://blog.test/")
  frames()
  @test K.web_address(e.buf.path) == "https://blog.test/" && e.look == :site && runs() == 1
  @test K.text_object(e).parent isa K.WebFolder{K.BlogDirectory}
  # A page with a rating is a book review, which shows its title and stars
  K.navigate!(e, "https://blog.test/reviews/book.html")
  frames()
  rows = K.matter_rows(e.buf.lines, K.front_matter(e.buf.lines))
  o = K.text_object(e)
  @test K.matter_view(e, o.parent, o, rows) isa K.ReviewHead
  @test K.matter_view(e, o.parent, o, filter(r -> lowercase(r[2]) != "rating", rows)) === nothing
  # The page itself runs no code, and has no buttons that publish the blog
  @test K.page_blog_folder(e) === nothing && K.blog_part(e) == ()
end

@testset "Reload Page asks again, and a page that changed runs again" begin
  n = length(ladders())
  K.reload_page!(e)
  frames()
  @test length(ladders()) == n + 2 && runs() == 1   # the same page doesn't run again
  page!("https://blog.test/.ladder", ladder_page("Ladder.FS.Directory"); type="")
  K.reload_page!(e)
  frames()
  @test runs() == 2 && e.look == :own
  page!("https://blog.test/.ladder", ladder_page("Ladder.BlogDirectory"); type="")
  K.reload_page!(e)
  frames()
  @test runs() == 3 && e.look == :site
end

@testset "Stop Site Code makes the site's folders plain" begin
  @test K.works_here(e, Val(:stop_site_code)) && !K.works_here(e, Val(:run_site_code))
  K.stop_site_code!(e)
  frames()
  @test K.site_runs("https://blog.test") === false && e.look == :own
  @test K.text_object(e).parent isa K.WebFolder{K.FS.Directory}
  K.run_site_code!(e)
  frames()
  @test e.look == :site && runs() == 3   # the code that ran is still loaded
end

@testset "a folder's page of a blog shows its table as the folder's list on the Mac" begin
  table = """
    | Name | Description | Created | Modified |
    |---|---|---|---|
    | [essays](essays/) | Things I _think_ | 2025-07-04 | 2026-10-03 |
    | [Plans.md](Plans.md) (draft) | Not done | 2026-11-18 | 2026-11-21 |
    | [feed.jl](feed.rss) |  | 2025-07-06 | 2025-07-26 |
    """
  page!("https://blog.test/", "# The blog\n\nWords.\n\n" * table)
  page!("https://blog.test/essays/", table)   # a folder with no Readme has only its list, from the page's first line
  K.navigate!(e, "https://blog.test/")
  frames()
  @test K.web_address(e.buf.path) == "https://blog.test/" && e.look == :site
  v = e.nodes[(:web_listing, "https://blog.test/")]
  @test v isa K.WebListing && isempty(v.up)
  @test [x.name for x in v.entries] == ["essays", "Plans.md", "feed.jl"]
  @test [x.icon for x in v.entries] == [:folder, :draft, :julia]
  @test [x.path for x in v.entries] == ["https://blog.test/essays/", "https://blog.test/Plans.md", "https://blog.test/feed.rss"]
  @test v.entries[1].about == "Things I think" && K.Blogs.short(v.entries[1].made) == "04/07/25" && K.Blogs.short(v.entries[1].saved) == "03/10/26"
  # The list shows in place of the table, at the end of the page
  @test any(it -> it.content isa K.Live && it.content.node === v, e.layout)
  @test !any(it -> it.content isa K.Grid, e.layout)
  # A click on a line asks for its page. A section's list starts with a line that goes up to the blog's page.
  v.rows[(:entry, "https://blog.test/essays/")].act(w)
  frames()
  @test K.web_address(e.buf.path) == "https://blog.test/essays/"
  s = e.nodes[(:web_listing, "https://blog.test/essays/")]
  @test s.up == "https://blog.test/" && haskey(s.rows, (:up, "https://blog.test/"))
  @test any(it -> it.content isa K.Live && it.content.node === s, e.layout) && !any(it -> it.content isa K.Grid, e.layout)
  s.rows[(:up, "https://blog.test/")].act(w)
  frames()
  @test K.web_address(e.buf.path) == "https://blog.test/"
  # Each page in a folder of book reviews is a review
  reviews = K.WebFolder{K.BookReviewDirectory}("https://blog.test/reviews/", K.WebFolder{K.BlogDirectory}("https://blog.test/", nothing))
  @test [x.icon for x in K.web_entries(reviews, ["| [A book.md](A%20book.html) | Good | 2025-07-20 | 2025-07-20 |"])] == [:review]
  # A page that isn't a folder's own keeps its table, and so does a table with other headings
  page!("https://blog.test/essays/post.md", "# A post\n\n" * table)
  K.navigate!(e, "https://blog.test/essays/post.md")
  frames()
  @test K.web_address(e.buf.path) == "https://blog.test/essays/post.md" && any(it -> it.content isa K.Grid, e.layout)
  page!("https://blog.test/", "# The blog\n\n| Name | Age |\n|---|---|\n| Sam | 3 |\n")
  K.navigate!(e, "https://blog.test/")
  frames()
  @test any(it -> it.content isa K.Grid, e.layout)
  page!("https://blog.test/", "# The blog\n\n[A post](essays/post.md)\n")
  page!("https://blog.test/essays/post.md", "# A post\n\nSome words.\n")
end

@testset "a folder's page of a blog shows no front matter, as its site shows none" begin
  page!("https://blog.test/", "+++\nsite = \"https://blog.test\"\n+++\n\n# The blog\n\nWords.\n")
  page!("https://blog.test/essays/post.md", "+++\ndescription = \"A post\"\n+++\n\n# A post\n\nSome words.\n")
  K.navigate!(e, "https://blog.test/")
  frames()
  @test K.web_address(e.buf.path) == "https://blog.test/" && e.look == :site
  top = e.layout[1]
  @test top.first == 1 && top.last == 3 && top.tall == 0px && !(top.content isa K.Live)
  # A post keeps its card
  K.navigate!(e, "https://blog.test/essays/post.md")
  frames()
  top = e.layout[1]
  @test top.last == 3 && top.content isa K.Live && top.content.node isa K.MatterCard
  page!("https://blog.test/", "# The blog\n\n[A post](essays/post.md)\n")
  page!("https://blog.test/essays/post.md", "# A post\n\nSome words.\n")
end

@testset "a site with no page of code asks nothing" begin
  n = length(asks)
  K.navigate!(e, "https://html.test/a.md")
  frames()
  @test K.web_address(e.buf.path) == "https://html.test/a.md" && "https://html.test/.ladder" in asked
  @test isempty(K.WEB_FOLDER_PAGES["https://html.test/"].lines) && e.look == :own
  K.navigate!(e, "https://words.test/a.md")
  frames()
  @test K.web_address(e.buf.path) == "https://words.test/a.md" && !K.WEB_FOLDER_PAGES["https://words.test/"].code
  # A site that has no .ladder page asks nothing either
  K.navigate!(e, "https://plain.test/a/b.md")
  frames()
  @test K.web_address(e.buf.path) == "https://plain.test/a/b.md" && "https://plain.test/a/.ladder" in asked
  @test length(asks) == n && !K.works_here(e, Val(:stop_site_code)) && K.works_here(e, Val(:run_site_code))
end

@testset "a site that you allow runs its page, and a page that fails says so" begin
  answer[] = true
  K.navigate!(e, "https://broken.test/a.md")
  frames()
  @test asks[end] == "https://broken.test" && K.site_runs("https://broken.test") === true
  @test occursin("The .ladder page of broken.test stopped", K.FOLDER_PAGE_STOPPED[][1]) && occursin("no such kind", K.FOLDER_PAGE_STOPPED[][1])
  @test e.look == :own && K.text_object(e).parent isa K.WebFolder{K.FS.Directory}
end

@testset "a page on the Mac has no web folders" begin
  file = joinpath(dir, "mine.md")
  write(file, "# Mine\n")
  K.open!(e, file)
  frames()
  @test !(K.text_object(e) isa K.WebPage) && e.look == :own
end

K.PAGE_GETTER[], K.SITE_ASKER[] = was_getter, was_asker
K.BROWSER_FOLDER[] = ""
foreach(f -> delete!(K.WEB_FOLDER_PAGES, f), filter(f -> endswith(Remote.host(f), ".test"), collect(keys(K.WEB_FOLDER_PAGES))))
