# A page from a web server: how Ladder gets it and shows it, the browser folder that keeps it, and the web address of each of its files
#
# Ladder shows a page of Markdown that a web server sends, as a browser shows
# a page of HTML, and keeps it as a file of the browser folder, ~/web.
# Each section below says more. sandbox.jl has the sandbox that the page's
# code runs in. The commands Navigate, Reload Page and Open In Browser are in
# main.jl.

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in! close_popup!
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring with_pool
@use "./html" html
@use "./markdown" Kind Line words wikitarget MATTER TOML_MATTER MATH
@use "./markdown" COMMENT
@use "./sheet" parts shown
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS AbstractDirectory
@use "./remote" => Remote
@use "./macfile" => MacFiles
@use "./app/facts" APP_ID
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
@use "./linkcard_view" exports...
@use "./check_view" exports...
@use "./view_block" exports...
@use "./result_block" exports...
@use "./folder_kinds" exports...
@use "./git_page" keep_saying! said_result unsay_result!

export COPY_ADDRESSES, COPY_MARK, GOT_MARK, PAGE_WAIT, PageAsked, RELOAD_ASKER, SHOWN_BLOCKS,
       ask_reload!, fingerprint, forget_view_copies!, got_mark, land_page!, mark_copy!, mark_file!,
       navigate!, navigate_place, open_in_browser!, place_label, reads_here, reload_page!,
       reload_panel, remote_tick!, saved_page, show_page!, take_page!, typed_path, unsay_getting!,
       web_buffer, open_address!, site_folder

# --- a page from a web server ----------------------------------------------------------------
#
# Ladder shows a page of Markdown that a web server sends, as a browser shows
# a page of HTML. The page's path is its address, like
# https://example.com/notes.md. There are five ways to ask for one:
#
#   - Press ⌘L, type or paste the address, and press Return. ⌘L is the key
#     of the command Navigate, as it's the key of a browser's address bar.
#   - Press ⌘⇧P, type or paste the address, and press Return. The list of
#     commands has Navigate first while what's typed is an address, with
#     where it goes under its name. Navigate is in the list by its name too,
#     and asks for the address.
#   - Press ⌘O, type or paste the address, and press Return.
#   - Click a link to it in a page.
#   - Name it when you start Ladder from its code, as in
#     `julia main.jl example.com/notes.md`. The `ladder` command of the
#     terminal takes no address yet.
#
# Ladder tells the server that it wants Markdown, so a server that keeps a
# page as Markdown and as HTML sends the Markdown. What comes is a page of
# Markdown when the server says so, or when the server doesn't say what it is
# and the address ends as a Markdown file's name does, like `.md`. See
# remote.jl.
#
# A server that has no Markdown at the address sends a page of HTML. Ladder
# shows the page that the HTML makes, with its own engine, as it shows an
# HTML file: see "an HTML file as its page". The page covers the window
# under the top bar, and it's yours to use: its scripts run, the wheel
# scrolls it, and you type in its fields. ⌘E shows the HTML that the server
# sent, and ⌘E again the page. A click on a link of the page goes where a
# link of a page of Markdown goes, so ⌘⌥← comes back. Anything else that a
# server sends, like a PDF file or a picture, opens in your browser.
#
# The window goes on showing the page that it has while the new one comes,
# and words under the top bar say that Ladder is getting it. If the server
# doesn't answer, or has no such page, the words say that.
#
# The page is read, and not changed. It has no caret, as an email has none.
# Its Save button, or ⌘S, saves a copy of it that you can change: see "a copy
# of a page from a web server". The top bar shows its address without the https://. ⌘⌥← goes back to the
# page before it, and shows that page as it was, without asking again. Reload
# Page, in the command palette, asks the server for the page again.
#
# A link of the page is from the page's own address: `../prices.md` is in the
# folder over the page's, on the same server. A click on a link asks for what
# it names. Markdown and HTML show in the window, and anything else opens in
# your browser. What the server says of an address that it has nothing for
# shows too, as a browser shows it. A link to a heading of the page, like
# `#prices`, goes there. A picture is from the page's address too.
#
# In a page of your own, a click on a link to an address that ends as a
# Markdown file's name does asks the server too. Any other address opens in
# your browser, as it always has, without Ladder asking for it first.
#
# Somebody else wrote a page of Markdown, so three rules keep it from the
# Mac. A page of HTML is kept from the Mac as a `view` block keeps one: see
# "a page of the web".
#
#   - It runs no code. A `ui` block, a sum in a line of text and a `check`
#     block show as their code. ⌘Return runs nothing.
#   - It shows no file of the Mac: no part of another page, no picture from
#     a path on the Mac, and no block that reads a file or a folder. Such a
#     block shows as its code. A wiki link, like [[Ideas]], goes nowhere.
#   - A block that asks a server for something, or sends it something, shows
#     as its code: `load`, `save`, `view` and the like.
#
# What still shows as more than its text: tables, diagrams, formulas, the
# card of the front matter, callouts, footnotes and pictures.
#
# The first rule holds for an email too, since somebody else wrote it: an
# email runs no code, and a block that Ladder would do more with shows as its
# code. See `foreign`.
#
# A folder on the server can change how the pages in it show, with a page
# called `.ladder`, as a folder on the Mac can. Ladder runs that page's code
# only for a site that you allow: see "a web folder's own page".
#
# A window that isn't on the screen, like one a test makes, asks the web for
# nothing, unless a test put its own function in `PAGE_GETTER`.

