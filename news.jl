# The facts of a folder of news, apart from the window that shows it. main.jl
# draws the folder as the front page of a newspaper, and starts the agents.
#
# A folder of news holds a page for each kind of news that you want, like
# `AI.md`, which says in your own words what to look for. Once a day an agent
# reads each page, looks on the web for news of that kind, and writes an
# article for each story. The name of the page is the name of the paper's
# section for its news. A page called Readme isn't a kind of news: it can say
# what the folder is for, and so can `CLAUDE.md`.
#
# Ladder keeps a file called `AGENTS.md` in the folder, which tells an agent
# of your own how to write the articles: see `instructions`. Many agents read a
# file of that name by themselves when they start in the folder.
#
# The articles of a day are in a folder that has the day's name, like
# `2026-11-25`. Each is a page of Markdown with front matter that says its
# headline, its section, a line or two on what happened, how much it matters
# (1 to 10), when it was written and by which agent:
#
#     ---
#     title: The headline
#     section: AI
#     summary: One or two sentences on what happened.
#     importance: 7
#     date: 2026-11-25T07:31
#     by: Claude
#     ---
#
#     The article's paragraphs, and then its sources.
#
# Ladder deletes an article when it's older than the settings keep news: a
# week, unless you change it. It deletes nothing else. A file that you put in
# a day's folder stays, and so does the folder while it holds one. To keep an
# article, move it out of its day's folder.
#
#     interests(folder)             # each page that says a kind of news: its section's name, its file and its words
#     editions(folder)              # the articles of each day, the newest day first
#     ask(interest, now; printed, since)   # what the agent is asked for the news of a page
#     reply_articles(reply)         # the articles in what the agent replied
#     write_articles!(folder, section, found, now; by)   # writes each article in the folder of its day
#     prune!(folder)                # deletes the articles that are older than the settings keep
#     keep_days(), keep_days!(n)    # how many days Ladder keeps an article: 0 is for ever
#     agents(), agents!(when)       # when Ladder's own agents get the news: :daily, :asked or :off
#     write_instructions!(folder)   # writes AGENTS.md, which tells another agent what to write
#
# Another agent can write the articles, like one that runs on a server: Ladder
# shows and deletes any article in a day's folder whose front matter has a
# title and a section. With the setting :off, Ladder starts no agent of its own.
#     last_ran(path), ran!(path)    # when an agent last got the news of the page at `path`

@use "github.com/jkroso/Prospects.jl" @def
@use Dates: Dates, Date, DateTime, Day, Hour, Minute

# --- the settings, and when the news of each page was last asked for ---------------------

"The file of the settings of news. A test names a file of its own."
const FILE = Ref("")
file() = isempty(FILE[]) ? joinpath(homedir(), "Library", "Application Support", "Ladder", "news") : FILE[]

"How many days Ladder keeps an article, until you change it"
const KEEP_DAYS = 7

"""
When Ladder's own agents get the news: `:daily`, once a day when the folder
shows, and when you ask; `:asked`, only when you ask; or `:off`, never, as
another agent writes the articles.
"""
const AGENTS = (:daily, :asked, :off)

"The settings of news, and when the news of each page was last asked for, by the page's file"
@def mutable struct Kept
  keep::Int = KEEP_DAYS
  agents::Symbol = :daily
  ran::Dict{String,DateTime} = Dict{String,DateTime}()
end

"What the file of settings held when it was last read or written: when it changed, its path, and what it holds"
const READ = Ref{Tuple{Float64,String,Kept}}((0.0, "", Kept()))

"The settings of news, from their file. The file is read again when it has changed."
kept() = begin
  path = file()
  t = try mtime(path) catch; 0.0 end
  at, from, k = READ[]
  t == at && from == path && return k
  k = Kept()
  t > 0 && for line in (try readlines(path) catch; String[] end)
    parts = split(line, '\t')
    if length(parts) == 3 && parts[1] == "ran"
      when = tryparse(DateTime, parts[3])
      when === nothing || (k.ran[String(parts[2])] = when)
    else
      m = match(r"^(\w+)=(.*)$", line)
      m === nothing && continue
      m[1] == "keep" && (k.keep = max(0, something(tryparse(Int, m[2]), k.keep)))
      m[1] == "agents" && Symbol(m[2]) in AGENTS && (k.agents = Symbol(m[2]))
    end
  end
  READ[] = (t, path, k)
  k
