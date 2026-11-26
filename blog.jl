# A blog is a folder of pages that puts itself on the web. Each Markdown file
# in the folder, and in the folders inside it, is a post. main.jl shows the
# folder's own page, with a list of the posts and a Publish button, and makes
# each post a page of HTML. This file knows what a post is and where the site
# goes. It draws nothing.
#
#     posts("/Users/sam/blog")              # [Post("…/2026-11-20-hello.md", "2026-11-20-hello", "", "Hello", Date(2026, 11, 20), false), …]
#     standing("/Users/sam/blog", post)     # :new, :changed, :published, :draft or :unknown
#     address("git@github.com:sam/blog.git")   # "https://sam.github.io/blog/"
#
# A post says things about itself in its front matter, between lines of `---`
# as YAML writes it, or between lines of `+++` as TOML writes it:
#
#     ---                         +++
#     title: Hello                title = "Hello"
#     date: 2026-11-20            date = 2026-11-20
#     draft: true                 complete = false
#     ---                         +++
#
# Without a title, a post has the words of its first heading, or else its
# file's name. Without a date, it has the day that its file's name starts
# with, like `2026-11-20-hello.md`, or else the day that the file was made. A
# post that says `draft: true`, or `complete = false`, is a draft.
#
# A folder inside the blog's folder is a section of the blog, and its posts
# are that section's. The page `Readme.md` of a folder, in any case, is no
# post: it says what the folder is. The page `index.md` of the blog's own
# folder is no post either. The text of that page, or else of the blog's
# `Readme.md`, goes over the list of the posts on the site's first page. That
# page can say where the site is, as `site: https://sam.example.com` in its
# front matter. A section's own `index.md` is a post, and it's the section's
# page on the site: the site shows it alone, with no list. A file or a folder whose name starts with a dot or an
# underscore is left out.
#
# Ladder writes the site into the folder `docs` in the blog's folder: a page
# for each post, with the same name and `.html`, in a folder of the section's
# name, a first page called `index.html`, and a copy of each picture that a
# post shows. GitHub Pages serves that folder when the repository's settings
# say so.
#
# A blog can make its site and send it itself, with a script of its own at
# `.bin/publish`. Then Ladder runs that script to publish it, and writes no
# `docs`. Such a blog's posts are also its book reviews, the files that end
# in `.review`, and the pages that Julia code makes, the files that end in
# `.dom.jl`, since its own script makes pages of them too. The folder `docs`
# of such a blog is a section like any other.

@use Dates: Dates, Date
@use "./macfile" made

"The folder in a blog's folder that Ladder writes the site into"
const SITE = "docs"
"The page of a blog whose text goes over the list of the posts"
const INDEX = "index.md"
"The script in a blog's folder that makes the blog's site and sends it, for a blog that does that itself"
const SCRIPT = joinpath(".bin", "publish")
"The endings of the files that are the posts of any blog"
const MARKDOWN = (".md", ".markdown")
"The endings of the other files that are posts of a blog that publishes itself: a book review, and the code of a page"
const OTHERS = (".review", ".dom.jl")

struct Post
  path::String     # its file
  name::String     # the file's name without its ending. The page of the site has this name, and .html.
  section::String  # the folder that it's in, from the blog's folder, like "Humans/Relationships", or "" for a post at the top
  title::String
  day::Date
  draft::Bool
end

"A post at the top of its blog's folder"
Post(path, name, title, day::Date, draft::Bool) = Post(path, name, "", title, day, draft)

const DAY = r"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"

"The first day that's written in `text` like 2026-11-25, or nothing"
day(text::AbstractString) = begin
  for m in eachmatch(DAY, text)
    y, mo, d = parse.(Int, m.captures)
    Dates.validargs(Date, y, mo, d) === nothing && return Date(y, mo, d)
  end
  nothing
end

