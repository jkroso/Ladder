# Tests for a folder that's a blog, in main.jl: the folder's own page lists
# its pages as posts, and Publish makes each a page of HTML in the folder
# `docs`, commits that folder and pushes it. blog.jl says what a post is. Run
# them with `julia -O0 --project=. test/blog_folder_test.jl`. They make a
# repository in a temporary folder with the Mac's own git, with another
# folder as its remote, so nothing goes to the web. They draw a window that
# isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a picture there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use GeometryBasics: Vec2
const px = K.px

const dir = realpath(mktempdir())
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const blog = joinpath(dir, "blog")
const remote = joinpath(dir, "remote.git")
mkpath(joinpath(blog, "pics"))
git(args...; at=blog) = read(pipeline(setenv(`git -C $at $args`, merge(ENV, Dict("LC_ALL" => "C"))), stderr=devnull), String)
run(pipeline(`git init --bare -b main $remote`, stdout=devnull, stderr=devnull))
git("init", "-b", "main")
foreach(kv -> git("config", kv...), (("user.name", "Test"), ("user.email", "test@example.com"), ("commit.gpgsign", "false")))
git("remote", "add", "origin", remote)

const hello = joinpath(blog, "2026-11-20-hello.md")
const shed = joinpath(blog, "shed.md")
write(joinpath(blog, "index.md"), "# Sam's blog\n\nThings that I built.\n")
write(hello, "# Hello\n\nSee [the shed](shed.md).\n\n![A picture](pics/a.png)\n\n```sheet\nPosts = 2\nWords = posts * 300\n```\n")
write(shed, "---\ntitle: The shed\ndate: 2026-10-03\ndraft: true\n---\n\nNot done yet.\n")
write(joinpath(blog, "pics", "a.png"), read(joinpath(K.pages_dir[], "photos", "2 frame.png")))

const e = K.build_editor(hello)
const w = Window(e, size=(1000px, 800px))
# Each frame is drawn with the newest code, as the window's loop draws it
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
folder() = K.FS.get(FSPath(blog))
"Draw frames until the blog is published, as the window does while Publish works"
publish(folder=blog) = begin
  K.publish!(folder)
  started = time()
  while haskey(K.PUBLISHING, folder) && time() - started < 60
    frames(1)
    sleep(0.01)
  end
  frames()
end
site(name) = joinpath(blog, "docs", name)
sent(args...) = git(args...; at=remote)

@testset "Show Folder As makes the folder a blog" begin
  kind = only(filter(k -> k.name == "Blog", K.choices_for(K.KindChoice, e)))
  Base.invokelatest(K.show_folder_as!, e, folder(), kind)
  frames()
  # The window shows the blog's front page, with the list of the blog's folder under it, as its site would
  @test folder() isa K.BlogDirectory && e.buf.path == joinpath(blog, "index.md") && K.page_blog_folder(e) isa K.BlogDirectory && K.entry_icon(folder()) == "rss"
  l = e.nodes[(:listing, blog)]
  @test [K.Blogs.standing(blog, p) for p in K.blog_posts(blog)] == [:new, :draft]
  @test K.blog_name(blog) == "Sam's blog"
  # The list leaves out the front page. The top bar can publish the blog, and the site has no page to show yet.
  @test haskey(l.rows, (:entry, hello)) && haskey(l.rows, (:entry, joinpath(blog, "pics"))) && !haskey(l.rows, (:entry, joinpath(blog, "index.md")))
  @test !K.blog_off(e, :publish) && K.blog_off(e, :open_site) && !isempty(K.blog_part(e))
  shot("blog.png")
end