end

"Write the settings `k` to their file. A page that's gone takes its line with it."
keep!(k::Kept) = begin
  path = file()
  filter!(p -> isfile(first(p)), k.ran)
  try
    mkpath(dirname(path))
    write(path, "keep=$(k.keep)\nagents=$(k.agents)\n" * join("ran\t$p\t$(Dates.format(t, "yyyy-mm-ddTHH:MM:SS"))\n" for (p, t) in sort!(collect(k.ran))))
    READ[] = (mtime(path), path, k)
  catch
    # A file that can't be written only means that the settings last until Ladder quits
    READ[] = (READ[][1], path, k)
  end
  k
end

"How many days Ladder keeps an article. 0 is for ever."
keep_days() = kept().keep
keep_days!(n::Integer) = (k = kept(); k.keep = max(0, Int(n)); keep!(k); nothing)

"When Ladder's own agents get the news: :daily, :asked or :off. See `AGENTS`."
agents() = kept().agents
agents!(when::Symbol) = (when in AGENTS || error("Ladder's agents get the news :daily, :asked or :off, not :$when."); k = kept(); k.agents = when; keep!(k); nothing)

"When an agent last got the news of the page at `path`, or nothing when none has"
last_ran(path::AbstractString) = get(kept().ran, String(path), nothing)
ran!(path::AbstractString, at::DateTime=Dates.now()) = (k = kept(); k.ran[String(path)] = at; keep!(k); nothing)

# --- the pages that say what news you want -------------------------------------------------

"The endings of the files that are pages"
const PAGES = (".md", ".markdown")

"A page of a folder of news that says, in your words, a kind of news that you want"
@def struct Interest
  name::String = ""    # the file's name without its ending: the name of the section of the paper that its news goes in
  path::String = ""
  words::String = ""   # what the page says, without its front matter
end

"The names of the pages of a folder of news that aren't kinds of news, in small letters: what the folder is for, and what an agent reads"
const NOT_NEWS = ("readme", "agents", "claude")

"True when the file called `name` can be a page that says a kind of news: a page that isn't hidden, and isn't the folder's Readme or an agent's instructions"
interest_name(name::AbstractString) =
  !startswith(name, '.') && lowercase(splitext(name)[2]) in PAGES && !(lowercase(splitext(name)[1]) in NOT_NEWS)

"The pages of the folder `folder` that each say a kind of news that you want, in the order of their names"
interests(folder::AbstractString) = begin
  names = try readdir(folder) catch; String[] end
  out = Interest[]
  for n in sort!(names, by=lowercase)
    interest_name(n) || continue
    path = joinpath(folder, n)
    isfile(path) || continue
    text = try read(path, String) catch; continue end
    push!(out, Interest(name=String(splitext(n)[1]), path=path, words=String(strip(last(matter(text))))))
  end
  out
end

# --- the articles --------------------------------------------------------------------------

"An article that an agent wrote"
@def struct Article
  path::String = ""
  title::String = ""
  section::String = ""
  summary::String = ""
  importance::Int = 5    # from 1 to 10: how much the story matters to you
  when::DateTime = DateTime(2000)   # when it was written, by the Mac's clock
  by::String = ""        # the agent that wrote it
  text::String = ""      # what's under its front matter
end

"The articles of one day, the most important first"
@def struct Edition
  day::Date = Date(2000)
  path::String = ""
  articles::Vector{Article} = Article[]
end

"`s` without the quotes round it that YAML can have"
unquote(s::AbstractString) = (t = strip(s); length(t) >= 2 && t[1] == t[end] && t[1] in ('"', '\'') ? String(t[2:end-1]) : String(t))