"""
What the front matter at the top of `lines` sets each of its keys to, by the
key in lower case. Front matter is between lines of `---`, with a colon after
each key, or between lines of `+++`, with `=` after each key. Lines with no
front matter have none.
"""
matter(lines) = begin
  out = Dict{String,String}()
  isempty(lines) && return out
  fence = rstrip(lines[1])
  fence in ("---", "+++") || return out
  pattern = fence == "---" ? r"^([^:#\s-][^:#]*):\s*(.*?)\s*$" : r"^([A-Za-z0-9_-]+)\s*=\s*(.*?)\s*$"
  for line in @view lines[2:end]
    rstrip(line) == fence && break
    m = match(pattern, line)
    m === nothing || (out[lowercase(strip(m[1]))] = String(strip(m[2], ['"', '\''])))
  end
  out
end

"`lines` after their front matter, if they have some"
body(lines) = begin
  (!isempty(lines) && rstrip(lines[1]) in ("---", "+++")) || return lines
  k = findnext(l -> rstrip(l) == rstrip(lines[1]), lines, 2)
  k === nothing ? lines : lines[k+1:end]
end

"The ending of the file called `name` that makes it a post, or nothing. With `others`, a book review and the code of a page are posts too."
ending(name::AbstractString, others::Bool=false) = begin
  low = lowercase(name)
  for e in (others ? (MARKDOWN..., OTHERS...) : MARKDOWN)
    endswith(low, e) && length(low) > length(e) && return e
  end
  nothing
end

"True for the page that says what its folder is"
isreadme(name::AbstractString) = occursin(r"^readme\.(md|markdown)$"i, name)

"True for a folder's own page, `index.md` in any case, which the site shows at the folder's address"
isindex(name::AbstractString) = occursin(r"^index\.(md|markdown)$"i, name)

"The post in the file at `path`, whose lines are `lines`. `section` is the folder that it's in, from the blog's folder."
post(path::AbstractString, lines=readlines(path); section::AbstractString="") = begin
  said = matter(lines)
  file = basename(path)
  e = something(ending(file, true), splitext(file)[2])
  name = file[1:end-length(e)]
  title = get(said, "title", "")
  if isempty(title)
    # The code of a page has no Markdown heading, and a line that starts with # is a comment there. Its heading is in an :h1.
    m = e == ".dom.jl" ? match(r"\[:h1\s+\"([^\"\\]+)\"", join(lines, '\n')) : nothing
    k = e == ".dom.jl" ? nothing : findfirst(l -> startswith(l, "# "), lines)
    title = m !== nothing ? String(m[1]) : k === nothing ? name : String(strip(lines[k][3:end]))
  end
  d = something(day(get(said, "date", "")), startswith(name, r"\d{4}-\d") ? day(name) : nothing, Date(Libc.strftime("%Y-%m-%d", made(path))))
  draft = lowercase(get(said, "draft", "")) in ("true", "yes") || lowercase(get(said, "complete", "")) in ("false", "no")
  Post(String(path), name, String(section), title, d, draft)
end

"The post that each file was last read as, and when the file had changed then, by its path. A file that hasn't changed isn't read again."
const READ = Dict{String,Tuple{Float64,Post}}()

"""
The posts of the blog in `folder`, the newest first: each Markdown file in
the folder and in the folders inside it. With `itself`, for a blog that
publishes itself, its book reviews and the code of its pages are posts too,
and its folder `docs` is a section like any other.
"""
posts(folder::AbstractString; itself::Bool=false) = begin
  out = Post[]
  gather!(out, folder, "", itself)
  sort!(out, by=p -> (p.day, p.name), rev=true)
end

"Put the posts of the section `section` of the blog in `folder` into `out`, and the posts of the sections inside it"
gather!(out, folder, section, itself) = begin
  at = isempty(section) ? folder : joinpath(folder, section)
  names = try readdir(at) catch; return out end   # a folder that macOS doesn't let Ladder read has no posts
  for name in names
    (startswith(name, '.') || startswith(name, '_')) && continue
    path = joinpath(at, name)
    if isdir(path)
      # A link to a folder could lead back to the blog, and Ladder writes the site in docs
      islink(path) || (!itself && isempty(section) && name == SITE) ||
        gather!(out, folder, isempty(section) ? name : section * "/" * name, itself)
      continue
    end
    e = ending(name, itself)
    (e === nothing || isreadme(name) || (isempty(section) && lowercase(name) == INDEX)) && continue
    changed = try mtime(path) catch; continue end
    kept = get(READ, path, nothing)
    if kept !== nothing && kept[1] == changed && kept[2].section == section
      push!(out, kept[2])
      continue
    end
    p = try post(path; section) catch; nothing end   # a file that can't be read is no post
    p === nothing && continue
    READ[path] = (changed, p)
    push!(out, p)
  end
  out
