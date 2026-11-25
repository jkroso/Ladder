# Tests for a folder of news: the pages that say what news you want, the
# agents that write the articles, the front page that shows them, an
# article's page, and the articles that go when they're too old. See "a folder
# of news" in main.jl, and news.jl. Run them with
# `KIP_FROZEN=1 julia -O0 --project=. test/news_test.jl`. They use a folder of
# their own, never ~/News, and a script in place of the agent, so no agent
# runs. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use GeometryBasics: Vec2
@use Dates: Dates, DateTime, Date, Day

const px = K.px
const N = K.News

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
N.FILE[] = joinpath(dir, "news-settings")
const news = mkpath(joinpath(dir, "News"))
K.NEWS_FOLDER[] = news
write(joinpath(dir, "page.md"), "# A page\n")

# The agent of these tests: it notes what it was asked, by the words of the page, and replies with what's in a file
const agent = joinpath(dir, "agent.sh")
write(agent, """
#!/bin/sh
case "\$1" in
  *Rockets*) printf '%s' "\$1" > "$dir/asked-space.txt"; cat "$dir/space.txt" ;;
  *models*) printf '%s' "\$1" > "$dir/asked-ai.txt"; cat "$dir/ai.txt" ;;
  *gardens*) echo "I looked everywhere."; echo; echo "NO NEWS" ;;
  *broken*) echo "The network is down."; exit 3 ;;
  *Slow*) sleep 30 ;;
esac
""")
K.NEWS_COMMAND[] = `sh $agent`

write(joinpath(dir, "space.txt"), """
Here's today's news.

=== ARTICLE ===
headline: A rocket lands on its tower: a first
summary: The booster came back to the tower that launched it, and the tower's arms caught it.
importance: 9
sources: https://www.example.com/rocket https://news.example.org/landing

The booster fell back to its tower and the tower's arms caught it, a first for any rocket.

The company said that it would fly the booster again within a month.

=== ARTICLE ===
headline: A probe reaches Jupiter's moons
summary: It's the first of three passes.
importance: 4
sources: https://example.com/probe

The probe flew past the moon at 12,000 km.
""")
write(joinpath(dir, "ai.txt"), """
=== ARTICLE ===
**headline:** A new model reads whole books
**summary:** It reads a million words at once.
**importance:** 6
**sources:** https://example.com/model

The model reads a million words at once, its makers said.
""")

const e = K.build_editor(joinpath(dir, "page.md"))
e.panel = true
const w = Window(e, size=(1200px, 900px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "news-$name.png"), w)
front(path=news) = e.nodes[(:news, path)]
"Read the folder again now, as two seconds do"
again(path=news) = (front(path).read = 0.0; frames())
"Draw frames until no agent works or waits, for 20 seconds at most"
finish() = begin
  from = time()
  while (!isempty(K.NEWS_WORKING) || !isempty(K.NEWS_WAITING)) && time() - from < 20
    frames(1)
    sleep(0.05)
  end
  frames()
end
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = begin
  at(place)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  frames(1)
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames(2)
end
middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
today() = joinpath(news, Dates.format(Dates.today(), "yyyy-mm-dd"))

@testset "the facts of a folder of news" begin
  found = N.reply_articles(read(joinpath(dir, "space.txt"), String) * "\n```\n")
  @test [f.headline for f in found] == ["A rocket lands on its tower: a first", "A probe reaches Jupiter's moons"]
  @test found[1].importance == 9 && found[1].sources == ["https://www.example.com/rocket", "https://news.example.org/landing"]
  @test found[2].text == "The probe flew past the moon at 12,000 km."   # the fence of a reply in a code block isn't part of the text
  # The agent can make the keys bold
  ai = N.reply_articles(read(joinpath(dir, "ai.txt"), String))
  @test only(ai).headline == "A new model reads whole books" && only(ai).importance == 6
  @test N.no_news("I looked.\n\nNO NEWS\n") && !N.no_news("There's NO NEWS like good news.")
  @test isempty(N.reply_articles("Sorry, I couldn't search the web."))
  # A file's name has the headline's words, with no colon
  @test N.file_name("A rocket lands on its tower: a first") == "A rocket lands on its tower - a first"
  @test N.file_name("Up/down: 50%") == "Up-down - 50%"
  # The day of a day's folder
  @test N.edition_day("2026-11-25") == Date(2026, 11, 25) && N.edition_day("notes") === nothing && N.edition_day("2026-13-45") === nothing
  # The settings start as a week, and Ladder's agents get the news daily
  @test N.keep_days() == 7 && N.agents() == :daily
