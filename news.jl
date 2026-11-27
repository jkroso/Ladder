# The facts of a folder of news, apart from the window that shows it. main.jl
# draws the folder as the front page of a newspaper, and starts the agents.
#
# A folder of news has a page called `Interests.md`, which says the kinds of
# news that you want. Each `##` heading in it is a section of the paper, and
# under it you say in your own words what to look for. Once a day an agent
# reads each section, looks on the web for news of that kind, and writes an
# article for each story. What comes before the first `##` heading isn't a
# kind of news: it can say what the page is for.
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
# You mark an article that you liked, or didn't, on its page: Ladder writes
# `liked: yes` or `liked: no` in its front matter. When you open an article
# from the front page, Ladder writes `read:` and the time. It keeps what you
# did with each article in `feedback.csv`, in the folder, after the article
# has gone, so the agents learn what you like. An article of an earlier day
# that you didn't open is there too: it didn't interest you enough. Each article's `by` is its reporter: an agent, or the
# author of a post of a feed (see feeds.jl). Each learns which of its
# articles you liked and read, so they compete as reporters do.
#
# Ladder deletes an article when it's older than the settings keep news: a
# week, unless you change it. It deletes nothing else. A file that you put in
# a day's folder stays, and so does the folder while it holds one. To keep an
# article, move it out of its day's folder.
#
#     interests(folder)             # each section of Interests.md: its name, what Ladder knows it by, and its words
#     editions(folder)              # the articles of each day, the newest day first
#     ask(interest, now; printed, since)   # what the agent is asked for the news of a section
#     reply_articles(reply)         # the articles in what the agent replied
#     write_articles!(folder, section, found, now; by)   # writes each article in the folder of its day
#     prune!(folder)                # deletes the articles that are older than the settings keep
#     keep_days(), keep_days!(n)    # how many days Ladder keeps an article: 0 is for ever
#     agents(), agents!(when)       # when Ladder's own agents get the news: :daily, :asked or :off
#     write_instructions!(folder)   # writes AGENTS.md, which tells another agent what to write
#     marked(text, liked)           # the article's text with your mark: true, false, or nothing for none
#     opened(text, at)              # the article's text with the time that you first read it
#     keep_marks!(folder)           # writes what you did with each of the folder's articles in feedback.csv
#     marks(folder), scores(folder) # each row that feedback.csv keeps, and how each reporter did
#
# Another agent can write the articles, like one that runs on a server: Ladder
# shows and deletes any article in a day's folder whose front matter has a
# title and a section. With the setting :off, Ladder starts no agent of its own.
#     last_ran(key), ran!(key)      # when an agent last got the news of the section that Ladder knows by `key`

@use "github.com/jkroso/Prospects.jl" @def
@use Dates: Dates, Date, DateTime, Day, Hour, Minute
@use "./markdown" front_matter matter_keys
@use "./csv" cells records

# --- the settings, and when the news of each section was last asked for ------------------

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

"The settings of news, and when the news of each section was last asked for, by its key: see `interest_key`"
@def mutable struct Kept
  keep::Int = KEEP_DAYS
  agents::Symbol = :daily
  ran::Dict{String,DateTime} = Dict{String,DateTime}()
  seen::Dict{String,DateTime} = Dict{String,DateTime}()   # the posts of feeds that are in the paper, by their ids, and when Ladder wrote each
  companion::Bool = true   # Ladder starts a reading companion when you open a folder of news: see main.jl
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
    if length(parts) == 3 && parts[1] in ("ran", "seen")
      when = tryparse(DateTime, parts[3])
      when === nothing || ((parts[1] == "ran" ? k.ran : k.seen)[String(parts[2])] = when)
    else
      m = match(r"^(\w+)=(.*)$", line)
      m === nothing && continue
      m[1] == "keep" && (k.keep = max(0, something(tryparse(Int, m[2]), k.keep)))
      m[1] == "agents" && Symbol(m[2]) in AGENTS && (k.agents = Symbol(m[2]))
      m[1] == "companion" && (k.companion = m[2] != "off")
    end
  end
  READ[] = (t, path, k)
  k
end

"How many days Ladder remembers that a post of a feed is in the paper"
const SEEN_DAYS = 90