"True when the window of `e` may ask a web server for a page: it's on the screen, or a test stands in for `curl`"
page_online(e) = PAGE_GETTER[] !== Remote.curl || on_screen(e)

"The languages of the code blocks that a page from a web server shows as more than their code. They run no code, read nothing of the Mac and ask no server."
const SHOWN_BLOCKS = (MATTER, TOML_MATTER, MATH, COMMENT, (l for (l, T) in BLOCKS if block_safe(T))...)

"""
Make each code block of a page that somebody else wrote one that only shows
its code, where Ladder would do more with it: run it, as it does a `ui`
block, or read a file for it, or ask a server. `ks` are the kinds of the
page's lines. A block of Julia code keeps its colours. A block in a language
that Ladder does nothing with, like `python`, stays as it is. True when a
block that would do more now only shows its code. See `foreign`.
"""
shown_only!(ks::Vector{Line}, shown=SHOWN_BLOCKS) = begin
  hid = false
  for (i, l) in enumerate(ks)
    (l.kind in (Kind.fence, Kind.code) && !isempty(l.lang) && !(l.lang in shown) && known_lang(l.lang)) || continue
    lang = l.lang in (LIVE, CHECK, RESULT, "julia") ? "julia" : ""
    hid |= lang != l.lang
    ks[i] = Line(l.kind, l.level, l.prefix, lang)
  end
  hid
end

# --- the browser folder ---
#
# Each page and file that Ladder gets from the web goes in the browser folder,
# ~/web, at its place on its site: https://example.com/notes/plans.md is
# example.com/notes/plans.md there. The window shows that file. Being in the
# folder is what makes the file act as a page of the web: its links and
# pictures are from its web address, a click on a link opens it, the path in
# the top bar starts with the site's name, and its code runs only for a site
# that you allow. You can change it, and ⌘S writes your changes to the file,
# never to the server.
#
# Each file keeps its web address in the extended attribute `COPY_MARK`, and a
# fingerprint of what the server sent in `GOT_MARK`, so Ladder knows when you
# changed it. When you go to its address again, the file shows at once while
# Ladder asks the server. What the server sends takes the file's place, unless
# you changed the file and the server has something new: then Ladder asks you
# first. Reload Page asks you whenever you changed the file.
#
# A page of Markdown ends in .md, and a page of HTML in .html: the page of
# example.com/notes/ is notes/index.md. No name can start with a dot, so a
# folder's .ladder page, which would run its code, is never in the folder:
# see "a web folder's own page".

"""
True when `path` is a file or a folder in the browser folder, of a site. A file
at the top of the folder, like Favourites.md, is of no site: it's a page of your own.
"""
in_browser(path::AbstractString) = begin
  root = browser_folder() * "/"
  (!isempty(path) && startswith(path, root)) || return false
  occursin('/', SubString(path, ncodeunits(root) + 1)) || isdir(path)
end

"""
The file of the browser folder that keeps what's at `address`, or nothing when
no file can, as for a name that starts with a dot. A `page` of Markdown ends in
.md, and a page of HTML (`html`) in .html. Any other file keeps its name.
"""
browser_path(address::AbstractString; page=false, html=false) = begin
  host = lowercase(Remote.host(address))
  (Remote.isaddress(address) && !isempty(host) && !startswith(host, '.') && !occursin('/', host)) || return nothing
  rel = Remote.copy_path(address; page)
  rel === nothing && return nothing
  html && !(lowercase(splitext(rel)[2]) in HTMLS) && (rel *= ".html")
  joinpath(browser_folder(), host, rel)
