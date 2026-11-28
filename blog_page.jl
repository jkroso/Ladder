# A folder that's a blog: its list, its pages and the look of its site
#
# A blog is a folder whose pages are the posts of a site. blog.jl says what a
# post is. A folder is a blog when its own page, the file `.ladder`, ends with
# this block. Show Folder As, in the command palette, writes it:
#
#     ```julia
#     Ladder.BlogDirectory
#     ```
#
# A folder inside the blog is a section of it. Each folder of the blog shows
# as its site shows it: its Readme, or the blog's index.md, and under it a list
# of the folder's files and folders, with what each is about, how big it is,
# and when it was made and last saved. blog.jl says what the list leaves out.
# A click on a folder in the sidebar, in the list or in the path in the top bar
# shows that folder's page, and the sidebar lists the folder. ⌘W on the last
# tab shows only the list. A folder with no Readme shows only its list. A section with
# its own index.md shows only that page, with no list, as its site does. Every
# page of the blog has the look of the site: see "the look of a blog's site".
#
# The top bar of a page of the blog has three buttons:
#
#   - Publish makes each post a page of HTML, as ⌘⇧E does for one page, in
#     the folder `docs` of the blog. It writes a first page that lists the
#     posts, and copies the pictures that the posts show. A draft stays out.
#     Then, when git keeps the blog and it has a remote called origin, Ladder
#     commits the folder `docs` and pushes it. It commits nothing else: the
#     posts' own files are yours to commit, since a draft is in them.
#   - Open Site shows the page in the browser as the site has it: at the
#     address that the blog's front page gives, or at its address on GitHub
#     Pages, and then the page's path. With no address, it shows the first
#     page in `docs`.
#   - New Post starts a page in the folder that shows.
#
# A blog with a script of its own at `.bin/publish` makes its site and sends
# it itself. Publish runs that script in the blog's folder, and writes no
# `docs`. Ladder notes when the script last did its work, and from then on the
# list says which posts were made or saved since. Before that, it can't tell.
#
# Publish writes one post in each frame, so the window goes on. git's push,
# and a blog's own script, run beside the window, and a later frame reads what
# they said.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor redraw_in!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./html" html escape
@use "./markdown" words after_matter
@use "./sheet" parts
@use "./dates" => DatesRead
@use "./remote" => Remote
@use "./git" => Git
@use "./blog" => Blogs
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use Colors: @colorant_str, RGBA
@use Dates: Dates
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./additions" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./git_marks" exports...
@use "./linkcard_view" exports...
@use "./takeoff_view" exports...
@use "./gallery_view" exports...
@use "./terminal_view" term_page

export BlogDirectory, BlogSection, BookReviewDirectory, SectionFolder, BlogFolder, blog_root,
       page_blog_folder, Publishing, PUBLISHING, PUBLISHED, PUSH_LIMIT, SITE_LIST, SCRIPT_LIMIT,
       COMMAND_FOLDERS, blog_posts, BLOG_POSTS, blog_name, sent_file, blog_sent, blog_sent!, blog_standing,
       blog_address, post_html, copy_assets!, publish!, publish_tick!, publish_step!, posts_words, run_script,
       last_words, script_step!, send_step!, front_page, section_index, open_site, site_address, url_coded,
       open_site_page, SiteListing, ListingRow, site_listing, SITE_LISTS, site_entries, listing_icon,
       listing_column, WebListing, LISTING_HEADS, web_entries, web_day, ReviewHead, SiteLink, web_folder_page,
       review_head, BLOG_ACTIONS, blog_part, blog_act!, blog_tip, blog_off, page_look, web_blog_page

"A blog: a folder whose pages are the posts of a site that Publish writes and sends to GitHub, or that the blog's own script makes and sends"
@def struct BlogDirectory <: AbstractDirectory end

"A folder inside a blog: a section of the blog, whose page shows as the site shows it"
@def struct BlogSection <: AbstractDirectory end

"""
A section of a blog that holds book reviews: each Markdown page in it is a
review, whose top shows as the site shows it. Its own page, `.ladder`, gives
it this kind with `Ladder.BookReviewDirectory` in a julia block. canon, which
makes the site, looks for that name in the page. See "a book review in a blog".
"""
@def struct BookReviewDirectory <: AbstractDirectory end

"A folder inside a blog: a section of it, or a section of book reviews"
const SectionFolder = Union{BlogSection,BookReviewDirectory}

"A folder of a blog: the blog's own folder, or a section of it"
const BlogFolder = Union{BlogDirectory,SectionFolder}

entry_icon(::BlogDirectory) = "rss"
entry_marks(e, o::BlogFolder) = git_marks(e, o)
entry_marks(e, ::BlogFolder, o::FSObject) = git_marks(e, o)
# A folder in a blog is a section of it, unless its own page gives it another kind, or Ladder finds one for it
FS.kind(::BlogFolder, path::FSPath) = (k = folder_kind(path); k === FS.Directory ? BlogSection : k)
# A folder of a blog on a web server is a section too, unless its own .ladder page gives it another kind. See "a web folder's own page".
web_kind(::WebFolder{<:BlogFolder}, f::AbstractString) = (k = web_page_kind(f); k === nothing || k === FS.Directory ? BlogSection : k)
push!(BLOCK_ICONS, "rss", "globe", "cloud-upload", "pencil-square", "folder-fill", "markdown", "pencil", "book", "file-earmark", "star-fill")

