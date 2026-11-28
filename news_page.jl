# A folder of news: its front page, the agents that write its articles, its feeds, the reading companion and an article
#
# A folder of news is a newspaper that agents write for you. Its page
# `Interests.md` has a `##` heading for each kind of news that you want, like
# `## AI`, and under it your own words on what to look for and what to leave
# out. The heading is the name of the paper's section for its news. Interests,
# in the top bar of the front page, shows the page. news.jl says what else is
# in the folder: a folder for each day's articles, like `2026-11-25`.
#
# The folder shows as the front page of a newspaper: the folder's name as the
# masthead, the day under it, and then the newest day's articles, the most
# important first. The first is the lead story, with its first paragraphs. The
# next few are beside it, and the rest are in columns under it. The earlier
# days follow, with their headlines. A click on a story shows its article,
# which has the look of a newspaper's page. A day's folder shows as that day's
# front page.
#
# Once a day, when the front page shows, Ladder starts an agent for each section
# whose news it hasn't asked for that day: the agent that Settings chose. Get
# the News, the round arrow in the top bar, asks again now, for every section. Settings can leave the daily news
# out, so an agent works only when you click Get the News, or turn Ladder's
# agents off, for another agent that writes the articles, like one on a
# server. Then the page has no Get the News, and shows what that agent wrote.
# Ladder keeps the file AGENTS.md in the folder, which tells such an agent
# what to write and where: see `News.instructions`. A file of that name that
# you changed stays as it is. Each agent searches the web and
# replies with articles, which Ladder writes in the folder of the day. Three
# agents work at once, and the others wait. Ladder stops an agent that takes
# more than 15 minutes, and Stop stops them all. The front page says what each
# agent is doing, and what went wrong.
#
# Feeds.md in the folder lists RSS and Atom feeds (see feeds.jl). Ladder gets
# each every hour while the front page shows, and when you click Get the News,
# and each new post becomes an article by its author. So with Ladder's agents
# off, Get the News is there while the folder has feeds.
#
# An article's page has two buttons, Liked it and Didn't like it, which write
# your mark in its front matter. Ladder keeps each mark in feedback.csv, and
# tells its agents what you liked of their section. So each reporter, an
# agent or a feed's author, learns what you read and like. The front page
# doesn't show their scores.
#
# Ladder deletes each article when it's older than Settings keep the news: a
# week, unless you change it. It looks when it lists the folder, at most once
# in 10 minutes.
#
# ~/News is a folder of news when it's there. The command Open News makes it
# and shows it. Show Folder As makes any other folder one, as News.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect
@use "github.com/jkroso/UI.jl/Interface/window" system_menu
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./markdown" front_matter
@use "./spreadsheet" moved
@use "./remote" => Remote
@use "./folders" => Folders
@use "./news" => News
@use "./feeds" => Feeds
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use Colors: @colorant_str, RGBA
@use Dates: Dates, Day
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./additions" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./agent/kinds" exports...
@use "./agent/session" exports...
@use "./agent/pane" exports...
@use "./agent/ask" exports...

export COMPANION_IN_TEST, COMPANION_START, FEEDS_ASKED, FEEDS_COMING, FEEDS_SAID, FEED_EVERY,
       FEED_GETTER, NEWS, NEWS_AT_ONCE, NEWS_COMMAND, NEWS_COMPANION, NEWS_COMPANIONS, NEWS_ENDED,
       NEWS_FOLDER, NEWS_LONGEST, NEWS_MAST, NEWS_MEASURE, NEWS_MOST, NEWS_PRUNED, NEWS_SAID,
       NEWS_SANS, NEWS_STORY_MENU, NEWS_WAITING, NEWS_WIDEST, NEWS_WORKING, NO_GLYPHS, NewsDay,
       NewsDirectory, NewsFolder, NewsHead, NewsMark, NewsPage, NewsRun, NewsStory,
       companion_status, companion_words, companions_tick!, episodes_landed!, feed_landed!,
       feeds_tick!, get_feeds!, get_news!, get_the_news!, news_auto!, news_bar, news_busy,
       news_byline, news_clock, news_columns, news_command, news_companion!, news_day_name,
       news_day_words, news_done!, news_empty, news_folder, news_front, news_glyphs, news_head,
       news_head_foot, news_kicker, news_liked, news_mark!, news_mark_file!, news_now!, news_open!,
       news_options, news_prune!, news_read!, news_rule, news_runs, news_sheet, news_spread,
       news_start!, news_status, news_story, news_story!, news_story_act!, news_text, news_tick!,
       news_width, news_words, open_feeds!, open_interests!, open_news!, show_feeds!,
       show_interests!, stop_companion!, stop_news!

"A folder of news: a page that says the kinds of news that you want, and a folder for each day's articles. See \"a folder of news\"."
@def struct NewsDirectory <: AbstractDirectory end
"The folder of one day's articles, in a folder of news, named by the day, like 2026-11-25"
@def struct NewsDay <: AbstractDirectory end
const NewsFolder = Union{NewsDirectory,NewsDay}

# A folder in a folder of news holds a day's articles, when its name is a day
FS.kind(::NewsDirectory, path::FSPath) = News.edition_day(basename(string(path))) === nothing ? folder_kind(path) : NewsDay
FS.kind(::NewsDay, path::FSPath) = folder_kind(path)

# The icons of the news, which the built app reads while it's made, as it has no folder of icons
push!(BLOCK_ICONS, "newspaper", "arrow-clockwise", "card-list", "stop-circle", "pencil-square", "plus-lg", "hand-thumbs-up", "hand-thumbs-up-fill", "hand-thumbs-down", "hand-thumbs-down-fill")
entry_icon(::NewsDirectory) = "newspaper"

"The folder of news that Open News makes: ~/News. A test names a folder of its own."
const NEWS_FOLDER = Ref("")
news_folder() = isempty(NEWS_FOLDER[]) ? joinpath(home_folder(), "News") : NEWS_FOLDER[]

"When the old articles of each folder of news were last deleted, by the folder"
const NEWS_PRUNED = Dict{String,Float64}()

"Delete the articles of the folder of news `folder` that are older than Settings keep them, at most once in 10 minutes. It gives what went."
news_prune!(folder::AbstractString) = begin
  time() - get(NEWS_PRUNED, folder, 0.0) < 600 && return String[]
  NEWS_PRUNED[folder] = time()
  News.prune!(folder)
end

# The sidebar lists the days first, the newest at the top, and then the pages that say what news you want
entries(e, d::NewsDirectory) = begin
  news_prune!(string(d.path))
  found = invoke(entries, Tuple{Any,AbstractDirectory}, e, d)
  days = sort!(filter(o -> o isa NewsDay, found), by=o -> basename(string(o.path)), rev=true)
  [days; filter(o -> !(o isa NewsDay), found)]
end

"A click on a folder of news in the sidebar shows its front page, and the sidebar lists what it holds"
open!(e, d::NewsFolder; record=true) = (open!(e, string(d.path); record); go_folder!(e, string(d.path)))
page_view(e, d::NewsFolder) = (path = string(d.path); node!(() -> NewsPage(path=path, day=d isa NewsDay), e, (:news, path)))
# The front page ends with its own room, so a page that nearly fits the window doesn't scroll on into nothing
page_bottom(e, ::NewsFolder) = 0px
page_fills(e, ::NewsFolder) = true