end

"""
The web address that the file or the folder at `path` is, for the window: an
address itself, and the address of a file or a folder of the browser folder.
It's "" for any other path.
"""
web_address(path::AbstractString) = begin
  isremote(path) && return String(path)
  in_browser(path) || return ""
  from = isfile(path) ? copied_from(path) : ""
  isempty(from) || return from
  # A file that has lost its mark, or a folder: its place in the folder says its address
  parts = split(relpath(path, browser_folder()), '/')
  rest = join(parts[2:end], '/')
  isdir(path) ? (rest = isempty(rest) ? "" : rest * "/") : (rest = replace(rest, r"(^|/)index\.(md|html)$" => s"\1"))
  "https://" * parts[1] * "/" * replace(rest, '%' => "%25", ' ' => "%20", '#' => "%23", '?' => "%3F")
end

"The file of the browser folder that keeps the page at `address` already, or nothing"
saved_page(address::AbstractString) = begin
  for path in (browser_path(Remote.bare(address), page=true), browser_path(Remote.bare(address), html=true))
    path !== nothing && isfile(path) && return path
  end
  nothing
end

"The name of the extended attribute that holds the fingerprint of what the server last sent for a file of the browser folder"
const GOT_MARK = APP_ID * ".got"

"A fingerprint of `bytes`, to tell whether two files hold the same: FNV-1a, which is the same in every run of Ladder"
fingerprint(bytes) = (h = 0xcbf29ce484222325; for x in bytes; h = (h ⊻ x) * 0x00000100000001b3; end; string(h, base=16))

"The fingerprint of what the server last sent for the file at `path`, or \"\""
got_mark(path::AbstractString) = (data = MacFiles.extra(path, GOT_MARK); data === nothing ? "" : String(data))

"Keep `value` in the extended attribute `name` of the file at `path`"
mark_file!(path, name, value) = (Sys.isapple() && ccall(:setxattr, Cint, (Cstring, Cstring, Ptr{UInt8}, Csize_t, UInt32, Cint),
                                                         path, name, value, sizeof(value), 0, 0); nothing)

"True when the file at `path` of the browser folder isn't what the server last sent: you changed it"
changed_here(path::AbstractString) = isfile(path) && fingerprint(read(path)) != got_mark(path)

"""
Put `bytes`, what the server sent for `address`, in the file at `path` of the
browser folder, marked with the address and the fingerprint of the bytes. It's
the path, or nothing when the disk says no, as when a file has the name of a
folder that the path needs.
"""
keep_got!(path, address, bytes) = try
  mkpath(dirname(path))
  read_now = isfile(path) ? read(path) : nothing
  read_now == bytes || write(path, bytes)
  mark_copy!(path, Remote.bare(address))
  mark_file!(path, GOT_MARK, fingerprint(bytes))
  path
catch
  nothing
end

"""
A page of the browser folder at `path`, as a window first shows it: with no
caret until a click puts one in it, so the keys scroll it, as a browser's do.
The caret's place is after any front matter, as it is in a file, so the front
matter shows as a card.
"""
web_buffer(path) = begin
  b = load(path)
  b.reading = true
  b
end

# --- a site with a viewer of its own ---
#
# A site's folder in the browser folder, like ~/web/x.com, can have a kind,
# as any folder can. Code gives it one by the site's name, in `SITE_KINDS`, or
# the folder's own page does: a file called `.ladder` that you put in the folder.
# The kind then shows the site its own way, as a kind shows a folder of films
# as posters. Ladder asks the kind before it asks the site's server, wherever
# an address of the site comes from: a link, a link card, Navigate, a
# favourite site, Reload Page.
#
#     Ladder.SITE_KINDS["x.com"] = XDirectory
#     Ladder.open_address!(e, d::XDirectory, address; record=true, reload=false) = begin
#       path = ...   # the folder of ~/web/x.com that's this address
#       mkpath(path)
#       Ladder.open!(e, path; record)
#       true
#     end
#     Ladder.FS.kind(::XDirectory, path::FSPath) = XPosts   # what its folders are
#     Ladder.page_view(e, d::XPosts) = ...                  # what the page shows of one
#
# The kind's method of `open_address!` shows a file or a folder of the site's
# folder, with `open!`, and what shows there is the kind's own: `page_view`,
# `window_view`, `side_menu` and the rest, as for any kind of folder. A site
# that only gives its pages to a browser that's signed in reads them through
# hiddenpage.jl. A site has other names, like twitter.com for x.com, when each
# name has the kind in `SITE_KINDS`. The folder of a name needn't be there.