"The blog's own folder, of the folder `d` of a blog"
blog_root(d::BlogDirectory) = d
blog_root(d::SectionFolder) = d.parent isa BlogFolder ? blog_root(d.parent) : d

"The folder of a blog that the page that shows is, or that holds it, or nothing for a page that's in no blog"
page_blog_folder(e) = begin
  o = page_object(e)
  o === nothing && (o = text_object(e))
  o isa BlogFolder && return o
  o isa FSObject && !(o isa AbstractDirectory) && o.parent isa BlogFolder ? o.parent : nothing
end

"The publishing of a blog that's under way: the posts that are still to write, how many there were, what it does now, and git's push while it runs"
@def mutable struct Publishing
  folder::String = ""
  posts::Vector{Blogs.Post} = Blogs.Post[]
  every::Vector{Blogs.Post} = Blogs.Post[]
  count::Int = 0
  step::Symbol = :write      # :write, :index or :send, or :script for a blog that publishes itself
  push::Any = nothing        # git's process, or the blog's own script, and what it prints
  since::Float64 = 0.0       # when the push or the script started
  wrote::Vector{String} = String[]   # the pages of the site that this publishing wrote, by their names
end

"The blogs that are being published now, by their folders"
const PUBLISHING = Dict{String,Publishing}()
"What the last publishing of each blog came to, by the blog's folder, for the folder's page to say"
const PUBLISHED = Dict{String,String}()
"How many seconds git has to push a site before Ladder stops it"
const PUSH_LIMIT = 90.0
"The file in a site's folder that lists the pages that Ladder wrote there, so that it can take away the page of a post that's gone"
const SITE_LIST = ".ladder-site"

"How many seconds a blog's own script has to make its site and send it before Ladder stops it"
const SCRIPT_LIMIT = 600.0
"The folders of commands that an app that the Finder opened has no PATH to, which a blog's own script can need: Julia's, Homebrew's and the like"
const COMMAND_FOLDERS = ("~/.juliaup/bin", "~/.local/bin", "/opt/homebrew/bin", "/usr/local/bin")

"The posts of the blog in `folder`, as blog.jl reads them. They're read again after 2 seconds."
blog_posts(folder) = begin
  kept = get(BLOG_POSTS, folder, nothing)
  kept !== nothing && time() - kept[1] < 2 && return kept[2]
  list = try Blogs.posts(folder, itself=Blogs.itself(folder)) catch; Blogs.Post[] end
  BLOG_POSTS[folder] = (time(), list)
  list
end
const BLOG_POSTS = Dict{String,Tuple{Float64,Vector{Blogs.Post}}}()

"What the blog in `folder` is called: the title of its front page, `index.md` or `Readme.md`, or else its folder's name. A Readme with no title of its own doesn't name the blog."
blog_name(folder) = begin
  top = Blogs.front(folder)
  isempty(top) && return basename(folder)
  p = try Blogs.post(top) catch; nothing end
  p === nothing || (Blogs.isreadme(basename(top)) && p.title == p.name) ? basename(folder) : p.title
end

"The file in Ladder's own folder that says when each blog's own script last sent its site"
sent_file() = joinpath(dirname(settings_file()), "blogs sent")

"When the script of the blog in `folder` last sent its site, in seconds, or nothing when Ladder hasn't published it"
blog_sent(folder) = begin
  for line in (isfile(sent_file()) ? readlines(sent_file()) : String[])
    at, path = split(line, '\t', limit=2) .|> String
    path == folder && return tryparse(Float64, at)
  end
  nothing
end

"Note that the script of the blog in `folder` sent its site at the time `at`"
blog_sent!(folder, at::Float64) = begin
  kept = filter(l -> !endswith(l, "\t" * folder), isfile(sent_file()) ? readlines(sent_file()) : String[])
  mkpath(dirname(sent_file()))
  write(sent_file(), join([kept; "$at\t$folder"], "\n") * "\n")
  nothing
end

"How the post `p` of the blog in `folder` stands beside the site: see `Blogs.standing`"
blog_standing(folder, p::Blogs.Post) = Blogs.standing(folder, p, sent=Blogs.itself(folder) ? blog_sent(folder) : nothing)

"""
The address of the blog's site: the one that the blog's front page gives, or
else its address on GitHub Pages. It's \"\" when the page gives none and git
doesn't keep the blog, or its remote isn't on GitHub.
"""
blog_address(folder) = begin
  said = Blogs.said_address(folder)
  isempty(said) || return said
  root = git_top(folder)
  isempty(root) && return ""
  url = something(Git.ask(root, `remote get-url origin`), "")
  site = Blogs.address(strip(url))
  # GitHub Pages serves the folder docs at the top of the repository. A blog deeper in has its site under its own folders.
  rel = relpath(realpath(folder), realpath(root))
  isempty(site) || rel == "." ? site : ""
end

"The post `p` of the blog called `blog` as a page of the site: what ⌘⇧E makes of it, with links to the other posts' pages, and a line at its top that leads back to the first page"
post_html(p::Blogs.Post, blog) = begin
  o = build_editor(p.path)
  layout!(o)
  heading = !any(l -> startswith(l, "# "), o.buf.lines)
  Blogs.framed(Blogs.linked(page_html(o)), escape(blog), escape(p.title), p; heading)
end