# --- the agents that get the news ---

"An agent that gets the news of one page of a folder of news"
@def mutable struct NewsRun
  folder::String = ""
  interest::News.Interest = News.Interest()
  command::Any = nothing      # what starts it, with the words that it's asked going after
  by::String = ""             # the agent's name
  at::Dates.DateTime = Dates.DateTime(2000)   # when it was asked, by the Mac's clock
  started::Float64 = 0.0
  process::Any = nothing
  reading::Any = nothing      # the task that reads what it prints
  step::String = ""           # what it's doing now, as the front page says it
  late::Bool = false          # Ladder stopped it, as it took too long
end

"The agents that get news now"
const NEWS_WORKING = NewsRun[]
"The agents that wait for their turn to get news"
const NEWS_WAITING = NewsRun[]
"What came of the last agent of each section of `Interests.md`, by its key: `:note` and words for no news, or `:problem` and what went wrong"
const NEWS_SAID = Dict{String,Tuple{Symbol,String}}()
"When an agent last ended, so a front page reads its folder again"
const NEWS_ENDED = Ref(0.0)
"How many agents get news at once"
const NEWS_AT_ONCE = Ref(3)
"How many seconds an agent has to get the news before Ladder stops it"
const NEWS_LONGEST = Ref(15 * 60.0)
"The most articles that an agent writes for one page"
const NEWS_MOST = 5
"The command that gets the news, for a test: it's given the words that the agent would get. Nothing means the agent that Settings chose."
const NEWS_COMMAND = Ref{Any}(nothing)

"""
The options of the agent `k` for the news: it searches the web and reads
pages, and changes no file. Claude Code writes articles with Sonnet, in safe
mode, so no plugin, MCP server or hook of yours runs, and no session is kept.
"""
news_options(k::AgentKind) =
  k.name == "Claude" ? ["--model", "sonnet", "--output-format", "stream-json", "--verbose", "--safe-mode", "--no-session-persistence",
                        "--allowedTools", "WebSearch,WebFetch", "-p"] :
  k.name == "Grok" ? ["--permission-mode", "plan", "--no-memory", "-p"] : k.look

"The command that gets the news for the window of `e`, and the agent's name"
news_command(e) = begin
  NEWS_COMMAND[] === nothing || return (NEWS_COMMAND[], agent_kind(e.ai).name)
  k = agent_kind(e.ai)
  (kind_command(k, news_options(k)), k.name)
end

"The agents of the folder of news `folder` that get news now, and then those that wait for their turn"
news_runs(folder) = NewsRun[r for r in [NEWS_WORKING; NEWS_WAITING] if r.folder == folder]

"""
Ask for the news of each section of `pages`, the sections of `Interests.md`
in the folder of news `folder`, with the agent that Settings chose for `e`.
Each waits for its turn. A section that says nothing, or whose news is asked
for already, isn't asked.
"""
get_news!(e, folder::AbstractString, pages=News.interests(folder)) = begin
  # Another agent writes the news, so Ladder starts none
  News.agents() == :off && return nothing
  asked = Set(r.interest.key for r in [NEWS_WORKING; NEWS_WAITING])
  pages = [p for p in pages if !isempty(p.words) && !(p.key in asked)]
  isempty(pages) && return nothing
  command, by = try
    news_command(e)
  catch err
    foreach(p -> NEWS_SAID[p.key] = (:problem, trouble(err)), pages)
    return nothing
  end
  for p in pages
    delete!(NEWS_SAID, p.key)
    push!(NEWS_WAITING, NewsRun(folder=folder, interest=p, command=command, by=by))
  end
  news_tick!(e)
  nothing
end

"Stop the agents that get the news of the folder `folder`, and those that wait"
stop_news!(folder::AbstractString) = begin
  for r in news_runs(folder)
    r.process === nothing || (try kill(r.process) catch end)
    NEWS_SAID[r.interest.key] = (:note, "You stopped it.")
  end
  filter!(r -> r.folder != folder, NEWS_WORKING)
  filter!(r -> r.folder != folder, NEWS_WAITING)
  nothing
end

"Start the agent `r`. The news is new since the agent last got the news of its page, or else since two days ago."
news_start!(r::NewsRun) = begin
  now = Dates.now()
  last = News.last_ran(r.interest.key)
  since = last === nothing || last < now - Day(2) ? now - Day(2) : last
  liked = filter(m -> m.section == r.interest.name, News.marks(r.folder))
  words = News.ask(r.interest, now; printed=News.printed(r.folder, r.interest.name), since, most=NEWS_MOST, liked)
  News.ran!(r.interest.key, now)
  r.at, r.started = now, time()
  try
    r.process, r.reading = start_agent(r.command, words, r.folder, r)
    push!(NEWS_WORKING, r)
  catch err
    NEWS_SAID[r.interest.key] = (:problem, "Ladder couldn't start $(r.by): " * trouble(err))
  end
  nothing
end

"Write the articles that the agent `r` wrote, which has ended, or say why there are none"
news_done!(r::NewsRun) = begin
  printed = try fetch(r.reading) catch err; trouble(err) end
  text = agent_text(printed)
  found = News.reply_articles(text)
  key, name = r.interest.key, r.interest.name
  if !isempty(found)
    try
      News.write_articles!(r.folder, name, found, r.at; by=r.by)
      delete!(NEWS_SAID, key)
    catch err
      NEWS_SAID[key] = (:problem, "Ladder couldn't write the articles of $name: " * trouble(err))
    end
  elseif News.no_news(text)
    NEWS_SAID[key] = (:note, "$(r.by) found no news of $name.")
  else
    why = strip(first(split(strip(text) * "\n", '\n')))
    NEWS_SAID[key] = (:problem, r.late ? "$(r.by) took more than $(round(Int, NEWS_LONGEST[] / 60)) minutes on $name, so Ladder stopped it." :
                                 isempty(why) ? "$(r.by) wrote no articles for $name." : "$(r.by) wrote no articles for $name: " * request_words(why))
  end
  NEWS_ENDED[] = time()
  foreach(list_files!, editors)
  nothing
end

"""
Take in what the agents that ended wrote, stop one that took too long, and
start those that wait while fewer than `NEWS_AT_ONCE` work. Each window does
this in each frame, and while agents work it draws a frame twice a second.
"""
news_tick!(e) = begin
  feeds_tick!(e)
  companions_tick!(e)
  isempty(NEWS_WORKING) && isempty(NEWS_WAITING) && return nothing
  for r in copy(NEWS_WORKING)
    if r.reading === nothing || istaskdone(r.reading)
      filter!(x -> x !== r, NEWS_WORKING)
      news_done!(r)
    elseif !r.late && time() - r.started > NEWS_LONGEST[]
      r.late = true
      try kill(r.process) catch end
    end
  end
  while length(NEWS_WORKING) < NEWS_AT_ONCE[] && !isempty(NEWS_WAITING)
    news_start!(popfirst!(NEWS_WAITING))
  end
  redraw_in!(e, 0.5)
  nothing