"Write the settings `k` to their file. A section whose page is gone takes its line with it, and so does a post seen more than `SEEN_DAYS` ago."
keep!(k::Kept) = begin
  path = file()
  filter!(p -> isfile(replace(first(p), r"#[^/]*\z" => "")), k.ran)
  oldest = Dates.now() - Day(SEEN_DAYS)
  filter!(p -> last(p) > oldest, k.seen)
  stamp(t) = Dates.format(t, "yyyy-mm-ddTHH:MM:SS")
  try
    mkpath(dirname(path))
    write(path, "keep=$(k.keep)\nagents=$(k.agents)\ncompanion=$(k.companion ? "on" : "off")\n" * join("ran\t$p\t$(stamp(t))\n" for (p, t) in sort!(collect(k.ran))) *
                join("seen\t$(replace(id, r"\s" => " "))\t$(stamp(t))\n" for (id, t) in sort!(collect(k.seen))))
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

"True when Ladder starts an agent to talk with about the news, when you open a folder of news"
companion() = kept().companion
companion!(on::Bool) = (k = kept(); k.companion = on; keep!(k); nothing)

"When an agent last got the news of the section that Ladder knows by `key`, or nothing when none has"
last_ran(key::AbstractString) = get(kept().ran, String(key), nothing)
ran!(key::AbstractString, at::DateTime=Dates.now()) = (k = kept(); k.ran[String(key)] = at; keep!(k); nothing)

"True when Ladder has put the post of a feed with the id `id` in the paper"
seen(id::AbstractString) = haskey(kept().seen, replace(id, r"\s" => " "))
"Remember that the posts with the ids `ids` are in the paper"
saw!(ids, at::DateTime=Dates.now()) = (isempty(ids) && return nothing; k = kept(); foreach(id -> k.seen[replace(id, r"\s" => " ")] = at, ids); keep!(k); nothing)

# --- the pages that say what news you want -------------------------------------------------

"The endings of the files that are pages"
const PAGES = (".md", ".markdown")

"The page of a folder of news that says the kinds of news that you want"
const INTERESTS = "Interests.md"

"What `Interests.md` says when Ladder makes it"
const INTERESTS_PAGE = """
# Interests

Each `##` heading on this page is a section of the paper. Under it, say in your own words what news you want in that section, and what to leave out. The heading is the section's name. Ladder's agent reads each section and writes its articles.

For example:

```markdown
## AI

New AI models and what they can do. Leave out funding rounds.
```
"""

"A section of `Interests.md`: a kind of news that you want, in your words"
@def struct Interest
  name::String = ""    # the heading: the name of the section of the paper that its news goes in
  key::String = ""     # what Ladder knows it by: see `interest_key`
  words::String = ""   # what the page says under the heading
end

"What Ladder knows the section `name` of the folder of news `folder` by, like `.../News/Interests.md#AI`"
interest_key(folder::AbstractString, name::AbstractString) = joinpath(folder, INTERESTS) * "#" * name

"""
The sections of `Interests.md` in the folder `folder`, in the page's order.
Each `##` heading starts one, and a `#` heading ends it. A heading in a block
of code isn't one. A section whose heading is there twice has the words of
both.
"""
interests(folder::AbstractString) = begin
  text = try read(joinpath(folder, INTERESTS), String) catch; return Interest[] end
  names, words = String[], Vector{String}[]
  inside, fenced = 0, false
  for line in eachsplit(last(matter(text)), '\n')
    heading = fenced ? nothing : match(r"^ {0,3}(#{1,2})[ \t]+(.+?)[ \t#]*$", line)
    if heading === nothing
      occursin(r"^ {0,3}(```|~~~)", line) && (fenced = !fenced)
      inside > 0 && push!(words[inside], String(line))
    elseif heading[1] == "##"
      name = String(strip(heading[2]))
      inside = something(findfirst(==(name), names), 0)
      inside == 0 && (push!(names, name); push!(words, String[]); inside = length(names))
    else
      inside = 0
    end
  end
  [Interest(name=n, key=interest_key(folder, n), words=String(strip(join(ws, '\n')))) for (n, ws) in zip(names, words)]
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
  by::String = ""        # its reporter: the agent that wrote it, or the author of the post of a feed
  text::String = ""      # what's under its front matter
  liked::Union{Bool,Nothing} = nothing   # what you thought of it: true, false, or nothing when you didn't say
  link::String = ""      # the post of a feed that it is, on the web
  read::Union{DateTime,Nothing} = nothing   # when you first opened it from the front page, or nothing
end

"What the word `s` of `liked:` means: true for yes, false for no, or nothing"
liked_word(s::AbstractString) = (w = lowercase(strip(s)); w in ("yes", "true", "liked") ? true : w in ("no", "false", "disliked") ? false : nothing)

"The articles of one day, the most important first"
@def struct Edition
  day::Date = Date(2000)
  path::String = ""
  articles::Vector{Article} = Article[]
end

