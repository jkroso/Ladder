# Tests for a folder of news: the pages that say what news you want, the
# agents that write the articles, the front page that shows them, an
# article's page, and the articles that go when they're too old. See
# news_page.jl and news.jl. Run them with
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
@use "./drive" drive middle

const px = K.px
const N = K.News

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
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
const (; frames, at, click, shot) = drive(w, frames=3, pressed=1, latest=true)
frames()

front(path=news) = e.nodes[(:news, path)]
"Read the folder again now, as two seconds do"
again(path=news) = (front(path).read = 0.0; frames())
"The top bar's button that does `action` on the front page, or nothing when the top bar has none"
bar_button(action) = (i = findfirst(p -> p isa K.ToolButton && p.action == action, K.news_bar(e)); i === nothing ? nothing : K.news_bar(e)[i])
"The top bar's button that gets the news"
getter() = bar_button(:get_news)
"The sections of Interests.md that the tests wrote, in order"
const wanted = Pair{String,String}[]
"Write `words` as the section `name` of Interests.md, or take the section out with nothing"
want!(name, words=nothing) = begin
  filter!(p -> p[1] != name, wanted)
  words === nothing || push!(wanted, name => words)
  write(joinpath(news, N.INTERESTS), "# Interests\n\nWhat I read.\n\n" * join("## $n\n\n$w\n\n" for (n, w) in wanted))
end
"What Ladder knows the section `name` of the tests' Interests.md by"
section_key(name) = N.interest_key(news, name)
"Draw frames until no agent works or waits, for 20 seconds at most"
finish() = begin
  from = time()
  while (!isempty(K.NEWS_WORKING) || !isempty(K.NEWS_WAITING)) && time() - from < 20
    frames(1)
    sleep(0.05)
  end
  frames()
end
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

@testset "each ## heading of Interests.md is a section, with the words under it" begin
  f = mktempdir()
  @test isempty(N.interests(f))
  write(joinpath(f, N.INTERESTS), """
  ---
  title: What I read
  ---
  # Interests

  What this page is for.

  ```markdown
  ## Not a section
  ```

  ## AI

  Models.

  ### Labs

  OpenAI.

  # Notes

  Not news.

  ## Space ##

  Rockets.

  ## AI

  Chips too.
  """)
  is = N.interests(f)
  # A heading in code isn't one, a `#` heading ends a section, and a heading that's there twice has the words of both
  @test [i.name for i in is] == ["AI", "Space"]
  @test startswith(is[1].words, "Models.") && occursin("### Labs\n\nOpenAI.", is[1].words) && endswith(is[1].words, "Chips too.")
  @test !occursin("Not news", is[1].words) && is[2].words == "Rockets."
  @test is[1].key == joinpath(f, "Interests.md") * "#AI"
  # What Ladder remembers of a section stays while its page is there
  N.ran!(is[2].key)
  @test N.last_ran(is[2].key) !== nothing
  rm(joinpath(f, N.INTERESTS)); N.ran!(joinpath(dir, "page.md"))
  @test N.last_ran(is[2].key) === nothing
end

@testset "a folder with no interests says how to ask for news, in a newspaper's look" begin
  @test K.found_kind(news) == K.NewsDirectory
  K.open_folder!(e, news)
  frames()
  v = front()
  @test v isa K.NewsPage && isempty(v.editions) && isempty(v.interests)
  @test e.look == :news && K.colours.bg == K.NEWS.bg
  @test isempty(K.NEWS_WORKING) && isempty(K.NEWS_WAITING)
  # The top bar's Get the News does nothing while no section says anything
  @test getter() isa K.ToolButton && K.off(getter())
  shot("news-empty")
  # Interests, in the top bar, makes Interests.md, which says what it's for and has no sections yet, and shows it
  click(middle(bar_button(:news_interests)))
  @test e.buf.path == joinpath(news, N.INTERESTS) && read(e.buf.path, String) == N.INTERESTS_PAGE && isempty(N.interests(news))
  K.open_folder!(e, news)
  frames()
  # Show Folder As offers News for any folder
  @test any(c -> c.name == "News" && c.from == K.NewsDirectory, K.choices_for(K.KindChoice, e))