"""
Show the page at `address` in the window of `e`, for the site whose folder in
the browser folder is `d`: true when the folder's kind showed it. False
leaves the page to Ladder, which asks the site's server for it, as it does
for a site with no viewer. A kind of folder has a method of this to show the
pages of its site its own way. `record` is false when the page that leaves
doesn't go on the list that `go_back!` reads. `reload` is true when Reload
Page asked, so what shows is asked for again.
"""
open_address!(e, d, address; record=true, reload=false) = false

"""
The object of the folder of the browser folder that keeps the site of
`address`, when that folder has a kind, or nothing: for an address of no
site, and for a site whose folder is plain. The folder needn't be there:
its object is of the kind that its path has.
"""
site_folder(address::AbstractString) = begin
  host = lowercase(Remote.host(address))
  (Remote.isaddress(address) && !isempty(host) && !startswith(host, '.') && !occursin('/', host)) || return nothing
  path = joinpath(browser_folder(), host)
  # The folder's own page says its kind, and loads the code of the kind. It runs now if it hasn't.
  isdir(path) && folder_pages!(path)
  d = try
    if isdir(path)
      Base.invokelatest(FS.get, FSPath(path))
    else
      kind = Base.invokelatest(folder_kind, FSPath(path))
      kind === FS.Directory ? nothing : kind(path=FSPath(path), parent=nothing)
    end
  catch
    nothing
  end
  d isa AbstractDirectory && !(d isa FS.Directory) ? d : nothing
end

site_shows!(e, address::AbstractString; record=true, reload=false) = begin
  d = site_folder(address)
  d === nothing && return false
  hosted(e) === nothing || (e = top_editor(e))   # a link in a part of another page shows in the window
  # A kind that a folder's page gave is newer than the click that asks
  Base.invokelatest(open_address!, e, d, String(address); record, reload) === true
end

"A page that the window of `e` has asked a web server for"
mutable struct PageAsked
  address::String      # as it was asked for, with what follows a #
  coming::Any          # the Remote.Coming, or nothing until the window may ask the web
  record::Bool         # the page that leaves goes on the list that `go_back!` reads
  else_browser::Bool   # what isn't Markdown opens in the browser, and Ladder says nothing of it
  again::Bool          # the window shows the page already, and this asks for it again
  reload::Bool         # Reload Page asked for it: Ladder asks you first if you changed the file
  since::Float64       # when it was asked for
end

"""
Ask the server for the page at `address`, and show it in the window of `e`.
A page that the browser folder has already shows at once, and what the
server sends takes its place when it comes: see "the browser folder". Else
the window shows what it has until the page comes. With `else_browser`, what
turns out not to be Markdown or HTML opens in your browser with no words
about it, as a link does. A page that's asked for while another is on its
way takes its place. `reload` is Reload Page's.
"""
get_page!(e, address; record=true, else_browser=false, again=false, reload=false) = begin
  hosted(e) === nothing || return get_page!(top_editor(e), address; record, else_browser, again, reload)   # a link in a part of another page
  address = String(strip(address))
  site_shows!(e, address; record, reload) && return e   # the site has a viewer of its own, and it showed the page
  saved = again ? nothing : saved_page(address)
  if saved !== nothing
    open!(e, saved; record)
    heading = Remote.place(address)
    isempty(heading) || go_heading!(e, saved, heading)
    record, again = false, true
  end
  e.nodes[:page_asked] = PageAsked(address, nothing, record, else_browser, again, reload, time())
  redraw_in!(e, 0)
  e
end

"How long a page can take to come before words under the top bar say that Ladder is getting it, in seconds"
const PAGE_WAIT = 0.4