"What the front matter of `text` says, by its keys in small letters, and the text after it. Text with no front matter says nothing."
matter(text::AbstractString) = begin
  lines = split(text, '\n')
  stop = front_matter(lines)
  stop == 0 ? (Dict{String,String}(), String(text)) : (matter_keys(lines), join(lines[stop+1:end], '\n'))
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
              by=get(said, "by", ""), text=String(strip(text)), liked=liked_word(get(said, "liked", "")), link=get(said, "link", ""),
              read=tryparse(DateTime, get(said, "read", "")))
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
folder that it leaves empty. A talk about the news in a day's folder, a `.chat`
or a `.vt` file, goes once all that day's articles have gone: when the whole day is older.
With `days` 0, nothing goes. It gives the paths of what went.
"""
prune!(folder::AbstractString; days::Integer=keep_days(), now::DateTime=Dates.now()) = begin
  gone = String[]
  days > 0 || return gone
  oldest = now - Day(days)
  for (d, dir) in day_folders(folder)
    names = try readdir(dir) catch; continue end
    for n in names
      path = joinpath(dir, n)
      if !startswith(n, '.') && lowercase(splitext(n)[2]) in (".chat", ".vt") && DateTime(d) + Day(1) < oldest
        try rm(path); push!(gone, path) catch end
        continue
      end
      (startswith(n, '.') || !(lowercase(splitext(n)[2]) in PAGES)) && continue
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

# --- what you thought of each article ------------------------------------------------------

"""
The text `text` with the key `key` of its front matter set to `value`, at the
end of the front matter, or taken out for nothing. Text with no front matter
stays as it is.
"""
with_key(text::AbstractString, key::AbstractString, value::Union{AbstractString,Nothing}) = begin
  lines = split(text, '\n')
  stop = front_matter(lines)
  (stop > 0 && rstrip(lines[1]) == "---") || return String(text)
  keys = [l for l in lines[2:stop-1] if !occursin(Regex("^" * key * "\\s*:", "i"), l)]
  value === nothing || push!(keys, "$key: $value")
  join([lines[1]; keys; lines[stop:end]], '\n')
end

"The text of an article, `text`, with your mark: `liked: yes` for true, `liked: no` for false, and no mark for nothing"
marked(text::AbstractString, liked::Union{Bool,Nothing}) = with_key(text, "liked", liked === nothing ? nothing : liked ? "yes" : "no")

"The text of an article, `text`, that you opened at `at`: it says `read:` and the time, unless it says that already"
opened(text::AbstractString, at::DateTime=Dates.now()) =
  haskey(first(matter(text)), "read") ? String(text) : with_key(text, "read", Dates.format(at, "yyyy-mm-ddTHH:MM"))

"The file of a folder of news that keeps each mark that you gave an article, after the article has gone"
const FEEDBACK = "feedback.csv"
"The most marks that it keeps: the newest"
const MOST_MARKS = 1000

"What you did with an article, as `feedback.csv` keeps it"
@def struct Mark
  day::Date = Date(2000)     # the day of the article
  by::String = ""            # its reporter
  section::String = ""
  liked::Union{Bool,Nothing} = nothing   # your mark: true, false, or nothing for none
  read::Bool = false         # you opened it from the front page
  title::String = ""
  summary::String = ""
  file::String = ""          # its file, from the folder of news, like 2026-11-25/A rocket lands.md
end

"The names of the columns of `feedback.csv`"
const MARK_COLUMNS = ["day", "by", "section", "liked", "read", "title", "summary", "file"]

"`s` as a cell of a CSV file: in quotes, with a quote in it written twice, on one line"
csv_cell(s) = "\"" * replace(replace(string(s), r"\s*\n\s*" => " "), "\"" => "\"\"") * "\""

"The text of `feedback.csv` with the marks `ms`"
marks_text(ms) = join(MARK_COLUMNS, ",") * "\n" *
  join(join(csv_cell.([Dates.format(m.day, "yyyy-mm-dd"), m.by, m.section, m.liked === nothing ? "" : m.liked ? "yes" : "no",
                       m.read ? "yes" : "no", m.title, m.summary, m.file]), ",") * "\n" for m in ms)

"Each row that `feedback.csv` of the folder of news `folder` keeps, the newest first"
marks(folder::AbstractString) = begin
  text = try read(joinpath(folder, FEEDBACK), String) catch; return Mark[] end
  rows = [cells(r, ',') for r in records(replace(text, "\r\n" => "\n", '\r' => '\n'))]
  isempty(rows) && return Mark[]
  col = Dict(lowercase(strip(n)) => i for (i, n) in enumerate(rows[1]))
  cell(r, name) = (i = get(col, name, 0); 0 < i <= length(r) ? r[i] : "")
  out = Mark[]
  for r in rows[2:end]
    isempty(cell(r, "file")) && isempty(cell(r, "title")) && continue
    push!(out, Mark(day=something(tryparse(Date, cell(r, "day")), Date(2000)), by=cell(r, "by"), section=cell(r, "section"),
                    liked=liked_word(cell(r, "liked")), read=liked_word(cell(r, "read")) === true,
                    title=cell(r, "title"), summary=cell(r, "summary"), file=cell(r, "file")))
  end
  out
end

"""
Write in `feedback.csv` what you did with each article of the folder of news
`folder`: each that you marked or opened, and each of a day before `today`,
which you had the chance to open. The row of an article that has gone stays.
The row of one that you took your mark off, and didn't open, goes, unless it's
of an earlier day. It's true when the file changed.
"""
keep_marks!(folder::AbstractString; today::Date=Dates.today()) = begin
  there, now = Set{String}(), Mark[]
  for ed in editions(folder), a in ed.articles
    file = relpath(a.path, folder)
    push!(there, file)
    a.liked === nothing && a.read === nothing && ed.day >= today && continue
    push!(now, Mark(day=ed.day, by=a.by, section=a.section, liked=a.liked, read=a.read !== nothing, title=a.title, summary=a.summary, file=file))
  end
  was = marks(folder)
  ms = [now; filter(m -> !(m.file in there), was)]
  sort!(ms, by=m -> (m.day, m.file), rev=true)
  length(ms) > MOST_MARKS && resize!(ms, MOST_MARKS)
  path = joinpath(folder, FEEDBACK)
  isempty(ms) && !isfile(path) && return false
  text = marks_text(ms)
  text == (try read(path, String) catch; "" end) && return false
  try write(path, text); true catch; false end
end

"""
How each reporter did, as (by, liked, not, read, of): how many of their
articles you liked, how many you didn't, how many you opened, and of how many
that `feedback.csv` keeps. The best are first: the most liked, less what you
didn't like, and then the most read.
"""
scores(folder::AbstractString) = begin
  count = Dict{String,Vector{Int}}()
  for m in marks(folder)
    isempty(m.by) && continue
    c = get!(() -> [0, 0, 0, 0], count, m.by)
    m.liked === true && (c[1] += 1)
    m.liked === false && (c[2] += 1)
    m.read && (c[3] += 1)
    c[4] += 1
  end
  sort!([(by, c[1], c[2], c[3], c[4]) for (by, c) in count], by=s -> (s[3] - s[2], -s[4] / max(s[5], 1), s[1]))
end

# --- what the agent is asked, and what it replies -------------------------------------------

"The line that starts each article in what the agent replies"
const MARK = "=== ARTICLE ==="

"""
What every agent is told of a post on x.com: the story shows it as a link card
on a line of its own, where the text tells of it, in place of a link and a
quote. See linkcard.jl.
"""
const X_POSTS = "When a story tells of a post on x.com, show the post itself. Put it on a line of its own, after the paragraph that tells of it, as `![Sam Lee on X](https://x.com/samlee/status/1234567890)` with the post's own address. Ladder shows that line as a card with the post's picture and the first two lines of its words. The reader clicks the card to open the post and its replies. Don't link to the post in the text as well. Quote only the words of a long post that the story needs, and say who wrote it and why it matters."

"What an agent says of the day `d`, like Wednesday 25 November 2026"
long_day(d) = Dates.format(d, "E d U yyyy")

"""
What the agent is told of what the reader did with the articles `ms`: those
that they liked, those that they didn't, those that they opened, and those
that they didn't open, 10 of each at most
"""
liked_words(ms) = begin
  line(m) = "- " * m.title * (isempty(m.summary) ? "" : ": " * m.summary)
  some(f) = [m for m in ms if f(m)][1:min(end, 10)]
  yes, no = some(m -> m.liked === true), some(m -> m.liked === false)
  read, unread = some(m -> m.read && m.liked === nothing), some(m -> !m.read && m.liked === nothing)
  all(isempty, (yes, no, read, unread)) && return ""
  "\nThe reader opens the articles that interest them, and marks those that they liked, and those that they didn't. Other reporters write for this paper too, and the reader's choices say whose articles they like best. Write more of what the reader liked and opened, and less of what they didn't." *
    (isempty(yes) ? "" : "\n\nThey liked these:\n\n" * join(line.(yes), "\n")) *
    (isempty(no) ? "" : "\n\nThey didn't like these:\n\n" * join(line.(no), "\n")) *
    (isempty(read) ? "" : "\n\nThey opened these:\n\n" * join(line.(read), "\n")) *
    (isempty(unread) ? "" : "\n\nThey didn't open these:\n\n" * join(line.(unread), "\n")) * "\n"
end

"""
What the agent is asked for the news of the section `interest`, at the time
`now`. `printed` are the headlines of its section that the paper has now, which
it leaves out. The news is new since `since`. `most` is how many articles it
writes at most. `liked` is what you did with the articles of its section,
from `feedback.csv`, so it writes more of what you liked and read.
"""
ask(interest::Interest, now::DateTime; printed=String[], since::DateTime=now - Day(2), most::Integer=5, liked=Mark[]) = """
You're the reporter of a newspaper that has one reader. It's $(long_day(now)), $(Dates.format(now, "HH:MM")) where the reader is.