end

each_frame!(news_tick!)

"Ask for the news of each section of the folder of `v` that hasn't had its news today, when Settings say to"
news_auto!(e, v) = begin
  (News.agents() == :daily && !v.day) || return nothing
  today = Dates.today()
  due = [p for p in v.interests if (l = News.last_ran(p.key); l === nothing || Dates.Date(l) < today)]
  isempty(due) || get_news!(e, v.path, due)
  nothing
end

# --- the feeds of a folder of news ---

"The feeds on their way from their servers, by their addresses, each with its folder of news. The shows of Apple Podcasts are a task that writes their episodes."
const FEEDS_COMING = Dict{String,Tuple{String,Feeds.Feed,Any}}()
"When Ladder last asked for each feed, by its address, as time() says"
const FEEDS_ASKED = Dict{String,Float64}()
"What went wrong when Ladder last got each feed, by its address"
const FEEDS_SAID = Dict{String,String}()
"How many seconds Ladder waits before it gets a feed again"
const FEED_EVERY = Ref(3600.0)
"What gets a feed, for a test: a function of the address, a file and a file for what the server said, as `Remote.curl` is. Nothing means curl."
const FEED_GETTER = Ref{Any}(nothing)

"Start to get each feed of the folder of news `folder` that Ladder hasn't got for an hour, or each now with `now`"
get_feeds!(folder::AbstractString; now=false) = begin
  for f in Feeds.feeds(folder)
    haskey(FEEDS_COMING, f.url) && continue
    now || time() - get(FEEDS_ASKED, f.url, -Inf) >= FEED_EVERY[] || continue
    FEEDS_ASKED[f.url] = time()
    # Apple Podcasts' library is read by a program, which the window doesn't wait for
    c = f.url == Feeds.PODCASTS ? (@async Feeds.write_episodes!(String(folder), f)) :
        FEED_GETTER[] === nothing ? Remote.ask(f.url) : Remote.ask(f.url; getter=FEED_GETTER[])
    FEEDS_COMING[f.url] = (String(folder), f, c)
  end
  nothing
end

"Write the posts of each feed that has come, as articles. Each window does this in each frame, with the agents."
feeds_tick!(e) = begin
  isempty(FEEDS_COMING) && return nothing
  for (url, (folder, f, c)) in collect(FEEDS_COMING)
    if c isa Task
      istaskdone(c) || continue
      delete!(FEEDS_COMING, url)
      episodes_landed!(f, c)
      continue
    end
    a = Remote.landed(c)
    a === nothing && continue
    delete!(FEEDS_COMING, url)
    feed_landed!(folder, f, a)
  end
  redraw_in!(e, 0.5)
  nothing
end

"Write the new posts of the feed `f` of the folder of news `folder`, from what its server answered, `a`, or say what went wrong"
feed_landed!(folder, f::Feeds.Feed, a) = begin
  if !(200 <= a.status < 300)
    FEEDS_SAID[f.url] = a.status == 0 ? "Ladder couldn't get the feed $(f.url)." : "Ladder couldn't get the feed $(f.url): its server answered $(a.status)."
    return nothing
  end
  name, posts = try Feeds.read_feed(String(copy(a.bytes))) catch; ("", Feeds.Post[]) end
  if isempty(name) && isempty(posts)
    FEEDS_SAID[f.url] = "$(f.url) isn't an RSS or Atom feed."
    return nothing
  end
  delete!(FEEDS_SAID, f.url)
  written = try
    Feeds.write_posts!(folder, f, name, posts)
  catch err
    FEEDS_SAID[f.url] = "Ladder couldn't write the posts of $(isempty(name) ? f.url : name): " * trouble(err)
    String[]
  end
  isempty(written) && return nothing
  NEWS_ENDED[] = time()
  foreach(list_files!, editors)
  nothing
end

"Say what came of the task `c` that wrote the new episodes of Apple Podcasts, of the line `f` of Feeds.md"
episodes_landed!(f::Feeds.Feed, c::Task) = begin
  written = try
    fetch(c)
  catch err
    why = err isa TaskFailedException ? err.task.exception : err
    FEEDS_SAID[f.url] = why isa ErrorException ? why.msg * "." : "Ladder couldn't write the episodes of Apple Podcasts: " * trouble(why)
    return nothing
  end
  delete!(FEEDS_SAID, f.url)
  isempty(written) && return nothing
  NEWS_ENDED[] = time()
  foreach(list_files!, editors)
  nothing
end

"Show `Feeds.md` of the folder of news `folder`, which lists its feeds. Ladder makes it, with what it's for, when it isn't there."
open_feeds!(e, folder::AbstractString) = begin
  path = joinpath(folder, Feeds.FILE)
  isfile(path) || (try write(path, Feeds.PAGE) catch; return nothing end)
  open!(e, path)
  list_files!(e)
  nothing
end

"Show `Interests.md` of the folder of news `folder`, which says the kinds of news that you want. Ladder makes it, with what it's for, when it isn't there."
open_interests!(e, folder::AbstractString) = begin
  path = joinpath(folder, News.INTERESTS)
  isfile(path) || (try write(path, News.INTERESTS_PAGE) catch; return nothing end)
  open!(e, path)
  list_files!(e)
  nothing
end

"Show the page that says the kinds of news that you want, of the folder of news that shows"
show_interests!(e) = (o = page_object(e); o isa NewsDirectory ? open_interests!(e, string(o.path)) : nothing)
add_command!(show_interests!, title="Show the page that says the news that you want, of the folder of news that shows: Interests.md")
works_here(e, ::Val{:show_interests}) = page_object(e) isa NewsDirectory

"Show the page that lists the feeds of the folder of news that shows"
show_feeds!(e) = (o = page_object(e); o isa NewsDirectory ? open_feeds!(e, string(o.path)) : nothing)
add_command!(show_feeds!, title="Show the page that lists the RSS and Atom feeds of the folder of news that shows: Feeds.md")
works_here(e, ::Val{:show_feeds}) = page_object(e) isa NewsDirectory

"Get the news of the folder of news `folder` now: its feeds, and the news of each section from Ladder's agent, when Settings let it"
news_now!(e, folder::AbstractString) = (get_feeds!(folder; now=true); get_news!(e, folder))

# --- a reading companion for a folder of news ---
#
# When you open a folder of news, Ladder starts a session with Grok behind
# the page, to talk with about what you read: your reading companion. The
# session's file is `Talk with Grok.chat` in the folder of today's articles,
# so it keeps the talk, and it goes when that day's articles go. Open it to
# read the talk, or to talk with Grok there. A talk that the day already has
# goes on.
#
# Ladder counts the companion as the agent of each article of the folder. So
# on any article, Ask Grok… gives its session your words, and what it says
# shows under what you marked: see "a request that a session answers". It's
# one session, so it remembers what you talked about. The folder's front
# page has a tab, like a file, and the companion ends when that tab closes,
# or its window.
#
# Ladder starts the companion again when you open the front page, its
# program has ended and it didn't start in the last five minutes. A window
# that keeps no settings, as a test's, starts none. Settings can turn the
# companion off.