end

@testset "a folder with no pages says how to ask for news, in a newspaper's look" begin
  @test K.found_kind(news) == K.NewsDirectory
  K.open_folder!(e, news)
  frames()
  v = front()
  @test v isa K.NewsPage && isempty(v.editions) && isempty(v.interests)
  @test e.look == :news && K.colours.bg == K.NEWS.bg
  @test isempty(K.NEWS_WORKING) && isempty(K.NEWS_WAITING)
  # The empty page's button makes a page, and Get the News does nothing while no page says anything
  @test v.buttons[:get].off
  shot("empty")
  # Show Folder As offers News for any folder
  @test any(c -> c.name == "News" && c.from == K.NewsDirectory, K.choices_for(K.KindChoice, e))
end

@testset "the agents write the articles of each page, and the front page shows them" begin
  write(joinpath(news, "Space.md"), "Rockets, probes and missions to the planets.\n")
  write(joinpath(news, "AI.md"), "New AI models and what they can do.\n")
  write(joinpath(news, "Readme.md"), "This folder is my newspaper.\n")   # not a kind of news
  write(joinpath(news, "Empty.md"), "")                                  # says nothing, so no agent reads it
  again()
  # The front page asked for the news of each page that says something, as none had its news today
  @test sort([r.interest.name for r in K.news_runs(news)]) == ["AI", "Space"]
  shot("working")
  finish()
  v = front()
  isempty(v.editions) && @show K.NEWS_SAID
  @test length(v.editions) == 1 && v.editions[1].day == Dates.today()
  titles = [a.title for a in v.editions[1].articles]
  # The most important first
  @test titles == ["A rocket lands on its tower: a first", "A new model reads whole books", "A probe reaches Jupiter's moons"]
  @test isfile(joinpath(today(), "A rocket lands on its tower - a first.md"))
  text = read(joinpath(today(), "A rocket lands on its tower - a first.md"), String)
  @test occursin("title: A rocket lands on its tower: a first\nsection: Space\n", text)
  @test occursin("- [example.com](https://www.example.com/rocket)", text)
  # What the agent was asked: the page's words, and how to reply
  asked = read(joinpath(dir, "asked-space.txt"), String)
  @test occursin("Rockets, probes and missions to the planets.", asked) && occursin(N.MARK, asked)
  @test N.last_ran(joinpath(news, "Space.md")) !== nothing && N.last_ran(joinpath(news, "Empty.md")) === nothing
  # Each story shows, and the page doesn't ask again today
  @test Set(keys(v.stories)) == Set(a.path for a in v.editions[1].articles)
  again()
  @test isempty(K.NEWS_WORKING) && isempty(K.NEWS_WAITING)
  # The sidebar lists the days first, and then the pages
  listed = K.entries(e, K.FS.get(FSPath(news)))
  @test listed[1] isa K.NewsDay && K.entry_name(listed[1]) == basename(today())
  shot("front")
end

@testset "a click on a story shows its article, with a newspaper's look" begin
  v = front()
  lead = v.editions[1].articles[1]
  click(middle(v.stories[lead.path]))
  @test e.buf.path == lead.path
  frames()
  @test e.look == :news
  h = e.nodes[:news_head]
  @test h.said["title"] == "A rocket lands on its tower: a first" && h.said["section"] == "Space"
  shot("article")
  # A day's folder shows as that day's front page
  K.open_folder!(e, today())
  frames()
  d = front(today())
  @test d.day && length(d.editions) == 1 && length(d.editions[1].articles) == 3
  @test !haskey(d.buttons, :get)
end

@testset "Get the News asks again, and leaves out what the paper has printed" begin
  K.open_folder!(e, news)
  frames()
  K.get_news!(e, news)
  finish()
  asked = read(joinpath(dir, "asked-space.txt"), String)
  @test occursin("which the paper has printed already", asked) && occursin("- A rocket lands on its tower: a first", asked)
end

