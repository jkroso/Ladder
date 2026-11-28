# Tests for blog.jl: what a post of a blog is, how it stands beside the site,
# and the address of the site. Run them with
# `julia -O0 --project=. test/blog_test.jl`. They open no window.

@use Test: @test, @testset
@use Dates: Date
@use "../folders/blog" => B

const dir = realpath(mktempdir())
page!(name, text) = (path = joinpath(dir, name); write(path, text); path)

@testset "a post" begin
  p = B.post(page!("2026-11-20-hello.md", "# Hello there\n\nWords.\n"))
  @test p.name == "2026-11-20-hello" && p.title == "Hello there" && p.day == Date(2026, 11, 20) && !p.draft
  # Front matter comes first: the title, the day, and whether it's a draft
  p = B.post(page!("shed.md", "---\ntitle: \"The shed\"\ndate: 2026-10-03\ndraft: true\n---\n\n# Another heading\n"))
  @test p.title == "The shed" && p.day == Date(2026, 10, 3) && p.draft
  # With neither, the title is the file's name, and the day is the day that the file was saved
  p = B.post(page!("plain.md", "Just words.\n"))
  @test p.title == "plain" && p.day == Date(Libc.strftime("%Y-%m-%d", time()))
  @test B.matter_keys(["# No front matter", "title: x"]) == Dict{String,String}()
  @test B.day("on 2026-13-40 and 2026-02-28") == Date(2026, 2, 28) && B.day("no day") === nothing
  @test B.long(Date(2026, 11, 3)) == "3 November 2026"
end

@testset "the posts of a folder" begin
  page!("index.md", "# Sam's blog\n\nHello.\n")
  page!("_notes.md", "# Not a post\n")
  page!(".hidden.md", "# Not a post\n")
  write(joinpath(dir, "picture.png"), "png")
  list = B.posts(dir)
  # The newest is first, and the first page, the hidden pages and the other files are no posts
  @test [p.name for p in list][end-1:end] == ["2026-11-20-hello", "shed"] && length(list) == 3 && list[1].name == "plain"
end

@testset "how a post stands beside the site" begin
  hello, shed = B.post(joinpath(dir, "2026-11-20-hello.md")), B.post(joinpath(dir, "shed.md"))
  @test B.standing(dir, hello) == :new && B.standing(dir, shed) == :draft
  mkpath(B.site(dir))
  write(B.page(dir, hello), "<html>")
  @test B.page(dir, hello) == joinpath(dir, "docs", "2026-11-20-hello.html") && B.standing(dir, hello) == :published
  # A post that's saved after its page was made has changed
  run(`touch -t 203001010000 $(hello.path)`)
  @test B.standing(dir, hello) == :changed
  @test B.words(:new) == "not on the site yet" && B.words(:published) == ""
end

@testset "the address of the site" begin
  @test B.address("git@github.com:sam/blog.git") == "https://sam.github.io/blog/"
  @test B.address("https://github.com/Sam/blog") == "https://sam.github.io/blog/"
  @test B.address("https://github.com/sam/sam.github.io.git\n") == "https://sam.github.io/"
  @test B.address("git@example.com:sam/blog.git") == "" && B.address("") == ""
end

@testset "the pages of the site" begin
  html = "<a href=\"shed.md\">Shed</a> <a href=\"two%20words.md#top\">Two</a> <a href=\"https://example.com/a.md\">Out</a> <a href=\"#here\">Here</a> <img src=\"pics/a b.png\"> <img src=\".media/x.png\"> <img src=\"https://example.com/y.png\">"
  made = B.linked(html)
  @test occursin("href=\"shed.html\"", made) && occursin("href=\"two%20words.html#top\"", made) && occursin("https://example.com/a.md", made)
  # The files that a page shows are the ones in the blog's own folder
  @test B.assets(made) == ["pics/a b.png", ".media/x.png"]
  @test B.assets("<img src=\"pics/a%20b.png\"><img src=\"pics/a%20b.png\">") == ["pics/a b.png"]
  list = [B.Post("/b/one.md", "one", "One", Date(2026, 11, 2), false), B.Post("/b/two words.md", "two words", "Two", Date(2026, 11, 1), false), B.Post("/b/d.md", "d", "Draft", Date(2026, 11, 3), true)]
  @test B.index(["# Blog", "", "Hello."], list) == ["# Blog", "", "Hello.", "", "- [One](one.md), 2 November 2026", "- [Two](two%20words.md), 1 November 2026"]
  page = B.framed("<head><title>one</title></head>\n<body>\n<p>Words</p></body>", "Sam&#39;s blog", "A \$5 title", list[1], heading=true)
  @test occursin("<title>A \$5 title</title>", page) && occursin("<body>\n<p style=", page) && occursin("← Sam&#39;s blog</a>", page)
  @test occursin("2 November 2026</p>\n<h1>A \$5 title</h1>\n<p>Words</p>", page)
  @test !occursin("<h1>", B.framed("<title>x</title><body>\n", "b", "t", list[1]))