@testset "Publish writes the site" begin
  publish()
  @test !haskey(K.PUBLISHING, blog)
  page = read(site("2026-11-20-hello.html"), String)
  # The post is a page of HTML, with a link to the other post's page, and a way back to the first page
  @test occursin("<h1>Hello</h1>", page) && occursin("href=\"shed.html\"", page) && occursin("<a href=\"index.html\">← Sam's blog</a>", page)
  @test occursin("<title>Hello</title>", page) && occursin("20 November 2026", page)
  # The sheet went in as a table of what its rows come to, as ⌘⇧E writes it
  @test occursin("<td>600</td>", page)
  # The picture that the post shows is in the site, and the draft isn't
  @test read(site("pics/a.png")) == read(joinpath(blog, "pics", "a.png")) && !isfile(site("shed.html"))
  first = read(site("index.html"), String)
  @test occursin("<h1>Sam's blog</h1>", first)
  @test occursin("Things that I built.", first) && occursin("<a href=\"2026-11-20-hello.html\">Hello</a>, 20 November 2026", first) && !occursin("shed", first)
  @test isfile(site(".nojekyll")) && readlines(site(".ladder-site")) == ["2026-11-20-hello.html", "index.html"]
  @test [K.Blogs.standing(blog, p) for p in K.blog_posts(blog)] == [:published, :draft]
end

@testset "Publish commits the site and pushes it, and nothing else" begin
  @test startswith(K.PUBLISHED[blog], "Published 1 post.")
  @test occursin("Publish the blog", sent("log", "--format=%s", "main"))
  files = split(strip(sent("ls-tree", "-r", "--name-only", "main")), '\n')
  @test sort(files) == ["docs/.ladder-site", "docs/.nojekyll", "docs/2026-11-20-hello.html", "docs/index.html", "docs/pics/a.png"]
  # The posts' own files are still the user's to commit
  @test occursin("?? shed.md", git("status", "--short")) && occursin("?? 2026-11-20-hello.md", git("status", "--short"))
  @test !K.blog_off(e, :open_site)
  shot("blog-published.png")
end

@testset "a post that becomes a draft leaves the site" begin
  write(hello, "---\ndraft: true\n---\n\n" * read(hello, String))
  write(shed, replace(read(shed, String), "draft: true\n" => ""))
  empty!(K.BLOG_POSTS)
  publish()
  @test !isfile(site("2026-11-20-hello.html")) && isfile(site("shed.html"))
  page = read(site("shed.html"), String)
  # A post with no heading in its text has its title as the page's heading
  @test occursin("<h1>The shed</h1>", page) && occursin("3 October 2026", page)
  @test !occursin("Hello", read(site("index.html"), String))
  @test sort(split(strip(sent("ls-tree", "-r", "--name-only", "main")), '\n')) == ["docs/.ladder-site", "docs/.nojekyll", "docs/index.html", "docs/pics/a.png", "docs/shed.html"]
end

@testset "a blog with nowhere to send its site says so" begin
  git("remote", "remove", "origin")
  publish()
  @test occursin("no remote called origin", K.PUBLISHED[blog]) && isfile(site("shed.html"))
  @test K.blog_address(blog) == ""
end

@testset "a section of the blog, and a picture whose path has a space" begin
  mkpath(joinpath(blog, "notes"))
  cp(joinpath(blog, "pics", "a.png"), joinpath(blog, "pics", "a b.png"))
  tips = joinpath(blog, "notes", "2026-11-01-tips.md")
  write(tips, "# Tips\n\n![The shed](../pics/a b.png)\n\nSee [the shed](../shed.md).\n")
  empty!(K.BLOG_POSTS); empty!(K.SITE_LISTS)
  # The editor shows the picture: the line is a picture's, though its path has a space
  @test K.pictured(K.build_editor(tips).buf, 3)
  publish()
  page = read(site("notes/2026-11-01-tips.html"), String)
  # The post's page is in a folder of the section's name, and its links start from there, as the post's do
  @test occursin("<img src=\"../pics/a%20b.png\"", page) && occursin("<a href=\"../index.html\">← Sam's blog</a>", page)
  @test occursin("href=\"../shed.html\"", page)
  @test read(site("pics/a b.png")) == read(joinpath(blog, "pics", "a b.png"))
  first = read(site("index.html"), String)
  @test occursin(r"<h2[^>]*>notes</h2>", first) && occursin("<a href=\"notes/2026-11-01-tips.html\">Tips</a>", first)
  l = e.nodes[(:listing, blog)]
  @test haskey(l.rows, (:entry, joinpath(blog, "notes"))) && haskey(l.rows, (:entry, shed))
  shot("blog-sections.png")
  # The page of a post in a section goes from the site when the post becomes a draft
  write(tips, "---\ndraft: true\n---\n" * read(tips, String))
  empty!(K.BLOG_POSTS)
  publish()
  @test !isfile(site("notes/2026-11-01-tips.html")) && isfile(site("shed.html"))