end

"The sections of the posts `list`, by their names: the top of the blog, \"\", comes first"
sections(list) = sort!(unique(p.section for p in list))

"The page of the blog in `folder` whose text goes over the list of its posts: its `index.md`, or else its `Readme.md`. It's \"\" when it has neither."
front(folder::AbstractString) = begin
  isfile(joinpath(folder, INDEX)) && return joinpath(folder, INDEX)
  names = try readdir(folder) catch; String[] end
  k = findfirst(isreadme, names)
  k === nothing ? "" : joinpath(folder, names[k])
end

"The address that the front page of the blog in `folder` gives its site, or \"\""
said_address(folder::AbstractString) = begin
  top = front(folder)
  isempty(top) && return ""
  said = try open(io -> matter(collect(Iterators.take(eachline(io), 40))), top) catch; Dict{String,String}() end
  get(said, "site", "")
end

"True when the blog in `folder` makes its site and sends it itself, with a script of its own"
itself(folder::AbstractString) = isfile(joinpath(folder, SCRIPT))

"The folder that Ladder writes the site of the blog in `folder` into"
site(folder::AbstractString) = joinpath(folder, SITE)

"The page of the site that the post `p` of the blog in `folder` has"
page(folder::AbstractString, p::Post) = joinpath(site(folder), p.section, p.name * ".html")

"The link from the page of the post `p` to the first page of its site"
home(p::Post) = "../"^(isempty(p.section) ? 0 : count('/', p.section) + 1) * "index.html"

"""
How the post `p` of the blog in `folder` stands: `:draft` for one that stays
out of the site, `:new` for one that the site hasn't got, `:changed` for one
that was saved since the site got it, and `:published`. A blog that publishes
itself was last sent at the time `sent`, in seconds. With `sent` nothing,
Ladder hasn't published it, so it can't tell, and the post is `:unknown`.
"""
standing(folder::AbstractString, p::Post; sent::Union{Nothing,Float64}=nothing) = begin
  p.draft && return :draft
  if itself(folder)
    sent === nothing && return :unknown
    made(p.path) > sent && return :new
    return mtime(p.path) > sent ? :changed : :published
  end
  written = page(folder, p)
  isfile(written) || return :new
  mtime(p.path) > mtime(written) ? :changed : :published
end

"What a list says of a post that stands as `s`, or \"\" for one that the site has as it is, or that Ladder can't tell about"
words(s::Symbol) = s == :draft ? "a draft" : s == :new ? "not on the site yet" : s == :changed ? "changed since the site got it" : ""

"The day `d` as a post shows it, like 20 November 2026"
long(d::Date) = "$(Dates.day(d)) $(Dates.monthname(d)) $(Dates.year(d))"

"""
The address of the site that GitHub Pages serves for the repository whose
remote is `url`, like `git@github.com:sam/blog.git`. A repository called
`sam.github.io` is served at that name. It's "" for a remote that isn't on GitHub.
"""
address(url::AbstractString) = begin
  m = match(r"github\.com[:/]([\w\-.]+)/([\w\-.]+?)(?:\.git)?/?\s*$", url)
  m === nothing && return ""
  user, repo = m[1], m[2]
  lowercase(repo) == lowercase(user) * ".github.io" ? "https://$repo/" : "https://$(lowercase(user)).github.io/$repo/"
end

"`html` with each link to a Markdown page beside it made a link to that page of the site"
linked(html::AbstractString) = replace(html, r"(href=\"(?![a-zA-Z][a-zA-Z0-9+.-]*:|#|/)[^\"#?]*?)\.md((?:#[^\"]*)?\")" => s"\1.html\2")