end

@testset "the agents write the articles of each section of Interests.md, and the front page shows them" begin
  want!("Space", "Rockets, probes and missions to the planets.")
  want!("AI", "New AI models and what they can do.")
  want!("Empty", "")                                                    # says nothing, so no agent reads it
  write(joinpath(news, "Readme.md"), "This folder is my newspaper.\n")   # a page that isn't Interests.md isn't a kind of news
  again()
  # The front page asked for the news of each section that says something, as none had its news today
  @test sort([r.interest.name for r in K.news_runs(news)]) == ["AI", "Space"]
  shot("news-working")
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
  # What the agent was asked: the section's words, and how to reply
  asked = read(joinpath(dir, "asked-space.txt"), String)
  @test occursin("Rockets, probes and missions to the planets.", asked) && occursin(N.MARK, asked)
  @test N.last_ran(section_key("Space")) !== nothing && N.last_ran(section_key("Empty")) === nothing
  # Each story shows, and the page doesn't ask again today
  @test Set(keys(v.stories)) == Set(a.path for a in v.editions[1].articles)
  again()
  @test isempty(K.NEWS_WORKING) && isempty(K.NEWS_WAITING)
  # The sidebar lists the days first, and then the pages
  listed = K.entries(e, K.FS.get(FSPath(news)))
  @test listed[1] isa K.NewsDay && K.entry_name(listed[1]) == basename(today())
  shot("news-front")
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
  shot("news-article")
  # A day's folder shows as that day's front page
  K.open_folder!(e, today())
  frames()
  d = front(today())
  @test d.day && length(d.editions) == 1 && length(d.editions[1].articles) == 3
  @test isempty(K.news_bar(e))
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
  want!("Gardens", "News of gardens.")
  want!("Broken", "The broken news.")
  again()
  finish()
  @test K.NEWS_SAID[section_key("Gardens")] == (:note, "Claude found no news of Gardens.")
  @test K.NEWS_SAID[section_key("Broken")] == (:problem, "Claude wrote no articles for Broken: The network is down.")
  shot("news-said")
  want!("Gardens"); want!("Broken")
  want!("Slow", "Slow news.")
  again()
  # While the agents work, the top bar's button turns, and a click on it stops them
  @test length(K.news_runs(news)) == 1 && K.BUTTONS[:get_news].busy(e) && !K.off(getter())
  click(middle(getter()))
  @test isempty(K.news_runs(news))
  @test K.NEWS_SAID[section_key("Slow")] == (:note, "You stopped it.")
  want!("Slow")
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
  shot("news-earlier")
  Base.invokelatest(Core.eval, m, :(news_days!(7)))
  again()
  @test !ispath(folder) && length(front().editions) == 1
  # A file that isn't an article stays, and so does its folder
  @test isfile(joinpath(kept, "mine.txt"))
  # With news only when you ask, opening the folder starts no agent, and Get the News is there
  Base.invokelatest(Core.eval, m, :(news_agents!("asked")))
  @test N.agents() == :asked && Base.invokelatest(Core.eval, m, :(news_agents())) == "asked"
  want!("Later", "Later news.")
  again()
  @test isempty(K.news_runs(news)) && bar_button(:news_interests) isa K.ToolButton
  @test !K.off(getter()) && !K.BUTTONS[:get_news].busy(e)
end

@testset "with Ladder's agents off, another agent writes the articles" begin
  m = K.sandbox(e)
  Base.invokelatest(Core.eval, m, :(news_agents!("off")))
  @test N.agents() == :off
  again()
  # There's no Get the News, and nothing starts an agent: not the button, the command, or a page with no news today
  @test bar_button(:news_interests) isa K.ToolButton && getter() === nothing
  @test !K.works_here(e, Val(:get_the_news))
  K.get_news!(e, news)
  @test isempty(K.news_runs(news))
  # An article that another agent writes shows, with the importance it gives it
  write(joinpath(today(), "A story from another agent.md"), "---\ntitle: A story from another agent\nsection: Space\nimportance: 10\nby: Grok\n---\n\nIts words.\n")
  again()
  lead = front().editions[1].articles[1]
  @test lead.title == "A story from another agent" && lead.by == "Grok"
  shot("news-other-agent")