"""
Copy each file that the page `html` shows from the blog's folder into its
site, when the site hasn't got it as it is. The page's links start from the
folder `at`, where its post is. The site's folders are the blog's, so each
link goes to the same file from the post's page in the site.
"""
copy_assets!(folder, html, at=folder) = begin
  site = Blogs.site(folder)
  for rel in Blogs.assets(html)
    from = normpath(joinpath(at, rel))
    # A file outside the blog's folder isn't the blog's to put on the web
    (startswith(from, folder * "/") && isfile(from) && !startswith(from, site * "/")) || continue
    to = joinpath(site, relpath(from, folder))
    (isfile(to) && mtime(to) >= mtime(from) && filesize(to) == filesize(from)) && continue
    mkpath(dirname(to))
    cp(from, to, force=true)
  end
end

"""
Start to publish the blog in `folder`: every post that's no draft is written
again, so that each page has the look of this version of Ladder. `publish_tick!`
does the work, a post in each frame.
"""
publish!(folder::AbstractString) = begin
  haskey(PUBLISHING, folder) && return nothing
  list = blog_posts(folder)
  todo = filter(p -> !p.draft, list)
  job = Publishing(folder=folder, posts=copy(todo), every=todo, count=length(todo))
  # A blog that publishes itself runs its own script, which makes every page
  if Blogs.itself(folder)
    job.step, job.posts = :script, Blogs.Post[]
    job.push, job.since = run_script(folder), time()
  end
  PUBLISHING[folder] = job
  delete!(PUBLISHED, folder)
  foreach(e -> redraw_in!(e, 0), editors)
  nothing
end

"Do the next part of each publishing that's under way. Each frame of each window calls this."
publish_tick!(e) = begin
  isempty(PUBLISHING) && return nothing
  for job in collect(values(PUBLISHING))
    said = try
      publish_step!(job)
    catch err
      "Publish stopped. " * trouble(err)
    end
    said === nothing && continue
    delete!(PUBLISHING, job.folder)
    PUBLISHED[job.folder] = said
    empty!(BLOG_POSTS)
  end
  # A step that writes a page has the next frame at once. While every job waits for a script or for git, the window looks ten times a second.
  redraw_in!(e, !isempty(PUBLISHING) && all(job -> job.step in (:script, :send), values(PUBLISHING)) ? 0.1 : 0)
  nothing
end
each_frame!(publish_tick!)

"The next part of the publishing `job`. It gives nothing while there's more to do, and at the end the words that say what it came to."
publish_step!(job::Publishing) = begin
  folder, site = job.folder, Blogs.site(job.folder)
  if job.step == :script
    script_step!(job)
  elseif job.step == :write
    isempty(job.posts) && (job.step = :index; return nothing)
    p = popfirst!(job.posts)
    made = post_html(p, blog_name(folder))
    to = Blogs.page(folder, p)
    mkpath(dirname(to))
    write(to, made)
    copy_assets!(folder, made, dirname(p.path))
    push!(job.wrote, relpath(to, site))
    nothing
  elseif job.step == :index
    top = Blogs.front(folder)
    # A Readme with no title of its own has the blog's name over it
    lines = isempty(top) ? String[] : text(top)
    any(l -> startswith(l, "# "), after_matter(lines)) || (lines = ["# " * blog_name(folder), "", after_matter(lines)...])
    made = Blogs.linked(html(Blogs.index(lines, job.every), title=blog_name(folder)))
    mkpath(site)
    write(joinpath(site, "index.html"), made)
    copy_assets!(folder, made)
    push!(job.wrote, "index.html")
    # GitHub Pages leaves out a folder whose name starts with a dot, like .media, unless this file is there
    touch(joinpath(site, ".nojekyll"))
    # The page of a post that's gone, or that's a draft now, goes from the site. Only a page in the site's own folders goes.
    list = joinpath(site, SITE_LIST)
    for name in (isfile(list) ? readlines(list) : String[])
      name in job.wrote || !endswith(name, ".html") || occursin("..", name) || startswith(name, '/') || rm(joinpath(site, name), force=true)
    end
    write(list, join(job.wrote, "\n") * "\n")
    job.step = :send
    nothing
  else
    send_step!(job)
  end
end

"How many posts, in words"
posts_words(n) = n == 1 ? "1 post" : "$n posts"

"""
Start the script of the blog in `folder`, which makes the blog's site and
sends it. It gives the script's process, and what the script prints. The
script runs in the blog's folder, and finds commands in the folders that a
terminal would. Nothing of the Julia that runs Ladder goes to it.
"""
run_script(folder) = begin
  script = joinpath(folder, Blogs.SCRIPT)
  env = Dict(k => v for (k, v) in ENV if !startswith(k, "KIP_") && !(k in ("JULIA_PROJECT", "JULIA_LOAD_PATH")))
  paths = [split(get(ENV, "PATH", "/usr/bin:/bin:/usr/sbin:/sbin"), ':'); [expanduser(p) for p in COMMAND_FOLDERS]]
  env["PATH"] = join(unique(filter(!isempty, paths)), ':')
  out = IOBuffer()
  cmd = Sys.isexecutable(script) ? `$script` : `/bin/sh $script`
  (run(pipeline(setenv(cmd, env; dir=folder), stdin=devnull, stdout=out, stderr=out), wait=false), out)
end

"The last line that's not blank in `said`, or \"\""
last_words(said::AbstractString) = (k = findlast(l -> !isempty(strip(l)), split(said, '\n')); k === nothing ? "" : String(strip(split(said, '\n')[k])))

