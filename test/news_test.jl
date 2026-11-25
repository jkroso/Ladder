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
  @test isempty(K.news_runs(news)) && [b.words for b in K.news_buttons(e, front())] == ["Get the News", "New Page"]
end

@testset "with Ladder's agents off, another agent writes the articles" begin
  m = K.sandbox(e)
  Base.invokelatest(Core.eval, m, :(news_agents!("off")))
  @test N.agents() == :off
  again()
  # There's no Get the News, and nothing starts an agent: not the button, the command, or a page with no news today
  @test [b.words for b in K.news_buttons(e, front())] == ["New Page"]
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

close(w)