end

@testset "a folder in a blog has a kind of its own" begin
  notes = joinpath(blog, "notes")
  # A folder in a blog is a section of it, until its own page says otherwise
  @test K.FS.get(FSPath(notes)) isa K.BlogSection
  kind = only(filter(k -> k.name == "Blog", K.choices_for(K.KindChoice, e)))
  Base.invokelatest(K.show_folder_as!, e, K.FS.get(FSPath(notes)), kind)
  frames()
  @test K.FS.get(FSPath(notes)) isa K.BlogDirectory && folder() isa K.BlogDirectory
end

@testset "a blog that publishes itself with its own script" begin
  canon = joinpath(dir, "Canon")
  mkpath(joinpath(canon, ".bin")); mkpath(joinpath(canon, "Humans"))
  write(joinpath(canon, "Readme.md"), "+++\nsite = \"https://canon.example.com\"\n+++\n\nWelcome.\n")
  write(joinpath(canon, "Quotes.md"), "Quotes.\n")
  write(joinpath(canon, "Humans", "Readme.md"), "+++\ndescription = \"People\"\n+++\n")
  write(joinpath(canon, "Humans", "Dating.md"), "+++\ncomplete = false\n+++\n\nWords.\n")
  write(joinpath(canon, "Humans", "Gene.review"), "+++\ntitle = \"The Selfish Gene\"\n+++\n\nGenes.\n")
  script = joinpath(canon, ".bin", "publish")
  write(script, "#!/bin/sh\n{ pwd; echo \"kip=\${KIP_FROZEN:-none}\"; echo \"\$PATH\"; } > sent.txt\necho Making the site\necho Sent it\n")
  chmod(script, 0o755)
  kind = only(filter(k -> k.name == "Blog", K.choices_for(K.KindChoice, e)))
  Base.invokelatest(K.show_folder_as!, e, K.FS.get(FSPath(canon)), kind)
  frames()
  l = e.nodes[(:listing, canon)]
  # A Readme with no title doesn't name the blog
  @test K.blog_name(canon) == "Canon"
  list = K.blog_posts(canon)
  @test sort([(p.section, p.title) for p in list]) == [("", "Quotes"), ("Humans", "Dating"), ("Humans", "The Selfish Gene")]
  @test e.buf.path == joinpath(canon, "Readme.md") && haskey(l.rows, (:entry, joinpath(canon, "Quotes.md"))) && haskey(l.rows, (:entry, joinpath(canon, "Humans")))
  # Before Ladder publishes it, the list can't say which posts the site hasn't got
  @test sort([K.blog_standing(canon, p) for p in list]) == [:draft, :unknown, :unknown]
  @test !K.blog_off(e, :publish) && !K.blog_off(e, :open_site)
  shot("canon.png")
  withenv("KIP_FROZEN" => "1") do
    publish(canon)
  end
  @test K.PUBLISHED[canon] == "Published. Your script .bin/publish made the site and sent it. The site is at https://canon.example.com"
  ran = readlines(joinpath(canon, "sent.txt"))
  # The script ran in the blog's folder, with a terminal's folders of commands, and without what the Julia of Ladder is told
  @test realpath(ran[1]) == realpath(canon) && ran[2] == "kip=none" && occursin(expanduser("~/.juliaup/bin"), ran[3])
  @test !isdir(joinpath(canon, "docs"))
  @test sort([K.blog_standing(canon, p) for p in list]) == [:draft, :published, :published]
  write(joinpath(canon, "Quotes.md"), "More quotes.\n")
  @test K.blog_standing(canon, K.Blogs.post(joinpath(canon, "Quotes.md"))) == :changed
  # A script that fails says why, in its last words
  write(script, "#!/bin/sh\necho Making the site\necho 'ssh: Could not resolve hostname raspberrypi.lan' >&2\nexit 255\n")
  publish(canon)
  @test K.PUBLISHED[canon] == "Your script .bin/publish stopped, and said: ssh: Could not resolve hostname raspberrypi.lan"
  shot("canon-stopped.png")