"""
Wait for the script of the publishing `job`. It gives nothing while the
script runs, and then the words that say what the publishing came to. When
the script did its work, Ladder notes the time that it started: a post saved
after that may not be in the site.
"""
script_step!(job::Publishing) = begin
  p, out = job.push
  if process_running(p)
    time() - job.since > SCRIPT_LIMIT || return nothing
    kill(p)
    return "Your script $(Blogs.SCRIPT) didn't finish in $(round(Int, SCRIPT_LIMIT / 60)) minutes, so Ladder stopped it."
  end
  wait(p)   # the last of what the script printed can still be on its way
  said = last_words(String(take!(out)))
  if success(p)
    blog_sent!(job.folder, job.since)
    site = blog_address(job.folder)
    return "Published. Your script $(Blogs.SCRIPT) made the site and sent it." * (isempty(site) ? "" : " The site is at $site")
  end
  "Your script $(Blogs.SCRIPT) stopped, and said: " * (isempty(said) ? "nothing" : said)
end

"Send the site of the publishing `job` to GitHub: commit the site's folder, and push. It gives nothing while git's push runs, and then the words that say what the publishing came to."
send_step!(job::Publishing) = begin
  folder = job.folder
  wrote = "Ladder wrote $(posts_words(job.count)) into the folder $(Blogs.SITE)."
  root = git_top(folder)
  isempty(root) && return wrote * " git doesn't keep this folder, so nothing went to the web."
  if job.push === nothing
    isempty(strip(something(Git.ask(root, `remote get-url origin`), ""))) &&
      return wrote * " The repository has no remote called origin, so nothing went to the web."
    rel = relpath(realpath(Blogs.site(folder)), realpath(root))
    Git.act(root, `add -- $rel`)
    # With nothing new in the site, git has nothing to commit, and the push still sends what an earlier commit left
    done, why = Git.act(root, `commit -m "Publish the blog" -- $rel`)
    done || occursin(r"nothing (added )?to commit|no changes added", why) ||
      return wrote * " git couldn't commit it: " * String(first(split(isempty(strip(why)) ? "it gave no reason" : strip(why), '\n')))
    job.push = Git.start(root, `push origin HEAD`)
    job.since = time()
    return nothing
  end
  p, out = job.push
  if process_running(p)
    time() - job.since > PUSH_LIMIT || return nothing
    kill(p)
    return wrote * " git didn't finish sending it in $(round(Int, PUSH_LIMIT)) seconds, so the site on the web is as it was."
  end
  Git.forget!()
  success(p) && return (site = blog_address(folder); "Published $(posts_words(job.count))." * (isempty(site) ? "" : " The site is at $site"))
  said = strip(String(take!(out)))
  wrote * " git couldn't send it: " * String(first(split(isempty(said) ? "it gave no reason" : said, '\n')))
end

"""
The page of the folder `d` of a blog that shows at the top, as its site shows
it: the blog's index.md or Readme, or a section's own index.md or else its
Readme. It's "" for a folder that has none.
"""
front_page(d::BlogDirectory) = Blogs.front(path_of(d))
front_page(d::SectionFolder) = begin
  folder = path_of(d)
  names = try readdir(folder) catch; String[] end
  k = findfirst(Blogs.isindex, names)
  k === nothing && (k = findfirst(Blogs.isreadme, names))
  k === nothing ? "" : joinpath(folder, names[k])
end

on_own_page(e, d::BlogFolder) = (top = front_page(d); !isempty(top) && e.buf.path == top)

"True for a section of a blog with its own index.md, which its site shows alone, with no list"
section_index(d::SectionFolder) = Blogs.isindex(basename(front_page(d)))
section_index(::BlogDirectory) = false

# A click on a folder of a blog shows its page as the site does: its Readme, with the list of the folder under
# it, or only the list when it has no Readme. A section with its own index.md shows only that page. The sidebar
# lists the folder.
open!(e, d::BlogFolder; record=true) = begin
  top = front_page(d)
  open!(e, isempty(top) ? string(d.path) : top; record)
  go_folder!(e, string(d.path))
end

page_foot(e, d::BlogFolder, o::FS.File) = path_of(o) == front_page(d) && !section_index(d) ? site_listing(e, d) : nothing
page_view(e, d::BlogFolder) = site_listing(e, d)

"Show the site of the blog in `folder` in the browser: at its address on the web when it has one, or else the first page that Publish wrote"
open_site(folder) = begin
  site = blog_address(folder)
  page = joinpath(Blogs.site(folder), "index.html")
  isempty(site) ? (isfile(page) && BROWSER[](page)) : BROWSER[](site)
  nothing
end

"""
The address of the page at `path` on the site of the blog in `folder`: the
site's address, and then the page's path in the blog, as the site names it. A
folder, its Readme and its own index.md are the folder's own address, which
ends in a /. A post ends in .html. Each character that an address can't hold,
such as a space or a ?, is written as its %-code, as the site writes its links.
It's "" when the site has no address.
"""
site_address(folder, path) = begin
  site = blog_address(folder)
  isempty(site) && return ""
  rel = isempty(path) ? "." : relpath(path, folder)
  (rel == "." || startswith(rel, "..")) && return site
  parts = String.(split(rel, '/'))
  name = parts[end]
  if isdir(path)
    push!(parts, "")
  elseif Blogs.isreadme(name) || Blogs.isindex(name)
    parts[end] = ""
  else
    ending = Blogs.ending(name, true)
    ending === nothing || (parts[end] = name[1:end-length(ending)] * ".html")
  end
  parts == [""] && return site   # the blog's own Readme is the site's first page
  (endswith(site, "/") ? site : site * "/") * join(url_coded.(parts), "/")
