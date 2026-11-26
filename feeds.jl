# The feeds of a folder of news. `Feeds.md` in the folder lists the address of
# each RSS or Atom feed that you want in the paper, under the heading of the
# section that its posts go in:
#
#     # Feeds
#
#     ## AI
#
#     - https://simonwillison.net/atom/everything/
#
# Ladder gets each feed while the front page shows (see "the feeds of a folder
# of news" in main.jl), and writes each new post as an article of the paper, by
# the post's author, as if the author wrote for the paper. A feed with no
# heading over it has a section of its own: the feed's name. An address in
# code, like `https://example.com/feed.xml`, is an example, and no feed.
#
# A line that says `Apple Podcasts` stands for each show that you follow in
# Apple Podcasts (see podcasts.jl): each new episode is an article by its show.
#
# Ladder remembers each post that it wrote (see `News.seen`), so a post that
# you deleted doesn't come back. A post that's older than the paper keeps its
# news isn't written.
#
#     feeds(folder)            # the feeds that Feeds.md lists
#     read_feed(text)          # a feed's name and its posts
#     write_posts!(folder, feed, name, posts; now, days)   # writes each new post as an article
#     html_text(html)          # the words of some HTML, as paragraphs of Markdown
#     PAGE                     # what Feeds.md says when Ladder makes it

@use "github.com/jkroso/Prospects.jl" @def
@use Dates: Dates, Date, DateTime, Day, Hour, Minute
@use "./xml" Element parse_xml
@use "./news" => News
@use "./podcasts" => Podcasts

"The page of a folder of news that lists its feeds"
const FILE = "Feeds.md"

"What a feed's address is for the line `Apple Podcasts`: the shows that you follow there"
const PODCASTS = "apple-podcasts:"

"What `Feeds.md` says when Ladder makes it"
const PAGE = """
# Feeds

Put the address of an RSS or Atom feed on a line of this page. Ladder gets each feed every hour while the paper shows, and when you click the round arrow at the right of the top bar. Each new post shows in the paper as an article by its author.

A feed's posts go in the section of the heading over it. A feed with no heading over it gets a section of its own, with the feed's name. For example:

```markdown
## AI

- https://simonwillison.net/atom/everything/
```

A line that says Apple Podcasts puts in the paper each new episode of the shows that you follow in Apple Podcasts, as an article by its show.

"""

"A feed that `Feeds.md` lists, and the section that its posts go in"
@def struct Feed
  url::String = ""
  section::String = ""   # the heading over it, or "" for the feed's own name
end

"The feeds that `Feeds.md` of the folder of news `folder` lists, in its order"
feeds(folder::AbstractString) = begin
  text = try read(joinpath(folder, FILE), String) catch; return Feed[] end
  out, section, fenced = Feed[], "", false
  for line in split(last(News.matter(text)), '\n')
    l = strip(line)
    startswith(l, "```") && (fenced = !fenced; continue)
    fenced && continue
    m = match(r"^(#{1,6})\s+(.+?)\s*#*$", l)
    if m !== nothing
      # The heading at the top names the page, and isn't a section
      section = length(m[1]) == 1 ? "" : String(m[2])
      continue
    end
    # The shows that you follow in Apple Podcasts
    if occursin(r"^(?:[-*+]\s+)?apple podcasts\.?$"i, l)
      any(f -> f.url == PODCASTS, out) || push!(out, Feed(url=PODCASTS, section=section))
      continue
    end
    for u in eachmatch(r"https?://[^\s<>()\[\]\"'`]+", replace(l, r"`[^`]*`" => ""))
      url = String(rstrip(u.match, ['.', ',', ';', ':']))
      any(f -> f.url == url, out) || push!(out, Feed(url=url, section=section))
    end
  end
  out
end

# --- reading a feed --------------------------------------------------------------------------

"A post of a feed"
@def struct Post
  id::String = ""        # what the feed calls it, or its address
  title::String = ""
  link::String = ""      # the post on the web
  author::String = ""
  when::Union{DateTime,Nothing} = nothing   # when it was posted, by the Mac's clock
  summary::String = ""
  text::String = ""      # its words, as Markdown
end

"The elements in `e` that are called one of `names`, in small letters"
children(e::Element, names...) = Element[c for c in e.children if c isa Element && lowercase(c.name) in names]
"The first element in `e` called one of `names`, in the order of `names`, or nothing"
child(e::Element, names...) = (for n in names, c in e.children; c isa Element && lowercase(c.name) == n && return c end; nothing)
"All the words in `e`, and in the elements in it"
words(e) = e === nothing ? "" : String(strip(join(c isa String ? c : words(c) for c in e.children)))