end

# The pages of the blog look as its site does, as jake.rosoman.info shows the folder Canon
const canon = joinpath(dir, "Canon")
const humans = joinpath(canon, "Humans")
const city = joinpath(canon, "City")
const review = joinpath(humans, "Gene.review")

@testset "a click on a section shows its page as the site does" begin
  write(review, "+++\ntitle = \"The Selfish Gene\"\nlink = \"https://en.wikipedia.org/wiki/The_Selfish_Gene\"\nrating = 4\npubDate = 1976-01-01\ndescription = \"Extends *Darwin's* theory\"\n+++\n\nGenes.\n")
  empty!(K.SITE_LISTS)
  e.panel = true
  frames()
  item(name) = only(i for i in K.file_tree(e).children if basename(i.firstchild.path) == name)
  # The sidebar lists the blog's folder. A click on Humans shows its Readme, with the list of the folder under it.
  K.choose!(e, item("Humans")); frames()
  @test e.folder == humans && e.buf.path == joinpath(humans, "Readme.md") && K.page_blog_folder(e) isa K.BlogSection
  l = e.nodes[(:listing, humans)]
  @test haskey(l.rows, (:up, canon)) && haskey(l.rows, (:entry, joinpath(humans, "Dating.md"))) && !haskey(l.rows, (:entry, joinpath(humans, "Readme.md")))
  entries = K.site_entries(humans, canon)
  @test [x.name for x in entries] == ["Dating.md", "Gene.review"] && [x.icon for x in entries] == [:draft, :review]
  @test entries[2].about == "Extends Darwin's theory"
  shot("canon-humans.png")
  # A click on a line shows its page, and the line at the top goes up to the blog's own page
  l.rows[(:entry, joinpath(humans, "Dating.md"))].act(w); frames()
  @test e.buf.path == joinpath(humans, "Dating.md")
  Base.invokelatest(K.open!, e, K.FS.get(FSPath(humans))); frames()
  l.rows[(:up, canon)].act(w); frames()
  @test e.buf.path == joinpath(canon, "Readme.md") && e.folder == canon
end

@testset "a section with no Readme shows only its list" begin
  mkpath(city)
  write(joinpath(city, "future city.md"), "+++\ndescription = \"If we started from scratch\"\n+++\n\nWords.\n")
  Base.invokelatest(K.open!, e, K.FS.get(FSPath(city))); frames()
  @test e.buf.path == city && e.buf.view == :file && K.page_object(e) isa K.BlogSection
  @test haskey(e.nodes[(:listing, city)].rows, (:entry, joinpath(city, "future city.md")))
  # The top bar has the blog's buttons in place of the words that say the page is only shown
  @test !isempty(K.blog_part(e))
  shot("canon-city.png")
end

@testset "a name too long for its column goes on to a second line, as on the site" begin
  long = joinpath(city, "Why Things Happened the Way They Did and Why They Will Again.md")
  write(long, "Words.\n")
  empty!(K.SITE_LISTS)
  Base.invokelatest(K.open!, e, K.FS.get(FSPath(city))); frames()
  rows = e.nodes[(:listing, city)].rows
  tall, short = rect(rows[(:entry, long)]), rect(rows[(:entry, joinpath(city, "future city.md"))])
  @test tall.height > short.height * 1.3
  shot("canon-long-name.png")
  rm(long)
  empty!(K.SITE_LISTS)