"Look whether the page that the window of `e` asked a web server for has come, and show it when it has. Each frame calls this."
remote_tick!(e) = begin
  isempty(WEB_FOLDER_PAGES) || web_folders_tick!(e)
  a = get(e.nodes, :page_asked, nothing)
  a isa PageAsked || return nothing
  if a.coming === nothing
    page_online(e) || return nothing   # a window that isn't on the screen yet asks once it is
    a.coming = Remote.ask(a.address, getter=(args...) -> PAGE_GETTER[](args...))
    # The page of each folder that it's in comes beside it: see "a web folder's own page"
    ask_web_folders!(a.address, again=a.again)
  end
  got = Remote.landed(a.coming)
  if got === nothing
    # A page that comes at once shows with no words before it. The words stay for as long as the page takes.
    # A page that shows already, from the browser folder, needs none, unless you asked for it again.
    words = "Getting $(Remote.label(a.address))…"
    (!a.again || a.reload) && time() - a.since > PAGE_WAIT && keep_saying!(e, words)
    redraw_in!(e, 0.05)
    return nothing
  end
  delete!(e.nodes, :page_asked)
  Remote.ismarkdown(got) && ask_web_folders!(got.address)   # a page that moved is in other folders
  land_page!(e, a, got)
  redraw_in!(e, 0)
  nothing
end

"Take away the words under the top bar that say that Ladder is getting a page"
unsay_getting!(e) = begin
  said = said_result(e)
  (said !== nothing && startswith(said[1], "Getting ")) || return nothing
  unsay_result!(e)
  w = window_of(e)
  w === nothing || close_popup!(w, :result)
  nothing
end

"""
Do what `got`, the server's answer for the page `a`, calls for. A page of
Markdown or of HTML goes in the browser folder, and the window shows it. Ask
for a page that the window shows already, and what came takes its place, as
`take_page!` says. Anything else that the server sent, like a PDF file, opens
in your browser. When the server sent nothing, or said that it has no such
page, words under the top bar say so, and the window keeps its page. The page
of what went wrong that a server sends with that isn't kept.
"""
land_page!(e, a::PageAsked, got) = begin
  unsay_getting!(e)
  page = Remote.ismarkdown(got)
  if !Remote.ok(got)
    say_result!(e, Remote.problem(got))
  elseif page || Remote.ishtml(got)
    path = browser_path(got.address; page, html=!page)
    path === nothing && return say_result!(e, "The browser folder can't keep $(Remote.label(got.address)).")
    take_page!(e, a, path, got.address, Vector{UInt8}(join(Remote.lines(got), "\n")))
  else
    # A picture, a PDF file, or a page that's neither Markdown nor HTML: a browser shows those
    BROWSER[](a.address)
    a.else_browser || say_result!(e, "$(Remote.host(a.address)) sent no page that Ladder shows, so your browser has it.")
  end
  e
end

"""
Keep `bytes`, the page at `address` that came for `a`, in the file at `path`
of the browser folder, and show it. What came takes the place of the file
that the folder has, unless you changed that file, or the window has changes
of yours to it that aren't saved. Then it stays as you changed it, and Ladder
asks you after the frame whether to take what came, when the server has
something new or you asked with Reload Page: see `ask_reload!`.
"""
take_page!(e, a::PageAsked, path, address, bytes) = begin
  b = get(e.buffers, path, nothing)
  mine = isfile(path) && (changed_here(path) || (b !== nothing && dirty(b)))
  if !mine
    keep_got!(path, address, bytes) === nothing && return say_result!(e, "The browser folder can't keep $(Remote.label(address)).")
  elseif read(path) == bytes
    mark_file!(path, GOT_MARK, fingerprint(bytes))   # what came is what you have, so nothing is changed after all
  elseif a.reload || fingerprint(bytes) != got_mark(path)
    e.nodes[:reload_ask] = (path, String(address), bytes)
  end
  show_page!(e, a, path)
end

"""
Show the page of the browser folder at `path`, which came for `a`. A page that
the window asked for again shows from where it was scrolled to.
"""
show_page!(e, a::PageAsked, path) = begin
  if !a.again
    open!(e, path; record=a.record)
    heading = Remote.place(a.address)
    isempty(heading) || e.buf.path != path || go_heading!(e, path, heading)
  end
  e
end