end

"`part` of an address with each character that an address can't hold as it is, such as a space or a ?, as its %-code"
url_coded(part::AbstractString) = replace(part, r"[^A-Za-z0-9\-._~]" => c -> join(string('%', uppercase(string(b, base=16, pad=2))) for b in codeunits(c)))

"Show the page that's in the window as the blog in `folder` has it on its site, or else the site's first page"
open_site_page(e, folder) = begin
  url = site_address(folder, e.buf.path)
  isempty(url) ? open_site(folder) : BROWSER[](url)
  nothing
end

# --- the list of a folder of a blog -----------------------------------------------------------
#
# Under a folder's Readme, a list of what the folder holds, as the blog's site
# has it: a line for each file and folder, with its icon and name, what it's
# about, how big it is, and the days that it was made and last saved. A
# section's list starts with a line that goes up to the folder above. A click
# on a line shows that file or folder. A post that the site hasn't got as it
# is has a dot after its name: that's Ladder's own, and the site has none.

"The list of a folder of a blog, as a part of the page"
@def mutable struct SiteListing <: SemanticUI
  path::String = ""   # the folder
  blog::String = ""   # the blog's own folder
  reviews::Bool = false   # the folder holds book reviews, so each page in it has a book in the list
  rows::Dict{Any,Any} = Dict{Any,Any}()
end

"A line of the list of a folder of a blog. Its name is the site's red while the mouse is over it."
@def mutable struct ListingRow <: SemanticUI
  act::Any = nothing     # what a click does, a function of the window
  cells::Any = nothing   # what the line shows, a function of whether the mouse is over it
  last::Bool = false     # the last line has no rule under it
end

describe(r::ListingRow) = Row(width(grow=grow), Alignment.Center, name="Line",
  (r.last ? () : (border(1px, :solid, colours.line)[:bottom],))..., r.cells(ishovered(r))...)
cursor(::ListingRow) = :hand
onkey(r::ListingRow, ev::KeyPress{Keys.mouse_left}) = r.act === nothing ? nothing : (r.act(ev.window); handled)

"The list of the folder `d` of a blog, as a part of the page"
site_listing(e, d::BlogFolder) = begin
  folder = path_of(d)
  v = node!(() -> SiteListing(path=folder), e, (:listing, folder))
  v.blog = path_of(blog_root(d))
  v.reviews = d isa BookReviewDirectory
  v
end

"What each folder of a blog holds, as its list has it, by the folder. Each is read again after 2 seconds."
const SITE_LISTS = Dict{String,Tuple{Float64,Vector{Blogs.Entry}}}()

"The entries of the list of `folder`, of the blog in `blog`. With `reviews`, each page in the folder is a book review."
site_entries(folder, blog; reviews=false) = begin
  kept = get(SITE_LISTS, folder, nothing)
  kept !== nothing && time() - kept[1] < 2 && return kept[2]
  list = try Blogs.listing(folder, blog, itself=Blogs.itself(blog), reviews=reviews) catch; Blogs.Entry[] end
  SITE_LISTS[folder] = (time(), list)
  list
end

"The icon of an entry of a list, and its colour, as the site's icons have them"
listing_icon(x::Blogs.Entry) =
  x.icon == :folder ? ("folder-fill", colorant"rgb(192,149,83)") :
  x.icon == :draft ? ("pencil", colorant"rgb(214,112,82)") :
  x.icon == :review ? ("book", colours.dim) :
  x.icon == :markdown ? ("markdown", colours.dim) : (file_icon(x.name), colours.dim)

describe(v::SiteListing) = begin
  e = editor(v)
  redraw_in!(e, 2.1)   # a file that's saved or added shows here soon after
  list = site_entries(v.path, v.blog, reviews=v.reviews)
  stale = Set(p.path for p in blog_posts(v.blog) if blog_standing(v.blog, p) in (:new, :changed))
  # A section's list starts with a line that goes up to the folder above it
  up = rstrip(v.path, '/') == rstrip(v.blog, '/') ? nothing : dirname(rstrip(v.path, '/'))
  listing_column(v, e, list; up, stale, go=path -> show_path!(e, path))
end