"The agent that Ladder starts as a reading companion, when it's installed. Else it's the agent that Settings chose."
const NEWS_COMPANION = "Grok"
"The reading companions that Ladder started, by their folders: when, and the pane of the session's file of each"
const NEWS_COMPANIONS = Dict{String,Tuple{Float64,Any}}()
"How many seconds a companion has to start before Ladder looks at its program"
const COMPANION_START = Ref(300.0)
"A test makes it true, so that its window, which keeps no settings, starts a companion"
const COMPANION_IN_TEST = Ref(false)

"What the reading companion of the folder of news `folder` is told first"
companion_words(folder) = """
You're my reading companion. I read the newspaper in the folder $folder in Ladder, an app that shows it as a newspaper, and I'll ask you about what I'm reading. It's one conversation for as long as I read, so remember what we talk about.

Read $(News.INSTRUCTIONS) in that folder to learn how the paper is made, and the titles and summaries of the newest day's articles, in the folder named by the date. $(News.FEEDBACK) says which articles I opened and which I liked. Don't change any file of the paper. Then say in one sentence that you're ready.

Each question of mine comes from Ladder, with the page that I'm reading and the words that I marked on it. Read the article. When it doesn't have the answer, search the web, or X. Answer in a few short sentences of Markdown. Ladder shows the last thing that you say under the words that I marked, so put the whole answer there."""

"True when the pane `p` is the session's file of a reading companion that runs"
is_companion(p) = any(c -> c[2] === p, values(NEWS_COMPANIONS))

"""
The pane of the reading companion of the file at `path`: the session's file
of the companion that the window of `e` started for the folder of news that
holds the file. It's nothing for a file with no companion, and for the
companion's own file.
"""
companion_pane(e, path) = begin
  (isempty(NEWS_COMPANIONS) || isempty(path)) && return nothing
  at = truepath(path)
  for (folder, (_, p)) in NEWS_COMPANIONS
    startswith(at, folder * "/") && p.session !== nothing && at != truepath(p.file) && any(x -> x === p, chats(e)) && return p
  end
  nothing
end

"""
Start the reading companion of the folder of news `folder` for the window of
`e`, unless it has just started or its program still runs. Its session goes
on with the talk that today's folder already has, or starts one with what a
companion is for.
"""
news_companion!(e, folder) = begin
  (News.companion() && (e.remember || COMPANION_IN_TEST[])) || return nothing
  folder = truepath(folder)
  started = get(NEWS_COMPANIONS, folder, nothing)
  if started !== nothing
    time() - started[1] < COMPANION_START[] && return nothing
    s = started[2].session
    s !== nothing && (s.busy || running(s)) && return nothing
  end
  k = agent_kind(NEWS_COMPANION)
  k = try agent_path(k); k catch; agent_kind(e.ai) end
  try
    # The file that an earlier Ladder made for a companion in a terminal to wait for
    rm(joinpath(folder, ".reading.md"), force=true)
    # The talk is kept in the folder of today's articles, which the agent works in
    day = joinpath(folder, Dates.format(Dates.today(), "yyyy-mm-dd"))
    mkpath(day)
    talk = joinpath(day, "Talk with $(k.name)$(first(CHATS))")
    isfile(talk) || write(talk, talk_mark("session", Dict("agent" => k.name, "folder" => day, "id" => "")) * "\n")
    p = get(e.nodes, (:chat, talk), nothing)
    if !(p isa AgentPane)
      p = e.nodes[(:chat, talk)] = AgentPane(file=talk)
      push!(chats(e), p)
    end
    p.session === nothing && load_talk!(p, e)
    NEWS_COMPANIONS[folder] = (time(), p)
    s = session!(p, e)
    any(it -> it isa YouSaid, s.items) || say!(s, companion_words(folder))
  catch
  end
  nothing
end

"""
End the reading companion of the folder of news `folder`, a session of the
window of `e`: its program ends, and its talk is written to its file.
"""
stop_companion!(e, folder) = begin
  started = pop!(NEWS_COMPANIONS, folder, nothing)
  started === nothing && return nothing
  p = started[2]
  s = p.session
  s === nothing && return nothing
  was = s.busy
  close!(s)
  was && (s.version += 1)   # what was under way is whole now
  keep_talk!(p)
  nothing
end

"End each reading companion of the window of `e` whose folder's tab has closed. A folder that shows still has its companion."
companions_tick!(e) = begin
  isempty(NEWS_COMPANIONS) && return nothing
  for (folder, (_, p)) in collect(NEWS_COMPANIONS)
    any(x -> x === p, chats(e)) || continue
    (any(t -> truepath(t) == folder, tabs(e)) || (!isempty(e.buf.path) && truepath(e.buf.path) == folder)) && continue
    stop_companion!(e, folder)
  end
  nothing
end

"The reading companions of the window of `e` end with it: `close_chats!` ends each session and writes its file"
end_companions!(e) = begin
  for (folder, (_, p)) in collect(NEWS_COMPANIONS)
    any(x -> x === p, chats(e)) && delete!(NEWS_COMPANIONS, folder)
  end
  nothing
end

"""
What the front page of `folder` says of its reading companion: what went
wrong, when the last thing in its session is that, like a program that
didn't start.
"""
companion_status(folder) = begin
  started = get(NEWS_COMPANIONS, truepath(folder), nothing)
  started === nothing && return ""
  p = started[2]
  s = p.session
  (s === nothing || isempty(s.items)) && return ""
  it = last(s.items)
  it isa SessionNote && it.bad ? "$(s.agent), your reading companion, has a problem: $(it.words) Open “$(basename(p.file))” in the folder $(basename(dirname(p.file))) to see the talk." : ""
end

# --- the front page ---

"The typeface of a newspaper's name at the top of its front page"
const NEWS_MAST = "Big Caslon"
"The typeface of the small capitals that name a story's section"
const NEWS_SANS = "Helvetica Neue"

"The colours of a newspaper: black ink on newsprint, and its links in a dark blue. Code keeps the colours of the paper theme."
const NEWS = Palette(bg=colorant"rgb(246,243,236)", ink=colorant"rgb(22,22,22)", dim=colorant"rgb(88,86,82)",
                     faint=colorant"rgb(150,146,138)", marker=colorant"rgb(110,106,100)",
                     line=colorant"rgb(206,201,190)", chip=colorant"rgb(236,232,222)",
                     chip_line=colorant"rgb(214,208,196)", block=colorant"rgb(240,236,227)",
                     head=colorant"rgb(236,232,222)", stripe=colorant"rgb(240,237,229)",
                     accent=colorant"rgb(28,72,122)", select=RGBA(0.11, 0.28, 0.48, 0.2),
                     panel=colorant"rgb(238,234,225)", hover=colorant"rgb(230,225,214)",
                     active=colorant"rgb(222,216,203)", float=colorant"rgb(250,248,243)",
                     shade=RGBA(0.1, 0.1, 0.1, 0.18),
                     comment=PAPER.comment, string=PAPER.string, number=PAPER.number,
                     keyword=PAPER.keyword, call=PAPER.call, type=PAPER.type)