"What the front matter of `text` says, by its keys in small letters, and the text after it. Text with no front matter says nothing."
matter(text::AbstractString) = begin
  lines = split(text, '\n')
  (length(lines) >= 2 && rstrip(lines[1]) == "---") || return (Dict{String,String}(), String(text))
  said = Dict{String,String}()
  for i in 2:length(lines)
    l = rstrip(lines[i])
    l in ("---", "...") && return (said, join(lines[i+1:end], '\n'))
    m = match(r"^(\w[\w .-]*):\s*(.*)$", l)
    m === nothing || (said[lowercase(m[1])] = unquote(m[2]))
  end
  (Dict{String,String}(), String(text))
end

"The day that a folder of a day's articles is named by, like 2026-11-25, or nothing for a folder of another name"
edition_day(name::AbstractString) = occursin(r"^\d{4}-\d{2}-\d{2}$", name) ? tryparse(Date, name) : nothing

"What's known of each article, with when its file had changed as it was read, by its path"
const ARTICLES = Dict{String,Tuple{Float64,Union{Article,Nothing}}}()

"""
The article in the file at `path`, or nothing for a file that isn't one: a
page whose front matter has a title and a section. `day` is the day of its
folder, for an article that doesn't say when it was written.
"""
article(path::AbstractString, day::Date=Date(2000)) = begin
  t = try mtime(path) catch; return nothing end
  kept = get(ARTICLES, path, nothing)
  kept !== nothing && kept[1] == t && return kept[2]
  length(ARTICLES) > 5000 && empty!(ARTICLES)
  a = try
    said, text = matter(read(path, String))
    title, section = get(said, "title", ""), get(said, "section", "")
    isempty(title) || isempty(section) ? nothing :
      Article(path=String(path), title=title, section=section, summary=get(said, "summary", ""),
              importance=clamp(something(tryparse(Int, get(said, "importance", "")), 5), 1, 10),
              when=something(tryparse(DateTime, get(said, "date", "")), DateTime(day) + Hour(12)),
              by=get(said, "by", ""), text=String(strip(text)))
  catch
    nothing
  end
  ARTICLES[path] = (t, a)
  a
end

"The folders of the days of `folder`, each with its day, the newest first"
day_folders(folder::AbstractString) = begin
  names = try readdir(folder) catch; String[] end
  found = Tuple{Date,String}[]
  for n in names
    d = edition_day(n)
    d === nothing || (path = joinpath(folder, n); isdir(path) && push!(found, (d, path)))
  end
  sort!(found, by=first, rev=true)
end

"The articles of the day's folder `path`, the most important first, and then the newest"
day_articles(path::AbstractString, day::Date) = begin
  names = try readdir(path) catch; String[] end
  found = Article[]
  for n in names
    (startswith(n, '.') || !(lowercase(splitext(n)[2]) in PAGES)) && continue
    a = article(joinpath(path, n), day)
    a === nothing || push!(found, a)
  end
  sort!(found, by=a -> (-a.importance, -Dates.value(a.when), a.title))
end

"The articles of each day of `folder`, the newest day first. A day with no articles isn't there."
editions(folder::AbstractString) =
  Edition[Edition(day=d, path=p, articles=as) for (d, p) in day_folders(folder) for as in (day_articles(p, d),) if !isempty(as)]

"The headlines of the section `section` that `folder` has now, for the agent to leave out"
printed(folder::AbstractString, section::AbstractString) =
  unique!(String[a.title for ed in editions(folder) for a in ed.articles if a.section == section])