end

@testset "an agent asked about a line of the list is told what the line says" begin
  # The agent was told only that the part is a ListingRow and where its code is, so it couldn't tell which line was meant
  Base.invokelatest(K.open!, e, K.FS.get(FSPath(city))); frames()
  c = K.part_choice(e.nodes[(:listing, city)].rows[(:entry, joinpath(city, "future city.md"))])
  what, _ = K.thing_words(c)
  @test occursin("a ListingRow. It shows these words: \"future city.md\", \"If we started from scratch\"", what)
  @test occursin("The window shows $city.", what)
  @test occursin("\"If we started from scratch\"", K.either_prompt([c], "Is this spelt right?"))
  # A part that isn't drawn now shows no words
  @test K.shown_words(K.ListingRow()) == String[]
end

@testset "a section with its own index.md shows only that page, as its site does" begin
  proof = joinpath(canon, "Proof")
  mkpath(proof)
  write(joinpath(proof, "Readme.md"), "+++\ndescription = \"Why groups decide badly\"\n+++\n")
  write(joinpath(proof, "index.md"), "# The Fundamental Problem\n\nWords.\n")
  write(joinpath(proof, "red.png"), UInt8[1, 2, 3])
  empty!(K.SITE_LISTS)
  Base.invokelatest(K.open!, e, K.FS.get(FSPath(proof))); frames()
  # The index.md shows, and not the Readme, with no list under it
  @test e.buf.path == joinpath(proof, "index.md") && e.folder == proof && K.page_blog_folder(e) isa K.BlogSection
  @test !haskey(e.nodes, (:listing, proof))
  @test e.look == :site
  # The blog's own folder still lists the section, with what its Readme says
  entry = only(x for x in K.site_entries(canon, canon) if x.path == proof)
  @test entry.about == "Why groups decide badly"
  # A section with only a Readme still has its list under it
  Base.invokelatest(K.open!, e, K.FS.get(FSPath(humans))); frames()
  @test e.buf.path == joinpath(humans, "Readme.md") && haskey(e.nodes, (:listing, humans))
  @test K.site_address(canon, joinpath(proof, "index.md")) == "https://canon.example.com/Proof/"
  rm(proof, recursive=true)
end

@testset "a page of a blog looks as its site does" begin
  quotes = joinpath(canon, "Quotes.md")
  write(quotes, "Words.\n\n# Quotes\n\nMore words.\n")
  e.panel = false   # so the window has more room than the site's text needs
  Base.invokelatest(K.show_path!, e, quotes); frames()
  @test e.look == :site && K.body(e).family == K.SITE_FONT[] && K.colours.bg == K.SITE.bg
  all(isfile, K.SITE_FONT_FILES) && @test K.SITE_FONT[] == "Literata"
  # The text is as wide as the site's, and a first heading is in the middle of it
  @test e.width ≈ K.SITE_MEASURE * K.TEXT_SIZE * e.zoom
  it = only(it for it in e.layout if it.first == 3)
  @test it.content.lines[1].x > 100px
  shot("canon-quotes.png")
  # A terminal's file in the blog isn't a page of it: it has the theme's colours
  vt = joinpath(canon, "Terminal.vt")
  write(vt, "\e[1;31mred\e[0m and plain\r\n")
  Base.invokelatest(K.show_path!, e, vt); frames()
  @test K.term_shown(e) && e.look == :own && K.colours.bg == K.SEPIA.bg
  @test e.nodes[(:term, vt)].paper == K.term_colour(K.SEPIA.bg)
  Base.invokelatest(K.show_path!, e, quotes); frames()
  @test e.look == :site
  rm(vt)
  # A page outside the blog has the settings' own look again
  Base.invokelatest(K.show_path!, e, joinpath(K.pages_dir[], "welcome.md")); frames()
  @test e.look == :own && K.colours.bg == K.SEPIA.bg && K.body(e).family == e.font && isempty(K.blog_part(e))