"""
The list of a folder of a blog, as `v`, a `SiteListing` or a `WebListing`,
shows it: a heading, then a line for each of the entries `list`. `up` is the
folder above, for a line at the top that goes up to it, or nothing for no
such line. The entries whose paths are in `stale` have a dot after their
names. A click on a line calls `go` with the path of the line's entry. With
`sizes`, the list has a column of how big each entry is.
"""
listing_column(v, e, list; up=nothing, stale=Set{String}(), go, sizes=true) = begin
  font = SITE_FONT[]
  s = body(e).size * 0.8   # the list's text is a little smaller than the page's, as the site's is
  small = s * 0.9
  said(t, size; style="", color=colours.ink) = Box(Text(t, size=size, family=font, subfamily=style, color=color, wrap=WrapMode.none))
  # The columns of the size and the days are as wide as they need to be. The names and what each is about share the rest, 3 to 4.
  size_w = sizes ? measure(Face(font, "", small, colours.dim, false), "000.00 kB") + s : 0px
  day_w = measure(Face(font, "", small, colours.dim, false), "00/00/00") + s
  rest = max(240px, e.width - size_w - 2day_w)
  name_w, about_w = rest * 3 / 7, rest * 4 / 7
  pad = padding(0px, s * 0.45)
  right(w, x) = Row(fixed(w), height(grow=grow), pad, justify=Alignment.End, x)
  heading(t, w; at_end=false) = (x = said(uppercase(t), s * 0.78, style="SemiBold", color=colours.dim);
                                at_end ? right(w, x) : Row(fixed(w), pad, Alignment.Start, x))
  head = Row(width(grow=grow), Alignment.Center, border(1px, :solid, SITE_RULE)[:bottom],
    heading("Name", name_w), heading("Description", about_w),
    (sizes ? (heading("Size", size_w, at_end=true),) : ())..., heading("Created", day_w, at_end=true), heading("Modified", day_w, at_end=true))
  line(key, path, cells) = begin
    r = get!(() -> own!(v, ListingRow()), v.rows, key)
    r.act, r.cells, r.last = _ -> (go(path); nothing), cells, false
    r
  end
  # A name that's wider than its column goes on to more lines, as the site's does, so none of it is cut off
  name_cell(icon, colour, name, over, dot=false) =
    Row(fixed(name_w), height(grow=grow), padding(s * 0.45, s * 1.1, s * 0.45, 0px), Alignment.Center, child_gap=s * 0.6, clip=true,
      Icon(icon, size=s * 1.15, color=colour),
      Box(Alignment.Start, Text(name, size=s, family=font, subfamily="SemiBold", color=over ? colours.accent : colours.ink, wrap=WrapMode.words)),
      (dot ? (Box(width(6px), height(6px), radius(3px), background(colours.accent)),) : ())...,
      Box(width(grow=grow)))
  rows = Any[]
  up === nothing || push!(rows, line((:up, up), up, over -> (name_cell("folder-fill", colorant"rgb(192,149,83)", "..", over), Box(fixed(about_w)))))
  for x in list
    icon, colour = listing_icon(x)
    push!(rows, line((:entry, x.path), x.path, over -> (
      name_cell(icon, colour, x.name, over, x.path in stale),
      Box(fixed(about_w), padding(s * 0.45, s * 1.1, s * 0.45, 0px), Alignment.Start,
        Text(x.about, size=s, family=font, subfamily="Italic", color=SITE_INK2, wrap=WrapMode.words)),
      (sizes ? (right(size_w, said(Blogs.size_words(x.bytes), small, color=colours.dim)),) : ())...,
      right(day_w, said(x.made > 0 ? Blogs.short(x.made) : "", small, color=colours.dim)),
      right(day_w, said(x.saved > 0 ? Blogs.short(x.saved) : "", small, color=colours.dim)))))
  end
  Column(width(grow=grow), Alignment.Start, padding(s * 1.6, 0px, 0px, 0px), name="Listing",
    head, (isempty(rows) ? () : (last(rows).last = true; rows))...)
end

cursor(::SiteListing) = :arrow

# --- the list of a folder of a blog on a web server ---------------------------------------------
#
# The site of a blog sends the page of a folder as Markdown: the folder's
# Readme, then a table of what the folder holds, with a line for each file
# and folder, as the canon tool writes it:
#
#     | Name | Description | Created | Modified |
#     |---|---|---|---|
#     | [Humans](Humans/) | My take on psychology | 2025-07-17 | 2026-10-04 |
#     | [Dating.md](Dating.md) (draft) | The problems with dating | 2025-12-12 | 2025-12-13 |
#
# When the folder's .ladder page makes it a folder of a blog, Ladder shows
# that table as the list that the folder has on the Mac: an icon and the name
# in bold, what each is about in italics, and the days. The server doesn't say
# how big each is, so the list has no column for that. A section's list
# starts with a line that goes up to the folder above it. A click on a line
# asks the server for its page.

"The list of a folder of a blog on a web server, from the table at the end of the folder's page"
@def mutable struct WebListing <: SemanticUI
  entries::Vector{Blogs.Entry} = Blogs.Entry[]   # a line for each, with its address as its path
  up::String = ""   # the address of the folder above, or "" for no line that goes up
  rows::Dict{Any,Any} = Dict{Any,Any}()
end

"The headings of the table at the end of the page of a folder of a blog on its site"
const LISTING_HEADS = ["name", "description", "created", "modified"]

table_view(e, d::WebFolder{<:BlogFolder}, o::WebPage, from, to) = begin
  lines = e.buf.lines
  # Only the folder's own page ends in its list
  rstrip(Remote.bare(o.address), '/') == rstrip(d.address, '/') || return nothing
  all(i -> isempty(strip(lines[i])), to+1:length(lines)) || return nothing
  lowercase.(celltexts(lines[from])) == LISTING_HEADS || return nothing
  v = node!(WebListing, e, (:web_listing, d.address))
  v.entries = web_entries(d, @view lines[from+2:to])
  v.up = d isa WebFolder{BlogDirectory} || d.parent === nothing ? "" : d.parent.address
  v
end