end

@testset "AGENTS.md tells an agent of your own what to write, and isn't a kind of news" begin
  path = joinpath(news, "AGENTS.md")
  # The front page wrote it when it first showed
  @test isfile(path) && startswith(read(path, String), N.KEPT_LINE)
  @test !any(p -> p.name == "AGENTS", front().interests)
  # It says the reader's time zone, how many articles to write, and how long Ladder keeps them
  text = N.instructions(days=7, most=5, zone="Australia/Sydney")
  @test occursin("their time zone is Australia/Sydney", text) && occursin("5 at most for each section", text) && occursin("Read `Interests.md`", text)
  @test occursin("It deletes each article 7 days after its date", text)
  @test occursin("It keeps every article", N.instructions(days=0, zone=""))
  @test occursin("Read `feedback.csv`", text) && occursin("`liked: yes`", text) && occursin("Feeds.md", text)
  @test !occursin("time zone is", N.instructions(zone=""))
  # A post on x.com shows as a card in the story, in what both kinds of agent read
  @test occursin("![Sam Lee on X](https://x.com/", text) && occursin(N.X_POSTS, N.ask(N.Interest(name="X", words="Posts."), Dates.now()))
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
  shot("news-article-marked")
  # Didn't like it gives the other mark, and a click on a mark that's on takes it off
  click(middle(disliked))
  @test occursin("\nliked: no\n", read(a.path, String)) && !occursin("liked: yes", read(a.path, String))
  click(middle(disliked))
  @test !occursin("liked:", read(a.path, String)) && row(a.path).liked === nothing && row(a.path).read
  click(middle(liked))
  # The front page shows the mark on the story. Each reporter's score comes from feedback.csv, and the page doesn't show it.
  K.open_folder!(e, news)
  again()
  s = only(filter(s -> s[1] == a.by, N.scores(news)))
  @test s[2] == 1 && s[3] == 0 && s[4] >= 1 && s[5] >= s[4]
  shot("news-marks")
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
  @test getter() isa K.ToolButton && !K.off(getter())
  shot("news-feeds")
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