"The files of the blog's folder that the page `html` shows or links to, by their paths from that page: pictures, sounds, videos and the like. A page of the site is none of them."
assets(html::AbstractString) = begin
  out = String[]
  for m in eachmatch(r"(?:src|href)=\"((?![a-zA-Z][a-zA-Z0-9+.-]*:|#|/)[^\"#?]+)\"", html)
    path = replace(String(m[1]), "%20" => " ")
    endswith(lowercase(path), ".html") || path in out || push!(out, path)
  end
  out
end

"The link from the first page of the site to the page of the post `p`, before `linked` makes it a link to HTML"
link(p::Post) = replace((isempty(p.section) ? "" : p.section * "/") * p.name, " " => "%20") * ".md"

"""
The lines of the Markdown that the site's first page is made from: `top`, the
lines of the blog's own front page or a heading with the blog's name, and a
list of the posts that are no drafts. The posts of each section are under a
heading with the section's name.
"""
index(top, list) = begin
  out = String[String(l) for l in body(top)]
  shown = filter(p -> !p.draft, list)
  for section in sections(shown)
    isempty(out) || isempty(strip(out[end])) || push!(out, "")
    isempty(section) || push!(out, "## " * replace(section, "/" => " / "), "")
    for p in shown
      p.section == section && push!(out, "- [$(p.title)]($(link(p))), $(long(p.day))")
    end
  end
  out
end

"""
`html`, the page of the post `p`, with a line at its top that leads back to
the first page of the blog called `blog`, and says the post's day. `blog` and
`title` are HTML. `title` is what the browser's tab says. With `heading`, the
title is the page's first heading too, for a post whose text has none.
"""
framed(html::AbstractString, blog::AbstractString, title::AbstractString, p::Post; heading::Bool=false) = begin
  top = "<p style=\"color: #8a7d6b; font-size: 0.85em\"><a href=\"$(home(p))\">← $blog</a> &nbsp;·&nbsp; $(long(p.day))</p>\n" * (heading ? "<h1>$title</h1>\n" : "")
  # The title goes in as it is: it can have a backslash or a dollar sign in it, which a pattern's replacement would read as its own
  a, b = findfirst("<title>", html), findfirst("</title>", html)
  a === nothing || b === nothing || (html = html[1:last(a)] * title * html[first(b):end])
  replace(html, "<body>\n" => "<body>\n" * top, count=1)
end

# --- what a folder of the site lists ------------------------------------------------------
#
# A site that mirrors its folders, as the canon tool makes jake.rosoman.info,
# shows each folder as a page: the folder's Readme, and under it a list of the
# folder's files and folders, with what each is about, how big it is, and when
# it was made and last saved. main.jl shows a folder of a blog the same way.
#
# The list leaves out a file or a folder whose name starts with a dot, the
# files favicon.ico and tracker.html, the folder's Readme, and the names that
# the folder's own `.gitignore` or `.canonignore` lists, like `*.toml`. A blog
# that Ladder publishes leaves out its folder `docs` and its page `index.md`
# too. The rest are in the order of their names, with capitals first.

"A file or a folder in the list of a folder of a blog"
struct Entry
  path::String
  name::String
  folder::Bool
  icon::Symbol     # :folder, :draft, :review, :markdown, :julia, or :file for anything else
  about::String    # what its description says, with no Markdown in it, or ""
  bytes::Int       # how big it is. A folder is as big as the files that it holds.
  made::Float64    # when it was made, and when it was last saved, in seconds since 1970
  saved::Float64
end

"A pattern of an ignore file, like `*.toml` or `.bin/`, as a pattern that a whole name has to match"
glob(pattern::AbstractString) = begin
  out = IOBuffer()
  for c in strip(strip(pattern), '/')
    print(out, c == '*' ? "[^/]*" : c == '?' ? "[^/]" : c in "[]" ? c : c in ".^\$+(){}|\\" ? "\\" * c : c)
  end
  Regex("^" * String(take!(out)) * "\$")
end