@testset "an agent that finds no news, one that fails, and one that's stopped" begin
  write(joinpath(news, "Gardens.md"), "News of gardens.\n")
  write(joinpath(news, "Broken.md"), "The broken news.\n")
  again()
  finish()
  @test K.NEWS_SAID[joinpath(news, "Gardens.md")] == (:note, "Claude found no news of Gardens.")
  @test K.NEWS_SAID[joinpath(news, "Broken.md")] == (:problem, "Claude wrote no articles for Broken: The network is down.")
  shot("said")
  rm(joinpath(news, "Gardens.md")); rm(joinpath(news, "Broken.md"))
  write(joinpath(news, "Slow.md"), "Slow news.\n")
  again()
  @test length(K.news_runs(news)) == 1 && front().buttons[:stop] isa K.PageButton
  click(middle(front().buttons[:stop]))
  @test isempty(K.news_runs(news))
  @test K.NEWS_SAID[joinpath(news, "Slow.md")] == (:note, "You stopped it.")
  rm(joinpath(news, "Slow.md"))
end

@testset "articles go when they're older than Settings keep them" begin
  old = Dates.today() - Day(10)
  folder = mkpath(joinpath(news, Dates.format(old, "yyyy-mm-dd")))
  write(joinpath(folder, "Old news.md"), "---\ntitle: Old news\nsection: Space\ndate: $(Dates.format(DateTime(old) + Dates.Hour(8), "yyyy-mm-ddTHH:MM"))\n---\n\nOld.\n")
  kept = mkpath(joinpath(news, Dates.format(old - Day(1), "yyyy-mm-dd")))
  write(joinpath(kept, "mine.txt"), "Not an article.")
  # With news kept for ever, nothing goes
  m = K.sandbox(e)
  Base.invokelatest(Core.eval, m, :(news_days!(0)))
  @test N.keep_days() == 0 && Base.invokelatest(Core.eval, m, :(news_days())) == 0
  again()
  @test length(front().editions) == 2 && isfile(joinpath(folder, "Old news.md"))
  shot("earlier")
  Base.invokelatest(Core.eval, m, :(news_days!(7)))
  again()
  @test !ispath(folder) && length(front().editions) == 1
  # A file that isn't an article stays, and so does its folder
  @test isfile(joinpath(kept, "mine.txt"))
  # With news only when you ask, opening the folder starts no agent, and Get the News is there
  Base.invokelatest(Core.eval, m, :(news_agents!("asked")))
  @test N.agents() == :asked && Base.invokelatest(Core.eval, m, :(news_agents())) == "asked"
  write(joinpath(news, "Later.md"), "Later news.\n")
  again()
  @test isempty(K.news_runs(news)) && [b.words for b in K.news_buttons(e, front())] == ["Get the News", "Feeds", "New Page"]
end

@testset "with Ladder's agents off, another agent writes the articles" begin
  m = K.sandbox(e)
  Base.invokelatest(Core.eval, m, :(news_agents!("off")))
  @test N.agents() == :off
  again()
  # There's no Get the News, and nothing starts an agent: not the button, the command, or a page with no news today
  @test [b.words for b in K.news_buttons(e, front())] == ["Feeds", "New Page"]
  @test !K.works_here(e, Val(:get_the_news))
  K.get_news!(e, news)
  @test isempty(K.news_runs(news))
  # An article that another agent writes shows, with the importance it gives it
  write(joinpath(today(), "A story from another agent.md"), "---\ntitle: A story from another agent\nsection: Space\nimportance: 10\nby: Grok\n---\n\nIts words.\n")
  again()
  lead = front().editions[1].articles[1]
  @test lead.title == "A story from another agent" && lead.by == "Grok"
  shot("other-agent")
end

@testset "AGENTS.md tells an agent of your own what to write, and isn't a kind of news" begin
  path = joinpath(news, "AGENTS.md")
  # The front page wrote it when it first showed
  @test isfile(path) && startswith(read(path, String), N.KEPT_LINE)
  @test !any(p -> p.name == "AGENTS", front().interests)
  @test !N.interest_name("AGENTS.md") && !N.interest_name("claude.md") && !N.interest_name("Readme.md") && N.interest_name("AI.md")
  # It says the reader's time zone, how many articles to write, and how long Ladder keeps them
  text = N.instructions(days=7, most=5, zone="Australia/Sydney")
  @test occursin("their time zone is Australia/Sydney", text) && occursin("5 at most for each page", text)
  @test occursin("It deletes each article 7 days after its date", text)
  @test occursin("It keeps every article", N.instructions(days=0, zone=""))
  @test occursin("Read `feedback.csv`", text) && occursin("`liked: yes`", text) && occursin("Feeds.md", text)
  @test !occursin("time zone is", N.instructions(zone=""))
  # It follows the settings
  m = K.sandbox(e)
  Base.invokelatest(Core.eval, m, :(news_days!(14)))
  again()
  @test occursin("14 days after its date", read(path, String))
  # A file whose first line you deleted is yours, and stays as it is
  write(path, "Write only about rockets.\n")
  Base.invokelatest(Core.eval, m, :(news_days!(7)))
  again()
  @test read(path, String) == "Write only about rockets.\n"