The reader wants news of this kind. These are their own words:

<<<
$(strip(interest.words))
>>>

Search the web for news of this kind from $(long_day(since)) until now. Choose the stories that the reader would most want to know about: $most at most, and fewer when there's less news. Leave out a story that isn't new since $(long_day(since)).$(isempty(printed) ? "" : " Leave out these stories, which the paper has printed already, unless something new has happened in them:\n\n" * join(("- " * p for p in printed), "\n"))
$(liked_words(liked))
Write an article about each story, as a good newspaper writes it. Put the most important facts first. Write 3 to 6 short paragraphs in plain words. Say only what your sources say, and name a source in the text where that matters.

$X_POSTS

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
`most` the most articles for one section, and `zone` the reader's time zone.
"""
instructions(; days::Integer=keep_days(), most::Integer=5, zone::AbstractString=time_zone()) = """
$KEPT_LINE

# How to write this newspaper

This folder is a newspaper. You find the news and write its articles. Ladder, a Markdown app, shows them to the reader as the front page of a newspaper.

## What the reader wants

`$INTERESTS` in this folder says the kinds of news that the reader wants, in their own words. Each `##` heading on it is a section of the paper, and the words under the heading say what news goes in that section. The heading is the section's name: `## AI` is the section `AI`. What comes before the first `##` heading isn't a kind of news.