"Each element called one of `names` in `e`, or in elements in it, but not in one another"
found(e::Element, names...) = begin
  out = Element[]
  for c in e.children
    c isa Element || continue
    lowercase(c.name) in names ? push!(out, c) : append!(out, found(c, names...))
  end
  out
end

"""
The name of the feed in the XML text `text`, and its posts, the newest first.
It reads RSS 2.0, RSS 1.0 and Atom. A post's author is the feed's when it
names none, and the feed's name when the feed names none either.
"""
read_feed(text::AbstractString) = begin
  root = parse_xml(text)
  top = something(child(root, "rss", "rdf:rdf", "feed"), root)
  channel = something(child(top, "channel"), top)
  name = plain(words(child(channel, "title")))
  everyone = names_of(something(child(channel, "author", "managingeditor", "dc:creator", "itunes:author"), Element("", Dict{String,String}(), [])))
  posts = Post[]
  for item in found(top, "item", "entry")
    p = post(item, isempty(everyone) ? name : everyone)
    p === nothing || push!(posts, p)
  end
  sort!(posts, by=p -> something(p.when, DateTime(2000)), rev=true)
  (name, posts)
end

"The name in an author element: Atom's name in it, or RSS's words, as `sam@example.com (Sam)` gives Sam"
names_of(e::Element) = begin
  n = child(e, "name")
  n === nothing || return plain(words(n))
  s = plain(words(e))
  m = match(r"\(([^)]+)\)", s)
  m !== nothing ? String(strip(m[1])) : occursin('@', s) ? "" : s
end

"The address of an Atom entry or an RSS item: its link to itself on the web"
link_of(item::Element) = begin
  for l in children(item, "link")
    href = get(l.attrs, "href", "")
    isempty(href) && (href = words(l))
    rel = get(l.attrs, "rel", "alternate")
    !isempty(href) && rel == "alternate" && return String(strip(href))
  end
  g = child(item, "guid")
  g !== nothing && get(g.attrs, "ispermalink", get(g.attrs, "isPermaLink", "true")) != "false" && startswith(words(g), "http") ? words(g) : ""
end

"The post that the item or entry `item` is, or nothing when it has no words. `author` is who wrote it when it doesn't say."
post(item::Element, author::AbstractString) = begin
  link = link_of(item)
  body = words(child(item, "content:encoded", "content"))
  about = words(child(item, "description", "summary"))
  if isempty(body)
    body, about = about, ""
  end
  text = html_text(body)
  summary = summary_of(isempty(about) ? text : html_text(about))
  title = plain(html_text(words(child(item, "title"))))
  # A post with no title, as a short post has, is called by its first words
  isempty(title) && (title = shorter(summary, 90))
  isempty(title) && return nothing
  who = child(item, "author", "dc:creator")
  by = who === nothing ? "" : names_of(who)
  id = words(child(item, "guid", "id"))
  Post(id=isempty(id) ? (isempty(link) ? title : link) : id, title=title, link=link, author=isempty(by) ? String(author) : by,
       when=when_of(words(child(item, "pubdate", "published", "dc:date", "updated"))), summary=summary, text=text)
end

"`s` cut to `n` characters at most, at the end of a word, with … when it's cut"
shorter(s::AbstractString, n::Integer) = begin
  length(s) <= n && return String(s)
  cut = first(s, n - 1)
  k = findlast(' ', cut)
  (k === nothing ? cut : cut[1:prevind(cut, k)]) * "…"
end

"The first sentences of the words `s`, as many as fit in 280 characters, on one line"
summary_of(s::AbstractString) = begin
  s = plain(s)
  length(s) <= 280 && return s
  stop = 0
  for m in eachmatch(r"[.!?](?=\s|$)", s)
    length(s[1:m.offset]) > 280 && break
    stop = m.offset
  end
  stop > 40 ? s[1:stop] : shorter(s, 280)
end

# --- when a post was posted --------------------------------------------------------------------

const MONTHS = ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
"The time zones that a date of RSS can name, as minutes from UTC"
const ZONES = Dict("gmt" => 0, "ut" => 0, "utc" => 0, "z" => 0, "est" => -300, "edt" => -240, "cst" => -360, "cdt" => -300,
                   "mst" => -420, "mdt" => -360, "pst" => -480, "pdt" => -420)