"""
Delete each article of `folder` that's older than `days` days, and a day's
folder that it leaves empty. With `days` 0, nothing goes. It gives the paths
of what went.
"""
prune!(folder::AbstractString; days::Integer=keep_days(), now::DateTime=Dates.now()) = begin
  gone = String[]
  days > 0 || return gone
  oldest = now - Day(days)
  for (d, dir) in day_folders(folder)
    names = try readdir(dir) catch; continue end
    for n in names
      (startswith(n, '.') || !(lowercase(splitext(n)[2]) in PAGES)) && continue
      path = joinpath(dir, n)
      a = article(path, d)
      (a !== nothing && a.when < oldest) || continue
      try
        rm(path)
        push!(gone, path)
        delete!(ARTICLES, path)
      catch
      end
    end
    # A day's folder goes once it holds nothing more than the Finder's own file, when its day started before the oldest article that stays
    DateTime(d) < oldest || continue
    left = try filter(n -> n != ".DS_Store", readdir(dir)) catch; continue end
    isempty(left) && (try rm(dir, recursive=true); push!(gone, dir) catch end)
  end
  gone
end

# --- what the agent is asked, and what it replies -------------------------------------------

"The line that starts each article in what the agent replies"
const MARK = "=== ARTICLE ==="

"What an agent says of the day `d`, like Wednesday 25 November 2026"
long_day(d) = Dates.format(d, "E d U yyyy")

"""
What the agent is asked for the news of the page `interest`, at the time
`now`. `printed` are the headlines of its section that the paper has now, which
it leaves out. The news is new since `since`. `most` is how many articles it
writes at most.
"""
ask(interest::Interest, now::DateTime; printed=String[], since::DateTime=now - Day(2), most::Integer=5) = """
You're the reporter of a newspaper that has one reader. It's $(long_day(now)), $(Dates.format(now, "HH:MM")) where the reader is.

The reader wants news of this kind. These are their own words:

<<<
$(strip(interest.words))
>>>

Search the web for news of this kind from $(long_day(since)) until now. Choose the stories that the reader would most want to know about: $most at most, and fewer when there's less news. Leave out a story that isn't new since $(long_day(since)).$(isempty(printed) ? "" : " Leave out these stories, which the paper has printed already, unless something new has happened in them:\n\n" * join(("- " * p for p in printed), "\n"))

Write an article about each story, as a good newspaper writes it. Put the most important facts first. Write 3 to 6 short paragraphs in plain words. Say only what your sources say, and name a source in the text where that matters.

Reply with only the articles, one after another, each in this form:

$MARK
headline: the headline, on one line
summary: one or two sentences that say what happened, on one line
importance: a number from 1 to 10 for how much the story matters to the reader
sources: the address of each web page that the article uses, with a space between them

The article's paragraphs, in Markdown, with no headings.

If there's no news of this kind, reply with only the words NO NEWS.
"""

"An article in what the agent replied, before it's written to its file"
@def struct Found
  headline::String = ""
  summary::String = ""
  importance::Int = 5
  sources::Vector{String} = String[]
  text::String = ""
end

"True when the agent's reply says that it found no news"
no_news(reply::AbstractString) = occursin(r"^\W*NO NEWS\W*$"m, reply) && !occursin(MARK, reply)

"""
The articles in `reply`, what the agent replied. Each starts with a line of
`MARK`, then a line for each of its headline, summary, importance and
sources, and then a blank line and its text. A part with no headline isn't an
article. What comes before the first article, like the agent's own words, is
left out.
"""
reply_articles(reply::AbstractString) = begin
  found = Found[]
  parts = split(replace(reply, "\r\n" => "\n"), r"^[ \t]*=+[ \t]*ARTICLE[ \t]*=+[ \t]*$"mi)
  for part in parts[2:end]
    lines = split(strip(part, '\n'), '\n')
    said = Dict{String,String}()
    i = 1
    while i <= length(lines)
      l = strip(lines[i])
      # The agent can make a key bold, as **headline:**
      m = match(r"^[*_]*(headline|summary|importance|sources)[*_]*\s*:[*_]*\s*(.*)$"i, l)
      m === nothing && break
      said[lowercase(m[1])] = String(strip(m[2]))
      i += 1
    end
    head = strip(replace(get(said, "headline", ""), r"\s+" => " "), ['*', '_', ' ', '"'])
    isempty(head) && continue
    rest = lines[i:end]
    # A reply in a code fence ends its last article with the fence
    while !isempty(rest) && (isempty(strip(rest[end])) || startswith(strip(rest[end]), "```"))
      pop!(rest)
    end
    sources = String[s for s in split(get(said, "sources", ""), r"[\s,]+") if occursin(r"^https?://"i, s)]
    push!(found, Found(headline=String(head), summary=String(strip(replace(get(said, "summary", ""), r"\s+" => " "))),
                       importance=clamp(something(tryparse(Int, strip(get(said, "importance", ""), ['*', ' ', '.'])), 5), 1, 10),
                       sources=unique!(sources), text=String(strip(join(rest, '\n')))))
  end
  found