"""
Ask whether the page of the browser folder that you changed takes what the
server sent, after the frame that shows the page: see `take_page!`. A panel
asks. When you say yes, the page is what came, in the file and in the window,
and your changes are gone. When you say no, the page stays as you changed it,
and Ladder asks again only when the server has something newer, or you use
Reload Page.
"""
ask_reload!(e) = begin
  q = pop!(e.nodes, :reload_ask, nothing)
  q === nothing && return nothing
  path, address, bytes = q
  yes = (RELOAD_ASKER[] !== reload_panel || on_screen(e)) && RELOAD_ASKER[](path, address)
  # The panel took the keyboard, so the window never heard the keys that answered it come up
  w = window_of(e)
  w === nothing || (w.keys = Keys(0))
  if yes
    keep_got!(path, address, bytes)
    # The page in the window is read again from the file, without your changes
    if haskey(e.buffers, path)
      b = e.buffers[path] = web_buffer(path)
      e.buf.path == path && (b.offset = e.scroll.offset; e.buf = b)
    end
  else
    mark_file!(path, GOT_MARK, fingerprint(bytes))
  end
  redraw_in!(e, 0)
  nothing
end

"""
Ask whether the page of the browser folder at `path`, which you changed, takes
what the server sent for `address`, in a panel. True when you say that it
does. The button that Return presses keeps your changes.
"""
reload_panel(path::AbstractString, address::AbstractString) = with_pool() do
  alert = msg(msg(cls("NSAlert"), "alloc"), "init")
  msg(alert, "setMessageText:", nsstring("You changed $(Remote.trail(address)[end][1])"))
  msg(alert, "setInformativeText:", nsstring(
    "$(Remote.label(address)) can show what $(Remote.host(address)) has now. Your changes are then lost. " *
    "The page is in your browser folder, at $(tilde(path))."))
  msg(alert, "addButtonWithTitle:", nsstring("Keep My Changes"))
  msg(alert, "addButtonWithTitle:", nsstring("Show What the Site Has"))
  # 1000 is the first button, Keep My Changes
  yes = ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), alert, sel("runModal")) == 1001
  msg(alert, "release")
  yes
end

"What asks whether a page that you changed takes what its server sent. A test puts its own function here."
const RELOAD_ASKER = Ref{Function}(reload_panel)

"""
The whole web address that `src` means in the page from a web server that
`e` shows, or nothing when it names no place on the web, as a path of the
Mac written `file:` doesn't. A picture of the page is from the page's address.
"""
remote_src(e, src::AbstractString) = begin
  to = Remote.against(web_address(e.buf.path), strip(src))
  Remote.isaddress(to) ? replace(to, ' ' => "%20") : nothing
end

"""
Follow the link `url` of the page from a web server that `e` shows. The link
is from the page's address. A link to a heading of the page goes there. An
address on the web is asked for: Markdown shows in the window, and anything
else opens in your browser. `mailto:` opens the app for email. A wiki link
and a link to a file of the Mac go nowhere.
"""
follow_remote!(e, url) = begin
  wikitarget(url) === nothing || return e
  page = web_address(e.buf.path)
  to = Remote.against(page, url)
  occursin(r"^mailto:"i, to) && return (BROWSER[](to); e)
  Remote.isaddress(to) || return e
  if Remote.bare(to) == Remote.bare(page)
    heading = Remote.place(to)
    isempty(heading) || go_heading!(e, e.buf.path, heading)   # the page's file, which shows
    return e
  end
  get_page!(e, to, else_browser=true)
end

"""
True when a click on the link `url`, in a page of your own, asks the server
for it: it's a web address that ends as a Markdown file's name does, and the
window may ask the web. Any other address opens in your browser unasked.
"""
reads_here(e, url) = Remote.isaddress(url) && Remote.named_markdown(url) && page_online(e)

"""
Navigate: go to a file or a folder of the Mac, like ~/Desktop, or to a web
address, like example.com/notes.md. A file or a folder shows as a link to it
shows it. A page of Markdown on the web shows in the window, and anything
else there opens in your browser.
"""
navigate!(e, address::String) = begin
  path = typed_path(e, address)
  if path !== nothing
    ispath(path) || return (say_result!(e, "There's no file or folder at $(tilde(path))."); e)
    return show_path!(e, path)
  end
  to = Remote.typed(address)
  to === nothing && return (say_result!(e, "“$(strip(address))” isn't a file, a folder or a web address. Write one like ~/Desktop or example.com/notes.md."); e)
  get_page!(e, to)
end
add_command!(navigate!, title="Go to a file or a folder, like ~/Desktop, or a web address, like example.com/notes.md: Markdown on the web shows here, and the rest in your browser", keys="cmd+l")