"How many times the size of its text an article is wide: about 11 words to a line, as a wide column of a newspaper has"
const NEWS_MEASURE = 38.0
"The widest a front page gets, before zooming. In a wider window it's in the middle, so it keeps a newspaper's shape."
const NEWS_WIDEST = 1140px

"True when the window shows a front page of a folder of news, or an article of one, which have a newspaper's look"
news_look(e) = begin
  term_page(e.buf) && return false
  o = page_object(e)
  o isa NewsFolder && return true
  o === nothing || return false
  o = text_object(e)
  o isa FSObject && !(o isa AbstractDirectory) && o.parent isa NewsDay
end

"The front page of a folder of news, or of one day's folder of its articles"
@def mutable struct NewsPage <: SemanticUI
  path::String = ""
  day::Bool = false                                       # it's the folder of one day's articles
  editions::Vector{News.Edition} = News.Edition[]
  interests::Vector{News.Interest} = News.Interest[]
  feeds::Vector{Feeds.Feed} = Feeds.Feed[]                # the feeds that Feeds.md lists
  read::Float64 = 0.0                                     # when the folder was last read
  stories::Dict{String,Any} = Dict{String,Any}()          # the node of each story, by its article's path
end

"A story on a front page: its look, which a click on it opens the article of"
@def mutable struct NewsStory <: SemanticUI
  path::String = ""
  look::Any = nothing   # a function of the story that gives what it shows, as it can be under the mouse
end

describe(s::NewsStory) = s.look === nothing ? Box() : s.look(s)
cursor(::NewsStory) = :hand
onkey(s::NewsStory, ::KeyPress{Keys.mouse_left}) = (news_open!(editor(s), s.path); handled)

"""
Show the article at `path`, from its story on a front page. The first time,
Ladder writes `read:` and the time in it, as what you open is a kind of
feedback too.
"""
news_open!(e, path) = begin
  text = try read(path, String) catch; "" end
  new = isempty(text) ? text : News.opened(text)
  if new != text
    try
      write(path, new)
      News.keep_marks!(dirname(dirname(path)))
      NEWS_ENDED[] = time()
    catch
    end
  end
  open_folder!(e, path)
  nothing
end

"The menu of a story on a front page: Open, and the marks, with a tick on the mark that its article has"
const NEWS_STORY_MENU = ["Open", "-", "Liked It", "Didn't Like It"]

"""
A right-click on a story shows its menu, so you can mark its article without
opening it. A mark with a tick is the article's mark now, and choosing it
takes the mark off.
"""
onkey(s::NewsStory, ev::KeyPress{Keys.mouse_right}) = begin
  a = News.article(s.path)
  a === nothing && return handled
  ticked = a.liked === nothing ? () : [(a.liked ? 3 : 4,)]
  act(i...) = news_story_act!(editor(s), s.path, last(i))
  system_menu(ev.window, NEWS_STORY_MENU, act; ticked) || drawn_menu!(ev.window, NEWS_STORY_MENU, act; ticked)
  handled
end

"Do what the item `i` of the menu of the story of the article at `path` says"
news_story_act!(e, path, i) = begin
  item = get(NEWS_STORY_MENU, i, "")
  item == "Open" && return news_open!(e, path)
  item in ("Liked It", "Didn't Like It") || return nothing
  a = News.article(path)
  a === nothing && return nothing
  liked = item == "Liked It"
  news_mark_file!(path, a.liked === liked ? nothing : liked)
end

"""
Give the article in the file at `path` your mark, as `news_mark!` does, by
writing its file. A window that shows the file reads it again.
"""
news_mark_file!(path, liked::Union{Bool,Nothing}) = begin
  text = try read(path, String) catch; return nothing end
  new = News.marked(text, liked)
  new == text && return nothing
  try write(path, new) catch; return nothing end
  News.keep_marks!(dirname(dirname(path)))
  NEWS_ENDED[] = time()
  nothing
end

"The story of the front page `v` for the article `a`, which looks as `look` says"
news_story!(v::NewsPage, a::News.Article, look) = begin
  length(v.stories) > 2000 && empty!(v.stories)
  s = get!(() -> own!(v, NewsStory(path=a.path)), v.stories, a.path)
  s.look = look
  s
end

"Read the folder of the front page `v` again, two seconds after it was last read, or when an agent has ended. Articles that are too old go first."
news_read!(e, v::NewsPage) = begin
  time() - v.read < 2 && v.read > Folders.changed() && v.read > NEWS_ENDED[] && return nothing
  v.read = time()
  top = v.day ? dirname(v.path) : v.path
  isempty(news_prune!(top)) || list_files!(e)
  # The instructions for an agent of your own are there, and up to date
  v.day || !News.write_instructions!(top; most=NEWS_MOST) || list_files!(e)
  if v.day
    d = News.edition_day(basename(v.path))
    v.editions = d === nothing ? News.Edition[] : [News.Edition(day=d, path=v.path, articles=News.day_articles(v.path, d))]
    filter!(ed -> !isempty(ed.articles), v.editions)
  else
    v.editions = News.editions(v.path)
  end
  v.interests = News.interests(top)
  v.feeds = Feeds.feeds(top)
  # Each mark is in feedback.csv, and the feeds come every hour
  News.keep_marks!(top)
  v.day || get_feeds!(top)
  nothing
end

"A day as a newspaper names it: Wednesday 25 November 2026"
news_day_words(d) = Dates.format(d, "E d U yyyy")
"The time of `t` as a clock shows it: 7:31 am"
news_clock(t::Dates.DateTime) = (h = Dates.hour(t); "$(h % 12 == 0 ? 12 : h % 12):$(lpad(Dates.minute(t), 2, '0')) $(h < 12 ? "am" : "pm")")
"What the day `d` is called over its stories: Today, Yesterday, or its name"
news_day_name(d) = d == Dates.today() ? "Today" : d == Dates.today() - Day(1) ? "Yesterday" : news_day_words(d)

"""
Words in the newspaper's type that wrap to their box. `lead` is how far apart
their lines are, by the size of the type: a headline's are close, as a
newspaper's are, and a paragraph's further apart.
"""
news_text(s, size; color=colours.ink, style="", family=NEWS_TYPE, align=TextAlign.Left, lead=1.45) =
  Box(width(grow=grow), Text(news_glyphs(s), size=size, family=family, subfamily=style, color=color, wrap=WrapMode.words, align=align, lineheight=size * lead))
"Words in the newspaper's type on one line"
news_words(s, size; color=colours.ink, style="", family=NEWS_TYPE) =
  Box(Text(news_glyphs(s), size=size, family=family, subfamily=style, color=color, wrap=WrapMode.none))

"How wide `news_words` draws `s`"
news_width(s, size, style, family) = width_in(Face(family, style, size, colours.ink, false), news_glyphs(s))