end

@testset "you mark an article that you liked, or didn't, and its reporter learns of it" begin
  K.open_folder!(e, news)
  frames()
  a = first(x for ed in front().editions for x in ed.articles if x.read === nothing)
  row(path) = (f = relpath(path, news); i = findfirst(m -> m.file == f, N.marks(news)); i === nothing ? nothing : N.marks(news)[i])
  # Opening a story from the front page writes when you read it, which feedback.csv keeps
  click(middle(front().stories[a.path]))
  @test e.buf.path == a.path
  frames()
  @test N.article(a.path).read !== nothing && occursin("\nread: ", read(a.path, String))
  r = row(a.path)
  @test r !== nothing && r.read && r.liked === nothing && r.title == a.title && r.by == a.by
  liked, disliked = e.nodes[:news_head].marks
  @test !liked.on && !disliked.on
  # Liked it writes the mark in the article, and feedback.csv keeps it
  click(middle(liked))
  @test occursin("\nliked: yes\n", read(a.path, String)) && N.article(a.path).liked === true
  @test liked.on && !disliked.on && row(a.path).liked === true
  shot("article-marked")
  # Didn't like it gives the other mark, and a click on a mark that's on takes it off
  click(middle(disliked))
  @test occursin("\nliked: no\n", read(a.path, String)) && !occursin("liked: yes", read(a.path, String))
  click(middle(disliked))
  @test !occursin("liked:", read(a.path, String)) && row(a.path).liked === nothing && row(a.path).read
  click(middle(liked))
  # The front page shows the mark on the story, and each reporter's score at its foot
  K.open_folder!(e, news)
  again()
  s = only(filter(s -> s[1] == a.by, front().scores))
  @test s[2] == 1 && s[3] == 0 && s[4] >= 1 && s[5] >= s[4]
  shot("marks")
  # A mark stays in feedback.csv after its article has gone
  rm(a.path)
  again()
  @test row(a.path) !== nothing && row(a.path).liked === true
  # An article of an earlier day that you didn't open is in feedback.csv, and one of today isn't yet
  old = mkpath(joinpath(news, Dates.format(Dates.today() - Day(1), "yyyy-mm-dd")))
  write(joinpath(old, "A dull story.md"), "---\ntitle: A dull story\nsection: Space\nby: Grok\n---\n\nWords.\n")
  write(joinpath(today(), "A new story.md"), "---\ntitle: A new story\nsection: Space\nby: Grok\n---\n\nWords.\n")
  again()
  @test row(joinpath(old, "A dull story.md")) !== nothing && !row(joinpath(old, "A dull story.md")).read
  @test row(joinpath(today(), "A new story.md")) === nothing
  # Ladder's agent is told what you liked of its section, and what you didn't open
  asked = N.ask(N.Interest(name="Space", words="Rockets."), Dates.now(); liked=filter(m -> m.section == "Space", N.marks(news)))
  @test occursin("They liked these:\n\n- $(a.title)", asked) && occursin("They didn't open these:", asked) && occursin("- A dull story", asked)
  # The menu of a story on the front page marks its article, without opening it. A mark with a tick comes off.
  b = joinpath(today(), "A new story.md")
  K.news_story_act!(e, b, findfirst(==("Didn't Like It"), K.NEWS_STORY_MENU))
  @test N.article(b).liked === false && N.article(b).read === nothing && e.buf.path != b
  K.news_story_act!(e, b, findfirst(==("Didn't Like It"), K.NEWS_STORY_MENU))
  @test N.article(b).liked === nothing && row(b) === nothing
  K.news_story_act!(e, b, findfirst(==("Liked It"), K.NEWS_STORY_MENU))
  again()
  @test N.article(b).liked === true && row(b).liked === true && !row(b).read
  # Its Open writes when you read it too
  K.news_story_act!(e, b, findfirst(==("Open"), K.NEWS_STORY_MENU))
  @test e.buf.path == b && N.article(b).read !== nothing