"""
The path of the Mac that `text` names when it's typed for Navigate, or nothing
when it names none. A path starts with /, ~ or file://. With `near`, other
words that aren't a web address are a path from the folder of the page that
shows, like `notes/plans.md` or `../Canon`, when that's a file or a folder.
A page from a web server has no such folder. A path that starts as a path's
does needn't be there. Its capitals are those of the file or the folder that's
there, so /users/jake is /Users/jake, as the Finder names it.
"""
typed_path(e, text::AbstractString; near=true) = begin
  t = String(strip(text))
  path = if occursin(r"^file://"i, t)
    Remote.unescaped(replace(t[8:end], r"^localhost(?=/)"i => ""))
  elseif startswith(t, '/') || t == "~" || startswith(t, "~/")
    expanduser(t)
  elseif near && !isempty(t) && !in_browser(e.buf.path) && Remote.typed(t) === nothing
    from = docdir(e)
    (isempty(from) || !ispath(joinpath(from, t))) && return nothing
    joinpath(from, t)
  else
    return nothing
  end
  path = normpath(path)
  length(path) > 1 && (path = String(rstrip(path, '/')))
  # The Mac finds /users/jake as /Users/jake. A link isn't followed: only the capitals change.
  real = ispath(path) ? realpath(path) : path
  lowercase(real) == lowercase(path) ? real : path
end

"Where Navigate goes for `text`: a path of the Mac, a web address, or nothing. See `typed_path` for what `near` does."
navigate_place(e, text::AbstractString; near=true) = something(typed_path(e, text; near), Remote.typed(text), Some(nothing))

"What the list of commands calls the place that Navigate goes to: a web address without its https://, or a path from ~"
place_label(to::AbstractString) = isremote(to) ? Remote.label(to) : tilde(to)

# Navigate changes no file, so it goes as soon as it has its address, with no press of Run. Its chip is wide, for a long address.
runs_at_once(::Val{:navigate}) = true
wide_words(::Val{:navigate}) = true

"Reload Page: ask the server again for the page from the web that shows"
reload_page!(e) = in_browser(e.buf.path) ? (at = web_address(e.buf.path); forget_view_copies!(web_site(at)); get_page!(e, at, record=false, again=true, reload=true)) : e
add_command!(reload_page!, title="Ask the server again for the page from the web that shows", kind=:look)

"Ask again for the files that the `view` blocks of the pages of `site` show, the next time that each shows"
forget_view_copies!(site) = filter!(((url, _),) -> web_site(url) != site, VIEW_COPIES)

"Open In Browser: show the page from the web that shows in your browser"
open_in_browser!(e) = (in_browser(e.buf.path) && BROWSER[](web_address(e.buf.path)); e)
add_command!(open_in_browser!, title="Show the page from the web that shows in your browser", kind=:look)

works_here(e, ::Union{Val{:reload_page},Val{:open_in_browser}}) = in_browser(e.buf.path)

# --- the web address of a file ---------------------------------------------------------------
#
# Each file of the browser folder keeps the address that it came from in an
# extended attribute named `COPY_MARK`, which macOS keeps with the file when
# Ladder saves your changes to it. So does each file of a copy of a site that
# Ladder saved before it had the browser folder. Somebody else wrote such a
# file, so it runs no code unless its site may: see `foreign`.

"The name of the extended attribute that holds the web address of a file of the browser folder, or of a copy that Ladder saved before it had one"
const COPY_MARK = APP_ID * ".from"

"Each file whose `COPY_MARK` Ladder has read or written, with the address that it came from, or \"\" when it has none"
const COPY_ADDRESSES = Dict{String,String}()

"The address of the page on the web that the file at `path` is a copy of, or \"\" when it's no copy"
copied_from(path::AbstractString) = isempty(path) || isremote(path) ? "" : get!(COPY_ADDRESSES, String(path)) do
  data = MacFiles.extra(path, COPY_MARK)
  data === nothing ? "" : String(data)
end

"Mark the file at `path` as a copy of what's at `address`"
mark_copy!(path, address) = begin
  COPY_ADDRESSES[path] = address
  Sys.isapple() && ccall(:setxattr, Cint, (Cstring, Cstring, Ptr{UInt8}, Csize_t, UInt32, Cint),
                         path, COPY_MARK, address, sizeof(address), 0, 0)
  nothing
end