"""
The words `s` without the emoji and the symbols that the newspaper's type
hasn't got, which a Text would draw as boxes: a podcast's name can have one,
like 🔓. A space after one goes too.
"""
news_glyphs(s) = replace(s, NO_GLYPHS => "")
const NO_GLYPHS = Regex("[\U1F000-\U1FAFF\u2600-\u27BF\u2B00-\u2BFF\uFE0F\u200D]+\\s?")
"A line across the page"
news_rule(h=1px; color=colours.ink) = Box(width(grow=grow), height(h), background(color))
"The small capitals over a headline that name its story's section"
news_kicker(a::News.Article, z) = news_words(uppercase(a.section), 10.5px * z, color=colours.accent, style="Bold", family=NEWS_SANS)
"The mark that you gave an article: a hand with its thumb up when you liked it, or down when you didn't"
news_liked(liked::Bool, size) = Icon(liked ? "hand-thumbs-up-fill" : "hand-thumbs-down-fill", size=size, color=liked ? colours.accent : colours.dim)

"Who wrote the article `a`, and when"
news_byline(a::News.Article, z) =
  news_words(join(filter(!isempty, [isempty(a.by) ? "" : "By $(a.by)", news_clock(a.when)]), "  ·  "), 11px * z, color=colours.dim, family=NEWS_SANS)

"A story with its section, its headline in `size`, and its summary in `small`, or no summary when `small` is nothing. With `opening`, its byline and that many of its first paragraphs follow."
news_story(v, a::News.Article, size, small, z; opening=0) = news_story!(v, a, s -> begin
  over = ishovered(s)
  paras = opening > 0 ? News.paragraphs(a) : String[]
  # A headline's box ends at the foot of its capitals, so big type needs more space under it.
  # The lead story's summary and byline get more space too.
  under = opening > 0 ? 0.3size : 0.08size
  Column(width(grow=grow), Alignment.Start, child_gap=9px * z, name="Story",
    a.liked === nothing ? news_kicker(a, z) : Row(child_gap=6px * z, news_kicker(a, z), news_liked(a.liked, 10.5px * z)),
    Box(width(grow=grow), padding(0px, 0px, under, 0px),
      news_text(a.title, size, style="Bold", color=over ? colours.accent : colours.ink, lead=1.12)),
    (small === nothing || isempty(a.summary) ? () :
      (Box(width(grow=grow), padding(0px, 0px, opening > 0 ? 6px * z : 0px, 0px), news_text(a.summary, small, color=colours.dim, lead=1.35)),))...,
    (opening > 0 ? (news_byline(a, z),) : ())...,
    (opening > 0 ? (Column(width(grow=grow), Alignment.Start, padding(0px, 6px * z), child_gap=20px * z,
                           (news_text(p, 15.5px * z) for p in paras[1:min(end, opening)])...),) : ())...,
    (length(paras) > opening > 0 ? (news_words("Continue reading", 13px * z, color=colours.accent, style="Bold", family=NEWS_SANS),) : ())...)
end)

"Columns with a line between each two, from the left, each as wide as one of `of` would be. A column with nothing in it isn't there."
news_columns(cols, z; gap=22px, of=length(cols)) =
  Row(width(grow=grow), Alignment.Start, child_gap=gap * z, border(1px, :solid, colours.line; between=true)[:between],
      (Column(width(percent=1 / of), Alignment.Start, child_gap=0px, c...) for c in cols if !isempty(c))...)

"The stories `as` in `n` columns, the first in the first column, the second in the next, and so on, with a line between two in a column"
news_spread(v, as, n, z; size=18px, small=14px) = begin
  cols = [Any[] for _ in 1:n]
  for (i, a) in enumerate(as)
    c = cols[mod1(i, n)]
    isempty(c) || push!(c, Box(width(grow=grow), padding(0px, 12px * z), news_rule(color=colours.line)))
    push!(c, news_story(v, a, size * z, small === nothing ? nothing : small * z, z))
  end
  news_columns(cols, z; of=n)
end

"What the front page `v` says over its stories about the agents of its folder: what each does, and what went wrong"
news_status(e, v::NewsPage, z) = begin
  lines = Any[]
  for r in news_runs(v.path)
    working = any(x -> x === r, NEWS_WORKING)
    mins = round(Int, (time() - r.started) / 60)
    words = working ? "$(r.by) is getting the news of $(r.interest.name)" * (isempty(r.step) ? "" : ": " * r.step) * (mins > 0 ? "  ·  $mins min" : "") :
                      "The news of $(r.interest.name) waits for its turn"
    push!(lines, news_words(words * "…", 13px * z, color=colours.dim, style="Italic"))
  end
  for p in v.interests
    said = get(NEWS_SAID, p.key, nothing)
    said === nothing && continue
    push!(lines, news_text(said[2], 13px * z, color=said[1] == :problem ? colours.removed : colours.dim, style="Italic"))
  end
  asks = v.day ? "" : companion_status(v.path)
  isempty(asks) || push!(lines, news_text(asks, 13px * z, color=colours.removed, style="Italic"))
  # A feed that went wrong has a line. When more than two did, as when the Mac is offline, one line says so.
  wrong = [FEEDS_SAID[f.url] for f in v.feeds if !isempty(get(FEEDS_SAID, f.url, ""))]
  says = length(wrong) <= 2 ? wrong : ["Ladder couldn't get $(length(wrong)) of the feeds. The first: " * lowercasefirst(replace(wrong[1], r"^Ladder couldn't get " => "")), ]
  foreach(s -> push!(lines, news_text(s, 13px * z, color=colours.removed, style="Italic")), says)
  isempty(lines) && return ()
  (Column(width(grow=grow), Alignment.Start, padding(0px, 8px * z), child_gap=4px * z, lines...),)
end

"The front page that the window shows, or nothing"
news_front(e) = (o = page_object(e); o isa NewsDirectory && readonly(e.buf) ? get(e.nodes, (:news, string(o.path)), nothing) : nothing)

"True while the agents get the news of the folder at `path`, or its feeds are on their way"
news_busy(path) = !isempty(news_runs(path)) || any(c -> c[1] == path, values(FEEDS_COMING))

"""
The buttons of the top bar on the front page of a folder of news. Interests
shows `Interests.md`, which says the kinds of news that you want. The round
arrow gets the news now: the posts of the feeds, and the news of each section
from Ladder's agent. It turns while they come, and then a click stops the
agents. A folder with nothing to get the news from, no agent and no feeds,
has no round arrow.
"""
news_bar(e) = begin
  v = news_front(e)
  v === nothing && return ()
  gets = !(News.agents() == :off && isempty(v.feeds) && !news_busy(v.path))
  (button(e, :news_interests, "card-list"), (gets ? (button(e, :get_news, "arrow-clockwise"),) : ())..., Box(width(4px)))
end
BAR_PARTS[:news] = news_bar
BUTTONS[:news_interests] = (
  run=e -> (v = news_front(e); v === nothing ? nothing : open_interests!(e, v.path)),
  tip=e -> "Interests: the page that says the news you want, with a heading for each section",
  off=e -> false,
  strong=false)