end

@testset "the posts of a feed show as articles by their authors" begin
  stamp(t) = Dates.format(t, "e, dd u yyyy HH:MM:SS") * " +0000"
  posted = Dates.now(Dates.UTC) - Dates.Hour(2)
  rss = """<?xml version="1.0"?><rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/"><channel><title>Sam's Blog</title>
    <item><title>A telescope sees the first stars</title><link>https://sam.example.com/stars</link><dc:creator>Sam Lee</dc:creator>
    <pubDate>$(stamp(posted))</pubDate><description>&lt;p&gt;The light left them 13 billion years ago.&lt;/p&gt;</description></item>
    <item><title>An old post</title><link>https://sam.example.com/old</link><pubDate>$(stamp(posted - Day(30)))</pubDate><description>Old.</description></item>
    </channel></rss>"""
  got = String[]
  K.FEED_GETTER[] = (address, file, about) -> begin
    push!(got, address)
    occursin("missing", address) ? write(about, "$address\ntext/html\n404\n") :
      (write(file, rss); write(about, "$address\napplication/rss+xml\n200\n"))
    () -> true
  end
  write(joinpath(news, "Feeds.md"), "# Feeds\n\n## Space\n\n- https://sam.example.com/feed.xml\n- https://missing.example.com/feed.xml\n")
  K.open_folder!(e, news)
  again()
  frames()
  @test length(got) == 2
  v = front()
  posts = [a for ed in v.editions for a in ed.articles if a.by == "Sam Lee"]
  @test length(posts) == 1 && posts[1].title == "A telescope sees the first stars" && posts[1].section == "Space"
  @test posts[1].link == "https://sam.example.com/stars" && occursin("The light left them 13 billion years ago.", posts[1].text)
  @test any(s -> occursin("missing.example.com", s) && occursin("404", s), values(K.FEEDS_SAID))
  @test !any(p -> p.name == "Feeds", v.interests)
  # The feeds come again after an hour, or when you click Get the News, which is there while the folder has feeds
  again()
  @test length(got) == 2
  @test [b.words for b in K.news_buttons(e, front())] == ["Get the News", "Feeds", "New Page"]
  shot("feeds")
  # A post that you deleted doesn't come back
  rm(posts[1].path)
  K.news_now!(e, news)
  frames()
  again()
  @test length(got) == 4
  @test !any(a -> a.by == "Sam Lee", (a for ed in front().editions for a in ed.articles))
end