"The entries of the list of the web folder `d` of a blog, from the `lines` of the table of its page that are under the line of dashes"
web_entries(d::WebFolder, lines) = begin
  reviews = d isa WebFolder{BookReviewDirectory}
  out = Blogs.Entry[]
  for line in lines
    cells = celltexts(line)
    length(cells) >= 4 || continue
    m = match(r"^\[(.*)\]\(([^)\s]*)\)\s*(\(draft\))?$", cells[1])
    m === nothing && continue
    name, link = String(m[1]), String(m[2])
    folder = endswith(link, "/")
    ending = Blogs.ending(name, true)
    icon = folder ? :folder : ending == ".review" || (reviews && ending in Blogs.MARKDOWN) ? :review :
           ending in Blogs.MARKDOWN ? (m[3] === nothing ? :markdown : :draft) : endswith(lowercase(name), ".jl") ? :julia : :file
    push!(out, Blogs.Entry(Remote.against(d.address, link), name, folder, icon, Blogs.plain(cells[2]), -1, web_day(cells[3]), web_day(cells[4])))
  end
  out
end

"The day `text`, like 2026-03-12, as a time in seconds since 1970, at noon so that it's that day in any time zone, or 0 when it isn't a day"
web_day(text) = (d = DatesRead.day(text; iso=true); d === nothing ? 0.0 : Dates.datetime2unix(Dates.DateTime(d)) + 12 * 3600)

describe(v::WebListing) = (e = editor(v);
  listing_column(v, e, v.entries; up=isempty(v.up) ? nothing : v.up, go=url -> follow_remote!(e, url), sizes=false))

cursor(::WebListing) = :arrow

# --- a book review in a blog ------------------------------------------------------------------
#
# A book review is Markdown with a header that says the book's title, an
# address to read about it, its rating out of 5, the year it came out and a
# line on what it's about:
#
#     +++
#     title = "The Selfish Gene"
#     link = "https://en.wikipedia.org/wiki/The_Selfish_Gene"
#     rating = 5
#     pubDate = 1976-01-01
#     description = "Extends Darwin's theory of evolution"
#     +++
#
# In a blog, the top of the review shows those as the site does: the title in
# the middle, then the address's site, the stars and the year, then the line
# in italics. The header's own lines show while the caret is in them.
#
# A review is a page in a section of book reviews: a folder whose page
# `.ladder` makes it a `BookReviewDirectory`, as Canon's Book Reviews is:
#
#     ```julia
#     Ladder.BookReviewDirectory
#     ```
#
# A file that ends in `.review` is a review too, anywhere in a blog. That's how
# reviews were written before.

"The top of a book review in a blog, in place of the card of its front matter"
@def mutable struct ReviewHead <: SemanticUI
  said::Dict{String,String} = Dict{String,String}()   # what the header sets, by its keys in small letters
  link::Any = nothing                                 # the address under the title, which a click opens
end

"An address at the top of a book review. A click opens it in the browser."
@def mutable struct SiteLink <: SemanticUI
  url::String = ""
  words::String = ""
  size::px = 13px
end

describe(l::SiteLink) = Box(name="Link", border(1px, :solid, RGBA(colours.accent, 0.34))[:bottom],
  Text(l.words, size=l.size, family=SITE_FONT[], color=colours.accent, wrap=WrapMode.none))
cursor(::SiteLink) = :hand
onkey(l::SiteLink, ::KeyPress{Keys.mouse_left}) = (isempty(l.url) || BROWSER[](l.url); handled)

# A folder's own page, its Readme or index.md, shows no front matter, as its site shows none. A post keeps its card.
matter_view(e, d::BlogFolder, o::FS.File, rows) = path_of(o) == front_page(d) ? false : nothing
matter_view(e, ::BlogFolder, ::FS.File{:review}, rows) = review_head(e, rows)
matter_view(e, d::BookReviewDirectory, o::FS.File{:md}, rows) = path_of(o) == front_page(d) ? false : review_head(e, rows)

# A page of a blog on a web server has no .review at the end of its address, so its front matter says that it's a
# book review: it has a rating, as each .review file has
matter_view(e, d::WebFolder{<:BlogFolder}, o::WebPage, rows) =
  web_folder_page(d, o) ? false : any(r -> lowercase(r[2]) == "rating", rows) ? review_head(e, rows) : nothing

"True when the page `o` from a web server is the own page of the web folder `d`: the page at the folder's address"
web_folder_page(d::WebFolder, o::WebPage) = rstrip(Remote.bare(o.address), '/') == rstrip(d.address, '/')

"The top of a book review of a blog, with what its front matter `rows` say"
review_head(e, rows) = begin
  h = node!(ReviewHead, e, :review_head)
  h.said = Dict(lowercase(k) => String(strip(v, ['"', '\''])) for (_, k, v) in rows)
  h
end

describe(h::ReviewHead) = begin
  e = editor(h)
  s = body(e).size
  font = SITE_FONT[]
  url = get(h.said, "link", "")
  m = match(r"^[a-z]+://([^/?#]+)"i, url)
  h.link === nothing && (h.link = own!(h, SiteLink()))
  h.link.url, h.link.words, h.link.size = url, m === nothing ? url : String(m[1]), s * 0.9
  stars = clamp(something(tryparse(Int, get(h.said, "rating", "")), 0), 0, 5)
  y = match(r"\d{4}", get(h.said, "pubdate", ""))
  about = Blogs.plain(get(h.said, "description", ""))
  meta = Any[]
  isempty(h.link.words) || push!(meta, h.link)
  # Literata has no star, so the stars are icons
  stars > 0 && push!(meta, Row(child_gap=s * 0.12, (Icon("star-fill", size=s * 0.85, color=SITE_STARS) for _ in 1:stars)...))
  y === nothing || push!(meta, Box(Text(String(y.match), size=s * 0.9, family=font, color=colours.dim, wrap=WrapMode.none)))
  Column(width(grow=grow), Alignment.Center, padding(s * 1.2, 0px, s * 1.6, 0px), child_gap=s * 1.1, name="Review",
    Box(width(grow=grow), Text(get(h.said, "title", ""), size=2.3s, family=font, subfamily="SemiBold", color=colours.ink, wrap=WrapMode.words, align=TextAlign.Center)),
    (isempty(meta) ? () : (Row(Alignment.Center, child_gap=s * 1.1, meta...),))...,
    (isempty(about) ? () : (Box(fixed(min(e.width, 26 * 1.12s)), Text(about, size=1.12s, family=font, subfamily="Italic", color=SITE_INK2, wrap=WrapMode.words, align=TextAlign.Center)),))...)