end

@testset "a book review shows its title, stars and year as the site does" begin
  Base.invokelatest(K.show_path!, e, review); frames()
  @test e.buf.view == :markdown && !K.readonly(e.buf)
  h = e.nodes[:review_head]
  @test e.layout[1].content isa K.Live && e.layout[1].content.node === h
  @test h.said["title"] == "The Selfish Gene" && h.link.words == "en.wikipedia.org" && h.said["rating"] == "4" && h.said["pubdate"] == "1976-01-01"
  shot("canon-review.png")
end

@testset "the top bar of a page of a blog" begin
  @test K.site_address(canon, joinpath(humans, "Readme.md")) == "https://canon.example.com/Humans/"
  @test K.site_address(canon, joinpath(humans, "Dating.md")) == "https://canon.example.com/Humans/Dating.html"
  @test K.site_address(canon, review) == "https://canon.example.com/Humans/Gene.html"
  @test K.site_address(canon, joinpath(city, "future city.md")) == "https://canon.example.com/City/future%20city.html"
  # A ? in a name would start a query, so the address has its %-code, as the site's own links do
  @test K.site_address(canon, joinpath(humans, "Why Things Happened?.md")) == "https://canon.example.com/Humans/Why%20Things%20Happened%3F.html"
  @test K.site_address(canon, city) == "https://canon.example.com/City/" && K.site_address(canon, joinpath(canon, "Readme.md")) == "https://canon.example.com"
  # Open Site shows the page that's in the window, on the site
  was, opened = K.BROWSER[], String[]
  K.BROWSER[] = url -> (push!(opened, url); nothing)
  K.blog_act!(e, :open_site)
  K.BROWSER[] = was
  @test opened == ["https://canon.example.com/Humans/Gene.html"]
  @test occursin("Publish Canon", K.blog_tip(e, :publish)) && K.blog_tip(e, :new_post) == "Start a post in Humans"
  # New Post starts a page in the folder that shows
  K.blog_act!(e, :new_post); frames()
  @test dirname(e.buf.path) == humans && startswith(basename(e.buf.path), "Untitled")
end

@testset "each page of a folder of book reviews is a review" begin
  reviews = joinpath(canon, "Book Reviews")
  mkpath(reviews)
  write(joinpath(reviews, ".ladder"), "A folder of book reviews.\n\n```julia\nLadder.BookReviewDirectory\n```\n")
  write(joinpath(reviews, "Readme.md"), "+++\ndescription = \"Books\"\n+++\n")
  red = joinpath(reviews, "Red Plenty.md")
  write(red, "+++\ntitle = \"Red Plenty\"\nlink = \"https://en.wikipedia.org/wiki/Red_Plenty\"\nrating = 4\npubDate = 2010-01-01\n+++\n\nPlans.\n")
  # The folder's own page gives it its kind, once the page has run
  K.folder_pages!(reviews)
  @test Base.invokelatest(K.FS.get, FSPath(reviews)) isa K.BookReviewDirectory
  @test Base.invokelatest(K.FS.get, FSPath(humans)) isa K.BlogSection
  empty!(K.SITE_LISTS)
  Base.invokelatest(K.open!, e, Base.invokelatest(K.FS.get, FSPath(reviews))); frames()
  @test e.buf.path == joinpath(reviews, "Readme.md") && Base.invokelatest(K.page_blog_folder, e) isa K.BookReviewDirectory
  # The list of the folder has a book for each review, as the site has
  l = e.nodes[(:listing, reviews)]
  @test l.reviews && [(x.name, x.icon) for x in K.site_entries(reviews, canon, reviews=true)] == [("Red Plenty.md", :review)]
  # A page of the folder has the top of a review
  Base.invokelatest(K.show_path!, e, red); frames()
  h = e.nodes[:review_head]
  @test e.layout[1].content isa K.Live && e.layout[1].content.node === h && h.said["title"] == "Red Plenty" && h.said["rating"] == "4"
  @test K.site_address(canon, red) == "https://canon.example.com/Book%20Reviews/Red%20Plenty.html"
  # A page of a plain section has no such top
  Base.invokelatest(K.show_path!, e, joinpath(humans, "Dating.md")); frames()
  @test !(e.layout[1].content isa K.Live && e.layout[1].content.node isa K.ReviewHead)