BUTTONS[:get_news] = (
  run=e -> (v = news_front(e); v === nothing ? nothing : isempty(news_runs(v.path)) ? news_now!(e, v.path) : stop_news!(v.path)),
  tip=e -> (v = news_front(e); v !== nothing && !isempty(news_runs(v.path)) ? "Click to stop the agents that are getting the news" :
                                "Get the news now: the posts of the feeds, and the news of each section from Ladder's agent"),
  # With no feeds, the agents need a page that says what news to get
  off=e -> (v = news_front(e); v === nothing || (isempty(v.feeds) && all(p -> isempty(p.words), v.interests))),
  busy=e -> (v = news_front(e); v !== nothing && news_busy(v.path)),
  strong=false)

"What the front page `v` shows when it has no stories: how to ask for news, or that the agents are getting it"
news_empty(e, v::NewsPage, z) = begin
  busy = !isempty(news_runs(v.path))
  off = News.agents() == :off
  says = off ?
    ("No news yet.",
     "Ladder starts no agent for the news, as Settings say. The articles that your own agent writes show here, and so do the posts of the feeds that Feeds.md lists. " *
     "Tell your agent to read $(News.INSTRUCTIONS) in this folder, which says what to write and where.") :
    isempty(v.interests) ?
    ("What news do you want?",
     "Click Interests, at the right of the top bar, and write a heading for each kind of news that you want, like ## AI. " *
     "Under it, say in your own words what to look for, and what to leave out. The heading is the name of its section. " *
     "Once a day, the agent that Settings chose reads each section, searches the web and writes the articles that show here.") :
    busy ? ("The first edition is on its way.", "An agent is reading the web for each of your interests. Its articles show here when it's done.") :
    v.day ? ("No articles.", "This day's articles have gone.") :
            ("No news yet.", "Click the round arrow at the right of the top bar, and an agent reads the web for each of your interests.")
  Column(width(grow=grow), Alignment.Center, padding(0px, 60px * z), child_gap=14px * z,
    news_text(says[1], 30px * z, style="Bold", align=TextAlign.Center, lead=1.12),
    Box(width(max=560px * z, grow=grow), news_text(says[2], 16px * z, color=colours.dim, align=TextAlign.Center)))
end

describe(v::NewsPage) = begin
  e = editor(v)
  news_read!(e, v)
  news_auto!(e, v)
  # The front page draws at least every two seconds, so a longer gap means that it has just opened
  shown, e.nodes[:news_shown] = get(e.nodes, :news_shown, 0.0), time()
  !v.day && time() - shown > 10 && news_companion!(e, v.path)
  redraw_in!(e, 2)   # the folder is read again, so a new article gets its story
  z = e.zoom
  wide = min(num(text_width(e)), num(NEWS_WIDEST * z))
  n = wide >= 980 ? 3 : wide >= 640 ? 2 : 1
  top = v.day ? dirname(v.path) : v.path
  newest = isempty(v.editions) ? nothing : v.editions[1]
  day = newest === nothing ? (v.day ? something(News.edition_day(basename(v.path)), Dates.today()) : Dates.today()) : newest.day
  sections = join((p.name for p in v.interests if !isempty(p.words)), "  ·  ")
  keep = News.keep_days()
  kept = keep == 0 ? "Kept for ever" : keep == 1 ? "Kept for a day" : keep == 7 ? "Kept for a week" : "Kept for $keep days"
  dated, named = uppercase(news_day_words(day)), basename(top)
  date, name = news_words(dated, 11px * z, style="Bold", family=NEWS_SANS), news_words(named, 72px * z, family=NEWS_MAST)
  # The date is at the left of the name, as a newspaper's ear is, when the line has room for it. The room at the right
  # is as wide, so the name is in the middle. The date stands on the name's baseline, as a Text's box ends at its
  # baseline. In a narrow window the date is on a line of its own over the name. The page's buttons are in the top bar.
  side = num(news_width(dated, 11px * z, "Bold", NEWS_SANS))
  gap = 24 * z
  ears = wide >= num(news_width(named, 72px * z, "", NEWS_MAST)) + 2side + 2gap
  # The type's box ends at its baseline, so the space under the name is more than over it
  masthead = ears ?
    (Row(width(grow=grow), Alignment.End, padding(8px * z, 0px, 24px * z, 0px), child_gap=gap * px,
       Row(width(grow=grow, min=side * px), date, Box(width(grow=grow))), name, Box(width(grow=grow, min=side * px))),) :
    (Row(width(grow=grow), height(30px * z), Alignment.Center, date),
     Box(width(grow=grow), Alignment.Center, padding(4px * z, 0px, 24px * z, 0px), name))
  head = Column(width(grow=grow), Alignment.Center, child_gap=0px, masthead...,
    news_rule(3px), Box(height(2px)), news_rule(),
    Row(width(grow=grow), height(28px * z), Alignment.Center, child_gap=12px,
      news_words(news_day_name(day), 12px * z, style="Italic"), Box(width(grow=grow)),
      news_words(uppercase(sections), 10.5px * z, color=colours.dim, style="Bold", family=NEWS_SANS),
      Box(width(grow=grow)), news_words(kept, 12px * z, color=colours.dim, style="Italic")),
    news_rule())
  newest === nothing && return news_sheet(z, head, news_status(e, v, z)..., news_empty(e, v, z))
  as = newest.articles
  lead, side, rest = as[1], as[2:min(end, 4)], as[5:end]
  front = if n == 1
    Column(width(grow=grow), Alignment.Start, child_gap=18px * z,
      news_story(v, lead, 30px * z, 17px * z, z; opening=2),
      (Column(width(grow=grow), Alignment.Start, child_gap=0px, news_rule(color=colours.line), Box(height(14px * z)),
              news_spread(v, as[2:end], 1, z)),)...)
  else
    sides = Any[]
    for (i, a) in enumerate(side)
      i > 1 && push!(sides, Box(width(grow=grow), padding(0px, 12px * z), news_rule(color=colours.line)))
      push!(sides, news_story(v, a, 21px * z, 14.5px * z, z))
    end
    Row(width(grow=grow), Alignment.Start, child_gap=22px * z, border(1px, :solid, colours.line; between=true)[:between],
      Column(width(percent=n == 3 ? 0.62 : 0.58), Alignment.Start, news_story(v, lead, 38px * z, 19px * z, z; opening=3)),
      Column(width(grow=grow), Alignment.Start, child_gap=0px, sides...))
  end
  earlier = Any[]
  for ed in v.editions[2:end]
    push!(earlier, Column(width(grow=grow), Alignment.Start, padding(30px * z, 0px, 0px, 0px), child_gap=10px * z,
      news_rule(2px), news_words(uppercase(news_day_name(ed.day)), 12px * z, style="Bold", family=NEWS_SANS),
      news_spread(v, ed.articles, n, z; size=15.5px, small=nothing)))
  end
  news_sheet(z, head, news_status(e, v, z)..., Box(height(18px * z)), front,
    (isempty(rest) ? () : (Box(width(grow=grow), padding(0px, 20px * z), news_rule()), news_spread(v, rest, n, z)))...,
    earlier...)
end

cursor(::NewsPage) = :arrow