## Each time you run

1. Read `$INTERESTS`.
2. Read `$FEEDBACK`, if it's there. It says which articles the reader opened, which they liked, and which they didn't.
3. For each section, search the web for news of that kind since your last run. If you don't know when that was, use the date of the newest article of that section, or else the last 2 days.
4. Read the headlines of that section's articles in the folders of the days. Leave out a story that's there already, unless something new has happened in it.
5. Write an article for each new story that the reader would want to know about: $most at most for each section. Write more of what the reader opened and liked, and less of what they didn't. If there's no news of a kind, write nothing for it.

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
- `section` is the heading of `$INTERESTS` that asked for the news, like `AI` for `## AI`. An article must have it.
- `summary` is one or two sentences that say what happened, on one line.
- `importance` is a number from 1 to 10 for how much the story matters to the reader. The most important story leads the front page. A story without one has 5.
- `date` is when you wrote the article, as YYYY-MM-DDTHH:MM in the reader's time zone.
- `by` is your name, like `Grok`.

Under the front matter, write 3 to 6 short paragraphs in plain words, with the most important facts first. Say only what your sources say, and name a source in the text where that matters. Put no headings in the story. End with a `## Sources` heading and a link to each web page that you used.

$(X_POSTS) `## Sources` needn't list a post that the story shows.

## What the reader thought

The reader marks an article that they liked with `liked: yes` in its front matter, and one that they didn't like with `liked: no`. When the reader opens an article from the front page, Ladder writes `read:` and the time in it.

Ladder keeps what the reader did with each article in `$FEEDBACK` in this folder, also after the article has gone. It has a row for each article that the reader opened or marked, and for each article of an earlier day. Its columns are the article's day, its reporter (`by`), its section, `liked` (yes, no, or nothing), `read` (yes or no), its title, its summary and its file. An article of an earlier day that the reader didn't open didn't interest them enough.

## Other reporters

Other agents write for this paper too. Ladder also puts the posts of the feeds that `Feeds.md` lists in the paper, each by its author. `$FEEDBACK` says which articles of each reporter the reader liked, and which they opened. Write your own name in `by`, so that the reader's marks count for you.

## What Ladder does

Ladder shows each article as soon as you write it. $(days > 0 ? "It deletes each article $(days == 1 ? "a day" : "$days days") after its date" : "It keeps every article"), so don't delete any. Don't change `$INTERESTS`, an article that's there already, `$FEEDBACK`, `Feeds.md` or this file.
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