end

onkey(h::ReviewHead, ev::KeyPress{Keys.mouse_left}) = click_page!(h, ev)

# --- the buttons of a page of a blog ------------------------------------------------------------

"The actions of the buttons that the top bar has on a page of a blog"
const BLOG_ACTIONS = (:publish, :open_site, :new_post)

"""
What the top bar has on a page of a blog: the buttons that publish the blog,
show the page on its site and start a post, and a word on how the last
publishing went. Publish's tooltip says the rest.
"""
blog_part(e) = begin
  d = page_blog_folder(e)
  d === nothing && return ()
  folder = path_of(blog_root(d))
  going = haskey(PUBLISHING, folder)
  going && redraw_in!(e, 0.03)   # each frame does the next part of the publishing
  last = get(PUBLISHED, folder, "")
  said = going ? "Publishing…" : isempty(last) ? "" : startswith(last, "Published") ? "Published" : "Not published"
  ((isempty(said) ? () : (Box(height(28px), padding(6px, 0px), label(said, 12px, color=colours.dim)),))...,
   button(e, :publish, "cloud-upload"), button(e, :open_site, "globe"), button(e, :new_post, "pencil-square"), Box(width(4px)))
end

"Do what the button of a page of a blog with the action `action` does"
blog_act!(e, action) = begin
  d = page_blog_folder(e)
  d === nothing && return nothing
  root = path_of(blog_root(d))
  action == :publish && publish!(root)
  action == :open_site && open_site_page(e, root)
  action == :new_post && new_page!(e, path_of(d))
  nothing
end

"What the tooltip of the button of a page of a blog with the action `action` says"
blog_tip(e, action) = begin
  d = page_blog_folder(e)
  d === nothing && return ""
  root = path_of(blog_root(d))
  action == :new_post && return "Start a post in $(basename(path_of(d)))"
  action == :open_site && return isempty(blog_address(root)) ? "Show the site that Publish wrote" : "Show this page on the site"
  job = get(PUBLISHING, root, nothing)
  job === nothing || return job.step == :script ? "Your script $(Blogs.SCRIPT) is making the site and sending it…" :
                            job.step == :send ? "Sending the site to GitHub…" : "Writing post $(job.count - length(job.posts)) of $(job.count)…"
  stands = [blog_standing(root, p) for p in blog_posts(root)]
  waiting, drafts = count(s -> s in (:new, :changed), stands), count(==(:draft), stands)
  join(["Publish $(blog_name(root))";
        (waiting == 0 ? String[] : ["$(posts_words(waiting)) that the site hasn't got as $(waiting == 1 ? "it is" : "they are")"]);
        (drafts == 0 ? String[] : [drafts == 1 ? "1 draft" : "$drafts drafts"]);
        (isempty(get(PUBLISHED, root, "")) ? String[] : ["Last time: " * PUBLISHED[root]])], "  ·  ")
end

"True when the button of a page of a blog with the action `action` does nothing now"
blog_off(e, action) = begin
  d = page_blog_folder(e)
  d === nothing && return true
  root = path_of(blog_root(d))
  action == :publish && return haskey(PUBLISHING, root) || !(Blogs.itself(root) || any(p -> !p.draft, blog_posts(root)))
  action == :open_site && return isempty(blog_address(root)) && !isfile(joinpath(Blogs.site(root), "index.html"))
  false
end

# --- the look of a blog's site ----------------------------------------------------------------
#
# Every page of a blog looks as the blog's site does, as the canon tool makes
# jake.rosoman.info: its text is in Literata, on the cream paper and in the
# warm ink of the site, with links in its red. The text is as wide as the
# site's, for as many words to a line, and a first heading is in the middle,
# as big as the site's. The window has the site's colours while such a page
# shows, whatever the theme. The page's front matter shows as on any page. A
# terminal's file in a blog's folder isn't a page of the blog, so it has the
# theme's colours.

"How the page that's in the window looks: :site for a page of a blog, on the Mac or on a web server, as its site has it, :news for a newspaper's front page or article, or :own, as the settings say"
page_look(e) = !term_page(e.buf) && (page_blog_folder(e) !== nothing || web_blog_page(e)) ? :site : news_look(e) ? :news : :own

"True when the page that shows is from a web server, in a folder of a blog there: see \"a web folder's own page\""
web_blog_page(e) = (o = text_object(e); o isa WebPage && o.parent isa WebFolder{<:BlogFolder})

"What the window's colours are called now, for what's kept with them: :site on a page of a blog, or else the theme's name"
look_key(e) = e.look in (:site, :news) ? e.look : e.theme