"How many minutes from UTC the zone `z` is: +1100, +11:00, Z or GMT"
zone_minutes(z) = begin
  z === nothing && return nothing
  m = match(r"^([+-])(\d{2}):?(\d{2})$", z)
  m === nothing && return get(ZONES, lowercase(z), 0)
  (m[1] == "-" ? -1 : 1) * (60parse(Int, m[2]) + parse(Int, m[3]))
end

"How far the Mac's clock is from UTC"
local_offset() = Minute(round(Int, Dates.value(Dates.now() - Dates.now(Dates.UTC)) / 60_000))

"""
When the date `s` of a feed is, by the Mac's clock: one of RSS, like `Wed, 25
Nov 2026 07:30:00 +0000`, or of Atom, like `2026-11-25T07:30:00Z`. A date that
names no time zone is by the Mac's clock. It's nothing for words that aren't a date.
"""
when_of(s::AbstractString) = begin
  s = strip(s)
  t, zone = nothing, nothing
  m = match(r"^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?\s*(Z|[+-]\d{2}:?\d{2})?)?", s)
  if m !== nothing
    n(i) = m[i] === nothing ? 0 : parse(Int, m[i])
    t = try DateTime(n(1), n(2), n(3), n(4), n(5), n(6)) catch; nothing end
    zone = m[7]
  else
    m = match(r"(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{2}:?\d{2}|[A-Za-z]{1,4})?", s)
    m === nothing && return nothing
    month = findfirst(==(lowercase(m[2])), MONTHS)
    month === nothing && return nothing
    year = parse(Int, m[3])
    t = try DateTime(year < 100 ? 2000 + year : year, month, parse(Int, m[1]), parse(Int, m[4]), parse(Int, m[5]), m[6] === nothing ? 0 : parse(Int, m[6])) catch; nothing end
    zone = m[7]
  end
  t === nothing && return nothing
  mins = zone_minutes(zone)
  mins === nothing ? t : t - Minute(mins) + local_offset()
end

# --- the words of HTML ---------------------------------------------------------------------------

"The names of the characters that HTML writes as &name;, which a post is most likely to have"
const HTML_NAMED = Dict("amp" => "&", "lt" => "<", "gt" => ">", "quot" => "\"", "apos" => "'", "nbsp" => " ",
  "rsquo" => "’", "lsquo" => "‘", "rdquo" => "”", "ldquo" => "“", "mdash" => "—", "ndash" => "–", "hellip" => "…",
  "copy" => "©", "reg" => "®", "trade" => "™", "times" => "×", "middot" => "·", "bull" => "•", "laquo" => "«",
  "raquo" => "»", "deg" => "°", "euro" => "€", "pound" => "£", "eacute" => "é", "egrave" => "è", "aacute" => "á",
  "uuml" => "ü", "ouml" => "ö", "auml" => "ä", "szlig" => "ß", "ccedil" => "ç", "minus" => "−", "thinsp" => " ",
  "ensp" => " ", "emsp" => " ", "zwj" => "", "zwnj" => "", "shy" => "")

"`s` with each &name;, &#38; and &#x26; as the character that it names"
unentity(s::AbstractString) = replace(s, r"&(?:#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);" => function (m)
  name = m[2:end-1]
  try
    startswith(name, "#x") || startswith(name, "#X") ? string(Char(parse(UInt32, name[3:end], base=16))) :
    startswith(name, "#") ? string(Char(parse(UInt32, name[2:end]))) : get(HTML_NAMED, name, m)
  catch
    m
  end
end)