@testset "a reading companion talks with you about any article of the folder, in a session whose file keeps the talk" begin
  # Grok's stand-in for a session: it writes down each line of JSON-RPC that Ladder gives it, and answers as `grok agent stdio` does
  heard = joinpath(dir, "companion-heard.txt")
  grok = joinpath(dir, "companion-agent")
  write(grok, replace(raw"""
#!/bin/sh
say() { printf '%s\n' "$1"; }
answer() { say '{"jsonrpc":"2.0","result":'"$2"',"id":"'"$1"'"}'; }
words() { say '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"news-1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"'"$1"'"}}}}'; }
while IFS= read -r line; do
  printf '%s\n' "$line" >> "HEARD"
  id=$(printf '%s' "$line" | sed -n 's/.*"id":"\(ladder-[0-9]*\)".*/\1/p')
  case "$line" in
  *'"initialize"'*) answer "$id" '{"protocolVersion":1,"agentCapabilities":{"loadSession":true}}' ;;
  *'"session/new"'*) answer "$id" '{"sessionId":"news-1","models":{"currentModelId":"grok-4.7"}}' ;;
  *'"session/resume"'*) answer "$id" '{"models":{"currentModelId":"grok-4.7"}}' ;;
  *'"session/set_model"'*) answer "$id" '{}' ;;
  *'"session/prompt"'*)
    case "$line" in
    *'reading companion'*) words "I am ready." ;;
    *)
      words "I will read the article."
      say '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"news-1","update":{"sessionUpdate":"tool_call","toolCallId":"c1","title":"read_file","rawInput":{"target_file":"/tmp/story.md"}}}}'
      say '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"news-1","update":{"sessionUpdate":"tool_call_update","toolCallId":"c1","status":"completed"}}}'
      words "It is about **paint**." ;;
    esac
    answer "$id" '{"stopReason":"end_turn"}' ;;
  esac
done
""", "HEARD" => heard))
  chmod(grok, 0o755)
  K.ACP_COMMAND[] = Cmd([grok])
  K.COMPANION_IN_TEST[] = true
  K.AGENT_MODELS["Grok"] = K.grok_list("Default model: grok-4.7\n\nAvailable models:\n  * grok-4.7 (default)\n")
  lines() = isfile(heard) ? readlines(heard) : String[]
  until(f, most=10) = (t = time(); while !f() && time() - t < most; sleep(0.02); frames(1) end; f())
  folder = realpath(news)
  # Opening the front page starts one: a session of Grok whose file is in the folder of today's articles
  opens() = (K.open_folder!(e, news); K.state_of(e, K.NewsShown).at = 0.0; frames())
  opens()
  @test haskey(K.NEWS_COMPANIONS, folder)
  p = K.NEWS_COMPANIONS[folder][2]
  s = p.session
  day = joinpath(folder, Dates.format(Dates.today(), "yyyy-mm-dd"))
  @test p.file == joinpath(day, "Talk with Grok.chat") && isfile(p.file) && any(x -> x === p, K.chats(e)) && e.nodes[(:chat, p.file)] === p
  @test s.agent == "Grok" && !s.turns && s.dir == day && K.is_companion(p)
  ok = until(() -> !s.busy)
  @test ok && K.running(s) && s.id == "news-1" && last(s.items) isa K.AgentReply && last(s.items).text == "I am ready."
  said = lines()
  @test occursin("\"method\":\"session/new\"", said[2]) && occursin("\"cwd\":\"$day\"", said[2])
  @test occursin("\"method\":\"session/prompt\"", said[3]) && occursin("reading companion", said[3]) && occursin(folder, said[3]) && !occursin("ladder wait", said[3])
  @test !any(i -> startswith(i.name, "."), front().interests)
  # The file keeps the talk, and the session stays though its file has no tab
  frames(4)
  ok = until(() -> occursin("I am ready.", read(p.file, String)))
  @test ok && K.running(s) && !(p.file in K.tabs(e))
  # It doesn't start again while it runs
  opens()
  K.NEWS_COMPANIONS[folder] = (0.0, p)
  opens()
  @test count(l -> occursin("\"initialize\"", l), lines()) == 1 && K.NEWS_COMPANIONS[folder][2] === p
  # It's the agent of each article of the folder, and of no other page
  art = first(a for ed in front().editions for a in ed.articles)
  @test K.companion_pane(e, art.path) === p && K.companion_pane(e, joinpath(dir, "page.md")) === nothing && K.companion_pane(e, p.file) === nothing
  @test isempty(K.agents(e, art.path)) && isempty(K.elsewhere(e))
  # So Ask Agent on an article gives the session your words, and what Grok says last shows as the answer
  K.news_open!(e, art.path)
  frames()
  @test K.sharer(e) == "Grok" && K.asks_whom(e) == "Grok"
  k = findlast(l -> !isempty(strip(l)), e.buf.lines)
  thing = K.words_thing(e.buf, (k, 0), (k, 3))
  K.ask_sharer!(e, K.sharer(e), [thing], "What is this about?"; asks=true)
  a = K.code_picker(e).asked
  @test a.session === s && a.sent && a.by == "Grok" && s.busy
  ok = until(() -> a.ended > 0)
  @test ok && !a.failed && !a.changed && a.said == "Grok answered." && a.step == "Reading story.md"
  asked = last(filter(l -> occursin("session/prompt", l), lines()))
  @test occursin("The user's words: What is this about?", asked) && occursin(basename(art.path), asked) && occursin("answer it in your reply", asked) && !occursin("ladder wait", asked)
  box = only(K.ask_boxes(e))
  @test occursin("It is about **paint**.", last(box.answers).answer) && !occursin("I will read", last(box.answers).answer)
  empty!(K.ask_boxes(e))
  K.code_picker(e).asked = nothing
  # Settings can turn it off
  K.stop_companion!(e, folder)
  ok = until(() -> !K.running(s))
  @test ok && !haskey(K.NEWS_COMPANIONS, folder) && K.companion_pane(e, art.path) === nothing && K.sharer(e) == ""
  N.companion!(false)
  opens()
  @test !haskey(K.NEWS_COMPANIONS, folder)
  N.companion!(true)
  # A talk that the day already has goes on: the program resumes the session, and isn't told again what a companion is for
  n = count(l -> occursin("session/prompt", l), lines())
  opens()
  p2 = K.NEWS_COMPANIONS[folder][2]
  ok = until(() -> any(l -> occursin("\"method\":\"session/resume\"", l) && occursin("\"sessionId\":\"news-1\"", l), lines()))
  @test ok && p2 === p && K.running(p2.session) && count(l -> occursin("session/prompt", l), lines()) == n
  # A day's talk goes when all that day's articles have gone
  old = mkpath(joinpath(news, Dates.format(Dates.today() - Day(9), "yyyy-mm-dd")))
  write(joinpath(old, "Talk with Grok.chat"), "Hello\n")
  write(joinpath(old, "Talk with Grok.vt"), "Hello\n")
  gone = N.prune!(news; days=7)
  @test joinpath(old, "Talk with Grok.chat") in gone && joinpath(old, "Talk with Grok.vt") in gone && !isdir(old)
  # When the session says that something went wrong, the front page says so
  push!(p.session.items, K.SessionNote(words="Grok didn't start: no login.", bad=true))
  @test occursin("Grok, your reading companion, has a problem: Grok didn't start: no login.", K.companion_status(news))
  pop!(p.session.items)
  @test K.companion_status(news) == ""
  # The front page has a tab, and the companion ends when the tab closes, but not while an article of the folder shows
  @test news in K.tabs(e)
  K.news_open!(e, art.path)
  frames()
  @test haskey(K.NEWS_COMPANIONS, folder) && K.running(p.session)
  K.close_tab!(e, news)
  frames()
  ok = until(() -> !K.running(p.session))
  @test ok && !haskey(K.NEWS_COMPANIONS, folder) && !(news in K.tabs(e))
  K.COMPANION_IN_TEST[] = false
  K.ACP_COMMAND[] = nothing
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
  # A paper with many reporters with long names, as feeds and podcasts give it, stays in the window
  rows = join(("\"$(Dates.today() - Day(1))\",\"A show with a long name, number $i, about history and philosophy 🔓\",\"AI\",\"\",\"no\",\"Title $i\",\"\",\"x/$i.md\"\n" for i in 1:30))
  write(joinpath(news, "feedback.csv"), join(N.MARK_COLUMNS, ",") * "\n" * rows)
  narrow = Window(e, size=(900px, 900px))
  K.open_folder!(e, news)
  front().read = 0.0
  foreach(_ -> Base.invokelatest(frame, narrow), 1:4)
  @test length(N.scores(news)) >= 30
  shown = filter(r -> r !== nothing, [rect(s) for s in values(front().stories)])
  @test !isempty(shown) && all(r -> K.num(r.left) >= 0 && K.num(r.left + r.width) <= 900, shown)
  @test K.news_glyphs("Premium (🔓 for Sam)") == "Premium (for Sam)"
  close(narrow)
end

@testset "the date is at the left of the name when it fits, and the page doesn't scroll on into nothing" begin
  e.panel = false
  # Where the lead story is in a window `w` wide, and the room under the last story
  at(w) = begin
    win = Window(e, size=(w * px, 1400px))
    K.open_folder!(e, news)
    front().read = 0.0
    foreach(_ -> Base.invokelatest(frame, win), 1:4)
    lead = minimum(K.num(r.top) for r in filter(r -> r !== nothing, [rect(s) for s in values(front().stories)]))
    last = maximum(K.num(r.top + r.height) for r in filter(r -> r !== nothing, [rect(s) for s in values(front().stories)]))
    # The page's Scroll starts under the top bar
    room = K.num(e.scroll.content_height) - (last - K.num(K.above_page(e)) + K.num(e.scroll.offset))
    out = (lead=lead, room=room)
    haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "news-head-$w.png"), win)
    close(win)
    out
  end
  wide, narrow = at(1300), at(560)
  # In the wide window the date is on the line of the name, so the stories start higher than in the narrow one,
  # where the date is on a line of its own over the name
  @test narrow.lead - wide.lead > 15
  # Under the last story is the front page's own room, and not the room for typing that a page of text has
  @test wide.room < 80 && narrow.room < 80
end