end

"A name for the file of an article with the headline `headline`: its words, with no character that a file's name can't have"
file_name(headline::AbstractString) = begin
  s = replace(headline, r"\s*:\s*" => " - ", r"[/\\]" => "-", r"[\x00-\x1f]" => " ")
  s = strip(replace(s, r"\s+" => " "), [' ', '.', '-'])
  s = length(s) > 80 ? rstrip(first(s, 80)) : s
  isempty(s) ? "Article" : String(s)
end

"The path in `dir` for a file called `base` with the ending `ending`, with a number after the name when that's taken"
free_path(dir, base, ending) = begin
  path = joinpath(dir, base * ending)
  n = 2
  while ispath(path)
    path = joinpath(dir, "$base $n$ending")
    n += 1
  end
  path
end

"The site of the address `url`, like example.com, for the words of its link"
site(url::AbstractString) = (m = match(r"^[a-z]+://(?:www\.)?([^/?#]+)"i, url); m === nothing ? String(url) : String(m[1]))

"The text of the file of the article `f` of the section `section`, written at `at` by `by`"
article_text(f::Found, section, at::DateTime, by) = begin
  oneline(s) = replace(strip(s), r"\s+" => " ")
  head = "---\ntitle: $(oneline(f.headline))\nsection: $(oneline(section))\n" *
         (isempty(f.summary) ? "" : "summary: $(oneline(f.summary))\n") *
         "importance: $(f.importance)\ndate: $(Dates.format(at, "yyyy-mm-ddTHH:MM"))\n" *
         (isempty(by) ? "" : "by: $(oneline(by))\n") * "---\n\n"
  sources = isempty(f.sources) ? "" : "\n\n## Sources\n\n" * join(("- [$(site(u))]($u)" for u in f.sources), "\n")
  head * f.text * sources * "\n"
end

"""
Write each article of `found` for the section `section` in the folder of the
day of `at`, in `folder`, and give their paths. `by` is the agent that wrote them.
"""
write_articles!(folder::AbstractString, section::AbstractString, found, at::DateTime; by::AbstractString="") = begin
  isempty(found) && return String[]
  dir = joinpath(folder, Dates.format(at, "yyyy-mm-dd"))
  mkpath(dir)
  paths = String[]
  for f in found
    path = free_path(dir, file_name(f.headline), ".md")
    write(path, article_text(f, section, at, by))
    push!(paths, path)
  end
  paths
end

"The text of the article `a` as plain words, by its paragraphs, with no Markdown, and with no Sources at its end"
paragraphs(a::Article) = begin
  text = split(a.text, r"\n#+ "; limit=2)[1]
  out = String[]
  for p in split(text, r"\n\s*\n")
    s = strip(replace(p, r"\s*\n\s*" => " "))
    (isempty(s) || startswith(s, '#') || startswith(s, "```")) && continue
    s = replace(s, r"!\[[^\]]*\]\([^)]*\)" => "", r"\[([^\]]*)\]\([^)]*\)" => s"\1", r"(\*\*|__|[*_`])" => "")
    s = strip(replace(s, r"^[-+*>]\s+" => ""))
    isempty(s) || push!(out, String(s))
  end
  out
end

# --- the instructions for an agent of your own ----------------------------------------------

"The file of a folder of news that tells an agent of your own how to write the articles"
const INSTRUCTIONS = "AGENTS.md"