@testset "the episodes of the shows that you follow in Apple Podcasts are articles by their shows" begin
  # A library like Apple Podcasts' own, with the columns that Ladder reads
  lib = joinpath(dir, "MTLibrary.sqlite")
  ago(h) = round(Int, time() - 3600h) - K.Feeds.Podcasts.APPLE_TIME
  sql = """
  create table ZMTPODCAST (Z_PK integer primary key, ZTITLE text, ZSUBSCRIBED integer, ZSTORECOLLECTIONID integer);
  create table ZMTEPISODE (Z_PK integer primary key, ZUUID text, ZTITLE text, ZPODCAST integer, ZPUBDATE real, ZSTORETRACKID integer, ZWEBPAGEURL text, ZUSERDELETED integer);
  create table ZMTEPISODEDESCRIPTION (Z_PK integer primary key, ZEPISODE integer, ZTEXT text, ZPLAINTEXT text);
  insert into ZMTPODCAST values (1, 'Sam Talks', 1, 111), (2, 'A show you left', 0, 222);
  insert into ZMTEPISODE values (1, 'ep-1', 'Rockets with Kim', 1, $(ago(3)), 999, null, 0), (2, 'ep-2', 'An old one', 1, $(ago(24 * 30)), 0, null, 0),
                                (3, 'ep-3', 'Not yours', 2, $(ago(2)), 0, null, 0);
  insert into ZMTEPISODEDESCRIPTION values (1, 1, '<p>Kim on how the <a href="https://example.com/b"> booster</a> lands.</p><p>Second part.</p>', null);
  """
  run(`/usr/bin/sqlite3 $lib $sql`)
  K.Feeds.Podcasts.LIBRARY[] = lib
  write(joinpath(news, "Feeds.md"), "# Feeds\n\n## Listening\n\n- Apple Podcasts\n")
  @test [f.url for f in K.Feeds.feeds(news)] == [K.Feeds.PODCASTS] && K.Feeds.feeds(news)[1].section == "Listening"
  K.open_folder!(e, news)
  K.news_now!(e, news)
  ok = (t = time(); while haskey(K.FEEDS_COMING, K.Feeds.PODCASTS) && time() - t < 10; frames(1); sleep(0.05) end; !haskey(K.FEEDS_COMING, K.Feeds.PODCASTS))
  again()
  eps = [a for ed in front().editions for a in ed.articles if a.by == "Sam Talks"]
  @test ok && length(eps) == 1 && eps[1].title == "Rockets with Kim" && eps[1].section == "Listening"
  @test eps[1].link == "https://podcasts.apple.com/podcast/id111?i=999" && occursin("## Listen\n\n- [Apple Podcasts](https://podcasts.apple.com/podcast/id111?i=999)", read(eps[1].path, String))
  @test occursin("Kim on how the [booster](https://example.com/b) lands.\n\nSecond part.", eps[1].text) && eps[1].summary == "Kim on how the booster lands. Second part."
  # A library that Ladder can't read says so on the front page
  K.Feeds.Podcasts.LIBRARY[] = joinpath(dir, "no library.sqlite")
  K.news_now!(e, news)
  ok = (t = time(); while haskey(K.FEEDS_COMING, K.Feeds.PODCASTS) && time() - t < 10; frames(1); sleep(0.05) end; !haskey(K.FEEDS_COMING, K.Feeds.PODCASTS))
  @test ok && occursin("Apple Podcasts", get(K.FEEDS_SAID, K.Feeds.PODCASTS, ""))
  K.Feeds.Podcasts.LIBRARY[] = ""
  delete!(K.FEEDS_SAID, K.Feeds.PODCASTS)
  rm(joinpath(news, "Feeds.md"))
end