end

# A blog like Jake's Canon: posts in folders, a Readme in each folder, TOML front matter, and a script of its own that publishes it
const canon = realpath(mktempdir())
at!(rel, text) = (path = joinpath(canon, rel); mkpath(dirname(path)); write(path, text); path)

@testset "front matter between lines of +++" begin
  p = B.post(at!("Humans/Dating.md", "+++\ndescription = \"How to, roughly\"\ncomplete = false\ndate = 2025-12-12\n+++\n\nWords.\n"))
  @test p.title == "Dating" && p.day == Date(2025, 12, 12) && p.draft && p.section == ""
  @test B.matter_keys(readlines(p.path))["description"] == "How to, roughly"
  @test B.after_matter(readlines(p.path)) == ["", "Words."] && B.after_matter(["# x"]) == ["# x"]
  p = B.post(at!("Book Reviews/The Selfish Gene.review", "+++\ntitle = \"The Selfish Gene\"\nrating = 5\n+++\n\nGenes.\n"), section="Book Reviews")
  @test p.name == "The Selfish Gene" && p.title == "The Selfish Gene" && p.section == "Book Reviews" && !p.draft
  # The code of a page has its title in an :h1, and its comments aren't headings
  p = B.post(at!("Civilization/Fairness.dom.jl", "# The sidenotes\n@dom[:div\n  [:h1 \"Fairness Matters\"]\n  [:p \"Words\"]]\n"))
  @test p.name == "Fairness" && p.title == "Fairness Matters"
end

@testset "a post's day is the day its file was made" begin
  path = at!("History/Chivalry.md", "Knights.\n")
  run(`touch -t 203001010000 $path`)   # saved again later
  @test B.made(path) <= time() + 1 && mtime(path) > time() + 86400
  @test B.post(path).day == Date(Libc.strftime("%Y-%m-%d", time()))
end

@testset "the sections of a blog" begin
  at!("Readme.md", "+++\nsite = \"https://words.example.com\"\n+++\n\nWelcome.\n")
  at!("Quotes.md", "Quotes.\n")
  at!("Humans/Readme.md", "+++\ndescription = \"People\"\n+++\n")
  at!("Humans/Relationships/On Men.md", "# On Men\n")
  at!("Civilization/democracy-proof/index.md", "# The Problem of Democracy\n")
  at!("_drafts/later.md", "# Later\n")
  at!(".remember/note.md", "# Hidden\n")
  at!("docs/old.md", "# In docs\n")
  # Without a script of its own, a blog's posts are its Markdown files, and Ladder's site in docs holds none
  names(list) = sort([(p.section, p.name) for p in list])
  @test names(B.posts(canon)) == [("", "Quotes"), ("Civilization/democracy-proof", "index"), ("History", "Chivalry"), ("Humans", "Dating"), ("Humans/Relationships", "On Men")]
  @test !B.itself(canon)
  at!(".bin/publish", "#!/bin/sh\necho sent\n")
  @test B.itself(canon)
  # A blog that publishes itself has its book reviews and the code of its pages as posts too, and docs is a section of it
  list = B.posts(canon, itself=true)
  @test names(list) == [("", "Quotes"), ("Book Reviews", "The Selfish Gene"), ("Civilization", "Fairness"), ("Civilization/democracy-proof", "index"), ("History", "Chivalry"), ("Humans", "Dating"), ("Humans/Relationships", "On Men"), ("docs", "old")]
  @test B.sections(list) == ["", "Book Reviews", "Civilization", "Civilization/democracy-proof", "History", "Humans", "Humans/Relationships", "docs"]
  # The Readme is the front page when there's no index.md, and it can say where the site is
  @test B.front(canon) == joinpath(canon, "Readme.md") && B.said_address(canon) == "https://words.example.com"
  at!("index.md", "# The index\n")
  @test B.front(canon) == joinpath(canon, "index.md") && B.said_address(canon) == ""
  rm(joinpath(canon, "index.md"))