"A front page with `parts`, from the top, no wider than `NEWS_WIDEST`, in the middle of the window"
news_sheet(z, parts...) =
  Column(width(grow=grow), Alignment.Center, child_gap=0px,
    Column(width(grow=grow, max=NEWS_WIDEST * z), Alignment.Start, padding(0px, 0px, 40px * z, 0px), child_gap=0px, name="Newspaper", parts...))

# --- an article ---

"The top of an article in a folder of news, in place of the card of its front matter: its section, headline, summary and byline, and your mark"
@def mutable struct NewsHead <: SemanticUI
  said::Dict{String,String} = Dict{String,String}()   # what the front matter sets, by its keys in small letters
  marks::Vector{Any} = Any[]                          # the buttons Liked it and Didn't like it
end

"""
A button at the top of an article that marks it: Liked it, or Didn't like it.
It shows your mark: its hand is filled while the article has its mark. A click
gives the article its mark, or takes the mark off when it has it.
"""
@def mutable struct NewsMark <: SemanticUI
  liked::Bool = true    # the mark that it gives: liked, or not liked
  on::Bool = false      # the article has its mark now
end

describe(m::NewsMark) = begin
  z = editor(m).zoom
  over = ishovered(m)
  colour = m.on ? colours.accent : over ? colours.ink : colours.dim
  icon = (m.liked ? "hand-thumbs-up" : "hand-thumbs-down") * (m.on ? "-fill" : "")
  Row(height(26px * z), padding(10px * z, 0px), radius(13px * z), child_gap=6px * z, Alignment.Center, name="Mark",
      background(m.on ? RGBA(colours.accent, 0.1) : over ? colours.hover : clear),
      border(1px, :solid, m.on ? RGBA(colours.accent, 0.45) : colours.line),
    Icon(icon, size=13px * z, color=colour),
    Box(Text(m.liked ? "Liked it" : "Didn't like it", size=12px * z, family=NEWS_SANS, subfamily="Medium", color=colour, wrap=WrapMode.none)))
end

cursor(::NewsMark) = :hand
onkey(m::NewsMark, ev::KeyPress{Keys.mouse_left}) = (hide_tooltip!(ev.window); news_mark!(editor(m), m.on ? nothing : m.liked); handled)
onmouse(m::NewsMark, ev::MouseMove) = begin
  r = rect(m)
  r === nothing && return handled
  tip = m.on ? "Click to take your mark off" :
        m.liked ? "Click to mark that you liked it. Its reporter learns from your marks." : "Click to mark that you didn't like it. Its reporter learns from your marks."
  show_tooltip!(ev.window, tip_label(tip), r.left, r.top, r.width, r.height, placement=:bottom, gap=6px)
  handled
end

"""
Give the article that the window of `e` shows your mark: `liked: yes` in its
front matter for true, `liked: no` for false, or no mark for nothing. The
caret stays where it was. Ladder saves the article, so its reporter and
feedback.csv have the mark at once.
"""
news_mark!(e, liked::Union{Bool,Nothing}) = begin
  b = e.buf
  lines = b.lines
  stop = front_matter(lines)
  (stop > 0 && rstrip(lines[1]) == "---") || return nothing
  was = join(lines[1:stop], '\n')
  new = News.marked(was, liked)
  new == was && return nothing
  caret, anchor = b.caret, b.anchor
  lo, hi = (1, 0), (stop, length(lines[stop]))
  edit!(b, lo, hi, new)
  ends = b.caret
  b.caret, b.anchor = moved(caret, lo, hi, ends), moved(anchor, lo, hi, ends)
  save!(b)
  folder = dirname(dirname(b.path))
  News.keep_marks!(folder)
  NEWS_ENDED[] = time()
  nothing
end

matter_view(e, ::NewsDay, ::FS.File{:md}, rows) = news_head(e, rows)

"The top of an article, with what its front matter `rows` say"
news_head(e, rows) = begin
  h = node!(NewsHead, e, :news_head)
  h.said = Dict(lowercase(k) => String(strip(v, ['"', '\''])) for (_, k, v) in rows)
  h
end

describe(h::NewsHead) = begin
  e = editor(h)
  s = body(e).size
  z = e.zoom
  said = h.said
  when = tryparse(Dates.DateTime, get(said, "date", ""))
  by = get(said, "by", "")
  byline = join(filter(!isempty, [isempty(by) ? "" : "By $by", when === nothing ? "" : news_day_words(when) * ", " * news_clock(when)]), "  ·  ")
  section, summary = get(said, "section", ""), get(said, "summary", "")
  Column(width(grow=grow), Alignment.Start, padding(s * 0.4, 0px, s * 1.1, 0px), child_gap=s * 0.6, name="Headline",
    (isempty(section) ? () : (news_words(uppercase(section), 11px * z, color=colours.accent, style="Bold", family=NEWS_SANS),))...,
    # A headline's box ends at the foot of its capitals, so its big type needs more space under it
    Box(width(grow=grow), padding(0px, 0px, 0.3 * 2.1s, 0px), news_text(get(said, "title", ""), 2.1s, style="Bold", lead=1.12)),
    (isempty(summary) ? () : (Box(width(grow=grow), padding(0px, 0px, 0.25s, 0px), news_text(summary, 1.2s, color=colours.dim, style="Italic", lead=1.35)),))...,
    news_head_foot(h, byline, News.liked_word(get(said, "liked", "")), z),
    news_rule(color=colours.line))
end

"The line under an article's summary: its byline, and the buttons that mark it, at the right"
news_head_foot(h::NewsHead, byline, liked, z) = begin
  isempty(h.marks) && (h.marks = Any[own!(h, NewsMark(liked=true)), own!(h, NewsMark(liked=false))])
  for m in h.marks
    m.on = liked === m.liked
  end
  Row(width(grow=grow), Alignment.Center, child_gap=8px * z,
    (isempty(byline) ? () : (news_words(byline, 11.5px * z, color=colours.dim, family=NEWS_SANS),))...,
    Box(width(grow=grow)), h.marks...)
end

onkey(h::NewsHead, ev::KeyPress{Keys.mouse_left}) = click_page!(h, ev)

# --- opening the news ---

"""
Show the folder of news ~/News, and make it first when it isn't there. Its
front page then says how to ask for news.
"""
open_news!(e) = begin
  path = news_folder()
  isdir(path) || mkpath(path)
  open_folder!(e, path)
  list_files!(e)
  nothing
end
add_command!(open_news!, title="Show your newspaper: the folder News in your home folder, where agents write the news that you ask for")

"Ask the agents for the news of each section of the folder of news that shows, now, as the round arrow in the top bar does"
get_the_news!(e) = (o = page_object(e); o isa NewsDirectory ? news_now!(e, string(o.path)) : nothing)
add_command!(get_the_news!, title="Get the news of the folder of news that shows, now: the posts of its feeds, and the news of each section from Ladder's agent")
works_here(e, ::Val{:get_the_news}) = (o = page_object(e); o isa NewsDirectory && (News.agents() != :off || !isempty(Feeds.feeds(string(o.path)))))