@testset "a reading companion talks with you about any article of the folder, in a terminal that keeps the talk" begin
  K.Agent.place[] = mktempdir()
  started = Any[]
  K.COMPANION_STARTER[] = v -> push!(started, v)
  folder = realpath(news)
  # Opening the front page starts one, in a terminal whose file is in the folder of today's articles
  opens() = (K.open_folder!(e, news); e.nodes[:news_shown] = 0.0; frames())
  opens()
  @test length(started) == 1
  v = started[1]
  file = realpath(joinpath(news, K.COMPANION_FILE))
  script = read(v.command[2], String)
  @test v.dir == folder && v.path == joinpath(folder, Dates.format(Dates.today(), "yyyy-mm-dd"), "Talk with Grok.vt") && isfile(v.path)
  @test v in K.terminals(e) && e.nodes[(:term, v.path)] === v
  @test occursin("ladder wait", script) && occursin(file, script) && occursin("reading companion", script) && occursin("say my question and your answer here too", script)
  @test !any(p -> startswith(p.name, "."), front().interests)
  # It doesn't start again while it starts
  opens()
  @test length(started) == 1
  # While it waits, it's the agent of each article of the folder, and of no other page. No dot says that it waits elsewhere.
  write(joinpath(K.Agent.folder(), "$(getpid()).wait"), file * "\nGrok\n")
  delete!(e.nodes, :agents)
  art = first(a for ed in front().editions for a in ed.articles)
  @test [w.name for w in K.agents(e, art.path)] == ["Grok"]
  @test isempty(K.agents(e, joinpath(dir, "page.md"))) && isempty(K.elsewhere(e))
  # So Ask Agent on an article asks it
  K.news_open!(e, art.path)
  frames()
  @test K.sharer(e) == "Grok" && K.asks_whom(e) == "Grok"
  # One that waits and that Ladder didn't start, as before Ladder last opened, stays
  delete!(K.NEWS_COMPANIONS, folder)
  opens()
  @test length(started) == 1
  rm(joinpath(K.Agent.folder(), "$(getpid()).wait"))
  # The `ladder wait` of a companion whose program has ended is stopped, and another starts, with a file of its own
  stale = run(`sleep 60`, wait=false)
  write(joinpath(K.Agent.folder(), "$(getpid(stale)).wait"), file * "\nGrok\n")
  delete!(e.nodes, :agents)
  K.NEWS_COMPANIONS[folder] = (0.0, v)
  opens()
  ok = (t = time(); while process_running(stale) && time() - t < 5; sleep(0.05) end; !process_running(stale))
  @test ok && length(started) == 2 && basename(started[2].path) == "Talk with Grok 2.vt"
  # Settings can turn it off
  K.NEWS_COMPANIONS[folder] = (0.0, v)
  N.companion!(false)
  opens()
  @test length(started) == 2
  N.companion!(true)
  # A day's talk goes when all that day's articles have gone
  old = mkpath(joinpath(news, Dates.format(Dates.today() - Day(9), "yyyy-mm-dd")))
  write(joinpath(old, "Talk with Grok.vt"), "Hello\n")
  @test joinpath(old, "Talk with Grok.vt") in N.prune!(news; days=7) && !isdir(old)
  # When Grok asks whether it may work in a folder that's new to it, the front page says where to answer
  v2 = started[2]
  K.NEWS_COMPANIONS[folder] = (time(), v2)
  v2.shell = :running
  K.Terms.feed!(K.Terms.terminal(v2), Vector{UInt8}("Do you trust the contents of this directory?"))
  @test occursin("Talk with Grok 2 asks whether it may work in this folder", K.companion_status(news))
  v2.shell = nothing
  @test K.companion_status(news) == ""
  # Its `ladder wait` stops when the window closes its terminal
  stale = run(`sleep 60`, wait=false)
  write(joinpath(K.Agent.folder(), "$(getpid(stale)).wait"), file * "\nGrok\n")
  K.end_companions!(e)
  ok = (t = time(); while process_running(stale) && time() - t < 5; sleep(0.05) end; !process_running(stale))
  @test ok && !haskey(K.NEWS_COMPANIONS, folder)
  # The front page has a tab, and the companion ends when the tab closes, but not while an article of the folder shows
  opens()
  v3 = started[end]
  @test news in K.tabs(e) && K.NEWS_COMPANIONS[folder][2] === v3
  K.news_open!(e, art.path)
  frames()
  @test haskey(K.NEWS_COMPANIONS, folder)
  stale = run(`sleep 60`, wait=false)
  write(joinpath(K.Agent.folder(), "$(getpid(stale)).wait"), file * "\nGrok\n")
  K.close_tab!(e, news)
  frames()
  ok = (t = time(); while process_running(stale) && time() - t < 5; sleep(0.05) end; !process_running(stale))
  @test ok && !haskey(K.NEWS_COMPANIONS, folder) && !(v3 in K.terminals(e)) && !(news in K.tabs(e))
  K.COMPANION_STARTER[] = nothing
  K.Agent.place[] = ""
  foreach(x -> filter!(o -> o !== x, K.terminals(e)), started)
end

close(w)

@testset "in a wide window, the front page is no wider than NEWS_WIDEST, in the middle" begin
  e.panel = false
  wide = Window(e, size=(2400px, 900px))
  K.open_folder!(e, news)
  foreach(_ -> Base.invokelatest(frame, wide), 1:4)
  shown = filter(r -> r !== nothing, [rect(s) for s in values(front().stories)])
  @test !isempty(shown)
  left = minimum(K.num(r.left) for r in shown)
  right = maximum(K.num(r.left + r.width) for r in shown)
  @test right - left <= K.num(K.NEWS_WIDEST * e.zoom) + 1
  @test abs((left + right) / 2 - 1200) < 40
  close(wide)
  # Many reporters with long names stay in the window, as a paper with feeds and podcasts has them
  rows = join(("\"$(Dates.today() - Day(1))\",\"A show with a long name, number $i, about history and philosophy 🔓\",\"AI\",\"\",\"no\",\"Title $i\",\"\",\"x/$i.md\"\n" for i in 1:30))
  write(joinpath(news, "feedback.csv"), join(N.MARK_COLUMNS, ",") * "\n" * rows)
  narrow = Window(e, size=(900px, 900px))
  K.open_folder!(e, news)
  front().read = 0.0
  foreach(_ -> Base.invokelatest(frame, narrow), 1:4)
  @test length(front().scores) >= 30
  shown = filter(r -> r !== nothing, [rect(s) for s in values(front().stories)])
  @test !isempty(shown) && all(r -> K.num(r.left) >= 0 && K.num(r.left + r.width) <= 900, shown)
  @test K.news_glyphs("Premium (🔓 for Sam)") == "Premium (for Sam)"
  close(narrow)
end