"The patterns of the names that the ignore files of `folder` list"
ignored(folder::AbstractString) = begin
  out = Regex[]
  for file in (".gitignore", ".canonignore"), line in (isfile(joinpath(folder, file)) ? readlines(joinpath(folder, file)) : String[])
    (isempty(strip(line)) || startswith(strip(line), '#')) && continue
    p = try glob(line) catch; nothing end
    p === nothing || push!(out, p)
  end
  out
end

"True when the list of a folder of a blog leaves out the file or the folder called `name`. `top` says that the folder is the blog's own, and `itself` that the blog publishes itself."
hidden(name::AbstractString, patterns; top::Bool=false, itself::Bool=true) =
  startswith(name, '.') || name in ("favicon.ico", "tracker.html") || occursin(r"^readme\.\w+$"i, name) ||
  (top && !itself && (name == SITE || lowercase(name) == INDEX)) || any(p -> occursin(p, name), patterns)

"How many bytes the files in `folder` and in the folders inside it hold, leaving out the hidden ones"
bytes(folder::AbstractString) = begin
  total = 0
  for name in (try readdir(folder) catch; String[] end)
    startswith(name, '.') && continue
    path = joinpath(folder, name)
    total += islink(path) ? 0 : isdir(path) ? bytes(path) : (try filesize(path) catch; 0 end)
  end
  total
end

"What the description of the page at `path` says, with no Markdown in it, or \"\". A folder's is its Readme's."
about(path::AbstractString) = begin
  if isdir(path)
    names = try readdir(path) catch; String[] end
    k = findfirst(isreadme, names)
    return k === nothing ? "" : about(joinpath(path, names[k]))
  end
  ending(basename(path), true) in (MARKDOWN..., ".review") || return ""
  lines = try open(io -> collect(Iterators.take(eachline(io), 40)), path) catch; String[] end
  plain(get(matter(lines), "description", ""))
end

"`text` with its Markdown taken out: a link shows its words, and the marks of bold, italic and code go"
plain(text::AbstractString) = String(strip(replace(replace(text, r"\[([^\]]*)\]\([^)]*\)" => s"\1"), r"[*_`]" => "")))

"The entry of the list for the file or the folder at `path`. With `review`, a page is a book review, as each page in a folder of reviews is."
entry(path::AbstractString; review::Bool=false) = begin
  name = basename(path)
  folder = isdir(path)
  e = ending(name, true)
  icon = folder ? :folder : e == ".review" || (review && e in MARKDOWN) ? :review : e in MARKDOWN ? :markdown : endswith(lowercase(name), ".jl") ? :julia : :file
  if icon == :markdown
    lines = try open(io -> collect(Iterators.take(eachline(io), 40)), path) catch; String[] end
    said = matter(lines)
    (lowercase(get(said, "draft", "")) in ("true", "yes") || lowercase(get(said, "complete", "")) in ("false", "no")) && (icon = :draft)
  end
  Entry(String(path), name, folder, icon, about(path), folder ? bytes(path) : (try filesize(path) catch; 0 end), made(path), mtime(path))
end

"""
The list of the folder `folder` of the blog in `blog`, as the site lists it:
an entry for each file and folder that it doesn't leave out, in the order of
their names. `itself` says that the blog publishes itself, and `reviews`
that the folder holds book reviews, so that each page in it is one.
"""
listing(folder::AbstractString, blog::AbstractString=folder; itself::Bool=true, reviews::Bool=false) = begin
  patterns = ignored(folder)
  top = rstrip(folder, '/') == rstrip(blog, '/')
  names = try readdir(folder) catch; String[] end
  [entry(joinpath(folder, name); review=reviews) for name in names if !hidden(name, patterns; top, itself)]
end

"How many bytes `n` is, as the site says it, like 614 B, 3.78 kB or 1.95 MB"
size_words(n::Integer) = begin
  x, units = Float64(n), ("B", "kB", "MB", "GB", "TB")
  k = 1
  while x > 999 && k < length(units)
    x /= 1000
    k += 1
  end
  x = round(x, digits=2)
  string(isinteger(x) ? round(Int, x) : x, ' ', units[k])
end

"The day of the time `t`, in seconds, as the site's list says it, like 05/09/25"
short(t::Real) = Libc.strftime("%d/%m/%y", t)