"""
The words of the HTML `html` as paragraphs of Markdown: a link keeps its
address, an item of a list starts with -, and the rest of the tags go.
"""
html_text(html::AbstractString) = begin
  s = replace(html, r"<(script|style)\b.*?</\1\s*>"is => "", r"<!--.*?-->"s => "")
  s = replace(s, r"<a\b[^>]*?\bhref\s*=\s*([\"'])(.*?)\1[^>]*>(.*?)</a\s*>"is => s"[\3](\2)")
  s = replace(s, r"<br\s*/?>"i => "\n", r"<li\b[^>]*>"i => "\n\n- ")
  s = replace(s, r"</?(?:p|div|ul|ol|li|blockquote|h[1-6]|pre|figure|figcaption|table|tr|section|article|header|footer|hr)\b[^>]*>"i => "\n\n")
  s = replace(s, r"<[^>]*>"s => "")
  s = replace(unentity(s), '\u00a0' => ' ')
  # A link to a place in the post, or with no words, keeps only its words
  s = replace(s, r"\[\s*\]\([^)]*\)" => "", r"\[([^\]]*)\]\((?!https?://)[^)]*\)" => s"\1")
  # The spaces at the ends of a link's words go outside it: [ Erebor](…) is  [Erebor](…)
  s = replace(s, r"\[(\s*)([^\]]*?)(\s*)\]\(([^)]*)\)" => s"\1[\2](\4)\3")
  paras = [strip(replace(p, r"\s+" => " ")) for p in split(s, r"\n[ \t\r\f\v]*\n")]
  join(filter(p -> !isempty(p) && p != "-", paras), "\n\n")
end

"The words of HTML or Markdown on one line, with no tags or links"
plain(s::AbstractString) = String(strip(replace(replace(unentity(replace(s, r"<[^>]*>" => "")), r"\[([^\]]*)\]\([^)]*\)" => s"\1"), r"\s+" => " ")))

# --- writing the posts ---------------------------------------------------------------------------

"The text of the article that the post `p` of the feed `f` is"
post_text(p::Post, f::Feed, section, by, when::DateTime) = begin
  oneline(s) = replace(strip(s), r"\s+" => " ")
  "---\ntitle: $(oneline(p.title))\nsection: $(oneline(section))\n" *
    (isempty(p.summary) ? "" : "summary: $(oneline(p.summary))\n") *
    "importance: 5\ndate: $(Dates.format(when, "yyyy-mm-ddTHH:MM"))\n" *
    (isempty(by) ? "" : "by: $(oneline(by))\n") *
    (isempty(p.link) ? "" : "link: $(p.link)\n") * "feed: $(f.url)\n---\n\n" *
    (isempty(p.text) ? p.summary : p.text) *
    (isempty(p.link) ? "" : f.url == PODCASTS ? "\n\n## Listen\n\n- [Apple Podcasts]($(p.link))" : "\n\n## Source\n\n- [$(News.site(p.link))]($(p.link))") * "\n"
end

"""
The episodes `es` of the shows that you follow in Apple Podcasts, as posts of
the feed of the line `Apple Podcasts`. Each is by its show.
"""
episode_posts(es) = Post[Post(id="podcast:" * e.id, title=e.title, link=e.link, author=e.show, when=e.when,
                              summary=summary_of(html_text(e.notes)), text=html_text(e.notes)) for e in es]

"""
Write each new episode of the shows that you follow in Apple Podcasts as an
article of the folder of news `folder`, as `write_posts!` writes the posts of
the feed `f`, and give their paths. Its section is Podcasts when no heading
is over its line.
"""
write_episodes!(folder::AbstractString, f::Feed; now::DateTime=Dates.now(), days::Integer=News.keep_days()) =
  write_posts!(folder, f, "Podcasts", episode_posts(Podcasts.episodes(now - Day(days > 0 ? days : 7))); now, days, most=30)

"""
Write each new post of `posts`, of the feed `f` called `name`, as an article
of the folder of news `folder`, in the folder of the day that it was posted.
A post that Ladder wrote before, or that's older than `days` days, isn't
written: 7 days when the paper keeps its news for ever. It writes `most` posts
at most, the newest, and gives their paths.
"""
write_posts!(folder::AbstractString, f::Feed, name::AbstractString, posts; now::DateTime=Dates.now(),
             days::Integer=News.keep_days(), most::Integer=10) = begin
  oldest = now - Day(days > 0 ? days : 7)
  section = isempty(f.section) ? (isempty(name) ? News.site(f.url) : name) : f.section
  written, ids = String[], String[]
  for p in posts
    News.seen(p.id) && continue
    push!(ids, p.id)
    when = min(something(p.when, now), now)
    (when < oldest || length(written) >= most) && continue
    dir = joinpath(folder, Dates.format(when, "yyyy-mm-dd"))
    mkpath(dir)
    path = News.free_path(dir, News.file_name(p.title), ".md")
    write(path, post_text(p, f, section, isempty(p.author) ? name : p.author, when))
    push!(written, path)
  end
  # A post that's too old, or one past the most, is seen too, so it doesn't come later
  News.saw!(ids, now)
  written
end