"The first line of the instructions while Ladder keeps them up to date. Once it's gone, Ladder leaves the file as it is."
const KEPT_LINE = "Ladder wrote this file, and keeps it up to date. To change it yourself, delete this line first."

"The name of the Mac's time zone, like Australia/Sydney, or \"\" when it can't say"
time_zone() = begin
  link = try readlink("/etc/localtime") catch; "" end
  m = match(r"zoneinfo/(.+)$", link)
  m === nothing ? "" : String(m[1])
end

"""
What `AGENTS.md` says: how an agent of your own writes the articles of a
folder of news. `days` is how many days Ladder keeps an article, 0 for ever,
`most` the most articles for one page, and `zone` the reader's time zone.
"""
instructions(; days::Integer=keep_days(), most::Integer=5, zone::AbstractString=time_zone()) = """
$KEPT_LINE

# How to write this newspaper

This folder is a newspaper. You find the news and write its articles. Ladder, a Markdown app, shows them to the reader as the front page of a newspaper.

## What the reader wants

Each Markdown page at the top of this folder says one kind of news that the reader wants, in their own words. `AI.md` is an example. The page's name without `.md` is the name of its section in the paper: `AI`. This file, `Readme.md` and `CLAUDE.md` aren't kinds of news.

## Each time you run

1. Read each page at the top of this folder.
2. For each page, search the web for news of that kind since your last run. If you don't know when that was, use the date of the newest article of that section, or else the last 2 days.
3. Read the headlines of that section's articles in the folders of the days. Leave out a story that's there already, unless something new has happened in it.
4. Write an article for each new story that the reader would want to know about: $most at most for each page. If there's no news of a kind, write nothing for it.

## Where an article goes

Put today's articles in a folder named by today's date, as YYYY-MM-DD, like `2026-11-25`. Make the folder if it isn't there. Use the date where the reader is$(isempty(zone) ? "" : ": their time zone is $zone").

Name each file by its headline, with `.md` at the end, like `A rocket lands on its tower.md`. Leave `/` and `:` out of the name.

## What an article holds

```markdown
---
title: A rocket lands on its tower
section: Space
summary: The tower's arms caught the booster as it fell, a first for any rocket.
importance: 7
date: 2026-11-25T07:30
by: Grok
---

The booster fell back to its tower, and the tower's arms caught it.

The company said that it would fly the booster again within a month.

## Sources

- [example.com](https://example.com/rocket)
```

The front matter is between the lines of `---`:

- `title` is the headline, on one line. An article must have it.
- `section` is the name of the page that asked for the news, like `AI` for `AI.md`. An article must have it.
- `summary` is one or two sentences that say what happened, on one line.
- `importance` is a number from 1 to 10 for how much the story matters to the reader. The most important story leads the front page. A story without one has 5.
- `date` is when you wrote the article, as YYYY-MM-DDTHH:MM in the reader's time zone.
- `by` is your name, like `Grok`.

Under the front matter, write 3 to 6 short paragraphs in plain words, with the most important facts first. Say only what your sources say, and name a source in the text where that matters. Put no headings in the story. End with a `## Sources` heading and a link to each web page that you used.

## What Ladder does

Ladder shows each article as soon as you write it. $(days > 0 ? "It deletes each article $(days == 1 ? "a day" : "$days days") after its date" : "It keeps every article"), so don't delete any. Don't change the reader's pages, an article that's there already, or this file.
"""

"""
Write `AGENTS.md` in the folder of news `folder`, when it isn't there, or
when Ladder wrote it and what it says has changed, as when the settings keep
articles for longer. A file whose first line isn't `KEPT_LINE` is yours, and
stays as it is. It's true when it wrote the file.
"""
write_instructions!(folder::AbstractString; most::Integer=5) = begin
  path = joinpath(folder, INSTRUCTIONS)
  text = instructions(; most)
  was = try read(path, String) catch; nothing end
  was == text && return false
  was === nothing || startswith(was, KEPT_LINE) || return false
  try
    write(path, text)
    true
  catch
    false
  end
end