end

"True when the page's front matter takes no room and shows nothing"
matter_hidden() = (it = e.layout[1]; it.first == 1 && it.last == K.front_matter(e.buf.lines) > 1 && it.tall == 0px && !(it.content isa K.Live))

@testset "a folder's own page shows no front matter, as its site shows none" begin
  # The blog's own page, a section's Readme and the Readme of a folder of book reviews
  Base.invokelatest(K.open!, e, K.FS.get(FSPath(canon))); frames()
  @test e.buf.path == joinpath(canon, "Readme.md") && matter_hidden()
  Base.invokelatest(K.open!, e, K.FS.get(FSPath(humans))); frames()
  @test e.buf.path == joinpath(humans, "Readme.md") && matter_hidden()
  reviews = joinpath(canon, "Book Reviews")
  Base.invokelatest(K.open!, e, Base.invokelatest(K.FS.get, FSPath(reviews))); frames()
  @test e.buf.path == joinpath(reviews, "Readme.md") && matter_hidden()
  # A post keeps its card
  Base.invokelatest(K.show_path!, e, joinpath(humans, "Dating.md")); frames()
  @test e.layout[1].content isa K.Live && e.layout[1].content.node isa K.MatterCard
  # ↑ from the first line goes onto the front matter as a whole, which then shows as a card. Return shows its lines.
  Base.invokelatest(K.show_path!, e, joinpath(canon, "Readme.md")); frames()
  e.buf.caret = e.buf.anchor = (5, 0); frames()
  @test matter_hidden()
  delete!(e.nodes, :chose)   # an earlier test chose in the sidebar with no key, so the next key would be the sidebar's
  foreach(_ -> (Base.invokelatest(onkey, w, KeyPress{Keys.up}(0, w)); frames()), 1:2)
  @test K.picked(e.buf) == (1, 3) && e.layout[1].content isa K.Live && e.layout[1].content.node isa K.MatterCard
  Base.invokelatest(onkey, w, KeyPress{Keys.enter}(0, w)); frames()
  @test K.picked(e.buf) === nothing && e.buf.caret[1] <= 3 && !(e.layout[1].content isa K.Live)
  # With the caret out of it, it hides again
  e.buf.caret = e.buf.anchor = (5, 0); frames()
  @test matter_hidden()
end

@testset "the path in the top bar shows a folder of the blog as a click in the list does" begin
  # The blog's own folder and a section show their Readme, with the list under it. A section with no Readme shows its list.
  Base.invokelatest(K.title_go!, e, w, canon); frames()
  @test e.buf.path == joinpath(canon, "Readme.md") && e.folder == canon
  @test K.page_foot(e, K.page_blog_folder(e), K.text_object(e)) === e.nodes[(:listing, canon)]
  # Another click on it, while its Readme shows, keeps the Readme
  Base.invokelatest(K.title_go!, e, w, canon); frames()
  @test e.buf.path == joinpath(canon, "Readme.md")
  Base.invokelatest(K.title_go!, e, w, humans); frames()
  @test e.buf.path == joinpath(humans, "Readme.md") && e.folder == humans
  Base.invokelatest(K.title_go!, e, w, city); frames()
  @test e.buf.path == city && e.buf.view == :file
  # ⌘W on the Readme, when it's the last tab, shows the blog's list, and not the Readme again
  empty!(K.tabs(e))
  Base.invokelatest(K.title_go!, e, w, canon); frames()
  @test K.tabs(e) == [joinpath(canon, "Readme.md")]
  Base.invokelatest(K.close_file!, e); frames()
  @test e.buf.path == canon && e.buf.view == :file && isempty(K.tabs(e))
end

close(w)