end

@testset "how a post of a blog that publishes itself stands" begin
  quotes = B.post(joinpath(canon, "Quotes.md"))
  # Before Ladder has published it, Ladder can't tell
  @test B.standing(canon, quotes) == :unknown && B.words(:unknown) == ""
  @test B.standing(canon, quotes, sent=time() + 10) == :published
  @test B.standing(canon, quotes, sent=time() - 3600) == :new
  # A post that was made before the site was sent, and saved after, has changed
  @test B.standing(canon, quotes, sent=B.made(quotes.path) + 0.5) == (mtime(quotes.path) > B.made(quotes.path) + 0.5 ? :changed : :published)
  run(`touch -t 203001010000 $(quotes.path)`)
  @test B.standing(canon, quotes, sent=B.made(quotes.path) + 0.5) == :changed
end

@testset "the pages of a site with sections" begin
  men = B.Post("/b/Humans/Relationships/On Men.md", "On Men", "Humans/Relationships", "On Men", Date(2026, 1, 2), false)
  gene = B.Post("/b/Book Reviews/Gene.md", "Gene", "Book Reviews", "Gene", Date(2026, 1, 3), false)
  top = B.Post("/b/one.md", "one", "One", Date(2026, 1, 1), false)
  @test B.page("/b", men) == "/b/docs/Humans/Relationships/On Men.html" && B.home(men) == "../../index.html" && B.home(top) == "index.html"
  @test B.index(["+++", "site = \"x\"", "+++", "# Blog"], [men, gene, top]) ==
    ["# Blog", "", "- [One](one.md), 1 January 2026", "", "## Book Reviews", "", "- [Gene](Book%20Reviews/Gene.md), 3 January 2026", "", "## Humans / Relationships", "", "- [On Men](Humans/Relationships/On%20Men.md), 2 January 2026"]
  @test occursin("<a href=\"../../index.html\">← b</a>", B.framed("<body>\n", "b", "t", men))
end

@testset "the list of a folder of a blog" begin
  top = realpath(mktempdir())
  put!(rel, text="x") = (path = joinpath(top, rel); mkpath(dirname(path)); write(path, text); path)
  put!("Readme.md", "+++\ndescription = \"Welcome\"\n+++\n")
  put!("Zebra.md", "+++\ndescription = \"A *striped* [horse](https://example.com)\"\n+++\n")
  put!("apple.md", "+++\ncomplete = false\n+++\n")
  notes = put!("Notes/Readme.md", "+++\ndescription = \"Things I noted\"\n+++\n")
  put!("Notes/one.md", "12345")
  put!("Notes/.hidden.md", "1234567890")
  put!(".gitignore", "*.toml\n.bin\n"); put!(".canonignore", "# pictures\nimages/\n")
  foreach(put!, ("Project.toml", "images/a.png", "favicon.ico", "tracker.html", "feed.jl", "docs/index.html", "index.md"))
  # The site's own rules leave out hidden files, the Readme, and the names that the ignore files list. Capitals come first.
  list = B.listing(top)
  @test [x.name for x in list] == ["Notes", "Zebra.md", "apple.md", "docs", "feed.jl", "index.md"]
  @test [x.icon for x in list] == [:folder, :markdown, :draft, :folder, :julia, :markdown]
  # A folder is about what its Readme says, and is as big as the files that it holds, but the hidden ones
  @test list[1].about == "Things I noted" && list[2].about == "A striped horse" && list[1].bytes == filesize(notes) + 5
  @test list[2].made <= list[2].saved + 1
  # A blog that Ladder publishes leaves out the site that it writes, and its front page. A section's list doesn't.
  @test [x.name for x in B.listing(top, itself=false)] == ["Notes", "Zebra.md", "apple.md", "feed.jl"]
  @test [x.name for x in B.listing(joinpath(top, "Notes"), top, itself=false)] == ["one.md"]
  @test B.size_words(614) == "614 B" && B.size_words(3780) == "3.78 kB" && B.size_words(10150) == "10.15 kB" && B.size_words(1_950_000) == "1.95 MB" && B.size_words(1000) == "1 kB"
  @test occursin(B.glob("*.toml"), "Project.toml") && !occursin(B.glob("*.toml"), "a/b.toml") && occursin(B.glob(".bin/"), ".bin") && occursin(B.glob("a?c"), "abc")
  @test B.plain("A *b* [c](d) `e`") == "A b c e" && B.short(time()) == Libc.strftime("%d/%m/%y", time())
end
